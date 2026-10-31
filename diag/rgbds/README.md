# DIAG RGBDS source

This directory contains the canonical maintainable RGBDS source for the shipped
**v1.0.0** ROM behavior.

Canonical build toolchain: **RGBDS 1.0.4**.

Build products are centralized at the repository root: final ROMs are written to `../../build/` and intermediate object files to `../../build/obj/`.


Build this suite:

```sh
make
make verify
```

`make verify` builds the suite and compares the result byte-for-byte with the
canonical pre-built ROM in [`../../roms/`](../../roms/).

See [`../../docs/source-guide.md`](../../docs/source-guide.md) for the source
layout and reproducibility model.
