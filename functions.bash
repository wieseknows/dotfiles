# Custom shell functions

# Show current git user
gitwho() {
    echo "Git user configuration:"
    echo "  Name:  $(git config user.name 2>/dev/null || echo 'Not set')"
    echo "  Email: $(git config user.email 2>/dev/null || echo 'Not set')"
    echo ""
    echo "Configuration sources:"
    git config --list --show-origin 2>/dev/null | grep -E "user\.(name|email)" | sed 's/^/  /'
}

# Helper to display available projects for proj
_proj_usage() {
    echo "Usage: proj <project_alias>"
    echo ""
    echo "Available projects:"

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

# Dynamic project navigation - quickly jump to configured project directories
proj() {
    if [ -z "${1:-}" ]; then
        _proj_usage
        return 1
    fi

    local alias_name="$1"
    local project_path="${PROJECT_PATHS[$alias_name]:-}"

    if [ -z "$project_path" ]; then
        echo "❌ Error: Unknown project alias '$alias_name'"
        echo ""
        _proj_usage
        return 1
    fi

    local target_dir
    if [[ "$project_path" == /* || "$project_path" =~ ^[A-Za-z]:[/\\] ]]; then
        target_dir="$project_path"
    elif [[ "$project_path" == "~" || "$project_path" == "~/"* ]]; then
        target_dir="${project_path/#\~/$HOME}"
    else
        if [ -z "${PROJECTS_ROOT:-}" ]; then
            echo "❌ Error: \$PROJECTS_ROOT is not set. Please define it in ~/.bashrc.local"
            return 1
        fi
        target_dir="${PROJECTS_ROOT%/}/$project_path"
    fi

    if [ -d "$target_dir" ]; then
        cd "$target_dir" || return
        echo "🔀 Changed to: $(pwd)"
    else
        echo "❌ Error: Directory $target_dir does not exist."
        return 1
    fi
}

# Create and cd into a new directory
mkcd() {
    if [ -z "${1:-}" ]; then
        echo "Usage: mkcd <directory_name>"
        return 1
    fi
    mkdir -p "$1" && cd "$1" || return
    echo "📁 Created and changed to: $(pwd)"
}

# Find file by name in current directory (case-insensitive, handles special characters)
findf() {
    if [ -z "${1:-}" ]; then
        echo "Usage: findf <filename_pattern> [search_path]"
        return 1
    fi
    find "${2:-.}" -type f -iname "*$1*"
}

# Find directory by name (case-insensitive, handles special characters)
findd() {
    if [ -z "${1:-}" ]; then
        echo "Usage: findd <dirname_pattern> [search_path]"
        return 1
    fi
    find "${2:-.}" -type d -iname "*$1*"
}
