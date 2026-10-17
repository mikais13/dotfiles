# wk: git worktrees in one layout, each with its own tmux session.
# Worktrees live in ~/localdocs/worktrees/<repo>/<branch-slug>. Named wk, not
# wt, so that Worktrunk can keep its own command name.

WK_ROOT=$HOME/localdocs/worktrees
WK_TMUX_SCRIPTS=$HOME/.config/tmux/scripts

_wk_main() {
  command git -C "${1:-.}" worktree list --porcelain | awk 'NR == 1 { print substr($0, 10) }'
}

_wk_session_ids() {
  tmux list-sessions -F $'#{session_id}\t#{session_path}' 2>/dev/null |
    awk -F'\t' -v p="$1" '$2 == p { print $1 }'
}

# Pick a linked worktree of this repo with fzf. The pointer starts on the
# current worktree, unless that is the main one.
_wk_pick_linked() {
  local current pos
  local -a linked opts
  current=$(command git rev-parse --show-toplevel) || return
  linked=(${(f)"$(command git worktree list --porcelain | awk '/^worktree / { print substr($0, 10) }' | tail -n +2)"})
  (( $#linked )) || { echo "wk: no linked worktrees in this repo" >&2; return 1 }
  pos=${linked[(Ie)$current]}
  (( pos )) && opts=(--bind="load:pos($pos)")
  print -l -- $linked |
    fzf --reverse --prompt='Remove: ' $opts \
        --preview 'git -C {} status --short; echo; git -C {} log --oneline --color=always -15'
}

_wk_help() {
  cat <<'EOF'
Usage: wk <command> [args]

  new <branch> [base]  Create a worktree for <branch> and open it in tmux.
                       Uses the local or origin branch if it exists, or
                       creates it from [base] (default: origin/HEAD).
  open                 Pick a worktree of this repo and open it in tmux.
  rm [-f] [dir]        Remove a worktree, its tmux session and its zoxide
                       entry. With no dir, pick one with fzf. -f also
                       removes a dirty worktree and loses its changes.
  gc                   Prune stale worktrees, kill sessions whose folder is
                       gone and drop missing zoxide paths.
  ls                   List the worktrees of this repo (default command).
  help                 Show this help.
EOF
}

wk() {
  local cmd=${1:-ls}
  (( $# )) && shift
  case $cmd in
    new)
      (( $# )) || { _wk_help; return 1 }
      local branch=$1 base=${2:-origin/HEAD} main dir
      main=$(_wk_main) || return
      dir=$WK_ROOT/${main:t}/${branch//\//-}
      command git -C "$main" fetch -q origin
      if command git -C "$main" rev-parse -q --verify "refs/heads/$branch" >/dev/null ||
         command git -C "$main" rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null; then
        # worktree.guessRemote makes git track origin/<branch> when needed.
        command git -C "$main" worktree add "$dir" "$branch"
      else
        command git -C "$main" worktree add --no-track -b "$branch" "$dir" "$base"
      fi || return
      worktree-setup "$main" "$dir" || return
      if [[ -n $TMUX ]]; then
        "$WK_TMUX_SCRIPTS/tmux-sessionizer.sh" "$dir"
      else
        cd "$dir"
      fi ;;
    open)
      "$WK_TMUX_SCRIPTS/tmux-worktree.sh" ;;
    rm)
      local dir main id ids force arg target
      for arg; do
        case $arg in
          -f|--force) force=--force ;;
          *) target=$arg ;;
        esac
      done
      if [[ -z $target ]]; then
        target=$(_wk_pick_linked) || return
      fi
      dir=$(command git -C "$target" rev-parse --show-toplevel) || return
      main=$(_wk_main "$dir") || return
      [[ $dir == "$main" ]] && { echo "wk: will not remove the main worktree: $dir" >&2; return 1 }
      command git -C "$main" worktree remove $force "$dir" || return
      # Leave only after the remove succeeds, so a failure keeps this shell in place.
      [[ $PWD/ == "$dir"/* ]] && cd "$main"
      zoxide remove "$dir" 2>/dev/null
      # Kill sessions last: one of them can be the session this shell runs in.
      ids=($(_wk_session_ids "$dir"))
      for id in $ids; do tmux kill-session -t "$id"; done ;;
    gc)
      local repo id session_dir zdir
      for repo in ~/localdocs/*/.git(N/); do
        command git -C "${repo:h}" worktree prune -v
      done
      tmux list-sessions -F $'#{session_id}\t#{session_path}' 2>/dev/null |
        while IFS=$'\t' read -r id session_dir; do
          [[ -d $session_dir ]] || tmux kill-session -t "$id"
        done
      zoxide query -l | while IFS= read -r zdir; do
        [[ -d $zdir ]] || zoxide remove "$zdir"
      done
      print -l -- "Worktrees in $WK_ROOT:" $WK_ROOT/*/*(N/) ;;
    ls)
      command git worktree list ;;
    help|-h|--help)
      _wk_help ;;
    *)
      _wk_help >&2
      return 1 ;;
  esac
}

_wk() {
  if (( CURRENT == 2 )); then
    compadd new open rm gc ls help
  elif [[ $words[2] == new ]]; then
    compadd -- ${(f)"$(
      command git for-each-ref --format='%(refname:lstrip=2)' refs/heads 2>/dev/null
      command git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin 2>/dev/null | grep -vx HEAD
    )"}
  elif [[ $words[2] == rm ]]; then
    compadd -- ${(f)"$(command git worktree list --porcelain 2>/dev/null | awk '/^worktree / { print substr($0, 10) }' | tail -n +2)"}
  fi
}
compdef _wk wk
