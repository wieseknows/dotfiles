# Dotfiles

Personal Bash and Git configuration for **Windows Git Bash (MINGW64)** and **Linux** with automated one-click setup, including optional Antigravity agent config orchestration.

---

## ⚡ Quick Start (One-Click Setup)

You don't need to copy or edit `.bashrc.local` manually. Both the GUI wizard and the CLI installer prompt you for your settings during setup and generate your machine-local configs in `$HOME` (`~/.bashrc.local` and `~/.gitconfig.local`) automatically. A reference template is also provided in `.bashrc.local.template`.

### Step 1. Clone the repository

```bash
git clone https://github.com/wieseknows/dotfiles.git
cd dotfiles
```

### Step 2. Run the installer

* **Windows (GUI Setup Wizard — recommended):** simply double-click **`install.bat`**.
  The graphical wizard lets you enter your Git name/email, browse and pick SSH keys and project folders, enter API keys securely, and toggle optional tools.
  *(To run the interactive console installer on Windows, use `install.bat --cli`).*

  ![Dotfiles Setup Wizard](assets/setup-wizard.png)
* **From terminal (Git Bash / Linux):**
  ```bash
  ./install.sh
  ```
  The installer will interactively ask for your Git identity, SSH keys, optional AI/GitReview API keys, and whether to sync Antigravity agent config on first run.
  * To re-run the interactive configuration later, use `./install.sh --reconfigure`.
  * For automated / headless installation, set `NONINTERACTIVE=1 ./install.sh` or `CI=1 ./install.sh` (optionally passing `GIT_USER_NAME`, `GIT_USER_EMAIL`, etc. via environment variables).
  * Useful flags: `--skip-agents`, `--only-agents`, `--dry-run`, `--help`.

### Step 3. Reload Bash

```bash
source ~/.bashrc
```
*(Or simply open a new terminal window / tab).*

---

## 🤖 Antigravity Agent Config (`my-agent-config`)

