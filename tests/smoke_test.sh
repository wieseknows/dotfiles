#!/usr/bin/env bash
# Smoke tests for dotfiles/install.sh in an isolated temporary HOME
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_DIR/install.sh"

TMP_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

TEST_HOME="$TMP_ROOT/home"
mkdir -p "$TEST_HOME"
export HOME="$TEST_HOME"
export NONINTERACTIVE=1
export INSTALL_GITREVIEW=0
export GIT_USER_NAME="Test User"
export GIT_USER_EMAIL="test@example.com"

# 1. Fresh install
"$INSTALLER" >/dev/null
[ -f "$TEST_HOME/.bashrc" ] || { echo "[FAIL] Missing ~/.bashrc" >&2; exit 1; }
[ -f "$TEST_HOME/.bashrc.local" ] || { echo "[FAIL] Missing ~/.bashrc.local" >&2; exit 1; }
[ -f "$TEST_HOME/.gitconfig.local" ] || { echo "[FAIL] Missing ~/.gitconfig.local" >&2; exit 1; }
grep -Fq "INSTALL_AGENT_CONFIG=false" "$TEST_HOME/.bashrc.local" || { echo "[FAIL] Missing INSTALL_AGENT_CONFIG in ~/.bashrc.local" >&2; exit 1; }

# 2. Idempotent second run
out2="$("$INSTALLER")"
grep -Fq "Summary" <<< "$out2" || { echo "[FAIL] Missing Summary in output" >&2; exit 1; }
grep -Fq "Backed up (0):" <<< "$out2" || { echo "[FAIL] Expected 0 backups on idempotent run" >&2; exit 1; }

# 3. --dry-run and --skip-agents
"$INSTALLER" --dry-run --skip-agents >/dev/null

# 4. --only-agents with local mock my-agent-config repository
MOCK_AGENT_REPO="$TMP_ROOT/mock-agent-config"
PROJ_DIR="$TMP_ROOT/my-project"
mkdir -p "$MOCK_AGENT_REPO" "$PROJ_DIR"
git -C "$PROJ_DIR" init -q

if [ -d "/c/dev/avi/local_projects/my-agent-config/.git" ]; then
    git clone -q /c/dev/avi/local_projects/my-agent-config "$MOCK_AGENT_REPO"
    cat >> "$TEST_HOME/.bashrc.local" <<EOF
export INSTALL_AGENT_CONFIG=true
export AGENT_CONFIG_REPO="$MOCK_AGENT_REPO"
export AGENT_CONFIG_DIR="$TEST_HOME/.local/share/my-agent-config"
declare -g -A PROJECT_PATHS=( ["demo"]="$PROJ_DIR" )
AGENT_CONFIG_PROJECTS=( "demo" )
EOF
    "$INSTALLER" --only-agents >/dev/null
    [ -f "$TEST_HOME/.gemini/GEMINI.md" ] || { echo "[FAIL] Missing ~/.gemini/GEMINI.md" >&2; exit 1; }
    [ -f "$PROJ_DIR/.agents/rules/dotnet.md" ] || { echo "[FAIL] Missing project rule" >&2; exit 1; }
    grep -qxF ".agents/" "$PROJ_DIR/.git/info/exclude" || { echo "[FAIL] Missing .agents/ in .git/info/exclude" >&2; exit 1; }
fi

# 5. Offline / unreachable AGENT_CONFIG_REPO warns and still exits 0
rm -rf "$TEST_HOME/.local/share/my-agent-config"
cat > "$TEST_HOME/.bashrc.local" <<EOF
export GIT_USER_NAME="Test User"
export GIT_USER_EMAIL="test@example.com"
export INSTALL_AGENT_CONFIG=true
export AGENT_CONFIG_REPO="file://$TMP_ROOT/does-not-exist.git"
export AGENT_CONFIG_DIR="$TEST_HOME/.local/share/my-agent-config"
EOF
out_offline="$("$INSTALLER" 2>&1)"
grep -Fq "Warnings" <<< "$out_offline" || { echo "[FAIL] Expected warning on offline agent repo" >&2; exit 1; }

printf '[PASS] All dotfiles smoke tests passed.\n'
