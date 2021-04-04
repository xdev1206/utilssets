#!/bin/bash

usage()
{
cat << EOF
Usage: $0 -i input.tex
  -i  input latex format file, like: input.tex

Analyse input.tex file and generate corresponding PDF file
EOF
}

input_f=
ENV_PATH=$(cd `dirname $BASH_SOURCE` && /bin/pwd)/..

OPTIND=1
while getopts ":i:" var;
do
  case ${var} in
  i)
    input_f=${OPTARG};;
  \?)
    echo -e "$0 got illegal option -${OPTARG}\n"
    usage
    exit 1;;
  :)
    echo -e "$0 -${OPTARG} missing argument\n"
    usage
    exit 1;;
  esac
done

if [ $# -lt 1 -o "$input_f" = "" ]; then
  usage
  exit 1
fi

set -x
xelatex $input_f
if [ $? -eq 0 ]; then
  xelatex $input_f
fi
set +x

rm *.aux  *.log  *.out *.toc > /dev/null 2>&1
