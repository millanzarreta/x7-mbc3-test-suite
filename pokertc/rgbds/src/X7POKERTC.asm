; Canonical RGBDS source matching the shipped v1.0.0 ROM bytes.
; Test logic and persistent format are unchanged; the main-menu cursor is preserved on return.

INCLUDE "../../common/rgbds/hardware.inc"

SECTION "Cartridge entry/header", ROM0[$0100]
    nop
    jp Start
    db $CE, $ED, $66, $66, $CC, $0D, $00, $0B, $03, $73, $00, $83, $00, $0C, $00, $0D, $00, $08, $11, $1F, $88, $89, $00, $0E, $DC, $CC, $6E, $E6, $DD, $DD, $D9, $99, $BB, $BB, $67, $63, $6E, $0E, $EC, $CC, $DD, $DC, $99, $9F, $BB, $B9, $33, $3E
    db "X7POKERTC"
    ds 6, 0
    db $80 ; CGB-compatible
    db $30, $30, $03, $10, $06, $03, $01, $33, $00
    db 0 ; header checksum, fixed by rgbfix -v
    db 0, 0 ; global checksum, fixed by rgbfix -v

SECTION "Program", ROM0[$0150]
; Boot entry. Initialize WRAM/video, validate persistent state, then audit SRAM before normal menu work.
Start:
    di
    ld sp, $DFF0
    ld a, $00
    ld [$C000], a
    ld [$C001], a
    ld [$C002], a
    ld [$C003], a
    ld [$C004], a
    ld [$C005], a
    ld [$C006], a
    ld [$C007], a
    ld [$C008], a
    ld [$C039], a
    ld [$C03A], a
    ld [$C03B], a
    ld [$C03C], a
    ld [$C010], a
    ld [$C011], a
    ld [$C012], a
    ld [$C013], a
    ld [$C014], a
    ld [$C020], a
    ld [$C021], a
    ld [$C022], a
    ld [$C023], a
    ld [$C024], a
    ld [$C025], a
    ld [$C026], a
    ld [$C027], a
    ld [$C028], a
    ld [$C029], a
    ld [$C02A], a
    ld [$C02B], a
    ld [$C02C], a
    ld [$C02D], a
    ld [$C02E], a
    ld [$C02F], a
    ld [$C030], a
    ld [$C031], a
    ld [$C032], a
    ld [$C033], a
    ld [$C034], a
    ld [$C035], a
    ld [$C036], a
    ld [$C037], a
    ld [$C038], a
    call InitVideo
    call EnableRAM
    call LoadSuper
    jp nc, HaveState
    call FirstRun
HaveState:
    call BootAudit
    jp MainMenu
; Initialize DMG/CGB video state and copy the built-in diagnostic font.
InitVideo:
    ldh a, [$FF40]
    and $80
    jp z, VideoLCDOff
WaitVBOff:
    ldh a, [$FF44]
    cp $90
    jr c, WaitVBOff
VideoLCDOff:
    ld a, $00
    ldh [$FF40], a
    ld a, $00
    ldh [$FF4F], a
    ld hl, $8000
    ld bc, $2000
    ld d, $00
ClrVRAM0:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClrVRAM0
    ld a, $01
    ldh [$FF4F], a
    ld hl, $8000
    ld bc, $2000
    ld d, $00
ClrVRAM1:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClrVRAM1
    ld a, $00
    ldh [$FF4F], a
    ld hl, FontData
    ld de, $8000
    ld bc, $0800
FontCopy:
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, FontCopy
    ld a, $E4
    ldh [$FF47], a
    ld a, $80
    ldh [$FF68], a
    ld a, $FF
    ldh [$FF69], a
    ld a, $7F
    ldh [$FF69], a
    ld a, $B5
    ldh [$FF69], a
    ld a, $56
    ldh [$FF69], a
    ld a, $4A
    ldh [$FF69], a
    ld a, $29
    ldh [$FF69], a
    ld a, $00
    ldh [$FF69], a
    ld a, $00
    ldh [$FF69], a
    ld a, $00
    ldh [$FF42], a
    ldh [$FF43], a
    ld a, $91
    ldh [$FF40], a
    ret
WaitVBlank:
WaitVB:
    ldh a, [$FF44]
    cp $90
    jr c, WaitVBlank
    ret
WaitVRAM:
WaitVR:
    ldh a, [$FF41]
    and $03
    cp $02
    jr nc, WaitVRAM
    ret
PutTileA:
    push af
    call WaitVRAM
    pop af
    ld [de], a
    ret
ClearScreen:
    ldh a, [$FF40]
    and $80
    jp z, CSOff
    call WaitVBlank
    ld a, $00
    ldh [$FF40], a
CSOff:
    ld hl, $9800
    ld bc, $0400
    ld d, $20
CSLoop:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, CSLoop
    ld a, $91
    ldh [$FF40], a
    ret
PrintString:
PSLoop:
    ld a, [hli]
    or a
    ret z
    call PutTileA
    inc de
    jr PrintString
NibbleASCII:
    and $0F
    add a, $30
    cp $3A
    ret c
    add a, $07
    ret
PrintHexByte:
    push af
    swap a
    call NibbleASCII
    call PutTileA
    inc de
    pop af
    call NibbleASCII
    call PutTileA
    ret
