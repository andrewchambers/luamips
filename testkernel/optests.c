#include "test.h"


void test_lui() {
	
	int v = 0;
	
	#define T(INIT,V,RES) \
	v = INIT; \
	asm("lui %0, " V "\n" : "=r"(v): "r"(v)); \
	if (v != RES) { \
		FAIL;\
	}
	
	T(0,"0xffff",0xffff0000)
	T(0xff,"0xffff",0xffff0000)
	T(0,"0x1000",0x10000000)
	T(0,"0x0",0x00000000)
	#undef T
	
}

void test_lw() {
	
	int x;
	int v[] = {0x11223344,0x44332211};
	int * p = &v[0];
	
	asm("lw %0, 0(%1)\n" : "=r"(x) : "r"(p));
	
	if ( x != 0x11223344) {
		FAIL;
	}
	
	asm("lw %0, 4(%1)\n" : "=r"(x) : "r"(p));
	
	if ( x != 0x44332211) {
		FAIL;
	}
	
}

void test_ori() {
	int v = 0;
	
	#define T(INIT,V,RES) \
	v = INIT; \
	asm("ori %0, " V "\n" : "=r"(v): "r"(v)); \
	if (v != RES) { \
		FAIL;\
	}
	
	T(0,"0xffff",0xffff)
	T(0xff,"0xffff",0xffff)
	T(0,"0x1000",0x1000)
	T(0xff,"0xff00",0xffff)
	#undef T
}


void test_sll() {
	
	int a;
	int v;
	
	#define T(A,SA,RES) \
	a = A;  \
	asm("sll %0, %1, " SA "\n" : "=r"(v): "r"(a)); \
	if (v != RES) { \
		FAIL;\
	}
	
	T(0,"0",0x0);
	T(0xfffffffe,"31",0x0);
	T(0xffffffff,"31",0x80000000);
	T(0x1,"2",4);

	#undef T
}



#define T(x) putb('.'); x()

void test_ops() {
	outs("starting opcode tests...");
	T(test_lui);
	T(test_lw);
	T(test_ori);
	T(test_sll);
	outs("\nfinished opcode tests...");
}
