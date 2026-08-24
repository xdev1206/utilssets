#!/usr/bin/env bash
# Configure locale environment variables

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

LOCALE="${1:-C.UTF-8}"

export_env LANG "${LOCALE}"
export_env LC_CTYPE "${LOCALE}"
export_env LC_ALL "${LOCALE}"

echo "Locale configured: ${LOCALE}"
