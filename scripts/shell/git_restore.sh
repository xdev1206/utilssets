#!/bin/bash

diff_info="`git diff --summary`"

IFS=$'\n'

for line in $diff_info
do
  if test `echo -e "$line" | head -c 12` == " mode change"; then
	old_mode=`echo "$line" | cut -d" " -f 4 | sed -e 's/100//g'`
	file=`echo "$line" | cut -d" " -f 7`

	echo "old: $old_mode"
	echo "file: $file"

	chmod $old_mode $file
  fi
done
