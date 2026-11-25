# Shell aliases
# General shortcuts for daily tasks

alias chistory='history'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias home='cd ~'
alias cls='clear'
alias c='clear'
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'

# Git shortcuts (additional to git aliases)
alias g='git'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'

# Directory navigation shortcuts
alias desk='cd ~/Desktop'
alias down='cd ~/Downloads'
alias docs='cd ~/Documents'

# Cross-platform development directory navigation
dev() {
    if [ -n "${DEV_DIR:-}" ] && [ -d "$DEV_DIR" ]; then
        cd "$DEV_DIR" || return
    elif [ -d "/c/dev" ]; then
        cd "/c/dev" || return
    elif [ -d "/mnt/c/dev" ]; then
        cd "/mnt/c/dev" || return
    elif [ -d "$HOME/dev" ]; then
        cd "$HOME/dev" || return
    else
        echo "❌ Development directory not found (/c/dev, /mnt/c/dev, or ~/dev)"
        return 1
    fi
}
