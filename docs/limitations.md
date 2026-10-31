# Limitations and non-claims

This project deliberately uses narrow claims.

## One tested X7 is not every X7

The RTC-to-SRAM alias was characterized on one physical EverDrive-GB X7:
Model 17 Rev.E (PCB 28.07.2021), FPGA 07, GBC-OS 1.06. See
[`tested-environment.md`](tested-environment.md). The repository does not claim
prevalence across all X7 units, FPGA versions or OS revisions.

## Historical trigger remains unknown

The diagnostic suite reproduces the underlying alias and the exact two-byte
Spanish Silver transformation. It has **not** reproduced the original ordinary-use
event end-to-end.

Therefore do not state that:

- the exact historical corruption has been fully reproduced;
- GBC-OS restore is proven to be the original trigger;
- a specific power cycle, game switch or RTC-setting action is known to cause it.

## ARM negative results narrow the possibilities

The ARM/lifecycle experiments were specifically designed to detect SRAM changes
that occur while the diagnostic ROM is outside its controlled execution boundary.
Reloads, RTC/no-RTC game transitions, power cycles, console changes, manual
RTC-related adjustments and multiple final selector states all returned cleanly
in the recorded campaigns.

This is strong evidence against the **simple deterministic** theory that one of
those tested actions is sufficient by itself to cause the historical corruption.
It also shows that GBC-OS RTC restore cannot simply alias bank 2/3 on every normal
restore under the tested conditions.

It does **not** prove that firmware/RTC synchronization can never participate in
a rarer state-dependent trigger. See [`test-results.md`](test-results.md) for the recorded campaign,
[`lifecycle-arm.md`](lifecycle-arm.md) for the method, and
[`firmware-notes.md`](firmware-notes.md) for the static firmware path.

## Game-specific findings are not the mapper proof

The Spanish Silver case supplies a highly specific motivating signature and
forensic history. The mapper claim stands on purpose-built ROM behavior, not on
assuming that a damaged game save alone proves a hardware bug.

## Normal Gold/Silver RTC code does not explain Box 1 / Box 8 by itself

The analyzed Spanish Silver paths read all RTC registers but the normal RTC
writes of interest target Day High (`0C`) for HALT/carry handling. Under the
observed alias that maps to SRAM bank 0, not Box 1 / Box 8. No ordinary `0A`/`0B`
write route was identified that directly explains the historical pair.

## No electrical/FPGA implementation proof

The observed mapping is compatible with incomplete selector decoding such as
`selector & 3`, and evidence supports a duplicate-write interpretation. Without
FPGA source or a hardware bus trace, the project describes the observed logical
behavior rather than claiming the exact HDL or gate-level defect.

## Firmware analysis is static

Addresses/names in [`firmware-notes.md`](firmware-notes.md) come from static
analysis of one GBC-OS v1.06 binary. They are descriptive labels, not vendor
symbols, and do not establish behavior of other firmware versions.

## POKERTC contains small game-derived fragments

Those fragments are retained for instruction/bus-sequence fidelity and are called
out in [`../THIRD_PARTY_NOTICES.md`](../THIRD_PARTY_NOTICES.md). The repository
does not distribute a complete commercial ROM or the user's private Pokémon saves.

## Release scope

The shipped ROM set identifies itself as `v1.0.0`. It is the only ROM set
included in this repository. The published binaries are intended to remain
byte-stable for this release; any later ROM behavior change should use a new
version and be validated explicitly.
