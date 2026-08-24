#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is not installed. Please install curl first."
  exit 1
fi

echo "Detected shell profile: ${SHELL_RC}"

CLAUDE_DIR="${HOME}/.claude"
CLAUDE_SHARED_DIR="${SCRIPT_DIR}/../../aiworking/claude/.claude"
CLAUDE_TEMPLATE_DIR="${SCRIPT_DIR}/../../aiworking/claude"
CLAUDE_LOCAL_DIR="${SCRIPT_DIR}/../../aiworking/claude/local"

install_cli() {
    if command -v claude >/dev/null 2>&1; then
        echo "claude already installed. Skipping."
        return 0
    fi

    echo "Installing Claude Code via native installer..."
    curl -fsSL https://claude.ai/install.sh | bash
}

copy_tree_if_missing() {
    local source_dir="$1"
    local label="$2"
    local source_path relative_path target_path

    if [ ! -d "${source_dir}" ]; then
        echo "Warning: ${source_dir} not found, skipping ${label}"
        return 0
    fi

    while read -r source_path; do
        relative_path="${source_path#${source_dir}/}"
        target_path="${CLAUDE_DIR}/${relative_path}"
        if [ -e "${target_path}" ]; then
            echo "Skipping existing ${target_path}"
            continue
        fi

        mkdir -p "$(dirname "${target_path}")"
        cp "${source_path}" "${target_path}"
        chmod 600 "${target_path}"
        echo "Copied ${source_path} to ${target_path}"
    done < <(find "${source_dir}" -type f ! -name '.gitkeep')

    echo "Claude config sync finished for ${label}"
}

copy_file_if_missing() {
    local source_path="$1"
    local target_path="$2"
    local label="$3"

    if [ ! -f "${source_path}" ]; then
        echo "Warning: ${source_path} not found, skipping ${label}"
        return 0
    fi

    if [ -e "${target_path}" ]; then
        echo "Skipping existing ${target_path}"
        return 0
    fi

    mkdir -p "$(dirname "${target_path}")"
    cp "${source_path}" "${target_path}"
    chmod 600 "${target_path}"
    echo "Copied ${source_path} to ${target_path}"
}

setup_claude_settings() {
    local local_settings="${CLAUDE_LOCAL_DIR}/settings.json"
    local example_settings="${CLAUDE_TEMPLATE_DIR}/settings.json.example"
    local target_settings="${CLAUDE_DIR}/settings.json"

    if [ -f "${local_settings}" ]; then
        copy_file_if_missing "${local_settings}" "${target_settings}" "local Claude settings"
        return 0
    fi

    copy_file_if_missing "${example_settings}" "${target_settings}" "example Claude settings"
}

mkdir -p "${CLAUDE_DIR}"

install_cli
copy_tree_if_missing "${CLAUDE_SHARED_DIR}" "shared Claude config"
copy_file_if_missing "${CLAUDE_TEMPLATE_DIR}/CLAUDE.md" "${CLAUDE_DIR}/CLAUDE.md" "shared Claude instructions"
setup_claude_settings

echo "Claude config sync complete: ${CLAUDE_DIR}"
