# Custom shell functions

# Show current git user
gitwho() {
    echo "Git user configuration:"
    echo "  Name:  $(git config user.name 2>/dev/null || echo 'Not set')"
    echo "  Email: $(git config user.email 2>/dev/null || echo 'Not set')"
    echo ""
    echo "Configuration sources:"
    git config --list --show-origin | grep user | sed 's/^/  /'
}

# Dynamic project navigation - quickly jump to configured project directories
proj() {
    if [ -z "$PROJECTS_ROOT" ]; then
        echo "❌ Error: \$PROJECTS_ROOT is not set. Please define it in ~/.bashrc.local"
        return 1
    fi

    # Helper to display available projects
    _proj_usage() {
        echo "Usage: proj <project_alias>"
        echo ""
        echo "Available projects in \$PROJECTS_ROOT ($PROJECTS_ROOT):"
        
        # Get all keys from associative array
        local keys=("${!PROJECT_PATHS[@]}")
        
        if [ ${#keys[@]} -gt 0 ]; then
            for key in "${keys[@]}"; do
                printf "  %-15s -> %s\n" "$key" "${PROJECT_PATHS[$key]}"
            done
        else
            echo "  (No projects configured in PROJECT_PATHS array in ~/.bashrc.local)"
        fi
    }

    if [ -z "$1" ]; then
        _proj_usage
        return 1
    fi

    local alias_name="$1"
    local relative_path="${PROJECT_PATHS[$alias_name]}"

    if [ -n "$relative_path" ]; then
        local target_dir="$PROJECTS_ROOT/$relative_path"
        if [ -d "$target_dir" ]; then
            cd "$target_dir" || return
            echo "🔀 Changed to: $(pwd)"
        else
            echo "❌ Error: Directory $target_dir does not exist."
            return 1
        fi
    else
        echo "❌ Error: Unknown project alias '$alias_name'"
        echo ""
        _proj_usage
        return 1
    fi
}

# Create and cd into a new directory
mkcd() {
    if [ -z "$1" ]; then
        echo "Usage: mkcd <directory_name>"
        return 1
    fi
    mkdir -p "$1" && cd "$1" || return
    echo "📁 Created and changed to: $(pwd)"
}

# Find file by name in current directory
findf() {
    if [ -z "$1" ]; then
        echo "Usage: findf <filename_pattern>"
        return 1
    fi
    find . -name "*$1*" -type f | grep --color=auto "$1"
}

# Find directory by name
findd() {
    if [ -z "$1" ]; then
        echo "Usage: findd <dirname_pattern>"
        return 1
    fi
    find . -name "*$1*" -type d | grep --color=auto "$1"
}