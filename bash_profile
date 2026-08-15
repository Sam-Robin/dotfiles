# macOS Terminal starts login shells, which read this file and never ~/.bashrc.
# Keep everything in bashrc so login and non-login shells behave identically.
[[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc"
