#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)
source $SCRIPT_PATH/env.sh
FZF_PATH=$ENV_ROOT/tool/fzf

remove_tmp()
{
  find $FZF_PATH -iname ".git*" -exec rm -rf {} \;
  find $FZF_PATH -iname "*.md" -exec rm -rf {} \;
  find $FZF_PATH -iname "LICENSE*" -exec rm -rf {} \;
}

update_fzf()
{

   rm -rf $FZF_PATH > /dev/null 2>&1

   git clone --depth 1 https://github.com/junegunn/fzf.git $FZF_PATH
   remove_tmp > /dev/null 2>&1
   $FZF_PATH/install
}

update_fzf
