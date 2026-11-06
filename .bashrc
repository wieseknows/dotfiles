# shellcheck shell=bash
# Main dotfiles configuration loader
# This file is sourced from ~/.bashrc via install.sh

# ====================================================
# Aliases
# ====================================================

if [ -f "$DOTFILES_DIR/aliases.bash" ]; then
    source "$DOTFILES_DIR/aliases.bash"
fi

# ====================================================
# Functions
# ====================================================

if [ -f "$DOTFILES_DIR/functions.bash" ]; then
    source "$DOTFILES_DIR/functions.bash"
fi

# ====================================================
# Default environment
# ====================================================

export PROJECTS_ROOT="${PROJECTS_ROOT:-/c/dev/projects}"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth
export EDITOR=vim

# ====================================================
# Local machine configuration
# ====================================================

if [ -f "$HOME/.bashrc.local" ]; then
    # shellcheck source=/dev/null
    source "$HOME/.bashrc.local"
fi

# ====================================================
# SSH Agent
# ====================================================

AGENT_INFO="$HOME/.ssh/agent_info"

print_ssh_status() {
    echo "🤖 SSH Agent (PID: ${SSH_AGENT_PID:-unknown})"

    local loaded_keys
    if loaded_keys=$(ssh-add -l 2>/dev/null) && [ -n "$loaded_keys" ]; then
        echo "🔑 Loaded keys:"
        # shellcheck disable=SC2001
        echo "$loaded_keys" | sed 's/^/   ✓ /'
    else
        echo "🔑 No SSH keys loaded"
    fi
}

add_ssh_keys() {
    if [ -z "${SSH_KEYS+x}" ] || [ ${#SSH_KEYS[@]} -eq 0 ]; then
        echo "  ⚠️ SSH_KEYS is not configured"
        return 0
    fi

    echo "🔑 Checking SSH keys..."

    local loaded_fps
    loaded_fps=$(ssh-add -l 2>/dev/null || true)

    for key in "${SSH_KEYS[@]}"; do
        if [ -f "$key" ]; then
            # Warn if user provided a PuTTY .ppk file directly
            if [[ "$key" == *.ppk ]]; then
                echo "  ⚠️ PuTTY format unsupported: $key (export as OpenSSH key in PuTTYgen)"
                continue
            fi

            # Check if key fingerprint is already loaded in agent
            local key_fp
            key_fp=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}')
            if [ -n "$key_fp" ] && echo "$loaded_fps" | grep -q "$key_fp"; then
                echo "  ✓ Loaded: $key"
            else
                if ssh-add "$key" 2>/dev/null; then
                    echo "  ✓ Added: $key"
                else
                    echo "  ✗ Failed: $key"
                fi
            fi
        else
            if [ -f "${key}.ppk" ]; then
                echo "  ⚠️ Key not found: $key (Found ${key}.ppk in PuTTY format — convert to OpenSSH)"
            else
                echo "  ⚠️ Key not found: $key"
            fi
        fi
    done
}

start_ssh_agent() {
    # 1. Load saved agent environment if available
    if [ -f "$AGENT_INFO" ]; then
        # shellcheck source=/dev/null
        source "$AGENT_INFO" >/dev/null 2>&1
    fi

    # 2. Check if existing agent is alive and responding
    if [ -n "$SSH_AGENT_PID" ] && kill -0 "$SSH_AGENT_PID" 2>/dev/null; then
        ssh-add -l >/dev/null 2>&1
        local ret=$?
        # ret 0 = keys present, ret 1 = agent alive without keys
        if [ $ret -eq 0 ] || [ $ret -eq 1 ]; then
            add_ssh_keys
            print_ssh_status
            return 0
        fi
    fi

    # 3. Start a new agent if none is running
    echo "🚀 Starting new SSH Agent..."
    eval "$(ssh-agent -s)" >/dev/null

    mkdir -p "$HOME/.ssh"
    cat > "$AGENT_INFO" <<EOF
export SSH_AUTH_SOCK="$SSH_AUTH_SOCK"
export SSH_AGENT_PID="$SSH_AGENT_PID"
EOF
    chmod 600 "$AGENT_INFO" 2>/dev/null || true

    add_ssh_keys
    print_ssh_status
}

# ====================================================
# Start / reconnect SSH agent
# ====================================================

start_ssh_agent
