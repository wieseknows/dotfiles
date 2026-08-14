# Main dotfiles configuration loader
# This file is sourced from ~/.bashrc via install.sh

# Source aliases
if [ -f "$DOTFILES_DIR/aliases.bash" ]; then
    source "$DOTFILES_DIR/aliases.bash"
fi

# Source functions
if [ -f "$DOTFILES_DIR/functions.bash" ]; then
    source "$DOTFILES_DIR/functions.bash"
fi

# Default environment variables (can be overridden in ~/.bashrc.local)
export PROJECTS_ROOT="${PROJECTS_ROOT:-/c/dev/projects}"
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth
export EDITOR=vim

# Source local settings FIRST (for secrets, machine-specific configs, and SSH_KEYS)
if [ -f "$HOME/.bashrc.local" ]; then
    source "$HOME/.bashrc.local"
fi

# Load saved agent info if exists
if [ -f ~/.ssh/agent_info ]; then
    source ~/.ssh/agent_info
fi

# Print summary of currently loaded SSH keys
print_ssh_status() {
    echo "🤖 SSH Agent (PID: $SSH_AGENT_PID)"
    local loaded_keys
    loaded_keys=$(ssh-add -l 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$loaded_keys" ]; then
        echo "🔑 Loaded keys:"
        echo "$loaded_keys" | sed 's/^/   ✓ /'
    else
        echo "🔑 No SSH keys loaded"
    fi
}

# Add SSH keys defined in SSH_KEYS array or fall back to defaults
add_ssh_keys() {
    if ssh-add -l > /dev/null 2>&1; then
        return 0
    fi
    
    echo "🔑 Adding SSH keys..."
    if [ -n "${SSH_KEYS+x}" ] && [ ${#SSH_KEYS[@]} -gt 0 ]; then
        for key in "${SSH_KEYS[@]}"; do
            if [ -f "$key" ]; then
                ssh-add "$key" 2>/dev/null && echo "  ✓ Added $key" || echo "  ✗ Failed to add $key"
            else
                echo "  ⚠️ Key file not found: $key"
            fi
        done
    else
        # Default key fallback if SSH_KEYS array is not set
        if [ -f "$HOME/.ssh/id_ed25519" ]; then
            ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null && echo "  ✓ Added id_ed25519"
        fi
    fi
}

# SSH Agent setup - ensures only ONE agent process runs across terminal sessions
start_ssh_agent() {
    local is_new_agent=false

    # Check if existing agent PID is running
    if [ -n "$SSH_AGENT_PID" ]; then
        if kill -0 "$SSH_AGENT_PID" 2>/dev/null || ps -p "$SSH_AGENT_PID" > /dev/null 2>&1; then
            print_ssh_status
            return 0
        fi
    fi
    
    # Check if socket exists and agent responds
    if [ -S "$SSH_AUTH_SOCK" ] 2>/dev/null; then
        if ssh-add -l > /dev/null 2>&1; then
            print_ssh_status
            return 0
        fi
        # Remove stale socket
        rm -f "$SSH_AUTH_SOCK" 2>/dev/null
    fi
    
    # Start a single new SSH agent instance
    echo "🚀 Starting new SSH Agent..."
    eval $(ssh-agent -s) > /dev/null
    
    # Persist agent environment variables for future shell instances
    mkdir -p ~/.ssh
    echo "export SSH_AUTH_SOCK=\"$SSH_AUTH_SOCK\"" > ~/.ssh/agent_info
    echo "export SSH_AGENT_PID=\"$SSH_AGENT_PID\"" >> ~/.ssh/agent_info
    
    add_ssh_keys
    print_ssh_status
}

# Start or reconnect to existing agent
start_ssh_agent