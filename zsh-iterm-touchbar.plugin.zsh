# GIT
GIT_UNCOMMITTED="${GIT_UNCOMMITTED:-☢}"
GIT_UNSTAGED="${GIT_UNSTAGED:-🚧}"
GIT_UNTRACKED="${GIT_UNTRACKED:-?}"
GIT_STASHED="${GIT_STASHED:-$}"
GIT_UNPULLED="${GIT_UNPULLED:-⬇}"
GIT_UNPUSHED="${GIT_UNPUSHED:-⬆}"

# Output name of current branch.
git_current_branch() {
  local ref
  ref=$(command git symbolic-ref --quiet HEAD 2> /dev/null)
  local ret=$?
  if [[ $ret != 0 ]]; then
    [[ $ret == 128 ]] && return  # no git repo.
    ref=$(command git rev-parse --short HEAD 2> /dev/null) || return
  fi
  echo ${ref#refs/heads/}
}

# Uncommitted changes.
# Check for uncommitted changes in the index.
git_uncomitted() {
  if ! $(git diff --quiet --ignore-submodules --cached); then
    echo -n "${GIT_UNCOMMITTED}"
  fi
}

# Unstaged changes.
# Check for unstaged changes.
git_unstaged() {
  if ! $(git diff-files --quiet --ignore-submodules --); then
    echo -n "${GIT_UNSTAGED}"
  fi
}

# Untracked files.
# Check for untracked files.
git_untracked() {
  if [ -n "$(git ls-files --others --exclude-standard)" ]; then
    echo -n "${GIT_UNTRACKED}"
  fi
}

# Stashed changes.
# Check for stashed changes.
git_stashed() {
  if $(git rev-parse --verify refs/stash &>/dev/null); then
    echo -n "${GIT_STASHED}"
  fi
}

# Unpushed and unpulled commits.
# Get unpushed and unpulled commits from remote and draw arrows.
git_unpushed_unpulled() {
  # check if there is an upstream configured for this branch
  command git rev-parse --abbrev-ref @'{u}' &>/dev/null || return

  local count
  count="$(command git rev-list --left-right --count HEAD...@'{u}' 2>/dev/null)"
  # exit if the command failed
  (( !$? )) || return

  # counters are tab-separated, split on tab and store as array
  count=(${(ps:\t:)count})
  local arrows left=${count[1]} right=${count[2]}

  (( ${right:-0} > 0 )) && arrows+="${GIT_UNPULLED}"
  (( ${left:-0} > 0 )) && arrows+="${GIT_UNPUSHED}"

  [ -n $arrows ] && echo -n "${arrows}"
}

pecho() {
  if [ -n "$TMUX" ]
  then
    echo -ne "\ePtmux;\e$*\e\\"
  else
    echo -ne $*
  fi
}

typeset -A buttons
buttons[F1]='^[OP'
buttons[F2]='^[OQ'
buttons[F3]='^[OR'
buttons[F4]='^[OS'
buttons[F5]='^[[15~'
buttons[F6]='^[[17~'
buttons[F7]='^[[18~' 
buttons[F8]='^[[19~'
buttons[F9]='^[[20~'
buttons[F10]='^[[21~'
buttons[F11]='^[[23~'
buttons[F12]='^[[24~'

touchBarState=''
npmScripts=()
lastPackageJsonPath=''

function _clearTouchbar() {
  pecho "\033]1337;PopKeyLabels\a"
}

function _unbindTouchbar() {
  for fnKey in "${(@k)buttons}"; do
    bindkey -s "$buttons[$fnKey]" ''
  done
}

function _setButton() {
  pecho "\033]1337;SetKeyLabel=$1=$2\a"
  bindkey -s "$buttons[$1]" "$3 \n"
}

function git_merge_master() {
  branchName=`git branch | grep \* | cut -d ' ' -f2`
  git add -A
  git stash
  git checkout master
  git pull
  git checkout $branchName
  git merge master
  git stash pop
}

function _displayDefault() {
  _clearTouchbar
  _unbindTouchbar

  touchBarState=''

  # Check if the current directory is in a Git repository.
  command git rev-parse --is-inside-work-tree &>/dev/null || return
  # Check if the current directory is in .git before running git checks.
  if [[ "$(git rev-parse --is-inside-git-dir 2> /dev/null)" == 'false' ]]; then

    # Ensure the index is up to date.
    git update-index --really-refresh -q &>/dev/null

    # String of indicators
    local indicators=''
    indicators+="$(git_uncomitted)"
    indicators+="$(git_unstaged)"
    indicators+="$(git_untracked)"
    # indicators+="$(git_stashed)"
    indicators+="$(git_unpushed_unpulled)"
    [ -n "${indicators}" ] && touchbarIndicators="${indicators}" || touchbarIndicators="🙌";

    # _setButton "F1" "👉 $(echo $(pwd) | awk -F/ '{print $(NF-1)"/"$(NF)}')" "pwd"
    _setButton "F1" "$touchbarIndicators" "git status"
    _setButton "F2" "❌ stash" "git add -A; git stash"
    _setButton "F3" "✅ unstash" "git stash pop"
    _setButton "F4" "☮ master" "git_merge_master"
    _setButton "F5" "${(r:200:: :)}"

  fi
}

function _displayNpmScripts() {
  # find available npm run scripts only if new directory
  if [[ $lastPackageJsonPath != $(echo "$(pwd)/package.json") ]]; then
    lastPackageJsonPath=$(echo "$(pwd)/package.json")
    npmScripts=($(node -e "console.log(Object.keys($(npm run --json)).filter(name => !name.includes(':')).sort((a, b) => a.localeCompare(b)).filter((name, idx) => idx < 12).join(' '))"))
  fi

  _clearTouchbar
  _unbindTouchbar

  touchBarState='npm'

  fnKeysIndex=1
  for npmScript in "$npmScripts[@]"; do
    fnKeysIndex=$((fnKeysIndex + 1))
    bindkey -s $fnKeys[$fnKeysIndex] "npm run $npmScript \n"
    pecho "\033]1337;SetKeyLabel=F$fnKeysIndex=$npmScript\a"
  done

  pecho "\033]1337;SetKeyLabel=F1=👈 back\a"
  bindkey "${fnKeys[1]}" _displayDefault
}

zle -N _displayDefault
zle -N _displayNpmScripts

precmd_iterm_touchbar() {
  if [[ $touchBarState == 'npm' ]]; then
    _displayNpmScripts
  else
    _displayDefault
  fi
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd precmd_iterm_touchbar

