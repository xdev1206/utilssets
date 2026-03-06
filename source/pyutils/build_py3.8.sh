#!/bin/bash

uid=$(id -u)
if [ "x${uid}" == "x0" ]; then
    SUDO=''
else
    SUDO='sudo'
fi

${SUDO} apt update
${SUDO} apt install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev \
    libssl-dev libreadline-dev libffi-dev libsqlite3-dev wget libbz2-dev

wget -v https://www.python.org/ftp/python/3.8.18/Python-3.8.18.tar.xz -O Python-3.8.18.tar.xz
tar -xJvf Python-3.8.18.tar.xz

cd Python-3.8.18

./configure --enable-optimizations --prefix=/usr/local --enable-shared

make -j 8
${SUDO} make altinstall

#update-alternatives --install
${SUDO} update-alternatives --install /usr/bin/python python /usr/local/bin/python3.8 70 \
    --slave /usr/bin/python3 python3 /usr/local/bin/python3.8 \
    --slave /usr/bin/python3-config python3-config /usr/local/bin/python3.8-config \
    --slave /usr/bin/python3.8 python3.8 /usr/local/bin/python3.8 \
    --slave /usr/bin/pip pip /usr/local/bin/pip3.8 \
    --slave /usr/bin/pip3 pip3 /usr/local/bin/pip3.8 \
    --slave /usr/bin/pydoc pydoc /usr/local/bin/pydoc3.8
