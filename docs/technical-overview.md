# Technical overview

## Scope

This repository characterizes an MBC3 RTC/SRAM behavior observed on one tested
EverDrive-GB X7. The primary experimental question is simple:

> When an MBC3 RTC register is selected and software writes to `A000`, does the
> write reach only the RTC register, or can the same byte also reach external
> cartridge SRAM?

The suite is designed to answer that question independently of a commercial game.

The physical observations cited as "the tested X7" refer to one specific
EverDrive-GB X7 Model 17 Rev.E / FPGA 07 / GBC-OS 1.06 configuration. See
[`tested-environment.md`](tested-environment.md) for the complete identification
and built-in diagnostic result.

## Nintendo-documented MBC3 selection model

The reference behavior used by this repository is defined by Nintendo's MBC3
documentation. The *Game Boy Programming Manual* v1.0 (DMG-06-4216-001-A), Chapter
8 sections 3.2-3.3 (pp. 216-217), documents the RAM/RTC selector values and assigns
the clock counters to the `A000-BFFF` external expansion RAM area. A public mirror of the
[Nintendo *Game Boy Programming Manual* v1.0](https://files.nekoblog.org/uploads/pdf/39999184-GameBoy-Programming-Manual.pdf)
is available online.

For an MBC3 cartridge with timer and RAM, writes to the selector register at
`4000-5FFF` choose what `A000-BFFF` addresses:

```text
00 -> SRAM bank 0
01 -> SRAM bank 1
02 -> SRAM bank 2
03 -> SRAM bank 3
08 -> RTC seconds
09 -> RTC minutes
0A -> RTC hours
0B -> RTC day low
0C -> RTC day high / flags
```

With `08..0C` selected, an `A000` write is an RTC-register write. Under the
Nintendo-documented mapping it must not also modify SRAM bank 0..3.

## Observed alias on the tested X7

### Demonstrated

Purpose-built diagnostic ROMs produced a repeatable mapping compatible with:

```text
selector 08 -> SRAM bank 0
selector 09 -> SRAM bank 1
selector 0A -> SRAM bank 2
selector 0B -> SRAM bank 3
selector 0C -> SRAM bank 0
```

This is equivalent to selecting a physical four-bank SRAM using the low two bits
of the RTC selector (`selector & 3`) while the RTC path remains active.

POKERTC's VALUE MAP deliberately writes unrelated values:

```text
08 <- 11   -> bank0 changed, mask 01
09 <- 22   -> bank1 changed, mask 02
0A <- 05   -> bank2 changed, mask 04
0B <- A7   -> bank3 changed, mask 08
0C <- 01   -> bank0 changed, mask 01
```

This demonstrates that the phenomenon is not specific to the historical bytes
`08` and `0C`.

### Demonstrated negative control

SameBoy was used as a software comparison implementation rather than as the
authority for MBC3 semantics. Its behavior for these tests matches the behavior
derived from Nintendo's documented MBC3 bank/register mapping: the same tests
leave the monitored SRAM intact (`MASK 00` for VALUE MAP). Read-only
selector/latch activity also passed in the TRACE experiments; the decisive
failures occurred when the RTC-selected `A000` path was written.

### Dual-write evidence

Diagnostic `.rtc` observations support the interpretation that RTC writes still
reach the RTC while SRAM receives the same write as an unintended side effect.
The project therefore describes the result as an **RTC-to-SRAM alias / duplicate
write**, not as proof that the RTC write is replaced by an SRAM write.

## Historical signature reproducer

DIAG-A initializes:

```text
bank2:A000 = 14
bank3:A000 = 00
```

`SIGNATURE` performs legal MBC3 accesses equivalent to:

```text
select RTC hours   (0A), write 08 to A000
select RTC day low (0B), write 0C to A000
```

On the tested X7 the monitored SRAM becomes:

```text
bank2:A000 14 -> 08
bank3:A000 00 -> 0C
```

That is exactly the byte transformation found in the motivating Spanish Pokémon
Silver save. It is a strong reproduction of the *mechanism and byte effect*, not
an end-to-end reproduction of the unknown historical trigger.

## Why three suites exist

### DIAG

Broad forensic environment: deterministic SRAM patterns, canaries, stress modes,
first-fault capture, append-only journal, MASTER campaigns, signature/RTC-map
controls and ARM boundaries.

### TRACE

A narrower experiment around ordering and final mapper state. It can leave a
controlled final selector (`PRESET`) immediately after committing the ARM record,
then performs an SRAM-first boot audit when the ROM returns. `SCENARIO` is only a
user metadata tag.

### POKERTC

Small direct tests. VALUE MAP identifies selector-to-bank behavior using arbitrary
data. The Gold/Silver-style routines reproduce the MBC3-facing operations that
matter for RTC reads and `RTC_DH` read/modify/write sequences.

## Evidence classification used by this repository

| Label | Meaning |
|---|---|
| **Demonstrated** | Reproduced directly by diagnostic code and captured/verified in the experiment. |
| **Observed** | Seen in supplied hardware/save/RTC artifacts but not necessarily isolated to a single causal mechanism. |
| **Supported interpretation** | Fits multiple observations and code paths but is not independently proven at the electrical/FPGA implementation level. |
| **Hypothesis** | Plausible explanation retained for testing; must not be presented as established cause. |
| **Unknown** | No adequate reproduction or evidence currently identifies the answer. |

## Current evidence boundary

### Demonstrated

- RTC-selected writes can alter SRAM on the tested X7.
- The mapping is compatible with `08→0, 09→1, 0A→2, 0B→3, 0C→0`.
- Arbitrary data bytes can be reflected into SRAM.
- DIAG-A reproduces `bank2:A000 14→08` and `bank3:A000 00→0C` exactly.
- SameBoy does not show the alias under the same diagnostic logic.
- Gold/Silver-style `RTC_DH` write sequences can trigger the `0C→bank0` form.
- Extensive read/selection-only tests did not show the same corruption pattern.

### Lifecycle/ARM result

The ARM experiments targeted corruption that might occur while the diagnostic ROM
was not running: reloads, game switches, power cycles, console changes, RTC-related
adjustments and controlled final selector states. The recorded campaigns returned
with monitored SRAM intact. This argues strongly against those tested actions being
sufficient deterministic triggers, while leaving a rarer state-dependent
firmware/FPGA condition unresolved. See [`test-results.md`](test-results.md) for the recorded campaign and
[`lifecycle-arm.md`](lifecycle-arm.md) for how the boundary works.

### Observed / strongly supported

- The motivating Spanish Silver save records a highly localized Box 1 / Box 8
  corruption consistent with those exact bank/address/value writes.
- The game later detected the two bad box checksums and retained a `0x0081`
  history bitmap before subsequent saves recomputed the box checksums.
- X7 RTC files indicate that RTC state was also updated during diagnostic writes,
  supporting a duplicate-write interpretation.

### Unknown

- The exact historical event that caused `0A<-08` and `0B<-0C`-equivalent writes
  to reach the Box 1 / Box 8 locations during ordinary use.
- Whether a particular GBC-OS/FPGA transition can reproduce that historical event
  on demand.
- Scope across other X7 hardware/core/firmware revisions.

## Release principle

The public claim is intentionally narrower than the motivating story: **a legal
MBC3 RTC write path on the tested X7 can alias into SRAM**. The suite does not
claim that every RTC restore corrupts SRAM, that all X7 units are affected, or
that the historical Pokémon corruption has been reproduced end-to-end.
