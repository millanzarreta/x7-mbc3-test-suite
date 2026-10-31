# Tested hardware and firmware environment

This document identifies the exact EverDrive-GB X7 configuration on which the
RTC-to-SRAM alias described by this repository was physically characterized.
It defines the scope of the hardware claims: results from this unit should not be
silently generalized to every X7 hardware, FPGA or OS revision.

## Physical cartridge

```text
Product:   EverDrive-GB X7
Model:     17
Revision:  Rev.E
PCB date:  28.07.2021
```

The identifying serial number is intentionally not published because it does not
help reproduce or characterize the mapper behavior.

## Device Info

The X7 `Device Info` screen reported the following while the cartridge was being
used on a Game Boy Color:

```text
Cart    : ED-GB-X7
OS ver  : 1.06
FPGA ver: 07
Sys type: GBC
Asm date: 26.11.2022
Asm time: 17:28:56
```

The power counter is intentionally omitted because it is a changing usage value,
not a hardware/firmware revision identifier.

Of these fields, **FPGA ver 07** is particularly relevant when comparing results
with another X7. A future comparison should record at least the hardware revision,
FPGA version and OS version before treating two units as equivalent test targets.

## Operating system

The investigation used the official **GBC-OS v1.06** package:

<https://krikzz.com/pub/support/everdrive-gb/x-series/OS/GBC-OS-v1.06.zip>

The analyzed `GBCOS.BIN` image used during the firmware investigation was:

```text
Size:    81,920 bytes (0x14000)
SHA-256: c61824768584b01f7fabe290eccc5dd9e10d78c49cc948a9addba1fb86204635
```

See [`firmware-notes.md`](firmware-notes.md) for the focused SRAM/RTC static
analysis. The firmware binary itself is not distributed by this repository.

## Built-in EverDrive diagnostics

The X7's built-in diagnostic completed successfully on the tested unit. The
reported component tests were:

```text
ROM test...OK
RAM test...OK
CPY test...OK
SDC test...OK
RTC test...OK
```

The displayed RTC date/time values were live values and are not relevant to the
revision record, so they are not reproduced here.

The all-OK built-in diagnostic result is useful context: the unit was not failing
its normal ROM/RAM/SD/RTC self-tests when the purpose-built MBC3 diagnostics
reproduced the alias.

It is **not** a contradiction. The project's failure is observed from ROM code
using the game-visible MBC3 selector and `A000-BFFF` access path. Passing the
built-in RTC diagnostic therefore does not establish that this CPU-visible MBC3
RTC/SRAM path is correctly isolated.

## Scope of the current hardware claim

The strongest supported wording is:

> The RTC-to-SRAM alias was reproduced on an EverDrive-GB X7 Model 17 Rev.E,
> PCB date 28.07.2021, reporting FPGA 07 and running GBC-OS 1.06.

The project does **not** currently establish:

- whether every Model 17 Rev.E unit behaves the same way;
- whether FPGA revisions other than 07 are affected;
- whether other X7 PCB revisions are affected;
- whether a different GBC-OS version changes the CPU-visible behavior;
- the prevalence of the issue across the installed X7 population.

The diagnostic suite is intended to make those comparisons straightforward. When
reporting a result from another unit, record its hardware revision, FPGA version,
OS version and the exact diagnostic ROM hash.
