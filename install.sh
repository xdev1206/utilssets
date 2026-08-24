#!/usr/bin/env bash
# Main installation script for utilssets

set -euo pipefail

# Make sure not running in dash
if ps aux | grep -i $$ | grep -qiE "(/| |da)sh[ ]+$0"; then
  echo "Error: Please run with bash:"
  echo "  bash $0"
  exit 1
fi

# Detect UTILSSETS_ROOT
UTILSSETS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export UTILSSETS_ROOT

# Source common utilities
source "${UTILSSETS_ROOT}/lib/shell/common.sh"

log_info "Starting utilssets installation..."
log_info "Installation root: ${UTILSSETS_ROOT}"

# Detect OS
OS_TYPE=$(detect_os)
log_info "Detected OS: ${OS_TYPE}"

# Setup environment first (defines export_env function)
log_info "Setting up environment..."
source "${UTILSSETS_ROOT}/install/common/env.sh"

# Check network status
if [ "${NETWORK}" = "1" ]; then
    log_info "Network available"
else
    log_warn "Network unavailable - skipping online installations"
fi

# Check prerequisites
log_info "Checking prerequisites..."
source "${UTILSSETS_ROOT}/install/common/prerequisite.sh"

# Run platform-specific installation
case "${OS_TYPE}" in
    Darwin)
        log_info "Running macOS installation..."
        source "${UTILSSETS_ROOT}/install/darwin/wizard_Darwin.sh" || true
        ;;
    Linux)
        log_info "Running Linux installation..."
        source "${UTILSSETS_ROOT}/install/linux/wizard_Linux.sh" || true
        ;;
    *)
        error_exit "Unsupported OS: ${OS_TYPE}"
        ;;
esac

# Setup vim (only if network available)
if [ "${NETWORK}" = "1" ]; then
    log_info "Setting up Vim..."
    source "${UTILSSETS_ROOT}/install/common/setup_vim.sh" || true
else
    log_warn "Skipping Vim setup (requires network)"
fi

# Setup fzf (only if network available)
if [ "${NETWORK}" = "1" ]; then
    log_info "Setting up fzf..."
    source "${UTILSSETS_ROOT}/install/common/update_fzf.sh" || true
else
    log_warn "Skipping fzf setup (requires network)"
fi

# Setup SSH configuration
log_info "Setting up SSH..."
source "${UTILSSETS_ROOT}/install/common/setup_ssh.sh" || true

# Setup tmux color configuration
log_info "Setting up tmux..."
source "${UTILSSETS_ROOT}/install/common/setup_tmux.sh" || true

# Auto-configure shell RC file
# Detect shell RC file
if [ -n "${ZSH_VERSION:-}" ] || [ "${SHELL##*/}" = "zsh" ]; then
    SHELL_RC="${HOME}/.zshrc"
else
    SHELL_RC="${HOME}/.bashrc"
fi

log_info "Configuring ${SHELL_RC}..."

# Check if already configured
if grep -q "UTILSSETS_ROOT.*${UTILSSETS_ROOT}" "${SHELL_RC}" 2>/dev/null; then
    log_info "Already configured in ${SHELL_RC}"
else
    # Backup
    cp "${SHELL_RC}" "${SHELL_RC}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true

    # Add configuration
    cat >> "${SHELL_RC}" << EOF

# Utilssets environment
export UTILSSETS_ROOT="${UTILSSETS_ROOT}"
source \${UTILSSETS_ROOT}/config/shell/config.env
EOF

    log_info "✓ Added to ${SHELL_RC}"
fi

log_info "Installation complete!"
log_info "Please run: source ${SHELL_RC}"