; Read both JOYP matrix halves with settling reads for physical hardware.
ReadKeys:
    ld a, $20
    ldh [$FF00], a
    ldh a, [$FF00]
    ldh a, [$FF00]
    ldh a, [$FF00]
    ldh a, [$FF00]
    cpl
    and $0F
    ld b, a
    ld a, $10
    ldh [$FF00], a
    ldh a, [$FF00]
    ldh a, [$FF00]
    ldh a, [$FF00]
    ldh a, [$FF00]
    cpl
    and $0F
    swap a
    or b
    ld b, a
    ld a, $30
    ldh [$FF00], a
    ld a, b
    ret
WaitInputFrame:
WaitInputOutVB:
    ldh a, [$FF44]
    cp $90
    jr nc, WaitInputFrame
WaitInputIntoVB:
    ldh a, [$FF44]
    cp $90
    jr c, WaitInputIntoVB
    ret
; Debounced menu input. Also recognizes the deliberate SRAM-clear chord.
WaitKey:
Release:
    call WaitInputFrame
    call ReadKeys
    or a
    jr nz, WaitKey
    call WaitInputFrame
    call ReadKeys
    or a
    jr nz, WaitKey
Press:
    call WaitInputFrame
    call ReadKeys
    or a
    jr z, Press
    ld c, a
    call WaitInputFrame
    call ReadKeys
    or a
    jr z, Press
    cp c
    jr nz, Press
    ld a, c
    cp $F0
    ret nz
    ld c, $1E
ClearChordHold:
    call WaitInputFrame
    call ReadKeys
    cp $F0
    jp nz, WaitKey
    dec c
    jr nz, ClearChordHold
    jp ClearSRAMTerminal
; Factory-reset only the 32 KiB diagnostic SRAM. Never select/latch/write RTC registers.
ClearSRAMTerminal:
    di
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, SRAM_WINDOW
    ld bc, $2000
    ld d, $00
ClearFullSRAM0:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearFullSRAM0
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, SRAM_WINDOW
    ld bc, $2000
    ld d, $00
ClearFullSRAM1:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearFullSRAM1
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, SRAM_WINDOW
    ld bc, $2000
    ld d, $00
ClearFullSRAM2:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearFullSRAM2
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, SRAM_WINDOW
    ld bc, $2000
    ld d, $00
ClearFullSRAM3:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearFullSRAM3
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld [MBC_RAM_ENABLE], a
    call ClearScreen
    ld hl, StrSRAMCleared
    ld de, $9860
    call PrintString
    ld hl, StrRTCUnchanged
    ld de, $98C0
    call PrintString
    ld hl, StrRestartRequired
    ld de, $9920
    call PrintString
ClearSRAMHold:
    call ReadKeys
    jp ClearSRAMHold
; Enable MBC external RAM/RTC window.
EnableRAM:
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    ret
; Disable external RAM/RTC using the same latch-close pattern used by the validated tester.
CloseSRAM:
    push af
    ld a, $00
    ld [MBC_LATCH], a
    ld [MBC_RAM_ENABLE], a
    pop af
    ret
; Perform the standard MBC3 RTC latch transition 00 -> 01 at $6000.
LatchClock:
    ld a, $00
    ld [MBC_LATCH], a
    ld a, $01
    ld [MBC_LATCH], a
    ret
SelectBankA:
    ld [MBC_RAM_RTC_SELECT], a
    ret
CalcSuper:
    ld hl, $C100
    ld de, MBC_RAM_ENABLE
    ld b, $3E
CalcSuperLoop:
    ld a, [hli]
    add a, e
    ld e, a
    jr nc, CalcNoCarry
    inc d
CalcNoCarry:
    dec b
    jr nz, CalcSuperLoop
    ret
UpdateSuperCK:
    call CalcSuper
    ld a, e
    ld [$C13E], a
    ld a, d
    ld [$C13F], a
    ret
SaveSuper:
    call EnableRAM
    call UpdateSuperCK
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C100
    ld de, $A100
    ld b, $40
SaveSuper0:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveSuper0
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C100
    ld de, $A100
    ld b, $40
SaveSuper1:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveSuper1
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
LoadSuperBank:
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $A100
    ld de, $C100
    ld b, $40
LSCopy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, LSCopy
    ld a, [$C100]
    cp $58
    jp nz, LSBad
    ld a, [$C101]
    cp $37
    jp nz, LSBad
    ld a, [$C102]
    cp $50
    jp nz, LSBad
    ld a, [$C103]
    cp $31
    jp nz, LSBad
    ld a, [$C104]
    cp $01
    jp nz, LSBad
    call CalcSuper
    ld a, e
    ld hl, $C13E
    cp [hl]
    jp nz, LSBad
    inc hl
    ld a, d
    cp [hl]
    jp nz, LSBad
    or a
    ret
LSBad:
    scf
    ret
LoadSuper:
    ld a, $00
    call LoadSuperBank
    ret nc
    ld a, $01
    call LoadSuperBank
    ret
Inc16:
    inc [hl]
    ret nz
    inc hl
    inc [hl]
    ret
FillPattern:
    ld a, b
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, SRAM_WINDOW
    ld a, e
    ld [hli], a
FillPatLoop:
    ld a, h
    cp d
    ret z
    ld a, h
    xor l
    xor c
    ld [hli], a
    jr FillPatLoop
ScanPattern:
    ld a, b
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, SRAM_WINDOW
    ld a, [hl]
    cp e
    jp nz, ScanFirstBad
    inc hl
