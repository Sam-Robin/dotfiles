# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
typeset -U path PATH   # keep PATH free of duplicates automatically

export PATH="$HOME/.local/bin:$PATH"

# asdf (v0.16+ is a Go binary — no asdf.sh to source, just put shims on PATH)
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="$HOME/.zsh_history"
HISTSIZE=50000
SAVEHIST=50000

setopt hist_ignore_all_dups    # drop older duplicates of a repeated command
setopt hist_reduce_blanks      # tidy up whitespace before saving
setopt hist_ignore_space       # a leading space keeps a command out of history
setopt hist_verify             # expand !! etc. onto the line instead of running it
setopt share_history           # live-share history between open tabs
setopt extended_history        # record timestamp + duration

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
[[ -n "$HOMEBREW_PREFIX" ]] && FPATH="$HOMEBREW_PREFIX/share/zsh/site-functions:$FPATH"

autoload -Uz compinit && compinit

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' menu select                          # arrow-key menu
zstyle ':completion:*' list-colors ''
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

# ---------------------------------------------------------------------------
# Navigation
# ---------------------------------------------------------------------------
setopt auto_cd              # `florence` instead of `cd florence`
setopt auto_pushd           # every cd pushes onto the dir stack
setopt pushd_ignore_dups
setopt pushd_silent
alias d='dirs -v'           # numbered recent dirs; `cd -2` to jump back

# ---------------------------------------------------------------------------
# Prompt: teal user@host, yellow dir, red git branch, white command text
# ---------------------------------------------------------------------------
autoload -Uz vcs_info
precmd_vcs_info() { vcs_info }
precmd_functions+=( precmd_vcs_info )
setopt prompt_subst

zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats       ' %F{red}(%b%u%c)%f'
zstyle ':vcs_info:git:*' actionformats ' %F{red}(%b|%a%u%c)%f'

PROMPT='%F{37}%n@%m%f %F{yellow}%~%f${vcs_info_msg_0_}%F{yellow} %#%f %F{white}'

# Reset colour after the command line so output isn't white
preexec() { print -Pn '%f' }

# ---------------------------------------------------------------------------
# direnv (loads florence/.envrc → .env.neon)
# ---------------------------------------------------------------------------
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias be='bundle exec'
alias fl='./bin/florence'
alias rs='rails s'
alias rc='rails c'
alias rspecf='bundle exec rspec'
alias rubo='bundle exec rubocop -a --force-exclusion'
alias tscheck='yarn typescript:check'
alias lintjs='yarn lint:js'

# ---------------------------------------------------------------------------
# Optional tools — activate automatically once brew-installed
# ---------------------------------------------------------------------------
# fzf: Ctrl-R history search, Ctrl-T file picker, Alt-C cd
if command -v fzf >/dev/null; then
  eval "$(fzf --zsh)"
  export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline'
  command -v rg >/dev/null && export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
fi

command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first'
  alias la='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
fi

if [[ -n "$HOMEBREW_PREFIX" ]]; then
  _zsh_plugin() { [[ -f "$1" ]] && source "$1" }
  _zsh_plugin "$HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
  # syntax highlighting must be sourced last
  _zsh_plugin "$HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

export BROWSER="open -a Firefox"

# Tab accepts an autosuggestion when one is showing, otherwise completes as normal
_accept_suggestion_or_complete() {
  if [[ -n "$POSTDISPLAY" ]]; then
    zle autosuggest-accept
  else
    zle expand-or-complete
  fi
}
zle -N _accept_suggestion_or_complete
bindkey '^I' _accept_suggestion_or_complete
