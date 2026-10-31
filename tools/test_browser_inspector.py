#!/usr/bin/env python3
"""Parity/self-containment checks for tools/sram_inspector.html.

If Node.js is available, the JavaScript parser embedded in the standalone HTML
is executed against the same synthetic fixtures as the Python inspector and the
complete decoded structures are compared. Without Node.js, static checks still
run and the parity portion is reported as skipped.
"""
from __future__ import annotations

import importlib.util
import json
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
HTML = HERE / "sram_inspector.html"


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    assert spec.loader
    spec.loader.exec_module(mod)
    return mod


def main() -> int:
    text = HTML.read_text(encoding="utf-8")
    required = [
        "X7D8", "X7T1", "X7P1", "POKE START RTC", "POKE STOP RTC",
        "SCENARIO", "PRESET", "SELECT+START+B+A", "FileReader" if False else "arrayBuffer",
        "Nothing is uploaded", ".ram", "Stress statistics", "Details", "CORE START", "CORE END",
    ]
    missing = [x for x in required if x not in text]
    if "http://" in text or "https://" in text:
        missing.append("standalone HTML unexpectedly contains an external URL")
    if missing:
        print("Browser inspector static check FAIL:")
        for x in missing:
            print(" -", x)
        return 1

    node = shutil.which("node")
    if not node:
        print("Browser inspector static checks PASS; Node.js not found, runtime parity SKIPPED.")
        return 0

    py = load_module("inspect_sram", HERE / "inspect_sram.py")
    fixtures = load_module("test_inspector", HERE / "test_inspector.py")
    cases = {
        "diag": fixtures.make_diag_trace("DIAG"),
        "trace": fixtures.make_diag_trace("TRACE"),
        "pokertc": fixtures.make_pokertc(),
        "cleared": bytes(0x8000),
    }

    scripts = re.findall(r"<script>(.*?)</script>", text, flags=re.S)
    if not scripts:
        print("Browser inspector runtime check FAIL: no embedded script")
        return 1

    wrapper = r'''
const fs=require('fs'), vm=require('vm');
global.window=global;
vm.runInThisContext(fs.readFileSync(process.argv[2],'utf8'));
const raw=new Uint8Array(fs.readFileSync(process.argv[3]));
process.stdout.write(JSON.stringify(X7Inspector.inspectBytes(raw)));
'''
    with tempfile.TemporaryDirectory() as td_s:
        td = Path(td_s)
        js = td / "inspector.js"
        js.write_text(scripts[-1], encoding="utf-8")
        runner = td / "runner.js"
        runner.write_text(wrapper, encoding="utf-8")
        for name, raw in cases.items():
            capture = td / f"{name}.srm"
            capture.write_bytes(raw)
            expected = py.inspect_bytes(raw)
            cp = subprocess.run(
                [node, str(runner), str(js), str(capture)],
                check=True, text=True, capture_output=True,
            )
            got = json.loads(cp.stdout)
            if got != expected:
                print(f"Browser inspector parity FAIL: {name}")
                print("Python:", json.dumps(expected, sort_keys=True))
                print("JS:    ", json.dumps(got, sort_keys=True))
                return 1
            print(f"PARITY {name}: PASS")

    print("Browser inspector runtime parity PASS for DIAG, TRACE, POKERTC and cleared SRAM.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
