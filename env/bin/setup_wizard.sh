#!/bin/bash

count=`ps aux | grep -i $$ | grep -ciE "(/| |da)sh[ ]+$0"`
if [ $count -gt 0 ]; then
  echo "usage:"
  echo "  bash $0"
  exit 0
fi

ENV_BIN=$(cd `dirname $BASH_SOURCE` && /bin/pwd)
ENV_PATH=$(cd $ENV_BIN/.. && /bin/pwd)

uid=$(id -u)

func_sudo_env()
{
  if [ $uid -ne 0 ]; then
    SUDO=sudo
  fi

  # keep user env and add customized env path to sudo secure_path variable
  env_reset_found=`sudo cat /etc/sudoers | grep -c "env_reset"`
  if [ $env_reset_found -gt 0 ]; then
    $SUDO sed -E -i 's/\!*env_reset/!env_reset/g' /etc/sudoers
  else
    set +H
    $SUDO bash -c 'echo -e "Defaults\t!env_reset" >> /etc/sudoers'
    set -H
  fi

  secure_path_found=`$SUDO cat /etc/sudoers | grep -c secure_path`
  if [ $secure_path_found -gt 0 ]; then
    path_found=`$SUDO cat /etc/sudoers | grep -c $ENV_BIN`
    if [ $path_found -eq 0 ]; then
      ENV_BIN_ESCAPE=${ENV_BIN//\//\\\/}
      $SUDO sed -i "s/secure_path=\"/secure_path=\"$ENV_BIN_ESCAPE:/g" /etc/sudoers
    fi
  fi
}

if [ `uname -m` == 'x86_64' ]; then
  ARCH=x86_64
else
  ARCH=i386
fi

func_install_package()
{
  DEB_PATH=$ENV_PATH/tool/deb

  # need root premission to install following packages
  if [ "${SUDO}x" = "x" ]; then
    apt install -y sudo accountsservice
  fi

  # necessary package
  # fonts-arphic-gkai00mp:文鼎PL简中楷（GB 码）
  $SUDO apt-get install -y make ctags git cscope vim curl bash-completion \
      openssh-server cifs-utils tree expect fonts-freefont-ttf pandoc \
      fonts-arphic-gkai00mp dos2unix libcanberra-gtk-module libssl-dev \
      libreadline-dev libsqlite3-dev gdb unzip libclang-7-dev

  # gdb build error: makeinfo is missing on your system
  $SUDO apt-get -y install texinfo
  # gdb build error: ada-lex.c missing and flex not available.
  $SUDO apt-get -y install flex
  # gdb build error: gdb-8.0.1/missing: bison: not found
  $SUDO apt-get -y install bison

  # for universal-ctags compiling
  $SUDO apt-get install -y libyaml-dev libxml2-dev libseccomp-dev libjansson-dev \
      pkg-config autoconf automake python3-docutils
}

# setup vim plugin environment
func_vim_env() {
  VIM_PATH=$ENV_PATH/vim
  vimrc=`readlink $HOME/.vimrc`

  if [ "$vimrc" = "$VIM_PATH/.vimrc" ]; then
    echo "has already setup vim env, jump to next step..."
    return
  fi

  pushd $ENV_PATH
  git clone https://github.com/aklt/plantuml-syntax.git plantuml-syntax
  git clone https://github.com/majutsushi/tagbar.git
  git clone https://github.com/xavierd/clang_complete.git
  popd

  # plantuml vim plugin
  rm -rf $ENV_PATH/plantuml-syntax/.git*
  rm -rf $ENV_PATH/plantuml-syntax/README.md
  cp -r $ENV_PATH/plantuml-syntax/* $VIM_PATH

  rm -rf $ENV_PATH/plantuml-syntax
  ### plantuml end

  ### tagbar
  rm -rf $ENV_PATH/tagbar/.git*
  rm -rf $ENV_PATH/tagbar/LICENSE
  rm -rf $ENV_PATH/tagbar/README.md
  cp -r $ENV_PATH/tagbar/* $VIM_PATH
  rm -rf $ENV_PATH/tagbar
  ### tagbar end

  ### clang_complete
  pushd $ENV_PATH/clang_complete
  make
  vim -c "set runtimepath^=$ENV_PATH/vim" clang_complete.vmb -c 'so %' -c 'q'
  popd

  rm -rf $ENV_PATH/clang_complete
  ### clang_complete end

  # install plug to manager plug-ins and this must be the last step in func_vimenv_setup
  curl -fLo $VIM_PATH/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

  # each user should use himself vim config
  ln -sf $VIM_PATH/.vimrc $HOME/.vimrc

  # install vim-gui-common, enable python and other feature support
  # it doesn't mather even if installing is failed
  $SUDO apt-get -y install vim-gui-common
}

# setup tool environment
func_tool_env() {
  TOOL_PATH=$ENV_PATH/tool
  TOOL_JAR_PATH=$ENV_PATH/tool/jar
  if [ ! -d $TOOL_JAR_PATH ]; then
    mkdir -p $TOOL_JAR_PATH
  fi

  if [ ! -d $ENV_PATH/tool ]; then
    mkdir -p $ENV_PATH/tool
  fi

  if [ -f $TOOL_JAR_PATH/plantuml.jar ]; then
    echo "has already setup tool env, jump to next step..."
    return
  fi

  # install graphviz
  $SUDO apt-get install -y graphviz

  if [ ! -d $HOME/.config ]; then
    mkdir -p $HOME/.config
    chmod 700 $HOME/.config
  fi

  # get plantuml.jar must be last step in func_toolenv_setup
  wget https://sourceforge.net/projects/plantuml/files/plantuml.jar/download -O $TOOL_JAR_PATH/plantuml.jar
  # create plantuml shell script
  echo -e '#!/bin/bash\n' > $ENV_BIN/plantuml
  echo "java -jar $TOOL_PATH/jar/plantuml.jar -tpng \$@" >> $ENV_BIN/plantuml
  chmod 755 $ENV_BIN/plantuml
}

func_sys_env() {
  SYS_PATH=$ENV_PATH/sys

  if [ -d $HOME/.fonts/NotoSerifCJKsc-hinted ]; then
    echo "has already setup sys env, jump to next step..."
    return
  fi

  # must be the last step in func_sysenv
  if [ ! -d $HOME_PATH/.fonts ]; then
    mkdir -p $HOME/.fonts
    wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSans-hinted.zip -O $HOME/.fonts/NotoSans-hinted.zip
    wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSerif-hinted.zip -O $HOME/.fonts/NotoSerif-hinted.zip
    wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSansCJKsc-hinted.zip -O $HOME/.fonts/NotoSansCJKsc-hinted.zip
    wget https://noto-website-2.storage.googleapis.com/pkgs/NotoSerifCJKsc-hinted.zip -O $HOME/.fonts/NotoSerifCJKsc-hinted.zip

    pushd $HOME/.fonts
    unzip NotoSans-hinted.zip -d NotoSans-hinted
    unzip NotoSerif-hinted.zip -d NotoSerif-hinted
    unzip NotoSansCJKsc-hinted.zip -d NotoSansCJKsc-hinted
    unzip NotoSerifCJKsc-hinted.zip -d NotoSerifCJKsc-hinted
    popd

    fc-cache
  fi
}

func_git_env() {
  git config --local user.name "Xin Xu"
  git config --local user.email "xuxin0509@gmail.com"
  git config --local core.editor vim
}

func_android_env() {
  # setup udev rules for example
  rules_example='/etc/udev/rules.d/51-android.rules.example'

  if [ -e $rules_example ]; then
    echo "has already created udev rule example, jump to next step..."
    return
  fi

  echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="22d9", ATTR{idProduct}=="276c", MODE="0660", GROUP="plugdev", SYMLINK+="android%n"' | $SUDO tee $rules_example
  # $SUDO service udev restart
}

func_bash_env()
{
  bash_config=`cat ~/.bashrc | grep -c "$ENV_PATH"`
  if [ $bash_config -gt 0 ]; then
    echo "has already setup bash env, jump to next step..."
    return
  fi

  # bash config
  echo -e "\nsource $ENV_PATH/config.env" >> ~/.bashrc
  # alias
  echo -e "\nalias ll='ls -l --color=auto'" >> ~/.bashrc
  echo -e "alias la='ls -la --color=auto'" >> ~/.bashrc
}

func_python_env()
{
  # install pyenv to manager python environment
  PYENV=$TOOL_PATH/pyenv
  PYENV_VIRENV=$PYENV/plugins/pyenv-virtualenv
  PYENV_CONF=$ENV_PATH/config/pyenv.conf

  if [ -d $PYENV ]; then
    echo "has already setup python env, skip this step..."
    return
  fi

  git clone https://github.com/pyenv/pyenv.git $PYENV
  git clone https://github.com/pyenv/pyenv-virtualenv.git $PYENV_VIRENV
  # remove system default virtualenv package
  rm -rf /home/nocent/.local/lib/python2.7/site-packages/virtualenv* 2>&1

  echo "export PYENV_ROOT="$TOOL_PATH/pyenv"" > $PYENV_CONF
  echo -e 'export PATH="$PYENV_ROOT/bin:$PATH"\n' >> $PYENV_CONF
  echo -e 'if command -v pyenv 1>/dev/null 2>&1; then' >> $PYENV_CONF
  echo '    eval "$(pyenv init -)"' >> $PYENV_CONF
  echo '    eval "$(pyenv virtualenv-init -)"' >> $PYENV_CONF
  echo 'fi' >> $PYENV_CONF

  # pip source config
  if [ ! -f $HOME/.pip/pip.conf ]; then
    mkdir -p $HOME/.pip
    echo -e "[global]\nindex-url = https://pypi.tuna.tsinghua.edu.cn/simple" > $HOME/.pip/pip.conf
  fi
}

func_enable_hints()
{
  cat << EOF
***********************************
***********************************
environment has been created.
enabling it by 'source $HOME/.bashrc'
***********************************
***********************************
EOF
}

unset_tool_env() {
  TOOL_PATH=$ENV_PATH/tool

  PYENV=$TOOL_PATH/pyenv
  PYENV_CONF=$ENV_PATH/config/pyenv.conf
  rm -rf $PYENV $PYENV_CONF 2>&1
}

func_sudo_env
func_install_package
func_tool_env
func_sys_env
func_vim_env
func_git_env
func_android_env
func_bash_env
func_python_env

export ENV_PATH=$ENV_PATH
vim -c PlugInstall -c q -c q

func_enable_hints
