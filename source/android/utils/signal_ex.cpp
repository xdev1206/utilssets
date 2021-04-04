// gcc signal_ex.cpp -o sigaction -lpthread

#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <syscall.h>

// man sigaction
// signal handler
void sig_handler(int signal)
{
    switch (signal) {
    case SIGINT:
        printf("tid: %d receive signal: %d, force exit!\n", syscall(SYS_gettid), signal);
        pthread_exit(0);
        break;
    default:
        printf("tid: %d receive signal: %d.\n", syscall(SYS_gettid), signal);
        break;
    }
}

void* thread_func(void* arg)
{
    struct sigaction siga;
    siga.sa_handler = sig_handler;

    int siga_ret;
    siga_ret = sigaction(SIGQUIT, &siga, NULL); // ctrl-4
    siga_ret = sigaction(SIGINT, &siga, NULL);  // ctrl-c
    if (siga_ret == -1) {
        printf("sigcation error: %s.\n", strerror(errno));
    }

    int slp = 100;
    while (1) {
        printf("tid: %d sleep %ds.\n", syscall(SYS_gettid), slp);
        sleep(slp); // sleep
    }
}

int main(void)
{
    pthread_t pthread;
    pthread_create(&pthread, NULL, thread_func, NULL);

    printf("tid: %d sleep 1s wait thread run.\n", syscall(SYS_gettid));
    sleep(1);

    pthread_kill(pthread, SIGINT);

    printf("sleep 1s wait thread handle signal.\n");
    sleep(1);
}
