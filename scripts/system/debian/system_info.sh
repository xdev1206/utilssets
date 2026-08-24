#!/bin/bash

echo ">>> Hostname"
hostname
echo

echo ">>> Operating System Information"
if [ -f /etc/os-release ]; then
    cat /etc/os-release
else
    echo "/etc/os-release not found"
fi
echo

echo ">>> Kernel Information"
uname -a
echo

echo ">>> Host Information"
if command -v hostnamectl >/dev/null 2>&1; then
    hostnamectl
else
    echo "hostnamectl command not found"
fi
echo

echo ">>> Uptime and Load"
uptime
echo

echo ">>> CPU Information"
if command -v lscpu >/dev/null 2>&1; then
    lscpu
else
    cat /proc/cpuinfo
fi
echo

echo ">>> Memory Information"
if command -v free >/dev/null 2>&1; then
    free -h
else
    cat /proc/meminfo
fi
echo

echo ">>> Block Device Information"
if command -v lsblk >/dev/null 2>&1; then
    lsblk
else
    echo "lsblk command not found"
fi
echo

echo ">>> Disk Usage"
df -h
echo

echo ">>> PCI Device Information"
if command -v lspci >/dev/null 2>&1; then
    lspci
else
    echo "lspci command not found, please install pciutils"
fi
echo

echo ">>> USB Device Information"
if command -v lsusb >/dev/null 2>&1; then
    lsusb
else
    echo "lsusb command not found, please install usbutils"
fi
echo

echo ">>> Network Interface Information"
if command -v ip >/dev/null 2>&1; then
    ip addr
else
    ifconfig
fi
echo

echo ">>> Mounted File Systems"
mount | column -t
echo

echo ">>> Recent Kernel Messages"
dmesg | tail -n 50
echo
