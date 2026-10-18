#!/usr/bin/env zsh
#
# Copyright 2026 Pétur Ingi Egilsson <petur@ingi.dk>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Installs (or removes) the zsh completion for Apple's container CLI.

emulate -R zsh
setopt err_return no_unset extended_glob

readonly SCRIPT_DIR=${0:A:h}
readonly MARK_BEGIN='# >>> zsh-container-completion >>>'
readonly MARK_END='# <<< zsh-container-completion <<<'

dir=$HOME/.zsh/completions
rc=${ZDOTDIR:-$HOME}/.zshrc
edit_rc=1
action=install

usage() {
  cat <<EOF
Usage: ./install.sh [options]

Installs _container, the zsh completion for Apple's container CLI.

Options:
  -d, --dir DIR    directory to install into (default: ~/.zsh/completions)
  -n, --no-rc      do not touch ${(D)rc}; you put DIR on fpath yourself
  -u, --uninstall  remove the completion and the block this script added
  -h, --help       show this help

The script:
  1. copies _container into DIR
  2. puts DIR on fpath in ${(D)rc}, before compinit (or before
     oh-my-zsh is sourced, since oh-my-zsh runs compinit), unless it
     is already there; the original file is kept as a timestamped backup
  3. deletes the compinit cache (~/.zcompdump*) so the new function is seen
EOF
}

info() { print -r -- "==> $*" }
warn() { print -ru2 -- "warning: $*" }
die()  { print -ru2 -- "error: $*"; exit 1 }

# --- .zshrc handling -------------------------------------------------------

