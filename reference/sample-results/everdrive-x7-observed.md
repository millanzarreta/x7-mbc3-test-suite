# Observed tested-X7 signatures

These are curated summaries of previously captured hardware results, not a claim
about every EverDrive-GB X7 revision.

Reference unit: EverDrive-GB X7 Model 17 Rev.E (PCB 28.07.2021), FPGA 07,
GBC-OS 1.06. See [`../../docs/tested-environment.md`](../../docs/tested-environment.md).

## POKERTC VALUE MAP

```text
08 <- 11 -> SRAM bank0, mask 01
09 <- 22 -> SRAM bank1, mask 02
0A <- 05 -> SRAM bank2, mask 04
0B <- A7 -> SRAM bank3, mask 08
0C <- 01 -> SRAM bank0, mask 01
```

The mapping is compatible with `selector & 3` for four physical SRAM banks.

## DIAG-A SIGNATURE

```text
before:
  bank2:A000 = 14
  bank3:A000 = 00

after RTC_H 0A<-08 and RTC_DL 0B<-0C:
  bank2:A000 = 08
  bank3:A000 = 0C
```

## Read vs write distinction

TRACE's selection/latch/read-only control ran cleanly, while deliberate RTC data
writes produced the alias. POKERTC Gold/Silver-style RTC_DH write tests also
showed the selector `0C` / bank0 form of the behavior.
