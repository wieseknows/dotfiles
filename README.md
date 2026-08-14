# Dotfiles

Personal Bash and Git configuration for **Windows Git Bash / MINGW64** and **Linux**.

## Features

* **SSH Agent** — automatically starts/manages an SSH agent and loads configured keys.
* **Project Navigation** — jump to projects with `proj <alias>`.
* **Git Aliases** — shortcuts for common Git workflows.
* **GitReview** — automatically installed/updated as a global .NET tool.
* **Local Overrides** — machine-specific settings and secrets stay outside the shared configuration.

## Structure

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

## Requirements

### Linux

* Bash
* Git
* OpenSSH
* .NET SDK — optional, required for GitReview

### Windows

* Git for Windows / Git Bash
* OpenSSH
* .NET SDK — optional, required for GitReview

## Installation

Clone the repository:

```bash
git clone https://github.com/wieseknows/dotfiles.git
cd dotfiles
```

Create local configuration files:

```bash
cp .bashrc.local.template .bashrc.local
cp .gitconfig.local.template .gitconfig.local
```

Edit them with your personal settings, then run:

```bash
./install.sh
```

Reload Bash:

```bash
source ~/.bashrc
```

The installer configures Bash and Git and, if `dotnet` is available, installs or updates the `wieseknows.GitReview` global tool.

## Local Configuration

Keep machine-specific settings in `.bashrc.local`.

### SSH keys

```bash
SSH_KEYS=(
    "C:/dev/private_key"
    "$HOME/.ssh/id_ed25519_personal"
)
```

### Project navigation

Set the root directory:

```bash
export PROJECTS_ROOT="/c/dev/projects"
```

Then define project aliases:

```bash
declare -g -A PROJECT_PATHS=(
    ["syn"]="synthesis_newdesign/web"
    ["oms"]="oms/web"
    ["pin"]="pinergy/web"
)
```

Paths are relative to `PROJECTS_ROOT`.

Use:

```bash
proj syn
proj oms
proj pin
```

Run `proj` without arguments to see all configured projects.

Adding a project only requires changing `.bashrc.local`:

```bash
["api"]="my-api/backend"
```

No changes to `functions.bash` are required.

### API keys

Secrets can also be stored in `.bashrc.local`:

```bash
export GEMINI_API_KEY="your_api_key_here"
export DEEPSEEK_API_KEY="your_api_key_here"
```

Never commit `.bashrc.local` or other credentials.

## Git

Useful aliases include:

| Command            | Description                                                                |
| ------------------ | -----------------------------------------                                  |
| `git get`          | Pull current branch and update submodules                                  |
| `git shr`          | Push current branch to `origin`                                            |
| `git upd`          | Stash, pull, and re-apply changes                                          |
| `git snap`         | Create a timestamped stash snapshot                                        |
| `git cos <branch>` | Checkout branch and show status                                            |
| `git history`      | Compact graphical Git history                                              |
| `git bump`         | Auto-increment patch tag (e.g., `v1.0.2` → `v1.0.3`) and push to `origin`  |

## GitReview

`install.sh` automatically checks for the .NET SDK and installs or updates:

```text
wieseknows.GitReview
```

If `.NET SDK` is not installed or not available in `PATH`, GitReview installation is skipped.

The GitReview provider can be configured locally:

```bash
export GIT_REVIEW_PROVIDER="gemini"
```

## Security

The following files are intended to remain local:

```text
.bashrc.local
.gitconfig.local
```

Do not commit:

* API keys
* passwords
* private SSH keys
* machine-specific secrets

If a credential is accidentally committed, revoke or rotate it immediately.

## Updating

Pull the latest changes:

```bash
cd /path/to/dotfiles
git pull
```

Then re-run:

```bash
./install.sh
source ~/.bashrc
```

## License

MIT