ScanLoop:
    ld a, h
    cp d
    jp z, ScanOK
    ld a, h
    xor l
    xor c
    ld e, a
    ld a, [hl]
    cp e
    jp nz, ScanBad
    inc hl
    jr ScanLoop
ScanFirstBad:
    ld [$C004], a
    ld a, e
    ld [$C003], a
    jp ScanStore
ScanBad:
    ld [$C004], a
    ld a, e
    ld [$C003], a
ScanStore:
    ld a, b
    ld [$C006], a
    ld a, l
    ld [$C007], a
    ld a, h
    ld [$C008], a
    scf
    ret
ScanOK:
    or a
    ret
; Initialize deterministic SRAM surveillance patterns and canaries.
InitPatterns:
    ld b, $00
    ld c, $10
    ld d, $A1
    ld e, $3C
    call FillPattern
    ld b, $01
    ld c, $20
    ld d, $A1
    ld e, $C3
    call FillPattern
    ld b, $02
    ld c, $5A
    ld d, $C0
    ld e, $14
    call FillPattern
    ld b, $03
    ld c, $A5
    ld d, $C0
    ld e, $00
    call FillPattern
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
ScanAll:
    call EnableRAM
    ld b, $00
    ld c, $10
    ld d, $A1
    ld e, $3C
    call ScanPattern
    ret c
    ld b, $01
    ld c, $20
    ld d, $A1
    ld e, $C3
    call ScanPattern
    ret c
    ld b, $02
    ld c, $5A
    ld d, $C0
    ld e, $14
    call ScanPattern
    ret c
    ld b, $03
    ld c, $A5
    ld d, $C0
    ld e, $00
    call ScanPattern
    ret c
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    or a
    ret
RestoreCanaries:
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $3C
    ld [SRAM_WINDOW], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $C3
    ld [SRAM_WINDOW], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $14
    ld [SRAM_WINDOW], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $00
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
; Initialize a new diagnostic campaign/state.
FirstRun:
    call ClearScreen
    ld hl, StrTitle
    ld de, $9800
    call PrintString
    ld hl, StrVersion
    ld de, $9820
    call PrintString
    ld hl, StrNoState
    ld de, $9880
    call PrintString
    ld hl, StrInit
    ld de, $98E0
    call PrintString
    ld hl, StrOwnRTC
    ld de, $9940
    call PrintString
FRWait:
    call WaitKey
    and $10
    jr z, FRWait
    call EnableRAM
    call InitPatterns
    ld hl, $C100
    ld b, $40
    ld a, $00
ZeroSup:
    ld [hli], a
    dec b
    jr nz, ZeroSup
    ld a, $58
    ld [$C100], a
    ld a, $37
    ld [$C101], a
    ld a, $50
    ld [$C102], a
    ld a, $31
    ld [$C103], a
    ld a, $01
    ld [$C104], a
    call SaveSuper
    call LoadSuper
    ret
; Audit deterministic SRAM state at boot before diagnostic RTC activity.
BootAudit:
    call ScanAll
    jp c, BootBad
    ld hl, $C105
    call Inc16
    call SaveSuper
    ret
BootBad:
    ld a, $EE
    ld [$C10A], a
    ld hl, $C107
    call Inc16
    call SaveSuper
    jp FaultScreen
; Transcription of the Gold/Silver-style RTC read sequence used by POKERTC.
PokemonGetClock:
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    call LatchClock
    ld hl, MBC_RAM_RTC_SELECT
    ld de, SRAM_WINDOW
    ld [hl], $08
    ld a, [de]
    and $3F
    ld [$C010], a
    ld [hl], $09
    ld a, [de]
    and $3F
    ld [$C011], a
    ld [hl], $0A
    ld a, [de]
    and $1F
    ld [$C012], a
    ld [hl], $0B
    ld a, [de]
    ld [$C013], a
    ld [hl], $0C
    ld a, [de]
    ld [$C014], a
    call CloseSRAM
    ret
; Focused helper reproduction that checks RTC_DH/HALT and writes scratch state.
Pokemon_UGetClock:
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    call LatchClock
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    push af
    call CloseSRAM
    pop af
    and $40
    ret z
    ld a, $01
    ld [MBC_LATCH], a
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $34
    ld [$B7EF], a
    ld a, $12
    ld [$B7F0], a
    call CloseSRAM
    ret
; Gold/Silver-style RTC_DH read/clear-HALT/write operation.
PokemonStartRTC:
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    call LatchClock
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    and $BF
    ld [SRAM_WINDOW], a
    call CloseSRAM
    ret
; Gold/Silver-style RTC_DH read/set-HALT/write operation.
PokemonStopRTC:
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    call LatchClock
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    or $40
    ld [SRAM_WINDOW], a
    call CloseSRAM
    ret
; Gold/Silver-style RTC_DH carry-bit handling used by save logic.
PokemonSaveRTC:
    ld a, $0A
    ld [MBC_RAM_ENABLE], a
    call LatchClock
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    and $7F
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $00
    ld [$AC60], a
    call CloseSRAM
    ret
ResetTestScratch:
    ld a, $00
    ld [$C002], a
    ld [$C003], a
    ld [$C004], a
    ld [$C005], a
    ld [$C006], a
    ld [$C007], a
    ld [$C008], a
    ld [$C039], a
    ld [$C03A], a
    ld [$C03B], a
    ld [$C03C], a
    ret
