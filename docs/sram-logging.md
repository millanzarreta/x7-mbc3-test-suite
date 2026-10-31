# SRAM persistence, journals and capture files

The diagnostic ROMs use their 32 KiB cartridge SRAM as a persistent forensic
record. The on-screen result is intentionally concise; the SRAM state is the
place to look when a complete campaign needs to be reconstructed or compared.

## Screen output and persistent state are different views

During a test, the screen reports the immediate outcome: for example `PASS`,
`SRAM FAULT`, `RTC->SRAM ALIAS`, a selector/mask, or the first relevant
expected/actual values. This is useful while operating the ROM, but it is not the
complete record.

The persistent SRAM contains additional state such as:

- mirrored metadata/superblocks;
- boot/error/campaign counters and current/last-result fields;
- DIAG/TRACE accumulated stress statistics by test/mode (runs, loops and stored timer ticks);
- deterministic monitored SRAM patterns and canaries;
- a persistent event or result journal;
- DIAG/TRACE first-fault information, preserved separately from later/current
  results;
- TRACE PRESET/SCENARIO state when applicable;
- POKERTC's latest VALUE MAP data.

For a hardware investigation, preserve the SRAM capture even when the screen
already appears conclusive. The inspectors expose more context than the ROM can
comfortably display on a Game Boy screen.

## Incremental logging

A normal test does **not** clear previous test history. Reboots and later tests
continue from the existing diagnostic state, and new journal records are added
according to the suite's policy.

| Suite | Journal behavior | Capacity | When capacity is reached |
|---|---|---:|---|
| **DIAG** | Mirrored, append-only event journal | 232 events | Existing events are preserved; the ROM marks the journal full and freezes further logging instead of overwriting old events. |
| **TRACE** | Mirrored, append-only event journal | 232 events | Same policy as DIAG: logging is frozen rather than wrapping over earlier evidence. |
| **POKERTC** | Mirrored circular result journal | 32 results | The next result reuses the oldest slot, so the journal always retains the newest 32 results. |

DIAG/TRACE journal entries are **events**, not necessarily one entry per menu
selection: a test or ARM workflow can emit more than one event (for example
start/pass/fault or arm/return activity). POKERTC records compact per-test result
entries.

The current/last-result fields are naturally updated by later operations even
when older journal entries remain available. In POKERTC, the dedicated VALUE MAP
area represents the latest VALUE MAP run; the circular journal preserves only
the newest 32 result records overall.

## Clearing the diagnostic history

On an interactive input screen, hold:

```text
SELECT + START + B + A
```

for roughly half a second. The ROM zeros all 32 KiB of diagnostic SRAM, displays
`SRAM CLEARED / RTC NOT TOUCHED / RESTART REQUIRED`, and stops until restart.
The RTC is deliberately left unchanged.

After that clear, the SRAM is all zero until the ROM is restarted and initialized
again. An ordinary reboot, power cycle, or running another test does **not** erase
the journal. The explicit SRAM clear (or deleting/replacing the environment's
save file before initialization) is the intentional way to begin a genuinely
fresh diagnostic campaign. Preserve a copy of the previous SRAM capture first if
its history is important.

## File extensions are only conventions

Different emulators, flash cartridges and tools use different names for raw save
RAM. Common examples include:

```text
.srm
.sav
.ram
.bin
```

The project therefore refers to these generically as **SRAM save/capture files**.
The extension by itself does not identify the internal format.

The supplied inspectors expect at least 32768 bytes and treat the **first 32 KiB**
as cartridge SRAM. Extra trailing bytes are reported separately rather than
parsed as diagnostic SRAM. This accommodates captures such as emulator saves
that append RTC-specific data after the SRAM image.

A file format that places a header or unrelated metadata **before** the 32 KiB
SRAM image is not automatically handled just because it uses one of the example
extensions; such a file would need the raw SRAM portion extracted first.

## Inspecting a capture

Browser, fully offline:

```text
tools/sram_inspector.html
```

Command line:

```sh
python3 tools/inspect_sram.py capture.sav
python3 tools/inspect_sram.py capture.sav --format json > capture.json
python3 tools/inspect_sram.py capture.sav --format html -o capture.html
```

Both inspectors auto-detect DIAG `X7D8/8`, TRACE `X7T1/2`, POKERTC `X7P1/1`,
and the all-zero post-clear state. The browser report additionally presents the
DIAG/TRACE accumulated stress statistics and expandable journal slots. Expanding
a slot exposes all fields persisted by that journal format, including loop/timing
metadata where available, mirror/checksum status and raw bytes from both mirrored
copies.
