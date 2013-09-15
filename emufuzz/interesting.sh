set -e

TIMEOUT=5s


rm -f ./hash.out
mips-baremetal-elf-gcc -mno-plt -DCSMITH_MINIMAL -DNO_PRINTF -I`pwd`/csmith_headers/ -nostartfiles plat.c support.c start.S rand_prog.c -o kern
timeout --foreground $TIMEOUT qemu-system-mips -machine mips  -cpu 4kc -kernel kern -nographic > ./hash.out
grep "checksum =" ./hash.out 

echo "interesting!"