`dotfiles` acts as the orchestrator for [wieseknows/my-agent-config](https://github.com/wieseknows/my-agent-config) without using Git submodules.

In `~/.bashrc.local` (see `.bashrc.local.template`):
* `INSTALL_AGENT_CONFIG=true|false` — enable/disable agent config sync.
* `AGENT_CONFIG_REPO` — repository URL (default: `https://github.com/wieseknows/my-agent-config.git`).
* `AGENT_CONFIG_DIR` — local clone path (default: `$HOME/.local/share/my-agent-config`).
* `AGENT_CONFIG_PROJECTS` — array of aliases from `PROJECT_PATHS` where `.agents/rules/` and `.agents/workflows/` should be installed. Leave empty for global-only (`~/.gemini/`).

When enabled, `./install.sh` performs a shallow clone or `git pull --ff-only`, then invokes `my-agent-config/install.sh --global` and `--project <path>` for each selected alias. If the network or agent step fails, `dotfiles` logs a warning, continues the rest of the setup, and reports the issue in the final summary.

---

## 🔑 Managing SSH Keys

### Important: OpenSSH vs PuTTY (`.ppk`)
Git Bash and `ssh-add` **only accept OpenSSH format** private keys (`-----BEGIN OPENSSH PRIVATE KEY-----` or `-----BEGIN RSA PRIVATE KEY-----`). They **cannot** parse `.ppk` files.

If you generate or maintain keys in **PuTTYgen**:
1. Open **PuTTYgen** and click **Load**.
2. Select your `.ppk` file (e.g., `C:\dev\private_key.ppk`).
3. In the top menu, choose: **Conversions → Export OpenSSH key**.
4. Save the file without the `.ppk` extension (e.g., `C:\dev\private_key`).

> [!TIP]
> `SSH_KEYS` is optional. If you leave it empty in the installer, `.bashrc` automatically discovers and loads OpenSSH private keys from `~/.ssh/`.
> The installer also validates any keys explicitly listed in `SSH_KEYS`. If a key is missing but a corresponding `.ppk` file is found on disk, the script will display a clear reminder on how to export it.

### Azure DevOps (`ssh.dev.azure.com`)
If you define `AZURE_SSH_KEY` in `~/.bashrc.local`, the installer automatically ensures the required host entry exists in `~/.ssh/config`:
```ssh
Host ssh.dev.azure.com vs-ssh.visualstudio.com
    HostName ssh.dev.azure.com
    IdentityFile <path_to_your_azure_ssh_key>
    IdentitiesOnly yes
    PubkeyAcceptedKeyTypes +ssh-rsa
```
Otherwise, you can add this block to `~/.ssh/config` manually if connecting to Azure DevOps.

---

## 🛠 Features & Commands

### 1. Project Navigation (`proj`)
Quickly jump to registered project directories from anywhere:
* `proj` — display all configured project aliases and their paths.
* `proj syn` — jump directly to the project (e.g., `/c/dev/projects/synthesis_newdesign/web`).

Aliases and project paths are configured in `~/.bashrc.local` via the `PROJECT_PATHS` associative array.

### 2. Git Identity Check (`gitwho`)
Inspect the effective Git name and email, along with their configuration sources:
```bash
gitwho
```

### 3. Useful Git Aliases

| Command | Action |
| :--- | :--- |
| `git get` | Pull current branch and update submodules |
| `git shr` | Push current branch to `origin` |
| `git brd <branch>` | Delete remote branch (`push origin --delete`) without argument duplication |
| `git gas [branch]` | Pull from origin |
| `git sas <branch>` | Push current branch to a specific remote branch name |
| `git cows <branch>` | Safe switch: stashes changes, checkouts target branch, pulls, and reapplies stash |
| `git upd` | Safe pull: stashes working changes, pulls upstream, and pops stash (preserves unrelated stashes) |
| `git snap` | Create an instant stash snapshot with a timestamp label (guards clean tree) |
| `git cos <branch>` | Checkout a branch and immediately show `git status` |
| `git cl` | Safe clean: cleans untracked files (`clean -d -f`) without removing gitignored `.local` configs |
| `git bump` | Auto-increment patch version tag (e.g. `v1.0.2` → `v1.0.3`) and push tag to `origin` |
| `git history` | Compact graphical commit history tree |

### 4. Shell Shortcuts
* `ll`, `la`, `l` — enhanced file listings.
* `..`, `...`, `....` — quickly navigate 1, 2, or 3 folder levels up.
* `dev` — cross-platform jump to development directory (`$DEV_DIR`, `/c/dev`, `/mnt/c/dev`, or `~/dev`).
* `cls`, `c` — clear screen.

### 5. File & Directory Search & Helpers
* `findf <pattern> [path]` — Case-insensitive file search safe with dashes, spaces, and glob patterns.
* `findd <pattern> [path]` — Case-insensitive directory search safe with dashes, spaces, and glob patterns.
* `mkcd <dir>` — Create directory and immediately change into it.

### 6. GitReview Tool
The installer detects .NET SDK and installs or updates the global CLI tool `wieseknows.gitreview`.

---

## 🔧 Troubleshooting

* **Windows symlinks:** Git Bash symlinks require Developer Mode or elevated privileges and can fail silently. Both `dotfiles` and `my-agent-config` copy files instead of symlinking and compare content hashes to stay idempotent.
* **PowerShell execution policy:** If PowerShell scripts are blocked, launch via `install.bat` (which uses `-ExecutionPolicy Bypass`) or run `./install.sh` directly in Git Bash.
* **Shared `~/.gemini/` with Gemini CLI:** Global agent rules installed to `~/.gemini/GEMINI.md` are shared with Gemini CLI. Existing differing files are backed up with a timestamp before overwriting.

---

## 📁 Repository Structure

```text
dotfiles/
├── assets/
│   └── setup-wizard.png      # GUI Setup Wizard screenshot
├── tests/
│   └── smoke_test.sh         # Isolated HOME smoke tests for install.sh
├── .bashrc                   # Main shell environment loader and SSH Agent manager
├── .bashrc.local.template    # Reference template for ~/.bashrc.local
├── .gitattributes            # Git repository configuration enforcing LF line endings
├── .gitconfig                # Shared public Git aliases and defaults
├── .gitignore                # Ensures local secrets and keys are never committed
├── aliases.bash              # Daily shell aliases and shortcuts
├── functions.bash            # Shell functions (proj, gitwho, mkcd, findf, findd)
├── install.sh                # Smart idempotent installer with interactive CLI setup
├── install-gui.ps1           # Windows WPF GUI Setup Wizard
├── install.bat               # One-click launcher for Windows Explorer (GUI / --cli)
└── README.md                 # Documentation
```

---

## 🔒 Security

Your personal settings (Git identity, API tokens, SSH key paths, project aliases) are stored outside the repository in `~/.bashrc.local` and `~/.gitconfig.local`, generated by the installer. Both `.bashrc.local` and `.gitconfig.local` are also listed in `.gitignore` so they are never tracked by Git.
