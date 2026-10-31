# GBC-OS v1.06 notes relevant to SRAM / RTC

This is a focused static-analysis note, not a general firmware reverse-engineering
project. Names below are descriptive labels assigned during analysis; the binary
does not contain those symbols.

## Analyzed image

```text
GBCOS.BIN size   81,920 bytes (0x14000)
SHA-256          c61824768584b01f7fabe290eccc5dd9e10d78c49cc948a9addba1fb86204635
```

The image was identified as the GBC-OS v1.06 firmware image used on the tested
EverDrive-GB X7. The exact cartridge/FPGA/OS configuration is recorded in
[`tested-environment.md`](tested-environment.md).

## Launch / save-restore ordering

The relevant launch/change path was reconstructed as:

```text
0x183E  call 0x6340   save SRAM / .srm
0x185F  call 0x66CF   save RTC / .rtc

... ROM preparation ...

0x1917  call 0x647D   restore SRAM / .srm
0x191F  call 0x676A   restore RTC / .rtc

... additional setup ...

0x1A86  call 0x67D4   RTC synchronization / post-processing
```

The important ordering fact is that game SRAM is restored **before** the game's
RTC state. That creates a theoretical window in which a faulty RTC-programming
path could affect already-restored SRAM before the game starts.

## `.rtc` representation

Observed X7 `.rtc` files are 512 bytes. Static analysis indicates that the
meaningful RTC state is held in two groups of five bytes; the remainder of the
sector-sized file is padding/unused for this purpose.

A lower routine around `0x5B2C` was reconstructed conceptually as:

```text
for index = 0..4:
    BD13 = index
    BD10 = rtc[index]
    BD11 = rtc[index + 5]
```

The index mapping is strongly consistent with the five MBC3 RTC registers:
Seconds, Minutes, Hours, Day Low, Day High. Initialization behavior using `0x40`
at index 4 further supports the Day-High interpretation because bit 6 is MBC3's
HALT flag.

## Internal interface vs CPU MBC3 writes

GBC-OS does **not** need to execute the same CPU-visible sequence as a game:

```text
[4000] = 0A
[A000] = hour
```

Instead, the restore/synchronization path programs internal X7 hardware registers
such as `BD10`, `BD11` and `BD13`. The suspected boundary is therefore:

```text
GBC-OS
  -> X7 internal RTC interface
  -> FPGA/core MBC3/RTC implementation
  -> emulated cartridge state
```

This matters because the diagnostic ROM demonstrates a CPU-visible RTC-to-SRAM
alias, while a possible historical restore trigger would travel through a
firmware/internal-hardware path.

## What the firmware analysis does and does not show

### Demonstrated by static analysis

- `.srm` restore precedes `.rtc` restore in the identified launch path.
- GBC-OS programs logical RTC indices through an internal X7 register interface.
- The `.rtc` restore path is separate from a simple bulk copy into the 32 KiB
  cartridge SRAM; no trivial 512-byte `.rtc`-over-`.srm` overflow was identified.

### Plausible but not demonstrated

A special FPGA/core state during internal RTC restore/synchronization could, in
principle, expose the same incomplete SRAM/RTC decode demonstrated by the CPU
MBC3 tests.

### Evidence against a simplistic theory

Extensive TRACE/DIAG ARM returns were clean across game switching, no-RTC
controls, power cycles, console switching and manual RTC-related experiments. If
**every** GBC-OS RTC restore deterministically wrote RTC indices 2/3 into SRAM
banks 2/3, those tests should have detected it. They did not.

Therefore the repository does **not** claim:

> “GBC-OS restore always causes the corruption.”

The clean ARM campaigns make that simple theory unlikely: ordinary tested
reloads, game transitions and RTC-related adjustments were not sufficient to
produce the historical effect. At most, firmware restore/synchronization remains
a candidate context for a rarer state-dependent trigger that has not been
reproduced end-to-end. See [`test-results.md`](test-results.md) for the campaign evidence and
[`lifecycle-arm.md`](lifecycle-arm.md) for ARM mechanics.
