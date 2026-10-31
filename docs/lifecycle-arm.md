# ARM / lifecycle experiments

## Purpose

The direct-write tests establish that the tested X7 can reflect an RTC-selected
`A000` write into SRAM. They do **not** explain how the original Pokémon Silver
corruption happened during ordinary use.

ARM exists to test a different boundary:

> Can SRAM change while the diagnostic ROM is no longer running, across an
> EverDrive lifecycle operation such as unload/reload, a game switch, power cycle,
> console change or RTC adjustment?

The key property is that the next boot audits monitored SRAM **before the ROM resumes
ordinary RTC activity**. A fault at that boundary would therefore be fundamentally
different evidence from deliberately running `SIGNATURE`, `RTC MAP` or `VALUE MAP`
inside the diagnostic itself.

Observed campaign results are intentionally kept out of this usage document. See
[`test-results.md`](test-results.md) for what happened on the tested X7.

## The ARM boundary

Conceptually:

```text
known-good SRAM
    ↓
pre-ARM audit
    ↓
record ARMED metadata
    ↓
leave a controlled final mapper state (TRACE PRESET, when used)
    ↓
================ ARM boundary ================
    ↓
user performs an external action
    ↓
load the same armed diagnostic identity again
    ↓
boot audit before ordinary RTC activity
    ↓
EXT_PASS or FAULT
```

ARM does **not** automate the EverDrive menu, power switch, another console or RTC
settings. Those actions are performed by the user outside the diagnostic ROM.

## PRESET and SCENARIO are different things

In TRACE the ARM screen has two independent concepts.

### PRESET: functional state preparation

PRESET actually changes how TRACE leaves the mapper immediately before the external
interval.

| ID | PRESET | Final controlled state |
|---:|---|---|
| `01` | `SILVER` | Controlled read/latch preparation; finish neutral on SRAM bank 0. |
| `02` | `SELECT` | Selector-transition/latch/read preparation; finish neutral on SRAM bank 0. |
| `03` | `RTC-H` | Leave RTC selector `0A` active. |
| `04` | `RTC-DL` | Leave RTC selector `0B` active. |
| `05` | `SRAM2` | Leave SRAM bank 2 selected. |
| `06` | `SRAM3` | Leave SRAM bank 3 selected. |

The current preparation is deliberately **RTC-write-free**. TRACE first records the
ARM event and persistent metadata, then applies the requested final selector. After
the `ARMED` boundary it must not perform another MBC3/SRAM/RTC access before the
external experiment begins.

TRACE-N has no RTC and therefore provides the SRAM-selector/no-RTC control cases.

### SCENARIO: your experiment label

SCENARIO is an opaque user-defined byte `01..FF`. It performs no hardware action and
has no built-in meaning.

For example, you can decide in your lab notes that:

```text
SCENARIO 21 = power off, power on, reload same TRACE-A
SCENARIO 22 = TRACE-A -> TRACE-B -> TRACE-A
SCENARIO 23 = TRACE-A -> TRACE-N -> TRACE-A
SCENARIO 24 = move X7 to another console, then reload TRACE-A
SCENARIO 25 = adjust the X7 RTC setting, then reload TRACE-A
```

Those meanings exist only in your experiment notes. If you arm `SCENARIO 22` and
then actually perform a power cycle instead, TRACE cannot detect the mismatch; the
forensic label would simply be wrong.

DIAG's `ARM EXTERNAL` uses the same basic idea but without TRACE's functional PRESET
matrix: its SCENARIO byte is also just a user-defined tag for the external interval.

## Practical example 1: reload the same ROM after a direct power cycle

Suppose you want to know whether the state left at RTC-H can become dangerous when
the cartridge is powered off and the same ROM is loaded again.

1. Start from a clean TRACE-A SRAM state and run `RAM AUDIT`.
2. Open `ARM PRESETS` and choose `RTC-H`.
3. Choose a SCENARIO byte that your notes define as this experiment, for example
   `21`.
4. Complete ARM. TRACE records the state, leaves selector `0A` active and reaches the
   `ARMED` boundary.
5. Physically power the console off.
6. Power it on and load the **same TRACE-A ROM** again.
7. Before ordinary RTC work, TRACE-A audits its monitored SRAM.
8. Preserve the SRAM capture whether the result is `EXT_PASS` or `FAULT`; the journal
   ties the return to PRESET `RTC-H` and SCENARIO `21`.

An `EXT_PASS` says that this particular controlled interval returned with SRAM
intact. A `FAULT` would say that SRAM changed while TRACE-A was outside its controlled
execution window.

## Practical example 2: RTC game -> another RTC game -> original game

This checks the X7's save/RTC isolation between two distinct RTC identities.

```text
TRACE-A
  -> ARM PRESET RTC-DL, SCENARIO 22
  -> leave TRACE-A
  -> load TRACE-B
  -> leave TRACE-B
  -> reload TRACE-A
  -> TRACE-A boot audit
```

A and B intentionally use different ROM identities and different SRAM canaries. That
makes cross-restore/contamination easier to recognize than switching between two
identical copies of one ROM.

You can repeat the same external path with different PRESETs (`RTC-H`, `RTC-DL`,
`SRAM2`, `SRAM3`) to hold the outside action constant while changing only the mapper
state delivered to the boundary.

## Practical example 3: RTC -> no-RTC -> RTC control

Use TRACE-N as the intermediate cartridge identity:

```text
TRACE-A
  -> ARM PRESET RTC-H, SCENARIO 23
  -> leave TRACE-A
  -> load TRACE-N
  -> leave TRACE-N
  -> reload TRACE-A
  -> TRACE-A boot audit
```

This is useful alongside the A -> B -> A experiment because the middle ROM has MBC3
RAM but no timer/RTC. The pair helps separate a generic game-switch/persistence path
from behavior that specifically requires another RTC identity.

## Practical example 4: console or RTC-setting changes

ARM can also bracket actions that cannot occur while a Game Boy ROM is running:

```text
TRACE-A armed
  -> power off
  -> move the X7 to another compatible console
  -> load TRACE-A
  -> boot audit
```

or:

```text
TRACE-A armed
  -> leave the ROM
  -> use the EverDrive UI to make a controlled RTC-related adjustment
  -> reload TRACE-A
  -> boot audit
```

Again, SCENARIO only labels what you say you did. The PRESET controls the state TRACE
itself delivers to the boundary.

## Reading the result

`EXT_PASS` means only:

> the ROM was armed, later returned, and the monitored SRAM was still intact before
> ordinary RTC activity resumed.

It does **not** prove that the user performed the intended physical operation; that
part comes from the experimenter's procedure/notes.

`FAULT` means the first boot audit found a monitored SRAM change across the armed
interval. DIAG/TRACE preserve the first-fault evidence so later activity does not
replace the original bank/address/expected/actual information.

## What ARM can and cannot answer

ARM is strong at localizing a change to an **external interval**. It can compare
reloads, game changes, no-RTC controls, power behavior, console changes and RTC UI
operations while also varying TRACE's final selector state.

It cannot inspect what GBC-OS or the FPGA did internally during that interval, and a
clean return cannot prove that a rarer state/timing-dependent path is impossible.
It only establishes that the particular controlled experiment returned without a
monitored SRAM change.

For the actual campaign outcome and the conclusions drawn from many clean returns,
see [`test-results.md`](test-results.md). For the static GBC-OS save/restore path,
see [`firmware-notes.md`](firmware-notes.md).
