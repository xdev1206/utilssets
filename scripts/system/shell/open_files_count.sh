#!/system/bin/sh
if [ 0 -eq $# ]; then
    echo "no parameter, exit!"
    exit 1
fi

while :
do
    lsof | grep $1 -c
    sleep 5
done
