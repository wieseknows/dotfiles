#!/usr/bin/env bash
# Dotfiles installation script (idempotent)
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
RECONFIGURE=0
SKIP_AGENTS=0
ONLY_AGENTS=0
DRY_RUN=0
CLI_AGENTS=0
CLI_AGENT_REPO=""
CLI_AGENT_DIR=""
CLI_AGENT_PROJECTS=()
CLI_AGENT_PROJECTS_SET=0

INSTALL_CONF="$HOME/.config/dotfiles/install.conf"
DEFAULT_AGENT_REPO="https://github.com/wieseknows/my-agent-config.git"
DEFAULT_AGENT_DIR="~/.local/share/my-agent-config"

SUMMARY_INSTALLED=()
SUMMARY_UPDATED=()
SUMMARY_SKIPPED=()
SUMMARY_BACKED_UP=()
SUMMARY_WARNINGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --reconfigure|-r)
            RECONFIGURE=1
            shift
            ;;
        --agents)
            CLI_AGENTS=1
            shift
            ;;
        --agent-project)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "[ERROR] --agent-project requires a path argument" >&2
                exit 1
            fi
            CLI_AGENT_PROJECTS+=("$2")
            CLI_AGENT_PROJECTS_SET=1
            shift 2
            ;;
        --agent-repo)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "[ERROR] --agent-repo requires a URL argument" >&2
                exit 1
            fi
            CLI_AGENT_REPO="$2"
            shift 2
            ;;
        --agent-dir)
            if [ $# -lt 2 ] || [ -z "${2:-}" ]; then
                echo "[ERROR] --agent-dir requires a path argument" >&2
                exit 1
            fi
            CLI_AGENT_DIR="$2"
            shift 2
            ;;
        --skip-agents)
            SKIP_AGENTS=1
            shift
            ;;
        --only-agents)
            ONLY_AGENTS=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  -r, --reconfigure       Interactively reconfigure ~/.bashrc.local (preserves existing values as defaults)
  --agents                Enable Antigravity agent config installation/sync (persisted in install.conf)
  --agent-project <path>  Absolute path to project for .agents/ rules (repeatable, persisted in install.conf)
  --agent-repo <url>      Override my-agent-config repository URL (persisted in install.conf)
  --agent-dir <path>      Override my-agent-config local clone directory (persisted in install.conf)
  --skip-agents           Skip Antigravity agent config installation/sync for this run
  --only-agents           Only install/sync Antigravity agent config (skip shell/git/ssh steps)
  --dry-run               Show planned actions without modifying files (forwarded to my-agent-config)
  -h, --help              Show this help message

Configuration:
  Shell runtime settings: ~/.bashrc.local
  Installer preferences:  ~/.config/dotfiles/install.conf (git-config format)

Environment variables:
  NONINTERACTIVE=1    Skip interactive prompts (uses existing/env defaults)
  INSTALL_GITREVIEW=0 Skip wieseknows.GitReview .NET tool installation
  UPDATE_GITREVIEW=1  Update wieseknows.GitReview if already installed
  PAUSE_ON_EXIT=1     Wait for Enter before exiting in interactive mode
EOF
            exit 0
            ;;
        *)
            echo "[ERROR] Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

echo "=================================================="
echo "🚀 Installing dotfiles from: $DOTFILES_DIR"
echo "📍 Target Home: $HOME"
[ "$DRY_RUN" = "1" ] && echo "🧪 Dry-run mode enabled (no files will be modified)"
echo "=================================================="

# ----------------------------------------------------
# Helpers
# ----------------------------------------------------
backup_if_exists() {
    local target="$1"
    if [ -f "$target" ] && [ ! -L "$target" ]; then
        local backup="${target}.bak.${TIMESTAMP}"
        if [ ! -f "$backup" ]; then
            if [ "$DRY_RUN" = "1" ]; then
                echo "📦 [dry-run] Would back up $target -> $backup"
            else
                cp "$target" "$backup"
                echo "📦 Backed up $target -> $backup"
            fi
            SUMMARY_BACKED_UP+=("$target -> $backup")
        fi
    fi
}

# Atomically replace target only when content differs; returns 0 if updated, 1 if unchanged
write_file_if_changed() {
    local target="$1"
    local tmp_file="$2"
    if [ -f "$target" ] && cmp -s "$tmp_file" "$target"; then
        rm -f "$tmp_file"
        return 1
    fi
    backup_if_exists "$target"
    if [ "$DRY_RUN" = "1" ]; then
        rm -f "$tmp_file"
        return 0
    fi
    mv "$tmp_file" "$target"
    return 0
}

is_interactive() {
    [ -t 0 ] && [ -z "${NONINTERACTIVE:-}" ] && [ -z "${CI:-}" ]
}

