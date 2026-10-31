# TRACE — X7MBC3TRACE

TRACE focuses on exact mapper state and the boundary between the final controlled
MBC3 operation before leaving the ROM and the first SRAM audit on the next boot.
It also contains phase-by-phase direct tests that localize the RTC-write fault.

Its ARM flow separates:

- **PRESET** — functional preparation / final MBC3 selector state;
- **SCENARIO** — opaque user-defined metadata byte `01..FF`; it does not execute
  or imply a particular external action.

## Variants

TRACE uses the same A/B/N identity scheme as DIAG.

| Variant | Cartridge profile | A000 canaries (banks 0/1/2/3) | Purpose |
|---|---|---|---|
| **A** | MBC3 + TIMER + RAM + BATTERY | `A0 / B1 / 14 / 00` | Primary identity; bank 2/3 match the healthy Spanish Silver Box 1 / Box 8 geometry. |
| **B** | MBC3 + TIMER + RAM + BATTERY | `A1 / B2 / 24 / 30` | Independent RTC identity with different starting bytes; useful for cross-checks and A↔B lifecycle runs. |
| **N** | MBC3 + RAM + BATTERY, no timer | `A2 / B3 / 34 / 40` | No-RTC negative control. |

A and B are parallel identities, not sequential versions.

Pre-built binaries are in [`../roms/`](../roms/). Canonical source is in
[`rgbds/`](rgbds/).

Build only TRACE with:

```sh
make -C trace/rgbds
make -C trace/rgbds verify
```

Inspect current TRACE SRAM with:

```sh
python3 tools/inspect_sram.py capture.sav
```

Continuous stress tests deliberately expose both `NORMAL + TIMER` and `BARE MAX` timing profiles; they run the same logical workload under different instrumentation/timing conditions. See [`../docs/test-guide.md`](../docs/test-guide.md) for the exact distinction.

The screen is only the immediate summary; test history is accumulated in the persistent SRAM journal (up to 232 append-only events). See
[`../docs/sram-logging.md`](../docs/sram-logging.md) for journal limits and capture-file conventions.

See [`../docs/test-guide.md`](../docs/test-guide.md) for PRESET behavior and
direct-test semantics, [`../docs/test-results.md`](../docs/test-results.md) for
observed campaign results, and [`../docs/lifecycle-arm.md`](../docs/lifecycle-arm.md)
for step-by-step external ARM usage.
