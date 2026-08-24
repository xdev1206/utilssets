install_universalctags()
{
    git clone https://github.com/universal-ctags/ctags.git

    if [ -d ctags ]; then
        pushd ctags
        latest_tag=$(git tag -l --sort=-version:refname "v*" | head -n1)
        version=${latest_tag:1}
        echo "universal-ctags latest version: ${version}"

        ctags_tar="uctags.tar.gz"
        tar_url="https://github.com/universal-ctags/ctags/releases/download/v${version}/universal-ctags-${version}.tar.gz"
        echo "downloading ${tar_url}"
        wget -O ${ctags_tar} ${tar_url}

        if [ -f ${ctags_tar} ]; then
            tar xzvf uctags.tar.gz
            cd universal-ctags-*
            ./autogen.sh
            ./configure --prefix=${UTILSSETS_ROOT}/tools
            make
            make install # may require extra privileges depending on where to install
        fi
        popd

        rm -rf ctags
    fi
}

vim_dependency()
{
    # need network
    if [ "x${reach_network}" == "x1" ]; then
        if [ "x$OS_NAME" == "xdebian" -o "x$OS_NAME" == "xubuntu" ]; then
            # install universal-ctags manually
            install_universalctags
            ${SUDO} ${INSTALL_CMD} libxml2 libjansson-dev libyaml-dev
        fi
    else
        echo "can't connect to network, ignore this action."
    fi
}

vim_os_specific()
{
    export_env VIM_PATH $VIM_PATH
    vim_dependency
}

echo "do vim os specific setting up"
vim_os_specific
