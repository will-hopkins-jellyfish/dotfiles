eval "$(/opt/homebrew/bin/brew shellenv)"
eval "$(/usr/local/bin/brew shellenv)"
export JF_MANAGED_HOMEBREW=true


export DIRENV_LOG_FORMAT=''
eval "$(direnv hook bash)"

export PATH="$HOME/.pyenv/shims:$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init --path)"
. "$HOME/.cargo/env"
