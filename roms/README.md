# Pre-built diagnostic ROMs

This directory contains the canonical **v1.0.0** binaries. They are ready to
copy to an emulator, flash cartridge or EverDrive; recompilation is not required
for normal use.

| File | Identity | Cartridge profile | Primary purpose |
|---|---|---|---|
| `X7MBC3DIAG-A.gbc` | DIAG-A | MBC3 + TIMER + RAM + BATTERY | Broad diagnostic with Silver-matching bank-2/3 canaries. |
| `X7MBC3DIAG-B.gbc` | DIAG-B | MBC3 + TIMER + RAM + BATTERY | Independent RTC identity with different canaries. |
| `X7MBC3DIAG-N.gbc` | DIAG-N | MBC3 + RAM + BATTERY | DIAG negative control without RTC. |
| `X7MBC3TRACE-A.gbc` | TRACE-A | MBC3 + TIMER + RAM + BATTERY | Fine-grained write/selector/lifecycle tracing, primary identity. |
| `X7MBC3TRACE-B.gbc` | TRACE-B | MBC3 + TIMER + RAM + BATTERY | Same TRACE engine with independent canaries. |
| `X7MBC3TRACE-N.gbc` | TRACE-N | MBC3 + RAM + BATTERY | TRACE negative control without RTC. |
| `X7POKERTC.gbc` | POKERTC | MBC3 + TIMER + RAM + BATTERY | Minimal RTC VALUE MAP and Gold/Silver-style RTC access tests. |

## A / B / N identities

DIAG and TRACE deliberately provide parallel identities rather than sequential
versions:

```text
A canaries: A0 / B1 / 14 / 00
B canaries: A1 / B2 / 24 / 30
N canaries: A2 / B3 / 34 / 40
```

A is the primary identity; `bank2:A000=14` and `bank3:A000=00` mirror the healthy
Box 1 / Box 8 count bytes in the motivating Spanish Silver case. B uses different
starting values so an observed `08` or `0C` cannot be explained as a value already
present in A. N is the no-RTC control.

## SHA-256

```text
663ac2065d7637377b857fd2927de026c6eb73ea0dd9669cef7d36246fe0ac66  X7MBC3DIAG-A.gbc
1548c6d9de6dd4a58526249c2d96449fe3405a3af3b68d62c1ad48414bb9c4c9  X7MBC3DIAG-B.gbc
311ad9a6ebf87727767801ad0ed8a4c20b62d8293916f625c77a9b0ae38f5217  X7MBC3DIAG-N.gbc
e5dbded1457ead2901fd0748e9be3c4de37d9fddfe459baaba0ef208f53b29ef  X7MBC3TRACE-A.gbc
46073c139d7a8ffffbbdcf9abb9416d54a44d276fdc7fd644d485b0d5ea0aa71  X7MBC3TRACE-B.gbc
385592019b9f4fc14b18da35736b759c1a474d35fe0dc435eedb20cb3bae497d  X7MBC3TRACE-N.gbc
f34e1b1533a7e931780e0276267f1a0c6438d293e20824b46a90ec3f85c76f5c  X7POKERTC.gbc
```

The same list is available as [`../SHA256SUMS.txt`](../SHA256SUMS.txt).
