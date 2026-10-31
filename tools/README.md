# Tools

Repository-level maintained tools live here.

## SRAM inspectors

### Standalone browser inspector

Open [`sram_inspector.html`](sram_inspector.html) directly in a browser and
drop/select a raw SRAM save/capture such as `.srm`, `.sav`, `.ram` or `.bin`.
The page is fully self-contained and offline; no file data leaves the browser.
It interprets the first 32 KiB as cartridge SRAM and reports trailing bytes
separately.

It supports current:

- DIAG `X7D8 / format 8`;
- TRACE `X7T1 / schema 2`;
- POKERTC `X7P1 / version 1`;
- the all-zero SRAM state produced by the SELECT+START+B+A clear action.

For DIAG/TRACE it also decodes the mirrored accumulated stress-statistics block
(runs, loops and stored timer ticks). Journal rows provide a compact overview and
can be expanded per slot to expose every decoded field, loop/timing metadata,
mirror/checksum validity and the raw bytes from both copies.

Browser/Python decoder parity test:

```sh
python3 -B tools/test_browser_inspector.py
```

### Command-line inspector

```sh
python3 tools/inspect_sram.py capture.sav
python3 tools/inspect_sram.py capture.sav --format json > capture.json
python3 tools/inspect_sram.py capture.sav --format html -o capture.html
```

Self-test:

```sh
python3 -B tools/test_inspector.py
```

## Build/source verification

### `verify_rgbds_build.py`

Compares actual RGBDS-built ROMs with the canonical pre-built files in `roms/`.

### `validate_rgbds_transcription.py`

Independent subset encoder that reconstructs the seven ROMs from the canonical
ASM without invoking RGBDS and compares them with `roms/`.

### `verify_clear_routine.py`

Small instruction/MBC3 model used to validate that the SRAM-clear routine touches
all 32 KiB through SRAM selectors `00..03` and does not select/write RTC.

### `audit_repository.py`

Checks the public repository shape: canonical ROM hashes, required files,
the README documentation index, and the published hash list.

Run the maintained checks with:

```sh
make audit
```
