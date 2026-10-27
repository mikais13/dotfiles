
export VOLTA_HOME="$HOME/.volta"
export PATH="$VOLTA_HOME/bin:$PATH"
. "$HOME/.cargo/env"

# Agents run non-interactive shells. Keep unmatched globs as text, like bash.
[[ -o interactive ]] || setopt no_nomatch
