#!/usr/bin/env bash
# Configure SSH keep-alive settings

SSH_CONFIG="${HOME}/.ssh/config"

log_info "Configuring SSH keep-alive..."

# Create .ssh directory if not exists
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"

# Check if already configured
if [ ! -f "${SSH_CONFIG}" ] || ! grep -q "ServerAliveInterval" "${SSH_CONFIG}"; then
    cat >> "${SSH_CONFIG}" << 'EOF'

# Keep SSH connections alive
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
    chmod 600 "${SSH_CONFIG}"
    log_info "✓ SSH keep-alive configured"
else
    log_info "SSH keep-alive already configured"
fi
