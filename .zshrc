# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Prompt: powerlevel10k
# Sourced from Homebrew rather than as an oh-my-zsh theme, so ZSH_THEME stays
# empty below. Run `p10k configure` to regenerate ~/.p10k.zsh.
source /opt/homebrew/opt/powerlevel10k/share/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Plugins: oh-my-zsh
# Plugins live in ~/.oh-my-zsh/custom/plugins as git clones.
# Order matters: fzf-tab must load before the plugins that wrap ZLE widgets
# (zsh-autosuggestions, zsh-syntax-highlighting).
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME=""  # powerlevel10k is sourced manually above instead
plugins=(fzf-tab zsh-autosuggestions zsh-completions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh

# Completion
# Case-insensitive matching and colours for the completion list.
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colours "${(s.:.)LS_COLORS}"

# fzf-tab replaces zsh's built-in menu, so that menu must stay off.
zstyle ':completion:*' menu no
# fzf-tab ignores FZF_DEFAULT_OPTS unless told otherwise, so opt in to keep
# Tab completion themed like the Ctrl-R and Ctrl-T widgets.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' switch-group '<' '>'

# History
HISTFILE=~/.zsh_history
HISTSIZE=5000
SAVEHIST=$HISTSIZE
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space      # keep commands that start with a space out
setopt hist_ignore_all_dups   # drop older duplicates of a repeated command
setopt hist_save_no_dups      # do not write duplicates to HISTFILE
setopt hist_find_no_dups      # skip duplicates while searching

# Key bindings
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# Aliases
alias cc="claude"
alias cc-dsp="claude --dangerously-skip-permissions"
alias oc="opencode"
alias oc-a="opencode --auto"
alias cx="codex"
alias cx-a="codex --approve-for-me"
alias v="nvim"
alias ls='ls --color'

# Tool setup
# These set PATH, so the shell integrations below must come after them.
# Keep this order: Homebrew is prepended after nvm and pyenv, so it wins for
# node and python. Changing the order changes which binary the shell picks.

# conda
# The /opt/anaconda3 executable is currently missing, so this hook fails fast
# and falls through. Kept for a future reinstall.
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
[ -s "$BUN_INSTALL/_bun" ] && source "$BUN_INSTALL/_bun"  # bun completions

# envman
# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - zsh)"

# pnpm
export PNPM_HOME="/Users/mikaisomerville/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

# homebrew
export PATH="/opt/homebrew/bin:$PATH"

# java
export JAVA_HOME=$(brew --prefix openjdk@21)
export PATH="$JAVA_HOME/bin:$PATH"

# terraform
autoload -U +X bashcompinit && bashcompinit
complete -o nospace -C /opt/homebrew/bin/terraform terraform

# libpq
export PATH="/opt/homebrew/opt/libpq/bin:$PATH"

# Shell integrations
# fzf: `fzf --zsh` emits both the completion and key-binding integrations,
# so neither shell/ file needs a separate source. It runs after oh-my-zsh so
# that it detects fzf-tab on Tab and keeps it as the fallback completer.
[[ -f ~/dotfiles/tmux/scripts/fzf-theme.sh ]] && source ~/dotfiles/tmux/scripts/fzf-theme.sh
eval "$(fzf --zsh)"

# zoxide, replacing cd
eval "$(zoxide init --cmd cd zsh)"
