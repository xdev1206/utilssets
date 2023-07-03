#!/bin/bash

usage()
{
cat << EOF
    $BASH_SOURCE pid -- like $BASH_SOURCE $$
EOF
}

para_num=$#
if [ ${para_num} -eq 0 ]; then
    echo "parameter nubmer is zero!"
    usage
    exit 1
fi

script=$0
pid=$1

while :
do
    result=`ps -A -o pid,ppid,cmd | sed 's/[ ]\+/ /g' | grep -iE "^[ ]*$pid " | grep -vE "$script|grep"`

    docker_hash=`echo $result | grep -ioE "moby/[a-zA-Z0-9]+"`
    if [ "$docker_hash" != "" ]; then
        echo "found_container: ${docker_hash}"
        container=`echo "$docker_hash" | cut -d'/' -f2 | head -c 10`
        docker ps -a | grep -i $container
        break
    fi

    pid=`echo $result | cut -d' ' -f2`
    echo -e "reulst:\n${result}"
    echo "new pid: ${pid}"

    if [ "x${pid}x" == "x0x" ]; then
        echo "can't find docker container, exit!"
        exit 0
    fi
done
