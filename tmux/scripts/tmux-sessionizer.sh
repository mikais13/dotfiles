#!/usr/bin/env bash

# Fuzzy session/project search with directory navigation in the same picker.
IGNORE='.git|node_modules|dist|build|out|target|.next|.nuxt|.cache|public|cache|paste-cache|debug|file-history|downloads|backups|session-env|sessions|shell-snapshots|telemetry|daemon|jobs|chrome|channels|ide|plans|tasks'
# Resolve relative paths from the current directory, regardless of shell setup.
CDPATH=
self=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")
source "$(dirname "$self")/fzf-theme.sh"

session_name() {
    local dir=${1%/} leaf parent
    leaf=$(basename "$dir")
    parent=$(dirname "$dir")
    [[ $parent != "$HOME" ]] && leaf="${leaf}__$(basename "$parent")"
    printf '%s' "${leaf//[.: ]/_}"
}

connect_session() {
    if [[ -n $TMUX ]]; then
        tmux switch-client -t "$1"
    else
        tmux attach-session -t "$1"
    fi
}

open_dir() {
    local dir name base id existing suffix=2
    dir=$(cd -- "$1" && pwd -P) || return 1
    # Reuse a session by path, not by its generated name.
    while IFS=$'\t' read -r id existing; do
        if [[ $existing == "$dir" ]]; then
            connect_session "$id"
            return
        fi
    done < <(tmux list-sessions -F $'#{session_id}\t#{session_path}' 2>/dev/null)
    base=$(session_name "$dir")
    name=$base
    while tmux has-session -t "=$name" 2>/dev/null; do
        name="${base}_${suffix}"
        ((suffix++))
    done
    id=$(tmux new-session -dP -F '#{session_id}' -s "$name" -c "$dir") || return
    connect_session "$id"
}

# Rows: kind, name, absolute path, session ID (or '-' for directories).
dir_row() {
    printf 'dir\t%s\t%s\t-\n' "$1" "$2"
}

