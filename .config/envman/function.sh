
# ---------------------------------------------------------------------------
# git() wrapper: intercepts "git worktree add" to copy .env files
# All other git subcommands are passed through unchanged.
# ---------------------------------------------------------------------------
git() {
  if [ "$1" != "worktree" ] || [ "$2" != "add" ]; then
    command git "$@"
    return $?
  fi

  # ---- Parse "git worktree add [options] <path> [<commit-ish>]" ----
  # Find the first non-option positional argument after "worktree add".
  # Flags that consume the next value: -b, -B, --orphan, --reason
  # All other flags are boolean.
  local worktree_path="" skip_next=0 i=0

  for arg in "$@"; do
    if [ $i -lt 2 ]; then i=$((i+1)); continue; fi
    if [ $skip_next -eq 1 ]; then skip_next=0; i=$((i+1)); continue; fi
    case "$arg" in
      -b|-B|--orphan|--reason) skip_next=1 ;;
      -*) ;;
      *) worktree_path="$arg"; break ;;
    esac
    i=$((i+1))
  done

  command git "$@"
  local exit_code=$?

  if [ $exit_code -ne 0 ] || [ -z "$worktree_path" ]; then
    return $exit_code
  fi

  # Resolve to absolute path
  case "$worktree_path" in
    /*) ;;
    *) worktree_path="$(pwd)/$worktree_path" ;;
  esac

  [ -d "$worktree_path" ] || return $exit_code

  # Main worktree is always the first entry in worktree list --porcelain
  local main_worktree
  main_worktree=$(command git worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')

  [ -n "$main_worktree" ] && [ "$main_worktree" != "$worktree_path" ] && \
    _copy_env_files "$main_worktree" "$worktree_path"

  return $exit_code
}

# Copy .env files from $1 (source tree) into $2 (destination tree).
# Skips files that already exist. Skips node_modules, .git, vendor.
_copy_env_files() {
  local src_root="$1" dst_root="$2" copied=0

  while IFS= read -r env_file; do
    local relative="${env_file#${src_root}/}"
    local dest="${dst_root}/${relative}"
    local dest_dir="${dest%/*}"
    if [ -d "$dest_dir" ] && [ ! -f "$dest" ]; then
      cp "$env_file" "$dest"
      echo "[worktree] Copied .env: $relative"
      copied=$((copied+1))
    fi
  done < <(find "$src_root" -maxdepth 4 -name ".env" \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -not -path "*/vendor/*" 2>/dev/null)

  if [ $copied -eq 0 ]; then
    echo "[worktree] No .env files to copy"
  else
    echo "[worktree] Done: $copied .env file(s) copied to $dst_root"
  fi
}
