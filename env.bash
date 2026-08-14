# Determine the directory where this script is stored
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Setting up dotfiles from $DOTFILES_DIR..."

# Symlink .bashrc
if [ -f "$HOME/.bashrc" ]; then
    echo "Backing up existing .bashrc to .bashrc.bak"
    mv "$HOME/.bashrc" "$HOME/.bashrc.bak"
fi
ln -sf "$DOTFILES_DIR/.bashrc" "$HOME/.bashrc"
echo "Linked .bashrc"

# Symlink .gitconfig
if [ -f "$HOME/.gitconfig" ]; then
    echo "Backing up existing .gitconfig to .gitconfig.bak"
    mv "$HOME/.gitconfig" "$HOME/.gitconfig.bak"
fi
ln -sf "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
echo "Linked .gitconfig"

# Create .bashrc.local if it doesn't exist
if [ ! -f "$HOME/.bashrc.local" ]; then
    cp "$DOTFILES_DIR/.bashrc.local.template" "$HOME/.bashrc.local"
    echo "Created .bashrc.local from template. Please update it with your secrets!"
fi

echo "Dotfiles setup complete! Restart your terminal or run: source ~/.bashrc"