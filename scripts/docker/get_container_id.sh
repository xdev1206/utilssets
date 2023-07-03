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
    result=`ps -A -o pid,ppid,cmd | grep -i "^$pid" | grep -vE "$script|grep" | sed 's/[ ]\+/ /g'`

    docker_hash=`echo $result | grep -ioE "moby/[a-zA-Z0-9]+"`
    if [ "$docker_hash" != "" ]; then
        container=`echo "$docker_hash" | cut -d'/' -f2 | head -c 10`
        docker ps -a | grep -i $container
        break
    fi

    pid=`echo $result | cut -d' ' -f2`
    echo "$result"
done
