#!/bin/bash

ADB=adb

usage()
{
cat << EOF
$0 usage:
  -d dir        push all files in the directory dir to Android device
  -f fn  a_dir  push file fn to direcotry a_dir in Android device
EOF
}

err_arg()
{
  local arg=$1
  case $arg in
  \?)
    echo -e "-$OPTARG illegal option\n"
    ;;
  :)
    echo -e "-$OPTARG missing option argument\n"
    ;;
  *)
    echo -e "-$OPTARG unknown option\n"
    ;;
  esac

  usage
  exit 1
}

push_file()
{
  local src_file=$1
  local dst_file=$2

  if [ -z "$dst_file" -o -z "$src_file" ]; then
    echo -e "src or dst file is null, src:$src_file, dst:$dst_file, exit...\n"
    exit 1
  fi

  $ADB push $1 $2
}

parse_d()
{
  local tb_push_dir=$OPTARG

  if [ ! -d "$tb_push_dir" ]; then
    echo -e "$tb_push_dir is not directory...\n"
    usage
    exit 1
  fi

  dev_st=`$ADB get-state`
  if [ "$dev_st" != "device" ]; then
    echo "can't get device state, exit..."
    exit 1
  fi

  local tb_push_list=`find $tb_push_dir -type f ! -name ".*"`

  for var in $tb_push_list; do
    #echo \/${var/\.\//}
    push_file $var \/${var/\.\//}
  done
}

parse_f()
{
    local tb_push_file=$OPTARG
    local tb_push_dst=$1
    OPTIND=$((OPTIND + 1))

    if [ -z "$tb_push_file" -o -z "$tb_push_dst" ]; then
      echo -e "src or dst is null, src:$tb_push_file, dst:$tb_push_dst, exit...\n"
      exit 1
    fi

    #echo $tb_push_file $tb_push_dst
    push_file $tb_push_file $tb_push_dst
}

OPTIND=1
while getopts ":d:f:" var
do
  case $var in
  d)
    parse_d
    ;;
  f)
    # compromise, it should not parse argument
    dst=`eval echo "\$"$OPTIND`
    parse_f $dst
    unset dst
    ;;
  \?)
    err_arg $var
    ;;
  :)
    err_arg $var
    ;;
  *)
    err_arg $var
    ;;
  esac
done

if [ $OPTIND -eq 1 ]; then
  echo "no parameters..."
  usage
  exit 1
fi
