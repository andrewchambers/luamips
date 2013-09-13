
#ifndef DEBUG_SERIAL 

#define UART_LSR 5 /* In:  Line Status Register */
#define UART_LSR_THRE 0x2 /* Transmit-hold-register empty */
#define PORT(offset) (0x1f000900 + (offset))
#define UART_TX         0       /* Out: Transmit buffer */

static inline void serial_out(int offset, int value)
{
	*(volatile int*)(PORT(offset)) = value;
}

static inline unsigned int serial_in(int offset)
{
	return *(volatile int*)(PORT(offset));
}

int putb(char c)
{
	while ((serial_in(UART_LSR) & UART_LSR_THRE) == 0)
		;

	serial_out(UART_TX, c);

	return 1;
}


#else

#define DEBUGOUTADDR 0xB0000000
void putb(char b) {
	while(*((char*)(DEBUGOUTADDR)) == 0)
		/* wait for ready */
		;
	*((char*)(DEBUGOUTADDR)) = b;
}

#endif

void outs(const char * s) {
	while(*s){
		putb(*s++);
	}
	putb('\n');
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
        putb(*o);
        o++;
    }
}





