#!/bin/bash

DEV=offline
EXIT=0
try=0
adb_port=5555
#ip address ip1.ip2.ip3.ip4
ip1=172
ip2=16
ip3=120
ip4=0
isroot=0

ip=$*

if [ -z "$ip" ]
then
    echo " no ip address paramters, exit!"
    exit 1
fi

ip_array=(${ip//./ })
ip_array_len=${#ip_array[@]}

# ip address can omit some number from head of ip address
# like 172.16.120.255,  172 can be omitted. The following for cyclic will
# read ip address in reverse way.
for i in `seq ${ip_array_len} -1 1`
do
    index=$((4 - ip_array_len + i))
    data=${ip_array[$((i - 1))]}
    eval ip$index=$data
done

adb kill-server

while [ $EXIT -ne 1 ]
do
    adb disconnect $ip1.$ip2.$ip3.$ip4 > /dev/null 2>&1
    adb connect $ip1.$ip2.$ip3.$ip4
    sleep 1
    DEV=`adb devices | sed -e "/devices/d" | grep "$ip1.$ip2.$ip3.$ip4" | grep -o "device"`
    if [ "$DEV" != "device" ]; then
        DEV=offline
        echo "device is offline, connect again"

        try=$(($try+1))
        if [ $try -ge 10 ]; then
            echo "adb connect try many times, give up!"
            EXIT=1
            break
        fi
        continue
    fi

    # adb root will restart adbd,
    # so after adb root, needs connect again
    if [ $isroot -eq 0 ]; then
        rootinfo=`adb -s $ip1.$ip2.$ip3.$ip4:$adb_port root 2>&1`

        if [[ "$rootinfo" =~ [a-z]+as\ root ]]; then
            isroot=1
            continue
        fi
    fi

    flag=`adb -s $ip1.$ip2.$ip3.$ip4:$adb_port remount`
    if [ "$flag" != "remount succeeded" ]; then
        flag=""
        echo "adb remount failed, try again"

        try=$(($try+1))
        if [ $try -ge 10 ]; then
            echo "adb remount try many times, give up!"
            EXIT=1
            break
        fi
        continue
    fi
    echo "remount succeeded"
    break
done
