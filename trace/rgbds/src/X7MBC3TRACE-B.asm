; Canonical RGBDS source matching the shipped v1.0.0 ROM bytes.
; Functional behavior and persistent formats are intentionally unchanged.

INCLUDE "../../common/rgbds/hardware.inc"

SECTION "Timer interrupt vector", ROM0[$0050]
    jp TimerISR

SECTION "Cartridge entry/header", ROM0[$0100]
    nop
    jp Start
    db $CE, $ED, $66, $66, $CC, $0D, $00, $0B, $03, $73, $00, $83, $00, $0C, $00, $0D, $00, $08, $11, $1F, $88, $89, $00, $0E, $DC, $CC, $6E, $E6, $DD, $DD, $D9, $99, $BB, $BB, $67, $63, $6E, $0E, $EC, $CC, $DD, $DC, $99, $9F, $BB, $B9, $33, $3E
    db "X7MBC3TRACE-B"
    ds 2, 0
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
    ld [$C008], a
    ld [$C009], a
    ld [$C00A], a
    ld [$C00B], a
    ld [$C00F], a
    ld [$C015], a
    ld [$C016], a
    ld [$C017], a
    ld [$C018], a
    ld [$C019], a
    ld [$C01A], a
    ld [$C01B], a
    ld [$C01C], a
    ld [$C00E], a
    ld [$C021], a
    ld [$C022], a
    ld [$C023], a
    ld [$C024], a
    ld [$C025], a
    ld [$C026], a
    ld [$C027], a
    ld [$C028], a
    ld a, $05
    ld [$C01F], a
    ld a, $01
    ld [$C020], a
    ld a, $FF
    ld [$C007], a
    ld [$C010], a
    ld [$C011], a
    ld [$C012], a
    ld [$C013], a
    ld [$C014], a
    call InitVideo
    call EnableRAM
    call LoadValidSuper
    jp nc, HaveState
    call FirstRun
HaveState:
    call LoadValidStats
    jp c, MetaFaultScreen
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
ClrVRAM0Loop:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClrVRAM0Loop
    ld a, $01
    ldh [$FF4F], a
    ld hl, $8000
    ld bc, $2000
    ld d, $00
ClrVRAM1Loop:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClrVRAM1Loop
    ld a, $00
    ldh [$FF4F], a
    ld hl, FontData
    ld de, $8000
    ld bc, $0800
FontCopyLoop:
    ld a, [hli]
    ld [de], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, FontCopyLoop
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
WaitVB1:
    ldh a, [$FF44]
    cp $90
    jr c, WaitVBlank
    ret
WaitVRAM:
WaitVRAMLoop:
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
    jp z, ClearScreenLCDOff
    call WaitVBlank
    ld a, $00
    ldh [$FF40], a
ClearScreenLCDOff:
    ld hl, $9800
    ld bc, $0400
    ld d, $20
ClearScreenLoop:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearScreenLoop
    ld a, $91
    ldh [$FF40], a
    ret
PrintString:
PrintStringLoop:
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
PrintDec2A:
    ld b, $00
PrintDec2Loop:
    cp $0A
    jr c, PrintDec2Done
    sub $0A
    inc b
    jr PrintDec2Loop
PrintDec2Done:
    ld c, a
    ld a, b
    add a, $30
    call PutTileA
    inc de
    ld a, c
    add a, $30
    call PutTileA
    ret
IncLoop32:
    ld a, [$C008]
    inc a
    ld [$C008], a
    ret nz
    ld a, [$C009]
    inc a
    ld [$C009], a
    ret nz
    ld a, [$C00A]
    inc a
    ld [$C00A], a
    ret nz
    ld a, [$C00B]
    inc a
    ld [$C00B], a
    ret
IncTick32:
    ld a, [$C019]
    inc a
    ld [$C019], a
    ret nz
    ld a, [$C01A]
    inc a
    ld [$C01A], a
    ret nz
    ld a, [$C01B]
    inc a
    ld [$C01B], a
    ret nz
    ld a, [$C01C]
    inc a
    ld [$C01C], a
    ret
TimerISR:
    push af
    call IncTick32
    ld a, [$C015]
    inc a
    cp $40
    jp c, TimerNoSecond
    ld a, $00
    ld [$C015], a
    ld a, [$C016]
    inc a
    cp $3C
    jp c, TimerStoreSec
    ld a, $00
    ld [$C016], a
    ld a, [$C017]
    inc a
    cp $3C
    jp c, TimerStoreMin
    ld a, $00
    ld [$C017], a
    ld a, [$C018]
    inc a
    cp $64
    jp c, TimerStoreHour
    ld a, $00
TimerStoreHour:
    ld [$C018], a
    jp TimerMarkDirty
TimerStoreMin:
    ld [$C017], a
    jp TimerMarkDirty
TimerStoreSec:
    ld [$C016], a
    jp TimerMarkDirty
TimerNoSecond:
    ld [$C015], a
    and $07
    jp nz, TimerISREnd
TimerMarkDirty:
    ld a, $01
    ld [$C00F], a
TimerISREnd:
    pop af
    reti
ResetStressCounters:
    ld a, $00
    ld [$C008], a
    ld [$C009], a
    ld [$C00A], a
    ld [$C00B], a
    ld [$C015], a
    ld [$C016], a
    ld [$C017], a
    ld [$C018], a
    ld [$C019], a
    ld [$C01A], a
    ld [$C01B], a
    ld [$C01C], a
    ld [$C00F], a
    ret
StartStressClock:
    di
    call ResetStressCounters
    ld a, $00
    ldh [$FF07], a
    ld a, $C0
    ldh [$FF06], a
    ldh [$FF05], a
    ldh a, [$FF0F]
    and $FB
    ldh [$FF0F], a
    ld a, $04
    ld [$FFFF], a
    ld a, $04
    ldh [$FF07], a
    ei
    ret
StopStressClock:
    di
    ld a, $00
    ldh [$FF07], a
    ld [$FFFF], a
    ret
DrawStressHUD:
    ld a, [$C018]
    ld de, $98E5
    call PrintDec2A
    ld a, [$C017]
    ld de, $98E8
    call PrintDec2A
    ld a, [$C016]
    ld de, $98EB
    call PrintDec2A
    ld a, [$C015]
    ld e, a
    ld d, $00
    ld hl, MsTable
    add hl, de
    add hl, de
    add hl, de
    add hl, de
    ld de, $98EE
    ld a, [hli]
    call PutTileA
    inc de
    ld a, [hli]
    call PutTileA
    inc de
    ld a, [hli]
    call PutTileA
    inc de
    ld a, [$C00B]
    ld de, $9926
    call PrintHexByte
    ld a, [$C00A]
    ld de, $9928
    call PrintHexByte
    ld a, [$C009]
    ld de, $992A
    call PrintHexByte
    ld a, [$C008]
    ld de, $992C
    call PrintHexByte
    ret
MaybeUpdateStressHUD:
    ld a, [$C00E]
    or a
    ret nz
    ld a, [$C00F]
    or a
    ret z
    ld a, $00
    ld [$C00F], a
    call DrawStressHUD
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
WaitRelease:
    call WaitInputFrame
    call ReadKeys
    or a
    jr nz, WaitKey
    call WaitInputFrame
    call ReadKeys
    or a
    jr nz, WaitKey
WaitPress:
    call WaitInputFrame
    call ReadKeys
    or a
    jr z, WaitPress
    ld c, a
    call WaitInputFrame
    call ReadKeys
    or a
    jr z, WaitPress
    cp c
    jr nz, WaitPress
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
SelectBankA:
    ld [MBC_RAM_RTC_SELECT], a
    ret
LatchRTC:
    ld a, $00
    ld [MBC_LATCH], a
    ld a, $01
    ld [MBC_LATCH], a
    ret
ReadRTCSnapshot:
    call LatchRTC
    ld a, $08
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C010], a
    ld a, $09
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C011], a
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C012], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C013], a
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C014], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
LoadSuperBank:
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $A100
    ld de, $C100
    ld b, $40
LoadSuperCopy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, LoadSuperCopy
    ld a, [$C100]
    cp $58
    jp nz, LoadSuperBad
    ld a, [$C101]
    cp $37
    jp nz, LoadSuperBad
    ld a, [$C102]
    cp $54
    jp nz, LoadSuperBad
    ld a, [$C103]
    cp $31
    jp nz, LoadSuperBad
    ld a, [$C104]
    cp $42
    jp nz, LoadSuperBad
    ld a, [$C105]
    cp $02
    jp nz, LoadSuperBad
    call CalcSuperChecksum
    ld a, e
    ld hl, $C13E
    cp [hl]
    jp nz, LoadSuperBad
    inc hl
    ld a, d
    cp [hl]
    jp nz, LoadSuperBad
    or a
    ret
LoadSuperBad:
    scf
    ret
LoadValidSuper:
    ld a, $00
    call LoadSuperBank
    jp nc, SuperFrom0
    ld a, $01
    call LoadSuperBank
    jp nc, SuperFrom1
    scf
    ret
SuperFrom0:
    ld a, $00
    ld [$C00D], a
    or a
    ret
SuperFrom1:
    ld a, $01
    ld [$C00D], a
    or a
    ret
CalcSuperChecksum:
    ld hl, $C100
    ld de, MBC_RAM_ENABLE
    ld b, $3E
CalcSCLoop:
    ld a, [hli]
    add a, e
    ld e, a
    jr nc, CalcSCNoCarry
    inc d
CalcSCNoCarry:
    dec b
    jr nz, CalcSCLoop
    ret
UpdateSuperChecksum:
    call CalcSuperChecksum
    ld a, e
    ld [$C13E], a
    ld a, d
    ld [$C13F], a
    ret
SaveSuper:
    call UpdateSuperChecksum
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C100
    ld de, $A100
    ld b, $40
SaveSuper0Loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveSuper0Loop
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C100
    ld de, $A100
    ld b, $40
SaveSuper1Loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveSuper1Loop
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
Inc16AtHL:
    inc [hl]
    ret nz
    inc hl
    inc [hl]
    ret
CalcStatsChecksum:
    ld hl, $C200
    ld de, MBC_RAM_ENABLE
    ld b, $7E
CalcStatsLoop:
    ld a, [hli]
    add a, e
    ld e, a
    jr nc, CalcStatsNoCarry
    inc d
CalcStatsNoCarry:
    dec b
    jr nz, CalcStatsLoop
    ret
LoadStatsBank:
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $A1A0
    ld de, $C200
    ld b, $80
