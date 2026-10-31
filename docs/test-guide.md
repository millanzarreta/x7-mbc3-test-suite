# Test guide

This document explains **what the current v1.0.0 tests do**, how to operate them,
and what `PASS`, `FAIL`, `FAULT`, `ALIAS` and `EXT_PASS` mean. It intentionally
does **not** describe the results of the project's hardware campaign; those are kept
separately in [`test-results.md`](test-results.md).

For persistent logging, journal limits and save/capture-file handling, see
[`sram-logging.md`](sram-logging.md). For the ARM boundary mechanism itself, see
[`lifecycle-arm.md`](lifecycle-arm.md).

## Outcome vocabulary

A result on the screen is a verdict about the invariant checked by that test, not a
verdict about whether the diagnostic ROM is functioning correctly.

| Result | Meaning |
|---|---|
| `PASS` | The invariant expected from a correct MBC3 RTC/SRAM bank/register mapping was preserved. |
| `FAIL` / `FAULT` | A monitored invariant was violated; DIAG/TRACE preserve first-fault details such as bank, address, expected and actual values. |
| `ALIAS` | POKERTC's explicit name for a detected RTC-selected write that was also observed in SRAM. |
| `EXT_PASS` | An armed external/lifecycle interval completed and the next boot found monitored SRAM intact before ordinary RTC activity resumed. |

For a deliberate RTC-write positive-control test, `FAULT`/`ALIAS` is the **positive
detection** the test was designed to capture. For a baseline SRAM/read-only control,
a fault instead indicates an unexpected failure of that control.

## NORMAL, BARE MAX and BARE FIXED

Continuous stress tests are available with deliberately different execution timing.
The modes are complementary; `BARE` is not simply a faster replacement for
`NORMAL`.

| Mode | Instrumentation | Stop condition | Why it exists |
|---|---|---|---|
| `NORMAL + TIMER` | Uses the Game Boy timer, periodic interrupts and a live `TIME`/`LOOPS` display. The timer is internal to the Game Boy and does not use the cartridge RTC. | Manual stop or configured timed phase. | Gives real elapsed-time metrics and exercises the mapper under a slightly more interrupted/variable CPU timing pattern. |
| `BARE MAX` | No live timer/HUD during the stress loop and no timer interrupts used for measurement; almost all CPU time goes to the workload. Loops are still counted. | Manual stop with `B`, or immediate fault. | Maximizes operation rate and minimizes measurement interference. |
| `BARE FIXED` | Same no-timer/no-live-HUD principle as BARE, but the loop compares its counter with a precomputed target. | Automatic stop at the target loop count. | Lets an automated/master run include a BARE-like phase without introducing periodic timer interrupts. |

`NORMAL + TIMER` and `BARE MAX` intentionally execute the same logical stress under
different timing conditions. A timing-sensitive defect could therefore appear in one
mode and not the other. `BARE FIXED` exists for automation; it is not a different
mapper operation.

# DIAG

DIAG is the broad characterization suite. A and B run the same test engine with
different identities/canaries; N is the no-RTC control.

## RAM AUDIT

Checks the deterministic monitored SRAM pattern and canaries.

**PASS:** every monitored byte matches the expected state.

**FAIL:** SRAM already differs from the expected diagnostic state. On a freshly
initialized baseline this is unexpected; after a deliberate alias test or an armed
external experiment it can be valuable evidence.

## BANK STRESS

Exercises ordinary SRAM-bank selectors `00..03` while repeatedly checking monitored
SRAM. It is a control for general RAM-banking instability and does not require RTC
data writes.

**PASS:** normal SRAM banking remained coherent for the run.

**FAIL:** ordinary bank selection/read/write behavior itself changed monitored SRAM,
which would point to a broader issue than the RTC-selected write path.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## SIGNATURE

The historical-effect reproducer. On RTC variants it performs legal MBC3 RTC writes:

```text
RTC_H  selector 0A <- 08
RTC_DL selector 0B <- 0C
```

DIAG-A starts with the motivating Silver-compatible canaries:

```text
bank2:A000 = 14
bank3:A000 = 00
```

DIAG-B uses different starting bytes at those locations (`24 / 30`) so the final
written values cannot be explained by A's initial state.

**PASS:** both writes affected the selected RTC registers only; monitored SRAM stayed
unchanged.

**FAULT:** SRAM changed while the RTC write sequence was active. This is a positive
detection of the bug class the test was designed to reproduce.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## RTC MAP

