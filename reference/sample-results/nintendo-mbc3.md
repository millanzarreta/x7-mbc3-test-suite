# Nintendo-documented MBC3 reference behavior

Representative expected results derived from Nintendo's documented MBC3 bank/register mapping.

Source: [Nintendo *Game Boy Programming Manual* v1.0](https://files.nekoblog.org/uploads/pdf/39999184-GameBoy-Programming-Manual.pdf), Chapter 8, sections 3.2-3.3, pp. 216-217.

```text
POKERTC VALUE MAP
08 <- 11 : MASK 00
09 <- 22 : MASK 00
0A <- 05 : MASK 00
0B <- A7 : MASK 00
0C <- 01 : MASK 00
```

DIAG-A `SIGNATURE` must leave:

```text
bank2:A000 = 14
bank3:A000 = 00
```

Gold/Silver-style POKERTC RTC_DH read/modify/write tests must update the RTC
register without changing the SRAM probe at bank0:A000.
