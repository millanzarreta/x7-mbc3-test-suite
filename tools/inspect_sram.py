#!/usr/bin/env python3
"""Unified SRAM inspector for X7MBC3DIAG, X7MBC3TRACE and X7POKERTC.

Only the first 32 KiB are treated as cartridge SRAM. Extra bytes (for emulator
containers or appended state) are reported but ignored by the parsers.
"""
from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path
from typing import Any

SRAM_SIZE = 0x8000
BANK_SIZE = 0x2000

CANARIES = {
    "A": ([0xA0, 0xB1, 0x14, 0x00], [0x10, 0x20, 0x5A, 0xA5]),
    "B": ([0xA1, 0xB2, 0x24, 0x30], [0x31, 0x42, 0x6B, 0xC6]),
    "N": ([0xA2, 0xB3, 0x34, 0x40], [0x52, 0x63, 0x7C, 0xD7]),
}
POKERTC_CAN = [0x3C, 0xC3, 0x14, 0x00]
POKERTC_CONST = [0x10, 0x20, 0x5A, 0xA5]

COMMON_TESTS = {
    0x00: "BOOT",
    0x01: "RAM_AUDIT",
    0x02: "BANK_STRESS",
    0x03: "SIGNATURE",
    0x04: "RTC_MAP",
    0x05: "RTC_STRESS",
    0x06: "LATCH_STRESS",
    0x07: "ARM",
    0x08: "VIEW_RTC",
    0x09: "STATUS",
    0x0A: "MASTER",
}
TRACE_TESTS = {
    **COMMON_TESTS,
    0x03: "SILVER_TRACE",
    0x04: "RTC_MAP",
    0x05: "RTC_TRACE",
    0x06: "SELECT_TRACE",
    0x20: "ARM_SILVER",
    0x21: "ARM_SELECT",
    0x22: "ARM_RTC_H",
    0x23: "ARM_RTC_DL",
    0x24: "ARM_SRAM2",
    0x25: "ARM_SRAM3",
}
POKERTC_TESTS = {
    1: "RAM AUDIT",
    2: "VALUE MAP",
    3: "POKE GET CLOCK",
    4: "POKE _GETCLOCK",
    5: "POKE START RTC",
    6: "POKE STOP RTC",
    7: "POKE SAVE RTC",
    8: "POKE STARTCLOCK",
    9: "VIEW RTC",
    10: "STATUS",
}
MODES = {0: "ONESHOT", 1: "NORMAL", 2: "BARE_MAX", 3: "BARE_FIXED", 4: "EXTERNAL", 5: "SYSTEM"}
CONTEXTS = {0: "SYSTEM", 1: "MANUAL", 2: "MASTER", 3: "EXTERNAL"}
REASONS = {0: "NONE", 1: "AUTO_PASS", 2: "MANUAL_B", 3: "MASTER_TIME", 4: "MASTER_TARGET", 5: "EXT_PASS", 6: "BOOT", 7: "INIT", 8: "ARMED", 9: "MASTER_DONE", 0xE0: "FAULT"}
EVENTS = {0x01: "INIT", 0x02: "BOOT", 0x03: "EXT_PASS", 0x10: "TEST_START", 0x11: "TEST_PASS", 0x20: "ARM", 0x30: "MASTER_START", 0x31: "MASTER_DONE", 0xE0: "FAULT"}
PRESETS = {1: "SILVER", 2: "SELECT", 3: "RTC-H", 4: "RTC-DL", 5: "SRAM2", 6: "SRAM3"}

STRESS_MODES = ("NORMAL", "BARE_MAX", "BARE_FIXED")
STRESS_TESTS = {
    "DIAG": ("BANK_STRESS", "SIGNATURE", "RTC_STRESS", "LATCH_STRESS"),
    "TRACE": ("BANK_STRESS", "SILVER_TRACE", "RTC_TRACE", "SELECT_TRACE"),
}
SELECTOR_NAMES = {
    0x00: "SRAM bank 0", 0x01: "SRAM bank 1", 0x02: "SRAM bank 2", 0x03: "SRAM bank 3",
    0x08: "RTC seconds", 0x09: "RTC minutes", 0x0A: "RTC hours",
    0x0B: "RTC day low", 0x0C: "RTC day high",
}

