# dotfiles

Personal shell configuration.

## Contents

- `zshrc` — zsh config: asdf shims, direnv hook, prompt (`vcs_info` git status), aliases, plugins
- `bashrc` — the same setup for bash: identical prompt, aliases and fzf helpers
- `bash_profile` — sources `bashrc`, because macOS starts login shells

## Install

```sh
git clone git@github.com:Sam-Robin/dotfiles.git ~/dotfiles
ln -s ~/dotfiles/zshrc ~/.zshrc
ln -s ~/dotfiles/bashrc ~/.bashrc
ln -s ~/dotfiles/bash_profile ~/.bash_profile
```

Then open a new shell.

## Machine-local config

Anything work-specific or sensitive goes in `~/.zshrc.local` (or `~/.bashrc.local`), which
is sourced last and deliberately not tracked here — so it can override anything above it.

## Dependencies

Installed via Homebrew:

```sh
brew install asdf direnv eza zsh-autosuggestions zsh-syntax-highlighting
brew install bash bash-completion@2 blesh   # bash only
```

Installing `bash` itself matters: macOS ships bash 3.2, which has no `EPOCHREALTIME` (the
prompt falls back to whole-second timings). `blesh` is bash's stand-in for
zsh-autosuggestions and zsh-syntax-highlighting. Everything degrades quietly if absent.

## Differences from `zshrc`

Bash has no direct equivalent for a few things, so `bashrc` approximates:

| zsh | bash |
| --- | --- |
| `RPROMPT` | right-aligned text printed, then overwritten via `\r` |
| `precmd` / `preexec` | `PROMPT_COMMAND` / `trap … DEBUG` |
| `vcs_info` | one `git status --porcelain=v2 --branch` call, parsed inline |
| `setopt auto_pushd` | a `cd` wrapper that calls `pushd` |
| `zstyle menu select` | `menu-complete` on Tab (cycles rather than showing a menu) |
| `typeset -U path` | `_path_prepend`, which checks before prepending |
