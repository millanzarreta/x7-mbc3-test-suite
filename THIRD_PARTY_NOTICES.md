# Third-party notices

The root [`LICENSE`](LICENSE) applies to project-authored source code,
documentation, tools and other original material in this repository except where
this file or another source file states otherwise. It does **not** purport to
relicense third-party material.

## Game Boy cartridge header

The diagnostic ROM images contain the standard Nintendo logo bytes required by
the original Game Boy boot process in the cartridge header. Those bytes are
retained as part of the hardware-bootable diagnostic ROM images. The project does
not claim ownership of Nintendo trademarks or branding.

## X7POKERTC Gold/Silver RTC fragments

`X7POKERTC` contains a small number of MBC3/RTC routine fragments transcribed from
the Spanish release of Pokémon Silver and cross-checked during the investigation
against the public `pret/pokegold` disassembly. They are retained because
instruction-level / bus-sequence equivalence is directly relevant to the
diagnostic purpose of POKERTC.

These fragments are not claimed as original project-authored code and are not
intended to be relicensed by the project's MIT license. No complete commercial
game ROM, game artwork, game audio, maps, scripts, Pokémon data tables, or private
game saves are distributed here.

Relevant source locations and the diagnostic rationale are documented in
[`docs/test-guide.md`](docs/test-guide.md) and
[`docs/pokemon-silver-case.md`](docs/pokemon-silver-case.md).

## Names and trademarks

Game Boy, Nintendo, Pokémon, Pokémon Gold, Pokémon Silver and Pokémon Crystal are
names/trademarks or intellectual property of their respective owners. EverDrive
is a trademark of its respective owner. Their use is referential: to identify
hardware/software involved in interoperability testing and the motivating case.

## External tools

RGBDS and SameBoy are external projects and are not redistributed by this
repository. Their own licenses apply. `common/rgbds/hardware.inc` is a small
project-local set of constants; it is not a vendored copy of upstream
`gbdev/hardware.inc`.
