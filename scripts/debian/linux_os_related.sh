# debian
lsb_release -a
cat /etc/issue
cat /etc/os-release
cat /etc/debian_version
hostnamectl

# kde desktop
sudo apt remove kwalletmanager konqueror kdeconnect firefox-esr kwin-x11

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

