# RGBDS source guide

The canonical source for all seven shipped ROMs is RGBDS assembly.

## Source locations

```text
diag/rgbds/src/
trace/rgbds/src/
pokertc/rgbds/src/
```

Each suite also contains its own `Makefile` and `assets/font.bin`. The root
`Makefile` builds all three families.

The canonical release builds were produced and verified with **RGBDS 1.0.4**.

## Why A/B/N are separate sources

A/B/N are deliberately separate ROM identities with different canaries and, for
N, a different no-timer cartridge profile. Keeping their entry sources separate
also makes byte-for-byte comparison of each shipped binary straightforward.

## Source style

The ASM uses:

- stable routine labels for code and data;
- symbolic labels for strings, tables and font data;
- comments at major MBC3, RTC, SRAM, forensic, ARM and test entry points;
- a small shared `common/rgbds/hardware.inc` for hardware addresses;
- ordinary RGBDS SM83 syntax;
- explicit fixed ROM sections for deterministic layout.

The cartridge header is authored directly and `rgbfix -v` calculates the header
and global checksums. A sentinel byte in ROM bank 127 forces the intended 2 MiB
ROM size; `rgblink -p 0xFF` reproduces the erased-ROM fill.

## Build

Build one family:

```sh
make -C diag/rgbds
make -C trace/rgbds
make -C pokertc/rgbds
```

Build everything:

```sh
make
```

All generated files are centralized at the repository root:

```text
build/
├── X7MBC3DIAG-A.gbc
├── X7MBC3DIAG-B.gbc
├── X7MBC3DIAG-N.gbc
├── X7MBC3TRACE-A.gbc
├── X7MBC3TRACE-B.gbc
├── X7MBC3TRACE-N.gbc
├── X7POKERTC.gbc
└── obj/
    └── *.o
```

The source-suite directories do not receive generated `build/` subdirectories.
`make clean` from the repository root removes the complete generated `build/` tree.

Then compare actual RGBDS output byte-for-byte against the pre-built ROMs in
`roms/`:

```sh
make verify-build
```

## Independent source check

`tools/validate_rgbds_transcription.py` independently parses the restricted ASM
subset used by these sources and reconstructs each ROM without invoking RGBDS.
The reconstructed bytes must match the corresponding file in `roms/`.

This complements `verify_rgbds_build.py`: one checks the source representation
independently, while the other checks the real RGBDS toolchain output.
