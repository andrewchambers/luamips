
#define UART_LSR 5 /* In:  Line Status Register */
#define UART_LSR_THRE 0x20 /* Transmit-hold-register empty */
#define PORT(offset) (0xa0000000 + 0x14000000 + 0x3f8 + (offset))
#define UART_TX         0       /* Out: Transmit buffer */


static inline void serial_out(int offset, int value)
{
	*(volatile unsigned char*)(PORT(offset)) = value;
}

static inline unsigned int serial_in(int offset)
{
	return (unsigned int)(*(volatile unsigned char*)(PORT(offset)));
}

int putb(char c)
{
	while ((serial_in(UART_LSR) & UART_LSR_THRE) == 0)
		;

	serial_out(UART_TX, c);

	return 1;
}

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





