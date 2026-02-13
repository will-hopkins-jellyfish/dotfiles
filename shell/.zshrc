# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="alanpeabody"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?

# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(1password aws battery docker gh git iterm2 pip pipenv postgres pyenv python tmux)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias p='pdm run'
alias m='p python manage.py'
alias t='p pytest --reuse-db --ds=jellyfish.settings.test'
alias rnd='m remotedb -s jf-prd-rnd-db'

export SOURCE_CODE_DIR=~/code

export DIRENV_LOG_FORMAT=''
eval "$(direnv hook zsh)"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

export TEAM_STAGE_ENV="http://jf-stg-sandbox-ro-1-db.crxkcfv1g61a.us-east-1.rds.amazonaws.com/"

# Created by `pipx` on 2024-07-16 18:47:26
export PATH="$PATH:/Users/willhopkins/.local/bin"

jelly-ssh () {
  pushd ~-jellyfish
  scripts/ssh -k ~/.ssh/id_ed25519 "$@"
  popd
}

unalias sso 2>/dev/null || true
sso () {
	local profile="${1:-default}"
	aws sso logout --profile "$profile" && aws sso login --profile "$profile"
}
alias dbpw='aws secretsmanager get-secret-value --secret-id $DB_CREDS_SECRET_ARN --output json'
alias tfshow='terraform show -no-color plan.out | pbcopy'

export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# SECURITY: Set your GitHub token manually or use gh CLI auth
# export GITHUB_AUTH_TOKEN=your_token_here

# Steve's worktree functions
# create work tree
# use it like this: $ wt feature-branch-name
wt() {
	# exit immediately on error
	# set -e

	# exit function immediately on error
	setopt LOCAL_OPTIONS ERR_EXIT

	# get the current git project directory (must be inside a git repo)
	local project_dir=$(git rev-parse --show-toplevel)

	# get the base name of the current porject folder
	local project_name=$(basename "$project_dir")

	# get the desired feature/branch name from the first argument
	local feature_branch_name="$1"

	# fail fast if no feature/branch name was provided
	if [ -z "$feature_branch_name" ]; then 
		echo "X no <feature_branch_name> provided"
		return 0
	fi

	# check if branch already exists
	if git -C "$project_dir" show-ref --verify --quiet "refs/heads/$feature_branch_name"; then
		echo "X branch '$feature_branch_name' already exists"
		return 0
	fi

	# define the parent folder where all worktrees go, beside the main repo
	local worktree_parent="$(dirname "$project_dir")/${project_name}-worktrees"

	# define the full path for the new worktree folder
	local worktree_path="${worktree_parent}/${feature_branch_name}"

	# create the parent worktree folder if it doesn't exist
	mkdir -p "$worktree_parent"

	# create the worktree and branch
	git -C "$project_dir" worktree add -b "$feature_branch_name" "$worktree_path"

	# list of files to copy over to worktree
	local untracked_files=(Claude.md .secrets.yaml .npmrc .envrc)

	# copy some untracked files over to new worktree folder
	for f in "${untracked_files[@]}"; do
		if [ -f "$project_dir/$f" ]; then
			cp "$project_dir/$f" "$worktree_path/$f"
			echo "Copied file $f into worktree"
		fi
	done

	 # conditionally copy db_url if it exists (for remote db connections)
	if [ -f "$project_dir/jellyfish/settings/db_url" ]; then
		mkdir -p "$worktree_path/jellyfish/settings"
		cp "$project_dir/jellyfish/settings/db_url" "$worktree_path/jellyfish/settings/db_url"
		echo "Copied jellyfish/settings/db_url into worktree (remote db config)"
	fi

	# list of hidden folders to copy over
	local hidden_dir=(.claude)

	# copy some untracked files over to new worktree folder
	for dir in "${hidden_dir[@]}"; do
		if [ -d "$project_dir/$dir" ]; then
			cp -R "$project_dir/$dir" "$worktree_path/$dir"
			echo "Copied directory $dir into worktree"
		fi
	done

	# open a new tab, and cd into the  new worktree
	runInNewTab "cd $worktree_path && direnv allow && echo '\n✓ Direnv allowed. \nEnvironment loaded. \nRun: pdm install && nvm use && npm ci'"
}


# alist to list work trees 
alias wt_list="git worktree list"


