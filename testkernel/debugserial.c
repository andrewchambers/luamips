#define DEBUGOUTADDR 0xB0000000



void putb(char b) {
	while(*((char*)(DEBUGOUTADDR)) == 0)
		/* wait for ready */
		;
	*((char*)(DEBUGOUTADDR)) = b;
}



void outs(const char * s) {
	while(*s){
		putb(*s++);
	}
	putb('\n');
}

