# ---------------------------------------------------------------------------
# Interactive shells only
# Must stay at the top: scp and rsync break if a non-interactive shell prints.
# ---------------------------------------------------------------------------
case $- in
  *i*) ;;
  *) return ;;
esac

# ---------------------------------------------------------------------------
# Platform
# This file runs on both macOS (Homebrew) and Debian, which name several of the
# same tools differently, so resolve everything through these two helpers.
# ---------------------------------------------------------------------------
_os=$(uname -s)

_have() { command -v "$1" >/dev/null 2>&1; }

# Echo the first of several command names that exists
_first_cmd() {
  local c
  for c in "$@"; do
    if _have "$c"; then printf '%s' "$c"; return 0; fi
  done
  return 1
}

# zsh gets HOMEBREW_PREFIX from /etc/zprofile; bash may not. Unset on Debian.
if [[ -z ${HOMEBREW_PREFIX:-} ]]; then
  for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
    [[ -x $_brew ]] && { eval "$("$_brew" shellenv)"; break; }
  done
  unset _brew
fi

_bat=$(_first_cmd bat batcat)     # Debian packages bat as batcat
_fd=$(_first_cmd fd fdfind)       # ...and fd as fdfind

# ---------------------------------------------------------------------------
# ble.sh — autosuggestions + syntax highlighting (must load before key bindings)
# ---------------------------------------------------------------------------
for _blesh in \
  "${HOMEBREW_PREFIX:-}/share/blesh/ble.sh" \
  "$HOME/.local/share/blesh/ble.sh" \
  /usr/share/blesh/ble.sh
do
  [[ -f $_blesh ]] && { source "$_blesh" --noattach; break; }
