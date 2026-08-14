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

# Dynamic project navigation - quickly jump to project directories
proj() {
    local target_dir=""
    
    case "$1" in
        syn|syn_new)
            target_dir="$PROJECTS_ROOT/synthesis_newdesign/web"
            ;;
        syn_old)
            target_dir="$PROJECTS_ROOT/synthesis_old/web"
            ;;
        syn_pub_uat)
            target_dir="$PROJECTS_ROOT/synthesis_publish_uat/web"
            ;;
        syn_pub_live)
            target_dir="$PROJECTS_ROOT/synthesis_publish_live/web"
            ;;
        oms)
            target_dir="$PROJECTS_ROOT/oms/web"
            ;;
        pin|dop)
            target_dir="$PROJECTS_ROOT/pinergy/web"
            ;;
        *)
            echo "Usage: proj {syn|syn_new|syn_old|syn_pub_uat|syn_pub_live|oms|pin|dop}"
            echo ""
            echo "Examples:"
            echo "  proj syn        - Go to synthesis_newdesign/web"
            echo "  proj syn_old    - Go to synthesis_old/web"
            echo "  proj oms        - Go to oms/web"
            echo "  proj pin        - Go to pinergy/web (same as dop)"
            return 1
            ;;
    esac
    
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