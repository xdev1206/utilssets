# write vim env config to config.env
compile_vim()
{
    if [ "x$OS_NAME" == "xdebian" -o "x$OS_NAME" == "xubuntu" ]; then
        ${SUDO} apt install libncurses5-dev libgtk2.0-dev libatk1.0-dev \
            libcairo2-dev libx11-dev libxpm-dev libxt-dev python2-dev \
            python3-dev ruby-dev lua5.2 liblua5.2-dev libperl-dev git

        git clone https://github.com/vim/vim.git
        cd vim

        ./configure --with-features=huge \
            --enable-multibyte \
            --enable-rubyinterp=yes \
            --enable-python3interp=yes \
            --with-python3-config-dir=$(python3-config --configdir) \
            --enable-perlinterp=yes \
            --enable-luainterp=yes \
            --enable-gui=gtk2 \
            --enable-cscope \
            --prefix=/usr/local

        ver_major=$(cat src/version.h | grep -i VIM_VERSION_MAJOR -m1 | sed "s/[^0-9]\+//")
        ver_minor=$(cat src/version.h | grep -i VIM_VERSION_MINOR -m1 | sed "s/[^0-9]\+//")
        ver_build=$(cat src/version.h | grep -i VIM_VERSION_BUILD -m1 | sed "s/[^0-9]\+//")
        echo "vim version: ${ver_major}.${ver_minor}.${ver_build}"

        make VIMRUNTIMEDIR=/usr/local/share/vim/vim${ver_major}${ver_minor}
        make install

        ${SUDO} apt remove vim-tiny vim-common vim-gui-common vim-nox
        ${SUDO} update-alternatives --install /usr/bin/editor editor /usr/local/bin/vim 1
        ${SUDO} update-alternatives --set editor /usr/local/bin/vim
        ${SUDO} update-alternatives --install /usr/bin/vi vi /usr/local/bin/vim 1
        ${SUDO} update-alternatives --set vi /usr/local/bin/vim

        cd .. ; rm -r vim
    fi
}

compile_vim
