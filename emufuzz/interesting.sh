set -e


rm -f ./hash1.out ./hash2.out ./kern.srec ./kern
mips-baremetal-elf-gcc -mno-plt -DCSMITH_MINIMAL -DNO_PRINTF -I`pwd`/csmith_headers/ -nostartfiles plat.c support.c start.S rand_prog.c -o kern
mips-baremetal-elf-objcopy -Osrec kern kern.srec
timeout --foreground 2s qemu-system-mips -machine mips  -cpu 4kc -kernel kern -nographic > ./hash1.out
grep "checksum =" ./hash1.out 

set +e

#this is gonna be alot slower. lets say 100 times threshold
timeout 200s lua ../emu.lua ./kern.srec > hash2.out

if [ $? -ne 0  ] ; then
    echo "interesting! - timeout or error"
    exit 0
fi

if ! diff -u hash1.out hash2.out ; then
   echo "interesting! - differing checksums"
   exit 0
fi


exit 1