LogResult:
    ld hl, $C050
    ld b, $10
    ld a, $00
LogClr:
    ld [hli], a
    dec b
    jr nz, LogClr
    ld a, [$C12E]
    ld [$C050], a
    ld a, [$C12F]
    ld [$C051], a
    ld a, [$C001]
    ld [$C052], a
    ld a, [$C002]
    ld [$C053], a
    ld a, [$C005]
    ld [$C054], a
    ld a, [$C003]
    ld [$C055], a
    ld a, [$C004]
    ld [$C056], a
    ld a, [$C039]
    ld [$C057], a
    ld a, [$C03A]
    ld [$C058], a
    ld a, [$C006]
    ld [$C059], a
    ld a, [$C007]
    ld [$C05A], a
    ld a, [$C008]
    ld [$C05B], a
    ld a, [$C03B]
    ld [$C05C], a
    ld a, [$C03C]
    ld [$C05D], a
    ld c, $00
    ld a, [$C001]
    cp $02
    jp nz, LogVMmaskDone
    ld a, [$C024]
    or c
    ld c, a
    ld a, [$C029]
    or c
    ld c, a
    ld a, [$C02E]
    or c
    ld c, a
    ld a, [$C033]
    or c
    ld c, a
    ld a, [$C038]
    or c
    ld c, a
LogVMmaskDone:
    ld a, c
    ld [$C05E], a
    ld hl, $C050
    ld b, $0F
    ld c, $00
LogSum:
    ld a, [hli]
    add a, c
    ld c, a
    dec b
    jr nz, LogSum
    ld a, c
    ld [$C05F], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [$C130]
    and $1F
    ld l, a
    ld h, $00
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $A200
    add hl, de
    ld de, $C050
    ld b, $10
LogWrite0:
    ld a, [de]
    ld [hl], a
    inc de
    inc hl
    dec b
    jr nz, LogWrite0
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [$C130]
    and $1F
    ld l, a
    ld h, $00
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $A200
    add hl, de
    ld de, $C050
    ld b, $10
LogWrite1:
    ld a, [de]
    ld [hl], a
    inc de
    inc hl
    dec b
    jr nz, LogWrite1
    ld hl, $C12E
    call Inc16
    ld a, [$C130]
    inc a
    and $1F
    ld [$C130], a
    call SaveSuper
    ret
PersistResult:
    ld a, [$C001]
    ld [$C109], a
    ld a, [$C002]
    ld [$C10A], a
    ld a, [$C005]
    ld [$C10B], a
    ld a, [$C003]
    ld [$C10C], a
    ld a, [$C004]
    ld [$C10D], a
    ld a, [$C03B]
    ld [$C12C], a
    ld a, [$C03C]
    ld [$C12D], a
    ld a, [$C010]
    ld [$C10E], a
    ld a, [$C011]
    ld [$C10F], a
    ld a, [$C012]
    ld [$C110], a
    ld a, [$C013]
    ld [$C111], a
    ld a, [$C014]
    ld [$C112], a
    ld a, [$C020]
    ld [$C113], a
    ld a, [$C021]
    ld [$C114], a
    ld a, [$C022]
    ld [$C115], a
    ld a, [$C023]
    ld [$C116], a
    ld a, [$C024]
    ld [$C117], a
    ld a, [$C025]
    ld [$C118], a
    ld a, [$C026]
    ld [$C119], a
    ld a, [$C027]
    ld [$C11A], a
    ld a, [$C028]
    ld [$C11B], a
    ld a, [$C029]
    ld [$C11C], a
    ld a, [$C02A]
    ld [$C11D], a
    ld a, [$C02B]
    ld [$C11E], a
    ld a, [$C02C]
    ld [$C11F], a
    ld a, [$C02D]
    ld [$C120], a
    ld a, [$C02E]
    ld [$C121], a
    ld a, [$C02F]
    ld [$C122], a
    ld a, [$C030]
    ld [$C123], a
    ld a, [$C031]
    ld [$C124], a
    ld a, [$C032]
    ld [$C125], a
    ld a, [$C033]
    ld [$C126], a
    ld a, [$C034]
    ld [$C127], a
    ld a, [$C035]
    ld [$C128], a
    ld a, [$C036]
    ld [$C129], a
    ld a, [$C037]
    ld [$C12A], a
    ld a, [$C038]
    ld [$C12B], a
    call SaveSuper
    call LogResult
    ret
IncError:
    ld hl, $C107
    call Inc16
    ret
ShowPass:
    call PersistResult
    call ClearScreen
    ld hl, StrPass
    ld de, $9860
    call PrintString
    ld hl, StrAnyKey
    ld de, $9920
    call PrintString
    call WaitKey
    jp MainMenu
ShowAlias:
    call IncError
    call PersistResult
    call ClearScreen
    ld hl, StrAlias
    ld de, $9840
    call PrintString
    ld hl, StrProbe
    ld de, $98A0
    call PrintString
    ld a, [$C003]
    ld de, $98A7
    call PrintHexByte
    ld hl, StrArrow
    ld de, $98A9
    call PrintString
    ld a, [$C004]
    ld de, $98AC
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9940
    call PrintString
    call WaitKey
    jp MainMenu
