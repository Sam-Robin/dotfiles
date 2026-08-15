# Login shells read this file and never ~/.bashrc — macOS Terminal opens every tab
# as a login shell, and so does every SSH session into a server. Keep the config
# itself in bashrc so login and non-login shells behave identically.

# Debian's stock ~/.profile sets up PATH and then sources ~/.bashrc itself.
# Bash reads ~/.bash_profile *instead of* ~/.profile, so pick it up by hand.
[[ -f "$HOME/.profile" ]] && source "$HOME/.profile"

# ...which means bashrc may already be loaded. Only source it if it isn't.
[[ -f "$HOME/.bashrc" && -z ${_dotfiles_bashrc_loaded:-} ]] && source "$HOME/.bashrc"

return 0
