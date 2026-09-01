#!/usr/bin/env bash

# tmux-sessionizer: fuzzy-find a running tmux session or a project directory
# and switch to it. One picker: curated dirs + live sessions by default,
# ctrl-f widens to a filesystem walk, ctrl-n makes a session from the typed
# path. Edit the dir list in --list / the roots in --walk to change scope.

IGNORE='node_modules|dist|build|out|target|.next|.nuxt|.cache|public|cache|paste-cache|debug|file-history|downloads|backups|session-env|sessions|shell-snapshots|telemetry|daemon|jobs|chrome|channels|ide|plans|tasks'

self=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")

source "$(dirname "$self")/fzf-theme.sh"

# tmux session name for a directory: the leaf, plus "__<parent>" when the
# dir isn't directly under $HOME, so ~/a/api and ~/b/api don't collide.
session_name() {
    local dir=${1%/}
    local leaf parent
    leaf=$(basename "$dir")
    parent=$(dirname "$dir")
    [[ $parent != "$HOME" ]] && leaf="${leaf}__$(basename "$parent")"
    printf '%s' "${leaf//[.: ]/_}"
}

open_dir() {
    local dir=$1
    [[ -z $dir ]] && exit 0
    local name
    name=$(session_name "$dir")

    # not inside tmux AND no server running -> start a fresh session
    if [[ -z $TMUX ]] && ! tmux list-sessions &>/dev/null; then
        tmux new-session -s "$name" -c "$dir"
        exit 0
    fi

    # create it detached if missing, then switch the current client to it
    tmux has-session -t="$name" 2>/dev/null || tmux new-session -ds "$name" -c "$dir"
    tmux switch-client -t "$name"
}

# ---- self-dispatched subcommands (called by fzf for its source/preview) ----

# rows are TAB-delimited: <kind>\t<field shown>\t<path>
if [[ $1 == --list ]]; then
    # live sessions first, then curated dirs; awk drops a curated dir whose
    # path already appeared as a session (seen[] is seeded by the session rows)
    {
        tmux list-sessions -F $'session\t#S\t#{session_path}' 2>/dev/null
        for dir in "$HOME/dotfiles" "$HOME/.claude" "$HOME"/localdocs/*/; do
            [[ -d $dir ]] && printf 'dir\t%s\t%s\n' "${dir%/}" "${dir%/}"
        done
    } | awk -F'\t' '!seen[$3]++'
    exit 0
fi

if [[ $1 == --walk ]]; then
    # broader browse, still narrow on purpose: $HOME top level + a deeper
    # walk of ~/Documents, hidden dirs and IGNORE names pruned
    { find "$HOME" -mindepth 1 -maxdepth 1 -type d -name '.*' -prune -o -type d -print
      find "$HOME/Documents" -mindepth 1 -maxdepth 4 -type d -name '.*' -prune -o -type d -print
    } 2>/dev/null | grep -Ev "/($IGNORE)(/|$)" \
        | while IFS= read -r dir; do printf 'dir\t%s\t%s\n' "$dir" "$dir"; done
    exit 0
fi

if [[ $1 == --preview ]]; then
    kind=$2 name=$3 path=$4
    if [[ $kind == session ]]; then
        echo '── windows ──'
        tmux list-windows -t "$name" -F '#I: #W'
        echo
        echo '── tree ──'
    fi
    tree -C -L 2 -I "$IGNORE" "$path" 2>/dev/null || ls -la "$path"
    exit 0
fi

# ---- main ---------------------------------------------------------------

# a path passed directly on the command line -> skip the picker
[[ $# -eq 1 && $1 != --* ]] && { open_dir "$1"; exit 0; }

out=$("$self" --list | fzf \
    --reverse \
    --border=rounded \
    --border-label=" sessionizer " \
    --border-label-pos=center \
    --prompt='  ' \
    --pointer='▶' \
    --header='enter: open · ctrl-f: browse all dirs · ctrl-r: back · ctrl-n: new from query' \
    --delimiter=$'\t' \
    --with-nth=2 \
    --print-query \
    --expect=ctrl-n \
    --bind="ctrl-f:reload($self --walk)" \
    --bind="ctrl-r:reload($self --list)" \
    --preview="$self --preview {1} {2} {3}" \
    --preview-window='right,55%,border-left')

# --expect + --print-query -> line 1 = key pressed, 2 = query, 3 = chosen row
{ IFS= read -r key; IFS= read -r query; IFS= read -r row; } <<< "$out"

if [[ $key == ctrl-n ]]; then
    # create a session at the typed path (~ and relative paths resolved)
    [[ -z $query ]] && exit 0
    dir=${query/#\~/$HOME}
    [[ $dir != /* ]] && dir="$HOME/$dir"
    mkdir -p "$dir"
    open_dir "$dir"
    exit 0
fi

[[ -z $row ]] && exit 0   # ESC / no selection
IFS=$'\t' read -r kind name path <<< "$row"
case $kind in
    session) tmux switch-client -t "$name" ;;
    dir)     open_dir "$path" ;;
esac
