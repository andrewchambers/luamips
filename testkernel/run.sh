set -e

#if run with an arg selects that test.
#else runs current test

if [ $# -eq 1 ] ; then
    bash select.sh $1
fi

if which luajit > /dev/null ; then
    INTERP=luajit
else
    INTERP=lua
fi

set +e
echo "" | timeout 2s qemu-system-mips -machine mips -cpu 4kc -nographic -kernel kern > qemu.out
timeout 20s $INTERP ../emu.lua ./kern.srec > luamips.out
set -e

if grep -q FAIL ./luamips.out ; then
    exit 1
fi

if grep -q FAIL ./qemu.out ; then
    exit 2
fi

if ! diff qemu.out luamips.out > /dev/null ; then
    exit 3
fi
