# Reproduction and build guide

## Requirements

The pre-built ROMs in [`../roms/`](../roms/) can be used directly without any
build dependencies. The standalone browser SRAM inspector requires only a
modern browser.

Building and verifying the ROMs from source requires:

- [RGBDS](https://rgbds.gbdev.io/) (`rgbasm`, `rgblink`, `rgbfix`)
- GNU Make
- Python 3

The canonical ROMs in this repository were built and verified with
[RGBDS 1.0.4](https://github.com/gbdev/rgbds/releases/tag/v1.0.4).

Other compatible RGBDS 1.x versions may also build the sources, but they have
not been tested by this project. RGBDS 1.0.4 is the toolchain used for the
canonical binaries and should be used when reproducing them or verifying a
rebuild byte-for-byte.

## Installing RGBDS

Platform-specific installation instructions are available in the
[official RGBDS documentation](https://rgbds.gbdev.io/install/).

RGBDS 1.0.4 release packages are available from the
[official release page](https://github.com/gbdev/rgbds/releases/tag/v1.0.4).

For example, on x86-64 Linux the official pre-built RGBDS 1.0.4 package can be
installed with:

```sh
curl -fL -o rgbds-linux-x86_64.tar.xz "https://github.com/gbdev/rgbds/releases/download/v1.0.4/rgbds-linux-x86_64.tar.xz"

mkdir rgbds-1.0.4
tar -xf rgbds-linux-x86_64.tar.xz -C rgbds-1.0.4
cd rgbds-1.0.4
sudo ./install.sh
```

For exact build verification, confirm the installed toolchain:

```sh
rgbasm -V
rgblink -V
rgbfix -V
```

All three tools should identify version 1.0.4.

## Clean deterministic build

From the repository root:

```sh
make clean
make audit
```

`make audit` runs the repository static audit, builds and verifies all seven ROMs
against their canonical pre-built counterparts, independently reconstructs the
ROMs from the restricted ASM subset, and runs the tooling tests.

During exact build verification, every generated ROM must report `EXACT`
relative to its canonical counterpart in `roms/`.

The individual stages can also be run separately:

```sh
make
make verify-build
make verify-source
make test-tools
make static-audit
```

`make` builds all seven ROMs into the root `build/` directory.

`make verify-build` compares RGBDS-built ROMs byte-for-byte with the canonical
files in `roms/`.

`make verify-source` independently reconstructs the ROMs from the supported ASM
subset without invoking RGBDS and compares the resulting bytes with the
canonical ROMs.

`make test-tools` runs the SRAM-inspector and related tooling tests.

`make static-audit` checks repository structure, canonical ROM metadata and
hashes, documentation links, and other repository invariants.

## Build outputs

Generated ROMs are written to:

```text
build/X7MBC3DIAG-A.gbc
build/X7MBC3DIAG-B.gbc
build/X7MBC3DIAG-N.gbc
build/X7MBC3TRACE-A.gbc
build/X7MBC3TRACE-B.gbc
build/X7MBC3TRACE-N.gbc
build/X7POKERTC.gbc
```

Intermediate object files are centralized in:

```text
build/obj/
```

The shipped pre-built files remain in:

```text
roms/
```

`make clean` removes the generated root `build/` tree and never removes the
canonical pre-built ROMs under `roms/`.

Do not use an unrelated commercial save with these ROMs. They create and manage
their own 32 KiB diagnostic SRAM state.

## Minimal reference check

The expected result below is derived from Nintendo's documented MBC3
bank/register mapping: selectors `00h..03h` select external RAM banks, while
`08h..0Ch` select RTC counters in the `A000-BFFF` cartridge window. See
[`technical-overview.md`](technical-overview.md) for the manual reference and
mapping details.

SameBoy was used as the software comparison environment and matched that
behavior in the recorded reference runs:

1. start with fresh diagnostic SRAM;
2. initialize POKERTC;
3. run `RAM AUDIT`;
4. run `VALUE MAP`;
5. expect all five `MASK` values to remain `00`.

DIAG-A `SIGNATURE` should also leave `bank2:A000=14` and `bank3:A000=00` intact.

## Tested-X7 alias characterization

The reference hardware result was obtained on the unit described in
[`tested-environment.md`](tested-environment.md). Record equivalent hardware
revision / FPGA / OS information when testing another X7.

For the shortest hardware characterization:

1. use [`../roms/X7POKERTC.gbc`](../roms/X7POKERTC.gbc) with a fresh save identity;
2. initialize;
3. run `RAM AUDIT` and confirm PASS;
4. run `VALUE MAP`;
5. preserve the resulting SRAM save/capture file and, on the X7, the associated
   `.rtc` file. X7 normally uses `.srm`; other environments may use names such as
   `.sav`, `.ram` or `.bin` for raw SRAM.

The reference X7 result was:

```text
08<-11 -> mask 01
09<-22 -> mask 02
0A<-05 -> mask 04
0B<-A7 -> mask 08
0C<-01 -> mask 01
```

DIAG-A `SIGNATURE` then provides the compact `14→08 / 00→0C` reproducer.

## Lifecycle testing

Direct RTC-write reproduction and external lifecycle testing answer different
questions. Do not interpret a clean ARM return as contradicting a direct-write
fault. See [`lifecycle-arm.md`](lifecycle-arm.md) before running ARM campaigns,
and [`test-results.md`](test-results.md) for the recorded reference campaign.

## Inspecting SRAM

For interactive use, open
[`../tools/sram_inspector.html`](../tools/sram_inspector.html) and drop/select
the capture. It is fully offline and supports current DIAG, TRACE and POKERTC
formats plus the all-zero SRAM-clear state.

Common raw-SRAM extensions include `.srm`, `.sav`, `.ram` and `.bin`; the
extension itself is not used to identify the diagnostic format.

For scripting, from the repository root:

```sh
python3 tools/inspect_sram.py capture.sav
python3 tools/inspect_sram.py capture.sav --format json > capture.json
python3 tools/inspect_sram.py capture.sav --format html -o capture.html
```

Both tools inspect the first 32768 bytes as cartridge SRAM and report any
trailing bytes separately. Formats with a header before the raw SRAM image
require that header to be removed first. See
[`sram-logging.md`](sram-logging.md).

## Resetting diagnostic SRAM

On an input screen, hold:

```text
SELECT + START + B + A
```

for approximately half a second. The ROM clears all 32 KiB of diagnostic SRAM
and enters a restart-required screen. It intentionally does not reset the RTC.

## Reproducibility rule

A source change that is not intended to alter canonical ROM output must pass:

```sh
make verify-build
```

under RGBDS 1.0.4.

If any ROM reports `DIFF`, treat it as a binary/behavior change requiring
explicit review rather than silently replacing the canonical ROM or hash.

Before publishing or releasing a repository revision, run the complete
validation:

```sh
make clean
make audit
```
