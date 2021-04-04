#!/bin/bash

# $1 filename
# $2 version
function check_java_copyright() {
  file=$1
  version=$2
  filename=`basename $file`

  copyright="/\*\n \* Copyright (C), 2018, xxx Corp., Ltd\n \* All rights reserved.\n \* File: $filename\n \* Description:\n \*\n \* Date: `date +'%F'`\n */\n"

  echo "$file, add copyright information..."
  sed '1i\'"$copyright" -i $file
}

# file extension suffix list
suffix_list="py java xml c cc cpp h hpp"

for suffix in $suffix_list
do
  file_list=`find . -type f -name "*.$suffix"`

  for file in $file_list
  do
    # if [ "$suffix" = "java" ]; then
    #   check_java_copyright $file 1.0
    # fi

    echo "auto formatting: $file"
     # change permission to 644
    chmod 644 $file
    # to unix file format
    dos2unix $file
    # remove trailing spaces at the end of lines
    sed -i 's/[ ]\+$//' $file
    # replace tab to 4 whitespace
    sed -i 's/\t/    /g' $file
    # merge multi-blank lines to one blank line
    sed -i '/^$/{N;/^\n*$/D}' $file
    # add \n if there is no \n at the last line of file
    sed -i '$a\' $file
  done
done