LoadStatsCopy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, LoadStatsCopy
    ld a, [$C200]
    cp $58
    jp nz, LoadStatsBad
    ld a, [$C201]
    cp $37
    jp nz, LoadStatsBad
    ld a, [$C202]
    cp $53
    jp nz, LoadStatsBad
    ld a, [$C203]
    cp $31
    jp nz, LoadStatsBad
    ld a, [$C204]
    cp $42
    jp nz, LoadStatsBad
    ld a, [$C205]
    cp $02
    jp nz, LoadStatsBad
    call CalcStatsChecksum
    ld a, e
    ld hl, $C27E
    cp [hl]
    jp nz, LoadStatsBad
    inc hl
    ld a, d
    cp [hl]
    jp nz, LoadStatsBad
    or a
    ret
LoadStatsBad:
    scf
    ret
LoadValidStats:
    ld a, $00
    call LoadStatsBank
    ret nc
    ld a, $01
    call LoadStatsBank
    ret
SaveStats:
    call CalcStatsChecksum
    ld a, e
    ld [$C27E], a
    ld a, d
    ld [$C27F], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C200
    ld de, $A1A0
    ld b, $80
SaveStats0Loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveStats0Loop
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C200
    ld de, $A1A0
    ld b, $80
SaveStats1Loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveStats1Loop
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
InitStats:
    ld hl, $C200
    ld b, $80
    ld a, $00
InitStatsZero:
    ld [hli], a
    dec b
    jr nz, InitStatsZero
    ld a, $58
    ld [$C200], a
    ld a, $37
    ld [$C201], a
    ld a, $53
    ld [$C202], a
    ld a, $31
    ld [$C203], a
    ld a, $42
    ld [$C204], a
    ld a, $02
    ld [$C205], a
    call SaveStats
    ret
UpdateStressStats:
    ld a, [$C119]
    cp $02
    jp z, StatsBank
    cp $03
    jp z, StatsSig
    cp $05
    jp z, StatsRTC
    cp $06
    jp z, StatsLatch
    ret
StatsBank:
    ld a, [$C00E]
    or a
    jp z, StatsBankNormal
    cp $01
    jp z, StatsBankBareMax
    jp StatsBankBareFixed
StatsBankNormal:
    ld hl, $C206
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C208]
    add a, b
    ld [$C208], a
    ld a, [$C009]
    ld b, a
    ld a, [$C209]
    adc a, b
    ld [$C209], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C20A]
    adc a, b
    ld [$C20A], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C20B]
    adc a, b
    ld [$C20B], a
    ld a, [$C019]
    ld b, a
    ld a, [$C20C]
    add a, b
    ld [$C20C], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C20D]
    adc a, b
    ld [$C20D], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C20E]
    adc a, b
    ld [$C20E], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C20F]
    adc a, b
    ld [$C20F], a
    call SaveStats
    ret
StatsBankBareMax:
    ld hl, $C210
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C212]
    add a, b
    ld [$C212], a
    ld a, [$C009]
    ld b, a
    ld a, [$C213]
    adc a, b
    ld [$C213], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C214]
    adc a, b
    ld [$C214], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C215]
    adc a, b
    ld [$C215], a
    ld a, [$C019]
    ld b, a
    ld a, [$C216]
    add a, b
    ld [$C216], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C217]
    adc a, b
    ld [$C217], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C218]
    adc a, b
    ld [$C218], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C219]
    adc a, b
    ld [$C219], a
    call SaveStats
    ret
StatsBankBareFixed:
    ld hl, $C21A
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C21C]
    add a, b
    ld [$C21C], a
    ld a, [$C009]
    ld b, a
    ld a, [$C21D]
    adc a, b
    ld [$C21D], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C21E]
    adc a, b
    ld [$C21E], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C21F]
    adc a, b
    ld [$C21F], a
    ld a, [$C019]
    ld b, a
    ld a, [$C220]
    add a, b
    ld [$C220], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C221]
    adc a, b
    ld [$C221], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C222]
    adc a, b
    ld [$C222], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C223]
    adc a, b
    ld [$C223], a
    call SaveStats
    ret
StatsSig:
    ld a, [$C00E]
    or a
    jp z, StatsSigNormal
    cp $01
    jp z, StatsSigBareMax
    jp StatsSigBareFixed
StatsSigNormal:
    ld hl, $C224
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C226]
    add a, b
    ld [$C226], a
    ld a, [$C009]
    ld b, a
    ld a, [$C227]
    adc a, b
    ld [$C227], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C228]
    adc a, b
    ld [$C228], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C229]
    adc a, b
    ld [$C229], a
    ld a, [$C019]
    ld b, a
    ld a, [$C22A]
    add a, b
    ld [$C22A], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C22B]
    adc a, b
    ld [$C22B], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C22C]
    adc a, b
    ld [$C22C], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C22D]
    adc a, b
    ld [$C22D], a
    call SaveStats
    ret
StatsSigBareMax:
    ld hl, $C22E
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C230]
    add a, b
    ld [$C230], a
    ld a, [$C009]
    ld b, a
    ld a, [$C231]
    adc a, b
    ld [$C231], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C232]
    adc a, b
    ld [$C232], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C233]
    adc a, b
    ld [$C233], a
    ld a, [$C019]
    ld b, a
    ld a, [$C234]
    add a, b
    ld [$C234], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C235]
    adc a, b
    ld [$C235], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C236]
    adc a, b
    ld [$C236], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C237]
    adc a, b
    ld [$C237], a
    call SaveStats
    ret
StatsSigBareFixed:
    ld hl, $C238
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C23A]
    add a, b
    ld [$C23A], a
    ld a, [$C009]
    ld b, a
    ld a, [$C23B]
    adc a, b
    ld [$C23B], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C23C]
    adc a, b
    ld [$C23C], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C23D]
    adc a, b
    ld [$C23D], a
    ld a, [$C019]
    ld b, a
    ld a, [$C23E]
    add a, b
    ld [$C23E], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C23F]
    adc a, b
    ld [$C23F], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C240]
    adc a, b
    ld [$C240], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C241]
    adc a, b
    ld [$C241], a
    call SaveStats
    ret
StatsRTC:
    ld a, [$C00E]
    or a
    jp z, StatsRTCNormal
    cp $01
    jp z, StatsRTCBareMax
    jp StatsRTCBareFixed
StatsRTCNormal:
    ld hl, $C242
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C244]
    add a, b
    ld [$C244], a
    ld a, [$C009]
    ld b, a
    ld a, [$C245]
    adc a, b
    ld [$C245], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C246]
    adc a, b
    ld [$C246], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C247]
    adc a, b
    ld [$C247], a
    ld a, [$C019]
    ld b, a
    ld a, [$C248]
    add a, b
    ld [$C248], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C249]
    adc a, b
    ld [$C249], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C24A]
    adc a, b
    ld [$C24A], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C24B]
    adc a, b
    ld [$C24B], a
    call SaveStats
    ret
StatsRTCBareMax:
    ld hl, $C24C
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C24E]
    add a, b
    ld [$C24E], a
    ld a, [$C009]
    ld b, a
    ld a, [$C24F]
    adc a, b
    ld [$C24F], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C250]
    adc a, b
    ld [$C250], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C251]
    adc a, b
    ld [$C251], a
    ld a, [$C019]
    ld b, a
    ld a, [$C252]
    add a, b
    ld [$C252], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C253]
    adc a, b
    ld [$C253], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C254]
    adc a, b
    ld [$C254], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C255]
    adc a, b
    ld [$C255], a
    call SaveStats
    ret
StatsRTCBareFixed:
    ld hl, $C256
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C258]
    add a, b
    ld [$C258], a
    ld a, [$C009]
    ld b, a
    ld a, [$C259]
    adc a, b
    ld [$C259], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C25A]
    adc a, b
    ld [$C25A], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C25B]
    adc a, b
    ld [$C25B], a
    ld a, [$C019]
    ld b, a
    ld a, [$C25C]
    add a, b
    ld [$C25C], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C25D]
    adc a, b
    ld [$C25D], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C25E]
    adc a, b
    ld [$C25E], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C25F]
    adc a, b
    ld [$C25F], a
    call SaveStats
    ret
StatsLatch:
    ld a, [$C00E]
    or a
    jp z, StatsLatchNormal
    cp $01
    jp z, StatsLatchBareMax
    jp StatsLatchBareFixed
StatsLatchNormal:
    ld hl, $C260
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C262]
    add a, b
    ld [$C262], a
    ld a, [$C009]
    ld b, a
    ld a, [$C263]
    adc a, b
    ld [$C263], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C264]
    adc a, b
    ld [$C264], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C265]
    adc a, b
    ld [$C265], a
    ld a, [$C019]
    ld b, a
    ld a, [$C266]
    add a, b
    ld [$C266], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C267]
    adc a, b
    ld [$C267], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C268]
    adc a, b
    ld [$C268], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C269]
    adc a, b
    ld [$C269], a
    call SaveStats
    ret
StatsLatchBareMax:
    ld hl, $C26A
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C26C]
    add a, b
    ld [$C26C], a
    ld a, [$C009]
    ld b, a
    ld a, [$C26D]
    adc a, b
    ld [$C26D], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C26E]
    adc a, b
    ld [$C26E], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C26F]
    adc a, b
    ld [$C26F], a
    ld a, [$C019]
    ld b, a
    ld a, [$C270]
    add a, b
    ld [$C270], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C271]
    adc a, b
    ld [$C271], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C272]
    adc a, b
    ld [$C272], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C273]
    adc a, b
    ld [$C273], a
    call SaveStats
    ret
StatsLatchBareFixed:
    ld hl, $C274
    call Inc16AtHL
    ld a, [$C008]
    ld b, a
    ld a, [$C276]
    add a, b
    ld [$C276], a
    ld a, [$C009]
    ld b, a
    ld a, [$C277]
    adc a, b
    ld [$C277], a
    ld a, [$C00A]
    ld b, a
    ld a, [$C278]
    adc a, b
    ld [$C278], a
    ld a, [$C00B]
    ld b, a
    ld a, [$C279]
    adc a, b
    ld [$C279], a
    ld a, [$C019]
    ld b, a
    ld a, [$C27A]
    add a, b
    ld [$C27A], a
    ld a, [$C01A]
    ld b, a
    ld a, [$C27B]
    adc a, b
    ld [$C27B], a
    ld a, [$C01B]
    ld b, a
    ld a, [$C27C]
    adc a, b
    ld [$C27C], a
    ld a, [$C01C]
    ld b, a
    ld a, [$C27D]
    adc a, b
    ld [$C27D], a
    call SaveStats
    ret
IncExternalPassStat:
    ld hl, $C112
    call Inc16AtHL
    call SaveSuper
    ret
CalcFaultCapChecksum:
    ld hl, $C180
    ld de, MBC_RAM_ENABLE
    ld b, $5E
CalcFCLoop:
    ld a, [hli]
    add a, e
    ld e, a
    jr nc, CalcFCNoCarry
    inc d
CalcFCNoCarry:
    dec b
    jr nz, CalcFCLoop
    ret
