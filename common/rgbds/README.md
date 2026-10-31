# Shared RGBDS support

`hardware.inc` defines the small set of mapper/hardware address constants shared
by the canonical RGBDS sources. It is project-authored and is not a vendored copy
of upstream `gbdev/hardware.inc`.

Each suite keeps its own validated font binary in `rgbds/assets/` because
POKERTC's asset differs from DIAG/TRACE.
