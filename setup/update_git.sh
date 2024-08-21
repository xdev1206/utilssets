#!/bin/bash

git config --local user.name "LittleMiner"
git config --local user.email "nocent@126.com"
git config --local credential.helper store
git config --global core.editor vim
git config --global --add safe.directory /work/xinxu5/bot-cctrl-service
git config --global http.version HTTP/1.1 # HTTP/2
git config --global http.sslBackend gnutls