LoadFaultCapBank:
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $A140
    ld de, $C180
    ld b, $60
LoadFCCopy:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, LoadFCCopy
    ld a, [$C180]
    cp $58
    jp nz, LoadFCBad
    ld a, [$C181]
    cp $37
    jp nz, LoadFCBad
    ld a, [$C182]
    cp $46
    jp nz, LoadFCBad
    ld a, [$C183]
    cp $31
    jp nz, LoadFCBad
    ld a, [$C184]
    cp $42
    jp nz, LoadFCBad
    ld a, [$C185]
    cp $02
    jp nz, LoadFCBad
    call CalcFaultCapChecksum
    ld a, e
    ld hl, $C1DE
    cp [hl]
    jp nz, LoadFCBad
    inc hl
    ld a, d
    cp [hl]
    jp nz, LoadFCBad
    or a
    ret
LoadFCBad:
    scf
    ret
LoadFaultCapsule:
    ld a, $00
    call LoadFaultCapBank
    ret nc
    ld a, $01
    call LoadFaultCapBank
    ret
SaveFirstFaultIfEmpty:
    call LoadFaultCapsule
    ret nc
    ld hl, $C180
    ld b, $60
    ld a, $00
FCZero:
    ld [hli], a
    dec b
    jr nz, FCZero
    ld a, $58
    ld [$C180], a
    ld a, $37
    ld [$C181], a
    ld a, $46
    ld [$C182], a
    ld a, $31
    ld [$C183], a
    ld a, $42
    ld [$C184], a
    ld a, $02
    ld [$C185], a
    ld a, [$C114]
    ld [$C186], a
    ld a, [$C115]
    ld [$C187], a
    ld a, [$C10C]
    ld [$C188], a
    ld a, [$C10D]
    ld [$C189], a
    ld a, [$C10E]
    ld [$C18A], a
    ld a, [$C10F]
    ld [$C18B], a
    ld a, [$C108]
    ld [$C18C], a
    ld a, [$C109]
    ld [$C18D], a
    ld a, [$C10A]
    ld [$C18E], a
    ld a, [$C10B]
    ld [$C18F], a
    ld a, [$C110]
    ld [$C190], a
    ld a, [$C111]
    ld [$C191], a
    ld a, [$C116]
    ld [$C192], a
    ld a, [$C117]
    ld [$C193], a
    ld a, $E0
    ld [$C194], a
    ld a, [$C119]
    ld [$C195], a
    ld a, [$C11A]
    ld [$C196], a
    ld a, [$C11B]
    ld [$C197], a
    ld a, [$C11C]
    ld [$C198], a
    ld a, [$C118]
    ld [$C199], a
    ld a, [$C11D]
    ld [$C19A], a
    ld a, [$C11E]
    ld [$C19B], a
    ld a, [$C11F]
    ld [$C19C], a
    ld a, [$C120]
    ld [$C19D], a
    ld a, [$C121]
    ld [$C19E], a
    ld a, [$C007]
    ld [$C19F], a
    ld a, [$C002]
    ld [$C1A0], a
    ld a, [$C003]
    ld [$C1A1], a
    ld a, [$C004]
    ld [$C1A2], a
    ld a, [$C005]
    ld [$C1A3], a
    ld a, [$C006]
    ld [$C1A4], a
    ld a, [$C008]
    ld [$C1A5], a
    ld a, [$C009]
    ld [$C1A6], a
    ld a, [$C00A]
    ld [$C1A7], a
    ld a, [$C00B]
    ld [$C1A8], a
    ld a, [$C019]
    ld [$C1A9], a
    ld a, [$C01A]
    ld [$C1AA], a
    ld a, [$C01B]
    ld [$C1AB], a
    ld a, [$C01C]
    ld [$C1AC], a
    ld a, [$C010]
    ld [$C1AD], a
    ld a, [$C011]
    ld [$C1AE], a
    ld a, [$C012]
    ld [$C1AF], a
    ld a, [$C013]
    ld [$C1B0], a
    ld a, [$C014]
    ld [$C1B1], a
    ld a, [$C024]
    ld [$C1B2], a
    ld a, [$C025]
    ld [$C1B3], a
    ld a, [$C026]
    ld [$C1B4], a
    ld a, [$C027]
    ld [$C1B5], a
    ld a, [$C018]
    ld [$C1B6], a
    ld a, [$C017]
    ld [$C1B7], a
    ld a, [$C016]
    ld [$C1B8], a
    ld a, [$C015]
    ld [$C1B9], a
    ld a, [$C135]
    ld [$C1BA], a
    call CalcFaultCapChecksum
    ld a, e
    ld [$C1DE], a
    ld a, d
    ld [$C1DF], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C180
    ld de, $A140
    ld b, $60
SaveFC0Loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveFC0Loop
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $C180
    ld de, $A140
    ld b, $60
SaveFC1Loop:
    ld a, [hli]
    ld [de], a
    inc de
    dec b
    jr nz, SaveFC1Loop
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    or a
    ret
JournalHasSpace:
    ld a, [$C10F]
    or a
    jp nz, JHSFull
    ld a, [$C10E]
    cp $E8
    jp c, JHSSpace
JHSFull:
    scf
    ret
JHSSpace:
    or a
    ret
MarkJournalFull:
    ld a, [$C106]
    or $04
    ld [$C106], a
    call SaveSuper
    scf
    ret
; Append one checksummed forensic journal record to both SRAM mirrors.
LogEvent:
    ld [$C01D], a
    call JournalHasSpace
    jp c, LogEventFull
    ld hl, $C140
    ld b, $20
    ld a, $00
ClrEventLoop:
    ld [hli], a
    dec b
    jr nz, ClrEventLoop
    ld a, [$C10C]
    ld [$C140], a
    ld a, [$C10D]
    ld [$C141], a
    ld a, [$C01D]
    ld [$C142], a
    ld a, [$C119]
    ld [$C143], a
    ld a, [$C11A]
    ld [$C144], a
    ld a, [$C11B]
    ld [$C145], a
    ld a, [$C11C]
    ld [$C146], a
    ld a, [$C118]
    ld [$C147], a
    ld a, [$C108]
    ld [$C148], a
    ld a, [$C109]
    ld [$C149], a
    ld a, [$C10A]
    ld [$C14A], a
    ld a, [$C10B]
    ld [$C14B], a
    ld a, [$C116]
    ld [$C14C], a
    ld a, [$C117]
    ld [$C14D], a
    ld a, [$C11D]
    ld [$C14E], a
    ld a, [$C11E]
    ld [$C14F], a
    ld a, [$C008]
    ld [$C150], a
    ld a, [$C009]
    ld [$C151], a
    ld a, [$C00A]
    ld [$C152], a
    ld a, [$C00B]
    ld [$C153], a
    ld a, [$C019]
    ld [$C154], a
    ld a, [$C01A]
    ld [$C155], a
    ld a, [$C01B]
    ld [$C156], a
    ld a, [$C01C]
    ld [$C157], a
    ld a, [$C007]
    ld [$C158], a
    ld a, [$C002]
    ld [$C159], a
    ld a, [$C003]
    ld [$C15A], a
    ld a, [$C004]
    ld [$C15B], a
    ld a, [$C005]
    ld [$C15C], a
    ld a, [$C006]
    ld [$C15D], a
    ld hl, $C140
    ld de, MBC_RAM_ENABLE
    ld b, $1E
EventSumLoop:
    ld a, [hli]
    add a, e
    ld e, a
    jr nc, EventSumNoCarry
    inc d
EventSumNoCarry:
    dec b
    jr nz, EventSumLoop
    ld a, e
    ld [$C15E], a
    ld a, d
    ld [$C15F], a
    ld a, [$C10E]
    ld l, a
    ld a, [$C10F]
    ld h, a
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    add hl, hl
    ld de, $A300
    add hl, de
    ld b, h
    ld c, l
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld h, b
    ld l, c
    ld de, $C140
    ld a, $20
    ld [$C01E], a
WriteEvent0Loop:
    ld a, [de]
    ld [hl], a
    inc de
    inc hl
    ld a, [$C01E]
    dec a
    ld [$C01E], a
    jr nz, WriteEvent0Loop
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld h, b
    ld l, c
    ld de, $C140
    ld a, $20
    ld [$C01E], a
WriteEvent1Loop:
    ld a, [de]
    ld [hl], a
    inc de
    inc hl
    ld a, [$C01E]
    dec a
    ld [$C01E], a
    jr nz, WriteEvent1Loop
    ld hl, $C10C
    call Inc16AtHL
    ld hl, $C10E
    call Inc16AtHL
    ld a, [$C10F]
    or a
    jp nz, LogEventSave
    ld a, [$C10E]
    cp $E8
    jp nz, LogEventSave
    ld a, [$C106]
    or $04
    ld [$C106], a
LogEventSave:
    call SaveSuper
    or a
    ret
LogEventFull:
    call MarkJournalFull
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
ScanPatLoop:
    ld a, h
    cp d
    jp z, ScanPatOK
    ld a, h
    xor l
    xor c
    ld e, a
    ld a, [hl]
    cp e
    jp nz, ScanBad
    inc hl
    jr ScanPatLoop
ScanFirstBad:
    ld [$C006], a
    ld a, e
    ld [$C005], a
    jp ScanStoreCommon
ScanBad:
    ld [$C006], a
    ld a, e
    ld [$C005], a
ScanStoreCommon:
    ld a, b
    ld [$C002], a
    ld a, l
    ld [$C003], a
    ld a, h
    ld [$C004], a
    scf
    ret
ScanPatOK:
    or a
    ret
; Audit all deterministic SRAM surveillance regions and stop on the first mismatch.
ScanAllPatterns:
    ld b, $00
    ld c, $31
    ld d, $A1
    ld e, $A1
    call ScanPattern
    ret c
    ld b, $01
    ld c, $42
    ld d, $A1
    ld e, $B2
    call ScanPattern
    ret c
    ld b, $02
    ld c, $6B
    ld d, $C0
    ld e, $24
    call ScanPattern
    ret c
    ld b, $03
    ld c, $C6
    ld d, $C0
    ld e, $30
    call ScanPattern
    ret c
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    or a
    ret
; Initialize deterministic SRAM surveillance patterns and canaries.
InitPatterns:
    ld b, $00
    ld c, $31
    ld d, $A1
    ld e, $A1
    call FillPattern
    ld b, $01
    ld c, $42
    ld d, $A1
    ld e, $B2
    call FillPattern
    ld b, $02
    ld c, $6B
    ld d, $C0
    ld e, $24
    call FillPattern
    ld b, $03
    ld c, $C6
    ld d, $C0
    ld e, $30
    call FillPattern
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
    ld de, $9860
    call PrintString
    ld hl, StrInitA
    ld de, $98A0
    call PrintString
    ld hl, StrInitWarn
    ld de, $98E0
    call PrintString
