# Sessionizer

Press `Ctrl-a`, then `f` to open the sessionizer. Type to fuzzy-search session
names and directory paths. All live sessions remain visible, including sessions
that share a directory.

| Key | Action |
| --- | --- |
| Enter | Switch to the selected session, or open a session at the selected directory. |
| Ctrl-f | Search project roots recursively, together with live sessions. Keeps the current query. |
| Tab | Browse the selected directory, or the selected session's directory. |
| Shift-Tab | Go to the parent of the browsed directory. Outside browse mode, go to the selected path's parent. |
| Ctrl-r | Return to the initial list and clear the query. |
| Ctrl-n | Create a session with an explicit directory and name. |
| Esc | Cancel the current prompt. In the main picker, close the popup. |

In browse mode, type to filter immediate child directories. Hidden directories
and directory symlinks are available. Select `.` and press Enter to open a session
in the current directory. The preview shows a directory tree and, for sessions,
their windows.

## Recursive Search

Search roots are `~/localdocs`, `~/Documents`, `~/dotfiles`, `~/.claude`, and
`~/.agents`. Edit the roots in `list_rows` in `scripts/tmux-sessionizer.sh` to
change them. The `IGNORE` list excludes generated directories during traversal.
Manual browsing is unrestricted, so use Tab to reach excluded directories or
locations outside the search roots.

## Session Creation

Enter reuses a session at the selected directory if one exists. Otherwise, it
creates a session with a directory-based name. If that name is taken by an
unrelated session, it adds a numeric suffix.

Ctrl-n creates a separate session, even if another session uses that directory:

1. Edit the directory path. It starts at the selected path, or the current browse
   directory when nothing is selected. Relative paths are resolved from there;
   `~` and absolute paths are also accepted.
2. Enter a unique session name.
3. Select `Create` and press Enter to confirm. The default is `Cancel`.

No directories or sessions are created before confirmation. Spaces and shell
characters in paths are treated literally, not executed. The picker uses tab- and
line-delimited rows, so paths with tabs or newlines are not supported.

You can also run `scripts/tmux-sessionizer.sh /path/to/project` directly. It
switches clients inside tmux and attaches from a terminal outside tmux.

## Tests

Run from the repository root:

```sh
python3 -B -m unittest discover -s tmux/tests -v
bash -n tmux/scripts/tmux-sessionizer.sh
```

Tests use temporary home directories and isolated tmux sockets. They do not alter
live sessions. The terminal tests also require fzf and Python 3.11 or newer.
