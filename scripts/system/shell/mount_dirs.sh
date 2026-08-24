#!/bin/bash

uid=`id -u`
if [ $uid -ne 0 ]; then
  SUDO=sudo
fi

function check_and_mkdir()
{
  dir=$1
  if [ ! -d $dir ]; then
    $SUDO mkdir $dir
  fi
}

function mount_dir()
{
  dir=$1
  mp=`mountpoint $dir | grep -c not`
  if [ $mp -eq 1 ]; then
    $SUDO mount -t nfs -o soft -o vers=3 172.19.120.60:$dir $dir
  fi
}

function do_mount()
{
  dir=$1
  check_and_mkdir $dir
  mount_dir $dir
}

do_mount /data120
