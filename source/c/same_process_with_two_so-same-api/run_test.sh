#!/usr/bin/env bash
echo "The dependencies are as follows:"
echo "    test --liba.so <- libc1.so"
echo "         \-libb.so <- libc2.so"

echo -e "\ntest1: dlopen with flag RTLD_GLOBAL\n"
make run1

echo -e "\ntest2: dlopen with flag RTLD_LOCAL\n"
make run2

echo -e "\ntest3: run in same thread and .so dependency automatically\n"
make run_auto

echo -e "\ntest4: run in diffrent thread and .so dependency automatically\n"
make run_thread


echo -e "\n clean!\n"
make clean
