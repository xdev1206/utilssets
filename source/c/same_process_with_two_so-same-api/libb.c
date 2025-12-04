#include <stdio.h>
#include "libc2.h"

void call_b() {
    printf("libb calling foo():\n");
    foo();
}