FirstRunWait:
    call WaitKey
    and $10
    jr z, FirstRunWait
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $A100
    ld bc, $1F00
    ld d, $00
ClearStateBank0:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearStateBank0
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, $A100
    ld bc, $1F00
    ld d, $00
ClearStateBank1:
    ld a, d
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, ClearStateBank1
    call InitPatterns
    ld hl, $C100
    ld b, $40
    ld a, $00
ZeroShadow:
    ld [hli], a
    dec b
    jr nz, ZeroShadow
    ld a, $58
    ld [$C100], a
    ld a, $37
    ld [$C101], a
    ld a, $54
    ld [$C102], a
    ld a, $31
    ld [$C103], a
    ld a, $42
    ld [$C104], a
    ld a, $02
    ld [$C105], a
    ld a, $00
    ld [$C000], a
    ld [$C001], a
    ld [$C002], a
    ld [$C003], a
    ld [$C004], a
    ld [$C005], a
    ld [$C006], a
    ld a, $FF
    ld [$C007], a
    ld a, $01
    ld [$C114], a
    ld a, $00
    ld [$C119], a
    ld a, $05
    ld [$C11A], a
    ld a, $00
    ld [$C11B], a
    ld a, $07
    ld [$C11C], a
    call SaveSuper
    call InitStats
    ld a, $01
    call LogEvent
    call LoadValidSuper
    call LoadValidStats
    ret
MetaFaultScreen:
    call ClearScreen
    ld hl, StrMetaFault
    ld de, $9820
    call PrintString
    ld hl, StrMetaFault2
    ld de, $9880
    call PrintString
    ld hl, StrPowerCopy
    ld de, $98E0
    call PrintString
MetaFaultHold:
    call WaitKey
    jp MetaFaultHold
; Audit deterministic SRAM state at boot before diagnostic RTC activity.
BootAudit:
    ld a, $00
    ld [$C119], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C106]
    and $01
    jp nz, BootAuditExternalCtx
    ld a, $05
    ld [$C11A], a
    ld a, $00
    ld [$C11B], a
    jp BootAuditScan
BootAuditExternalCtx:
    ld a, $04
    ld [$C11A], a
    ld a, $03
    ld [$C11B], a
BootAuditScan:
    call ScanAllPatterns
    jp c, BootFault
    ld hl, $C108
    call Inc16AtHL
    ld hl, $C10A
    call Inc16AtHL
    ld a, [$C106]
    and $01
    jp z, BootNormal
    ld a, [$C106]
    and $FE
    ld [$C106], a
    ld a, $A5
    ld [$C107], a
    ld a, $05
    ld [$C11C], a
    call IncExternalPassStat
    ld a, $03
    call LogEvent
    ret
BootNormal:
    ld a, $05
    ld [$C11A], a
    ld a, $00
    ld [$C11B], a
    ld a, $06
    ld [$C11C], a
    ld a, $55
    ld [$C107], a
    ld a, $02
    call LogEvent
    ret
BootFault:
    ld a, $E0
    ld [$C11C], a
    call RecordFault
    jp FaultScreen
; Capture the first fault and preserve the forensic state needed for later analysis.
RecordFault:
    call StopStressClock
    ld a, $E0
    ld [$C11C], a
    ld a, [$C106]
    or $02
    ld [$C106], a
    ld a, [$C007]
    ld [$C122], a
    ld a, [$C002]
    ld [$C123], a
    ld a, [$C003]
    ld [$C124], a
    ld a, [$C004]
    ld [$C125], a
    ld a, [$C005]
    ld [$C126], a
    ld a, [$C006]
    ld [$C127], a
    ld a, [$C008]
    ld [$C128], a
    ld a, [$C009]
    ld [$C129], a
    ld a, [$C00A]
    ld [$C12A], a
    ld a, [$C00B]
    ld [$C12B], a
    ld a, [$C019]
    ld [$C12C], a
    ld a, [$C01A]
    ld [$C12D], a
    ld a, [$C01B]
    ld [$C12E], a
    ld a, [$C01C]
    ld [$C12F], a
    ld hl, $C110
    call Inc16AtHL
    ld a, $EE
    ld [$C107], a
    ld a, [$C010]
    ld [$C130], a
    ld a, [$C011]
    ld [$C131], a
    ld a, [$C012]
    ld [$C132], a
    ld a, [$C013]
    ld [$C133], a
    ld a, [$C014]
    ld [$C134], a
    call SaveFirstFaultIfEmpty
    ld a, $E0
    call LogEvent
    call SaveSuper
    ret
FaultScreen:
    call ClearScreen
    ld hl, StrFault
    ld de, $9800
    call PrintString
    ld hl, StrBank
    ld de, $9840
    call PrintString
    ld a, [$C002]
    ld de, $9845
    call PrintHexByte
    ld hl, StrAddr
    ld de, $9860
    call PrintString
    ld a, [$C004]
    ld de, $9865
    call PrintHexByte
    ld a, [$C003]
    ld de, $9867
    call PrintHexByte
    ld hl, StrExp
    ld de, $98A0
    call PrintString
    ld a, [$C005]
    ld de, $98A4
    call PrintHexByte
    ld hl, StrGot
    ld de, $98C0
    call PrintString
    ld a, [$C006]
    ld de, $98C4
    call PrintHexByte
    ld hl, StrFirstCap
    ld de, $9920
    call PrintString
    ld hl, StrPowerCopy
    ld de, $9960
    call PrintString
FaultHalt:
    call WaitKey
    jp FaultHalt
; Top-level interactive menu.
MainMenu:
    ld a, [$C106]
    and $04
    jp nz, JournalFullScreen
MainMenuRender:
    call RenderMenu
MainMenuWait:
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
    jp MainMenuWait
MenuUp:
    ld a, [$C000]
    or a
    jp z, MenuUpWrap
    dec a
    ld [$C000], a
    jp MainMenuRender
MenuUpWrap:
    ld a, $07
    ld [$C000], a
    jp MainMenuRender
MenuDown:
    ld a, [$C000]
    inc a
    cp $08
    jp c, MenuDownStore
    ld a, $00
MenuDownStore:
    ld [$C000], a
    jp MainMenuRender
MenuRun:
    ld a, [$C000]
    cp $00
    jp z, RunRamAudit
    cp $01
    jp z, RunSignature
    cp $02
    jp z, RunLatchStress
    cp $03
    jp z, RunRTCStress
    cp $04
    jp z, RunRTCMap
    cp $05
    jp z, ArmPresets
    cp $06
    jp z, ViewRTC
    cp $07
    jp z, ShowStatus
    jp MainMenuRender
JournalFullScreen:
    call ClearScreen
    ld hl, StrJournalFull
    ld de, $9820
    call PrintString
    ld hl, StrJournal480
    ld de, $9860
    call PrintString
    ld hl, StrLoggingFrozen
    ld de, $98A0
    call PrintString
    ld hl, StrCopySRAM
    ld de, $98E0
    call PrintString
    ld hl, StrNewCampaign
    ld de, $9920
    call PrintString
    ld hl, StrAStatus
    ld de, $9980
    call PrintString
JournalFullWait:
    call WaitKey
    and $10
    jp nz, ShowStatus
    jp JournalFullWait
RenderMenu:
    call ClearScreen
    ld hl, StrTitle
    ld de, $9800
    call PrintString
    ld hl, StrBoot
    ld de, $9820
    call PrintString
    ld a, [$C109]
    ld de, $9825
    call PrintHexByte
    ld a, [$C108]
    ld de, $9827
    call PrintHexByte
    ld hl, StrSel
    ld de, $982B
    call PrintString
    ld a, [$C000]
    ld de, $982F
    call PrintHexByte
    ld hl, StrMenu0
    ld de, $9860
    call PrintString
    ld hl, StrMenu1
    ld de, $9880
    call PrintString
    ld hl, StrMenu2
    ld de, $98A0
    call PrintString
    ld hl, StrMenu3
    ld de, $98C0
    call PrintString
    ld hl, StrMenu4
    ld de, $98E0
    call PrintString
    ld hl, StrMenu5
    ld de, $9900
    call PrintString
    ld hl, StrMenu6
    ld de, $9920
    call PrintString
    ld hl, StrMenu7
    ld de, $9940
    call PrintString
    ld hl, StrFooter
    ld de, $99E0
    call PrintString
    ld de, $9860
    ld a, [$C000]
    ld c, a
MenuMarkerLoop:
    ld a, c
    or a
    jp z, MenuMarkerDone
    ld a, $20
    add a, e
    ld e, a
    jr nc, MenuMarkerNoCarry
    inc d
MenuMarkerNoCarry:
    dec c
    jr MenuMarkerLoop
MenuMarkerDone:
    ld a, $3E
    call PutTileA
    ret
SetTest:
    ld [$C119], a
    ld a, $00
    ld [$C11C], a
    call ResetStressCounters
    ld a, $00
    ld [$C002], a
    ld [$C003], a
    ld [$C004], a
    ld [$C005], a
    ld [$C006], a
    ld a, $FF
    ld [$C007], a
    ld a, $10
    call LogEvent
    ret
CopyRunMetricsToSuper:
    ld a, [$C008]
    ld [$C128], a
    ld a, [$C009]
    ld [$C129], a
    ld a, [$C00A]
    ld [$C12A], a
    ld a, [$C00B]
    ld [$C12B], a
    ld a, [$C019]
    ld [$C12C], a
    ld a, [$C01A]
    ld [$C12D], a
    ld a, [$C01B]
    ld [$C12E], a
    ld a, [$C01C]
    ld [$C12F], a
    ret
FinishTestPass:
    call CopyRunMetricsToSuper
    ld a, $01
    ld [$C11C], a
    ld a, $66
    ld [$C107], a
    ld a, $11
    call LogEvent
    call ClearScreen
    ld hl, StrPass
    ld de, $9840
    call PrintString
    ld hl, StrLoops
    ld de, $9880
    call PrintString
    ld a, [$C00B]
    ld de, $9886
    call PrintHexByte
    ld a, [$C00A]
    ld de, $9888
    call PrintHexByte
    ld a, [$C009]
    ld de, $988A
    call PrintHexByte
    ld a, [$C008]
    ld de, $988C
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9900
    call PrintString
    call WaitKey
    jp MainMenu
FinishStressPass:
    call StopStressClock
    call CopyRunMetricsToSuper
    call UpdateStressStats
    ld a, [$C023]
    or a
    jp nz, FinishStressMasterReason
    ld a, $02
    ld [$C11C], a
    jp FinishStressReasonDone
FinishStressMasterReason:
    ld a, [$C00E]
    or a
    jp nz, FinishStressMasterFixedReason
    ld a, $03
    ld [$C11C], a
    jp FinishStressReasonDone