# cleanup work tree(s) [note: does not clean up branch, just worktree]
# can be used to clean up a single worktree or all worktrees 
# $ wt_delete feature-branch-name
# $ wt_delete all
# $ wt_delete --force feature-branch-name
# $ wt_delete --force all
wt_delete() {
    # DON'T use ERR_EXIT - handle errors explicitly instead
    # This prevents the shell from terminating on git errors

    # get the current git project directory (must be inside a git repo)
    local project_dir=$(git rev-parse --show-toplevel)

    # get the base name of the current porject folder
    local project_name=$(basename "$project_dir")

    # parse arguments for --force flag
    local force_flag=""
    local first_argument=""

    if [[ "$1" == "--force" ]]; then
        force_flag="--force"
        first_argument="$2"
    else
        first_argument="$1"
    fi

    # fail fast if no feature/branch name was provided
    if [ -z "$first_argument" ]; then
        echo "X no argument provided"
        return 0
    fi

    # get all worktrees as an ARRAY using zsh globbing
    local all_worktree_names=()
    for dir in ${project_dir}-worktrees/*(N:t); do
        all_worktree_names+=($dir)
        # echo "$all_worktree_names" -- debug, see worktrees array as it's being built
    done

    # determine which worktrees to cleanup
    if [[ "$first_argument" == "all" ]]; then
        echo "cleaning up all worktrees"
          # get worktree directories
        local worktrees_to_cleanup=($all_worktree_names)
    else
        # check the provided worktree is a valid one
        if [[ ${all_worktree_names[(ie)$first_argument]} -le ${#all_worktree_names} ]]; then
            local worktrees_to_cleanup=($first_argument)
        else
            echo "X provided worktree '$first_argument' not in list of all worktrees:"
            printf '  %s\n' "* ${all_worktree_names[@]}"
            return 0
        fi
    fi

    # give user feedback on what's about to happen
    echo "about to cleanup worktrees:"
    printf '  * %s\n' "${worktrees_to_cleanup[@]}"
    [[ -n "$force_flag" ]] && echo "(using --force)"

    # remove worktrees with error handling
    local failed_removals=()
    for wt in "${worktrees_to_cleanup[@]}"; do
        if git worktree remove $force_flag "$wt" 2>/dev/null; then
            echo "✓ removed worktree $wt"
        else
            echo "✗ failed to remove worktree $wt (may have uncommitted changes)"
            failed_removals+=($wt)
        fi
    done

    # Report any failures
    if [[ ${#failed_removals[@]} -gt 0 ]]; then
        echo "\nFailed to remove ${#failed_removals[@]} worktree(s):"
        printf '  * %s\n' "${failed_removals[@]}"
        echo "Use 'git worktree remove --force <name>' to force removal"
        return 1
    fi

    echo "\n✓ Successfully cleaned up all worktrees"
}


# move current branch to a worktree
# use it like this: $ wt_move
wt_move() {
    # DON'T use ERR_EXIT - handle errors explicitly instead

    # get the current git project directory (must be inside a git repo)
    local project_dir=$(git rev-parse --show-toplevel)
    if [ $? -ne 0 ]; then
        echo "X not in a git repository"
        return 1
    fi

    # get the base name of the current project folder
    local project_name=$(basename "$project_dir")

    # get the current branch name
    local current_branch=$(git branch --show-current)

    # fail fast if on develop already
    if [ "$current_branch" = "develop" ]; then
        echo "X already on develop, nothing to move"
        return 0
    fi

    # fail fast if in detached HEAD state
    if [ -z "$current_branch" ]; then
        echo "X cannot move detached HEAD state"
        return 0
    fi

    # define the parent folder where all worktrees go
    local worktree_parent="$(dirname "$project_dir")/${project_name}-worktrees"

    # define the full path for the new worktree folder
    local worktree_path="${worktree_parent}/${current_branch}"

    # check if worktree already exists
    if [ -d "$worktree_path" ]; then
        echo "X worktree for branch '$current_branch' already exists at:"
        echo "  $worktree_path"
        echo "Either work from that worktree, or delete it and try again"
        return 0
    fi

    # check for uncommitted changes
    local git_status=$(git status --porcelain)
    if [ -n "$git_status" ]; then
        echo "Uncommitted changes detected:"
        echo ""
        git status
        echo ""
        echo -n "These changes will be lost. Continue? (y/N): "
        read response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "✓ Cancelled. Commit or stash your changes, then try again."
            return 0
        fi
    fi

    # create the parent worktree folder if it doesn't exist
    mkdir -p "$worktree_parent"

    # switch main repo to develop FIRST (this is the key difference)
    echo "Switching main repo to develop..."
    git checkout develop 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "X failed to checkout develop"
        return 1
    fi

    # NOW create the worktree (branch already exists, so no -b flag)
    echo "Creating worktree for '$current_branch'..."
    git worktree add "$worktree_path" "$current_branch" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "X failed to create worktree"
        return 1
    fi

    # list of files to copy over to worktree
    local untracked_files=(Claude.md .secrets.yaml .npmrc .envrc)

    # copy some untracked files over to new worktree folder
    for f in "${untracked_files[@]}"; do
        if [ -f "$project_dir/$f" ]; then
            cp "$project_dir/$f" "$worktree_path/$f"
            echo "Copied file $f into worktree"
        fi
    done

    # conditionally copy db_url if it exists (for remote db connections)
    if [ -f "$project_dir/jellyfish/settings/db_url" ]; then
        mkdir -p "$worktree_path/jellyfish/settings"
        cp "$project_dir/jellyfish/settings/db_url" "$worktree_path/jellyfish/settings/db_url"
        echo "Copied jellyfish/settings/db_url into worktree (remote db config)"
    fi

    # list of hidden folders to copy over
    local hidden_dir=(.claude)

    # copy some untracked files over to new worktree folder
    for dir in "${hidden_dir[@]}"; do
        if [ -d "$project_dir/$dir" ]; then
            cp -R "$project_dir/$dir" "$worktree_path/$dir"
            echo "Copied directory $dir into worktree"
        fi
    done

    # open a new tab, and cd into the new worktree
    runInNewTab "cd $worktree_path && direnv allow && echo '\n✓ Direnv allowed. \nEnvironment loaded. \nRun: pdm install && nvm
 use && npm ci'"

    echo "✓ Moved branch '$current_branch' to worktree"
    echo "✓ Main repo switched to develop"
}

export CLAUDE_CODE_USE_BEDROCK=1
# The anthropic model will occasionally change. Check this page every now and then!
export ANTHROPIC_DEFAULT_OPUS_MODEL=arn:aws:bedrock:us-east-1:686150682967:application-inference-profile/1nil8tuydhgz
export ANTHROPIC_DEFAULT_SONNET_MODEL=arn:aws:bedrock:us-east-1:686150682967:application-inference-profile/5siz04xlqq9g
export ANTHROPIC_DEFAULT_HAIKU_MODEL=arn:aws:bedrock:us-east-1:686150682967:application-inference-profile/vgz4zbsrb75u