FaultScreen:
    call ClearScreen
    ld hl, StrFault
    ld de, $9820
    call PrintString
    ld hl, StrBank
    ld de, $9880
    call PrintString
    ld a, [$C006]
    ld de, $9885
    call PrintHexByte
    ld hl, StrAddr
    ld de, $98A0
    call PrintString
    ld a, [$C008]
    ld de, $98A5
    call PrintHexByte
    ld a, [$C007]
    ld de, $98A7
    call PrintHexByte
    ld hl, StrExp
    ld de, $98E0
    call PrintString
    ld a, [$C003]
    ld de, $98E4
    call PrintHexByte
    ld hl, StrGot
    ld de, $9900
    call PrintString
    ld a, [$C004]
    ld de, $9904
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9980
    call PrintString
    call WaitKey
    jp MainMenu
; Focused suite SRAM integrity control.
RunRam:
    ld a, $01
    ld [$C001], a
    call ResetTestScratch
    call ScanAll
    jp c, RamBad
    ld a, $00
    ld [$C002], a
    jp ShowPass
RamBad:
    ld a, $01
    ld [$C002], a
    call IncError
    call PersistResult
    jp FaultScreen
; Write distinct values to RTC selectors 08-0C and record which SRAM bank changes.
RunValueMap:
    ld a, $02
    ld [$C001], a
    call ResetTestScratch
    call ScanAll
    jp c, RamBad
    ld hl, $C020
    ld b, $19
    ld a, $00
ClearVM:
    ld [hli], a
    dec b
    jr nz, ClearVM
    ld a, $08
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C005], a
    ld a, $11
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C020], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C021], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C022], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C023], a
    ld c, $00
    ld a, [$C020]
    cp $3C
    jp z, VM0B0OK
    ld a, c
    or $01
    ld c, a
VM0B0OK:
    ld a, [$C021]
    cp $C3
    jp z, VM0B1OK
    ld a, c
    or $02
    ld c, a
VM0B1OK:
    ld a, [$C022]
    cp $14
    jp z, VM0B2OK
    ld a, c
    or $04
    ld c, a
VM0B2OK:
    ld a, [$C023]
    cp $00
    jp z, VM0B3OK
    ld a, c
    or $08
    ld c, a
VM0B3OK:
    ld a, c
    ld [$C024], a
    call RestoreCanaries
    ld a, $09
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C005], a
    ld a, $22
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C025], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C026], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C027], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C028], a
    ld c, $00
    ld a, [$C025]
    cp $3C
    jp z, VM1B0OK
    ld a, c
    or $01
    ld c, a
VM1B0OK:
    ld a, [$C026]
    cp $C3
    jp z, VM1B1OK
    ld a, c
    or $02
    ld c, a
VM1B1OK:
    ld a, [$C027]
    cp $14
    jp z, VM1B2OK
    ld a, c
    or $04
    ld c, a
VM1B2OK:
    ld a, [$C028]
    cp $00
    jp z, VM1B3OK
    ld a, c
    or $08
    ld c, a
VM1B3OK:
    ld a, c
    ld [$C029], a
    call RestoreCanaries
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C005], a
    ld a, $05
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C02A], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C02B], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C02C], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C02D], a
    ld c, $00
    ld a, [$C02A]
    cp $3C
    jp z, VM2B0OK
    ld a, c
    or $01
    ld c, a
VM2B0OK:
    ld a, [$C02B]
    cp $C3
    jp z, VM2B1OK
    ld a, c
    or $02
    ld c, a
VM2B1OK:
    ld a, [$C02C]
    cp $14
    jp z, VM2B2OK
    ld a, c
    or $04
    ld c, a
VM2B2OK:
    ld a, [$C02D]
    cp $00
    jp z, VM2B3OK
    ld a, c
    or $08
    ld c, a
VM2B3OK:
    ld a, c
    ld [$C02E], a
    call RestoreCanaries
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C005], a
    ld a, $A7
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C02F], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C030], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C031], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C032], a
    ld c, $00
    ld a, [$C02F]
    cp $3C
    jp z, VM3B0OK
    ld a, c
    or $01
    ld c, a
VM3B0OK:
    ld a, [$C030]
    cp $C3
    jp z, VM3B1OK
    ld a, c
    or $02
    ld c, a
VM3B1OK:
    ld a, [$C031]
    cp $14
    jp z, VM3B2OK
    ld a, c
    or $04
    ld c, a
VM3B2OK:
    ld a, [$C032]
    cp $00
    jp z, VM3B3OK
    ld a, c
    or $08
    ld c, a
VM3B3OK:
    ld a, c
    ld [$C033], a
    call RestoreCanaries
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C005], a
    ld a, $01
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C034], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C035], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C036], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C037], a
    ld c, $00
    ld a, [$C034]
    cp $3C
    jp z, VM4B0OK
    ld a, c
    or $01
    ld c, a
VM4B0OK:
    ld a, [$C035]
    cp $C3
    jp z, VM4B1OK
    ld a, c
    or $02
    ld c, a
VM4B1OK:
    ld a, [$C036]
    cp $14
    jp z, VM4B2OK
    ld a, c
    or $04
    ld c, a
VM4B2OK:
    ld a, [$C037]
    cp $00
    jp z, VM4B3OK
    ld a, c
    or $08
    ld c, a
VM4B3OK:
    ld a, c
    ld [$C038], a
    call RestoreCanaries
    ld a, $00
    ld [$C002], a
    ld a, [$C024]
    or a
    jp z, VMNo0
    ld a, $01
    ld [$C002], a
