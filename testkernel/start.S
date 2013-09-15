

.extern main

.global _start
_start:
	li $sp, 0x83000000
	la $gp, _gp
	jal main
	loop:
	j loop
