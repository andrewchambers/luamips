#! /bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DIR=$DIR/cur_fuzz/

mips-baremetal-elf-gcc -DCSMITH_MINIMAL -DNO_PRINTF -I$DIR/csmith_headers/ -nostartfiles $DIR/plat.c $DIR/support.c $DIR/start.S rand_prog.c -o kern
mips-baremetal-elf-objcopy -Osrec kern kern.srec
echo "" | timeout 1s qemu-system-mips -machine mips  -cpu 4kc -kernel kern -nographic -serial file:$DIR/hash1.out
grep "checksum =" $DIR/hash1.out 

set +e

#this is gonna be alot slower.
timeout 10s luajit $DIR/../../emu.lua ./kern.srec > $DIR/hash2.out

RETCODE=$?

if [ $RETCODE -eq 124  ] ; then
    echo "not interesting! - timeouts take too long"
    exit 1
fi

if [ $RETCODE -ne 0  ] ; then
    echo "interesting! - error"
    exit 0
fi

if ! diff -u $DIR/hash1.out $DIR/hash2.out ; then
   echo "interesting! - differing checksums"
   exit 0
fi

exit 1
