#!/bin/bash

# --graph：用 ASCII 字符绘制分支结构图
# --oneline：单行显示提交信息
# --decorate：显示分支名和标签
# --all：所有分支一起显示，适合完整查看分支关系
git log --graph --oneline --decorate --all --color
