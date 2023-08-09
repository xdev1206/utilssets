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

    docker_hash=`echo $result | grep -ioE "moby( -id |/)[a-z0-9]+"`
   if [ "$docker_hash" != "" ]; then
        echo "found_hash: ${docker_hash}"
        container=`echo "$docker_hash" | sed -e "s/moby\( -id \|\/\)//g" | head -c 10`
        echo "found_container: ${container}"

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
