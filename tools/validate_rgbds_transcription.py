#!/usr/bin/env python3
from pathlib import Path
import re, ast, hashlib, json, sys

ROM_SIZE=2*1024*1024
SYMS={'MBC_RAM_ENABLE':0x0000,'MBC_RAM_RTC_SELECT':0x4000,'MBC_LATCH':0x6000,'SRAM_WINDOW':0xA000}
R8=['b','c','d','e','h','l','[hl]','a']
R8I={r:i for i,r in enumerate(R8)}
R16=['bc','de','hl','sp']; R16I={r:i for i,r in enumerate(R16)}
CONDS={'nz':0,'z':1,'nc':2,'c':3}

def split_args(s):
    out=[]; cur=''; q=False
    for ch in s:
        if ch=='"': q=not q; cur+=ch
        elif ch==',' and not q: out.append(cur.strip()); cur=''
        else: cur+=ch
    if cur.strip(): out.append(cur.strip())
    return out

def val(tok, labels=None):
    tok=tok.strip()
    if labels and tok in labels: return labels[tok]
    if tok in SYMS: return SYMS[tok]
    if tok.upper() in SYMS: return SYMS[tok.upper()]
    if tok.startswith('$'): return int(tok[1:],16)
    if tok.startswith('%'): return int(tok[1:],2)
    return int(tok,0)

def strip_comment(line):
    q=False
    for i,ch in enumerate(line):
        if ch=='"': q=not q
        if ch==';' and not q: return line[:i]
    return line

def data_bytes(line, base, labels, cwd):
    low=line.lower()
    if low.startswith('db '):
        bs=bytearray()
        for arg in split_args(line[3:]):
            if arg.startswith('"'):
                bs += ast.literal_eval(arg).encode('latin1')
            else: bs.append(val(arg,labels)&0xff)
        return bytes(bs)
    if low.startswith('ds '):
        a=split_args(line[3:]); n=val(a[0],labels); fill=val(a[1],labels)&0xff if len(a)>1 else 0
        return bytes([fill])*n
    if low.startswith('incbin '):
        path=ast.literal_eval(line.split(None,1)[1].strip())
        return (cwd/path).read_bytes()
    return None

def ins_size(line,cwd):
    d=data_bytes(line,0,{},cwd)
    if d is not None: return len(d)
    l=line.lower().strip()
    if not l: return 0
    op=l.split()[0]
    if op in ('nop','di','ei','reti','halt','cpl','scf'): return 1
    if op in ('swap','srl','sla'): return 2
    if op=='ret': return 1
    if op in ('jp','call'): return 3
    if op=='jr': return 2
    if op in ('push','pop','inc','dec'): return 1
    if op=='rst': return 1
    if op=='ldh': return 2
    if op=='ld':
        a=split_args(line.split(None,1)[1])
        dst,src=a[0].lower(),a[1].lower()
        if dst in R16I: return 3
        if dst in R8I and (src.startswith('$') or src.isdigit()): return 2
        if dst in R8I and src in R8I: return 1
        if (dst=='a' and src.startswith('[') and src not in ('[hl]','[hli]','[hld]','[de]')) or (dst.startswith('[') and dst not in ('[hl]','[hli]','[hld]','[de]') and src in ('a','sp')): return 3
        if (dst,src) in (('[hli]','a'),('a','[hli]'),('[hld]','a'),('a','[hld]'),('[de]','a'),('a','[de]'),('[hl]','a'),('a','[hl]')): return 1
        if dst=='[hl]': return 2
        raise ValueError('ld size '+line)
    if op=='add':
        a=split_args(line.split(None,1)[1]);
        if a[0].lower()=='hl': return 1
        return 2 if a[1].strip().startswith('$') else 1
    if op=='adc': return 1
    if op in ('and','or','xor','cp','sub'):
        arg=line.split(None,1)[1].strip().lower(); return 2 if arg.startswith('$') or arg.isdigit() else 1
    raise ValueError('size unknown '+line)

