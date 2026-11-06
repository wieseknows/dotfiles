# Dotfiles

Personal Bash and Git configuration for **Windows Git Bash (MINGW64)** and **Linux** with automated one-click setup.

---

## ⚡ Quick Start (One-Click Setup)

All system customization is unified into **a single configuration file**.

### Step 1. Clone the repository

```bash
git clone https://github.com/wieseknows/dotfiles.git
cd dotfiles
```

### Step 2. Create and customize `.bashrc.local`

```bash
cp .bashrc.local.template ~/.bashrc.local
```
*(If you skip this step, `install.sh` will automatically create this file from the template on first run).*

Open `~/.bashrc.local` in your favorite editor and set your details:

```bash
# 1. Git Identity (install.sh automatically writes this to Git — no need to edit .gitconfig.local!)
export GIT_USER_NAME="Your Name"
export GIT_USER_EMAIL="your.email@example.com"

# 2. Paths to private SSH keys (in OpenSSH format)
SSH_KEYS=(
    "/c/dev/private_key"
    "$HOME/.ssh/id_ed25519_personal"
    "$HOME/.ssh/id_rsa"
)

# 3. API Keys & AI tools
export OPENROUTER_API_KEY="sk-..."
export PROJECTS_ROOT="/c/dev/projects"
```

### Step 3. Run the installer

* **From terminal (Git Bash / Linux):**
  ```bash
  ./install.sh
  ```
  *(For automated / headless installation, set `NONINTERACTIVE=1 ./install.sh` or `CI=1 ./install.sh`).*
* **Or in Windows Explorer:** simply double-click **`install.bat`**.

> [!NOTE]
> The console window **will not close automatically** after installation finishes — you can comfortably inspect all validation and setup logs before pressing Enter to exit.

### Step 4. Reload Bash

```bash
source ~/.bashrc
```
*(Or simply open a new terminal window / tab).*

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
> The installer automatically validates all keys listed in `SSH_KEYS`. If a key is missing but a corresponding `.ppk` file is found on disk, the script will display a clear reminder on how to export it.

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

Aliases and relative paths are configured in `~/.bashrc.local` via the `PROJECT_PATHS` associative array.

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

## 📁 Repository Structure

```text
dotfiles/
├── .bashrc                  # Main shell environment loader and SSH Agent manager
├── .bashrc.local.template   # UNIFIED local configuration template
├── .gitattributes           # Git repository configuration enforcing LF line endings
├── .gitconfig               # Shared public Git aliases and defaults
├── .gitconfig.local.template# Git INI template for local overrides (~/.gitconfig.local)
├── .gitignore               # Ensures local secrets and keys are never committed
├── aliases.bash             # Daily shell aliases and shortcuts
├── functions.bash           # Shell functions (proj, gitwho, mkcd, findf, findd)
├── install.sh               # Smart idempotent installer (Bash)
├── install.bat              # One-click launcher for Windows Explorer
└── README.md                # Documentation
```

---

## 🔒 Security

Files named `.bashrc.local` and `.gitconfig.local` are listed in `.gitignore` and **are never tracked by Git**. Your secrets, API tokens, and private SSH key paths remain strictly local to your machine.