# Succeeds if a non-comment fpath line in $rc already mentions $dir.
rc_has_dir() {
  [[ -r $rc ]] || return 1
  local line form
  local -a forms=( $dir )
  if [[ $dir == $HOME/* ]]; then
    local rel=${dir#$HOME/}
    forms+=( "~/$rel" "\$HOME/$rel" "\${HOME}/$rel" )
  fi
  for line in "${(@f)$(<$rc)}"; do
    [[ $line == [[:space:]]#\#* || $line != *fpath* ]] && continue
    for form in $forms; do
      [[ $line == *"$form"* ]] && return 0
    done
  done
  return 1
}

backup_rc() {
  local backup=$rc.bak.$(date +%Y%m%d%H%M%S)
  cp -p -- $rc $backup
  info "backed up ${(D)rc} to ${(D)backup}"
}

add_to_rc() {
  local entry
  if [[ $dir == $HOME/* ]]; then
    entry="\"\$HOME/${dir#$HOME/}\""
  else
    entry=${(qq)dir}
  fi
  local -a block=(
    $MARK_BEGIN
    '# Must come before compinit (oh-my-zsh runs compinit when it is sourced).'
    "fpath=($entry \$fpath)"
  )

  if [[ ! -e $rc ]]; then
    print -rl -- $block 'autoload -Uz compinit && compinit' $MARK_END > $rc
    info "created ${(D)rc} with fpath and compinit"
    return
  fi

  local -a lines=( "${(@f)$(<$rc)}" )
  local -i i at=0
  # The first non-comment line that runs compinit, directly or via oh-my-zsh.
  for (( i = 1; i <= $#lines; i++ )); do
    [[ $lines[i] == [[:space:]]#\#* ]] && continue
    if [[ $lines[i] == *compinit* ||
          $lines[i] == [[:space:]]#(source|.)[[:space:]]##*oh-my-zsh.sh* ]]; then
      at=i
      break
    fi
  done

  backup_rc
  if (( at )); then
    # Write in place so permissions and symlinked dotfiles are preserved.
    print -rl -- "${(@)lines[1,at-1]}" $block $MARK_END "" "${(@)lines[at,-1]}" >| $rc
    info "added fpath entry to ${(D)rc} before line $at: $lines[at]"
  else
    print -rl -- "" $block 'autoload -Uz compinit && compinit' $MARK_END >> $rc
    info "no compinit found; appended fpath and compinit to ${(D)rc}"
  fi
}

remove_from_rc() {
  [[ -r $rc ]] || return 0
  local -a lines=( "${(@f)$(<$rc)}" ) kept
  local -i inside=0 found=0
  local line
  for line in $lines; do
    if [[ $line == $MARK_BEGIN ]]; then inside=1 found=1; continue; fi
    if (( inside )); then
      [[ $line == $MARK_END ]] && inside=0
      continue
    fi
    kept+=( $line )
  done
  if (( found )); then
    backup_rc
    print -rl -- "${(@)kept}" >| $rc
    info "removed the installer's block from ${(D)rc}"
  elif rc_has_dir; then
    info "${(D)rc} has an fpath line for ${(D)dir} that this script did not add; left it alone"
  fi
}

# --- compinit cache --------------------------------------------------------

clear_compdump() {
  local -a dumps=( ${ZDOTDIR:-$HOME}/.zcompdump*(N) )
  [[ -n ${ZSH_COMPDUMP:-} ]] && dumps+=( $ZSH_COMPDUMP(N) $ZSH_COMPDUMP.zwc(N) )
  dumps=( ${(u)dumps} )
  if (( $#dumps )); then
    rm -f -- $dumps
    local d
    local -a shown
    for d in $dumps; do shown+=( ${(D)d} ); done
    info "deleted compinit cache: ${(j:, :)shown}"
  fi
}

# Starts a fresh interactive shell and reports which _container it would use.
verify() {
  local out
  out=$(zsh -i -c 'print -r -- "@@${_comps[container]:-}@@"
                   local d; for d in $fpath; do
                     [[ -r $d/_container ]] && { print -r -- "@@$d/_container@@"; break }
                   done' </dev/null 2>/dev/null) || true
  local -a found=( ${(M)${(f)out}:#*@@*@@*} )
  found=( ${${found#*@@}%@@*} )
  if [[ ${found[1]:-} == _container && ${found[2]:-} == $dir/_container ]]; then
    info "verified: a new shell completes container with ${(D)found[2]}"
  elif [[ ${found[1]:-} == _container ]]; then
    warn "a new shell uses ${found[2]:-an unknown file}, which is earlier on fpath than ${(D)dir}"
  else
    warn "a new interactive shell did not register the completion; check that ${(D)dir} is on fpath before compinit"
  fi
}

# --- main ------------------------------------------------------------------

while (( $# )); do
  case $1 in
    (-d|--dir) (( $# >= 2 )) || die "$1 needs an argument"; dir=$2; shift ;;
    (--dir=*) dir=${1#--dir=} ;;
    (-n|--no-rc) edit_rc=0 ;;
    (-u|--uninstall) action=uninstall ;;
    (-h|--help) usage; exit 0 ;;
    (*) usage >&2; die "unknown option: $1" ;;
  esac
  shift
done
# Expand a leading ~ the shell left alone (e.g. --dir=~/x), then make it absolute.
[[ $dir == '~' || $dir == '~/'* ]] && dir=$HOME${dir#'~'}
dir=${dir:A}

case $action in
  (install)
    [[ -r $SCRIPT_DIR/_container ]] || die "_container not found next to install.sh"
    (( $+commands[container] )) ||
      warn "the container CLI is not on PATH; the completion will be ready once it is"

    mkdir -p -- $dir
    cp -- $SCRIPT_DIR/_container $dir/_container
    chmod 644 $dir/_container
    info "installed ${(D)dir}/_container"

    if (( edit_rc )); then
      if rc_has_dir; then
        info "${(D)rc} already puts ${(D)dir} on fpath"
      else
        add_to_rc
      fi
    fi

    clear_compdump
    (( edit_rc )) && verify
    info "done; run 'exec zsh' (or open a new terminal) to start using it"
    ;;
  (uninstall)
    if [[ -e $dir/_container ]]; then
      rm -f -- $dir/_container
      info "removed ${(D)dir}/_container"
    else
      info "${(D)dir}/_container is not installed"
    fi
    (( edit_rc )) && remove_from_rc
    clear_compdump
    info "done; run 'exec zsh' to reload completion"
    ;;
esac
