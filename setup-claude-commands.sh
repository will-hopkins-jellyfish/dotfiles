#!/bin/bash
# Script to symlink Claude commands from dotfiles to home directory

DOTFILES_DIR="$HOME/code/dotfiles"
CLAUDE_DIR="$HOME/.claude"

# Create .claude directory in home if it doesn't exist
mkdir -p "$CLAUDE_DIR"

# Symlink the commands directory
if [ -d "$DOTFILES_DIR/.claude/commands" ]; then
    if [ -L "$CLAUDE_DIR/commands" ]; then
        echo "Symlink already exists for commands directory"
    elif [ -d "$CLAUDE_DIR/commands" ]; then
        echo "Warning: $CLAUDE_DIR/commands exists as a regular directory"
        echo "Please backup and remove it, then run this script again"
    else
        ln -s "$DOTFILES_DIR/.claude/commands" "$CLAUDE_DIR/commands"
        echo "Created symlink: $CLAUDE_DIR/commands -> $DOTFILES_DIR/.claude/commands"
    fi
fi

# If you have skills, do the same
if [ -d "$DOTFILES_DIR/.claude/skills" ]; then
    if [ -L "$CLAUDE_DIR/skills" ]; then
        echo "Symlink already exists for skills directory"
    elif [ -d "$CLAUDE_DIR/skills" ]; then
        echo "Warning: $CLAUDE_DIR/skills exists as a regular directory"
        echo "Please backup and remove it, then run this script again"
    else
        ln -s "$DOTFILES_DIR/.claude/skills" "$CLAUDE_DIR/skills"
        echo "Created symlink: $CLAUDE_DIR/skills -> $DOTFILES_DIR/.claude/skills"
    fi
fi

echo "Setup complete!"
