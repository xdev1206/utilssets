#!/system/bin/sh

pid_name="$1"

if [ $# -eq 0 ]; then
cat <<EOF
Usage:
    $0 processName
EOF
    exit 1
fi

TMP_DIR="/data/local/tmp"

echo "Start monitoring process: ${pid_name}"

i=1

while [ $i -le 10000 ]
do
    pid=$(pidof -s "${pid_name}")

    if [ -z "${pid}" ]; then
        echo "$(date): Process ${pid_name} not found, wait 500ms and retry..."
        sleep 0.5
        continue
    fi

    if [ ! -d "/proc/${pid}" ]; then
        echo "$(date): Process ${pid_name} pid ${pid} disappeared, wait 500ms and retry..."
        sleep 0.5
        continue
    fi

    out_dir="${TMP_DIR}/${pid_name}_${pid}"

    if [ ! -d "${out_dir}" ]; then
        mkdir -p "${out_dir}"
        echo "Output directory: ${out_dir}"
    fi

    cpu_file="${out_dir}/cpu_usage_${pid_name}_${pid}_summary"
    mem_file="${out_dir}/meminfo_${pid_name}_${pid}_summary"

    ts=$(date)

    {
        echo
        echo "${i}th cpu usage info:"
        echo "${ts}"

        # 优先使用 ps -p，提高效率
        if ps -p "${pid}" -o PID,%CPU,NAME >/dev/null 2>&1; then
            ps -p "${pid}" -o PID,%CPU,NAME
        elif ps -o PID,%CPU,NAME -p "${pid}" >/dev/null 2>&1; then
            ps -o PID,%CPU,NAME -p "${pid}"
        else
            ps -o PID,%CPU,NAME -A | awk -v pid="${pid}" '$1 == pid'
        fi
    } >> "${cpu_file}"

    {
        echo
        echo "${i}th memory info:"
        echo "${ts}"
        dumpsys meminfo "${pid}"
    } >> "${mem_file}"

    echo "${ts}: Collected cpu and memory info for ${pid_name}, pid=${pid}"

    i=$((i + 1))
    sleep 0.5
done

echo "Monitoring finished."
