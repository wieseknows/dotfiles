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
        local line
        while IFS= read -r line; do
            echo "   ✓ $line"
        done <<< "$loaded_keys"
    else
        echo "🔑 No SSH keys loaded"
    fi
}

discover_ssh_keys() {
    local ssh_dir="$HOME/.ssh"
    [ -d "$ssh_dir" ] || return 0

    local candidate
    for candidate in "$ssh_dir"/*; do
        [ -f "$candidate" ] || continue
        case "$candidate" in
            *.pub|*.ppk|*.bak|*.bak.*|*/config|*/known_hosts*|*/authorized_keys*|*/agent_info*)
                continue
                ;;
        esac
        if grep -qsE '^-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----' "$candidate"; then
            printf '%s\n' "$candidate"
        fi
    done
}

add_ssh_keys() {
    local keys_to_load=()
    if [ -n "${SSH_KEYS+x}" ] && [ ${#SSH_KEYS[@]} -gt 0 ]; then
        keys_to_load=("${SSH_KEYS[@]}")
    else
        local discovered_key
        while IFS= read -r discovered_key; do
            [ -n "$discovered_key" ] && keys_to_load+=("$discovered_key")
        done < <(discover_ssh_keys)
    fi

    if [ ${#keys_to_load[@]} -eq 0 ]; then
        echo "  ℹ️  No SSH keys configured or found in ~/.ssh"
        return 0
    fi

    echo "🔑 Checking SSH keys..."

    local loaded_fps
    loaded_fps=$(ssh-add -l 2>/dev/null || true)

    local key key_fp
    for key in "${keys_to_load[@]}"; do
        if [ ! -f "$key" ]; then
            if [ -f "${key}.ppk" ]; then
                echo "  ⚠️ Key not found: $key (Found ${key}.ppk in PuTTY format — convert to OpenSSH)"
            else
                echo "  ⚠️ Key not found: $key"
            fi
            continue
        fi

        # Warn if user provided a PuTTY .ppk file directly
        if [[ "$key" == *.ppk ]]; then
            echo "  ⚠️ PuTTY format unsupported: $key (export as OpenSSH key in PuTTYgen)"
            continue
        fi

        # Check if key fingerprint is already loaded in agent
        key_fp=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $2}')
        if [ -n "$key_fp" ] && printf '%s\n' "$loaded_fps" | grep -Fq "$key_fp"; then
            echo "  ✓ Loaded: $key"
        elif ssh-add "$key" 2>/dev/null; then
            echo "  ✓ Added: $key"
        else
            echo "  ✗ Failed: $key"
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

    # 3. Start a new agent if none is running.
    # Redirect stdin/stderr so the background daemon does not hold the terminal PTY open.
    echo "🚀 Starting new SSH Agent..."
    eval "$(ssh-agent -s </dev/null 2>/dev/null)" >/dev/null

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
# Start / reconnect SSH agent (interactive shells only)
# ====================================================

if [[ $- == *i* ]]; then
    start_ssh_agent
fi