list_rows() {
    local mode=$1 root dir entry
    local prune=() ignored
    {
        tmux list-sessions -F $'session\t#{session_name}\t#{session_path}\t#{session_id}' 2>/dev/null
        if [[ $mode == --walk ]]; then
            IFS='|' read -r -a ignored <<< "$IGNORE"
            for entry in "${ignored[@]}"; do
                [[ ${#prune[@]} -gt 0 ]] && prune+=(-o)
                prune+=(-name "$entry")
            done
            # Explicit hidden roots are included; costly generated dirs are pruned.
            for root in "$HOME/localdocs" "$HOME/Documents" "$HOME/dotfiles" "$HOME/.claude" "$HOME/.agents"; do
                [[ -d $root ]] || continue
                while IFS= read -r dir; do
                    dir_row "${dir##*/}" "$dir"
                done < <(find -H "$root" -type d \( "${prune[@]}" \) -prune -o -type d -print 2>/dev/null)
            done
        else
            for dir in "$HOME" "$HOME/Documents" "$HOME/dotfiles" "$HOME/.claude" "$HOME/.agents" "$HOME"/localdocs/*/; do
                dir=${dir%/}
                [[ -d $dir ]] && dir_row "${dir##*/}" "$dir"
            done
        fi
    } | awk -F'\t' '$1 == "session" { seen[$3] = 1; print; next } !seen[$3]++'
}

browse_rows() {
    local dir
    dir_row . "$1"
    # Include hidden directories and symlinks here so manual navigation is unrestricted.
    for dir in "$1"/* "$1"/.[!.]* "$1"/..?*; do
        [[ -d $dir ]] && dir_row "${dir##*/}" "$dir"
    done
    return 0
}

prompt_value() {
    local out
    out=$(printf '\n' | fzf --disabled --print-query --query="$2" \
        --prompt="$1: " --header='Enter: continue | Esc: cancel' --preview-window=hidden) || return 1
    printf '%s' "${out%%$'\n'*}"
}

new_session() {
    local base=$1 dir name id choice
    dir=$(prompt_value 'Directory' "$base") || return 1
    [[ -n $dir ]] || return 1
    case $dir in
        '~') dir=$HOME ;;
        '~/'*) dir="$HOME/${dir:2}" ;;
        /*) ;;
        *) dir="$base/$dir" ;;
    esac
    if [[ $dir == *$'\t'* || $dir == *$'\n'* ]]; then
        notice='Directory paths cannot contain tabs or newlines.'
        return 1
    fi
    name=$(prompt_value 'Session name' "$(session_name "$dir")") || return 1
    if [[ -z $name || $name == *[.:]* || $name == *$'\t'* || $name == *$'\n'* ]]; then
        notice='Use a nonempty session name without dots, colons, tabs, or newlines.'
        return 1
    fi
    if tmux has-session -t "=$name" 2>/dev/null; then
        notice="Session already exists: $name. Choose another name."
        return 1
    fi
    choice=$(printf 'Cancel\nCreate\n' | fzf --prompt='Confirm: ' \
        --header="New session: $name
Directory: $dir
Missing directories will be created." --preview-window=hidden) || return 1
    [[ $choice == Create ]] || return 1
    mkdir -p -- "$dir" || { notice="Cannot create directory: $dir"; return 1; }
    dir=$(cd -- "$dir" && pwd -P) || return 1
    id=$(tmux new-session -dP -F '#{session_id}' -s "$name" -c "$dir") || {
        notice="Cannot create session: $name"
        return 1
    }
    connect_session "$id"
}

# Allow regression tests to call functions without launching the picker.
[[ ${BASH_SOURCE[0]} != "$0" ]] && return

case ${1:-} in
    --list|--walk) list_rows "$1"; exit ;;
    --browse) browse_rows "$2"; exit ;;
    --preview)
        if [[ $2 == session ]]; then
            printf '%s\n' '-- windows --'
            tmux list-windows -t "$4" -F '#I: #W'
            printf '\n%s\n' '-- tree --'
        fi
        tree -a -C -L 2 -I "$IGNORE" -- "$3" 2>/dev/null || ls -la -- "$3"
        exit ;;
esac

[[ $# -eq 1 && $1 != --* ]] && { open_dir "$1"; exit $?; }

mode=--list
current=$HOME
query=
notice=
# fzf executes previews through a shell; quote the script path as well as fields.
printf -v preview '%q --preview {1} {3} {4}' "$self"
while :; do
    if [[ $mode == --browse ]]; then
        label="Browse: $current"
    elif [[ $mode == --walk ]]; then
        label='Search: project roots + live sessions'
    else
        label='Sessions + projects'
    fi
    out=$(
        if [[ $mode == --browse ]]; then browse_rows "$current"; else list_rows "$mode"; fi |
        fzf --reverse --border=rounded --border-label=" $label " \
            --prompt='Find: ' --query="$query" --delimiter=$'\t' --with-nth=1,2,3 \
            --print-query --expect=ctrl-f,ctrl-r,tab,shift-tab,ctrl-n \
            --header="Enter: open | Tab: browse | Shift-Tab: parent
Ctrl-f: recursive search | Ctrl-r: home | Ctrl-n: new session
$notice" \
            --preview="$preview" --preview-window='right,55%,border-left'
    )
    status=$?
    # fzf returns 1 on an accepted empty result; navigation/new still work there.
    [[ $status -gt 1 ]] && exit 0
    { IFS= read -r query; IFS= read -r key; IFS= read -r row; } <<< "$out"
    IFS=$'\t' read -r kind name path id <<< "$row"
    notice=
    case $key in
        ctrl-f) mode=--walk ;;
        ctrl-r) mode=--list; current=$HOME; query= ;;
        tab)
            [[ -d $path ]] || continue
            current=$(cd -- "$path" && pwd -P)
            mode=--browse; query= ;;
        shift-tab)
            [[ $mode == --browse ]] || current=${path:-$HOME}
            current=$(dirname "$current")
            mode=--browse; query= ;;
        ctrl-n)
            new_session "${path:-$current}" && exit 0 ;;
        '')
            case $kind in
                session) connect_session "$id"; exit $? ;;
                dir) open_dir "$path"; exit $? ;;
                *) exit 0 ;;
            esac ;;
    esac
done
