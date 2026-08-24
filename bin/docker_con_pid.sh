#!/bin/bash

if [ $# -ne 1 ]; then
    echo "need 1 argument."
    exit
fi

script=$0
pid=$1

while :
do
    if [ $pid -eq 0 ]; then
        echo "has reached root process, exit"
        exit 1
    fi

    result=`ps -A -o pid,ppid,cmd | grep -E "^[ ]*$pid" | sed 's/[ ]\+/ /g' | sed 's/^[ ]\+//g'`

    if [ "X$result" = "X" ]; then
        echo "hasn't found process: $pid"
        exit 1
    fi

    docker_hash=`echo $result | grep -ioE "moby/[a-zA-Z0-9]+"`
    if [ "$docker_hash" != "" ]; then
        container=`echo "$docker_hash" | cut -d'/' -f2 | head -c 10`
  echo "container id: $container"
        docker ps -a | grep -i $container
        break
    fi

    pid=`echo "$result" | cut -d' ' -f2`
    if [ "X$pid" == "X" ]; then
        echo "has no parent process, exit"
        exit 1
    fi
done