FinishStressMasterFixedReason:
    ld a, $04
    ld [$C11C], a
FinishStressReasonDone:
    ld a, $66
    ld [$C107], a
    ld a, $11
    call LogEvent
    ld a, [$C023]
    or a
    jp nz, MasterPhaseComplete
    call ClearScreen
    ld hl, StrPass
    ld de, $9820
    call PrintString
    ld hl, StrLoops
    ld de, $9860
    call PrintString
    ld a, [$C00B]
    ld de, $9866
    call PrintHexByte
    ld a, [$C00A]
    ld de, $9868
    call PrintHexByte
    ld a, [$C009]
    ld de, $986A
    call PrintHexByte
    ld a, [$C008]
    ld de, $986C
    call PrintHexByte
    ld a, [$C00E]
    or a
    jp nz, StressPassBare
    ld hl, StrTime
    ld de, $98A0
    call PrintString
    ld a, [$C018]
    ld de, $98A5
    call PrintDec2A
    ld a, [$C017]
    ld de, $98A8
    call PrintDec2A
    ld a, [$C016]
    ld de, $98AB
    call PrintDec2A
    ld a, [$C015]
    ld e, a
    ld d, $00
    ld hl, MsTable
    add hl, de
    add hl, de
    add hl, de
    add hl, de
    ld de, $98AE
    ld a, [hli]
    call PutTileA
    inc de
    ld a, [hli]
    call PutTileA
    inc de
    ld a, [hli]
    call PutTileA
    inc de
    jp StressPassDone
StressPassBare:
    ld hl, StrBareNoTime
    ld de, $98A0
    call PrintString
StressPassDone:
    ld hl, StrAnyKey
    ld de, $9920
    call PrintString
    call WaitKey
    jp MainMenu
TestFault:
    call StopStressClock
    call RecordFault
    jp FaultScreen
CheckStopB:
    call ReadKeys
    and $20
    ret
StressStopDecision:
    ld a, [$C023]
    or a
    jp z, StressStopManual
    ld a, [$C00E]
    or a
    jp nz, StressStopFixed
    call MaybeUpdateStressHUD
    ld a, [$C017]
    ld b, a
    ld a, [$C01F]
    ld c, a
    ld a, b
    cp c
    jp nc, StressStopYes
    ld a, $00
    or a
    ret
StressStopFixed:
    ld a, [$C008]
    ld b, a
    ld a, [$C024]
    cp b
    jp nz, StressStopNo
    ld a, [$C009]
    ld b, a
    ld a, [$C025]
    cp b
    jp nz, StressStopNo
    ld a, [$C00A]
    ld b, a
    ld a, [$C026]
    cp b
    jp nz, StressStopNo
    ld a, [$C00B]
    ld b, a
    ld a, [$C027]
    cp b
    jp nz, StressStopNo
StressStopYes:
    ld a, $01
    or a
    ret
StressStopNo:
    ld a, $00
    or a
    ret
StressStopManual:
    call MaybeUpdateStressHUD
    call CheckStopB
    ret
ChooseStressMode:
    ld hl, StrModeNormal
    ld de, $98A0
    call PrintString
    ld hl, StrModeBare
    ld de, $98E0
    call PrintString
    ld hl, StrModeBack
    ld de, $9920
    call PrintString
StressModeWait:
    call WaitKey
    ld b, a
    ld a, b
    and $20
    jp nz, StressModeBack
    ld a, b
    and $40
    jp nz, StressModeBare
    ld a, b
    and $10
    jp nz, StressModeNormal
    jp StressModeWait
StressModeNormal:
    ld a, $00
    ld [$C00E], a
    ld a, $01
    ld [$C11A], a
    ld a, $01
    ld [$C11B], a
    or a
    ret
StressModeBare:
    ld a, $01
    ld [$C00E], a
    ld a, $02
    ld [$C11A], a
    ld a, $01
    ld [$C11B], a
    or a
    ret
StressModeBack:
    scf
    ret
BeginStressRun:
    ld a, [$C00E]
    or a
    jp nz, BeginStressBare
    call StartStressClock
    ret
BeginStressBare:
    call StopStressClock
    call ResetStressCounters
    ret
RenderStressCommon:
    ld a, [$C00E]
    or a
    jp nz, RenderStressBare
    ld hl, StrNormalRunning
    ld de, $9880
    call PrintString
    ld hl, StrTimeTemplate
    ld de, $98E0
    call PrintString
    ld hl, StrLoopsTemplate
    ld de, $9920
    call PrintString
    ld hl, StrStopB
    ld de, $9980
    call PrintString
    call DrawStressHUD
    ret
RenderStressBare:
    ld hl, StrBareRunning
    ld de, $9880
    call PrintString
    ld hl, StrBareNoLive
    ld de, $98E0
    call PrintString
    ld hl, StrLoopsTracked
    ld de, $9920
    call PrintString
    ld hl, StrStopB
    ld de, $9980
    call PrintString
    ret
RequireRTC:
    or a
    ret
; One-shot full SRAM pattern audit.
RunRamAudit:
    ld a, $00
    ld [$C11A], a
    ld a, $01
    ld [$C11B], a
    ld a, $01
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    ld a, $01
    ld [$C008], a
    jp FinishTestPass
; Stress ordinary SRAM bank selection only; control for RTC-specific failures.
RunBankStress:
    call ClearScreen
    ld hl, StrBankStress
    ld de, $9840
    call PrintString
    call ChooseStressMode
    jp c, MainMenu
    ld a, $02
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call ClearScreen
    ld hl, StrBankStress
    ld de, $9840
    call PrintString
    call RenderStressCommon
BankStressLoop:
    call ScanAllPatterns
    jp c, TestFault
    call IncLoop32
    call StressStopDecision
    jp nz, FinishStressPass
    jp BankStressLoop
WriteRTC_H8_DL12:
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $08
    ld [SRAM_WINDOW], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $0C
    ld [SRAM_WINDOW], a
    ret
CheckA000All:
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    cp $A1
    jp nz, A000Bad0
    jp A000Next0
A000Bad0:
    ld [$C006], a
    ld a, $A1
    ld [$C005], a
    ld a, $00
    ld [$C002], a
    ld a, $00
    ld [$C003], a
    ld a, $A0
    ld [$C004], a
    scf
    ret
A000Next0:
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    cp $B2
    jp nz, A000Bad1
    jp A000Next1
A000Bad1:
    ld [$C006], a
    ld a, $B2
    ld [$C005], a
    ld a, $01
    ld [$C002], a
    ld a, $00
    ld [$C003], a
    ld a, $A0
    ld [$C004], a
    scf
    ret
A000Next1:
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    cp $24
    jp nz, A000Bad2
    jp A000Next2
A000Bad2:
    ld [$C006], a
    ld a, $24
    ld [$C005], a
    ld a, $02
    ld [$C002], a
    ld a, $00
    ld [$C003], a
    ld a, $A0
    ld [$C004], a
    scf
    ret
A000Next2:
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    cp $30
    jp nz, A000Bad3
    jp A000Next3
A000Bad3:
    ld [$C006], a
    ld a, $30
    ld [$C005], a
    ld a, $03
    ld [$C002], a
    ld a, $00
    ld [$C003], a
    ld a, $A0
    ld [$C004], a
    scf
    ret
A000Next3:
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    or a
    ret
RestoreA000Canaries:
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $A1
    ld [SRAM_WINDOW], a
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $B2
    ld [SRAM_WINDOW], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $24
    ld [SRAM_WINDOW], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, $30
    ld [SRAM_WINDOW], a
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
; Directly reproduce the historical 0A<-08 / 0B<-0C signature against watched SRAM.
RunSignature:
    call RequireRTC
    jp c, MainMenu
    call ClearScreen
    ld hl, StrSigStress
    ld de, $9840
    call PrintString
    call ChooseStressMode
    jp c, MainMenu
    ld a, $03
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call ClearScreen
    ld hl, StrSigStress
    ld de, $9840
    call PrintString
    call RenderStressCommon
SigLoop:
    ld a, $01
    ld [$C11E], a
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $08
    ld [SRAM_WINDOW], a
    call CheckA000All
    jp c, TestFault
    ld a, $02
    ld [$C11E], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $0C
    ld [SRAM_WINDOW], a
    call CheckA000All
    jp c, TestFault
    ld a, $03
    ld [$C11E], a
    call LatchRTC
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C012], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C013], a
    call CheckA000All
    jp c, TestFault
    ld a, $00
    ld [$C11E], a
    call IncLoop32
    ld a, [$C008]
    or a
    jp nz, SigSkipFull
    call ScanAllPatterns
    jp c, TestFault
SigSkipFull:
    call StressStopDecision
    jp nz, FinishStressPass
    jp SigLoop
WriteRTCMapValues:
    ld a, $08
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $11
    ld [SRAM_WINDOW], a
    ld a, $09
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $22
    ld [SRAM_WINDOW], a
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $08
    ld [SRAM_WINDOW], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $0C
    ld [SRAM_WINDOW], a
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, $00
    ld [SRAM_WINDOW], a
    ret
; Write a known pattern to RTC selectors 08-0C and inspect SRAM alias results.
RunRTCMap:
    call RequireRTC
    jp c, MainMenu
    ld a, $00
    ld [$C11A], a
    ld a, $01
    ld [$C11B], a
    ld a, $04
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call WriteRTCMapValues
    call CheckA000All
    jp c, TestFault
    call ReadRTCSnapshot
    ld a, $01
    ld [$C008], a
    jp FinishTestPass
; Repeated legal RTC register writes with immediate SRAM auditing.
RunRTCStress:
    call RequireRTC
    jp c, MainMenu
    call ClearScreen
    ld hl, StrRTCStress
    ld de, $9840
    call PrintString
    call ChooseStressMode
    jp c, MainMenu
    ld a, $05
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call ClearScreen
    ld hl, StrRTCStress
    ld de, $9840
    call PrintString
    call RenderStressCommon
RTCStressLoop:
    call WriteRTCMapValues
    call LatchRTC
    ld a, $08
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $09
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0C
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    call CheckA000All
    jp c, TestFault
    call IncLoop32
    ld a, [$C008]
    or a
    jp nz, RTCStressSkipFull
    call ScanAllPatterns
    jp c, TestFault
RTCStressSkipFull:
    call StressStopDecision
    jp nz, FinishStressPass
    jp RTCStressLoop
; Repeated RTC latch/read activity; separates latch/read behavior from RTC writes.
RunLatchStress:
    call RequireRTC
    jp c, MainMenu
    call ClearScreen
    ld hl, StrLatchStress
    ld de, $9840
    call PrintString
    call ChooseStressMode
    jp c, MainMenu
    ld a, $06
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call ClearScreen
    ld hl, StrLatchStress
    ld de, $9840
    call PrintString
    call RenderStressCommon
