# write vim env config to config.env
vim_env_to_config()
{
  sed '/^export.*VIM_PATH.*/d' -i $ENV_CONF
  echo "export VIM_PATH=$VIM_PATH" >> $ENV_CONF
}

vim_dependency()
{
  brew install --HEAD universal-ctags/universal-ctags/universal-ctags
}

vim_os_specific()
{
  vim_env_to_config
  vim_dependency
}

echo "do vim os specific setting up"
vim_os_specific
