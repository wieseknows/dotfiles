#!/usr/bin/env bash
# Smoke tests for dotfiles/install.sh in an isolated temporary HOME
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

norm_path() {
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$1"
    else
        printf '%s\n' "$1"
    fi
}

TEST_HOME="$TMP_ROOT/home"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
export NONINTERACTIVE=1
export INSTALL_GITREVIEW=0
export GIT_USER_NAME="Test User"
export GIT_USER_EMAIL="test@example.com"

# 1. Fresh install (agents disabled by default, no agent vars in ~/.bashrc.local)
"$INSTALLER" >/dev/null
[ -f "$TEST_HOME/.bashrc" ] || { echo "[FAIL] Missing ~/.bashrc" >&2; exit 1; }
[ -f "$TEST_HOME/.bashrc.local" ] || { echo "[FAIL] Missing ~/.bashrc.local" >&2; exit 1; }
[ -f "$TEST_HOME/.gitconfig.local" ] || { echo "[FAIL] Missing ~/.gitconfig.local" >&2; exit 1; }
if grep -qE 'INSTALL_AGENT_CONFIG|AGENT_CONFIG_' "$TEST_HOME/.bashrc.local"; then
    echo "[FAIL] Unexpected agent variables in ~/.bashrc.local" >&2
    exit 1
fi
[ ! -f "$TEST_HOME/.config/dotfiles/install.conf" ] || { echo "[FAIL] Unexpected install.conf on default install" >&2; exit 1; }

# 2. Idempotent second run
out2="$("$INSTALLER")"
grep -Fq "Summary" <<< "$out2" || { echo "[FAIL] Missing Summary in output" >&2; exit 1; }
grep -Fq "Backed up (0):" <<< "$out2" || { echo "[FAIL] Expected 0 backups on idempotent run" >&2; exit 1; }

# 3. Create or clone agent-config fixture repository
FIXTURE_REPO="$TMP_ROOT/fixture-agent-config"
if [ -n "${AGENT_CONFIG_FIXTURE:-}" ] && [ -d "$AGENT_CONFIG_FIXTURE/.git" ]; then
    git clone -q "$AGENT_CONFIG_FIXTURE" "$FIXTURE_REPO"
else
    mkdir -p "$FIXTURE_REPO"
    git -C "$FIXTURE_REPO" init -q
    git -C "$FIXTURE_REPO" config user.name "Fixture"
    git -C "$FIXTURE_REPO" config user.email "fixture@example.com"
    cat > "$FIXTURE_REPO/install.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
DRY_RUN=0
PROJECTS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --global) shift ;;
        --project) PROJECTS+=("$2"); shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        *) shift ;;
    esac
done
[ "$DRY_RUN" = "1" ] && exit 0
mkdir -p "$HOME/.gemini"
printf '# Global Rules\n' > "$HOME/.gemini/GEMINI.md"
for p in ${PROJECTS[@]+"${PROJECTS[@]}"}; do
    mkdir -p "$p/.agents/rules"
    printf '# Sample Rule\n' > "$p/.agents/rules/sample.md"
    if [ -d "$p/.git" ] && ! grep -qxF ".agents/" "$p/.git/info/exclude" 2>/dev/null; then
        mkdir -p "$p/.git/info"
        printf '.agents/\n' >> "$p/.git/info/exclude"
    fi
done
EOF
    chmod +x "$FIXTURE_REPO/install.sh"
    git -C "$FIXTURE_REPO" add install.sh
    git -C "$FIXTURE_REPO" commit -q -m "chore: initial fixture"
fi

# 4. --dry-run creates no files
DRY_HOME="$TMP_ROOT/dry-home"
mkdir -p "$DRY_HOME"
HOME="$DRY_HOME" "$INSTALLER" --dry-run --agents --agent-repo "$FIXTURE_REPO" >/dev/null
[ ! -e "$DRY_HOME/.bashrc" ] || { echo "[FAIL] --dry-run created ~/.bashrc" >&2; exit 1; }
[ ! -e "$DRY_HOME/.bashrc.local" ] || { echo "[FAIL] --dry-run created ~/.bashrc.local" >&2; exit 1; }
[ ! -e "$DRY_HOME/.config/dotfiles/install.conf" ] || { echo "[FAIL] --dry-run created install.conf" >&2; exit 1; }
[ ! -e "$DRY_HOME/.local/share/my-agent-config" ] || { echo "[FAIL] --dry-run cloned agent repo" >&2; exit 1; }

# 5. CLI flags, install.conf persistence, and CLI > install.conf priority
PROJ_DIR="$TMP_ROOT/my-project"
PROJ_DIR2="$TMP_ROOT/my-project-2"
mkdir -p "$PROJ_DIR" "$PROJ_DIR2"
git -C "$PROJ_DIR" init -q
git -C "$PROJ_DIR2" init -q

"$INSTALLER" --only-agents --agents \
    --agent-repo "$FIXTURE_REPO" \
    --agent-dir "$TEST_HOME/.local/share/my-agent-config" \
    --agent-project "$PROJ_DIR" >/dev/null

