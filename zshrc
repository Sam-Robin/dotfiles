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
setopt auto_cd              # type a directory name to cd into it
setopt auto_pushd           # every cd pushes onto the dir stack
setopt pushd_ignore_dups
setopt pushd_silent
alias d='dirs -v'           # numbered recent dirs; `cd -2` to jump back

# ---------------------------------------------------------------------------
# Prompt: two-line, git ahead/behind, exit status, command duration
# ---------------------------------------------------------------------------
zmodload zsh/datetime
autoload -Uz vcs_info
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '*'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats       '%b%u%c%m'
zstyle ':vcs_info:git:*' actionformats '%b|%a%u%c%m'
zstyle ':vcs_info:git*+set-message:*' hooks git-aheadbehind

# Append ↑n / ↓n for commits ahead of / behind the upstream branch
+vi-git-aheadbehind() {
  local ahead behind
  ahead=$(command git rev-list --count @{upstream}..HEAD 2>/dev/null)
  behind=$(command git rev-list --count HEAD..@{upstream} 2>/dev/null)
  (( ahead ))  && hook_com[misc]+="↑${ahead}"
  (( behind )) && hook_com[misc]+="↓${behind}"
}

_cmd_start=
_cmd_elapsed=
_arrow_colour=241

preexec() {
  _cmd_start=$EPOCHREALTIME
  print -Pn '%f'            # reset colour so command output isn't tinted
}

precmd() {
  local exit_status=$?
  (( exit_status == 0 )) && _arrow_colour=241 || _arrow_colour=red

  _cmd_elapsed=''
  if [[ -n $_cmd_start ]]; then
    local -F seconds=$(( EPOCHREALTIME - _cmd_start ))
    (( seconds > 2 )) && _cmd_elapsed=$(printf '%.1fs' $seconds)
    _cmd_start=
  fi

  vcs_info

  if [[ -n $vcs_info_msg_0_ ]]; then
    _git_segment="─[%F{red}${vcs_info_msg_0_}%F{244}]"
  else
    _git_segment=''
  fi
}

PROMPT='%F{244}┌─[%F{37}%n@%m%F{244}]─[%F{yellow}%~%F{244}]${_git_segment}
%F{244}└──%F{${_arrow_colour}}▶%f %F{white}'

RPROMPT='%F{240}${_cmd_elapsed:+${_cmd_elapsed}  }%D{%H:%M:%S}%f'

# ---------------------------------------------------------------------------
# direnv (per-project .envrc)
# ---------------------------------------------------------------------------
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias be='bundle exec'
alias rs='rails s'
alias rc='rails c'
alias rspecf='bundle exec rspec'
alias rubo='bundle exec rubocop -a --force-exclusion'

# ---------------------------------------------------------------------------
# Optional tools — activate automatically once brew-installed
# ---------------------------------------------------------------------------
# fzf: Ctrl-R history search, Ctrl-T file picker, Alt-C cd
if command -v fzf >/dev/null; then
  eval "$(fzf --zsh)"
  export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline --marker=+'

  if command -v fd >/dev/null; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --exclude .git'
    export FZF_ALT_C_COMMAND='fd --type d --hidden --exclude .git'
  elif command -v rg >/dev/null; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
  fi
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

  # Ctrl-T: preview the file under the cursor
  if command -v bat >/dev/null; then
    export FZF_CTRL_T_OPTS='--preview "bat --style=numbers --color=always --line-range=:200 {}" --preview-window=right:60%:wrap'
  fi

  # Alt-C: preview the directory tree under the cursor
  if command -v eza >/dev/null; then
    export FZF_ALT_C_OPTS='--preview "eza --tree --level=2 --colour=always --group-directories-first {}" --preview-window=right:50%'
  fi

  # Ctrl-R: wrap long commands in a preview pane instead of truncating them
  export FZF_CTRL_R_OPTS='--preview "echo {}" --preview-window=down:3:wrap --bind "ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort"'
fi

# Fuzzy-find a file and open it in $EDITOR
fe() {
  local file
  file=$(fzf --query="$1" --select-1 --exit-0) && [[ -n $file ]] && ${EDITOR:-vim} "$file"
}

# Fuzzy-search file *contents* with ripgrep, open the match in $EDITOR
if command -v rg >/dev/null; then
  rgf() {
    local match file line
    match=$(rg --line-number --no-heading --color=always --smart-case "${1:-}" |
      fzf --ansi --delimiter=: --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
          --preview-window='right:60%:wrap:+{2}-/2') || return
    file=${match%%:*}
    line=${${match#*:}%%:*}
    [[ -n $file ]] && ${EDITOR:-vim} "+${line}" "$file"
  }
fi

# Fuzzy-checkout a git branch
fbr() {
  local branch
  branch=$(git branch --all --sort=-committerdate --format='%(refname:short)' 2>/dev/null |
    grep -v '^origin/HEAD' | fzf --preview 'git log --oneline --color=always -20 {}') || return
  [[ -n $branch ]] && git checkout "${branch#origin/}"
}

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

# ---------------------------------------------------------------------------
# Machine-local config (work aliases, secrets) — not tracked in this repo
# ---------------------------------------------------------------------------
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