def enc_ins(line, pc, labels, cwd):
    d=data_bytes(line,pc,labels,cwd)
    if d is not None: return d
    l=line.strip(); low=l.lower(); op=low.split()[0]
    if op in {'nop','di','ei','reti','halt','cpl','scf'}:
        return bytes([{'nop':0x00,'di':0xF3,'ei':0xFB,'reti':0xD9,'halt':0x76,'cpl':0x2F,'scf':0x37}[op]])
    if op in ('swap','srl','sla'):
        assert low.split(None,1)[1].strip()=='a'; return bytes([0xCB,{'swap':0x37,'srl':0x3F,'sla':0x27}[op]])
    if op=='ret':
        parts=low.split(); return bytes([0xC9 if len(parts)==1 else {'nz':0xC0,'z':0xC8,'nc':0xD0,'c':0xD8}[parts[1]]])
    if op in ('jp','call'):
        args=split_args(l.split(None,1)[1]); cond=None
        if len(args)==2: cond=args[0].lower(); target=args[1]
        else: target=args[0]
        v=val(target,labels)
        if op=='jp': opc=0xC3 if cond is None else {'nz':0xC2,'z':0xCA,'nc':0xD2,'c':0xDA}[cond]
        else: opc=0xCD if cond is None else {'nz':0xC4,'z':0xCC,'nc':0xD4,'c':0xDC}[cond]
        return bytes([opc,v&255,v>>8&255])
    if op=='jr':
        args=split_args(l.split(None,1)[1]); cond=None
        if len(args)==2: cond=args[0].lower(); target=args[1]
        else: target=args[0]
        tgt=val(target,labels); disp=tgt-(pc+2)
        if not -128<=disp<=127: raise ValueError(f'JR range {pc:04x}->{tgt:04x}')
        opc=0x18 if cond is None else {'nz':0x20,'z':0x28,'nc':0x30,'c':0x38}[cond]
        return bytes([opc,disp&255])
    if op in ('push','pop'):
        r=low.split()[1]; return bytes([({'push':{'bc':0xC5,'de':0xD5,'hl':0xE5,'af':0xF5},'pop':{'bc':0xC1,'de':0xD1,'hl':0xE1,'af':0xF1}}[op])[r]])
    if op in ('inc','dec'):
        r=low.split()[1]
        rr={'inc':{'bc':0x03,'de':0x13,'hl':0x23,'sp':0x33},'dec':{'bc':0x0B,'de':0x1B,'hl':0x2B,'sp':0x3B}}[op]
        if r in rr: return bytes([rr[r]])
        base=0x04 if op=='inc' else 0x05; return bytes([base+8*R8I[r]])
    if op=='rst':
        v=val(l.split(None,1)[1],labels); return bytes([0xC7+(v//8)*8])
    if op=='ldh':
        args=split_args(l.split(None,1)[1]); dst,src=args[0].lower(),args[1].lower()
        if dst=='a': addr=val(src[1:-1],labels); return bytes([0xF0,addr&0xFF])
        addr=val(dst[1:-1],labels); return bytes([0xE0,addr&0xFF])
    if op=='ld':
        args=split_args(l.split(None,1)[1]); dst,src=args[0].lower(),args[1].lower()
        if dst in R16I:
            v=val(args[1],labels); return bytes([0x01+0x10*R16I[dst],v&255,v>>8&255])
        if dst in R8I and src in R8I: return bytes([0x40+8*R8I[dst]+R8I[src]])
        if dst in R8I and (src.startswith('$') or src.isdigit()): return bytes([0x06+8*R8I[dst],val(args[1],labels)&255])
        specials={('[hli]','a'):0x22,('a','[hli]'):0x2A,('[hld]','a'):0x32,('a','[hld]'):0x3A,('[de]','a'):0x12,('a','[de]'):0x1A,('[hl]','a'):0x77,('a','[hl]'):0x7E}
        if (dst,src) in specials: return bytes([specials[(dst,src)]])
        if dst=='[hl]': return bytes([0x36,val(args[1],labels)&255])
        if dst=='a' and src.startswith('['):
            v=val(src[1:-1],labels); return bytes([0xFA,v&255,v>>8&255])
        if dst.startswith('[') and src=='a':
            v=val(dst[1:-1],labels); return bytes([0xEA,v&255,v>>8&255])
        if dst.startswith('[') and src=='sp':
            v=val(dst[1:-1],labels); return bytes([0x08,v&255,v>>8&255])
        raise ValueError('ld encode '+line)
    if op=='add':
        args=split_args(l.split(None,1)[1]); dst,argsrc=args[0].lower(),args[1].lower()
        if dst=='hl': return bytes([0x09+0x10*R16I[argsrc]])
        assert dst=='a'
        if argsrc in R8I: return bytes([0x80+R8I[argsrc]])
        return bytes([0xC6,val(args[1],labels)&255])
    if op=='adc':
        args=split_args(l.split(None,1)[1]); assert args[0].lower()=='a'; return bytes([0x88+R8I[args[1].lower()]])
    if op in ('and','or','xor','cp','sub'):
        arg=l.split(None,1)[1].strip().lower()
        if arg in R8I:
            base={'and':0xA0,'xor':0xA8,'or':0xB0,'cp':0xB8,'sub':0x90}[op]
            return bytes([base+R8I[arg]])
        opc={'and':0xE6,'or':0xF6,'xor':0xEE,'cp':0xFE,'sub':0xD6}[op]
        return bytes([opc,val(l.split(None,1)[1],labels)&255])
    raise ValueError('encode unknown '+line)

def parse_source(path):
    cwd=path.parent.parent  # rgbds/ directory, matching Makefile execution
    raw=[strip_comment(x).strip() for x in path.read_text().splitlines()]
    raw=[x for x in raw if x and not x.upper().startswith('INCLUDE ')]
    labels={}; pc=None
    # first pass
    for line in raw:
        if line.upper().startswith('SECTION '):
            m=re.search(r'ROM0\[\$(?P<a>[0-9A-Fa-f]+)\]',line,re.I)
            if m: pc=int(m.group('a'),16); continue
            m=re.search(r'ROMX\[\$(?P<a>[0-9A-Fa-f]+)\],\s*BANK\[(?P<b>\d+)\]',line,re.I)
            if m: pc=int(m.group('b'))*0x4000+(int(m.group('a'),16)-0x4000); continue
            raise ValueError('section '+line)
        if line.endswith(':'):
            if pc is None: raise ValueError('label no section')
            labels[line[:-1]]=pc; continue
        if pc is None: continue
        pc += ins_size(line,cwd)
    rom=bytearray([0xFF])*ROM_SIZE; pc=None
    for line in raw:
        if line.upper().startswith('SECTION '):
            m=re.search(r'ROM0\[\$(?P<a>[0-9A-Fa-f]+)\]',line,re.I)
            if m: pc=int(m.group('a'),16); continue
            m=re.search(r'ROMX\[\$(?P<a>[0-9A-Fa-f]+)\],\s*BANK\[(?P<b>\d+)\]',line,re.I)
            pc=int(m.group('b'))*0x4000+(int(m.group('a'),16)-0x4000); continue
        if line.endswith(':'): continue
        if pc is None: continue
        b=enc_ins(line,pc,labels,cwd); rom[pc:pc+len(b)]=b; pc+=len(b)
    # rgbfix -v equivalent for the two checksums (header fields are already authored).
    x=0
    for b in rom[0x134:0x14D]: x=(x-b-1)&0xff
    rom[0x14D]=x
    g=(sum(rom[:0x14E])+sum(rom[0x150:]))&0xffff
    rom[0x14E]=(g>>8)&255; rom[0x14F]=g&255
    return bytes(rom), labels

def main(root):
    root=Path(root)
    entries=[
        ("diag", "A", "diag/rgbds/src/X7MBC3DIAG-A.asm", "roms/X7MBC3DIAG-A.gbc", "663ac2065d7637377b857fd2927de026c6eb73ea0dd9669cef7d36246fe0ac66"),
        ("diag", "B", "diag/rgbds/src/X7MBC3DIAG-B.asm", "roms/X7MBC3DIAG-B.gbc", "1548c6d9de6dd4a58526249c2d96449fe3405a3af3b68d62c1ad48414bb9c4c9"),
        ("diag", "N", "diag/rgbds/src/X7MBC3DIAG-N.asm", "roms/X7MBC3DIAG-N.gbc", "311ad9a6ebf87727767801ad0ed8a4c20b62d8293916f625c77a9b0ae38f5217"),
        ("trace", "A", "trace/rgbds/src/X7MBC3TRACE-A.asm", "roms/X7MBC3TRACE-A.gbc", "e5dbded1457ead2901fd0748e9be3c4de37d9fddfe459baaba0ef208f53b29ef"),
        ("trace", "B", "trace/rgbds/src/X7MBC3TRACE-B.asm", "roms/X7MBC3TRACE-B.gbc", "46073c139d7a8ffffbbdcf9abb9416d54a44d276fdc7fd644d485b0d5ea0aa71"),
        ("trace", "N", "trace/rgbds/src/X7MBC3TRACE-N.asm", "roms/X7MBC3TRACE-N.gbc", "385592019b9f4fc14b18da35736b759c1a474d35fe0dc435eedb20cb3bae497d"),
        ("pokertc", "P", "pokertc/rgbds/src/X7POKERTC.asm", "roms/X7POKERTC.gbc", "f34e1b1533a7e931780e0276267f1a0c6438d293e20824b46a90ec3f85c76f5c"),
    ]
    failures=[]
    for family,variant,source,reference,expected in entries:
        src=root/source; ref=root/reference
        try: rom,labels=parse_source(src)
        except Exception as e:
            failures.append((str(src),f'parse/encode: {e}')); continue
        actual=hashlib.sha256(rom).hexdigest()
        exact=rom==ref.read_bytes()
        print(f"{family:7s} {variant:4s} exact={exact} sha={actual}")
        if not exact or actual != expected:
            rd=ref.read_bytes(); diffs=[i for i,(a,b) in enumerate(zip(rom,rd)) if a!=b]
            failures.append((str(src),f'{len(diffs)} diffs first={diffs[:10]} actual={actual} expected={expected}'))
    if failures:
        print('FAILURES:')
        for f,m in failures: print(f,m)
        return 1
    print('All RGBDS source transcriptions reproduce the canonical pre-built ROMs byte-for-byte under the independent subset encoder.')
    return 0
if __name__=='__main__': sys.exit(main(sys.argv[1] if len(sys.argv)>1 else '.'))
