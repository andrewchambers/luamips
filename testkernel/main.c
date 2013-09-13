#include "test.h"



int main(){
    outs("mips test kernel...");
    outs("sanity beef: ");
    putb(' '); putb(' ');
    outn(0xdeadbeef);
    putb('\n');
	outs("test start...");
	test_ops();
    test_exec();
	outs("test end...");
	return 0;
}