def pokertc_result_name(test_id: int, result: int) -> str:
    if result == 0:
        return "PASS"
    if result == 0xEE:
        return "FAULT"
    if result == 1:
        return "ALIAS" if test_id in {2, 5, 6, 7, 8} else "FAIL"
    return f"0x{result:02X}"


def u16(b: bytes, o: int) -> int:
    return b[o] | (b[o + 1] << 8)


def u32(b: bytes, o: int) -> int:
    return b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)


def fmt_ticks(ticks: int) -> str:
    total_ms = ticks * 1000 // 64
    h, rem = divmod(total_ms, 3_600_000)
    m, rem = divmod(rem, 60_000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def block(data: bytes, bank: int, rel: int, length: int) -> bytes:
    base = bank * BANK_SIZE + rel
    return data[base : base + length]


def additive16_ok(b: bytes, checksum_off: int) -> bool:
    return len(b) > checksum_off + 1 and (sum(b[:checksum_off]) & 0xFFFF) == u16(b, checksum_off)


def hex_bytes(b: bytes) -> str:
    return " ".join(f"{x:02X}" for x in b)


def parse_stress_stats(data: bytes, family: str, variant: str) -> dict[str, Any]:
    expected_magic = b"X7S8" if family == "DIAG" else b"X7S1"
    expected_version = 8 if family == "DIAG" else 2
    copies = []
    for bank in (0, 1):
        raw = block(data, bank, 0x1A0, 128)
        valid = (
            len(raw) == 128
            and raw[:4] == expected_magic
            and raw[4] == ord(variant)
            and raw[5] == expected_version
            and additive16_ok(raw, 126)
        )
        copies.append((raw, valid))

    selected_index = next((i for i, (_raw, ok) in enumerate(copies) if ok), None)
    if selected_index is None:
        return {
            "valid": False,
            "magic": expected_magic.decode(),
            "variant": variant,
            "version": expected_version,
            "mirrors_valid": [copies[0][1], copies[1][1]],
            "mirrors_identical": copies[0][0] == copies[1][0],
            "entries": [],
        }

    raw = copies[selected_index][0]
    entries = []
    off = 6
    for test in STRESS_TESTS[family]:
        for mode in STRESS_MODES:
            runs = u16(raw, off)
            loops = u32(raw, off + 2)
            ticks = u32(raw, off + 6)
            entries.append({
                "test": test,
                "mode": mode,
                "runs": runs,
                "loops": loops,
                "ticks": ticks,
                "elapsed": fmt_ticks(ticks),
                "timed": mode == "NORMAL",
            })
            off += 10

    return {
        "valid": True,
        "magic": raw[:4].decode("ascii", "replace"),
        "variant": chr(raw[4]),
        "version": raw[5],
        "mirrors_valid": [copies[0][1], copies[1][1]],
        "mirrors_identical": copies[0][0] == copies[1][0],
        "selected_mirror": selected_index,
        "checksum_stored": u16(raw, 126),
        "checksum_calculated": sum(raw[:126]) & 0xFFFF,
        "entries": entries,
    }


def detect_family(data: bytes) -> str | None:
    if len(data) < SRAM_SIZE:
        return None
    magics = {block(data, bank, 0x100, 4) for bank in (0, 1)}
    if b"X7D8" in magics:
        return "DIAG"
    if b"X7T1" in magics:
        return "TRACE"
    if b"X7P1" in magics:
        return "POKERTC"
    return None


def expected_byte(bank: int, off: int, variant: str, family: str) -> int:
    if family == "POKERTC":
        cans, consts = POKERTC_CAN, POKERTC_CONST
    else:
        cans, consts = CANARIES[variant]
    if off == 0:
        return cans[bank]
    addr = 0xA000 + off
    return ((addr >> 8) ^ (addr & 0xFF) ^ consts[bank]) & 0xFF


def pattern_audit(data: bytes, variant: str, family: str, max_entries: int = 64) -> dict[str, Any]:
    mismatches = []
    for bank in range(4):
        limit = 0x100 if bank < 2 else 0x2000
        base = bank * BANK_SIZE
        for off in range(limit):
            expected = expected_byte(bank, off, variant, family)
            actual = data[base + off]
            if actual != expected:
                mismatches.append({
                    "bank": bank,
                    "address": 0xA000 + off,
                    "expected": expected,
                    "actual": actual,
                })
                if len(mismatches) >= max_entries:
                    return {"pass": False, "mismatch_count_at_least": len(mismatches), "mismatches": mismatches}
    return {"pass": not mismatches, "mismatch_count": len(mismatches), "mismatches": mismatches}


def parse_diag_trace(data: bytes, family: str) -> dict[str, Any]:
    assert family in {"DIAG", "TRACE"}
    magic = b"X7D8" if family == "DIAG" else b"X7T1"
    version = 8 if family == "DIAG" else 2
    tests = COMMON_TESTS if family == "DIAG" else TRACE_TESTS
    supers = []
    for bank in (0, 1):
        s = block(data, bank, 0x100, 64)
        valid = len(s) == 64 and s[:4] == magic and s[5] == version and additive16_ok(s, 62)
        supers.append((s, valid))
    selected = next((s for s, ok in supers if ok), None)
    if selected is None:
        raise ValueError(f"No valid {family} superblock")
    variant = chr(selected[4])
    if variant not in CANARIES:
        raise ValueError(f"Unsupported {family} variant {variant!r}")

    flags = selected[6]
    super_info: dict[str, Any] = {
        "magic": selected[:4].decode("ascii", "replace"),
        "variant": variant,
        "version": selected[5],
        "mirrors_valid": [supers[0][1], supers[1][1]],
        "mirrors_identical": supers[0][0] == supers[1][0],
        "flags": flags,
        "armed": bool(flags & 1),
        "fault": bool(flags & 2),
        "journal_full": bool(flags & 4),
        "result": selected[7],
        "boot": u16(selected, 8),
        "generation": u16(selected, 10),
        "event_sequence": u16(selected, 12),
        "journal_count": min(u16(selected, 14), 232),
        "errors": u16(selected, 16),
        "external_passes": u16(selected, 18),
        "campaign": u16(selected, 20),
        "master_run": u16(selected, 22),
        "scenario": selected[24],
        "test_id": selected[25],
        "test": tests.get(selected[25], f"0x{selected[25]:02X}"),
        "mode": MODES.get(selected[26], f"0x{selected[26]:02X}"),
        "context": CONTEXTS.get(selected[27], f"0x{selected[27]:02X}"),
        "reason": REASONS.get(selected[28], f"0x{selected[28]:02X}"),
        "master_cycle": selected[29],
        "master_phase": selected[30],
        "master_cycles_config": selected[31],
        "master_phases_config": selected[32],
        "master_minutes_config": selected[33],
        "last_selector": selected[34],
        "fault_bank": selected[35],
        "fault_address": (selected[37] << 8) | selected[36],
        "expected": selected[38],
        "actual": selected[39],
        "loops": u32(selected, 40),
        "ticks": u32(selected, 44),
        "elapsed": fmt_ticks(u32(selected, 44)),
        "rtc": list(selected[48:53]),
    }
    if family == "TRACE":
        super_info["preset_id"] = selected[53]
        super_info["preset"] = PRESETS.get(selected[53], f"0x{selected[53]:02X}") if selected[53] else "NONE"

    journal = []
    for i in range(super_info["journal_count"]):
        base = 0x300 + i * 32
        r0 = data[base : base + 32]
        r1 = data[BANK_SIZE + base : BANK_SIZE + base + 32]
        ok0 = len(r0) == 32 and additive16_ok(r0, 30)
        ok1 = len(r1) == 32 and additive16_ok(r1, 30)
        if not (ok0 or ok1):
            journal.append({
                "slot": i,
                "valid": False,
                "mirror0_valid": ok0,
                "mirror1_valid": ok1,
                "mirrors_identical": r0 == r1,
                "mirror0_checksum_stored": u16(r0, 30),
                "mirror0_checksum_calculated": sum(r0[:30]) & 0xFFFF,
                "mirror1_checksum_stored": u16(r1, 30),
                "mirror1_checksum_calculated": sum(r1[:30]) & 0xFFFF,
                "mirror0_raw_hex": hex_bytes(r0),
                "mirror1_raw_hex": hex_bytes(r1),
            })
            continue
        selected_mirror = 0 if ok0 else 1
        r = r0 if ok0 else r1
        journal.append({
            "slot": i,
            "valid": True,
            "mirrors": "OK" if ok0 and ok1 and r0 == r1 else "DEGRADED",
            "mirror0_valid": ok0,
            "mirror1_valid": ok1,
            "mirrors_identical": ok0 and ok1 and r0 == r1,
            "selected_mirror": selected_mirror,
            "sequence": u16(r, 0),
            "event_id": r[2],
            "event": EVENTS.get(r[2], f"0x{r[2]:02X}"),
            "test_id": r[3],
            "test": tests.get(r[3], f"0x{r[3]:02X}"),
            "mode_id": r[4],
            "mode": MODES.get(r[4], f"0x{r[4]:02X}"),
            "context_id": r[5],
            "context": CONTEXTS.get(r[5], f"0x{r[5]:02X}"),
            "reason_id": r[6],
            "reason": REASONS.get(r[6], f"0x{r[6]:02X}"),
            "scenario": r[7],
            "boot": u16(r, 8),
            "generation": u16(r, 10),
            "master_run": u16(r, 12),
            "master_cycle": r[14],
            "master_phase": r[15],
            "loops": u32(r, 16),
            "ticks": u32(r, 20),
            "elapsed": fmt_ticks(u32(r, 20)),
            "selector": r[24],
            "selector_name": SELECTOR_NAMES.get(r[24], f"0x{r[24]:02X}"),
            "bank": r[25],
            "address": (r[27] << 8) | r[26],
            "expected": r[28],
            "actual": r[29],
            "checksum_stored": u16(r, 30),
            "checksum_calculated": sum(r[:30]) & 0xFFFF,
            "mirror0_checksum_stored": u16(r0, 30),
            "mirror0_checksum_calculated": sum(r0[:30]) & 0xFFFF,
            "mirror1_checksum_stored": u16(r1, 30),
            "mirror1_checksum_calculated": sum(r1[:30]) & 0xFFFF,
            "raw_hex": hex_bytes(r),
            "mirror0_raw_hex": hex_bytes(r0),
            "mirror1_raw_hex": hex_bytes(r1),
        })

    # First-fault capsule has parallel layout and family-specific magic/version.
    fmagic = b"X7F8" if family == "DIAG" else b"X7F1"
    fault_caps = []
    for bank in (0, 1):
        f = block(data, bank, 0x140, 96)
        ok = len(f) == 96 and f[:4] == fmagic and f[4] == ord(variant) and f[5] == version and additive16_ok(f, 94)
        fault_caps.append((f, ok))
    f = next((x for x, ok in fault_caps if ok), None)
    fault_info = None
    if f is not None:
        fault_info = {
            "mirrors_valid": [fault_caps[0][1], fault_caps[1][1]],
            "mirrors_identical": fault_caps[0][0] == fault_caps[1][0],
            "campaign": u16(f, 6),
            "sequence": u16(f, 8),
            "journal_count": u16(f, 10),
            "boot": u16(f, 12),
            "generation": u16(f, 14),
            "errors": u16(f, 16),
            "master_run": u16(f, 18),
            "event": EVENTS.get(f[20], f"0x{f[20]:02X}"),
            "test": tests.get(f[21], f"0x{f[21]:02X}"),
            "mode": MODES.get(f[22], f"0x{f[22]:02X}"),
            "context": CONTEXTS.get(f[23], f"0x{f[23]:02X}"),
            "reason": REASONS.get(f[24], f"0x{f[24]:02X}"),
            "scenario": f[25],
            "selector": f[31],
            "selector_name": SELECTOR_NAMES.get(f[31], f"0x{f[31]:02X}"),
            "bank": f[32],
            "address": (f[34] << 8) | f[33],
            "expected": f[35],
            "actual": f[36],
            "loops": u32(f, 37),
            "ticks": u32(f, 41),
            "elapsed": fmt_ticks(u32(f, 41)),
            "rtc": list(f[45:50]),
        }
        if family == "TRACE":
            fault_info["preset_id"] = f[58]
            fault_info["preset"] = PRESETS.get(f[58], f"0x{f[58]:02X}") if f[58] else "NONE"

    return {
        "family": family,
        "format": f"{magic.decode()} / {version}",
        "super": super_info,
        "first_fault": fault_info,
        "stress_stats": parse_stress_stats(data, family, variant),
        "pattern_audit": pattern_audit(data, variant, family),
        "journal": journal,
    }


def parse_pokertc(data: bytes) -> dict[str, Any]:
    supers = []
    for bank in (0, 1):
        s = block(data, bank, 0x100, 64)
        valid = len(s) == 64 and s[:4] == b"X7P1" and s[4] == 1 and additive16_ok(s, 62)
        supers.append((s, valid))
    s = next((x for x, ok in supers if ok), None)
    if s is None:
        raise ValueError("No valid POKERTC X7P1 superblock")

    value_map = []
    values = [0x11, 0x22, 0x05, 0xA7, 0x01]
    for i, sel in enumerate(range(0x08, 0x0D)):
        r = s[19 + i * 5 : 24 + i * 5]
        value_map.append({
            "selector": sel,
            "value": values[i],
            "bank_values": list(r[:4]),
            "mask": r[4],
        })

    seq = u16(s, 46)
    jidx = s[48] & 31
    count = min(seq, 32)
    first = (jidx - count) & 31
    journal = []
    for n in range(count):
        slot = (first + n) & 31
        r0 = data[0x200 + slot * 16 : 0x200 + (slot + 1) * 16]
        r1 = data[0x2200 + slot * 16 : 0x2200 + (slot + 1) * 16]
        ok0 = len(r0) == 16 and (sum(r0[:15]) & 0xFF) == r0[15]
        ok1 = len(r1) == 16 and (sum(r1[:15]) & 0xFF) == r1[15]
        if not (ok0 or ok1):
            journal.append({
                "slot": slot,
                "valid": False,
                "mirror0_valid": ok0,
                "mirror1_valid": ok1,
                "mirrors_identical": r0 == r1,
                "mirror0_checksum_stored": r0[15],
                "mirror0_checksum_calculated": sum(r0[:15]) & 0xFF,
                "mirror1_checksum_stored": r1[15],
                "mirror1_checksum_calculated": sum(r1[:15]) & 0xFF,
                "mirror0_raw_hex": hex_bytes(r0),
                "mirror1_raw_hex": hex_bytes(r1),
            })
            continue
        selected_mirror = 0 if ok0 else 1
        r = r0 if ok0 else r1
        journal.append({
            "slot": slot,
            "valid": True,
            "mirrors": "OK" if ok0 and ok1 and r0 == r1 else "DEGRADED",
            "mirror0_valid": ok0,
            "mirror1_valid": ok1,
            "mirrors_identical": ok0 and ok1 and r0 == r1,
            "selected_mirror": selected_mirror,
            "sequence": u16(r, 0),
            "test_id": r[2],
            "test": POKERTC_TESTS.get(r[2], f"0x{r[2]:02X}"),
            "result": r[3],
            "result_name": pokertc_result_name(r[2], r[3]),
            "selector": r[4],
            "selector_name": SELECTOR_NAMES.get(r[4], f"0x{r[4]:02X}"),
            "expected": r[5],
            "actual": r[6],
            "probe_before": r[7],
            "probe_after": r[8],
            "fault_bank": r[9],
            "fault_address": (r[11] << 8) | r[10],
            "aux0": r[12],
            "aux1": r[13],
            "value_map_mask": r[14],
            "checksum_stored": r[15],
            "checksum_calculated": sum(r[:15]) & 0xFF,
            "mirror0_checksum_stored": r0[15],
            "mirror0_checksum_calculated": sum(r0[:15]) & 0xFF,
            "mirror1_checksum_stored": r1[15],
            "mirror1_checksum_calculated": sum(r1[:15]) & 0xFF,
            "raw_hex": hex_bytes(r),
            "mirror0_raw_hex": hex_bytes(r0),
            "mirror1_raw_hex": hex_bytes(r1),
        })

    return {
        "family": "POKERTC",
        "format": "X7P1 / 1",
        "super": {
            "magic": "X7P1",
            "version": 1,
            "mirrors_valid": [supers[0][1], supers[1][1]],
            "mirrors_identical": supers[0][0] == supers[1][0],
            "boot": u16(s, 5),
            "errors": u16(s, 7),
            "last_test_id": s[9],
            "last_test": POKERTC_TESTS.get(s[9], f"0x{s[9]:02X}"),
            "result": s[10],
            "selector": s[11],
            "expected": s[12],
            "actual": s[13],
            "rtc": list(s[14:19]),
            "aux": [s[44], s[45]],
            "journal_sequence": seq,
            "journal_index": jidx,
        },
        "value_map": value_map,
        "pattern_audit": pattern_audit(data, "A", "POKERTC"),
        "journal": journal,
    }


def inspect_bytes(raw: bytes) -> dict[str, Any]:
    if len(raw) < SRAM_SIZE:
        raise ValueError(f"Expected at least {SRAM_SIZE} bytes of SRAM, got {len(raw)}")
    data = raw[:SRAM_SIZE]
    family = detect_family(data)
    if family is None:
        if not any(data):
            return {
                "family": "UNINITIALIZED",
                "format": "cleared / all-zero SRAM",
                "status": (
                    "SRAM is fully zeroed. This is the expected persistent state "
                    "immediately after the SELECT+START+B+A SRAM-clear "
                    "action, before re-initialization."
                ),
                "sram_bytes": SRAM_SIZE,
                "input_bytes": len(raw),
                "trailing_bytes": len(raw) - SRAM_SIZE,
            }
        raise ValueError("Unknown SRAM format: no valid X7D8/X7T1/X7P1 superblock magic found")
    result = parse_pokertc(data) if family == "POKERTC" else parse_diag_trace(data, family)
    result["sram_bytes"] = SRAM_SIZE
    result["input_bytes"] = len(raw)
    result["trailing_bytes"] = len(raw) - SRAM_SIZE
    return result


def h(v: int, width: int = 2) -> str:
    return f"0x{v:0{width}X}"


def render_text(r: dict[str, Any]) -> str:
    lines = [
        f"Family: {r['family']}",
        f"Format: {r['format']}",
        f"Input: {r['input_bytes']} bytes (SRAM {r['sram_bytes']}, trailing {r['trailing_bytes']})",
        "",
        "Superblock:",
    ]
    s = r["super"]
    for k, v in s.items():
        if k in {"rtc", "aux"} and isinstance(v, list):
            value = " ".join(f"{x:02X}" for x in v)
        elif k in {"scenario", "selector", "last_selector", "expected", "actual", "flags", "result", "fault_bank"} and isinstance(v, int):
            value = h(v)
        else:
            value = str(v)
        lines.append(f"  {k}: {value}")

    if "value_map" in r:
        lines += ["", "Value map:"]
        for row in r["value_map"]:
            vals = " ".join(f"{x:02X}" for x in row["bank_values"])
            lines.append(f"  {row['selector']:02X} <- {row['value']:02X} : {vals} mask {row['mask']:02X}")

    stats = r.get("stress_stats")
    if stats is not None:
        lines += ["", "Stress statistics:"]
        if not stats.get("valid"):
            lines.append("  no valid mirrored statistics block")
        else:
            for row in stats["entries"]:
                if row["runs"] == 0 and row["loops"] == 0 and row["ticks"] == 0:
                    continue
                timing = row["elapsed"] if row["timed"] else "not timed"
                lines.append(
                    f"  {row['test']} {row['mode']}: runs={row['runs']} "
                    f"loops={row['loops']} time={timing} raw_ticks={row['ticks']}"
                )

    pa = r["pattern_audit"]
    count = pa.get("mismatch_count", pa.get("mismatch_count_at_least", len(pa.get("mismatches", []))))
    lines += ["", f"Pattern audit: {'PASS' if pa['pass'] else 'FAIL'} ({count} mismatch{'es' if count != 1 else ''})"]
    for x in pa.get("mismatches", [])[:32]:
        lines.append(f"  bank{x['bank']}:{x['address']:04X} expected {x['expected']:02X} got {x['actual']:02X}")

    ff = r.get("first_fault")
    if ff is not None:
        lines += ["", "First-fault capsule:"]
        for k, v in ff.items():
            if k in {"scenario", "selector", "bank", "expected", "actual"} and isinstance(v, int):
                value = h(v)
            elif k == "rtc" and isinstance(v, list):
                value = " ".join(f"{x:02X}" for x in v)
            else:
                value = str(v)
            lines.append(f"  {k}: {value}")

    journal_len = len(r.get("journal", []))
    if r["family"] == "POKERTC":
        journal_label = f"Journal entries retained: {journal_len}/32 (circular; oldest overwritten after 32)"
    else:
        journal_label = f"Journal events: {journal_len}/232 (append-only; logging freezes at capacity)"
    lines += ["", journal_label]
    for row in r.get("journal", []):
        if not row.get("valid"):
            lines.append(f"  slot {row['slot']:03d}: INVALID")
            continue
        if r["family"] == "POKERTC":
            lines.append(
                f"  #{row['sequence']:04X} slot{row['slot']:02d} {row['test']} "
                f"res={row['result']:02X} sel={row['selector']:02X} "
                f"exp={row['expected']:02X} got={row['actual']:02X} "
                f"probe={row['probe_before']:02X}>{row['probe_after']:02X} "
                f"vmask={row['value_map_mask']:02X} mirrors={row['mirrors']}"
            )
        else:
            lines.append(
                f"  #{row['sequence']:04X} slot{row['slot']:03d} {row['event']} "
                f"test={row['test']} mode={row['mode']} ctx={row['context']} "
                f"reason={row['reason']} scen={row['scenario']:02X} "
                f"loops={row['loops']} elapsed={row['elapsed']} "
                f"sel={row['selector']:02X} bank={row['bank']:02X} "
                f"addr={row['address']:04X} exp={row['expected']:02X} got={row['actual']:02X} "
                f"mirrors={row['mirrors']}"
            )
    return "\n".join(lines) + "\n"


def render_html(r: dict[str, Any], source_name: str) -> str:
    payload = html.escape(json.dumps(r, indent=2, sort_keys=True))
    summary = html.escape(render_text(r))
    title = html.escape(f"X7 SRAM report — {source_name}")
    return f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<style>
body{{font-family:system-ui,-apple-system,Segoe UI,sans-serif;max-width:1100px;margin:2rem auto;padding:0 1rem;line-height:1.45}}
h1,h2{{line-height:1.15}} pre{{background:#f4f4f4;padding:1rem;overflow:auto;border-radius:.4rem}}
code{{font-family:ui-monospace,SFMono-Regular,Consolas,monospace}} details{{margin:1rem 0}}
.bad{{font-weight:700}} .meta{{color:#555}}
</style></head><body>
<h1>{title}</h1>
<p class="meta">Generated by <code>tools/inspect_sram.py</code>. No external resources are required.</p>
<h2>Decoded report</h2><pre>{summary}</pre>
<details><summary>Raw structured JSON</summary><pre>{payload}</pre></details>
</body></html>'''


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path, help="raw SRAM save/capture (for example .srm/.sav/.ram/.bin; at least 32768 bytes)")
    ap.add_argument("--format", choices=("text", "json", "html"), default="text")
    ap.add_argument("-o", "--output", type=Path, help="write report to file instead of stdout")
    args = ap.parse_args(argv)
    try:
        result = inspect_bytes(args.input.read_bytes())
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.format == "json":
        rendered = json.dumps(result, indent=2, sort_keys=True) + "\n"
    elif args.format == "html":
        rendered = render_html(result, args.input.name)
    else:
        rendered = render_text(result)

    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
        print(args.output)
    else:
        sys.stdout.write(rendered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
