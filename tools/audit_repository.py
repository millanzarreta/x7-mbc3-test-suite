#!/usr/bin/env python3
"""Static consistency checks for the public repository."""
from pathlib import Path
import hashlib
import re
import sys

ROOT = Path(__file__).resolve().parents[1]

EXPECTED_ROMS = {
    "roms/X7MBC3DIAG-A.gbc": "663ac2065d7637377b857fd2927de026c6eb73ea0dd9669cef7d36246fe0ac66",
    "roms/X7MBC3DIAG-B.gbc": "1548c6d9de6dd4a58526249c2d96449fe3405a3af3b68d62c1ad48414bb9c4c9",
    "roms/X7MBC3DIAG-N.gbc": "311ad9a6ebf87727767801ad0ed8a4c20b62d8293916f625c77a9b0ae38f5217",
    "roms/X7MBC3TRACE-A.gbc": "e5dbded1457ead2901fd0748e9be3c4de37d9fddfe459baaba0ef208f53b29ef",
    "roms/X7MBC3TRACE-B.gbc": "46073c139d7a8ffffbbdcf9abb9416d54a44d276fdc7fd644d485b0d5ea0aa71",
    "roms/X7MBC3TRACE-N.gbc": "385592019b9f4fc14b18da35736b759c1a474d35fe0dc435eedb20cb3bae497d",
    "roms/X7POKERTC.gbc": "f34e1b1533a7e931780e0276267f1a0c6438d293e20824b46a90ec3f85c76f5c",
}

EXPECTED_TITLES = {
    "roms/X7MBC3DIAG-A.gbc": "X7MBC3DIAG-A",
    "roms/X7MBC3DIAG-B.gbc": "X7MBC3DIAG-B",
    "roms/X7MBC3DIAG-N.gbc": "X7MBC3DIAG-N",
    "roms/X7MBC3TRACE-A.gbc": "X7MBC3TRACE-A",
    "roms/X7MBC3TRACE-B.gbc": "X7MBC3TRACE-B",
    "roms/X7MBC3TRACE-N.gbc": "X7MBC3TRACE-N",
    "roms/X7POKERTC.gbc": "X7POKERTC",
}

REQUIRED = [
    "README.md", "LICENSE", "THIRD_PARTY_NOTICES.md", "SHA256SUMS.txt",
    "docs/test-guide.md", "docs/test-results.md", "docs/sram-logging.md", "docs/lifecycle-arm.md", "docs/tested-environment.md",
    "tools/sram_inspector.html", "tools/inspect_sram.py",
]



