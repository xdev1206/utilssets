#!/bin/bash

WEBSITE=http://www.ishadowsocks.net/
WEBFILE=index.html
ss_config_a=.shadowsocks.json_a
ss_config_b=.shadowsocks.json_b
ss_config_c=.shadowsocks.json_c
option=null
#wget $WEBSITE

function check()
{
    if [ "$option" = "null" ]; then
        echo "no shadowsocks account info, exit!!"
        exit 0
    fi
}

function analyze()
{
    for str in $option; do
        echo $str | cut -d ':' -f 2
    done
}

function getinfo()
{
    if [ $? -eq 0 ]; then
        option=`awk '/服务器地址:|端口:|密码:|加密方式:/' $WEBFILE  | sed -e "s/<[^<]*>//g;s/[ ]*//g"`
#    rm $WEBFILE
    else
        printf "Can't access $WEBSITE !!\n"
    fi
    echo $option
}
#while getopts
echo "{"
echo -n "    \"server\":"
echo -n "    \"local_port\":"
echo -n "    \"password\":"
echo -n "    \"time\":"
echo -n "    \"method\":"
echo "}"

getinfo
check
analyze
