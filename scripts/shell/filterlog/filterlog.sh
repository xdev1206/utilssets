#!/bin/bash

file=$1
keyword=`cat $2`

for str in $keyword;
do
    echo "delete line contains $str";
    sed -i -e "/$str/d" $file;
done
