#!/bin/bash

include_dir=/data/xuxin/tensorflow/include

headers=`find tensorflow/lite -maxdepth 3 -iname "*.h"`
for header in ${headers}
do
  dir=`dirname $header`
  file=`basename $header`

  if [ ! -d "${include_dir}/$dir" ]; then
    mkdir -p "${include_dir}/$dir"
  fi

  echo "copy file: ${header}"
  cp ${header} ${include_dir}/$dir
done

# copy flatbuffer header files
cp -r tensorflow/lite/tools/make/downloads/flatbuffers/include/flatbuffers ${include_dir}
