# Dotfiles

My personal configuration files for development tools and environments.

## What's Included

### Shell
- **Zsh** - Main shell configuration (`.zshrc`)
- **Bash** - Bash profile and RC files
- **Oh My Zsh** - Custom themes and plugins (referenced in shell config)

### Editors
- **Vim** - `.vimrc` and `.vim/` directory
- **Neovim** - Complete nvim configuration
- **Zed** - Zed editor settings
- **VS Code** - Settings, keybindings, snippets, and MCP configuration

### Terminal
- **Zellij** - Terminal multiplexer configuration
- **Ghostty** - Ghostty terminal emulator settings
- **Kitty** - Kitty terminal configuration (if used)

### Tools
- **Git** - Global git configuration and GitHub CLI settings
- **Claude** - Claude CLI configuration and custom settings
- **pi** - [pi coding agent](https://www.npmjs.com/package/@earendil-works/pi-coding-agent) subagent definitions (planner / reviewer / worker / scout) wired to `jf-localdev-*` Bedrock application inference profiles for cost attribution
- **Agent context** - `AGENTS.md`, `USER.md`, and `MODEL_ROUTING.md` symlinked into `$HOME` so coding agents (pi, Claude Code, etc.) pick up consistent instructions
- **AWS** - AWS CLI configuration (regions, SSO settings)
- **SSH** - SSH client configuration
- **Keyboard Maestro** - Custom macros and automation
- **Rectangle Pro** - Window management configuration

## Installation

### Quick Install

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The install script will:
1. Backup your existing configurations to `~/.dotfiles_backup_TIMESTAMP`
2. Create symlinks from your home directory to this repo
3. Preserve your original files safely

### Manual Installation

If you prefer to install configurations selectively:

```bash
# Shell
ln -s ~/dotfiles/shell/.zshrc ~/.zshrc

# Vim
ln -s ~/dotfiles/vim/.vimrc ~/.vimrc
ln -s ~/dotfiles/vim/.vim ~/.vim

# Neovim
ln -s ~/dotfiles/nvim ~/.config/nvim

# Git
ln -s ~/dotfiles/git/.gitconfig ~/.gitconfig

# Add others as needed...
```

## Post-Installation

### Required Manual Setup

Some sensitive files are not included in this repo and need manual setup:

1. **AWS Credentials**
   ```bash
   # Create ~/.aws/credentials with your access keys
   # This file is excluded from the repo for security
   ```

2. **SSH Keys**
   ```bash
   # Generate new keys or copy existing ones
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```

3. **Kubernetes Config**
   ```bash
   # Set up your kubectl contexts manually
   # ~/.kube/config contains sensitive cluster certificates
   ```

4. **Databricks**
   ```bash
   # Configure databricks CLI
   databricks configure --token
   ```

### Apply Changes

After installation, reload your shell:

```bash
source ~/.zshrc  # or source ~/.bash_profile
```

## Maintenance

### Updating Dotfiles

When you make changes to your configs, commit and push:

```bash
cd ~/dotfiles
git add .
git commit -m "Update configuration"
git push
```

### Syncing to a New Machine

```bash
git clone https://github.com/YOUR_USERNAME/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

Then complete the manual setup steps above.

## Structure

```
dotfiles/
├── shell/              # Shell configurations
├── vim/                # Vim configuration
├── nvim/               # Neovim configuration
├── zed/                # Zed editor
├── vscode/             # VS Code settings
├── terminal/           # Terminal emulators and multiplexers
│   ├── zellij/
│   ├── ghostty/
│   └── kitty/
├── git/                # Git and GitHub CLI
├── claude/             # Claude CLI
├── pi/                 # pi coding agent subagent definitions
│   └── agent/agents/   # planner, reviewer, worker, scout (symlinked into ~/.pi/agent/agents/)
├── AGENTS.md           # Top-level agent instructions (symlinked to ~/AGENTS.md)
├── USER.md             # Personal/professional context for agents (symlinked to ~/USER.md)
├── MODEL_ROUTING.md    # Which model tier to use for which agent role (symlinked to ~/MODEL_ROUTING.md)
├── aws/                # AWS CLI config
├── ssh/                # SSH config
├── keyboard-maestro/   # Keyboard Maestro macros
├── rectangle-pro/      # Rectangle Pro window management
├── .gitignore          # Excludes sensitive files
├── install.sh          # Installation script
└── README.md           # This file
```

## Security

This repository uses `.gitignore` to exclude sensitive files:
- AWS credentials
- SSH private keys
- Kubernetes certificates
- API tokens and secrets
- Shell history files

**Always review changes before committing to ensure no secrets are included.**

## Tools Used

- [Oh My Zsh](https://ohmyz.sh/) - Zsh framework
- [Neovim](https://neovim.io/) - Hyperextensible Vim-based text editor
- [Zed](https://zed.dev/) - High-performance code editor
- [Zellij](https://zellij.dev/) - Terminal multiplexer
- [Ghostty](https://ghostty.org/) - Terminal emulator
- [Claude](https://claude.com/) - AI assistant CLI

## License

Feel free to use and modify as needed.