LatchStressLoop:
    ld a, $01
    ld [$C11E], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C012], a
    call CheckA000All
    jp c, TestFault
    ld a, $02
    ld [$C11E], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C013], a
    call CheckA000All
    jp c, TestFault
    ld a, $03
    ld [$C11E], a
    call LatchRTC
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C012], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C013], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld [$C007], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    call CheckA000All
    jp c, TestFault
    ld a, $00
    ld [$C11E], a
    call IncLoop32
    ld a, [$C008]
    or a
    jp nz, LatchSkipFull
    call ScanAllPatterns
    jp c, TestFault
LatchSkipFull:
    call StressStopDecision
    jp nz, FinishStressPass
    jp LatchStressLoop
; Configure the long automatic stress campaign.
MasterConfig:
MasterConfigRender:
    call ClearScreen
    ld hl, StrMasterCfg
    ld de, $9800
    call PrintString
    ld hl, StrMasterMinutes
    ld de, $9860
    call PrintString
    ld a, [$C01F]
    ld de, $986C
    call PrintDec2A
    ld hl, StrMasterCycles
    ld de, $98A0
    call PrintString
    ld a, [$C020]
    ld de, $98AC
    call PrintDec2A
    ld hl, StrMasterPhases8
    ld de, $98E0
    call PrintString
    ld hl, StrMasterKeys1
    ld de, $9940
    call PrintString
    ld hl, StrMasterKeys2
    ld de, $9980
    call PrintString
    ld hl, StrMasterStart
    ld de, $99C0
    call PrintString
MasterConfigWait:
    call WaitKey
    ld b, a
    ld a, b
    and $02
    jp nz, MasterMinDown
    ld a, b
    and $01
    jp nz, MasterMinUp
    ld a, b
    and $04
    jp nz, MasterCyclesUp
    ld a, b
    and $08
    jp nz, MasterCyclesDown
    ld a, b
    and $20
    jp nz, MainMenu
    ld a, b
    and $10
    jp nz, MasterStart
    jp MasterConfigWait
MasterMinDown:
    ld a, [$C01F]
    cp $01
    jp z, MasterConfig
    dec a
    ld [$C01F], a
    jp MasterConfig
MasterMinUp:
    ld a, [$C01F]
    cp $1E
    jp z, MasterConfig
    inc a
    ld [$C01F], a
    jp MasterConfig
MasterCyclesUp:
    ld a, [$C020]
    cp $09
    jp z, MasterConfig
    inc a
    ld [$C020], a
    jp MasterConfig
MasterCyclesDown:
    ld a, [$C020]
    cp $01
    jp z, MasterConfig
    dec a
    ld [$C020], a
    jp MasterConfig
; Reserve journal capacity and start the automatic multi-phase campaign.
MasterStart:
    ld a, [$C020]
    swap a
    add a, $02
    ld b, a
    ld a, [$C10F]
    or a
    jp nz, MasterLogLowScreen
    ld a, [$C10E]
    add a, b
    jp c, MasterLogLowScreen
    cp $E9
    jp c, MasterSpaceOK
    jp MasterLogLowScreen
MasterSpaceOK:
    ld a, $01
    ld [$C023], a
    ld a, $00
    ld [$C021], a
    ld [$C022], a
    ld [$C024], a
    ld [$C025], a
    ld [$C026], a
    ld [$C027], a
    ld [$C028], a
    ld hl, $C116
    call Inc16AtHL
    ld a, [$C020]
    ld [$C11F], a
    ld a, [$C01F]
    ld [$C121], a
    ld a, $08
    ld [$C120], a
    ld [$C002], a
    ld a, $00
    ld [$C11D], a
    ld [$C11E], a
    ld a, $0A
    ld [$C119], a
    ld a, $05
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    call ResetStressCounters
    ld a, $00
    ld [$C003], a
    ld [$C004], a
    ld a, $FF
    ld [$C007], a
    ld a, [$C01F]
    ld [$C005], a
    ld a, [$C020]
    ld [$C006], a
    ld a, $30
    call LogEvent
    jp MasterDispatch
MasterRenderHeader:
    call ClearScreen
    ld hl, StrMasterRun
    ld de, $9800
    call PrintString
    ld hl, StrMasterCycle
    ld de, $9820
    call PrintString
    ld a, [$C021]
    inc a
    ld de, $9826
    call PrintDec2A
    ld a, $2F
    ld de, $9828
    call PutTileA
    ld a, [$C020]
    ld de, $9829
    call PrintDec2A
    ld hl, StrMasterPhase
    ld de, $9840
    call PrintString
    ld a, [$C022]
    inc a
    ld de, $9846
    call PrintDec2A
    ld a, $2F
    ld de, $9848
    call PutTileA
    ld a, $08
    ld de, $9849
    call PrintDec2A
    ret
MasterRenderNormal:
    call MasterRenderHeader
    ld hl, StrMasterNormal
    ld de, $98A0
    call PrintString
    ld hl, StrTimeTemplate
    ld de, $98E0
    call PrintString
    ld hl, StrLoopsTemplate
    ld de, $9920
    call PrintString
    ld hl, StrMasterAuto
    ld de, $9980
    call PrintString
    call DrawStressHUD
    ret
MasterRenderFixed:
    call MasterRenderHeader
    ld hl, StrMasterFixed
    ld de, $98A0
    call PrintString
    ld hl, StrMasterTarget
    ld de, $98E0
    call PrintString
    ld a, [$C027]
    ld de, $98E7
    call PrintHexByte
    ld a, [$C026]
    ld de, $98E9
    call PrintHexByte
    ld a, [$C025]
    ld de, $98EB
    call PrintHexByte
    ld a, [$C024]
    ld de, $98ED
    call PrintHexByte
    ld hl, StrMasterNoIRQ
    ld de, $9920
    call PrintString
    ld hl, StrMasterAuto
    ld de, $9980
    call PrintString
    ret
MasterDispatch:
    ld a, [$C106]
    and $04
    jp nz, JournalFullScreen
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, [$C022]
    cp $00
    jp z, MasterBankNormal
    cp $01
    jp z, MasterBankFixed
    cp $02
    jp z, MasterSigNormal
    cp $03
    jp z, MasterSigFixed
    cp $04
    jp z, MasterRTCNormal
    cp $05
    jp z, MasterRTCFixed
    cp $06
    jp z, MasterLatchNormal
    cp $07
    jp z, MasterLatchFixed
    jp MasterComplete
MasterLogLowScreen:
    ld a, $00
    ld [$C023], a
    call ClearScreen
    ld hl, StrMasterLogLow
    ld de, $9840
    call PrintString
    ld hl, StrCopySRAM
    ld de, $98C0
    call PrintString
    ld hl, StrAnyKey
    ld de, $9940
    call PrintString
    call WaitKey
    jp MainMenu
MasterBankNormal:
    ld a, $00
    ld [$C00E], a
    ld a, $01
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $02
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderNormal
    ld hl, StrBankStress
    ld de, $9880
    call PrintString
    jp BankStressLoop
MasterBankFixed:
    ld a, $02
    ld [$C00E], a
    ld a, $03
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $02
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderFixed
    ld hl, StrBankStress
    ld de, $9880
    call PrintString
    jp BankStressLoop
MasterSigNormal:
    ld a, $00
    ld [$C00E], a
    ld a, $01
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $03
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderNormal
    ld hl, StrSigStress
    ld de, $9880
    call PrintString
    jp SigLoop
MasterSigFixed:
    ld a, $02
    ld [$C00E], a
    ld a, $03
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $03
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderFixed
    ld hl, StrSigStress
    ld de, $9880
    call PrintString
    jp SigLoop
MasterRTCNormal:
    ld a, $00
    ld [$C00E], a
    ld a, $01
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $05
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderNormal
    ld hl, StrRTCStress
    ld de, $9880
    call PrintString
    jp RTCStressLoop
MasterRTCFixed:
    ld a, $02
    ld [$C00E], a
    ld a, $03
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $05
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderFixed
    ld hl, StrRTCStress
    ld de, $9880
    call PrintString
    jp RTCStressLoop
MasterLatchNormal:
    ld a, $00
    ld [$C00E], a
    ld a, $01
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $06
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderNormal
    ld hl, StrLatchStress
    ld de, $9880
    call PrintString
    jp LatchStressLoop
MasterLatchFixed:
    ld a, $02
    ld [$C00E], a
    ld a, $03
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $00
    ld [$C11C], a
    ld a, [$C021]
    ld [$C11D], a
    ld a, [$C022]
    ld [$C11E], a
    ld a, $06
    call SetTest
    call ScanAllPatterns
    jp c, TestFault
    call BeginStressRun
    call MasterRenderFixed
    ld hl, StrLatchStress
    ld de, $9880
    call PrintString
    jp LatchStressLoop
MasterPhaseComplete:
    ld a, [$C00E]
    or a
    jp nz, MasterNoTargetCopy
    ld a, [$C008]
    ld [$C024], a
    ld a, [$C009]
    ld [$C025], a
    ld a, [$C00A]
    ld [$C026], a
    ld a, [$C00B]
    ld [$C027], a
MasterNoTargetCopy:
    ld a, [$C022]
    inc a
    ld [$C022], a
    cp $08
    jp c, MasterDispatch
    ld a, $00
    ld [$C022], a
    ld a, [$C021]
    inc a
    ld [$C021], a
    ld b, a
    ld a, [$C020]
    cp b
    jp nz, MasterDispatch
    jp MasterComplete
MasterComplete:
    call StopStressClock
    ld a, $00
    ld [$C023], a
    call ResetStressCounters
    ld a, $00
    ld [$C002], a
    ld [$C003], a
    ld [$C004], a
    ld [$C005], a
    ld [$C006], a
    ld a, $FF
    ld [$C007], a
    ld a, $0A
    ld [$C119], a
    ld a, $05
    ld [$C11A], a
    ld a, $02
    ld [$C11B], a
    ld a, $09
    ld [$C11C], a
    ld a, [$C020]
    ld [$C11D], a
    ld a, $FF
    ld [$C11E], a
    ld a, $31
    call LogEvent
    call ClearScreen
    ld hl, StrMasterDone
    ld de, $9840
    call PrintString
    ld hl, StrMasterAllPass
    ld de, $98A0
    call PrintString
    ld hl, StrMasterCycles
    ld de, $98E0
    call PrintString
    ld a, [$C020]
    ld de, $98EC
    call PrintDec2A
    ld hl, StrAnyKey
    ld de, $9960
    call PrintString
    call WaitKey
    jp MainMenu
; Choose the functional mapper/RTC state TRACE leaves immediately before an external experiment.
ArmPresets:
    ld a, $01
    ld [$C028], a
    ld a, $01
    ld [$C00C], a
    jp ArmPresetRender
