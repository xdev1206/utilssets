# write vim env config to config.env
vim_env_to_config()
{
  sed -i "" '/^export.*VIM_PATH.*/d' $ENV_CONF
  echo "export VIM_PATH=$VIM_PATH" >> $ENV_CONF

  found=$(cat "$shell_rc" | grep -c "$ENV_CONF")
  if [ $found -eq 0 ]; then
    echo 'source $ENV_PATH/config.env' >> $BASH_RC
  fi
}

vim_dependency()
{
  brew install --HEAD universal-ctags/universal-ctags/universal-ctags
}

function vim_os_specific()
{
  vim_env_to_config
  vim_dependency
}

echo "do vim os specific setting up"
vim_os_specific