Writes all five standard MBC3 RTC selectors and audits SRAM around the sequence.
DIAG uses diagnostic values including `11`, `22`, `08`, `0C`, `00`; POKERTC's
`VALUE MAP` is the cleaner per-selector arbitrary-data characterization.

**PASS:** RTC writes did not alter SRAM.

**FAULT:** one or more RTC-selected writes altered monitored SRAM.

## RTC STRESS

Repeatedly performs legal RTC writes/reads/latches while auditing SRAM. It applies
sustained pressure to the same general write path characterized by `RTC MAP`.

**PASS:** monitored SRAM stayed isolated from RTC writes throughout the run.

**FAULT:** an RTC write was observed in monitored SRAM.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## LATCH STRESS

Repeatedly latches the RTC, selects RTC registers and reads them, while avoiding RTC
data writes. It is the main read/selection control against the write-heavy tests.

**PASS:** latch/selection/read activity did not modify monitored SRAM.

**FAULT:** read-side RTC activity alone changed SRAM.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## MASTER RUN

Automates the continuous DIAG stress phases for a configured number of minutes and
cycles. It alternates timed `NORMAL` phases with no-timer `BARE FIXED` phases and
persists progress between phases.

`MASTER RUN` has no independent mapper verdict: a failure belongs to the phase that
was running when the fault occurred.

## ARM EXTERNAL

Creates a forensic boundary around an experiment the user performs **outside** the
ROM. DIAG stores an opaque `SCENARIO` byte as a user-defined label; it does not know
or enforce what physical action that number represents.

On the next boot, SRAM is audited before normal RTC activity resumes.

**EXT_PASS:** monitored SRAM remained intact across the external interval.

**FAULT:** SRAM changed while the ROM was outside its controlled execution window.

See [`lifecycle-arm.md`](lifecycle-arm.md) for practical usage examples and TRACE's
more controlled PRESET system.

## VIEW RTC

Displays RTC S/M/H/DL/DH through the normal read/latch path. It is a utility/read-side
observation, not a write-alias test.

## STATUS

Displays persistent diagnostic state, counters and journal information. It reports
evidence but does not itself exercise the mapper.

# TRACE

TRACE is designed to localize the first operation that changes SRAM and to create
more controlled ARM boundaries than DIAG.

## RAM AUDIT

Same purpose as DIAG: verifies the current monitored SRAM baseline before another
experiment begins.

## SILVER TRACE

Separates the historical `0A<-08 / 0B<-0C` sequence into auditable phases:

```text
phase 1: selector 0A -> write 08 -> audit SRAM
phase 2: selector 0B -> write 0C -> audit SRAM
phase 3: latch / RTC reads       -> audit SRAM
```

**PASS:** all phases completed without monitored SRAM changing.

**FAULT:** the first changing phase is captured, allowing the write/selector that
first caused the problem to be distinguished from later operations.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## SELECT TRACE

Exercises the selector geometry associated with the motivating case without writing
RTC data. It includes direct transitions around:

```text
SRAM bank 2 <-> RTC-H  (0A)
SRAM bank 3 <-> RTC-DL (0B)
```

plus latch/read activity and SRAM audits.

**PASS:** selector changes, latch and reads alone were insufficient to modify SRAM.

**FAULT:** the selection/read path itself changed monitored SRAM.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## RTC TRACE

Aggressive repeated RTC-write/latch/read control retained to compare with DIAG's RTC
stress behavior, with TRACE-style fault localization.

**PASS:** no RTC-to-SRAM write effect was detected during the run.

**FAULT:** the write path altered monitored SRAM.

Manual runs offer `NORMAL + TIMER` and `BARE MAX`.

## RTC MAP

TRACE retains the legal five-selector RTC write characterization for direct
comparison with DIAG.

**PASS:** SRAM remained unchanged.

**FAULT:** an RTC-selected write changed SRAM.

## ARM PRESETS

TRACE ARM separates two concepts:

- **PRESET** is functional. It prepares a controlled mapper/RTC boundary and decides
  the final MBC3 selector state before the ROM stops touching the mapper.
- **SCENARIO** is only an opaque user-defined byte `01..FF`. It is a label for the
  external experiment you intend to perform. It does not load another ROM, power
  cycle the console, change time, or verify that you performed the action you wrote
  in your notes.

Current PRESETs:

| ID | PRESET | Final controlled state |
|---:|---|---|
| `01` | `SILVER` | Controlled read/latch preparation; finish neutral on SRAM bank 0. |
| `02` | `SELECT` | Selector-transition/latch/read preparation; finish neutral on SRAM bank 0. |
| `03` | `RTC-H` | Leave RTC selector `0A` active. |
| `04` | `RTC-DL` | Leave RTC selector `0B` active. |
| `05` | `SRAM2` | Leave SRAM bank 2 selected. |
| `06` | `SRAM3` | Leave SRAM bank 3 selected. |

The ARM preparation is deliberately RTC-write-free. The record is committed first,
then the requested final selector is applied; after the `ARMED` boundary the ROM
must not touch the MBC3 mapping registers/SRAM before the user performs the external
experiment.

**EXT_PASS:** the next boot finds monitored SRAM intact before normal RTC activity.

**FAULT:** SRAM changed during the external interval.

See [`lifecycle-arm.md`](lifecycle-arm.md) for step-by-step examples.

## VIEW RTC / STATUS

Same roles as DIAG: read-only RTC display and persistent-state inspection.

# POKERTC

POKERTC is the smallest direct RTC characterization suite. It has no ARM subsystem.

## RAM AUDIT

Checks the current deterministic SRAM canaries/patterns.

## VALUE MAP

Writes five deliberately distinct arbitrary values, one per standard RTC selector,
and audits all four SRAM banks after **each** individual write:

| RTC selector | Value written | Correct SRAM-change mask |
|---:|---:|---:|
| `08` | `11` | `00` |
| `09` | `22` | `00` |
| `0A` | `05` | `00` |
| `0B` | `A7` | `00` |
| `0C` | `01` | `00` |

Canaries are restored before the next selector, so a later write cannot hide which
bank changed for the current selector.

**PASS:** all five masks are `00`.

**ALIAS/FAIL:** at least one mask is non-zero and identifies the SRAM bank(s) changed
while that RTC selector was active.

## POKE GET CLOCK

Reproduces the MBC3-facing Spanish Silver `GetClock` read sequence: enable/latch,
read selectors `08..0C`, apply the relevant masks, then close SRAM. It does not write
RTC data registers.

**PASS:** read/latch activity completed without modifying the SRAM probe/pattern.

**FAIL:** the read-side path unexpectedly changed SRAM.

## POKE _GETCLOCK

Reproduces the relevant `_GetClock` path around RTC Day High. If HALT is set, the
routine also performs the expected controlled Silver-style SRAM bookkeeping; that
bookkeeping is not an RTC-to-SRAM alias.

**PASS:** only intended bookkeeping occurred and the RTC read path did not create an
unintended alias.

## POKE START RTC

Reproduces the Gold/Silver-style RTC_DH sequence using selector `0C`: read Day High,
clear HALT bit 6, write Day High back. POKERTC places a controlled probe at
`bank0:A000` first.

**PASS:** the SRAM probe remains unchanged.

**ALIAS/FAIL:** the RTC_DH write byte is also observed in SRAM bank 0.

## POKE STOP RTC

Reads RTC_DH, sets HALT bit 6 and writes the register back, again with a controlled
bank-0 probe.

**PASS:** the probe remains unchanged.

**ALIAS/FAIL:** the RTC_DH write byte is also reflected into SRAM bank 0.

## POKE SAVE RTC

Reproduces the relevant Silver RTC_DH carry/flag write plus the intended Silver SRAM
bookkeeping at its own address.

**PASS:** intended bookkeeping occurs but the A000 probe remains isolated from the
RTC_DH write.

**ALIAS/FAIL:** the RTC_DH write byte also replaces the A000 probe.

## POKE STARTCLOCK

Controlled composition of the relevant `_GetClock -> GetClock -> StartRTC`
MBC3/SRAM-facing sequence. Game-only logic that adds no RTC-selector access is
intentionally omitted.

**PASS:** the composite path completes without unintended SRAM alias.

**FAIL:** one of its write-side operations produced the same class of alias isolated
more directly by START/STOP/SAVE RTC.

## VIEW RTC / STATUS

Read-only RTC display and persistent-state inspection.

# Persistent formats

- DIAG: `X7D8`, format 8.
- TRACE: `X7T1`, schema/format byte 2; statistics `X7S1`, fault capsule `X7F1`.
- POKERTC: `X7P1`, version 1.

The documentation/tooling changes do not alter these persistent formats.
