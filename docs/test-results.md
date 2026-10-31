# Experimental test results

This document records the **observed campaign results** that support the project's
claims. It is intentionally separate from [`test-guide.md`](test-guide.md), which
explains how the tests work without mixing in historical outcomes.

The physical X7 results refer only to the unit documented in
[`tested-environment.md`](tested-environment.md): EverDrive-GB X7 Model 17 Rev.E,
FPGA 07, GBC-OS 1.06. SameBoy, a Game Boy / Game Boy Color emulator, was used as
a high-accuracy software comparison environment. For the operations exercised by
this suite, its recorded behavior matched Nintendo's documented RTC/SRAM selection
model. All direct mapper/RTC diagnostics used in the campaign remained clean there.

The important point is not merely which rows say PASS or FAIL. Several clean PASS
results sharply narrow the defect by showing which operations were **not** sufficient
to reproduce it, while the fault capsules identify exactly where some positive tests
first changed SRAM.

## Executive result matrix

| Suite / test | SameBoy reference | Tested X7 | Main inference |
|---|---|---|---|
| DIAG `RAM AUDIT` | PASS | PASS repeatedly | Baseline monitored SRAM was healthy before deliberate alias tests. |
| DIAG `BANK STRESS` | PASS | PASS in NORMAL and BARE | Ordinary SRAM selectors `00..03` were not sufficient to reproduce the alias. |
| DIAG `LATCH STRESS` | PASS | PASS through long runs | Latch + RTC selection + RTC reads alone were not sufficient. |
| DIAG `SIGNATURE` | PASS | **FAULT immediately** | `0A<-08` / `0B<-0C` can contaminate SRAM and reproduce the motivating byte pair. |
| DIAG `RTC MAP` | PASS | **FAULT immediately** | Legal RTC writes across `08..0C` exercise the same alias class. |
| DIAG `RTC STRESS` | PASS | **FAULT immediately** | Repeated RTC writes reproduce the same write-side defect. |
| TRACE `SILVER TRACE` | PASS | **FAULT in phase 1** | A single `0A + write 08` is sufficient; later `0B`, latch and reads are not required for the first fault. |
| TRACE `SELECT TRACE` | PASS | PASS through extensive loops | The suspect selector transitions plus latch/read activity are not sufficient without an RTC data write. |
| TRACE `RTC TRACE` / `RTC MAP` | PASS | **FAULT** in retained final X7 captures | TRACE independently reproduces the same full RTC-write selector-to-SRAM-bank pattern characterized by DIAG/POKERTC. |
| POKERTC `VALUE MAP` | masks `00,00,00,00,00` | **`01,02,04,08,01`** | All five legal RTC selectors hit SRAM banks in the observed low-two-bit pattern. |
| POKERTC `GET CLOCK` / `_GETCLOCK` | PASS | PASS in clean captures | Gold/Silver-style read-side RTC paths did not reproduce the alias. |
| POKERTC `START/STOP/SAVE RTC` | PASS | **ALIAS/FAIL** | Real Gold/Silver-style RTC_DH writes through `0C` can also overwrite SRAM bank 0. |
| ARM / lifecycle returns | EXT_PASS | **EXT_PASS throughout the recorded campaign** | Tested reload/game/power/console/RTC-adjustment operations were not sufficient deterministic triggers. |

Rows not retained as independent clean X7 captures are discussed below and are not
counted as separate hardware proofs.

## DIAG: direct characterization

### Baseline controls stayed clean

`RAM AUDIT` repeatedly passed before deliberate RTC-write tests. `BANK STRESS`
passed in both `NORMAL + TIMER` and `BARE MAX`, showing that ordinary SRAM banking
through selectors `00..03` was stable in the tested campaigns.

`LATCH STRESS` is especially important because it repeatedly performs RTC latch,
selection and reads without writing RTC data. Long runs remained clean. That result
separates the read/selection side from the write side:

```text
SRAM bank switching       -> clean in tested runs
RTC selector changes      -> clean in tested read-side runs
RTC latch                 -> clean in tested read-side runs
RTC reads                 -> clean in tested read-side runs
RTC data writes           -> alias reproduced
```

### SIGNATURE reproduced the motivating two bytes

On DIAG-A, the relevant starting canaries were:

```text
bank2:A000 = 14
bank3:A000 = 00
```

