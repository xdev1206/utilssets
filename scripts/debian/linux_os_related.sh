# debian
uid=$(id -u)
if [ "x${uid}" == "x0" ]; then
    SUDO=''
else
    SUDO='sudo'
fi

lsb_release -a
cat /etc/issue
cat /etc/os-release
cat /etc/debian_version
hostnamectl

# kde desktop
#${SUDO} apt remove kwalletmanager konqueror kdeconnect firefox-esr kwin-x11

# locale
#LC_CTYPE="en_US.UTF-8"
#LC_NUMERIC="en_US.UTF-8"
#LC_TIME="en_US.UTF-8"
#LC_COLLATE="en_US.UTF-8"
#LC_MONETARY="en_US.UTF-8"
#LC_MESSAGES="en_US.UTF-8"
#LC_PAPER="en_US.UTF-8"
#LC_NAME="en_US.UTF-8"
#LC_ADDRESS="en_US.UTF-8"
#LC_TELEPHONE="en_US.UTF-8"
#LC_MEASUREMENT="en_US.UTF-8"
#LC_IDENTIFICATION="en_US.UTF-8"
#LC_ALL=
localectl set-locale LANG=en_US.UTF-8
localectl set-locale LANGUAGE=en_US

#update-alternatives --install
#  --install <link> <name> <path> <priority>
#   [--slave <link> <name> <path>] ...
#                           add a group of alternatives to the system.
${SUDO} update-alternatives --install /usr/bin/python python /usr/local/bin/python3.8 70 \
    --slave /usr/bin/python3 python3 /usr/local/bin/python3.8 \
    --slave /usr/bin/python3-config python3-config /usr/local/bin/python3.8-config \
    --slave /usr/bin/pip pip /usr/local/bin/pip3.8 \
    --slave /usr/bin/pydoc pydoc /usr/local/bin/pydoc3.8

#Your C++ compiler does NOT fully support C++17
${SUDO} apt-get install g++-8
${SUDO} update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 700 --slave /usr/bin/g++ g++ /usr/bin/g++-7
${SUDO} update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-8 800 --slave /usr/bin/g++ g++ /usr/bin/g++-8
