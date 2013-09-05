import sys
import re

#remaps errors in emu.lua to the original source file


def repl(m):
    s = m.group(0)
    curfname = "unknown"
    curlineno = 0
    targetline = int(s[len("emu.lua:"):].strip())
    for idx,line in enumerate(open("emu.lua")):
        if idx == targetline:
            return "%s:%s"%(curfname,curlineno)
            
        curlineno += 1
        if line.startswith("--!!FILE "):
            curfname = line[len("--!!FILE "):].strip()
            curlineno = 0
    return "unknown:unknown"
    
for line in sys.stdin:
    line,n = re.subn(r"emu\.lua\:[0-9]+", repl, line)
    sys.stdout.write(line)
    sys.stdout.flush()
