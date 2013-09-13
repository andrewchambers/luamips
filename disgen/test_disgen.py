from disgen import *
import pytest

def test_fixOpstring():
    assert fixOpstring("abc xxx 10 3") == "xxxxxx10x"

def test_opstringsame():
    assert canNotDistinguishOpstring("xxx","xxx")
    assert canNotDistinguishOpstring("111","xxx")
    assert canNotDistinguishOpstring("000","xxx")
    assert not canNotDistinguishOpstring("000","x1x")
    assert not canNotDistinguishOpstring("000","111")
    assert not canNotDistinguishOpstring("000","111")

def test_ensureCanDistinguish():
    vals = [["foo","xxx"],["bar","1xx"]]
    
    with pytest.raises(Exception):
        ensureCanDistinguish(vals)
    
    vals = [["foo","0xx"],["bar","1xx"]]
    ensureCanDistinguish(vals)
    

def testopstringToMask():
    assert opstringToMask("0011xx0011") == "1111001111"

def testFindBestAndMask():
    v = [["foo","11x0"],["bar","00x0"]]
    best = findBestAndMask(v)
    assert best == "1101"

def testopstringToVal():
    assert opstringToVal("111xx00") == 0b1110000