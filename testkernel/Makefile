
CC=mips-baremetal-elf-gcc
OBJCOPY=mips-baremetal-elf-objcopy

kern.srec: kern
	$(OBJCOPY) -Osrec kern kern.srec

kern: exec_tests.gen.c *.c *.h *.S
	$(CC) -O0 -nostartfiles *.c *.S -o kern

exec_tests.gen.c: generate_exec_tests.sh ./exec/*.c
	bash generate_exec_tests.sh

clean:
	rm -vf ./kern.srec ./kern
	rm -vf *.o *.gen.c
