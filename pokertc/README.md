# POKERTC — X7POKERTC

POKERTC is the smallest and most direct RTC characterization suite. It combines
an arbitrary-data **VALUE MAP** with small Gold/Silver MBC3-facing RTC routines so
the bus-visible sequence can be compared with behavior relevant to the motivating
game.

POKERTC intentionally has **no ARM subsystem**. Lifecycle experiments belong in
DIAG/TRACE; POKERTC is for direct RTC access tests.

The pre-built binary is [`../roms/X7POKERTC.gbc`](../roms/X7POKERTC.gbc).
Canonical source is in [`rgbds/`](rgbds/).

Build only POKERTC with:

```sh
make -C pokertc/rgbds
make -C pokertc/rgbds verify
```

The screen gives the immediate result. The SRAM save/capture keeps a persistent
32-entry circular result journal (newer results eventually replace the oldest).
Inspect it with:

```sh
python3 tools/inspect_sram.py capture.sav
```

The small Gold/Silver fragments retained for instruction/bus-sequence fidelity
are documented in [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md).
Canonical test behavior is in [`../docs/test-guide.md`](../docs/test-guide.md);
observed SameBoy/X7 results are in [`../docs/test-results.md`](../docs/test-results.md).
Persistence, journal limits and save-file conventions are documented in
[`../docs/sram-logging.md`](../docs/sram-logging.md).
