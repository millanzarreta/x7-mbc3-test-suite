# X7 MBC3 / RTC Test Suite

A reproducible Game Boy / Game Boy Color diagnostic suite for characterizing
MBC3 RTC/SRAM behavior across flash cartridges, reproduction cartridges,
emulators, FPGA implementations, and other MBC3-compatible environments.

The suite was developed while investigating an **RTC-write → SRAM alias**
observed on a tested EverDrive-GB X7. The project started from a real
Pokémon Silver / Pokémon Plata save-corruption case, but the tests themselves
are game-independent and can be used to compare MBC3 implementations.

On the tested X7, purpose-built ROMs reproduce and isolate a write-side MBC3
RTC/SRAM behavior that conflicts with Nintendo's documented RTC/SRAM bank
selection. Results documented by this repository refer specifically to the
tested X7 unless stated otherwise.

Current ROM set: **v1.0.0**. Canonical binaries are included in [`roms/`](roms/),
and release builds were produced and verified with **RGBDS 1.0.4**.

## Key finding

On the tested X7, writing to `A000` while one of the standard MBC3 RTC selectors
`08h..0Ch` is active can also modify external SRAM at `A000`. The observed
selector-to-bank mapping is compatible with:

```text
RTC selector 08 -> SRAM bank 0
RTC selector 09 -> SRAM bank 1
RTC selector 0A -> SRAM bank 2
RTC selector 0B -> SRAM bank 3
RTC selector 0C -> SRAM bank 0
```

