# dotfiles

Personal shell configuration.

## Contents

- `zshrc` — zsh config: asdf shims, direnv hook, prompt (`vcs_info` git status), aliases, plugins

## Install

```sh
git clone git@github.com:Sam-Robin/dotfiles.git ~/dotfiles
ln -s ~/dotfiles/zshrc ~/.zshrc
```

Then open a new shell.

## Dependencies

Installed via Homebrew:

```sh
brew install asdf direnv eza zsh-autosuggestions zsh-syntax-highlighting
```