VMNo0:
    ld a, [$C029]
    or a
    jp z, VMNo1
    ld a, $01
    ld [$C002], a
VMNo1:
    ld a, [$C02E]
    or a
    jp z, VMNo2
    ld a, $01
    ld [$C002], a
VMNo2:
    ld a, [$C033]
    or a
    jp z, VMNo3
    ld a, $01
    ld [$C002], a
VMNo3:
    ld a, [$C038]
    or a
    jp z, VMNo4
    ld a, $01
    ld [$C002], a
VMNo4:
    ld a, [$C002]
    or a
    jp z, VMNoErr
    call IncError
VMNoErr:
    call PersistResult
    call ClearScreen
    ld hl, StrValueMap
    ld de, $9800
    call PrintString
    ld a, $08
    ld de, $9840
    call PrintHexByte
    ld a, $11
    ld de, $9843
    call PrintHexByte
    ld hl, StrMask
    ld de, $9846
    call PrintString
    ld a, [$C024]
    ld de, $984B
    call PrintHexByte
    ld a, $09
    ld de, $9860
    call PrintHexByte
    ld a, $22
    ld de, $9863
    call PrintHexByte
    ld hl, StrMask
    ld de, $9866
    call PrintString
    ld a, [$C029]
    ld de, $986B
    call PrintHexByte
    ld a, $0A
    ld de, $9880
    call PrintHexByte
    ld a, $05
    ld de, $9883
    call PrintHexByte
    ld hl, StrMask
    ld de, $9886
    call PrintString
    ld a, [$C02E]
    ld de, $988B
    call PrintHexByte
    ld a, $0B
    ld de, $98A0
    call PrintHexByte
    ld a, $A7
    ld de, $98A3
    call PrintHexByte
    ld hl, StrMask
    ld de, $98A6
    call PrintString
    ld a, [$C033]
    ld de, $98AB
    call PrintHexByte
    ld a, $0C
    ld de, $98C0
    call PrintHexByte
    ld a, $01
    ld de, $98C3
    call PrintHexByte
    ld hl, StrMask
    ld de, $98C6
    call PrintString
    ld a, [$C038]
    ld de, $98CB
    call PrintHexByte
    ld hl, StrMaskHint
    ld de, $9920
    call PrintString
    ld hl, StrAnyKey
    ld de, $9980
    call PrintString
    call WaitKey
    jp MainMenu
; Execute the read-only Pokemon-style GetClock probe.
RunGetClock:
    ld a, $03
    ld [$C001], a
    call ResetTestScratch
    call PokemonGetClock
    call ScanAll
    jp c, RamBad
    ld a, $00
    ld [$C002], a
    call PersistResult
    call ClearScreen
    ld hl, StrGetClock
    ld de, $9800
    call PrintString
    ld hl, StrS
    ld de, $9860
    call PrintString
    ld a, [$C010]
    ld de, $9864
    call PrintHexByte
    ld hl, StrM
    ld de, $9880
    call PrintString
    ld a, [$C011]
    ld de, $9884
    call PrintHexByte
    ld hl, StrH
    ld de, $98A0
    call PrintString
    ld a, [$C012]
    ld de, $98A4
    call PrintHexByte
    ld hl, StrDL
    ld de, $98C0
    call PrintString
    ld a, [$C013]
    ld de, $98C4
    call PrintHexByte
    ld hl, StrDH
    ld de, $98E0
    call PrintString
    ld a, [$C014]
    ld de, $98E4
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9960
    call PrintString
    call WaitKey
    jp MainMenu
; Execute the helper probe that also checks the HALT-branch scratch writes.
RunUGetClock:
    ld a, $04
    ld [$C001], a
    call ResetTestScratch
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $00
    ld [$B7EF], a
    ld [$B7F0], a
    call CloseSRAM
    call Pokemon_UGetClock
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [$B7EF]
    ld [$C03B], a
    ld a, [$B7F0]
    ld [$C03C], a
    call CloseSRAM
    call ScanAll
    jp c, RamBad
    ld a, $00
    ld [$C002], a
    call PersistResult
    call ClearScreen
    ld hl, StrUGetClock
    ld de, $9800
    call PrintString
    ld hl, StrHaltScratch
    ld de, $9880
    call PrintString
    ld a, [$C03B]
    ld de, $98C5
    call PrintHexByte
    ld a, [$C03C]
    ld de, $98C8
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9960
    call PrintString
    call WaitKey
    jp MainMenu
; Probe the real Pokemon-style StartRTC operation while watching bank0:A000.
RunStartRTC:
    ld a, $05
    ld [$C001], a
    call ResetTestScratch
    ld a, $0C
    ld [$C005], a
    ld a, $40
    ld [$C003], a
    ld [$C039], a
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $40
    ld [SRAM_WINDOW], a
    call CloseSRAM
    call PokemonStartRTC
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C004], a
    ld [$C03A], a
    ld a, $3C
    ld [SRAM_WINDOW], a
    call CloseSRAM
    ld a, [$C004]
    cp $40
    jp nz, RunStartRTCBad
    ld a, $00
    ld [$C002], a
    jp ShowPass
RunStartRTCBad:
    ld a, $01
    ld [$C002], a
    jp ShowAlias
