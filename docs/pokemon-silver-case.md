# Motivating case: Spanish Pokémon Silver / Pokémon Plata

This case study explains why DIAG-A uses its unusual bank 2/3 canaries. It is not
required to reproduce the mapper bug, and the user's private game saves are not
included in this repository.

## Historical symptom

The motivating save eventually showed two contradictory PC-box states:

- Box 1 reported only 8 Pokémon even though all 20 physical Pokémon records were
  still present.
- Box 8 initially acquired a phantom count of 12 while its logical Pokémon list
  remained empty. Four later legitimate deposits were therefore written into
  physical slots 13-16 and the displayed count became 16.

Backups established that Box 8 had been genuinely empty before the corruption;
the twelve phantom entries were not lost Pokémon.

## Exact byte transition

The last clearly healthy snapshot used:

```text
Box 1 count = 0x14 (20)
Box 8 count = 0x00 (0)
```

The corrupted state introduced:

```text
Box 1 count = 0x08 (8)
Box 8 count = 0x0C (12)
```

In the `.srm` / MBC3 geometry these are exactly:

```text
bank2:A000  14 -> 08   Box 1 count
bank3:A000  00 -> 0C   Box 8 count
```

Within each box's logical data region, the initial corruption was localized to
the count byte. Later game saves also updated the per-box checksum bytes, as
expected after the game had accepted the already-corrupted counts.

## Spanish box layout

The Spanish ROM uses `0x44E` logical box bytes plus a two-byte little-endian box
checksum, for a physical stride of `0x450`:

```text
+0000  count
+0001  species list (21 bytes including terminator)
+0016  20 x 32-byte Pokémon structures
+0296  OT names
+0372  nicknames
+044E  checksum low
+044F  checksum high
```

Physical starts:

```text
SRAM bank 2 / .srm +0x4000
  Box 1  A000 / 4000
  Box 2  A450 / 4450
  ...
  Box 7  B9E0 / 59E0

SRAM bank 3 / .srm +0x6000
  Box 8  A000 / 6000
  Box 9  A450 / 6450
  ...
  Box 14 B9E0 / 79E0
```

This makes Box 1 and Box 8 uniquely sensitive to writes at `A000` of SRAM banks
2 and 3.

## Independent checksum-history evidence

The Spanish save retained a box-corruption-history bitmap `0x0081`, whose set bits
correspond to Box 1 and Box 8. The reconstructed sequence is:

```text
healthy box data + healthy checksums
        |
        | localized count corruption
        v
Box1 count 14->08, old checksum still present
Box8 count 00->0C, old checksum still present
        |
        | later game-side verification
        v
Box1 checksum mismatch + Box8 checksum mismatch
history |= 0x0081
        |
        | later normal save
        v
box checksums recalculated over the already-corrupt counts
history remains 0x0081
```

This is evidence that the count bytes changed *before* the later checksum rewrite;
it is inconsistent with a simple theory that the game intentionally saved those
new counts and matching checksums in one normal operation.

## Connection to the X7 diagnostic result

DIAG-A intentionally initializes the same two bytes:

```text
bank2:A000 = 14
bank3:A000 = 00
```

and `SIGNATURE` legally writes:

```text
RTC Hours   selector 0A <- 08
RTC Day Low selector 0B <- 0C
```

On the tested X7 this produced:

```text
bank2:A000 = 08
bank3:A000 = 0C
```

The mapper test therefore reproduces the exact **bank + address + before/after
byte transformation** seen in the historical save.

## Important limitation

This does **not** establish the original trigger. Normal Spanish Silver RTC code
was found to read `08..0C` but its ordinary RTC writes of interest use `RTC_DH`
(`0C`) for HALT/carry manipulation; no normal write path to Hours (`0A`) or Day
Low (`0B`) was identified. Therefore the project does not claim that ordinary
Pokémon code directly issued the historical `0A<-08 / 0B<-0C` pair.

The case motivates the tests and strongly links the observed mapper alias to a
plausible corruption mechanism; the missing end-to-end trigger remains explicitly
open.
