set -e

CURTEST=`cat ./cur_test/CURTEST`

mips-baremetal-elf-gcc -msoft-float -DCURTEST=$CURTEST -I./cur_test -nostartfiles ./cur_test/*.c ./cur_test/*.S -o kern 2> gccerrs.out
mips-baremetal-elf-objcopy -Osrec kern kern.srec