; Probe the real Pokemon-style StopRTC operation while watching bank0:A000.
RunStopRTC:
    ld a, $06
    ld [$C001], a
    call ResetTestScratch
    ld a, $0C
    ld [$C005], a
    ld a, $00
    ld [$C003], a
    ld [$C039], a
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $00
    ld [SRAM_WINDOW], a
    call CloseSRAM
    call PokemonStopRTC
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C004], a
    ld [$C03A], a
    ld a, $3C
    ld [SRAM_WINDOW], a
    call CloseSRAM
    ld a, [$C004]
    cp $00
    jp nz, RunStopRTCBad
    ld a, $00
    ld [$C002], a
    jp ShowPass
RunStopRTCBad:
    ld a, $01
    ld [$C002], a
    jp ShowAlias
; Probe the real Pokemon-style SaveRTC operation while watching bank0:A000.
RunSaveRTC:
    ld a, $07
    ld [$C001], a
    call ResetTestScratch
    ld a, $0C
    ld [$C005], a
    ld a, $80
    ld [$C003], a
    ld [$C039], a
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $80
    ld [SRAM_WINDOW], a
    call CloseSRAM
    call PokemonSaveRTC
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C004], a
    ld [$C03A], a
    ld a, $3C
    ld [SRAM_WINDOW], a
    call CloseSRAM
    ld a, [$C004]
    cp $80
    jp nz, RunSaveRTCBad
    ld a, $00
    ld [$C002], a
    jp ShowPass
RunSaveRTCBad:
    ld a, $01
    ld [$C002], a
    jp ShowAlias
; Run the core _GetClock -> GetClock -> StartRTC sequence used during startup.
RunStartClock:
    ld a, $08
    ld [$C001], a
    call ResetTestScratch
    ld a, $0C
    ld [$C005], a
    ld a, $40
    ld [$C003], a
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $40
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [$B7EF], a
    ld [$B7F0], a
    call CloseSRAM
    call Pokemon_UGetClock
    call PokemonGetClock
    call PokemonStartRTC
    call EnableRAM
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C004], a
    ld a, [$B7EF]
    ld [$C03B], a
    ld a, [$B7F0]
    ld [$C03C], a
    ld a, $3C
    ld [SRAM_WINDOW], a
    call CloseSRAM
    ld a, [$C004]
    cp $40
    jp nz, StartClockBad
    ld a, $00
    ld [$C002], a
    call PersistResult
    call ClearScreen
    ld hl, StrStartClock
    ld de, $9800
    call PrintString
    ld hl, StrPass
    ld de, $9860
    call PrintString
    ld hl, StrHaltScratch
    ld de, $98C0
    call PrintString
    ld a, [$C03B]
    ld de, $9905
    call PrintHexByte
    ld a, [$C03C]
    ld de, $9908
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9980
    call PrintString
    call WaitKey
    jp MainMenu
StartClockBad:
    ld a, $01
    ld [$C002], a
    jp ShowAlias
RunView:
    ld a, $09
    ld [$C001], a
    call PokemonGetClock
    call ClearScreen
    ld hl, StrRTCView
    ld de, $9800
    call PrintString
    ld hl, StrS
    ld de, $9860
    call PrintString
    ld a, [$C010]
    ld de, $9864
    call PrintHexByte
    ld hl, StrM
    ld de, $9880
    call PrintString
    ld a, [$C011]
    ld de, $9884
    call PrintHexByte
    ld hl, StrH
    ld de, $98A0
    call PrintString
    ld a, [$C012]
    ld de, $98A4
    call PrintHexByte
    ld hl, StrDL
    ld de, $98C0
    call PrintString
    ld a, [$C013]
    ld de, $98C4
    call PrintHexByte
    ld hl, StrDH
    ld de, $98E0
    call PrintString
    ld a, [$C014]
    ld de, $98E4
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9960
    call PrintString
    call WaitKey
    jp MainMenu
RunStatus:
    call ClearScreen
    ld hl, StrStatus
    ld de, $9800
    call PrintString
    ld hl, StrBoot
    ld de, $9840
    call PrintString
    ld a, [$C106]
    ld de, $9845
    call PrintHexByte
    ld a, [$C105]
    ld de, $9847
    call PrintHexByte
    ld hl, StrErrors
    ld de, $9860
    call PrintString
    ld a, [$C108]
    ld de, $9866
    call PrintHexByte
    ld a, [$C107]
    ld de, $9868
    call PrintHexByte
    ld hl, StrLast
    ld de, $98A0
    call PrintString
    ld a, [$C109]
    ld de, $98A5
    call PrintHexByte
    ld hl, StrResult
    ld de, $98C0
    call PrintString
    ld a, [$C10A]
    ld de, $98C7
    call PrintHexByte
    ld hl, StrSel
    ld de, $98E0
    call PrintString
    ld a, [$C10B]
    ld de, $98E4
    call PrintHexByte
    ld hl, StrProbe
    ld de, $9920
    call PrintString
    ld a, [$C10C]
    ld de, $9927
    call PrintHexByte
    ld hl, StrArrow
    ld de, $9929
    call PrintString
    ld a, [$C10D]
    ld de, $992C
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $99A0
    call PrintString
    call WaitKey
    jp MainMenu
; Top-level interactive menu.
MainMenu:
    ; Preserve the current menu cursor when returning from an option.
    ; Five NOPs keep the binary layout stable relative to the previous reset sequence.
    nop
    nop
    nop
    nop
    nop
