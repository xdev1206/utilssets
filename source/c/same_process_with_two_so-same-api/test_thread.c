#include <stdio.h>
#include <pthread.h>
#include <unistd.h>

void call_a(void);
void call_b(void);

void* thread_func_a(void* arg) {
    printf("[线程 %lu] 调用 call_a()\n", pthread_self());
    call_a();
    return NULL;
}

void* thread_func_b(void* arg) {
    printf("[线程 %lu] 调用 call_b()\n", pthread_self());
    call_b();
    return NULL;
}

int main() {
    printf("\n[多线程自动加载依赖测试]\n");

    pthread_t ta, tb;

    // 创建线程1执行 call_a()
    if (pthread_create(&ta, NULL, thread_func_a, NULL) != 0) {
        perror("pthread_create a");
        return 1;
    }

    // 创建线程2执行 call_b()
    if (pthread_create(&tb, NULL, thread_func_b, NULL) != 0) {
        perror("pthread_create b");
        return 1;
    }

    // 等待线程结束
    pthread_join(ta, NULL);
    pthread_join(tb, NULL);

    printf("[主线程 %lu] 所有子线程执行完毕\n", pthread_self());
    return 0;
}

