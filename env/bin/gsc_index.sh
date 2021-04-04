#!/bin/bash
# generate source code index

file_list=sc_files.list
workdir="$(/bin/pwd)/"
droid_dir=(bionic device external frameworks hardware libcore system)
clang_complete='.clang_complete'
file_suffix=(.h .hh .hp .c .cxx .cpp .java)

function usage()
{
cat << EOF
usage: gsc_index.sh [-a dir] or [-c dir]
  -a        generate source code index for android specific source code dir
  -c dir    generate source code index for current source code dir
  -d dir    generate source code index for specify source code dir
  -r        remove all generated index files
EOF
}

function cleanup
{
    echo "remove cscope index and ctags files..."
    rm cscope.* > /dev/null 2>&1
    rm tags > /dev/null 2>&1
    rm ${clang_complete} > /dev/null 2>&1
}

function cscope_os_things()
{
  if [ -f /etc/redhat-release ]; then
    centos=`cat /etc/redhat-release | grep -ic centos`
    if [ ${centos} -gt 0 ]; then
      echo "centos"
    fi
  fi
}

function generate_index
{
    echo "generate source code index..."

    find ${searchdir[@]} -type f -iname "*.java" -o -iname "*.h" -o -iname "*.h[h|p]" -o -iname "*.c" -o -iname "*.c[x|p]?" > ${file_list}
    find ${searchdir[@]} -type f -iname "*.h" -o -iname "*.h[h|p]" > ${clang_complete}

    sed -i 's/^/-I"/;s/$/"/' ${clang_complete}

    ctags -aR -h ".h.H.hh.hpp.hxx.h++.inc.def" --output-format=e-ctags -L ${file_list} -f tags
    # file path starts with double quote(")
    sed -i 's/^/"/;s/$/"/' ${file_list}
    cscope -bkqUv -i ${file_list}

    # delete file list
    rm ${file_list}

    # generate .clang_complete file
    echo "-DDEBUG" >> ${clang_complete}
}

OPTIND=1

while getopts ":acd:r" args;
do
    case $args in
    a)
        searchdir=(${droid_dir[@]});;
    c)
        searchdir=('.');;
    d)
        searchdir=(${searchdir[@]} $OPTARG);;
    r)
        cleanup
        exit 1;;
    *)
        echo "unknown parameter!"
        exit 1;;
    esac
done

if [ $# -eq 0 -o $OPTIND -eq 1 ]; then
    usage
    exit 1
fi

searchdir=(${searchdir[@]/#/"$workdir"})
cleanup
generate_index
