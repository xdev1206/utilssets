#!/system/bin/sh

if [ $# -ne 1 ]; then
    echo "ERROR!  $0: need process cmdline."
    exit 0
fi

top -o PID,RES,%MEM,%CPU,CMDLINE -s 3 -n 1 | grep -iE "%MEM|$1"

echo -e "\nGPU idle:"
cat /sys/module/ged/parameters/gpu_idle
echo -e "\nGPU loading:"
cat /sys/module/ged/parameters/gpu_loading
