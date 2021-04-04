#!/system/bin/sh
loop=0
mkdir -p /data/ps
cd /data/ps

while :
do
ps -t > ps.$loop
loop=$((loop+1))
sleep 10
done
