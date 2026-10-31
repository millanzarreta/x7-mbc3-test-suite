# DIAG — X7MBC3DIAG

DIAG is the broad characterization suite. Use it for persistent SRAM surveillance,
stress tests, exact historical-byte reproduction, or a forensic ARM boundary
around an external lifecycle experiment.

## Variants

All three variants use the same test engine and persistent FORMAT-8 layout. They
use different cartridge identities and canaries so results from one identity can
be distinguished from another.

| Variant | Cartridge profile | A000 canaries (banks 0/1/2/3) | Purpose |
|---|---|---|---|
| **A** | MBC3 + TIMER + RAM + BATTERY | `A0 / B1 / 14 / 00` | Primary reproduction identity. `bank2:A000=14` and `bank3:A000=00` match the healthy Spanish Silver Box 1 / Box 8 count bytes. |
| **B** | MBC3 + TIMER + RAM + BATTERY | `A1 / B2 / 24 / 30` | Independent RTC identity. Different starting bytes show that observed `08/0C` results are imposed by the write sequence rather than inherited from A; also useful for A↔B lifecycle experiments. |
| **N / X7MBC3DIAG-N** | MBC3 + RAM + BATTERY, no timer | `A2 / B3 / 34 / 40` | Negative control for experiments that should not involve an RTC. |

A/B are parallel experimental identities, not versions. N is the no-RTC control.

Pre-built binaries are in [`../roms/`](../roms/). Canonical source is in
[`rgbds/`](rgbds/).

Build only DIAG with:

```sh
make -C diag/rgbds
make -C diag/rgbds verify
```

Inspect current DIAG SRAM with:

```sh
python3 tools/inspect_sram.py capture.sav
```

Continuous stress tests deliberately expose both `NORMAL + TIMER` and `BARE MAX` timing profiles; they run the same logical workload under different instrumentation/timing conditions. See [`../docs/test-guide.md`](../docs/test-guide.md) for the exact distinction.

The screen is only the immediate summary; test history is accumulated in the persistent SRAM journal (up to 232 append-only events). See
[`../docs/sram-logging.md`](../docs/sram-logging.md) for journal limits and capture-file conventions.

See [`../docs/test-guide.md`](../docs/test-guide.md) for test semantics,
[`../docs/test-results.md`](../docs/test-results.md) for the observed campaign
results, and [`../docs/lifecycle-arm.md`](../docs/lifecycle-arm.md) for practical
ARM usage.
