#!/bin/bash

# Dotfiles Installation Script
# This script creates symlinks from your home directory to the dotfiles repo

set -e

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DIR="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"

echo "🚀 Installing dotfiles from $DOTFILES_DIR"
echo ""

# Function to create a symlink with backup
create_symlink() {
    local source="$1"
    local target="$2"

    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "$target")"

    # Backup existing file/directory if it exists and is not a symlink
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        echo "  📦 Backing up existing $target"
        mkdir -p "$BACKUP_DIR"
        mv "$target" "$BACKUP_DIR/"
    fi

    # Remove existing symlink
    if [ -L "$target" ]; then
        rm "$target"
    fi

    # Create new symlink
    echo "  🔗 Linking $target → $source"
    ln -s "$source" "$target"
}

echo "📝 Setting up shell configurations..."
create_symlink "$DOTFILES_DIR/shell/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/shell/.bash_profile" "$HOME/.bash_profile"
create_symlink "$DOTFILES_DIR/shell/.bashrc" "$HOME/.bashrc"

echo ""
echo "✏️  Setting up vim and neovim..."
create_symlink "$DOTFILES_DIR/vim/.vimrc" "$HOME/.vimrc"
create_symlink "$DOTFILES_DIR/vim/.vim" "$HOME/.vim"
create_symlink "$DOTFILES_DIR/nvim" "$HOME/.config/nvim"

echo ""
echo "🎨 Setting up editors..."
create_symlink "$DOTFILES_DIR/zed" "$HOME/.config/zed"
create_symlink "$DOTFILES_DIR/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
if [ -f "$DOTFILES_DIR/vscode/mcp.json" ]; then
    create_symlink "$DOTFILES_DIR/vscode/mcp.json" "$HOME/Library/Application Support/Code/User/mcp.json"
fi
if [ -d "$DOTFILES_DIR/vscode/snippets" ]; then
    create_symlink "$DOTFILES_DIR/vscode/snippets" "$HOME/Library/Application Support/Code/User/snippets"
fi

echo ""
echo "🖥️  Setting up terminal configurations..."
create_symlink "$DOTFILES_DIR/terminal/zellij" "$HOME/.config/zellij"
create_symlink "$DOTFILES_DIR/terminal/ghostty" "$HOME/Library/Application Support/com.mitchellh.ghostty"
if [ -d "$DOTFILES_DIR/terminal/kitty" ]; then
    create_symlink "$DOTFILES_DIR/terminal/kitty" "$HOME/.config/kitty"
fi

echo ""
echo "🔧 Setting up git..."
create_symlink "$DOTFILES_DIR/git/.gitconfig" "$HOME/.gitconfig"
if [ -d "$DOTFILES_DIR/git/gh" ]; then
    create_symlink "$DOTFILES_DIR/git/gh" "$HOME/.config/gh"
fi
if [ -d "$DOTFILES_DIR/git/config" ]; then
    create_symlink "$DOTFILES_DIR/git/config" "$HOME/.config/git"
fi

echo ""
echo "🤖 Setting up Claude..."
create_symlink "$DOTFILES_DIR/claude/.claude.json" "$HOME/.claude.json"
create_symlink "$DOTFILES_DIR/claude/config" "$HOME/.claude"

echo ""
echo "☁️  Setting up cloud configurations..."
create_symlink "$DOTFILES_DIR/aws/config" "$HOME/.aws/config"
if [ -f "$DOTFILES_DIR/ssh/config" ]; then
    create_symlink "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
fi

echo ""
echo "⌨️  Setting up Keyboard Maestro..."
if [ -f "$DOTFILES_DIR/keyboard-maestro/Keyboard Maestro Macros.plist" ]; then
    create_symlink "$DOTFILES_DIR/keyboard-maestro/Keyboard Maestro Macros.plist" "$HOME/Library/Application Support/Keyboard Maestro/Keyboard Maestro Macros.plist"
fi

echo ""
echo "🪟 Setting up Rectangle Pro..."
if [ -d "$DOTFILES_DIR/rectangle-pro" ]; then
    for file in "$DOTFILES_DIR/rectangle-pro"/*.padl "$DOTFILES_DIR/rectangle-pro"/*.spadl; do
        if [ -f "$file" ]; then
            create_symlink "$file" "$HOME/Library/Application Support/Rectangle Pro/$(basename "$file")"
        fi
    done
fi

echo ""
echo "🤖 Setting up pi coding agent harness..."
# pi looks for subagent definitions under ~/.pi/agent/agents/. Symlink each agent
# file individually so a `pi update` (which can replace files in this directory)
# only ever touches its own files, never our dotfiles content.
for agent_file in "$DOTFILES_DIR"/pi/agent/agents/*.md; do
    if [ -f "$agent_file" ]; then
        create_symlink "$agent_file" "$HOME/.pi/agent/agents/$(basename "$agent_file")"
    fi
done

echo ""
echo "📜 Setting up agent context files (AGENTS.md, USER.md, MODEL_ROUTING.md)..."
create_symlink "$DOTFILES_DIR/AGENTS.md" "$HOME/AGENTS.md"
create_symlink "$DOTFILES_DIR/USER.md" "$HOME/USER.md"
create_symlink "$DOTFILES_DIR/MODEL_ROUTING.md" "$HOME/MODEL_ROUTING.md"

echo ""
echo "✅ Dotfiles installation complete!"
echo ""
if [ -d "$BACKUP_DIR" ]; then
    echo "📦 Your original files have been backed up to: $BACKUP_DIR"
    echo ""
fi

echo "⚠️  IMPORTANT: Some configurations require manual setup:"
echo "  • AWS credentials: Set up ~/.aws/credentials manually"
echo "  • SSH keys: Generate or copy your SSH keys to ~/.ssh/"
echo "  • Kubernetes: Set up ~/.kube/config manually"
echo "  • Databricks: Set up ~/.databrickscfg manually"
echo ""
echo "🔄 Restart your shell or run 'source ~/.zshrc' to apply changes"
