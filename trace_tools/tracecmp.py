import sys
import json

def main():
    t1 = open(sys.argv[1])
    t2 = open(sys.argv[2])
    
    prevpc = -1
    s1,s2 = {},{}
    for l1,l2 in zip(t1,t2):
        delta1,delta2 = json.loads(l1),json.loads(l2)
        for k in delta1:
            s1[k] = delta1[k]
        
        for k in delta2:
            s2[k] = delta2[k]
        
        if s1 != s2:
            print "Traces diverge after %08x"%prevpc
            sys.exit(1)
        
        prevpc = s1["pc"]
    t1.close()
    t2.close()
    t1 = open(sys.argv[1])
    t2 = open(sys.argv[2])
    t1len = 0
    t2len = 0
    for l in t1:
        t1len += 1
    for l in t2:
        t2len += 1
    if t1len != t2len:
        print "Traces differ in length last PC %08x"%prevpc
        sys.exit(1)
    print "Traces match."
    
main()
