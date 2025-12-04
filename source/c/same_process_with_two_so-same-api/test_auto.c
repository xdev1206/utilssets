#include <stdio.h>

void call_a(void);
void call_b(void);

int main() {
    printf("\n[自动加载依赖测试]\n");

    printf("--- calling liba ---\n");
    call_a();

    printf("--- calling libb ---\n");
    call_b();

    return 0;
}
