#!/bin/bash

# Source env.sh to get export_env function
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common/env.sh"

install_package()
{
  # necessary packages for development
  $SUDO ${INSTALL_CMD} curl wget tree pkg-config autoconf automake git-xet
}

shell_env()
{
    export_env CLICOLOR 1
    export_env LSCOLORS exfxcxdxcxegedabagacad
    export_env HOMEBREW_NO_AUTO_UPDATE 1

    if [ "${SHELL}" = "/bin/bash" ]; then
        export_env PS1 '"\[\e]0;\u@\h: \w\a\]\[\e[33m\]\u@\h\[\e[0m\]:\[\033[01;34m\]\w\[\e[0m\]\$ "'
    elif [ "${SHELL}" = "/bin/zsh" ]; then
        export_env PS1 "\"%F{yellow}%n@%h%f:%F{blue}%~%f%# \""

        # Add zsh completion if not exists
        if [ -n "${SHELL_RC}" ] && ! grep -q "autoload -Uz compinit" "${SHELL_RC}" 2>/dev/null; then
            echo 'autoload -Uz compinit' >> "${SHELL_RC}"
            echo 'compinit' >> "${SHELL_RC}"
        fi
    fi
}

macos_defaults()
{
    # Prevent .DS_Store files on network and USB drives
    defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool TRUE
    defaults write com.apple.desktopservices DSDontWriteUSBStores -bool TRUE
}

install_package
shell_env
macos_defaults

# Source keybindings if exists
KEYBINDINGS_FILE="${SCRIPT_DIR}/keybindings.sh"
[ -f "${KEYBINDINGS_FILE}" ] && source "${KEYBINDINGS_FILE}"

# Configure locale (default: C.UTF-8)
bash "${SCRIPT_DIR}/../common/setup_locale.sh"
bash "${SCRIPT_DIR}/../common/setup_pip.sh"
