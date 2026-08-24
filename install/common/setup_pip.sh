#!/usr/bin/env bash
# Configure pip to use Chinese mirrors

# Detect pip command
if command -v pip &>/dev/null; then
    PIP_CMD="pip"
elif command -v pip3 &>/dev/null; then
    PIP_CMD="pip3"
elif command -v python3 &>/dev/null; then
    PIP_CMD="python3 -m pip"
else
    echo "Warning: pip not found, skipping pip configuration"
    exit 0
fi

$PIP_CMD config set --user global.index-url https://mirrors.aliyun.com/pypi/simple/
$PIP_CMD config set --user global.extra-index-url https://pypi.org/simple/
$PIP_CMD config set --user global.timeout 120
$PIP_CMD config set --user install.trusted-host mirrors.aliyun.com

echo "pip configured ($PIP_CMD):"
$PIP_CMD config list --user
