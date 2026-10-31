#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("inspect_sram", HERE / "inspect_sram.py")
mod = importlib.util.module_from_spec(spec)
assert spec.loader
spec.loader.exec_module(mod)


def put_u16(b: bytearray, off: int, value: int) -> None:
    b[off] = value & 0xFF
    b[off + 1] = (value >> 8) & 0xFF


def fill_patterns(data: bytearray, family: str, variant: str = "A") -> None:
    for bank in range(4):
        limit = 0x100 if bank < 2 else 0x2000
        base = bank * 0x2000
        for off in range(limit):
            data[base + off] = mod.expected_byte(bank, off, variant, family)


def checksum16(buf: bytearray, off: int) -> None:
    put_u16(buf, off, sum(buf[:off]) & 0xFFFF)


def make_diag_trace(family: str) -> bytes:
    data = bytearray(0x8000)
    fill_patterns(data, family, "A")
    magic, version = (b"X7D8", 8) if family == "DIAG" else (b"X7T1", 2)
    s = bytearray(64)
    s[:4] = magic
    s[4] = ord("A")
    s[5] = version
    s[6] = 1
    put_u16(s, 8, 3)
    put_u16(s, 14, 1)
    s[24] = 0x2A
    s[25] = 0x07 if family == "DIAG" else 0x22
    s[26] = 4
    s[27] = 3
    s[28] = 8
    s[34] = 0x0A
    if family == "TRACE":
        s[53] = 3
    checksum16(s, 62)
    for bank in (0, 1):
        data[bank * 0x2000 + 0x100 : bank * 0x2000 + 0x140] = s

    stats = bytearray(128)
    stats[:4] = b"X7S8" if family == "DIAG" else b"X7S1"
    stats[4] = ord("A")
    stats[5] = version
    put_u16(stats, 6, 2)
    stats[8:12] = (1234).to_bytes(4, "little")
    stats[12:16] = (640).to_bytes(4, "little")
    put_u16(stats, 16, 1)
    stats[18:22] = (9876).to_bytes(4, "little")
    stats[22:26] = (0).to_bytes(4, "little")
    checksum16(stats, 126)
    for bank in (0, 1):
        data[bank * 0x2000 + 0x1A0 : bank * 0x2000 + 0x220] = stats

    r = bytearray(32)
    put_u16(r, 0, 1)
    r[2] = 0x20
    r[3] = s[25]
    r[4] = 4
    r[5] = 3
    r[6] = 8
    r[7] = 0x2A
    r[24] = 0x0A
    checksum16(r, 30)
    for bank in (0, 1):
        base = bank * 0x2000 + 0x300
        data[base : base + 32] = r
    return bytes(data)


def make_pokertc() -> bytes:
    data = bytearray(0x8000)
    fill_patterns(data, "POKERTC", "A")
    s = bytearray(64)
    s[:4] = b"X7P1"
    s[4] = 1
    put_u16(s, 5, 2)
    s[9] = 2
    for i, mask in enumerate((1, 2, 4, 8, 1)):
        p = 19 + i * 5
        s[p:p+4] = bytes((0, 0, 0, 0))
        s[p+4] = mask
    put_u16(s, 46, 1)
    s[48] = 1
    checksum16(s, 62)
    for bank in (0, 1):
        data[bank * 0x2000 + 0x100 : bank * 0x2000 + 0x140] = s
    r = bytearray(16)
    put_u16(r, 0, 1)
    r[2] = 2
    r[14] = 1
    r[15] = sum(r[:15]) & 0xFF
    for bank in (0, 1):
        base = bank * 0x2000 + 0x200
        data[base : base + 16] = r
    return bytes(data)


class InspectorTests(unittest.TestCase):
    def test_diag_detection_and_audit(self):
        r = mod.inspect_bytes(make_diag_trace("DIAG"))
        self.assertEqual(r["family"], "DIAG")
        self.assertTrue(r["pattern_audit"]["pass"])
        self.assertEqual(r["super"]["scenario"], 0x2A)
        self.assertEqual(len(r["journal"]), 1)
        self.assertTrue(r["stress_stats"]["valid"])
        self.assertEqual(r["stress_stats"]["entries"][0]["runs"], 2)
        self.assertEqual(r["stress_stats"]["entries"][0]["loops"], 1234)
        self.assertEqual(r["stress_stats"]["entries"][0]["elapsed"], "00:00:10.000")
        self.assertEqual(r["stress_stats"]["entries"][1]["mode"], "BARE_MAX")
        self.assertFalse(r["stress_stats"]["entries"][1]["timed"])
        self.assertIn("raw_hex", r["journal"][0])

    def test_trace_preset(self):
        r = mod.inspect_bytes(make_diag_trace("TRACE"))
        self.assertEqual(r["family"], "TRACE")
        self.assertEqual(r["super"]["preset"], "RTC-H")
        self.assertTrue(r["pattern_audit"]["pass"])

    def test_pokertc_value_map(self):
        r = mod.inspect_bytes(make_pokertc())
        self.assertEqual(r["family"], "POKERTC")
        self.assertEqual([x["mask"] for x in r["value_map"]], [1, 2, 4, 8, 1])
        self.assertTrue(r["pattern_audit"]["pass"])
        self.assertEqual(r["journal"][0]["result_name"], "PASS")
        self.assertIn("mirror0_raw_hex", r["journal"][0])

    def test_cleared_sram_is_recognized(self):
        r = mod.inspect_bytes(bytes(0x8000))
        self.assertEqual(r["family"], "UNINITIALIZED")
        self.assertIn("all-zero", r["format"])

    def test_corruption_is_reported(self):
        d = bytearray(make_diag_trace("DIAG"))
        d[2 * 0x2000] = 0x08
        r = mod.inspect_bytes(bytes(d))
        self.assertFalse(r["pattern_audit"]["pass"])
        first = r["pattern_audit"]["mismatches"][0]
        self.assertEqual((first["bank"], first["address"], first["expected"], first["actual"]), (2, 0xA000, 0x14, 0x08))

    def test_html_renderer_is_self_contained(self):
        r = mod.inspect_bytes(make_pokertc())
        page = mod.render_html(r, "test.srm")
        self.assertIn("<!doctype html>", page.lower())
        self.assertIn("X7 SRAM report", page)
        self.assertNotIn("http://", page)
        self.assertNotIn("https://", page)


if __name__ == "__main__":
    unittest.main()