done
unset _blesh

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
# bash has no `typeset -U path`, so check before prepending
_path_prepend() {
  [[ -d $1 ]] || return
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

_path_prepend "$HOME/.local/bin"

# asdf (v0.16+ is a Go binary — no asdf.sh to source, just put shims on PATH)
_path_prepend "${ASDF_DATA_DIR:-$HOME/.asdf}/shims"

export PATH

# ---------------------------------------------------------------------------
# History
# ---------------------------------------------------------------------------
HISTFILE="$HOME/.bash_history"
HISTSIZE=50000
HISTFILESIZE=50000

HISTCONTROL=ignoreboth:erasedups   # drop duplicates, and lines starting with a space
HISTTIMEFORMAT='%F %T '            # record timestamps

shopt -s histappend                # never clobber the file from a second tab
shopt -s cmdhist                   # keep a multi-line command on one history line
shopt -s histverify                # expand !! onto the line instead of running it
shopt -s lithist

# Live-share history between open tabs (zsh's share_history)
_history_sync() { history -a; history -c; history -r; }

# ---------------------------------------------------------------------------
# Completion
# ---------------------------------------------------------------------------
for _bc in \
  "${HOMEBREW_PREFIX:-}/etc/profile.d/bash_completion.sh" \
  /usr/share/bash-completion/bash_completion \
  /etc/bash_completion
do
  [[ -r $_bc ]] && { source "$_bc"; break; }
done
unset _bc

bind 'set completion-ignore-case on'      # case-insensitive
bind 'set completion-map-case on'         # treat - and _ as equivalent
bind 'set show-all-if-ambiguous on'       # one Tab lists, don't make me press twice
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set menu-complete-display-prefix on'

# Closest bash has to zsh's `menu select`: Tab cycles, Shift-Tab cycles back
bind '"\t": menu-complete'
bind '"\e[Z": menu-complete-backward'

# ---------------------------------------------------------------------------
# Navigation
# 2>/dev/null because autocd/dirspell/globstar need bash 4+, and macOS ships 3.2
# ---------------------------------------------------------------------------
shopt -s autocd 2>/dev/null          # type a directory name to cd into it
shopt -s cdspell
shopt -s dirspell 2>/dev/null
shopt -s globstar 2>/dev/null
shopt -s checkwinsize                # keep $COLUMNS accurate — the right-hand prompt needs it

# bash has no auto_pushd — push on every cd, ignoring repeats (pushd_ignore_dups)
cd() {
  if (( $# == 0 )); then
    builtin pushd "$HOME" >/dev/null
  elif [[ $1 == - ]]; then
    builtin cd - >/dev/null || return
  elif [[ -d $1 && $1 -ef $PWD ]]; then
    return 0
  else
    builtin pushd "$@" >/dev/null
  fi
}

alias d='dirs -v'        # numbered recent dirs; `cd ~2` to jump back

# ---------------------------------------------------------------------------
# Prompt: two-line, git ahead/behind, exit status, command duration
# ---------------------------------------------------------------------------
_arrow_colour=241
_git_clean_colour=71
_git_dirty_colour=196
_cmd_start=
_cmd_elapsed=

# EPOCHREALTIME is bash 5+; on older bash fall back to whole seconds
_timer_now() {
  if [[ -n ${EPOCHREALTIME:-} ]]; then
    printf '%s' "$EPOCHREALTIME"
  else
    printf '%s' "$SECONDS"
  fi
}

# DEBUG trap is bash's preexec
_preexec() {
  [[ -n ${COMP_LINE:-} ]] && return              # completion, not a command
  [[ $BASH_COMMAND == _prompt_command* ]] && return
  [[ -n $_cmd_start ]] && return
  _cmd_start=$(_timer_now)
  printf '\033[0m'                               # don't tint command output
}
trap '_preexec' DEBUG

# Branch, dirty/staged markers, in-progress action, ahead/behind — one git call
_git_info() {
  local out line head ab action staged= unstaged= untracked= misc=
  out=$(command git status --porcelain=v2 --branch 2>/dev/null) || return 1

  while IFS= read -r line; do
    case $line in
      '# branch.head '*) head=${line#\# branch.head } ;;
      '# branch.ab '*)   ab=${line#\# branch.ab } ;;
      # vcs_info doesn't mark untracked files, but they still count as dirty
      '? '*)             untracked=1 ;;
      [12u]' '*)
        local xy=${line#* }
        xy=${xy%% *}
        [[ ${xy:0:1} != . ]] && staged='+'
        [[ ${xy:1:1} != . ]] && unstaged='*'
        ;;
    esac
  done <<< "$out"

  [[ -z $head ]] && return 1
  [[ $head == '(detached)' ]] && head=$(command git rev-parse --short HEAD 2>/dev/null)

  if [[ -n ${ab:-} ]]; then
    local ahead=${ab%% *} behind=${ab##* }
    (( ${ahead#+} )) && misc+="↑${ahead#+}"
    (( ${behind#-} )) && misc+="↓${behind#-}"
  fi

  local gitdir
  gitdir=$(command git rev-parse --git-dir 2>/dev/null)
  if [[ -d $gitdir/rebase-merge || -d $gitdir/rebase-apply ]]; then
    action='REBASE'
  elif [[ -f $gitdir/MERGE_HEAD ]]; then
    action='MERGE'
  elif [[ -f $gitdir/CHERRY_PICK_HEAD ]]; then
    action='CHERRY-PICK'
  fi

  printf '%s%s%s%s%s' "$head" "${action:+|$action}" "$unstaged" "$staged" "$misc"
  [[ -n $unstaged$staged$untracked ]] && return 2
  return 0
}

_prompt_command() {
  local exit_status=$?
  (( exit_status == 0 )) && _arrow_colour=241 || _arrow_colour=196

  _cmd_elapsed=
  if [[ -n $_cmd_start ]]; then
    local now
    now=$(_timer_now)
    if (( ${now%%[.,]*} - ${_cmd_start%%[.,]*} >= 2 )); then
      _cmd_elapsed=$(awk -v s="$_cmd_start" -v e="$now" \
        'BEGIN { gsub(",", ".", s); gsub(",", ".", e); printf "%.1fs", e - s }')
    fi
    _cmd_start=
  fi

  _history_sync

  local git_text git_state git_segment=
  git_text=$(_git_info); git_state=$?
  if (( git_state != 1 )); then
    local branch_colour=$_git_clean_colour
    (( git_state == 2 )) && branch_colour=$_git_dirty_colour
    git_segment="─[\[\033[38;5;${branch_colour}m\]${git_text}\[\033[38;5;244m\]]"
  fi

  # bash has no RPROMPT: print right-aligned, then \r and let line one overwrite
  local right="${_cmd_elapsed:+${_cmd_elapsed}  }$(date +%H:%M:%S)"
  local right_col=$(( ${COLUMNS:-80} - ${#right} + 1 ))
  (( right_col < 1 )) && right_col=1
  local rprompt="\[\033[${right_col}G\033[38;5;240m${right}\033[0m\r\]"

  PS1="${rprompt}\[\033[38;5;244m\]┌─[\[\033[38;5;37m\]\u@\h\[\033[38;5;244m\]]─[\[\033[33m\]\w\[\033[38;5;244m\]]${git_segment}
\[\033[38;5;244m\]└──\[\033[38;5;${_arrow_colour}m\]▶\[\033[0m\] \[\033[97m\]"
}

PROMPT_COMMAND=_prompt_command
PS2='   \[\033[38;5;244m\]…\[\033[0m\] '

# ---------------------------------------------------------------------------
# direnv (per-project .envrc)
# ---------------------------------------------------------------------------
_have direnv && eval "$(direnv hook bash)"

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
alias be='bundle exec'
alias rs='rails s'
alias rc='rails c'
alias rspecf='bundle exec rspec'
alias rubo='bundle exec rubocop -a --force-exclusion'

# ---------------------------------------------------------------------------
# Optional tools — activate automatically once installed
# ---------------------------------------------------------------------------
# fzf: Ctrl-R history search, Ctrl-T file picker, Alt-C cd
if _have fzf; then
  if fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  else
    # fzf < 0.48, e.g. Debian's package, ships the bindings as files instead
    for _f in \
      /usr/share/doc/fzf/examples/key-bindings.bash \
      /usr/share/fzf/key-bindings.bash \
      "${HOMEBREW_PREFIX:-}/opt/fzf/shell/key-bindings.bash"
    do
      [[ -r $_f ]] && { source "$_f"; break; }
    done
    for _f in \
      /usr/share/doc/fzf/examples/completion.bash \
      /usr/share/fzf/completion.bash \
      "${HOMEBREW_PREFIX:-}/opt/fzf/shell/completion.bash"
    do
      [[ -r $_f ]] && { source "$_f"; break; }
    done
    unset _f
  fi

  export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline --marker=+'

  if [[ -n $_fd ]]; then
    export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --exclude .git"
    export FZF_ALT_C_COMMAND="$_fd --type d --hidden --exclude .git"
  elif _have rg; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
  fi
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

  # Ctrl-T: preview the file under the cursor
  if [[ -n $_bat ]]; then
    export FZF_CTRL_T_OPTS="--preview \"$_bat --style=numbers --color=always --line-range=:200 {}\" --preview-window=right:60%:wrap"
  fi

  # Alt-C: preview the directory tree under the cursor
  if _have eza; then
    export FZF_ALT_C_OPTS='--preview "eza --tree --level=2 --colour=always --group-directories-first {}" --preview-window=right:50%'
  elif _have tree; then
    export FZF_ALT_C_OPTS='--preview "tree -C -L 2 {}" --preview-window=right:50%'
  fi

  # Ctrl-R: wrap long commands in a preview pane instead of truncating them,
  # and Ctrl-Y copies one — if this box has a clipboard to copy to
  FZF_CTRL_R_OPTS='--preview "echo {}" --preview-window=down:3:wrap'
  _clip=$(_first_cmd pbcopy wl-copy xclip xsel)
  case $_clip in
    xclip) _clip='xclip -selection clipboard' ;;
    xsel)  _clip='xsel --clipboard --input' ;;
  esac
  [[ -n $_clip ]] &&
    FZF_CTRL_R_OPTS+=" --bind \"ctrl-y:execute-silent(echo -n {2..} | $_clip)+abort\""
  export FZF_CTRL_R_OPTS
  unset _clip
fi

# Fuzzy-find a file and open it in $EDITOR
fe() {
  local file
  file=$(fzf --query="${1:-}" --select-1 --exit-0) && [[ -n $file ]] && ${EDITOR:-vim} "$file"
}

# Fuzzy-search file *contents* with ripgrep, open the match in $EDITOR
if _have rg; then
  rgf() {
    local match file line rest preview='cat {1}'
    [[ -n $_bat ]] && preview="$_bat --style=numbers --color=always --highlight-line {2} {1}"
    match=$(rg --line-number --no-heading --color=always --smart-case "${1:-}" |
      fzf --ansi --delimiter=: --preview "$preview" \
          --preview-window='right:60%:wrap:+{2}-/2') || return
    file=${match%%:*}
    rest=${match#*:}
    line=${rest%%:*}
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

_have zoxide && eval "$(zoxide init bash)"

if _have eza; then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first'
  alias la='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
elif [[ $_os == Linux ]]; then
  # GNU coreutils ls, which BSD/macOS ls doesn't understand
  _have dircolors && eval "$(dircolors -b)"
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lh --color=auto --group-directories-first'
  alias la='ls -lah --color=auto --group-directories-first'
  alias grep='grep --color=auto'
fi

# Headless servers get no BROWSER at all, which is what most tools expect
if _have open; then
  export BROWSER="open -a Firefox"
elif [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] && _have xdg-open; then
  export BROWSER='xdg-open'
fi

# ---------------------------------------------------------------------------
# Machine-local config (work aliases, secrets) — not tracked in this repo
# ---------------------------------------------------------------------------
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"

# ble.sh takes over the line editor last, once every binding is in place
[[ -n ${BLE_VERSION:-} ]] && ble-attach

_dotfiles_bashrc_loaded=1
