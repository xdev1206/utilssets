#!/usr/bin/env bash

username=x.x
password=y.y

# gerrit query 支持 --patch-sets，它会列出变更的所有 patch set 信息
ssh -p 29418 ${username}@gerrit.example.com gerrit query owner:${username} status:merged limit:50 --patch-sets

change_id=xxx
ssh -p 29418 ${username}@gerrit.example.com gerrit query change:${change_id} --patch-sets

numeric_id=1
# numeric_id 是 Gerrit 内部的数字 ID（可以在网页 URL 看到），返回的 JSON 里 "revisions" 字段就是所有 patch set
curl --user ${username}:${password} "https://gerrit.example.com/a/changes/${numeric_id}/detail"
