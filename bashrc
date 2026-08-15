# ---------------------------------------------------------------------------
# Interactive shells only
# ---------------------------------------------------------------------------
case $- in
  *i*) ;;
  *) return ;;
esac

# ---------------------------------------------------------------------------
# ble.sh — autosuggestions + syntax highlighting (must load before anything else)
# ---------------------------------------------------------------------------
_blesh="${HOMEBREW_PREFIX:-/opt/homebrew}/share/blesh/ble.sh"
[[ -f $_blesh ]] && source "$_blesh" --noattach

# ---------------------------------------------------------------------------
# Homebrew
# zsh gets HOMEBREW_PREFIX from /etc/zprofile; bash may not, so set it here.
# ---------------------------------------------------------------------------
if [[ -z ${HOMEBREW_PREFIX:-} && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# ---------------------------------------------------------------------------
# PATH
# ---------------------------------------------------------------------------
# bash has no `typeset -U path`, so dedupe by hand when prepending
_path_prepend() {
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
if [[ -r "${HOMEBREW_PREFIX:-}/etc/profile.d/bash_completion.sh" ]]; then
  source "$HOMEBREW_PREFIX/etc/profile.d/bash_completion.sh"
elif [[ -d "${HOMEBREW_PREFIX:-}/etc/bash_completion.d" ]]; then
  for _c in "$HOMEBREW_PREFIX"/etc/bash_completion.d/*; do
    [[ -r $_c ]] && source "$_c"
  done
  unset _c
fi

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
# ---------------------------------------------------------------------------
shopt -s autocd          # type a directory name to cd into it
shopt -s cdspell dirspell
shopt -s checkwinsize    # keep $COLUMNS accurate (the right-hand prompt needs it)
shopt -s globstar

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
command -v direnv >/dev/null && eval "$(direnv hook bash)"

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
  eval "$(fzf --bash)"
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
  file=$(fzf --query="${1:-}" --select-1 --exit-0) && [[ -n $file ]] && ${EDITOR:-vim} "$file"
}

# Fuzzy-search file *contents* with ripgrep, open the match in $EDITOR
if command -v rg >/dev/null; then
  rgf() {
    local match file line rest
    match=$(rg --line-number --no-heading --color=always --smart-case "${1:-}" |
      fzf --ansi --delimiter=: --preview 'bat --style=numbers --color=always --highlight-line {2} {1}' \
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

command -v zoxide >/dev/null && eval "$(zoxide init bash)"

if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -l --git --group-directories-first'
  alias la='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
fi

export BROWSER="open -a Firefox"

# ---------------------------------------------------------------------------
# Machine-local config (work aliases, secrets) — not tracked in this repo
# ---------------------------------------------------------------------------
[[ -f "$HOME/.bashrc.local" ]] && source "$HOME/.bashrc.local"

# ble.sh takes over the line editor last, once every binding is in place
[[ -n ${BLE_VERSION:-} ]] && ble-attach