ArmPresetRender:
    call ClearScreen
    ld hl, StrArmTitle
    ld de, $9800
    call PrintString
    ld hl, StrPreset
    ld de, $9860
    call PrintString
    ld a, [$C028]
    ld de, $9867
    call PrintHexByte
    call RenderArmPresetName
    ld hl, StrArmPresetKeys
    ld de, $98E0
    call PrintString
    ld hl, StrArmBack
    ld de, $9940
    call PrintString
ArmPresetWait:
    call WaitKey
    ld b, a
    ld a, b
    and $02
    jp nz, ArmPresetPrev
    ld a, b
    and $01
    jp nz, ArmPresetNext
    ld a, b
    and $20
    jp nz, MainMenu
    ld a, b
    and $10
    jp nz, ArmScenarioRender
    jp ArmPresetWait
ArmPresetPrev:
    ld a, [$C028]
    cp $01
    jp z, ArmPresetPrevWrap
    dec a
    ld [$C028], a
    jp ArmPresetRender
ArmPresetPrevWrap:
    ld a, $06
    ld [$C028], a
    jp ArmPresetRender
ArmPresetNext:
    ld a, [$C028]
    inc a
    cp $07
    jp c, ArmPresetNextStore
    ld a, $01
ArmPresetNextStore:
    ld [$C028], a
    jp ArmPresetRender
RenderArmPresetName:
    ld a, [$C028]
    cp $01
    jp z, ArmNameSilver
    cp $02
    jp z, ArmNameSelect
    cp $03
    jp z, ArmNameRTCH
    cp $04
    jp z, ArmNameRTCDL
    cp $05
    jp z, ArmNameSRAM2
    jp ArmNameSRAM3
ArmNameSilver:
    ld hl, StrArmSilver
    ld de, $9882
    call PrintString
    ret
ArmNameSelect:
    ld hl, StrArmSelect
    ld de, $9882
    call PrintString
    ret
ArmNameRTCH:
    ld hl, StrArmRTCH
    ld de, $9882
    call PrintString
    ret
ArmNameRTCDL:
    ld hl, StrArmRTCDL
    ld de, $9882
    call PrintString
    ret
ArmNameSRAM2:
    ld hl, StrArmSRAM2
    ld de, $9882
    call PrintString
    ret
ArmNameSRAM3:
    ld hl, StrArmSRAM3
    ld de, $9882
    call PrintString
    ret
; Choose an opaque user-defined SCENARIO tag; the ROM does not assign its meaning.
ArmScenarioRender:
    call ClearScreen
    ld hl, StrArmScenarioTitle
    ld de, $9800
    call PrintString
    ld hl, StrPreset
    ld de, $9840
    call PrintString
    ld a, [$C028]
    ld de, $9847
    call PrintHexByte
    call RenderArmPresetNameRow3
    ld hl, StrScenario
    ld de, $98A0
    call PrintString
    ld a, [$C00C]
    ld de, $98A9
    call PrintHexByte
    ld hl, StrArmScenarioKeys
    ld de, $9940
    call PrintString
    ld hl, StrArmBackPreset
    ld de, $9980
    call PrintString
ArmScenarioWait:
    call WaitKey
    ld b, a
    ld a, b
    and $02
    jp nz, ArmScenarioPrev
    ld a, b
    and $01
    jp nz, ArmScenarioNext
    ld a, b
    and $20
    jp nz, ArmPresetRender
    ld a, b
    and $10
    jp nz, ArmDo
    jp ArmScenarioWait
ArmScenarioPrev:
    ld a, [$C00C]
    dec a
    jp z, ArmScenarioPrevWrap
    ld [$C00C], a
    jp ArmScenarioRender
ArmScenarioPrevWrap:
    ld a, $FF
    ld [$C00C], a
    jp ArmScenarioRender
ArmScenarioNext:
    ld a, [$C00C]
    inc a
    jp nz, ArmScenarioNextStore
    ld a, $01
ArmScenarioNextStore:
    ld [$C00C], a
    jp ArmScenarioRender
RenderArmPresetNameRow3:
    ld a, [$C028]
    cp $01
    jp z, ArmName3Silver
    cp $02
    jp z, ArmName3Select
    cp $03
    jp z, ArmName3RTCH
    cp $04
    jp z, ArmName3RTCDL
    cp $05
    jp z, ArmName3SRAM2
    jp ArmName3SRAM3
ArmName3Silver:
    ld hl, StrArmSilver
    ld de, $9862
    call PrintString
    ret
ArmName3Select:
    ld hl, StrArmSelect
    ld de, $9862
    call PrintString
    ret
ArmName3RTCH:
    ld hl, StrArmRTCH
    ld de, $9862
    call PrintString
    ret
ArmName3RTCDL:
    ld hl, StrArmRTCDL
    ld de, $9862
    call PrintString
    ret
ArmName3SRAM2:
    ld hl, StrArmSRAM2
    ld de, $9862
    call PrintString
    ret
ArmName3SRAM3:
    ld hl, StrArmSRAM3
    ld de, $9862
    call PrintString
    ret
SetArmTestID:
    ld a, [$C028]
    cp $01
    jp z, SetArmTSilver
    cp $02
    jp z, SetArmTSelect
    cp $03
    jp z, SetArmTRTCH
    cp $04
    jp z, SetArmTRTCDL
    cp $05
    jp z, SetArmTSRAM2
    ld a, $25
    ld [$C119], a
    ret
SetArmTSilver:
    ld a, $20
    ld [$C119], a
    ret
SetArmTSelect:
    ld a, $21
    ld [$C119], a
    ret
SetArmTRTCH:
    ld a, $22
    ld [$C119], a
    ret
SetArmTRTCDL:
    ld a, $23
    ld [$C119], a
    ret
SetArmTSRAM2:
    ld a, $24
    ld [$C119], a
    ret
PrepareArmPreset:
    ld a, [$C028]
    cp $01
    jp z, PrepArmSilver
    cp $02
    jp z, PrepArmSelect
    cp $03
    jp z, PrepArmRTCCommon
    cp $04
    jp z, PrepArmRTCCommon
    cp $05
    jp z, PrepArmSRAM2
    jp PrepArmSRAM3
PrepArmSilver:
    call ReadRTCSnapshot
    call ScanAllPatterns
    jp c, TestFault
    ld a, $00
    ld [$C007], a
    ret
PrepArmSelect:
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C012], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C013], a
    call LatchRTC
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C012], a
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C013], a
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld [$C01D], a
    call ScanAllPatterns
    jp c, TestFault
    ld a, $00
    ld [$C007], a
    ret
PrepArmRTCCommon:
    call ReadRTCSnapshot
    call ScanAllPatterns
    jp c, TestFault
    ld a, [$C028]
    cp $03
    jp z, PrepArmSetH
    ld a, $0B
    ld [$C007], a
    ret
PrepArmSetH:
    ld a, $0A
    ld [$C007], a
    ret
PrepArmSRAM2:
    call ReadRTCSnapshot
    call ScanAllPatterns
    jp c, TestFault
    ld a, $02
    ld [$C007], a
    ret
PrepArmSRAM3:
    call ReadRTCSnapshot
    call ScanAllPatterns
    jp c, TestFault
    ld a, $03
    ld [$C007], a
    ret
ApplyArmFinalSelector:
    ld a, [$C028]
    cp $03
    jp z, ArmFinalH
    cp $04
    jp z, ArmFinalDL
    cp $05
    jp z, ArmFinal2
    cp $06
    jp z, ArmFinal3
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ret
ArmFinalH:
    ld a, $0A
    ld [MBC_RAM_RTC_SELECT], a
    ret
ArmFinalDL:
    ld a, $0B
    ld [MBC_RAM_RTC_SELECT], a
    ret
ArmFinal2:
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ret
ArmFinal3:
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ret
; Persist the forensic ARM boundary and wait for the user to perform an external lifecycle experiment.
ArmDo:
    call ResetStressCounters
    ld a, $00
    ld [$C002], a
    ld [$C003], a
    ld [$C004], a
    ld [$C005], a
    ld [$C006], a
    ld a, [$C028]
    ld [$C135], a
    ld a, [$C00C]
    ld [$C118], a
    call SetArmTestID
    ld a, $04
    ld [$C11A], a
    ld a, $03
    ld [$C11B], a
    ld a, $08
    ld [$C11C], a
    ld a, $00
    ld [$C11E], a
    call ScanAllPatterns
    jp c, TestFault
    call PrepareArmPreset
    ld a, [$C010]
    ld [$C130], a
    ld a, [$C011]
    ld [$C131], a
    ld a, [$C012]
    ld [$C132], a
    ld a, [$C013]
    ld [$C133], a
    ld a, [$C014]
    ld [$C134], a
    ld a, [$C007]
    ld [$C122], a
    ld a, [$C106]
    or $01
    ld [$C106], a
    ld hl, $C10A
    call Inc16AtHL
    ld a, $20
    call LogEvent
    call ApplyArmFinalSelector
    call ClearScreen
    ld hl, StrArmed
    ld de, $9800
    call PrintString
    ld hl, StrPreset
    ld de, $9840
    call PrintString
    ld a, [$C028]
    ld de, $9847
    call PrintHexByte
    call RenderArmPresetNameRow3
    ld hl, StrScenario
    ld de, $98A0
    call PrintString
    ld a, [$C00C]
    ld de, $98A9
    call PrintHexByte
    ld hl, StrLastSel
    ld de, $9900
    call PrintString
    ld a, [$C007]
    ld de, $9909
    call PrintHexByte
    ld hl, StrExitNow
    ld de, $9960
    call PrintString
    ld hl, StrNextAudit
    ld de, $99A0
    call PrintString
ArmHold:
    call WaitKey
    jp ArmHold
ViewRTC:
    call RequireRTC
    jp c, MainMenu
    call ReadRTCSnapshot
    call ClearScreen
    ld hl, StrRTCView
    ld de, $9800
    call PrintString
    ld hl, StrS
    ld de, $9840
    call PrintString
    ld a, [$C010]
    ld de, $9843
    call PrintHexByte
    ld hl, StrM
    ld de, $9860
    call PrintString
    ld a, [$C011]
    ld de, $9863
    call PrintHexByte
    ld hl, StrH
    ld de, $9880
    call PrintString
    ld a, [$C012]
    ld de, $9883
    call PrintHexByte
    ld hl, StrDL
    ld de, $98A0
    call PrintString
    ld a, [$C013]
    ld de, $98A4
    call PrintHexByte
    ld hl, StrDH
    ld de, $98C0
    call PrintString
    ld a, [$C014]
    ld de, $98C4
    call PrintHexByte
    ld hl, StrAnyKey
    ld de, $9940
    call PrintString
    call WaitKey
    jp MainMenu
