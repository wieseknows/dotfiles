# Dotfiles - Bash & Git Environment

Personal dotfiles setup optimized for Windows Git Bash / MINGW64 and Linux environments.

## Features

- **Dynamic SSH Agent**: Automatically manages a single SSH agent instance and loads keys defined in configuration.
- **Project Navigation**: Fast switching between project directories via the `proj` function.
- **Git Workflows**: Extended set of aliases for efficient branch management, stashing, and reviews.
- **Local Overrides**: Clean separation between shared dotfiles and local secrets (`.bashrc.local`, `.gitconfig.local`).

## Directory Structure

dotfiles/
├── .bashrc                 # Central configuration loader & SSH Agent setup
├── .bashrc.local.template  # Template for local variables & SSH keys
├── .gitconfig              # Global Git options and custom aliases
├── .gitconfig.local.template # Template for Git user credentials
├── .gitignore              # Ignores local keys, logs, and sensitive overrides
├── aliases.bash            # General terminal shortcuts
├── functions.bash          # Shell helper utilities (proj, gitwho, etc.)
├── install.sh              # One-step installer script
└── README.md               # Project documentation

## Quick Start

1. Clone the repository:
   git clone https://github.com/wieseknows/dotfiles.git ~/dotfiles
   cd ~/dotfiles

2. Create your local config files from templates:
   cp .bashrc.local.template .bashrc.local
   cp .gitconfig.local.template .gitconfig.local

3. Fill in your personal credentials and settings:

   - Edit `.bashrc.local` to set your API keys and SSH key paths:
     SSH_KEYS=(
         "C:/dev/private_key"
         "$HOME/.ssh/id_ed25519_personal"
     )
     export GEMINI_API_KEY="your_api_key_here"

   - Edit `.gitconfig.local` to set your Git identity:
     [user]
         name = Your Name
         email = your.email@example.com

4. Run the installation script:
   ./install.sh

5. Apply the configuration:
   source ~/.bashrc

## Key Commands

### Shell & Navigation Aliases
- `ll`, `la`, `l` — Detailed directory listings
- `c`, `cls` — Clear screen
- `..`, `...`, `....` — Navigate up directory tree
- `proj <target>` — Jump to predefined project directory (e.g., `proj syn`, `proj oms`)

### Git Aliases
- `git get` — Pull current branch and update submodules
- `git shr` — Push current branch to origin
- `git upd` — Stash, pull current branch, and apply stash
- `git snap` — Create a timestamped stash snapshot without wiping workspace
- `git cos <branch>` — Checkout branch and view status
- `git history` — Graphical single-line log format

## License

MIT