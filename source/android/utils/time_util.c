/*#include <time.h>

struct timespec
{
    time_t tv_sec; [>second<]
    long tv_nsec;  [>nanosecond<]
}*/

#include <time.h>
#include <memory.h>
#include <stdio.h>

int main()
{
    // It's best not to use gettimeofday() or currentTimeMillis() on a mobile
    // device. These return "wall clock" time, which can jump forward or
    // backward suddenly if the network updates the time.

    // Use the monotonic clock instead for performance measurements
    // System.nanoTime() or clock_gettime() with CLOCK_MONOTONIC.
    // Note this returns a struct timespec rather than a struct timeval;
    // primary difference is that the clock resolution is nanoseconds
    // rather than microseconds.
    struct timespec wall_time, monotonic_time;

    memset(&wall_time, 0, sizeof(struct timespec));
    memset(&monotonic_time, 0, sizeof(struct timespec));

    clock_gettime(CLOCK_REALTIME, &wall_time);  // wall time
    clock_gettime(CLOCK_MONOTONIC, &monotonic_time);  // monotonic_time

    printf("second: %ld, nanosecond: %ld\n", wall_time.tv_sec, wall_time.tv_nsec);

    long int timer;
    struct timeval time_start;
    struct timeval time_end;

    gettimeofday(&time_start, NULL);  // wall time
    gettimeofday(&time_end, NULL);

    timer = 1000000 * (time_end.tv_sec - time_start.tv_sec) + (time_end.tv_usec - time_start.tv_usec);
    return 0;
}
