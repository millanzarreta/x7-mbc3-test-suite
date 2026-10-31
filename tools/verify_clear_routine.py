#!/usr/bin/env python3
"""Execute the assembled SRAM-clear block with a tiny LR35902/MBC3 model.

This is intentionally not a general Game Boy emulator. It uses the independent
ASM subset encoder to reconstruct the current sources, then executes only the
instruction subset used by ClearSRAMTerminal. It verifies that all 4 x 8 KiB
SRAM banks become zero, the only bank selectors are 00/01/02/03/00, RAM is
enabled then disabled, and $6000 is never written.
"""
from pathlib import Path
import importlib.util
import sys

ROOT = Path(__file__).resolve().parents[1]
CASES = [
    ("diag", ROOT / "diag/rgbds/src/X7MBC3DIAG-A.asm"),
    ("trace", ROOT / "trace/rgbds/src/X7MBC3TRACE-A.asm"),
    ("pokertc", ROOT / "pokertc/rgbds/src/X7POKERTC.asm"),
]


def load_encoder():
    path = ROOT / "tools/validate_rgbds_transcription.py"
    spec = importlib.util.spec_from_file_location("x7_source_encoder", path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def simulate(rom, labels):
    pc=labels['ClearSRAMTerminal']; clear_screen=labels['ClearScreen']
    A=B=C=D=0; HL=BC=0; z=False; selected=0; enabled=False; steps=0
    sram=[bytearray([0xA5])*0x2000 for _ in range(4)]; mapper=[]
    while steps<200000:
        steps+=1; op=rom[pc]
        if op==0xF3: pc+=1
        elif op==0x3E: A=rom[pc+1]; pc+=2
        elif op==0xEA:
            addr=rom[pc+1]|(rom[pc+2]<<8); pc+=3
            if addr in (0x0000,0x4000,0x6000): mapper.append((addr,A))
            if addr==0x0000: enabled=(A&0x0F)==0x0A
            elif addr==0x4000: selected=A
            elif 0xA000<=addr<=0xBFFF and enabled and selected<4: sram[selected][addr-0xA000]=A
        elif op==0x21: HL=rom[pc+1]|(rom[pc+2]<<8); pc+=3
        elif op==0x01: BC=rom[pc+1]|(rom[pc+2]<<8); pc+=3
        elif op==0x16: D=rom[pc+1]; pc+=2
        elif op==0x7A: A=D; pc+=1
        elif op==0x22:
            if enabled and selected<4 and 0xA000<=HL<=0xBFFF: sram[selected][HL-0xA000]=A
            HL=(HL+1)&0xffff; pc+=1
        elif op==0x0B: BC=(BC-1)&0xffff; B=BC>>8; C=BC&0xff; pc+=1
        elif op==0x78: A=B; pc+=1
        elif op==0xB1: A|=C; z=(A==0); pc+=1
        elif op==0x20:
            rel=rom[pc+1]; rel=rel-256 if rel>=128 else rel
            pc=(pc+2 if z else pc+2+rel)&0xffff
        elif op==0xCD:
            target=rom[pc+1]|(rom[pc+2]<<8)
            if target==clear_screen: break
            raise RuntimeError(f'unexpected CALL {target:04X} at {pc:04X}')
        else: raise RuntimeError(f'unsupported opcode {op:02X} at {pc:04X}')
    assert all(all(v==0 for v in bank) for bank in sram)
    assert [v for a,v in mapper if a==0x4000]==[0,1,2,3,0]
    assert [v for a,v in mapper if a==0x0000]==[0x0A,0]
    assert not any(a==0x6000 for a,v in mapper)
    return steps


def main():
    enc=load_encoder()
    for name,source in CASES:
        rom,labels=enc.parse_source(source)
        steps=simulate(rom,labels)
        print(f'{name}: PASS ({steps} instructions before ClearScreen)')
    return 0


if __name__=='__main__':
    sys.exit(main())
