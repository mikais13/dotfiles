#!/usr/bin/env bash

# Pick a worktree of the current repo and open it as a tmux session.
dir_of_script=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source "$dir_of_script/fzf-theme.sh"

if ! worktrees=$(git worktree list --porcelain 2>/dev/null); then
    printf 'Not in a git repository: %s\n' "$PWD"
    read -rsn1 -p 'Press any key to close.'
    exit 0
fi

# Put the current worktree first, so the pointer starts on it.
current=$(git rev-parse --show-toplevel)
dir=$(sed -n 's/^worktree //p' <<<"$worktrees" |
    awk -v cur="$current" '$0 == cur { print; next } { rest[++n] = $0 } END { for (i = 1; i <= n; i++) print rest[i] }' |
    fzf --reverse --border=rounded --border-label=' Worktrees ' --prompt='Find: ' \
        --preview 'git -C {} log --oneline --color=always -15' \
        --preview-window='right,55%,border-left') || exit 0
exec "$dir_of_script/tmux-sessionizer.sh" "$dir"