escape_bash_dq() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Insert or replace a marker-delimited block in target; returns 0 if updated, 1 if unchanged
upsert_marked_block() {
    local target="$1" start_marker="$2" end_marker="$3" block="$4"
    local tmp_file
    tmp_file="$(mktemp)"
    if [ -f "$target" ] && grep -Fq "$start_marker" "$target" && grep -Fq "$end_marker" "$target"; then
        awk -v start="$start_marker" -v end="$end_marker" -v block="$block" '
            $0 == start { print block; skip = 1; next }
            $0 == end && skip { skip = 0; next }
            !skip { print }
        ' "$target" > "$tmp_file"
    else
        if [ -f "$target" ]; then
            cat "$target" > "$tmp_file"
            [ -s "$tmp_file" ] && [ -n "$(tail -c 1 "$tmp_file")" ] && echo "" >> "$tmp_file"
            echo "" >> "$tmp_file"
        fi
        printf '%s\n' "$block" >> "$tmp_file"
    fi
    write_file_if_changed "$target" "$tmp_file"
}

detect_default_ssh_keys() {
    local candidate
    for candidate in "$HOME/.ssh/id_ed25519" "$HOME/.ssh/id_rsa"; do
        [ -f "$candidate" ] && printf '%s\n' "$candidate"
    done
}

prompt_with_default() {
    local prompt_text="$1" default_val="$2" reply=""
    if [ -n "$default_val" ]; then
        read -rp "$prompt_text [$default_val]: " reply
        printf '%s' "${reply:-$default_val}"
    else
        read -rp "$prompt_text: " reply
        printf '%s' "$reply"
    fi
}

prompt_required() {
    local prompt_text="$1" val="$2"
    [ -n "$val" ] && val="$(prompt_with_default "$prompt_text" "$val")"
    while [ -z "$val" ]; do
        val="$(prompt_with_default "$prompt_text" "")"
        [ -z "$val" ] && echo "  ⚠️ $prompt_text is required." >&2
    done
    printf '%s' "$val"
}

prompt_secret() {
    local label="$1" current="${2:-}" reply=""
    if [ -n "$current" ]; then
        read -rsp "$label (already set, Enter to keep, or type new): " reply
        echo "" >&2
        printf '%s' "${reply:-$current}"
    else
        read -rsp "$label (hidden, Enter to skip): " reply
        echo "" >&2
        printf '%s' "$reply"
    fi
}

