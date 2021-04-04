#!/bin/bash

input_f=
output_f=temp.pdf
title="Unknwon Title"
author="Xin Xu"

usage()
{
cat << EOF
Usage: $0 -i markdown_file -o latex_file
  -a  set document author section, like: "Peter Pan"
  -t  set document title section, like: "Peter Pan's paper"
  -i  input markdown format file, like: a.md
  -o  output latex format file, like: "a.pdf"
EOF
}

ENV_PATH=$(cd `dirname $BASH_SOURCE` && /bin/pwd)/..

OPTIND=1
while getopts ":i:o:t:a:" var;
do
  case ${var} in
  a)
    author=${OPTARG};;
  t)
    title=${OPTARG};;
  i)
    input_f=${OPTARG};;
  o)
    output_f=${OPTARG};;
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

if [ $OPTIND -eq 1 ]; then
  usage
  exit 1
fi

title=${title//_/\\_}
author=${author//_/\\_}

echo "covert ${input_f} to ${output_f}..."

set -x
pandoc --template=$ENV_PATH/latex/md2pdf.tex --latex-engine=xelatex -s -f markdown+escaped_line_breaks+multiline_tables+link_attributes ${input_f} -t latex --toc --toc-depth=3 --variable author="$author" --variable title="$title" -o xtemp.tex
set +x

sed -i 's/\\begin{verbatim}/\\begin{lstlisting}/g' xtemp.tex
sed -i 's/\\end{verbatim}/\\end{lstlisting}/g' xtemp.tex

xelatex xtemp.tex
if [ $? -eq 0 ]; then
  xelatex xtemp.tex
fi

rm xtemp.tex *.aux  *.log  *.out *.toc > /dev/null 2>&1

mv xtemp.pdf ${output_f}
