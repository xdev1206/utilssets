#!/system/bin/sh

pkn=com.android.systemui

pid=`ps | grep -i $pkn | busybox cut -b 11-16`

kill $pid

sleep 2

dumpsys meminfo $pkn
