
CC=mips-baremetal-elf-gcc
OBJCOPY=mips-baremetal-elf-objcopy

kern.srec: kern
	$(OBJCOPY) -Osrec kern kern.srec

kern: *.c *.h *.S
	$(CC) -O0 -nostartfiles *.c *.S -o kern

clean:
	rm -vf ./kern.srec ./kern
	rm -vf *.o