CONF_FILE="$TEST_HOME/.config/dotfiles/install.conf"
[ -f "$CONF_FILE" ] || { echo "[FAIL] Missing install.conf after --agents" >&2; exit 1; }
[ "$(git config --file "$CONF_FILE" --get agents.enabled)" = "true" ] || { echo "[FAIL] Expected agents.enabled=true" >&2; exit 1; }
[ "$(norm_path "$(git config --file "$CONF_FILE" --get agents.repo)")" = "$(norm_path "$FIXTURE_REPO")" ] || { echo "[FAIL] Expected agents.repo in install.conf" >&2; exit 1; }
[ "$(norm_path "$(git config --file "$CONF_FILE" --get-all agents.project)")" = "$(norm_path "$PROJ_DIR")" ] || { echo "[FAIL] Expected agents.project in install.conf" >&2; exit 1; }
[ -f "$TEST_HOME/.gemini/GEMINI.md" ] || { echo "[FAIL] Missing ~/.gemini/GEMINI.md" >&2; exit 1; }
[ -f "$PROJ_DIR/.agents/rules/sample.md" ] || { echo "[FAIL] Missing project rule in PROJ_DIR" >&2; exit 1; }
grep -qxF ".agents/" "$PROJ_DIR/.git/info/exclude" || { echo "[FAIL] Missing .agents/ in .git/info/exclude" >&2; exit 1; }

# Second run without flags uses persisted install.conf
"$INSTALLER" --only-agents >/dev/null

# CLI --agent-project overrides install.conf
"$INSTALLER" --only-agents --agent-project "$PROJ_DIR2" >/dev/null
[ -f "$PROJ_DIR2/.agents/rules/sample.md" ] || { echo "[FAIL] CLI --agent-project did not override install.conf" >&2; exit 1; }
[ "$(norm_path "$(git config --file "$CONF_FILE" --get-all agents.project)")" = "$(norm_path "$PROJ_DIR2")" ] || { echo "[FAIL] install.conf not updated by CLI override" >&2; exit 1; }

# 6. One-time migration from legacy ~/.bashrc.local
MIG_HOME="$TMP_ROOT/mig-home"
MIG_PROJ_ROOT="$TMP_ROOT/mig-projects"
mkdir -p "$MIG_HOME" "$MIG_PROJ_ROOT/app"
cat > "$MIG_HOME/.bashrc.local" <<EOF
export GIT_USER_NAME="Test User"
export GIT_USER_EMAIL="test@example.com"
export PROJECTS_ROOT="$MIG_PROJ_ROOT"
declare -g -A PROJECT_PATHS=( ["app"]="app" )
export INSTALL_AGENT_CONFIG=true
export AGENT_CONFIG_REPO="$FIXTURE_REPO"
export AGENT_CONFIG_DIR="$MIG_HOME/.local/share/my-agent-config"
AGENT_CONFIG_PROJECTS=( "app" )
EOF

out_mig="$(HOME="$MIG_HOME" "$INSTALLER" 2>&1)"
grep -Fq "Migrating legacy agent settings" <<< "$out_mig" || { echo "[FAIL] Expected migration warning" >&2; exit 1; }
[ -f "$MIG_HOME/.config/dotfiles/install.conf" ] || { echo "[FAIL] Migration did not create install.conf" >&2; exit 1; }
[ "$(git config --file "$MIG_HOME/.config/dotfiles/install.conf" --get agents.enabled)" = "true" ] || { echo "[FAIL] Migrated agents.enabled != true" >&2; exit 1; }
[ "$(norm_path "$(git config --file "$MIG_HOME/.config/dotfiles/install.conf" --get-all agents.project)")" = "$(norm_path "$MIG_PROJ_ROOT/app")" ] || { echo "[FAIL] Migrated project alias not resolved" >&2; exit 1; }
[ -f "$MIG_PROJ_ROOT/app/.agents/rules/sample.md" ] || { echo "[FAIL] Migrated project rules not installed" >&2; exit 1; }
grep -Fq "INSTALL_AGENT_CONFIG=true" "$MIG_HOME/.bashrc.local" || { echo "[FAIL] Migration modified ~/.bashrc.local unexpectedly" >&2; exit 1; }

# Second run after migration must not re-migrate
out_mig2="$(HOME="$MIG_HOME" "$INSTALLER" 2>&1)"
if grep -Fq "Migrating legacy agent settings" <<< "$out_mig2"; then
    echo "[FAIL] Migration ran more than once" >&2
    exit 1
fi

# 7. Unreachable agent repo warns and still exits 0
OFFLINE_HOME="$TMP_ROOT/offline-home"
mkdir -p "$OFFLINE_HOME"
out_offline="$(HOME="$OFFLINE_HOME" "$INSTALLER" --agents --agent-repo "file://$TMP_ROOT/does-not-exist.git" --agent-dir "$OFFLINE_HOME/.local/share/my-agent-config" 2>&1)"
grep -Fq "Warnings" <<< "$out_offline" || { echo "[FAIL] Expected warning on offline agent repo" >&2; exit 1; }

printf '[PASS] All dotfiles smoke tests passed.\n'
