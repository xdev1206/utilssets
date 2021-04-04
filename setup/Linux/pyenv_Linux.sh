linux_version()
{
  LINUX_VERSION='debian'
  if [ -f '/etc/centos-release' ]; then
    LINUX_VERSION='centos'
  elif [ -f '/etc/redhat-release' ]; then
    LINUX_VERSION='redhat'
  elif [ -f '/etc/oracle-release' ]; then
    LINUX_VERSION='oracle'
  elif [ -f '/etc/debian_version' ]; then
    LINUX_VERSION='debian'
  elif [ -f '/etc/lsb-release' ]; then
    LINUX_VERSION='ubuntu'
  fi
}

pyenv_os_specific()
{
  linux_version # get current linux version
  if [ "x$LINUX_VERSION" == "xdebian" -o "x$LINUX_VERSION" == "xubuntu" ]; then
    apt-get install -y libsqlite3-dev libssl-dev libreadline-dev libbz2-dev curl zlib1g-dev
  fi
}

echo "do pyenv os specific setting up"
pyenv_os_specific
