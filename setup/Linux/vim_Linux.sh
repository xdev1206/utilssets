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

# write vim env config to config.env
vim_env_to_config()
{
  local shell_rc="$HOME/.bashrc"

  sed '/^export.*VIM_PATH.*/d' -i $ENV_CONF
  echo "export VIM_PATH=$VIM_PATH" >> $ENV_CONF

  found=$(cat "$shell_rc" | grep -c "$ENV_CONF")
  if [ $found -eq 0 ]; then
    echo "export ENV_PATH=$ENV_ROOT" >> $shell_rc
    echo "source $ENV_CONF" >> $shell_rc
  fi
}

vim_dependency()
{
  linux_version # get current linux version
  if [ "x$LINUX_VERSION" == "xdebian" -o "x$LINUX_VERSION" == "xubuntu" ]; then
    apt-get install -y libxml2 libjansson-dev libyaml-dev
  fi
}

vim_os_specific()
{
  vim_env_to_config
}

echo "do vim os specific setting up"
vim_os_specific
