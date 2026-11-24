#!/usr/bin/env python3
"""Check a kernel's symbol CRCs against modules or a saved reference list.

  kmi_check.py dump <out.txt> <module dir>...   save the kernel symbols the
                                                 modules import, with CRCs
  kmi_check.py check <vmlinux.symvers> <ref.txt>  fail if any CRC differs or
                                                 a symbol is not exported
"""
import os, struct, sys

def sections(path):
    b = open(path, 'rb').read()
    shoff, = struct.unpack_from('<Q', b, 0x28)
    shentsize, shnum, shstrndx = struct.unpack_from('<HHH', b, 0x3a)
    hdrs = [struct.unpack_from('<IIQQQQIIQQ', b, shoff + i * shentsize) for i in range(shnum)]
    strtab = hdrs[shstrndx][4]
    out = {}
    for h in hdrs:
        name = b[strtab + h[0]:b.index(b'\0', strtab + h[0])].decode()
        out[name] = b[h[4]:h[4] + h[5]]
    return out

def dump(out, dirs):
    imports, exported = {}, set()
    for d in dirs:
        for root, _, files in os.walk(d):
            for f in files:
                if not f.endswith('.ko'):
                    continue
                s = sections(os.path.join(root, f))
                exported |= {x.decode() for x in s.get('__ksymtab_strings', b'').split(b'\0') if x}
                v = s.get('__versions', b'')
                for i in range(0, len(v), 64):
                    crc, = struct.unpack('<Q', v[i:i + 8])
                    imports[v[i + 8:i + 64].split(b'\0')[0].decode()] = crc & 0xffffffff
    with open(out, 'w') as fh:
        for name in sorted(n for n in imports if n not in exported):
            fh.write(f'0x{imports[name]:08x}\t{name}\n')
    print(f'{out}: {len([n for n in imports if n not in exported])} kernel symbols')

def check(symvers, ref):
    have = {}
    for line in open(symvers):
        p = line.split('\t')
        have[p[1]] = int(p[0], 16) & 0xffffffff
    bad = missing = total = 0
    for line in open(ref):
        crc, name = line.split()
        total += 1
        if name not in have:
            missing += 1
            print(f'  missing: {name}')
        elif have[name] != int(crc, 16):
            bad += 1
            print(f'  crc changed: {name}')
    print(f'{os.path.basename(ref)}: {total} symbols, {bad} changed, {missing} missing')
    return bad + missing == 0

if __name__ == '__main__':
    if len(sys.argv) >= 4 and sys.argv[1] == 'dump':
        dump(sys.argv[2], sys.argv[3:])
    elif len(sys.argv) == 4 and sys.argv[1] == 'check':
        sys.exit(0 if check(sys.argv[2], sys.argv[3]) else 1)
    else:
        sys.exit(__doc__)
