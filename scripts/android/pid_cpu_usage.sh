#!/system/bin/sh

pid_name=$1

if [ $# -eq 0 ]; then
  cat << EOF
Usage:
  pid.sh processName
EOF
  exit 1
fi

PS_PID_CMD="ps -o PID,%CPU,NAME -A"
PS_TID_CMD="ps -o PID,%CPU,NAME -AT"

tmp_dir="/data/local/tmp"

pid=`${PS_PID_CMD} | grep -iE "${pid_name}$" | cut -d' ' -f1`

if [ "X${pid}" == "X" ]; then
    echo "no ${pid_name} process, exit!"
    exit 1
fi

echo "${pid_name} pid: ${pid}"
pid_dir="${tmp_dir}/${pid}"

if [ ! -d "${pid_dir}" ]; then
    echo "mkdir -p ${pid_dir}"
    mkdir -p ${pid_dir}
fi

for i in `seq 1 10000`
do
    if [ ! -d /proc/${pid} ]; then
        echo "no ${pid_name} process, exit loop!"
        exit 1
    fi

    echo -e "\n${i}th cpu usage info:\n" >> ${pid_dir}/cpu_usage_${pid}_summary
    date >> ${pid_dir}/cpu_usage_${pid}_summary
    ${PS_PID_CMD} | grep -iE "${pid_name}$" >> ${pid_dir}/cpu_usage_${pid}_summary

    date
    sleep 1;
done
