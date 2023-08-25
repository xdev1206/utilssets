#!/bin/bash

if [ $# -lt 2 ]; then
  echo "$0 needs 2 arguments, exit..."
  exit 1
fi

arg_arr=($@)
arr_n=${#arg_arr[@]}

for ((i=0; i < $((arr_n-1)); ++i))
do
  be_copied=${arg_arr[i]//*\//}
  copy_to=${arg_arr[$((arr_n-1))]/%\//}

  echo "rm $copy_to/$be_copied"
  rm $copy_to/$be_copied

  echo "cp ${ANDROID_BUILD_TOP}/${arg_arr[i]} ${arg_arr[$((arr_n -1))]}"
  cp ${ANDROID_BUILD_TOP}/${arg_arr[i]} ${arg_arr[$((arr_n -1))]}
done
