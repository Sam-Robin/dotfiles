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

## Machine-local config

Anything work-specific or sensitive goes in `~/.zshrc.local`, which is sourced last
and deliberately not tracked here — so it can override anything in `zshrc`.

## Dependencies

Installed via Homebrew:

```sh
brew install asdf direnv eza zsh-autosuggestions zsh-syntax-highlighting
```
