/*
 * compilation:
 * g++ -o timeExe time_util.c -std=c++11
 */

/*#include <time.h>

struct timespec
{
    time_t tv_sec; [>second<]
    long tv_nsec;  [>nanosecond<]
}*/

#include <iostream>
#include <unistd.h> // usleep function

#include <time.h>
#include <memory.h>
#include <stdio.h>
#include <chrono> // C++
#include <sys/time.h> // gettimeofday

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

    struct timeval time_start;
    struct timeval time_end;

    gettimeofday(&time_start, NULL);  // wall time
    gettimeofday(&time_end, NULL);

    long int timer = 1000000 * (time_end.tv_sec - time_start.tv_sec) + (time_end.tv_usec - time_start.tv_usec);
    printf("gettimeofday: %ld\n", timer);

    /*
     * C++ print timestamp and date
     */
    auto start = std::chrono::system_clock::now();
    // Some computation here
    usleep(100000); // sleep 100ms
    auto end = std::chrono::system_clock::now();

    std::time_t end_time = std::chrono::system_clock::to_time_t(end);
    std::chrono::duration<double> elapsed_seconds = end - start;

    std::cout << "date: " << std::ctime(&end_time)
              << "elapsed time: " << elapsed_seconds.count() << "s\n";
    return 0;
}
