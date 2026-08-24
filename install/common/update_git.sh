#!/bin/bash

echo "IFS:$IFS, as delimeter"

read -p "set local/global config (L/G)?: " scope && [[ $scope == [lLgG] ]] || exit 1
read -p "username, like 'Han Lei': " username
read -p "email: " email

if [[ $scope == [lL] ]]; then
    option="--local"
else
    option="--global"
fi

git config $option user.name "$username"
git config $option user.email "$email"

git config --global credential.helper store
git config --global core.editor vim
git config --global --add safe.directory /workspace
git config --global http.version HTTP/1.1 # HTTP/2
git config --global http.sslBackend gnutls

# 配置diff忽略行尾空白
# git config --global core.whitespace trailing-space,space-before-tab
# git config --global apply.whitespace fix

# 忽略所有空白字符的变化
# git config --global core.autocrlf input
# git config --global diff.ignoreSubmodules dirty

# 禁用行尾处理
git config --global core.eol native
git config --global core.autocrlf false
git config --global core.safecrlf false
