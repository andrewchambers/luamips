.section .text
.global _start
_start:
    li $t0,0xb0000004
    lw $t0,0($t0)
    move $sp,$t0
    li $t0,0xa0000000
    add $sp,$sp,$t0
    jal main
    ___loop:
    j ___loop
