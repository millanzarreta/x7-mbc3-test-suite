#!/usr/bin/env python3
"""Compare RGBDS build outputs with the canonical pre-built ROMs in roms/."""
from pathlib import Path
import argparse
import hashlib
import sys

ROOT = Path(__file__).resolve().parents[1]

ROMS = [
    ("diag", "X7MBC3DIAG-A.gbc", "663ac2065d7637377b857fd2927de026c6eb73ea0dd9669cef7d36246fe0ac66"),
    ("diag", "X7MBC3DIAG-B.gbc", "1548c6d9de6dd4a58526249c2d96449fe3405a3af3b68d62c1ad48414bb9c4c9"),
    ("diag", "X7MBC3DIAG-N.gbc", "311ad9a6ebf87727767801ad0ed8a4c20b62d8293916f625c77a9b0ae38f5217"),
    ("trace", "X7MBC3TRACE-A.gbc", "e5dbded1457ead2901fd0748e9be3c4de37d9fddfe459baaba0ef208f53b29ef"),
    ("trace", "X7MBC3TRACE-B.gbc", "46073c139d7a8ffffbbdcf9abb9416d54a44d276fdc7fd644d485b0d5ea0aa71"),
    ("trace", "X7MBC3TRACE-N.gbc", "385592019b9f4fc14b18da35736b759c1a474d35fe0dc435eedb20cb3bae497d"),
    ("pokertc", "X7POKERTC.gbc", "f34e1b1533a7e931780e0276267f1a0c6438d293e20824b46a90ec3f85c76f5c"),
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--suite", choices=["diag", "trace", "pokertc"])
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()
    if not args.all and not args.suite:
        ap.error("use --suite NAME or --all")

    entries = [e for e in ROMS if args.all or e[0] == args.suite]
    failed = False
    for family, name, expected_hash in entries:
        ref = ROOT / "roms" / name
        out = ROOT / "build" / name
        if not ref.exists():
            print(f"MISSING reference roms/{name}")
            failed = True
            continue
        if not out.exists():
            print(f"MISSING {out.relative_to(ROOT)}")
            failed = True
            continue
        exact = out.read_bytes() == ref.read_bytes()
        got = sha256(out)
        ref_hash = sha256(ref)
        status = "EXACT" if exact and got == expected_hash and ref_hash == expected_hash else "DIFF"
        print(f"{status:5s} {out.relative_to(ROOT)} sha256={got}")
        if status != "EXACT":
            failed = True

    if failed:
        print("RGBDS build verification FAILED")
        return 1
    print("All selected RGBDS outputs match the canonical pre-built ROMs byte-for-byte.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
