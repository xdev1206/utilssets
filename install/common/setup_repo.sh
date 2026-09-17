#!/bin/bash

SCRIPT_PATH=$(cd `dirname ${BASH_SOURCE[0]}` && /bin/pwd)

if [ -z "${OS_NAME}" ]; then
    source ${SCRIPT_PATH}/env.sh
fi

REPO_DIR="${BIN_DIR}"
REPO_PATH="$REPO_DIR/repo"
REPO_URL="https://storage.googleapis.com/git-repo-downloads/repo"
MANIFEST_URL="https://github.com/xdev1206/manifests.git"
GITHUB_AUTH_FILE="${UTILSSETS_ROOT}/aiworking/github/local/token.env"
REPO_COMMAND="init"
ADD_URL=""
ADD_PATH=""
ADD_REVISION=""
if [ "${1:-}" = "sync" ] || [ "${1:-}" = "list" ]; then
    REPO_COMMAND="$1"
    shift
elif [ "${1:-}" = "add" ]; then
    REPO_COMMAND="add"
    shift
    ADD_URL="${1:-}"
    ADD_PATH="${2:-}"
    ADD_REVISION="${3:-}"
    if [ -z "${ADD_URL}" ]; then
        echo "usage: $0 add <github-url> <path> <revision>" >&2
        exit 1
    fi
    if [ -z "${ADD_PATH}" ]; then
        SUGGESTED_PATH=""
        if [[ "${ADD_URL}" =~ ^https://github\.com/[A-Za-z0-9_.-]+/([A-Za-z0-9_.-]+)(\.git)?/?$ ]]; then
            SUGGESTED_PATH="${BASH_REMATCH[1]}"
            SUGGESTED_PATH="${SUGGESTED_PATH%.git}"
        fi
        echo "error: path is required${SUGGESTED_PATH:+; suggested path: ${SUGGESTED_PATH}}" >&2
        echo "usage: $0 add <github-url> <path> <revision>" >&2
        exit 1
    fi
    if [ -z "${ADD_REVISION}" ]; then
        echo "error: revision is required; suggested revision: main" >&2
        echo "usage: $0 add <github-url> <path> <revision>" >&2
        exit 1
    fi
    shift $(( $# >= 3 ? 3 : $# ))
    if [ "$#" -ne 0 ]; then
        echo "usage: $0 add <github-url> <path> <revision>" >&2
        exit 1
    fi
fi
SYNC_TARGETS=("$@")

if [ -f "${GITHUB_AUTH_FILE}" ]; then
    # shellcheck disable=SC1090
    source "${GITHUB_AUTH_FILE}"
fi

if ! command -v repo >/dev/null 2>&1; then
    mkdir -p "$REPO_DIR"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$REPO_URL" -o "$REPO_PATH"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$REPO_URL" -O "$REPO_PATH"
    else
        echo "error: can't find curl or wget!"
        exit 1
    fi

    chmod a+x "$REPO_PATH"
    echo "repo download successfully: $REPO_PATH"
else
    echo "repo already installed: $(which repo)"
fi

# Setup repo workspace
REPO_WORKSPACE="${UTILSSETS_ROOT}/src/repo"

if [ "${NETWORK}" = "1" ]; then
    mkdir -p "$REPO_WORKSPACE"
    cd "$REPO_WORKSPACE"

    # Use full path to repo
    REPO_CMD="${REPO_PATH}"

    if [ -n "${GH_TOKEN:-}" ]; then
        export GIT_CONFIG_COUNT=2
        export GIT_CONFIG_KEY_0=credential.helper
        export GIT_CONFIG_VALUE_0=
        export GIT_CONFIG_KEY_1=credential.helper
        export GIT_CONFIG_VALUE_1='!f() { printf "username=%s\npassword=%s\n\n" "${GH_USERNAME:-x-access-token}" "$GH_TOKEN"; }; f'
    fi

    if [ "${REPO_COMMAND}" = "list" ]; then
        if [ ! -f ".repo/manifest.xml" ]; then
            echo "error: repo workspace is not initialized" >&2
            exit 1
        fi
        "${REPO_CMD}" list -p
        exit $?
    fi

    if [ ! -f ".repo/manifest.xml" ] || [ ! -d ".repo/manifests" ]; then
        if [ -d ".repo" ]; then
            echo "Repo workspace metadata is incomplete, reinitializing..."
        fi
        if ! git ls-remote "${MANIFEST_URL}"; then
            echo "error: unable to access manifest repository" >&2
            exit 1
        fi

        echo "Initializing repo workspace..."
        if ! "${REPO_CMD}" init -u "${MANIFEST_URL}" -b main; then
            echo "error: failed to initialize repo workspace" >&2
            exit 1
        fi
    else
        echo "Repo workspace already initialized at $REPO_WORKSPACE"
    fi

    if [ "${REPO_COMMAND}" = "add" ]; then
        if [[ ! "${ADD_URL}" =~ ^https://github\.com/([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(\.git)?/?$ ]]; then
            echo "error: only GitHub HTTPS repository URLs are supported" >&2
            exit 1
        fi
        PROJECT_REPOSITORY="${BASH_REMATCH[2]}"
        PROJECT_REPOSITORY="${PROJECT_REPOSITORY%.git}"
        PROJECT_NAME="${BASH_REMATCH[1]}/${PROJECT_REPOSITORY}"
        if [ -z "${ADD_PATH}" ]; then
            ADD_PATH="${PROJECT_REPOSITORY}"
        fi
        if [[ ! "${ADD_PATH}" =~ ^[A-Za-z0-9._/-]+$ ]] || [[ ! "${ADD_REVISION}" =~ ^[A-Za-z0-9._/-]+$ ]]; then
            echo "error: path and revision contain unsupported characters" >&2
            exit 1
        fi
        MANIFEST_FILE=".repo/manifests/default.xml"
        if grep -qE "path=\"${ADD_PATH}\"|name=\"${PROJECT_NAME}\"" "${MANIFEST_FILE}"; then
            echo "error: project already exists in ${MANIFEST_FILE}" >&2
            exit 1
        fi
        PROJECT_LINE="  <project name=\"${PROJECT_NAME}\" path=\"${ADD_PATH}\" revision=\"${ADD_REVISION}\" />"
        TEMP_MANIFEST="${MANIFEST_FILE}.tmp"
        awk -v project_line="${PROJECT_LINE}" '{ if ($0 ~ /<\/manifest>/) print project_line; print }' "${MANIFEST_FILE}" > "${TEMP_MANIFEST}"
        mv "${TEMP_MANIFEST}" "${MANIFEST_FILE}"
        SYNC_TARGETS=("${ADD_PATH}")
        echo "Added ${PROJECT_NAME} to ${MANIFEST_FILE}"
    fi

    if [ "${#SYNC_TARGETS[@]}" -eq 0 ]; then
        echo "Syncing all repositories..."
    else
        echo "Syncing repositories: ${SYNC_TARGETS[*]}"
    fi
    if ! "${REPO_CMD}" sync "${SYNC_TARGETS[@]}"; then
        echo "error: failed to sync repositories" >&2
        exit 1
    fi
else
    echo "Network unavailable, skipping repo sync"
fi

# Add to .gitignore
GITIGNORE="${UTILSSETS_ROOT}/.gitignore"
if ! grep -q "^src/repo$" "$GITIGNORE" 2>/dev/null; then
    echo "src/repo" >> "$GITIGNORE"
    echo "Added src/repo to .gitignore"
fi
