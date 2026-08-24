#!/system/bin/sh

p=0

if [ $@ -gt 0 ]; then
    p=$1
fi

setprop framebuffer.pattern $p
