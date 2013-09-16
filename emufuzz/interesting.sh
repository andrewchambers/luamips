#! /bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

mips-baremetal-elf-gcc -DCSMITH_MINIMAL -DNO_PRINTF -I$DIR/csmith_headers/ -nostartfiles $DIR/plat.c $DIR/support.c $DIR/start.S rand_prog.c -o kern
mips-baremetal-elf-objcopy -Osrec kern kern.srec
echo "" | timeout 2s qemu-system-mips -machine mips  -cpu 4kc -kernel kern -nographic -serial file:hash1.out
grep "checksum =" ./hash1.out 

set +e

#this is gonna be alot slower.
timeout 60s luajit $DIR/../emu.lua ./kern.srec > hash2.out

if [ $? -ne 0  ] ; then
    echo "interesting! - timeout or error"
    exit 0
fi

#if ! diff -u hash1.out hash2.out ; then
#   echo "interesting! - differing checksums"
#   exit 0
#fi


exit 1
