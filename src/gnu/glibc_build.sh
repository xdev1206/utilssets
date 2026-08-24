#!/bin/bash

uid=$(id -u)
if [ "x${uid}" == "x0" ]; then
    SUDO=''
else
    SUDO='sudo'
fi

ver=2.33
wget -4c https://ftp.gnu.org/gnu/glibc/glibc-${ver}.tar.gz
tar -zxvf glibc-${ver}.tar.gz

pushd glibc-${ver}

mkdir build_dir
cd build_dir

${SUDO} ../configure --prefix=/opt/glibc
${SUDO} make
${SUDO} make install

popd
