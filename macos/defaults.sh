#!/usr/bin/env bash
#
# macOS system defaults.
# Run: ./macos/defaults.sh
# Note: Some settings need a logout/login to take effect.

set -euo pipefail

# Keyboard: fast key repeat
# KeyRepeat is below the System Settings minimum of 2.
defaults write -g KeyRepeat -int 1           # repeat rate, ~15ms per character
defaults write -g InitialKeyRepeat -int 15   # delay before repeat starts, ~225ms

# Dock: auto-hide with no delay before it appears.
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
killall Dock
