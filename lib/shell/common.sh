#!/usr/bin/env bash
# Common error handling and utility functions for all scripts

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Error handler
error_exit() {
    log_error "$1"
    exit "${2:-1}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect shell type
detect_shell() {
    if [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        echo "zsh"
    else
        echo "unknown"
    fi
}

# Get script directory (works in both bash and zsh)
get_script_dir() {
    if [ -n "${BASH_SOURCE:-}" ]; then
        echo "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    elif [ -n "${ZSH_VERSION:-}" ]; then
        echo "$(cd "$(dirname "${(%):-%x}")" && pwd)"
    else
        echo "$(cd "$(dirname "$0")" && pwd)"
    fi
}

# Check network connectivity
check_network() {
    if command_exists curl; then
        curl -s --connect-timeout 5 https://www.google.com > /dev/null 2>&1
        return $?
    elif command_exists wget; then
        wget -q --spider --timeout=5 https://www.google.com > /dev/null 2>&1
        return $?
    else
        log_warn "Neither curl nor wget found, cannot check network"
        return 1
    fi
}

# Detect OS type
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "Darwin" ;;
        Linux*)     echo "Linux" ;;
        *)          echo "Unknown" ;;
    esac
}

export -f log_info log_warn log_error error_exit command_exists detect_shell get_script_dir check_network detect_os
