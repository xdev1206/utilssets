#!/system/bin/sh

top -s rss >> /data/mem.info
sleep 1

cat /proc/meminfo >> /data/mem.info
sleep 3
