# dotfiles

Personal shell configuration.

## Contents

- `zshrc` — zsh config: asdf shims, direnv hook, prompt (`vcs_info` git status), aliases, plugins
- `bashrc` — the same setup for bash: identical prompt, aliases and fzf helpers.
  Runs on macOS and Debian
- `bash_profile` — sources `bashrc`, because login shells don't read it themselves
- `tmux.conf` — prefix Ctrl-a, true colour, zero escape delay for nvim
- `ghostty/config` — Ghostty terminal: JetBrainsMono Nerd Font, Option as Alt
- `bin/wt` — one git worktree + tmux session per branch, with nvim and Claude open.
  `wt <branch>` creates or attaches, `wt rm <branch>` tears down, `wt ls` lists.
  Works from bash or zsh; it is a plain script on `~/.local/bin`

## Install

```sh
git clone git@github.com:Sam-Robin/dotfiles.git ~/dotfiles
ln -s ~/dotfiles/zshrc ~/.zshrc
ln -s ~/dotfiles/bashrc ~/.bashrc
ln -s ~/dotfiles/bash_profile ~/.bash_profile
ln -s ~/dotfiles/tmux.conf ~/.tmux.conf
mkdir -p ~/.config/ghostty ~/.local/bin
ln -s ~/dotfiles/ghostty/config ~/.config/ghostty/config
ln -s ~/dotfiles/bin/wt ~/.local/bin/wt
```

Then open a new shell.

## Machine-local config

Anything work-specific or sensitive goes in `~/.zshrc.local` (or `~/.bashrc.local`), which
is sourced last and deliberately not tracked here — so it can override anything above it.

## Dependencies

Every tool below is optional — `bashrc` detects what's installed and quietly skips the
rest, so it works on a bare Debian box with nothing but `git`.

macOS, via Homebrew:

```sh
brew install asdf direnv eza zsh-autosuggestions zsh-syntax-highlighting
brew install tmux && brew install --cask ghostty font-jetbrains-mono-nerd-font
brew install bash bash-completion@2 blesh   # bash only
```

Installing `bash` itself matters on macOS: the system one is 3.2, which has no
`EPOCHREALTIME`, so the prompt falls back to whole-second timings. `blesh` is bash's
stand-in for zsh-autosuggestions and zsh-syntax-highlighting.

Debian, via apt:

```sh
sudo apt install git bash-completion fzf ripgrep bat fd-find direnv tree
sudo apt install eza zoxide   # trixie and later only
```

No need to symlink `batcat` → `bat` or `fdfind` → `fd`: `bashrc` looks for both names.

## Debian servers

`bashrc` returns before it prints anything unless the shell is interactive, which is what
keeps `scp` and `rsync` working — never add output above that guard.

Other things it adapts on Debian:

| | |
| --- | --- |
| `bat` / `fd` | resolved as `batcat` / `fdfind` |
| fzf < 0.48 | no `fzf --bash`, so the key bindings are sourced from `/usr/share/doc/fzf/examples` |
| `eza` absent | falls back to GNU `ls --color=auto --group-directories-first` |
| Clipboard | `pbcopy`, else `wl-copy`/`xclip`/`xsel`; Ctrl-Y in Ctrl-R is dropped if headless |
| `$BROWSER` | left unset when there's no display, which is what CLI tools expect |

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
