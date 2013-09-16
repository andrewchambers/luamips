#include "plat.h"

int putchar (int c) {
	write_serial(c);
}

void outs(const char * s) {
	while(*s){
		putchar(*s++);
	}
	putchar('\n');
}

void outn(unsigned int n) {
    int i = 0;
    char * hexchars = "0123456789abcdef";
    char output[9];
    output[8] = 0;
    while (i != 8) {
        output[7-i] = hexchars[n % 16];
        n = n / 16;
        i++;
    }
    
    char * o = &output[0];
    
    while(*o){
        putchar(*o);
        o++;
    }
}

