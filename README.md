# Dotfiles - Bash & Git Environment

Personal dotfiles setup optimized for **Windows Git Bash / MINGW64** and **Linux** environments.

The configuration is intentionally split into shared dotfiles and local overrides, keeping machine-specific settings and secrets outside the repository.

## Features

* **Dynamic SSH Agent** — automatically manages a single SSH agent instance and loads configured keys.
* **Project Navigation** — quickly switch between predefined project directories with `proj`.
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

Edit `.bashrc.local` and add your machine-specific settings.

For example:

```bash
SSH_KEYS=(
    "C:/dev/private_key"
    "$HOME/.ssh/id_ed25519_personal"
)

export GEMINI_API_KEY="your_api_key_here"
```

Use paths appropriate for your environment. On Windows Git Bash, both Windows-style paths such as `C:/dev/private_key` and Bash paths such as `$HOME/.ssh/id_ed25519` can be used where supported by the configuration.

### 4. Configure Git identity

Edit `.gitconfig.local`:

```ini
[user]
    name = Your Name
    email = your.email@example.com
```

### 5. Run the installer

```bash
./install.sh
```

If the script is not executable:

```bash
bash install.sh
```

### 6. Reload Bash

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

### Project navigation

Use `proj` to jump directly to predefined project directories:

```bash
proj syn
proj oms
```

The available project names and paths are configured in your local Bash configuration.

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

Do **not** commit secrets directly to the repository.

## Security

Treat `.bashrc.local` and SSH-related files as sensitive configuration.

Never add private keys or API credentials to Git:

```text
id_rsa
id_ed25519
*.pem
*.key
.bashrc.local
.gitconfig.local
```

If a secret is accidentally committed, removing the file in a later commit is **not sufficient**. The exposed credential should be considered compromised and rotated/revoked.

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

The intended customization flow is:

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

Keep reusable configuration in the repository and machine-specific values in the local files.

## Troubleshooting

### Changes are not applied

Reload the configuration:

```bash
source ~/.bashrc
```

Or open a new Git Bash terminal.

### SSH key was not loaded

Check the agent:

```bash
ssh-add -l
```

If necessary, verify that the configured key path exists:

```bash
ls -la "$HOME/.ssh"
```

For Windows paths, verify the path from Git Bash:

```bash
ls -la "C:/dev"
```

### `proj` does not work

Make sure the project directory configuration is defined in your local Bash configuration and reload the shell:

```bash
source ~/.bashrc
```

### Git identity is incorrect

Check the effective Git configuration:

```bash
git config --global --list
```

Your personal identity should normally come from `.gitconfig.local`.

## License

MIT
