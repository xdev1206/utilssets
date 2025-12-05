#include <stdio.h>
#include "libc2.h"

void call_b() {
    printf("libb calling foo():\n");
    foo();

    printf("libb calling foo_again():\n");
    foo_again();
}

