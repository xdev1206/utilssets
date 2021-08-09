#!/system/bin/sh

pid_name=$1

if [ $# -eq 0 ]; then
  cat << EOF
Usage:
  pid.sh processName
EOF
  exit 1
fi

PS_PID_CMD="ps -A"
PS_TID_CMD="ps -AT"

TOP_PID_CMD="top -n 1 -p"

tmp_dir="/data/local/tmp"

pid=`${PS_PID_CMD} | grep -i ${pid_name} | sed -E "s/[ ]+/ /g" | cut -d' ' -f2`

if [ "X${pid}" == "X" ]; then
    echo "no ${pid_name} process, exit!"
    exit 1
fi

echo "${pid_name} pid: ${pid}"
pid_dir="${tmp_dir}/${pid}"

if [ ! -d "${pid_dir}" ]; then
    echo "mkdir -p ${pid_dir}"
    mkdir -p ${pid_dir}
    mkdir -p ${pid_dir}/top
fi

for i in `seq 1 1000`
do
    echo "${i}th memory info:"
    #echo "cat /proc/${pid}/maps > ${pid_dir}/maps_${pid}_$i"
    #cat /proc/${pid}/maps > ${pid_dir}/maps_${pid}_$i

    ${TOP_PID_CMD} ${pid} >> ${pid_dir}/top/top_${pid}_$i

    vmRSS=`cat /proc/${pid}/status | grep -i VmRSS | sed 's/[ ]\{1,10\}/ /g' | cut -d' ' -f 2`
    vmData=`cat /proc/${pid}/status | grep -i VmData | sed 's/[ ]\{1,10\}/ /g' | cut -d' ' -f 2`
    vmStk=`cat /proc/${pid}/status | grep -i VmStk | sed 's/[ ]\{1,10\}/ /g' | cut -d' ' -f 2`
    vmExe=`cat /proc/${pid}/status | grep -i VmExe | sed 's/[ ]\{1,10\}/ /g' | cut -d' ' -f 2`

    echo "rss:${vmRSS}, data:${vmData}, stack:${vmStk}, vmExe:${vmExe} KB"
    sleep 1;
done
