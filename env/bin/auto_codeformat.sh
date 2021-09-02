#!/bin/bash

function formatting()
{
  source_file=$1

  echo "auto formatting: ${source_file}"
   # change permission to 644
  chmod 644 ${source_file}
  # to unix file format
  #dos2unix ${source_file}
  # remove trailing spaces at the end of lines
  sed -i 's/[ ]\+$//' ${source_file}
  # replace tab to 4 whitespace
  sed -i 's/\t/    /g' ${source_file}
  # merge multi-blank lines to one blank line
  sed -i '/^$/{N;/^\n*$/D}' ${source_file}
  # add \n if there is no \n at the last line of file
  sed -i '$a\' ${source_file}
}

astyle_common_options="-v -n -r"

java_style='--style=java'
c_style='--style=kr'

tab_style='--attach-namespaces --attach-extern-c --attach-closing-while --indent=spaces=4'

indentation_style='--indent-preproc-define --indent-col1-comments --min-conditional-indent=0 --max-continuation-indent=120'

padding_style='--pad-oper --pad-comma --pad-header --align-pointer=type --align-reference=type'

formatting_config='--break-closing-braces --attach-return-type --attach-return-type-decl --keep-one-line-blocks --keep-one-line-statements --convert-tabs --max-code-length=200 --mode=c'

other_config='--lineend=linux'

java_wildcard='*.java'
c_wildcard='*.cpp,*.cc,*.c,*.h'

astyle ${java_style} ${tab_style} ${indentation_style} ${padding_style} ${formatting_config} ${other_config} ${astyle_common_options} "${java_wildcard}"
astyle ${c_style} ${tab_style} ${indentation_style} ${padding_style} ${formatting_config} ${other_config} ${astyle_common_options} "${c_wildcard}"