def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    errors=[]
    for rel in REQUIRED:
        if not (ROOT/rel).exists(): errors.append(f"missing required file: {rel}")

    timer_roms={
        "roms/X7MBC3DIAG-A.gbc", "roms/X7MBC3DIAG-B.gbc",
        "roms/X7MBC3TRACE-A.gbc", "roms/X7MBC3TRACE-B.gbc",
        "roms/X7POKERTC.gbc",
    }
    for rel, expected in EXPECTED_ROMS.items():
        p=ROOT/rel
        if not p.exists(): errors.append(f"missing ROM: {rel}"); continue
        data=p.read_bytes()
        got=hashlib.sha256(data).hexdigest()
        if got != expected: errors.append(f"ROM hash changed: {rel}: {got}")
        if len(data) != 2*1024*1024:
            errors.append(f"unexpected ROM size: {rel}: {len(data)}")
        expected_type=0x10 if rel in timer_roms else 0x13
        if data[0x147] != expected_type:
            errors.append(f"unexpected cartridge type: {rel}: {data[0x147]:02X}")
        if data[0x148] != 0x06 or data[0x149] != 0x03:
            errors.append(f"unexpected ROM/RAM size header: {rel}: {data[0x148]:02X}/{data[0x149]:02X}")
        title=data[0x134:0x143].split(b"\0",1)[0].decode("ascii", "replace")
        if title != EXPECTED_TITLES[rel]:
            errors.append(f"unexpected cartridge title: {rel}: {title!r}")
        h=0
        for b in data[0x134:0x14D]: h=(h-b-1)&0xFF
        if data[0x14D] != h:
            errors.append(f"header checksum invalid: {rel}")
        g=(sum(data[:0x14E])+sum(data[0x150:]))&0xFFFF
        stored=(data[0x14E]<<8)|data[0x14F]
        if stored != g:
            errors.append(f"global checksum invalid: {rel}: {stored:04X}!={g:04X}")

    # Validate relative Markdown links between repository documents/files.
    link_re = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
    for doc in ROOT.rglob("*.md"):
        text=doc.read_text(errors="ignore")
        for target in link_re.findall(text):
            target=target.strip()
            if not target or target.startswith(("http://", "https://", "mailto:", "#")):
                continue
            clean=target.split("#",1)[0]
            if not clean:
                continue
            dest=(doc.parent/clean).resolve()
            try:
                dest.relative_to(ROOT.resolve())
            except ValueError:
                errors.append(f"Markdown link escapes repository: {doc.relative_to(ROOT)} -> {target}")
                continue
            if not dest.exists():
                errors.append(f"broken Markdown link: {doc.relative_to(ROOT)} -> {target}")

    # Public tree hygiene.
    for p in ROOT.rglob("*"):
        rel=p.relative_to(ROOT).as_posix()
        if "__pycache__" in p.parts or p.suffix == ".pyc":
            errors.append(f"cache artifact present: {rel}")
        if p.is_dir() and p.name == "build" and p != ROOT / "build":
            errors.append(f"unexpected nested build directory present: {rel}")
        if p.is_file() and p.suffix.lower() == ".zip":
            errors.append(f"nested ZIP artifact present: {rel}")
    # If a local root build exists, it must contain only the expected generated artifacts.
    build_root = ROOT / "build"
    if build_root.exists():
        expected_build_files = {f"build/{Path(rel).name}" for rel in EXPECTED_ROMS}
        expected_build_files |= {
            "build/obj/X7MBC3DIAG-A.o",
            "build/obj/X7MBC3DIAG-B.o",
            "build/obj/X7MBC3DIAG-N.o",
            "build/obj/X7MBC3TRACE-A.o",
            "build/obj/X7MBC3TRACE-B.o",
            "build/obj/X7MBC3TRACE-N.o",
            "build/obj/X7POKERTC.o",
        }
        actual_build_files = {
            p.relative_to(ROOT).as_posix() for p in build_root.rglob("*") if p.is_file()
        }
        unexpected_build = sorted(actual_build_files - expected_build_files)
        if unexpected_build:
            errors.append(f"unexpected generated build artifacts: {unexpected_build}")

    gbc=[p.relative_to(ROOT).as_posix() for p in ROOT.rglob("*.gbc") if "build" not in p.parts]
    if sorted(gbc) != sorted(EXPECTED_ROMS):
        errors.append(f"unexpected shipped .gbc inventory: {sorted(gbc)}")

    # Root README must directly link every maintained Markdown file except itself.
    readme=(ROOT/"README.md").read_text()
    md_files=[]
    for p in ROOT.rglob("*.md"):
        if p == ROOT/"README.md": continue
        if any(part == "build" for part in p.parts): continue
        md_files.append(p.relative_to(ROOT).as_posix())
    for rel in sorted(md_files):
        if f"({rel})" not in readme:
            errors.append(f"README.md does not link Markdown document: {rel}")

    # Unique cartridge identifiers and mutable usage counters are intentionally omitted.
    public_text="\n".join(
        p.read_text(errors="ignore") for p in ROOT.rglob("*.md")
    )
    if re.search(r"(?mi)^\s*SN\s*:", public_text): errors.append("published SN field found")
    if re.search(r"(?mi)^\s*Pwr\s+cntr\s*:", public_text): errors.append("published power-counter field found")

    inspector_html=(ROOT/"tools/sram_inspector.html").read_text(errors="ignore")
    for required_text in ("Stress statistics", "Expand any slot", "Superblock / current state"):
        if required_text not in inspector_html:
            errors.append(f"browser inspector missing expected UI feature text: {required_text}")
    for ext in (".srm", ".sav", ".ram", ".bin"):
        if ext not in inspector_html:
            errors.append(f"browser inspector does not advertise supported SRAM capture extension: {ext}")

    # The renamed DIAG no-RTC identity should not leave stale public/source naming behind.
    for p in ROOT.rglob("*"):
        if not p.is_file() or p.suffix.lower() in {".gbc", ".bin", ".png", ".jpg", ".jpeg"}:
            continue
        try:
            text=p.read_text(errors="strict")
        except (UnicodeDecodeError, OSError):
            continue
        stale_names=("X7RAM" + "-NORTC", "X7RAM" + "NORTC")
        if any(name in text for name in stale_names):
            errors.append(f"stale DIAG-N name found: {p.relative_to(ROOT)}")

    # Hash list must match the canonical ROM set.
    sums=(ROOT/"SHA256SUMS.txt").read_text()
    for rel, expected in EXPECTED_ROMS.items():
        if f"{expected}  {rel}" not in sums:
            errors.append(f"SHA256SUMS missing canonical entry: {rel}")

    if errors:
        print("Repository audit FAILED:")
        for e in errors: print(" -", e)
        return 1
    print(f"Repository audit PASS: {len(EXPECTED_ROMS)} ROM hashes valid; {len(md_files)} Markdown documents indexed from README; public tree consistency checks passed.")
    return 0

if __name__ == "__main__":
    sys.exit(main())