ShowStatus:
    call ClearScreen
    ld hl, StrStatus
    ld de, $9800
    call PrintString
    ld hl, StrBoot
    ld de, $9840
    call PrintString
    ld a, [$C109]
    ld de, $9845
    call PrintHexByte
    ld a, [$C108]
    ld de, $9847
    call PrintHexByte
    ld hl, StrGen
    ld de, $9860
    call PrintString
    ld a, [$C10B]
    ld de, $9864
    call PrintHexByte
    ld a, [$C10A]
    ld de, $9866
    call PrintHexByte
    ld hl, StrFlags
    ld de, $9880
    call PrintString
    ld a, [$C106]
    ld de, $9886
    call PrintHexByte
    ld hl, StrErrs
    ld de, $98A0
    call PrintString
    ld a, [$C111]
    ld de, $98A5
    call PrintHexByte
    ld a, [$C110]
    ld de, $98A7
    call PrintHexByte
    ld hl, StrPreset
    ld de, $98C0
    call PrintString
    ld a, [$C135]
    ld de, $98C7
    call PrintHexByte
    ld hl, StrScenario
    ld de, $98E0
    call PrintString
    ld a, [$C118]
    ld de, $98E9
    call PrintHexByte
    ld hl, StrJrn
    ld de, $9900
    call PrintString
    ld a, [$C10F]
    ld de, $9904
    call PrintHexByte
    ld a, [$C10E]
    ld de, $9906
    call PrintHexByte
    ld hl, StrJrnMax
    ld de, $9908
    call PrintString
    ld hl, StrA000
    ld de, $9940
    call PrintString
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld de, $9945
    call PrintHexByte
    ld a, $01
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld de, $9948
    call PrintHexByte
    ld a, $02
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld de, $994B
    call PrintHexByte
    ld a, $03
    ld [MBC_RAM_RTC_SELECT], a
    ld a, [SRAM_WINDOW]
    ld de, $994E
    call PrintHexByte
    ld a, $00
    ld [MBC_RAM_RTC_SELECT], a
    ld hl, StrAnyKey
    ld de, $99C0
    call PrintString
    call WaitKey
    jp MainMenu
StrTitle:
    db "X7MBC3TRACE-B", 0
StrNoState:
    db "NO VALID TRACE STATE", 0
StrVersion:
    db "TRACE V1.0.0  ", 0
StrInitA:
    db "A = NEW CAMPAIGN", 0
StrInitWarn:
    db "ERASES TRACE SRAM", 0
StrFault:
    db "** FAULT DETECTED **", 0
StrBank:
    db "BANK ", 0
StrAddr:
    db "ADDR ", 0
StrExp:
    db "EXP ", 0
StrGot:
    db "GOT ", 0
StrPowerCopy:
    db "POWER OFF/COPY SRAM", 0
StrFirstCap:
    db "FIRST FAULT SAVED", 0
StrMetaFault:
    db "METADATA INVALID", 0
StrMetaFault2:
    db "COPY SRAM - STOP", 0
StrBoot:
    db "BOOT ", 0
StrSel:
    db "SEL ", 0
StrMenu0:
    db "  RAM AUDIT", 0
StrMenu1:
    db "  SILVER TRACE", 0
StrMenu2:
    db "  SELECT TRACE", 0
StrMenu3:
    db "  RTC TRACE", 0
StrMenu4:
    db "  RTC MAP", 0
StrMenu5:
    db "  ARM PRESETS", 0
StrMenu6:
    db "  VIEW RTC", 0
StrMenu7:
    db "  STATUS", 0
StrMenu8:
    db "  VIEW RTC", 0
StrMenu9:
    db "  STATUS", 0
StrFooter:
    db "UP/DN  A=RUN", 0
StrPass:
    db "PASS", 0
StrLoops:
    db "LOOPS ", 0
StrAnyKey:
    db "PRESS ANY KEY", 0
StrTime:
    db "TIME ", 0
StrNoRTC:
    db "NO RTC IN THIS ROM", 0
StrBankStress:
    db "BANK STRESS", 0
StrStopB:
    db "B = STOP + PASS", 0
StrSigStress:
    db "SILVER TRACE", 0
StrRTCStress:
    db "RTC TRACE", 0
StrLatchStress:
    db "SELECT TRACE", 0
StrModeNormal:
    db "A=NORMAL + TIMER", 0
StrModeBare:
    db "SELECT=BARE MAX", 0
StrModeBack:
    db "B=BACK", 0
StrNormalRunning:
    db "MODE NORMAL TIMER", 0
StrBareRunning:
    db "MODE BARE MAX", 0
StrTimeTemplate:
    db "TIME 00:00:00.000", 0
StrLoopsTemplate:
    db "LOOPS 00000000", 0
StrBareNoLive:
    db "NO LIVE TIMER", 0
StrLoopsTracked:
    db "LOOPS TRACKED", 0
StrBareNoTime:
    db "TIME DISABLED BARE", 0
StrMasterCfg:
    db "MASTER RUN CONFIG", 0
StrMasterMinutes:
    db "MIN/PHASE ", 0
StrMasterCycles:
    db "CYCLES ", 0
StrMasterPhases8:
    db "8 PHASES / CYCLE", 0
StrMasterPhases2:
    db "2 PHASES / CYCLE", 0
StrMasterKeys1:
    db "L/R=MIN  UP/DN=CYC", 0
StrMasterKeys2:
    db "1-30 MIN   1-9 CYC", 0
StrMasterStart:
    db "A=START  B=BACK", 0
StrMasterRun:
    db "*** MASTER RUN ***", 0
StrMasterCycle:
    db "CYCLE ", 0
StrMasterPhase:
    db "PHASE ", 0
StrMasterNormal:
    db "NORMAL TIMED", 0
StrMasterFixed:
    db "BARE FIXED", 0
StrMasterTarget:
    db "TARGET ", 0
StrMasterNoIRQ:
    db "NO TIMER / NO HUD", 0
StrMasterAuto:
    db "AUTO NEXT PHASE", 0
StrMasterDone:
    db "MASTER COMPLETE", 0
StrMasterAllPass:
    db "ALL PHASES PASS", 0
StrMasterLogLow:
    db "JOURNAL SPACE LOW", 0
StrArmTitle:
    db "ARM PRESETS", 0
StrPreset:
    db "PRESET ", 0
StrScenario:
    db "SCENARIO ", 0
StrArmPresetKeys:
    db "L/R CHOOSE  A=NEXT", 0
StrArmBack:
    db "B=BACK", 0
StrArmScenarioTitle:
    db "ARM SCENARIO", 0
StrArmScenarioKeys:
    db "L/R CHOOSE  A=ARM", 0
StrArmBackPreset:
    db "B=PRESETS", 0
StrArmSilver:
    db "SILVER", 0
StrArmSelect:
    db "SELECT", 0
StrArmRTCH:
    db "RTC-H", 0
StrArmRTCDL:
    db "RTC-DL", 0
StrArmSRAM2:
    db "SRAM2", 0
StrArmSRAM3:
    db "SRAM3", 0
StrArmed:
    db "*** ARMED ***", 0
StrLastSel:
    db "LAST SEL ", 0
StrExitNow:
    db "PERFORM EXT TEST", 0
StrNextAudit:
    db "NEXT BOOT AUDITS", 0
StrRTCView:
    db "RTC SNAPSHOT", 0
StrS:
    db "S  ", 0
StrM:
    db "M  ", 0
StrH:
    db "H  ", 0
StrDL:
    db "DL  ", 0
StrDH:
    db "DH  ", 0
StrStatus:
    db "TRACE STATUS", 0
StrGen:
    db "GEN ", 0
StrFlags:
    db "FLAGS ", 0
StrErrs:
    db "ERRS ", 0
StrA000:
    db "A000 0  1  2  3", 0
StrJrn:
    db "JRN ", 0
StrJrnMax:
    db "/00E8", 0
StrSRAMCleared:
    db "SRAM CLEARED", 0
StrRTCUnchanged:
    db "RTC NOT TOUCHED", 0
StrRestartRequired:
    db "RESTART REQUIRED", 0
StrJournalFull:
    db "*** JOURNAL FULL ***", 0
StrJournal480:
    db "232/232 EVENTS USED", 0
StrLoggingFrozen:
    db "LOGGING FROZEN", 0
StrCopySRAM:
    db "COPY SRAM FIRST", 0
StrNewCampaign:
    db "NEW SAVE = NEW CAMP", 0
StrAStatus:
    db "A = STATUS ONLY", 0
MsTable:
    db $30, $30, $30, $00, $30, $31, $35, $00, $30, $33, $31, $00, $30, $34, $36, $00
    db $30, $36, $32, $00, $30, $37, $38, $00, $30, $39, $33, $00, $31, $30, $39, $00
    db $31, $32, $35, $00, $31, $34, $30, $00, $31, $35, $36, $00, $31, $37, $31, $00
    db $31, $38, $37, $00, $32, $30, $33, $00, $32, $31, $38, $00, $32, $33, $34, $00
    db $32, $35, $30, $00, $32, $36, $35, $00, $32, $38, $31, $00, $32, $39, $36, $00
    db $33, $31, $32, $00, $33, $32, $38, $00, $33, $34, $33, $00, $33, $35, $39, $00
    db $33, $37, $35, $00, $33, $39, $30, $00, $34, $30, $36, $00, $34, $32, $31, $00
    db $34, $33, $37, $00, $34, $35, $33, $00, $34, $36, $38, $00, $34, $38, $34, $00
    db $35, $30, $30, $00, $35, $31, $35, $00, $35, $33, $31, $00, $35, $34, $36, $00
    db $35, $36, $32, $00, $35, $37, $38, $00, $35, $39, $33, $00, $36, $30, $39, $00
    db $36, $32, $35, $00, $36, $34, $30, $00, $36, $35, $36, $00, $36, $37, $31, $00
    db $36, $38, $37, $00, $37, $30, $33, $00, $37, $31, $38, $00, $37, $33, $34, $00
    db $37, $35, $30, $00, $37, $36, $35, $00, $37, $38, $31, $00, $37, $39, $36, $00
    db $38, $31, $32, $00, $38, $32, $38, $00, $38, $34, $33, $00, $38, $35, $39, $00
    db $38, $37, $35, $00, $38, $39, $30, $00, $39, $30, $36, $00, $39, $32, $31, $00
    db $39, $33, $37, $00, $39, $35, $33, $00, $39, $36, $38, $00, $39, $38, $34, $00
FontData:
    INCBIN "assets/font.bin"

; Force a 2 MiB / 128-bank ROM. rgblink fills all gaps with $FF.
SECTION "ROM size sentinel", ROMX[$7FFF], BANK[127]
    db $FF
