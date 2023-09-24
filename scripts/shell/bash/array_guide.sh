#!/bin/bash

# If the subscript is ‘@’ or ‘*’, the word expands to all members of the array name.
# These subscripts differ only when the word appears within double quotes.
# If the word is double-quoted,
# ${name[*]} expands to a single word with the value of each array member separated by the first character of the IFS variable, and
# ${name[@]} expands each element of name to a separate word.
# When there are no array members, ${name[@]} expands to nothing.
# If the double-quoted expansion occurs within a word,
# the expansion of the first parameter is joined with the beginning part of the original word, and
# the expansion of the last parameter is joined with the last part of the original word.
# This is analogous to the expansion of the special parameters ‘@’ and ‘*’.
# ${#name[subscript]} expands to the length of ${name[subscript]}. If subscript is ‘@’ or ‘*’, the expansion is the number of elements in the array.
# If the subscript used to reference an element of an indexed array evaluates to a number less than zero,
# it is interpreted as relative to one greater than the maximum index of the array,
# so negative indices count back from the end of the array, and an index of -1 refers to the last element.

repo_list=(
    https://www.github.com/vnpy/vnpy_ctp
    https://www.github.com/vnpy/vnpy_mini
    https://www.github.com/vnpy/vnpy_sopt
    https://www.github.com/vnpy/vnpy_femas
    https://www.github.com/vnpy/vnpy_uft
    https://www.github.com/vnpy/vnpy_esunny
    https://www.github.com/vnpy/vnpy_sec
    https://www.github.com/vnpy/vnpy_hts
)

echo "array length: ${#repo_list[@]}"

for repo in ${repo_list[@]}; do
    echo "$repo"
    echo "repo name: ${repo##https*\/}"
done
