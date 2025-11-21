vim_dependency()
{
  brew install --HEAD universal-ctags/universal-ctags/universal-ctags
}

vim_os_specific()
{
  export_env VIM_PATH $VIM_PATH
  vim_dependency
}

echo "do vim os specific setting up"
vim_os_specific
