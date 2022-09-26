source env.sh

if [ "x${reach_network}" == "x1" ]; then
    git clone https://github.com/universal-ctags/ctags.git
    cd ctags
    ./autogen.sh
    ./configure --prefix=${ENV_ROOT} #default
    make
    make install # may require extra privileges depending on where to install
    cd .. && rm -r ctags
else
    echo "${BASH_SOURCE[0]}: can't connect to network, skip this step."
fi
