# Dotfiles - Bash & Git Environment

Personal dotfiles setup optimized for **Windows Git Bash / MINGW64** and **Linux** environments.

The configuration is intentionally split into shared dotfiles and local overrides, keeping machine-specific settings and secrets outside the repository.

## Features

* **Dynamic SSH Agent** — automatically manages a single SSH agent instance and loads configured keys.
* **Dynamic Project Navigation** — jump to configured project directories with `proj` without modifying the shared dotfiles.
* **Git Workflows** — useful aliases for branching, pulling, pushing, stashing, and reviewing history.
* **Cross-platform** — designed for Git Bash / MINGW64 on Windows and Bash on Linux.
* **Local Overrides** — keep personal settings, credentials, API keys, and machine-specific paths in untracked local files.
* **One-step Installation** — install the configuration with `install.sh`.

## Directory Structure

```text
dotfiles/
├── .bashrc
├── .bashrc.local.template
├── .gitconfig
├── .gitconfig.local.template
├── .gitignore
├── aliases.bash
├── functions.bash
├── install.sh
└── README.md
```

### Configuration Files

| File                        | Purpose                                                           |
| --------------------------- | ----------------------------------------------------------------- |
| `.bashrc`                   | Main Bash configuration loader and SSH agent setup                |
| `.bashrc.local.template`    | Template for machine-specific Bash settings                       |
| `.gitconfig`                | Shared global Git configuration and aliases                       |
| `.gitconfig.local.template` | Template for personal Git identity                                |
| `.gitignore`                | Prevents local configuration, keys, and logs from being committed |
| `aliases.bash`              | General shell aliases                                             |
| `functions.bash`            | Shell helper functions such as `proj` and `gitwho`                |
| `install.sh`                | Installs/symlinks the dotfiles into the user's home directory     |

## Requirements

### Linux

* Bash
* Git
* OpenSSH client

### Windows

* Git for Windows
* Git Bash / MINGW64
* OpenSSH client included with Git for Windows

The configuration is intended to be used from **Bash**, not PowerShell or `cmd.exe`.

## Quick Start

### 1. Clone the repository

```bash
git clone https://github.com/wieseknows/dotfiles.git
cd dotfiles
```

### 2. Create local configuration files

```bash
cp .bashrc.local.template .bashrc.local
cp .gitconfig.local.template .gitconfig.local
```

These files are intentionally kept outside version control.

### 3. Configure local Bash settings

Edit `.bashrc.local` and configure your machine-specific settings.

#### SSH keys

```bash
SSH_KEYS=(
    "C:/dev/private_key"
    "$HOME/.ssh/id_ed25519_personal"
)
```

Use paths appropriate for your environment. On Windows Git Bash, Windows-style paths such as `C:/dev/private_key` can be used.

#### API keys

Add local secrets only to `.bashrc.local`:

```bash
export GEMINI_API_KEY="your_api_key_here"
```

Do **not** commit `.bashrc.local` or API credentials to the repository.

### 4. Configure Git identity

Edit `.gitconfig.local`:

```ini
[user]
    name = Your Name
    email = your.email@example.com
```

### 5. Configure project navigation

Set the root directory containing your projects:

```bash
export PROJECTS_ROOT="/c/dev/projects"
```

Then define project aliases using the `PROJECT_PATHS` associative array:

```bash
declare -g -A PROJECT_PATHS=(
    ["syn"]="synthesis_newdesign/web"
    ["syn_old"]="synthesis_old/web"
    ["syn_pub_uat"]="synthesis_publish_uat/web"
    ["syn_pub_live"]="synthesis_publish_live/web"
    ["oms"]="oms/web"
    ["pin"]="pinergy/web"
    ["dop"]="pinergy/web"
)
```

Each value is a path **relative to `PROJECTS_ROOT`**.

For example:

```text
PROJECTS_ROOT
└── /c/dev/projects
    ├── synthesis_newdesign/web
    ├── synthesis_old/web
    ├── synthesis_publish_uat/web
    ├── synthesis_publish_live/web
    ├── oms/web
    └── pinergy/web
```

### 6. Run the installer

```bash
./install.sh
```

If the script is not executable:

```bash
bash install.sh
```

### 7. Reload Bash

```bash
source ~/.bashrc
```

Alternatively, start a new Git Bash terminal.

## Shell & Navigation

### Directory aliases

| Command | Description                             |
| ------- | --------------------------------------- |
| `ll`    | Detailed directory listing              |
| `la`    | Detailed listing including hidden files |
| `l`     | Short directory listing                 |
| `c`     | Clear terminal                          |
| `cls`   | Clear terminal                          |
| `..`    | Go up one directory                     |
| `...`   | Go up two directories                   |
| `....`  | Go up three directories                 |

## Project Navigation

The `proj` function provides dynamic project navigation based on the `PROJECT_PATHS` configuration in `.bashrc.local`.

### Usage

```bash
proj <project_alias>
```

For example:

```bash
proj syn
proj oms
proj pin
```

The function resolves the configured relative path against `PROJECTS_ROOT`.

For example:

```bash
PROJECTS_ROOT="/c/dev/projects"
```

with:

```bash
["syn"]="synthesis_newdesign/web"
```

results in:

```text
/c/dev/projects/synthesis_newdesign/web
```

### List available projects

Run `proj` without arguments:

```bash
proj
```

It displays all currently configured project aliases and their relative paths.

Example:

```text
Usage: proj <project_alias>

Available projects in $PROJECTS_ROOT (/c/dev/projects):
  syn             -> synthesis_newdesign/web
  syn_old         -> synthesis_old/web
  syn_pub_uat     -> synthesis_publish_uat/web
  syn_pub_live    -> synthesis_publish_live/web
  oms             -> oms/web
  pin             -> pinergy/web
  dop             -> pinergy/web
```

### Add a new project

Projects can be added entirely through `.bashrc.local` without modifying `functions.bash`.

For example:

```bash
declare -g -A PROJECT_PATHS=(
    ["syn"]="synthesis_newdesign/web"
    ["oms"]="oms/web"
    ["api"]="my-api/backend"
    ["frontend"]="my-frontend"
)
```

Then reload Bash:

```bash
source ~/.bashrc
```

The new projects are immediately available:

```bash
proj api
proj frontend
```

### Project aliases

Multiple aliases can point to the same directory.

For example:

```bash
["pin"]="pinergy/web"
["dop"]="pinergy/web"
```

Both commands resolve to the same project:

```bash
proj pin
proj dop
```

### Project validation

`proj` checks that:

1. `PROJECTS_ROOT` is configured.
2. The requested alias exists in `PROJECT_PATHS`.
3. The resulting directory actually exists.

If the project does not exist, an error is displayed instead of changing the current directory.

## Git Workflows

The configuration provides several aliases for common Git operations.

### Update and synchronize

```bash
git get
```

Pull the current branch and update submodules.

```bash
git shr
```

Push the current branch to `origin`.

```bash
git upd
```

Stash local changes, pull the current branch, and re-apply the stash.

> **Note:** `git upd` can potentially produce merge conflicts when the remote branch and local changes overlap. Review the resulting working tree with `git status`.

### Branch workflow

```bash
git cos <branch>
```

Checkout a branch and immediately display its status.

Example:

```bash
git cos feature/my-feature
```

### Stash snapshots

```bash
git snap
```

Create a timestamped stash snapshot without intentionally wiping the current workspace.

### History

```bash
git history
```

Display a compact graphical Git history.

## SSH Agent

The Bash configuration automatically manages an SSH agent and loads the keys listed in `SSH_KEYS`.

Example:

```bash
SSH_KEYS=(
    "$HOME/.ssh/id_ed25519"
    "$HOME/.ssh/id_ed25519_personal"
)
```

On Windows Git Bash, a Windows path can also be specified:

```bash
SSH_KEYS=(
    "C:/dev/private_key"
)
```

The goal is to avoid starting multiple SSH agent processes unnecessarily while still making configured keys available to Git and SSH operations.

You can verify the currently loaded keys with:

```bash
ssh-add -l
```

## Local Configuration

Local configuration files are deliberately separated from the shared repository:

```text
.bashrc.local
.gitconfig.local
```

This allows the repository to contain reusable configuration without exposing:

* Git identity
* API keys
* private SSH key paths
* machine-specific directories
* other local settings

## Security

Treat `.bashrc.local` and SSH-related files as sensitive configuration.

Never add private keys or API credentials to Git.

Typical sensitive files include:

```text
id_rsa
id_ed25519
*.pem
*.key
.bashrc.local
.gitconfig.local
```

If a secret is accidentally committed, removing the file in a later commit is **not sufficient**. The exposed credential should be considered compromised and rotated or revoked.

## Updating the Dotfiles

Pull the latest changes:

```bash
cd /path/to/dotfiles
git pull
```

Then reload Bash:

```bash
source ~/.bashrc
```

If the installer manages symlinks or copied configuration files, re-run it when necessary:

```bash
./install.sh
```

## Customization

The configuration follows a simple separation between shared functionality and local configuration:

```text
Shared configuration
        │
        ├── .bashrc
        ├── .gitconfig
        ├── aliases.bash
        └── functions.bash
                │
                ▼
        Local configuration
                │
                ├── .bashrc.local
                └── .gitconfig.local
```

### Shared configuration

Keep reusable functionality in the repository:

* shell aliases
* Bash functions
* Git aliases
* SSH agent logic
* configuration loading

### Local configuration

Keep machine-specific values in `.bashrc.local`:

* `PROJECTS_ROOT`
* `PROJECT_PATHS`
* SSH key paths
* API keys
* local aliases
* other machine-specific settings

This means project paths can differ between machines without changing or committing modifications to the shared dotfiles.

## Troubleshooting

### Changes are not applied

Reload the configuration:

```bash
source ~/.bashrc
```

Or open a new Git Bash terminal.

### `proj` reports that `PROJECTS_ROOT` is not set

Make sure `.bashrc.local` contains:

```bash
export PROJECTS_ROOT="/c/dev/projects"
```

Then reload:

```bash
source ~/.bashrc
```

### `proj` reports an unknown project alias

Check the configured aliases:

```bash
proj
```

Then add the missing project to `PROJECT_PATHS` in `.bashrc.local`.

### `proj` reports that a directory does not exist

Verify the resulting path.

For example:

```bash
ls -la "$PROJECTS_ROOT"
```

Then check the project-specific path:

```bash
ls -la "$PROJECTS_ROOT/synthesis_newdesign/web"
```

Remember that values in `PROJECT_PATHS` are relative to `PROJECTS_ROOT`.

### SSH key was not loaded

Check the agent:

```bash
ssh-add -l
```

If necessary, verify that the configured key path exists:

```bash
ls -la "$HOME/.ssh"
```

For Windows paths:

```bash
ls -la "C:/dev"
```

### Git identity is incorrect

Check the effective Git configuration:

```bash
git config --global --list
```

Your personal identity should normally come from `.gitconfig.local`.

## License

MIT
