#!/bin/bash
#if [ $# != 1 ]; then
#    echo "Usage: $0 <your dir>"
#    exit -1
#fi

VAR=$1
sed -i -e"s/mstar scripts/$VAR\/&/g" auto_update.txt

#sed -i -e"s/tftp 0x20200000 /tftp 0x20200000 $1\//g" $1/scripts/*
#sed -i -e"s/mstar scripts/mstar $1\/scripts/g" $1/auto_update.txt
#sed -i -e"s/mstar scripts/mstar $1\/scripts/g" $1/auto_update_factory.txt
#sed -i -e"s/mstar scripts/mstar $1\/scripts/g" $1/auto_update_mboot.txt
#sed -i -e"s/mstar scripts/mstar $1\/scripts/g" $1/auto_update_single.txt
