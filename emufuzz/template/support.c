#include "plat.h"


void* memcpy(void* dest, const void* src, unsigned int count) {
  char* dst8 = (char*)dest;
  char* src8 = (char*)src;
  
  while (count--) {
    *dst8++ = *src8++;
  }
  return dest;
}

void *memset(void *s, int c, unsigned int n)
{
    unsigned char* p=s;
    while(n--)
        *p++ = (unsigned char)c;
    return s;
}

int putchar (int c) {
	write_serial(c);
}

