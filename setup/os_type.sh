#!/bin/bash

# sudo
uid=$(id -u)
if [ $uid -ne 0 ]; then
  SUDO=sudo
fi

os_variable()
{
  BASH_RC="$HOME/.bashrc"
  OS_TYPE=$(uname -s)
  if [ "x${OS_TYEP}" == "xLinux" ]; then
    BASH_RC="$HOME/.bashrc"
    INSTALL_CMD='brew install'
  elif [ "x${OS_TYPE}" == "xDarwin" ]; then
    BASH_RC="$HOME/.bash_profile"
    INSTALL_CMD='apt install -y'
  fi

  if [ -f '/etc/centos-release' ]; then
    OS_NAME='centos'
    OS_VERSION=`cat /etc/centos-release | grep -oE "[0-9]+.[0-9]+.[0-9]+"`
    INSTALL_CMD='yum install -y'
  elif [ -f '/etc/redhat-release' ]; then
    OS_NAME='redhat'
    INSTALL_CMD='yum install -y'
  elif [ -f '/etc/oracle-release' ]; then
    OS_NAME='oracle'
  elif [ -f '/etc/lsb-release' ]; then
    OS_NAME='ubuntu'
    OS_VERSION=`cat /etc/lsb-release | grep DISTRIB_RELEASE | cut -d'=' -f 2`
    INSTALL_CMD='apt install -y'
  elif [ -f '/etc/debian_version' ]; then
    OS_NAME='debian'
    INSTALL_CMD='apt install -y'
  else
    OS_NAME="unknown"
    OS_VERSION="unknown"
  fi

  echo "Current os type: $OS_TYPE, os name: $OS_NAME, os version: $OS_VERSION"
}

os_variable