MenuRender:
    call ClearScreen
    ld hl, StrTitle
    ld de, $9800
    call PrintString
    ld hl, StrVersion
    ld de, $9820
    call PrintString
    ld hl, StrM0
    ld de, $9860
    call PrintString
    ld hl, StrM1
    ld de, $9880
    call PrintString
    ld hl, StrM2
    ld de, $98A0
    call PrintString
    ld hl, StrM3
    ld de, $98C0
    call PrintString
    ld hl, StrM4
    ld de, $98E0
    call PrintString
    ld hl, StrM5
    ld de, $9900
    call PrintString
    ld hl, StrM6
    ld de, $9920
    call PrintString
    ld hl, StrM7
    ld de, $9940
    call PrintString
    ld hl, StrM8
    ld de, $9960
    call PrintString
    ld hl, StrM9
    ld de, $9980
    call PrintString
    ld hl, StrFooter
    ld de, $99E0
    call PrintString
    ld hl, $9860
    ld a, [$C000]
    ld b, a
MarkLoop:
    ld a, b
    or a
    jp z, MarkDone
    ld de, $0020
    add hl, de
    dec b
    jr MarkLoop
MarkDone:
    ld a, $3E
    ld d, h
    ld e, l
    call PutTileA
MenuWait:
    call WaitKey
    ld b, a
    ld a, b
    and $04
    jp nz, MenuUp
    ld a, b
    and $08
    jp nz, MenuDown
    ld a, b
    and $10
    jp nz, MenuRun
    jp MenuWait
MenuUp:
    ld a, [$C000]
    or a
    jp z, MenuUpWrap
    dec a
    ld [$C000], a
    jp MenuRender
MenuUpWrap:
    ld a, $09
    ld [$C000], a
    jp MenuRender
MenuDown:
    ld a, [$C000]
    inc a
    cp $0A
    jp c, MenuDownStore
    ld a, $00
MenuDownStore:
    ld [$C000], a
    jp MenuRender
MenuRun:
    ld a, [$C000]
    cp $00
    jp z, RunRam
    cp $01
    jp z, RunValueMap
    cp $02
    jp z, RunGetClock
    cp $03
    jp z, RunUGetClock
    cp $04
    jp z, RunStartRTC
    cp $05
    jp z, RunStopRTC
    cp $06
    jp z, RunSaveRTC
    cp $07
    jp z, RunStartClock
    cp $08
    jp z, RunView
    cp $09
    jp z, RunStatus
    jp MenuRender
StrTitle:
    db "X7POKERTC", 0
StrVersion:
    db "MIMIC v1.0.0  ", 0
StrNoState:
    db "NO VALID SRAM STATE", 0
StrInit:
    db "A = INITIALIZE", 0
StrOwnRTC:
    db "USES ITS OWN RTC", 0
StrM0:
    db "  RAM AUDIT", 0
StrM1:
    db "  VALUE MAP", 0
StrM2:
    db "  POKE GET CLOCK", 0
StrM3:
    db "  POKE _GETCLOCK", 0
StrM4:
    db "  POKE START RTC", 0
StrM5:
    db "  POKE STOP RTC", 0
StrM6:
    db "  POKE SAVE RTC", 0
StrM7:
    db "  POKE STARTCLOCK", 0
StrM8:
    db "  VIEW RTC", 0
StrM9:
    db "  STATUS", 0
StrFooter:
    db "UP/DN A=RUN", 0
StrSRAMCleared:
    db "SRAM CLEARED", 0
StrRTCUnchanged:
    db "RTC NOT TOUCHED", 0
StrRestartRequired:
    db "RESTART REQUIRED", 0
StrPass:
    db "PASS - SRAM INTACT", 0
StrAlias:
    db "RTC->SRAM ALIAS", 0
StrFault:
    db "SRAM FAULT", 0
StrProbe:
    db "PROBE ", 0
StrArrow:
    db "->", 0
StrBank:
    db "BANK ", 0
StrAddr:
    db "ADDR ", 0
StrExp:
    db "EXP ", 0
StrGot:
    db "GOT ", 0
StrAnyKey:
    db "PRESS ANY KEY", 0
StrValueMap:
    db "VALUE MAP", 0
StrMask:
    db "MASK ", 0
StrMaskHint:
    db "BITS=B0 B1 B2 B3", 0
StrGetClock:
    db "POKE GET CLOCK", 0
StrUGetClock:
    db "POKE _GETCLOCK", 0
StrHaltScratch:
    db "HALT SCRATCH", 0
StrS:
    db "S ", 0
StrM:
    db "M ", 0
StrH:
    db "H ", 0
StrDL:
    db "DL ", 0
StrDH:
    db "DH ", 0
StrStartClock:
    db "POKE STARTCLOCK", 0
StrRTCView:
    db "RTC VIA POKE READ", 0
StrStatus:
    db "POKERTC STATUS", 0
StrBoot:
    db "BOOT ", 0
StrErrors:
    db "ERRORS ", 0
StrLast:
    db "LAST ", 0
StrResult:
    db "RESULT ", 0
StrSel:
    db "SEL ", 0
FontData:
    INCBIN "assets/font.bin"

; Force a 2 MiB / 128-bank ROM. rgblink fills all gaps with $FF.
SECTION "ROM size sentinel", ROMX[$7FFF], BANK[127]
    db $FF
