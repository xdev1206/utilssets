#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"

# Check for curl
if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl is not installed. Please install curl first."
  exit 1
fi

echo "Detected shell profile: ${SHELL_RC}"

install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        echo "Fetching latest NVM release version..."
        NVM_LATEST_TAG="$(curl -fsSLI -o /dev/null -w '%{url_effective}\n' https://github.com/nvm-sh/nvm/releases/latest | awk -F/ '{print $NF}')"

        if [ -z "$NVM_LATEST_TAG" ]; then
            echo "Error: failed to fetch the latest NVM version."
            exit 1
        fi

        echo "Installing NVM ${NVM_LATEST_TAG}..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_LATEST_TAG}/install.sh" | bash
    else
        echo "NVM directory already exists at ~/.nvm"
    fi

    # Always load NVM into the current shell
    export_env NVM_DIR "$HOME/.nvm"
    export NVM_DIR="$HOME/.nvm"

    if [ -s "$NVM_DIR/nvm.sh" ]; then
        # shellcheck disable=SC1090
        . "$NVM_DIR/nvm.sh"
    else
        echo "Error: $NVM_DIR/nvm.sh not found. NVM installation may have failed."
        exit 1
    fi

    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

    if ! command -v nvm >/dev/null 2>&1; then
        echo "Error: NVM was not loaded successfully."
        exit 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo "Installing the latest Node.js version..."
        nvm install node
        nvm alias default node
        nvm use default
    else
        echo "Node.js already installed: $(node -v)"
    fi

    echo "NVM: $(nvm --version)  Node: $(node -v)  npm: $(npm -v)"
    echo "If commands are unavailable in a new terminal, run: source \"${SHELL_RC}\""
}

install_cli() {
    #cli_cmd=claude
    cli_cmd=codex
    if command -v ${cli_cmd} &>/dev/null; then
        echo "${cli_cmd} already installed. Skipping."
        return 0
    fi

    #npm_pkg="@anthropic-ai/claude-code"
    npm_pkg="@openai/codex"
    echo "Installing ${npm_pkg} via npm..."

    if npm install -g ${npm_pkg}; then
        echo "${npm_pkg} installed successfully via npm"
        return 0
    fi

    echo "npm install failed, falling back to URL install..."

    local fallback_url="https://chatgpt.com/codex/install.sh"

    case "${OS_TYPE}" in
        Darwin|Linux)
            local tmp_script http_code
            tmp_script=$(mktemp)
            # shellcheck disable=SC2064
            trap "rm -f ${tmp_script}" RETURN

            http_code=$(curl -sS -L -o "${tmp_script}" -w "%{http_code}" "${fallback_url}")
            if [ "${http_code}" = "200" ]; then
                bash "${tmp_script}" || return 1
            else
                echo "npm install -g ${npm_pkg} ..."
                npm install -g ${npm_pkg}
            fi
            ;;
        *)
            echo "Unsupported OS: ${OS_TYPE}"
            return 1
            ;;
    esac

    echo "${npm_pkg} installed successfully via URL"
}

setup_cli() {
    install_nvm
    install_cli || return 1

    echo ""
    echo "setup complete!"
    echo "Codex CLI installed."
}

setup_cli

CODEX_DIR="${HOME}/.codex"
CODEX_SHARED_DIR="${SCRIPT_DIR}/../../aiworking/codex/shared"
CODEX_LOCAL_DIR="${SCRIPT_DIR}/../../aiworking/codex/local"

mkdir -p "${CODEX_DIR}"

copy_codex_tree_if_missing() {
    local source_dir="$1"
    local label="$2"
    local source_path relative_path target_path

    if [ ! -d "${source_dir}" ]; then
        echo "Warning: ${source_dir} not found, skipping ${label}"
        return 0
    fi

    while read -r source_path; do
        relative_path="${source_path#${source_dir}/}"
        target_path="${CODEX_DIR}/${relative_path}"
        if [ -e "${target_path}" ]; then
            echo "Skipping existing ${target_path}"
            continue
        fi

        mkdir -p "$(dirname "${target_path}")"
        cp "${source_path}" "${target_path}"
        chmod 600 "${target_path}"
        echo "Copied ${source_path} to ${target_path}"
    done < <(find "${source_dir}" -type f ! -name '.gitkeep')

    echo "Codex config sync finished for ${label}"
}

ensure_local_codex_demo_files() {
    local local_auth_file="${CODEX_LOCAL_DIR}/auth.json"
    local local_config_file="${CODEX_LOCAL_DIR}/config.toml"

    mkdir -p "${CODEX_LOCAL_DIR}"

    if [ ! -f "${local_auth_file}" ]; then
        cat > "${local_auth_file}" <<'EOF'
{
  "auth_mode": "apikey",
  "OPENAI_API_KEY": "ky_demo123456789"
}
EOF
        echo "Generated demo ${local_auth_file}"
    fi

    if [ ! -f "${local_config_file}" ]; then
        cat > "${local_config_file}" <<'EOF'
model_provider = "azure"
model = "azure/gpt-5.4"
approval_policy = "never"
sandbox_mode = "danger-full-access"

[model_providers.azure]
name = "Azure"
base_url = "https://example.ai.com/v1"
wire_api = "responses"
# Export CODEX_API_KEY before running Codex with this custom provider.
env_key = "CODEX_API_KEY"
EOF
        echo "Generated demo ${local_config_file}"
    fi
    chmod 600 "${local_auth_file}" "${local_config_file}"
}

copy_codex_tree_if_missing "${CODEX_SHARED_DIR}" "shared Codex config"
ensure_local_codex_demo_files
copy_codex_tree_if_missing "${CODEX_LOCAL_DIR}" "local Codex config"

if [ -f "${CODEX_DIR}/AGENTS.md" ]; then
    chmod 600 "${CODEX_DIR}/AGENTS.md"
fi

echo "Codex config sync complete: ${CODEX_DIR}"