generate_bashrc_local() {
    local git_name="${GIT_USER_NAME:-$(git config --global user.name 2>/dev/null || true)}"
    local git_email="${GIT_USER_EMAIL:-$(git config --global user.email 2>/dev/null || true)}"
    local azure_key="${AZURE_SSH_KEY:-}"
    local provider="${GIT_REVIEW_PROVIDER:-openrouter}"
    local openrouter_model="${OPENROUTER_MODEL:-poolside/laguna-s-2.1:free}"
    local openrouter_key="${OPENROUTER_API_KEY:-}"
    local gemini_key="${GEMINI_API_KEY:-}"
    local deepseek_key="${DEEPSEEK_API_KEY:-}"
    local projects_root="${PROJECTS_ROOT:-/c/dev/projects}"

    local ssh_keys=() detected_key
    if [ -n "${SSH_KEYS+x}" ] && [ ${#SSH_KEYS[@]} -gt 0 ]; then
        ssh_keys=("${SSH_KEYS[@]}")
    else
        while IFS= read -r detected_key; do
            [ -n "$detected_key" ] && ssh_keys+=("$detected_key")
        done < <(detect_default_ssh_keys)
    fi

    if is_interactive; then
        echo ""
        echo "🛠️  Interactive setup for local machine settings (~/.bashrc.local)"
        echo "   Press Enter to accept defaults in [brackets] or leave optional fields blank."
        echo ""

        git_name="$(prompt_required "Git User Name" "$git_name")"
        git_email="$(prompt_required "Git Email" "$git_email")"

        local default_ssh_str="" ssh_input=""
        [ ${#ssh_keys[@]} -gt 0 ] && default_ssh_str="$(IFS=,; echo "${ssh_keys[*]}")"
        ssh_input="$(prompt_with_default "SSH key paths (comma-separated, or 'none')" "$default_ssh_str")"
        ssh_keys=()
        if [ -n "$ssh_input" ] && [ "$ssh_input" != "none" ]; then
            local raw_item
            IFS=',' read -ra raw_items <<< "$ssh_input"
            for raw_item in "${raw_items[@]}"; do
                raw_item="$(printf '%s' "$raw_item" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
                [ -n "$raw_item" ] && ssh_keys+=("$raw_item")
            done
        fi

        azure_key="$(prompt_with_default "Azure DevOps SSH key (optional)" "$azure_key")"

        local configure_ai=""
        read -rp "Configure AI / GitReview API keys now? [y/N]: " configure_ai
        if [[ "$configure_ai" =~ ^[Yy]$ ]]; then
            provider="$(prompt_with_default "Default AI provider (openrouter/gemini/deepseek)" "$provider")"
            openrouter_model="$(prompt_with_default "OpenRouter model" "$openrouter_model")"
            openrouter_key="$(prompt_secret "OpenRouter API Key" "$openrouter_key")"
            gemini_key="$(prompt_secret "Gemini API Key" "$gemini_key")"
            deepseek_key="$(prompt_secret "DeepSeek API Key" "$deepseek_key")"
        fi
    fi

    local tmp_local
    tmp_local="$(mktemp)"
    {
        echo "# =============================================================================="
        echo "# LOCAL CONFIGURATION (Generated by dotfiles install.sh)"
        echo "# =============================================================================="
        echo ""
        echo "# 1. Git Identity"
        [ -n "$git_name" ] && echo "export GIT_USER_NAME=\"$(escape_bash_dq "$git_name")\""
        [ -n "$git_email" ] && echo "export GIT_USER_EMAIL=\"$(escape_bash_dq "$git_email")\""
        echo ""
        echo "# 2. SSH Keys"
        echo "SSH_KEYS=("
        for k in ${ssh_keys[@]+"${ssh_keys[@]}"}; do
            [ -n "$k" ] && echo "    \"$(escape_bash_dq "$k")\""
        done
        echo ")"
        [ -n "$azure_key" ] && echo "export AZURE_SSH_KEY=\"$(escape_bash_dq "$azure_key")\""
        echo ""
        echo "# 3. API Keys & AI Providers"
        echo "export GIT_REVIEW_PROVIDER=\"$(escape_bash_dq "$provider")\""
        echo "export OPENROUTER_MODEL=\"$(escape_bash_dq "$openrouter_model")\""
        [ -n "$openrouter_key" ] && echo "export OPENROUTER_API_KEY=\"$(escape_bash_dq "$openrouter_key")\""
        [ -n "$gemini_key" ] && echo "export GEMINI_API_KEY=\"$(escape_bash_dq "$gemini_key")\""
        [ -n "$deepseek_key" ] && echo "export DEEPSEEK_API_KEY=\"$(escape_bash_dq "$deepseek_key")\""
        echo ""
        echo "# 4. Project Navigation (\`proj <alias>\`)"
        echo "export PROJECTS_ROOT=\"$(escape_bash_dq "$projects_root")\""
        echo "declare -g -A PROJECT_PATHS=("
        if [ -n "${PROJECT_PATHS+x}" ] && [ ${#PROJECT_PATHS[@]} -gt 0 ]; then
            local proj_alias
            for proj_alias in "${!PROJECT_PATHS[@]}"; do
                echo "    [\"$(escape_bash_dq "$proj_alias")\"]=\"$(escape_bash_dq "${PROJECT_PATHS[$proj_alias]}")\""
            done
        else
            echo "    # [\"app\"]=\"/c/dev/projects/my-app/web\""
        fi
        echo ")"
    } > "$tmp_local"

    local existed=0
    [ -f "$HOME/.bashrc.local" ] && existed=1
    if write_file_if_changed "$HOME/.bashrc.local" "$tmp_local"; then
        echo "✅ Updated $HOME/.bashrc.local"
        if [ "$existed" -eq 1 ]; then
            SUMMARY_UPDATED+=("$HOME/.bashrc.local")
        else
            SUMMARY_INSTALLED+=("$HOME/.bashrc.local")
        fi
    else
        echo "ℹ️  $HOME/.bashrc.local unchanged"
        SUMMARY_SKIPPED+=("$HOME/.bashrc.local (unchanged)")
    fi
}

resolve_project_path() {
    local raw_path="$1"
    if [[ "$raw_path" == /* || "$raw_path" =~ ^[A-Za-z]:[/\\] ]]; then
        printf '%s\n' "$raw_path"
    elif [[ "$raw_path" == "~" || "$raw_path" == "~/"* ]]; then
        printf '%s\n' "${raw_path/#\~/$HOME}"
    elif [ -n "${PROJECTS_ROOT:-}" ]; then
        printf '%s\n' "${PROJECTS_ROOT%/}/$raw_path"
    else
        return 1
    fi
}

expand_tilde() {
    local p="$1"
    case "$p" in
        "~") printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s\n' "$HOME/${p#~/}" ;;
        *) printf '%s\n' "$p" ;;
    esac
}

conf_has_agents_section() {
    [ -f "$INSTALL_CONF" ] && git config --file "$INSTALL_CONF" --get-regexp '^agents\.' >/dev/null 2>&1
}

write_agents_conf() {
    local enabled="$1" repo="$2" dir="$3"
    shift 3
    local projects=("$@")

    if [ "$DRY_RUN" = "1" ]; then
        echo "ℹ️  [dry-run] Would update $INSTALL_CONF"
        return 0
    fi

    mkdir -p "$(dirname "$INSTALL_CONF")"
    git config --file "$INSTALL_CONF" agents.enabled "$enabled"
    git config --file "$INSTALL_CONF" agents.repo "$repo"
    git config --file "$INSTALL_CONF" agents.dir "$dir"
    git config --file "$INSTALL_CONF" --unset-all agents.project 2>/dev/null || true
    local proj
    for proj in ${projects[@]+"${projects[@]}"}; do
        [ -n "$proj" ] && git config --file "$INSTALL_CONF" --add agents.project "$proj"
    done
}

# One-time migration from legacy ~/.bashrc.local agent variables into install.conf.
# Leaves ~/.bashrc.local untouched so no lines are deleted without an explicit backup.
migrate_legacy_agent_config() {
    conf_has_agents_section && return 0
    [ -f "$HOME/.bashrc.local" ] || return 0
    grep -qE '^(export[[:space:]]+)?(INSTALL_AGENT_CONFIG|AGENT_CONFIG_)' "$HOME/.bashrc.local" || return 0

    local mig_enabled="${INSTALL_AGENT_CONFIG:-false}"
    local mig_repo="${AGENT_CONFIG_REPO:-$DEFAULT_AGENT_REPO}"
    local mig_dir="${AGENT_CONFIG_DIR:-$DEFAULT_AGENT_DIR}"
    local mig_projects=()
    local alias_name raw_proj resolved_proj

    for alias_name in ${AGENT_CONFIG_PROJECTS[@]+"${AGENT_CONFIG_PROJECTS[@]}"}; do
        [ -n "$alias_name" ] || continue
        raw_proj="${PROJECT_PATHS[$alias_name]:-}"
        if [ -n "$raw_proj" ]; then
            if resolved_proj="$(resolve_project_path "$raw_proj")"; then
                mig_projects+=("$resolved_proj")
            else
                echo "⚠️ Cannot resolve legacy project alias '$alias_name': $raw_proj" >&2
                SUMMARY_WARNINGS+=("Unresolved legacy agent project alias: $alias_name")
            fi
        elif [[ "$alias_name" == /* || "$alias_name" == "~/"* || "$alias_name" =~ ^[A-Za-z]:[/\\] ]]; then
            mig_projects+=("$(expand_tilde "$alias_name")")
        else
            echo "⚠️ Unknown legacy AGENT_CONFIG_PROJECTS alias during migration: $alias_name" >&2
            SUMMARY_WARNINGS+=("Unknown legacy agent project alias: $alias_name")
        fi
    done

    echo "⚠️ Migrating legacy agent settings from ~/.bashrc.local to $INSTALL_CONF (legacy variables in ~/.bashrc.local are no longer read)" >&2
    SUMMARY_WARNINGS+=("Migrated legacy agent settings from ~/.bashrc.local to $INSTALL_CONF")
    write_agents_conf "$mig_enabled" "$mig_repo" "$mig_dir" ${mig_projects[@]+"${mig_projects[@]}"}
}

sync_agent_config() {
    migrate_legacy_agent_config

    local eff_enabled="false"
    local eff_repo="$DEFAULT_AGENT_REPO"
    local eff_dir="$DEFAULT_AGENT_DIR"
    local eff_projects=()

    if conf_has_agents_section; then
        local val
        val="$(git config --file "$INSTALL_CONF" --get agents.enabled 2>/dev/null || true)"
        [ -n "$val" ] && eff_enabled="$val"
        val="$(git config --file "$INSTALL_CONF" --get agents.repo 2>/dev/null || true)"
        [ -n "$val" ] && eff_repo="$val"
        val="$(git config --file "$INSTALL_CONF" --get agents.dir 2>/dev/null || true)"
        [ -n "$val" ] && eff_dir="$val"
        while IFS= read -r val; do
            [ -n "$val" ] && eff_projects+=("$val")
        done < <(git config --file "$INSTALL_CONF" --get-all agents.project 2>/dev/null || true)
    fi

    local cli_override=0
    if [ "$CLI_AGENTS" = "1" ]; then
        eff_enabled="true"
        cli_override=1
    fi
    if [ -n "$CLI_AGENT_REPO" ]; then
        eff_repo="$CLI_AGENT_REPO"
        cli_override=1
    fi
    if [ -n "$CLI_AGENT_DIR" ]; then
        eff_dir="$CLI_AGENT_DIR"
        cli_override=1
    fi
    if [ "$CLI_AGENT_PROJECTS_SET" = "1" ]; then
        eff_projects=("${CLI_AGENT_PROJECTS[@]}")
        cli_override=1
    fi

    if [ "$cli_override" = "1" ]; then
        write_agents_conf "$eff_enabled" "$eff_repo" "$eff_dir" ${eff_projects[@]+"${eff_projects[@]}"}
    fi

    if [ "$SKIP_AGENTS" = "1" ]; then
        echo "ℹ️  Skipping Antigravity agent config (--skip-agents)"
        SUMMARY_SKIPPED+=("Agent config (--skip-agents)")
        return 0
    fi

    if [ "$eff_enabled" != "true" ] && [ "$ONLY_AGENTS" != "1" ]; then
        echo "ℹ️  Skipping Antigravity agent config (agents.enabled=$eff_enabled)"
        SUMMARY_SKIPPED+=("Agent config (disabled)")
        return 0
    fi

    local repo="$eff_repo"
    local dir
    dir="$(expand_tilde "$eff_dir")"
    echo "🤖 Syncing Antigravity agent config ($dir)..."

    if [ -d "$dir/.git" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            echo "ℹ️  [dry-run] Would pull updates in $dir"
        elif ! git -C "$dir" pull --ff-only; then
            echo "⚠️ Failed to update $dir (continuing dotfiles setup)" >&2
            SUMMARY_WARNINGS+=("Agent config git pull failed in $dir")
            return 0
        fi
    else
        if [ "$DRY_RUN" = "1" ]; then
            echo "ℹ️  [dry-run] Would shallow-clone $repo -> $dir"
            SUMMARY_SKIPPED+=("Agent config ([dry-run] not cloned yet)")
            return 0
        fi
        mkdir -p "$(dirname "$dir")"
        if ! git clone --depth 1 "$repo" "$dir"; then
            echo "⚠️ Failed to clone $repo (continuing dotfiles setup)" >&2
            SUMMARY_WARNINGS+=("Agent config git clone failed: $repo")
            return 0
        fi
    fi

    local agent_installer="$dir/install.sh"
    if [ ! -f "$agent_installer" ]; then
        echo "⚠️ Agent installer not found: $agent_installer" >&2
        SUMMARY_WARNINGS+=("Missing $agent_installer")
        return 0
    fi

    local args=("--global")
    [ "$DRY_RUN" = "1" ] && args+=("--dry-run")

    local raw_proj resolved_proj
    for raw_proj in ${eff_projects[@]+"${eff_projects[@]}"}; do
        [ -n "$raw_proj" ] || continue
        resolved_proj="$(expand_tilde "$raw_proj")"
        if [ ! -d "$resolved_proj" ]; then
            echo "⚠️ Agent project directory does not exist: $resolved_proj" >&2
            SUMMARY_WARNINGS+=("Missing agent project directory: $resolved_proj")
            continue
        fi
        args+=("--project" "$resolved_proj")
    done

    if bash "$agent_installer" "${args[@]}"; then
        SUMMARY_UPDATED+=("Agent config ($dir)")
    else
        echo "⚠️ Agent config installer exited with an error (continuing dotfiles setup)" >&2
        SUMMARY_WARNINGS+=("Agent config installer failed ($agent_installer)")
    fi
}

if [ "$ONLY_AGENTS" = "1" ]; then
    if [ -f "$HOME/.bashrc.local" ]; then
        # shellcheck source=/dev/null
        source "$HOME/.bashrc.local"
    fi
    sync_agent_config
else
    # ----------------------------------------------------
    # 1. Idempotent dotfiles loader in ~/.bashrc
    # ----------------------------------------------------
    LOADER_START="# >>> dotfiles loader >>>"
    LOADER_END="# <<< dotfiles loader <<<"
    LEGACY_MARKER="# AUTO-GENERATED LOADER FOR DOTFILES"
    BASHRC_TARGET="$HOME/.bashrc"

    if [ -f "$BASHRC_TARGET" ] && grep -Fq "$LEGACY_MARKER" "$BASHRC_TARGET"; then
        tmp_legacy="$(mktemp)"
        awk -v marker="$LEGACY_MARKER" -v start="$LOADER_START" '
            $0 == marker { in_legacy = 1; next }
            in_legacy && $0 == start { in_legacy = 0; print; next }
            in_legacy && /^fi$/ { seen_fi = 1; next }
            in_legacy && seen_fi && /^# =+$/ { in_legacy = 0; seen_fi = 0; next }
            !in_legacy { print }
        ' "$BASHRC_TARGET" > "$tmp_legacy"
        if write_file_if_changed "$BASHRC_TARGET" "$tmp_legacy"; then
            echo "🧹 Removed legacy dotfiles loader from $BASHRC_TARGET"
        fi
    fi

    loader_block="$(cat << EOF
$LOADER_START
# Generated by dotfiles install.sh
export DOTFILES_DIR="$DOTFILES_DIR"
if [ -f "\$DOTFILES_DIR/.bashrc" ]; then
    source "\$DOTFILES_DIR/.bashrc"
fi
$LOADER_END
EOF
)"

    bashrc_existed=0
    [ -f "$BASHRC_TARGET" ] && bashrc_existed=1
    if upsert_marked_block "$BASHRC_TARGET" "$LOADER_START" "$LOADER_END" "$loader_block"; then
        echo "✅ Dotfiles loader updated in $BASHRC_TARGET"
        if [ "$bashrc_existed" -eq 1 ]; then
            SUMMARY_UPDATED+=("$BASHRC_TARGET")
        else
            SUMMARY_INSTALLED+=("$BASHRC_TARGET")
        fi
    else
        echo "ℹ️  Dotfiles loader already up to date in $BASHRC_TARGET"
        SUMMARY_SKIPPED+=("$BASHRC_TARGET (unchanged)")
    fi

    # ----------------------------------------------------
    # 2. Main Git configuration include
    # ----------------------------------------------------
    DOTFILES_GITCONFIG="$DOTFILES_DIR/.gitconfig"
    DOTFILES_GITCONFIG_WIN=""
    if win_dir="$(cd "$DOTFILES_DIR" && pwd -W 2>/dev/null || true)" && [ -n "$win_dir" ]; then
        DOTFILES_GITCONFIG_WIN="$win_dir/.gitconfig"
    fi

    if git config --global --get-all include.path 2>/dev/null | grep -F -e "$DOTFILES_GITCONFIG" ${DOTFILES_GITCONFIG_WIN:+-e "$DOTFILES_GITCONFIG_WIN"} -q; then
        echo "ℹ️  Git global include already configured: $DOTFILES_GITCONFIG"
        SUMMARY_SKIPPED+=("Git global include (unchanged)")
    else
        echo "🔧 Configuring Git global include..."
        if [ "$DRY_RUN" = "1" ]; then
            echo "ℹ️  [dry-run] Would run: git config --global --add include.path $DOTFILES_GITCONFIG"
        else
            git config --global --add include.path "$DOTFILES_GITCONFIG"
            echo "✅ Git configured to include $DOTFILES_GITCONFIG"
        fi
        SUMMARY_UPDATED+=("Git global include ($DOTFILES_GITCONFIG)")
    fi

    # ----------------------------------------------------
    # 3. Manage local configuration (~/.bashrc.local)
    # ----------------------------------------------------
    if [ -f "$HOME/.bashrc.local" ]; then
        # Load existing settings first so --reconfigure preserves them as defaults
        # shellcheck source=/dev/null
        source "$HOME/.bashrc.local"
    fi

    if [ ! -f "$HOME/.bashrc.local" ] || [ "$RECONFIGURE" = "1" ]; then
        generate_bashrc_local
        if [ -f "$HOME/.bashrc.local" ] && [ "$DRY_RUN" = "0" ]; then
            # shellcheck source=/dev/null
            source "$HOME/.bashrc.local"
        fi
    else
        echo "ℹ️  $HOME/.bashrc.local exists (run with --reconfigure to update interactively)"
        SUMMARY_SKIPPED+=("$HOME/.bashrc.local (exists)")
    fi

    # ----------------------------------------------------
    # 4. Configure local Git settings (~/.gitconfig.local)
    # ----------------------------------------------------
    GITCONFIG_LOCAL="$HOME/.gitconfig.local"
    if [ ! -f "$GITCONFIG_LOCAL" ]; then
        if [ "$DRY_RUN" = "1" ]; then
            echo "ℹ️  [dry-run] Would create $GITCONFIG_LOCAL"
        else
            touch "$GITCONFIG_LOCAL"
            echo "✅ Created $GITCONFIG_LOCAL"
        fi
        SUMMARY_INSTALLED+=("$GITCONFIG_LOCAL")
    fi

    sync_git_identity_key() {
        local key="$1" expected="$2"
        [ -n "$expected" ] || return 1
        local current
        current="$(git config --file "$GITCONFIG_LOCAL" --get "$key" 2>/dev/null || true)"
        if [ "$current" != "$expected" ]; then
            if [ "$DRY_RUN" = "0" ]; then
                git config --file "$GITCONFIG_LOCAL" "$key" "$expected"
            fi
            return 0
        fi
        return 1
    }

    updated_git=0
    sync_git_identity_key "user.name" "${GIT_USER_NAME:-}" && updated_git=1 || true
    sync_git_identity_key "user.email" "${GIT_USER_EMAIL:-}" && updated_git=1 || true
    if [ "$updated_git" = "1" ]; then
        echo "✅ Git identity synced in ~/.gitconfig.local: ${GIT_USER_NAME:-} <${GIT_USER_EMAIL:-}>"
        SUMMARY_UPDATED+=("$GITCONFIG_LOCAL")
    else
        echo "ℹ️  ~/.gitconfig.local identity up to date"
        SUMMARY_SKIPPED+=("$GITCONFIG_LOCAL (unchanged)")
    fi

    # ----------------------------------------------------
    # 5. Validate SSH keys & detect PuTTY (.ppk) issues
    # ----------------------------------------------------
    validate_ssh_keys() {
        echo "🔑 Validating SSH keys configuration..."
        if [ "$DRY_RUN" = "0" ]; then
            mkdir -p "$HOME/.ssh"
            chmod 700 "$HOME/.ssh" 2>/dev/null || true
        fi

        if [ -z "${SSH_KEYS+x}" ] || [ ${#SSH_KEYS[@]} -eq 0 ]; then
            echo "  ℹ️  No SSH_KEYS defined; ~/.bashrc will auto-detect OpenSSH keys in ~/.ssh"
            return 0
        fi

        local key fp
        for key in "${SSH_KEYS[@]}"; do
            if [ ! -f "$key" ]; then
                echo "  ⚠️ Key not found: $key"
                SUMMARY_WARNINGS+=("SSH key not found: $key")
                if [ -f "${key}.ppk" ]; then
                    echo "     💡 Found PuTTY key: ${key}.ppk (export as OpenSSH key in PuTTYgen)"
                fi
                continue
            fi
            if [[ "$key" == *.ppk ]]; then
                echo "  ⚠️ PuTTY format (.ppk): $key (export as OpenSSH key in PuTTYgen)"
                SUMMARY_WARNINGS+=("PuTTY .ppk key unsupported: $key")
                continue
            fi
            fp=$(ssh-keygen -lf "$key" 2>/dev/null | awk '{print $1, $2, $4}' || true)
            if [ -n "$fp" ]; then
                echo "  ✓ Valid OpenSSH key: $key ($fp)"
            else
                echo "  ⚠️ Key file exists but failed to read: $key"
                SUMMARY_WARNINGS+=("Unreadable SSH key: $key")
            fi
        done
    }

    validate_ssh_keys

    # ----------------------------------------------------
    # 6. Azure DevOps host entry in ~/.ssh/config (optional)
    # ----------------------------------------------------
    AZURE_START="# >>> dotfiles azure ssh >>>"
    AZURE_END="# <<< dotfiles azure ssh <<<"
    SSH_CONFIG="$HOME/.ssh/config"

    if [ -n "${AZURE_SSH_KEY:-}" ]; then
        azure_block="$(cat << EOF
$AZURE_START
Host ssh.dev.azure.com vs-ssh.visualstudio.com
    HostName ssh.dev.azure.com
    IdentityFile $AZURE_SSH_KEY
    IdentitiesOnly yes
    PubkeyAcceptedKeyTypes +ssh-rsa
$AZURE_END
EOF
)"
        if [ -f "$SSH_CONFIG" ] && grep -q "ssh.dev.azure.com" "$SSH_CONFIG" 2>/dev/null && ! grep -Fq "$AZURE_START" "$SSH_CONFIG"; then
            echo "ℹ️  Custom Azure DevOps entry already present in ~/.ssh/config"
            SUMMARY_SKIPPED+=("$SSH_CONFIG (custom Azure entry)")
        elif upsert_marked_block "$SSH_CONFIG" "$AZURE_START" "$AZURE_END" "$azure_block"; then
            [ "$DRY_RUN" = "0" ] && chmod 600 "$SSH_CONFIG" 2>/dev/null || true
            echo "✅ Configured Azure DevOps in ~/.ssh/config"
            SUMMARY_UPDATED+=("$SSH_CONFIG (Azure DevOps)")
        else
            echo "ℹ️  Azure DevOps entry already up to date in ~/.ssh/config"
            SUMMARY_SKIPPED+=("$SSH_CONFIG (unchanged)")
        fi
    else
        echo "ℹ️  No AZURE_SSH_KEY specified, skipping Azure DevOps SSH configuration"
    fi

    # ----------------------------------------------------
    # 7. Install GitReview dotnet tool (optional)
    # ----------------------------------------------------
    if [ "${INSTALL_GITREVIEW:-1}" = "1" ]; then
        echo "🔍 Checking for .NET CLI & GitReview tool..."
        if command -v dotnet >/dev/null 2>&1; then
            if dotnet tool list -g | grep -qi "wieseknows.gitreview"; then
                if [ "${UPDATE_GITREVIEW:-0}" = "1" ]; then
                    echo "🔄 Updating wieseknows.GitReview tool..."
                    if [ "$DRY_RUN" = "1" ]; then
                        echo "ℹ️  [dry-run] Would run: dotnet tool update -g wieseknows.GitReview"
                    elif dotnet tool update -g wieseknows.GitReview; then
                        SUMMARY_UPDATED+=("wieseknows.GitReview")
                    else
                        echo "⚠️ Failed to update GitReview tool"
                        SUMMARY_WARNINGS+=("Failed to update wieseknows.GitReview")
                    fi
                else
                    echo "ℹ️  wieseknows.GitReview already installed (set UPDATE_GITREVIEW=1 to update)"
                    SUMMARY_SKIPPED+=("wieseknows.GitReview (already installed)")
                fi
            else
                echo "📦 Installing wieseknows.GitReview tool..."
                if [ "$DRY_RUN" = "1" ]; then
                    echo "ℹ️  [dry-run] Would run: dotnet tool install -g wieseknows.GitReview"
                elif dotnet tool install -g wieseknows.GitReview; then
                    SUMMARY_INSTALLED+=("wieseknows.GitReview")
                else
                    echo "⚠️ Failed to install GitReview tool"
                    SUMMARY_WARNINGS+=("Failed to install wieseknows.GitReview")
                fi
            fi
        else
            echo "⚠️ .NET SDK (dotnet) not found in PATH. Skipping GitReview installation."
            SUMMARY_SKIPPED+=("wieseknows.GitReview (dotnet not found)")
        fi
    else
        echo "ℹ️  Skipping GitReview installation (INSTALL_GITREVIEW=0)"
        SUMMARY_SKIPPED+=("wieseknows.GitReview (INSTALL_GITREVIEW=0)")
    fi

    # ----------------------------------------------------
    # 8. Sync Antigravity agent config (optional)
    # ----------------------------------------------------
    sync_agent_config

    # ----------------------------------------------------
    # 9. Sanity checks (GIT_SSH hijack, duplicates, tracked secrets)
    # ----------------------------------------------------
    if [ -f "$BASHRC_TARGET" ]; then
        loader_count=$(grep -cE 'source[[:space:]]+.*DOTFILES_DIR/\.bashrc' "$BASHRC_TARGET" 2>/dev/null || true)
        if [ "${loader_count:-0}" -gt 1 ]; then
            echo "🚨 WARNING: Multiple dotfiles loaders ($loader_count) detected in $BASHRC_TARGET."
            SUMMARY_WARNINGS+=("Multiple dotfiles loaders in $BASHRC_TARGET")
        fi
    fi

    include_count=$(git config --global --get-all include.path 2>/dev/null | grep -F -c -e "$DOTFILES_GITCONFIG" ${DOTFILES_GITCONFIG_WIN:+-e "$DOTFILES_GITCONFIG_WIN"} || true)
    if [ "${include_count:-0}" -gt 1 ]; then
        echo "🚨 WARNING: Duplicate Git include.path entries ($include_count) for $DOTFILES_GITCONFIG in ~/.gitconfig."
        SUMMARY_WARNINGS+=("Duplicate Git include.path entries in ~/.gitconfig")
    fi

    if [ -n "${GIT_SSH:-}" ]; then
        echo "🚨 WARNING: GIT_SSH is set to: $GIT_SSH (TortoiseGitPlink overrides OpenSSH ssh-agent keys)."
        SUMMARY_WARNINGS+=("GIT_SSH override active: $GIT_SSH")
    fi
    SSH_CMD_GLOBAL="$(git config --global --get core.sshCommand 2>/dev/null || true)"
    if [ -n "$SSH_CMD_GLOBAL" ]; then
        echo "🚨 WARNING: git core.sshCommand (global) is set to: $SSH_CMD_GLOBAL"
        SUMMARY_WARNINGS+=("git core.sshCommand active: $SSH_CMD_GLOBAL")
    fi

    for f in .bashrc.local .gitconfig.local; do
        if [ -f "$DOTFILES_DIR/$f" ] && git -C "$DOTFILES_DIR" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            echo "🚨 WARNING: $f is committed to the dotfiles repo! Remove with: git -C \"$DOTFILES_DIR\" rm --cached $f"
            SUMMARY_WARNINGS+=("Tracked secret file in repo: $f")
        fi
    done
fi

echo ""
echo "=================================================="
echo "📋 Summary"
echo "=================================================="
echo "  Installed (${#SUMMARY_INSTALLED[@]}): ${SUMMARY_INSTALLED[*]:-none}"
echo "  Updated   (${#SUMMARY_UPDATED[@]}): ${SUMMARY_UPDATED[*]:-none}"
echo "  Skipped   (${#SUMMARY_SKIPPED[@]}): ${SUMMARY_SKIPPED[*]:-none}"
echo "  Backed up (${#SUMMARY_BACKED_UP[@]}): ${SUMMARY_BACKED_UP[*]:-none}"
if [ ${#SUMMARY_WARNINGS[@]} -gt 0 ]; then
    echo "  Warnings  (${#SUMMARY_WARNINGS[@]}):"
    for w in "${SUMMARY_WARNINGS[@]}"; do
        echo "    - $w"
    done
fi
echo "=================================================="
echo "✅ Dotfiles installation complete!"
echo "📌 Restart your terminal or run: source ~/.bashrc"
echo "=================================================="
echo ""

if [ "${PAUSE_ON_EXIT:-0}" = "1" ] && is_interactive; then
    read -rp "Press Enter to exit..." _
fi