The `SIGNATURE` test performs:

```text
selector 0A <- 08
selector 0B <- 0C
```

On the tested X7 it faulted immediately and the resulting monitored bytes were:

```text
bank2:A000  14 -> 08
bank3:A000  00 -> 0C
```

That is the exact two-byte transformation that motivated the investigation.

DIAG-B began from different values and still received the RTC write data:

```text
bank2:A000  24 -> 08
bank3:A000  30 -> 0C
```

This matters because it shows that `08` and `0C` were imposed by the RTC write
sequence rather than inherited from DIAG-A's initial canaries.

### RTC MAP / RTC STRESS

`RTC MAP` and `RTC STRESS` faulted immediately on the tested X7 while remaining
clean in the recorded SameBoy reference runs. The resulting SRAM pattern was compatible
with:

```text
08 -> SRAM bank 0
09 -> SRAM bank 1
0A -> SRAM bank 2
0B -> SRAM bank 3
0C -> SRAM bank 0
```

POKERTC later provided the cleaner per-selector arbitrary-data proof described below.

## TRACE: locating the first failing operation

TRACE was useful because it audited between steps instead of only after a complete
sequence.

### SILVER TRACE

On the tested X7, both A and B faulted in **phase 1**:

```text
A:
selector   0A
bank       2
address    A000
expected   14
actual     08

B:
selector   0A
bank       2
address    A000
expected   24
actual     08
```

Phase 1 consists of the single `selector 0A -> write 08` operation followed by an
SRAM audit. Therefore the first fault did **not** require:

```text
the later selector 0B -> write 0C
an RTC latch after that write
subsequent RTC reads
```

This is one of the strongest localization results in the project: one legal RTC-H
write was sufficient to place the written byte in SRAM bank 2.

### SELECT TRACE

`SELECT TRACE` repeatedly exercised the exact selector geometry of interest,
including `2 <-> 0A` and `3 <-> 0B`, with latch/read activity but without RTC data
writes. It passed through extensive loops on the tested X7.

Combined with `SILVER TRACE`, this supports the narrower statement that selector
changes/read-side activity were not sufficient in the tested conditions; the data
write is the operation that distinguishes the failing path.

### RTC TRACE / TRACE RTC MAP

The final X7 regression captures also exercised these write-side controls.
`RTC TRACE` on TRACE-A faulted with the same full selector-to-bank pattern seen in
DIAG: bank 0/1/2/3 received `00 / 22 / 08 / 0C` from starting canaries
`A0 / B1 / 14 / 00`. `RTC MAP` on TRACE-B independently produced the corresponding
pattern from B's different canaries (`A1 / B2 / 24 / 30`).

These captures are consistent with the direct DIAG/POKERTC characterization and
provide an additional TRACE-family reproduction. They do not change the narrower
localization from `SILVER TRACE`: a single `0A <- 08` write is already sufficient
to produce the first bank-2 fault before the later `0B` write, latch or reads.

## POKERTC: per-selector mapping and Silver-style RTC_DH writes

### VALUE MAP

SameBoy produced no SRAM change for any selector:

```text
08 <- 11   mask 00
09 <- 22   mask 00
0A <- 05   mask 00
0B <- A7   mask 00
0C <- 01   mask 00
```

The tested X7 produced:

```text
08 <- 11   mask 01   -> bank 0
09 <- 22   mask 02   -> bank 1
0A <- 05   mask 04   -> bank 2
0B <- A7   mask 08   -> bank 3
0C <- 01   mask 01   -> bank 0
```

Because the data values are deliberately unrelated to the selector numbers, this
shows that the historical `08` / `0C` bytes were not special trigger values. The
selector chooses the affected SRAM bank; the written data byte can be arbitrary.

### Read-side Silver paths

`POKE GET CLOCK` and `POKE _GETCLOCK` passed in clean tested-X7 captures. Together
with DIAG `LATCH STRESS` and TRACE `SELECT TRACE`, these results provide converging
read-side controls: Gold/Silver-style latch/read activity did not by itself produce
the SRAM write alias.

### Silver-style RTC_DH writes

The direct `RTC_DH` routines did reproduce bank-0 aliasing on the tested X7:

```text
POKE START RTC   controlled probe 40 -> 00 in an isolated clean capture
POKE STOP RTC    controlled probe 00 -> 40 in an isolated clean capture
POKE SAVE RTC    probe replacement by the RTC_DH write observed in campaign data
```

