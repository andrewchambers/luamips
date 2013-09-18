import sys

buff = ""
def next():
    global buff
    if len(buff):
        ret = buff[-1]
        buff = buff[:-1]
        return ret
    return sys.stdin.read(1)

def rewind(s):
    global buff
    buff = s[::-1] + buff

def consume(s):
    for i,c in enumerate(s):
        inc = next()
        if c != inc:
            raise Exception("char '%s' not equal '%s'  (matching against '%s'[%d]) "%(inc,c,s,i))

def hexnum():
    start = next() + next()
    if start != "0x":
        rewind(start)
    
    hexnum = ""
    
    while True:
        c = next()
        if c in "0123456789abcdef":
            hexnum += c
        else:
            rewind(c)
            break
    
    if len(hexnum) == 0:
        raise Exception("expected a hex number!")
    
    return int(hexnum,16)
    
def is_eof():
    n = next()
    if n == "":
        return True
    rewind(n)
    return False 


def parseFormat(formatString):
    ret = {}
    idx = 0
    while idx < len(formatString):
        if formatString[idx:idx+1] == "%%":
            consume("%")
            idx += 2
            continue
        if formatString[idx] == "%":
            idx += 1
            import string
            name = ""
            while idx < len(formatString) and formatString[idx] in (string.letters + string.digits):
                name += formatString[idx]
                idx += 1
            try:
                n = hexnum()
                ret[name] = n
            except:
                raise Exception("hex num parse failed! hex num -> %s" % name)
        if formatString[idx] != next():
            raise Exception("bad match on format string %s at idx %d" % (formatString,idx))
        
        idx += 1
    return ret            

cpuFormat = """pc=%pc HI=%hi LO=%lo ds %xxx %xxx %xxx
GPR00: r0 %r0 at %at v0 %v0 v1 %v1
GPR04: a0 %a0 a1 %a1 a2 %a2 a3 %a3
GPR08: t0 %t0 t1 %t1 t2 %t2 t3 %t3
GPR12: t4 %t4 t5 %t5 t6 %t6 t7 %t7
GPR16: s0 %s0 s1 %s1 s2 %s2 s3 %s3
GPR20: s4 %s4 s5 %s5 s6 %s6 s7 %s7
GPR24: t8 %t8 t9 %t9 k0 %k0 k1 %k1
GPR28: gp %gp sp %sp s8 %s8 ra %ra
CP0 Status  %xxx Cause   %xxx EPC    %xxx
    Config0 %xxx Config1 %xxx LLAddr %xxx
"""
def cpuEntry():
    return parseFormat(cpuFormat)

state = {}

while not is_eof():
    test = next() + next() + next()
    rewind(test)
    if test == "pc=":        
        entry = cpuEntry()
        del entry['xxx']
        tentry = "{"
        for idx,k in enumerate(entry):
            if entry[k] != state.get(k,None):
                state[k] = entry[k] 
                tentry += ' "%s" : %d ,'%(k,entry[k])
        if tentry != "{":#handle no entries
            tentry = tentry[:-1]
        tentry += "}\n"
        sys.stdout.write(tentry)
        sys.stdout.flush()
    else:
        while next() != "\n":
            continue