Nintendo's *Game Boy Programming Manual* v1.0 (Chapter 8, sections 3.2-3.3,
pp. 216-217) documents `00h..03h` as RAM-bank selections and `08h..0Ch` as RTC
counter selections in the `A000-BFFF` external-expansion window. Under that
documented mapping, an `A000` write with `08h..0Ch` selected targets the selected
RTC counter; it must not also modify an SRAM bank. A public mirror of the
[Nintendo *Game Boy Programming Manual* v1.0](https://files.nekoblog.org/uploads/pdf/39999184-GameBoy-Programming-Manual.pdf)
is available online.

The X7 pattern is compatible with the low two selector bits reaching a four-bank
SRAM decode while the RTC path remains active. The tests establish the logical
behavior; they do not claim the exact FPGA/HDL implementation.

POKERTC's `VALUE MAP` writes unrelated data values (`11,22,05,A7,01`) and, on the
tested X7, observes the bank masks `01,02,04,08,01`. The same test logic leaves
monitored SRAM unchanged in the SameBoy reference runs.

The physical result was characterized on one
**[EverDrive-GB X7](https://krikzz.com/our-products/cartridges/edgbx7.html) Model 17 Rev.E**
(PCB 28.07.2021), reporting **FPGA 07** and running **GBC-OS 1.06**. See
[`docs/tested-environment.md`](docs/tested-environment.md).

## Minimal reproduction

For the shortest independent check:

1. Copy [`roms/X7POKERTC.gbc`](roms/X7POKERTC.gbc) to the target environment.
2. Start with a fresh diagnostic SRAM/save identity; do **not** reuse a commercial
   game save.
3. Initialize POKERTC and run `RAM AUDIT`; confirm `PASS`.
4. Run `VALUE MAP`.
5. Preserve the resulting SRAM save/capture and, on an X7, the associated `.rtc`
   file if available.

Expected result under documented MBC3 behavior:

```text
08 <- 11 : MASK 00
09 <- 22 : MASK 00
0A <- 05 : MASK 00
0B <- A7 : MASK 00
0C <- 01 : MASK 00
```

Observed on the tested X7:

```text
08 <- 11 : MASK 01
09 <- 22 : MASK 02
0A <- 05 : MASK 04
0B <- A7 : MASK 08
0C <- 01 : MASK 01
```

For exact operating steps and result semantics, see
[`docs/reproduction.md`](docs/reproduction.md) and
[`docs/test-guide.md`](docs/test-guide.md).

## Evidence boundary

The repository intentionally separates what is demonstrated from what remains
unknown.

**Demonstrated on the tested X7:** legal CPU-visible MBC3 RTC writes can also
modify SRAM; all five standard RTC selectors reproduce the observed bank pattern;
arbitrary data bytes can be reflected into SRAM; and DIAG-A can reproduce the
exact historical `bank2:A000 14→08 / bank3:A000 00→0C` transformation.

**Not demonstrated:** the original ordinary-use event that caused those two
writes in the Pokémon Silver save. Extensive lifecycle/ARM tests did not reproduce
that transition automatically. They argue against the tested reload, game-switch,
power-cycle, console-change or RTC-adjustment operations being sufficient
deterministic triggers, but they do not exclude a rarer state-dependent
GBC-OS/FPGA condition.

**Not claimed:** that every X7 hardware/FPGA/OS revision is affected, or that the
historical Pokémon corruption has been reproduced end-to-end.

See [`docs/test-results.md`](docs/test-results.md),
[`docs/lifecycle-arm.md`](docs/lifecycle-arm.md), and
[`docs/limitations.md`](docs/limitations.md).

## ROMs

**RGBDS is not required to run the suite.** The canonical pre-built ROMs are in
[`roms/`](roms/):

| ROM | Purpose |
|---|---|
| [`X7POKERTC.gbc`](roms/X7POKERTC.gbc) | Smallest direct RTC characterization ROM; recommended first test. |
| [`X7MBC3DIAG-A.gbc`](roms/X7MBC3DIAG-A.gbc) | Broad diagnostic; bank 2/3 canaries match the motivating Silver geometry. |
| [`X7MBC3DIAG-B.gbc`](roms/X7MBC3DIAG-B.gbc) | Independent RTC identity with different starting canaries. |
| [`X7MBC3DIAG-N.gbc`](roms/X7MBC3DIAG-N.gbc) | No-RTC negative control. |
| [`X7MBC3TRACE-A.gbc`](roms/X7MBC3TRACE-A.gbc) | Fine-grained write/selector/lifecycle tracing, primary identity. |
| [`X7MBC3TRACE-B.gbc`](roms/X7MBC3TRACE-B.gbc) | TRACE with independent canaries/RTC identity. |
| [`X7MBC3TRACE-N.gbc`](roms/X7MBC3TRACE-N.gbc) | TRACE no-RTC negative control. |

Hashes and the A/B/N identity scheme are in [`roms/README.md`](roms/README.md)
and [`SHA256SUMS.txt`](SHA256SUMS.txt).

### Which ROM should I use?

| Goal | Start with | Why |
|---|---|---|
| Confirm the alias quickly | **POKERTC** | `VALUE MAP` isolates all five RTC selectors and records which SRAM bank changed. |
| Reproduce the historical `14→08 / 00→0C` byte effect | **DIAG-A** | Its bank 2/3 canaries match the motivating Box 1 / Box 8 count bytes. |
| Pinpoint the first write that causes corruption | **TRACE-A** | `SILVER TRACE` audits after each phase and isolates the first fault at `0A + write`. |
| Study unload/reload and final mapper state | **TRACE-A/B/N** | ARM presets establish controlled final states and audit SRAM on the next boot. |
| Negative control without RTC | **DIAG-N / TRACE-N** | MBC3 + RAM + BATTERY profile with no timer. |

The three suites intentionally overlap, but their roles differ: **POKERTC** is the
small direct probe, **DIAG** is the broad persistent/stress environment, and
**TRACE** localizes operation ordering and lifecycle boundaries. Every menu option
is documented in [`docs/test-guide.md`](docs/test-guide.md).

## Historical signature reproducer

DIAG-A initializes the two canaries that match the motivating Spanish Silver box
geometry:

```text
bank2:A000 = 14
bank3:A000 = 00
```

Its `SIGNATURE` test deliberately performs:

```text
selector 0A <- 08
selector 0B <- 0C
```

On the tested X7 this produces:

```text
bank2:A000  14 -> 08
bank3:A000  00 -> 0C
```

This reproduces the **mechanism and byte effect**, not the unknown historical
trigger. The case study is documented in
[`docs/pokemon-silver-case.md`](docs/pokemon-silver-case.md).

## SameBoy reference runs

[SameBoy](https://sameboy.github.io/) was used as a high-accuracy software
comparison environment, not as the specification for MBC3 behavior. For the MBC3
operations exercised by this suite, the recorded SameBoy behavior agrees with
Nintendo's documented register selection and RTC/SRAM mapping. Direct mapper/RTC
tests that produce `FAULT`/`ALIAS` on the tested X7 leave the monitored SRAM
unchanged in the recorded SameBoy runs.

SameBoy was also used to smoke-test persistence and ARM bookkeeping. An `EXT_PASS`
inside an emulator validates the ROM's arm/boot/audit mechanism; it does **not**
simulate physical X7 actions such as moving the cartridge to another console or
changing an X7 RTC setting. Those lifecycle experiments were performed on the
physical X7.

## Persistent SRAM evidence

The ROM screen is the immediate summary; the more complete forensic record is the
diagnostic **SRAM state**. Depending on the suite, it contains mirrored metadata,
counters, monitored canaries/patterns, journals, stress statistics, and
DIAG/TRACE first-fault information.

A normal reboot or later test does not start a new empty history. DIAG/TRACE retain
up to **232 append-only events** and freeze logging when full; POKERTC retains the
newest **32** result records in a circular journal. The SRAM-clear hotkey
(`SELECT + START + B + A`) erases diagnostic SRAM history without resetting the
RTC.

See [`docs/sram-logging.md`](docs/sram-logging.md).

## SRAM inspectors

For interactive use, open [`tools/sram_inspector.html`](tools/sram_inspector.html)
and drop/select a raw SRAM save/capture. It is self-contained and offline; no
Python, server, or network connection is required.

Command-line use:

```sh
python3 tools/inspect_sram.py capture.sav
python3 tools/inspect_sram.py capture.sav --format json > capture.json
python3 tools/inspect_sram.py capture.sav --format html -o capture.html
```

Both inspectors use the first 32 KiB as cartridge SRAM and report trailing data
separately. Common extensions such as `.srm`, `.sav`, `.ram`, and `.bin` are only
naming conventions; the extension does not determine the diagnostic format.

## Build and verification

The pre-built ROMs in [`roms/`](roms/) can be used directly. Building and
verifying the project from source requires [RGBDS](https://rgbds.gbdev.io/),
GNU Make, and Python 3.

The canonical ROMs in this repository were built and verified with
[RGBDS 1.0.4](https://github.com/gbdev/rgbds/releases/tag/v1.0.4).
Other compatible RGBDS 1.x versions may also build the sources, but they have
not been tested by this project. Use RGBDS 1.0.4 when reproducing the canonical
release binaries or verifying rebuilt ROMs byte-for-byte against them.

Installation instructions are available in the
[RGBDS documentation](https://rgbds.gbdev.io/install/). The complete project
setup and reproduction procedure is documented in
[`docs/reproduction.md`](docs/reproduction.md).

From the repository root:

```sh
make clean
make audit
```

`make audit` performs the static repository checks, builds all seven ROMs and
compares them byte-for-byte with the canonical files in [`roms/`](roms/),
independently reconstructs the ROMs from the restricted ASM subset without
invoking RGBDS, and runs the tooling tests.

The individual build and verification targets can also be run separately; see
[`docs/reproduction.md`](docs/reproduction.md) and
[`docs/source-guide.md`](docs/source-guide.md).

## Repository structure

| Path | Contents |
|---|---|
| `roms/` | Canonical pre-built v1.0.0 ROMs. |
| `diag/` | X7MBC3DIAG guide and canonical RGBDS sources. |
| `trace/` | X7MBC3TRACE guide and canonical RGBDS sources. |
| `pokertc/` | X7POKERTC guide and canonical RGBDS source. |
| `common/` | Small project-local RGBDS constants shared by the suites. |
| `tools/` | SRAM inspectors and repository/build/source verification tools. |
| `docs/` | Technical model, test semantics/results, case study, lifecycle, firmware, logging and reproduction notes. |
| `reference/sample-results/` | Text-only reference examples; no private game saves. |
| `.github/workflows/` | CI build, exact-ROM verification and tooling tests. |

## Documentation map

Every maintained Markdown document in the repository is linked here.

### Main technical documentation

| Document | Purpose |
|---|---|
| [`docs/technical-overview.md`](docs/technical-overview.md) | MBC3 model, observed alias and evidence boundaries. |
| [`docs/test-guide.md`](docs/test-guide.md) | Neutral guide to every test, PASS/FAIL semantics, stress modes and ARM PRESET/SCENARIO behavior. |
| [`docs/test-results.md`](docs/test-results.md) | Observed SameBoy/X7 campaign results, first-fault localization and interpretation. |
| [`docs/sram-logging.md`](docs/sram-logging.md) | Persistent SRAM state, journals, reset behavior and capture-file conventions. |
| [`docs/lifecycle-arm.md`](docs/lifecycle-arm.md) | ARM/lifecycle experiment design, operation and evidence limits. |
| [`docs/pokemon-silver-case.md`](docs/pokemon-silver-case.md) | Motivating Spanish Silver corruption and exact `14→08 / 00→0C` signature. |
| [`docs/firmware-notes.md`](docs/firmware-notes.md) | Focused static analysis of GBC-OS v1.06 SRAM/RTC paths. |
| [`docs/tested-environment.md`](docs/tested-environment.md) | Exact X7 hardware, FPGA/OS and built-in diagnostic result. |
| [`docs/limitations.md`](docs/limitations.md) | Non-claims and unresolved questions. |
| [`docs/reproduction.md`](docs/reproduction.md) | Build, verification and emulator/hardware reproduction workflow. |
| [`docs/source-guide.md`](docs/source-guide.md) | RGBDS source layout and deterministic-build details. |
| [`docs/terminology.md`](docs/terminology.md) | ARM, PRESET and SCENARIO terminology. |

### Suite and source guides

| Document | Purpose |
|---|---|
| [`roms/README.md`](roms/README.md) | Pre-built ROM inventory, A/B/N identities and hashes. |
| [`diag/README.md`](diag/README.md) | DIAG variants and intended use. |
| [`diag/rgbds/README.md`](diag/rgbds/README.md) | DIAG source/build notes. |
| [`trace/README.md`](trace/README.md) | TRACE variants, PRESET/SCENARIO and intended use. |
| [`trace/rgbds/README.md`](trace/rgbds/README.md) | TRACE source/build notes. |
| [`pokertc/README.md`](pokertc/README.md) | POKERTC purpose and direct RTC tests. |
| [`pokertc/rgbds/README.md`](pokertc/rgbds/README.md) | POKERTC source/build notes. |
| [`common/README.md`](common/README.md) | Shared support overview. |
| [`common/rgbds/README.md`](common/rgbds/README.md) | Shared RGBDS include notes. |
| [`tools/README.md`](tools/README.md) | Inspectors and verification tools. |

### Reference results and legal notices

| Document | Purpose |
|---|---|
| [`reference/sample-results/README.md`](reference/sample-results/README.md) | Scope of curated public result examples. |
| [`reference/sample-results/nintendo-mbc3.md`](reference/sample-results/nintendo-mbc3.md) | Nintendo-documented MBC3 reference behavior. |
| [`reference/sample-results/everdrive-x7-observed.md`](reference/sample-results/everdrive-x7-observed.md) | Concise tested-X7 signatures. |
| [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) | Third-party fragments, header material, trademarks and external tools. |

## License and affiliation

Project-authored code, tools and documentation are released under the
[`LICENSE`](LICENSE) (MIT), subject to the boundaries in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

This is an independent, unofficial hardware diagnostic and research project. It
is not affiliated with, endorsed by, sponsored by, or associated with Nintendo,
The Pokémon Company, Creatures, GAME FREAK, or Krikzz. Referenced product and
game names belong to their respective owners. No complete commercial game ROM,
game artwork, audio, or private game save is distributed by this repository.