The exact byte can include legitimate Day-High flag state, so the invariant is not
one universal final constant; the important observation is that the value written to
RTC_DH through selector `0C` can also replace the SRAM bank-0 probe.

`POKE STARTCLOCK` completed correctly in SameBoy. A single isolated X7 STARTCLOCK
capture is not used as primary evidence because the direct START/STOP/SAVE component
tests isolate the write behavior more cleanly.

## ARM / lifecycle campaign

ARM was deliberately aimed at a different question from the direct-write tests: can
the save change **while the diagnostic ROM is not running**, during an EverDrive
lifecycle operation?

The final consolidated campaign analysis recorded **30 TRACE-A ARM returns and 20
TRACE-B ARM returns as `EXT_PASS`, with no ARM-produced fault**. The campaign used
multiple PRESET classes and repeatedly exercised practical external operations such
as:

- returning to the same diagnostic identity;
- A -> B -> A between two independent RTC identities;
- A -> no-RTC -> A;
- direct power-off / power-on returns;
- normal exit followed by power cycling;
- moving the X7 between different Game Boy Color consoles, and also to a Game Boy Advance, before returning;
- manual RTC-related adjustment through the X7 UI;
- controlled final selector states including neutral, RTC-H (`0A`), RTC-DL (`0B`),
  SRAM bank 2 and SRAM bank 3.

On return, the boot audit ran before ordinary RTC activity and found the monitored
SRAM intact. The campaign therefore provides strong evidence against a simple
**deterministic** explanation in which one of those tested actions is by itself
sufficient to reproduce the historical Box 1 / Box 8 event.

The result is especially relevant to GBC-OS. Static analysis shows that the launch
path restores game SRAM before restoring RTC state. If every ordinary RTC restore
always misdirected logical RTC indices 2/3 into SRAM banks 2/3, the armed return audit
should have detected that behavior repeatedly. It did not.

This does **not** prove that GBC-OS, RTC synchronization or FPGA-internal RTC logic
can never participate. A rarer trigger could depend on an internal state, timing,
RTC value/rollover, sequence or condition not reproduced by the campaign. The
historical trigger therefore remains unknown.

For how ARM is constructed and how to run an experiment, see
[`lifecycle-arm.md`](lifecycle-arm.md). For the static firmware path, see
[`firmware-notes.md`](firmware-notes.md).

## What the Silver code analysis narrows

Analysis of the Spanish Silver ROM found normal read paths for all RTC registers and
normal write-side routines centered on RTC Day High (`0C`) for HALT/carry handling.
Those real write routines are enough to reproduce the `0C -> SRAM bank 0` alias in
POKERTC, but they do not explain the historical Box 1 / Box 8 pair by themselves:

```text
Box 1 first byte -> SRAM bank 2:A000 -> requires the observed 0A-class path
Box 8 first byte -> SRAM bank 3:A000 -> requires the observed 0B-class path
```

No ordinary Silver CPU path was identified that naturally performs the required
`0A`/`0B` writes corresponding to the historical pair. That makes the direct mapper
defect real but leaves the source of the original two writes unresolved.

## Combined evidence boundary

The current evidence supports the following separation:

**Demonstrated:** legal CPU-visible MBC3 RTC writes on the tested X7 can also write
SRAM; the five legal selectors map to the observed bank pattern; arbitrary data is
reflected; and `0A<-08 / 0B<-0C` reproduces the motivating two bytes exactly.

**Strongly narrowed:** ordinary SRAM banking, RTC latch/read activity and the tested
lifecycle actions were not sufficient deterministic triggers under the tested
conditions. The normal Silver write paths identified in the ROM do not by themselves
explain the bank-2/bank-3 historical pair.

**Still unknown:** what historical end-to-end condition caused the two relevant
writes to reach those box-count locations during ordinary use. A rarer
firmware/FPGA/RTC-state interaction remains a hypothesis, not a demonstrated cause.

## Public result examples

Concise text-only examples are retained in:

- [`../reference/sample-results/nintendo-mbc3.md`](../reference/sample-results/nintendo-mbc3.md)
- [`../reference/sample-results/everdrive-x7-observed.md`](../reference/sample-results/everdrive-x7-observed.md)
