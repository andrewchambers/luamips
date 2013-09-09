
void outs(const char * s);
void putb(char s);
void test_ops();

#define FAIL do { outs("\nFAILED:"); putb(' '); putb(' ');  outs(__func__); while(1) ; } while(0)
