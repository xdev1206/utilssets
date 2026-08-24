#include <stdio.h>
#include <dlfcn.h>

typedef void (*func_t)();

int main() {
    void* ha = dlopen("./liba.so", RTLD_NOW | RTLD_LOCAL);
    void* hb = dlopen("./libb.so", RTLD_NOW | RTLD_LOCAL);

    func_t call_a = (func_t)dlsym(ha, "call_a");
    func_t call_b = (func_t)dlsym(hb, "call_b");

    printf("--- calling liba ---\n");
    call_a();

    printf("--- calling libb ---\n");
    call_b();

    return 0;
}

