# Common support

Shared project-local support lives here.

- [`rgbds/hardware.inc`](rgbds/hardware.inc) — the small set of MBC/IO constants
  shared by the canonical ASM sources.
- [`rgbds/README.md`](rgbds/README.md) — notes on the deliberately minimal shared
  layer.

The suites keep most routines local so their validated binaries remain easy to
compare independently.
