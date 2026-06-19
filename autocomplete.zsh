#!/bin/zsh
# Autocomplete.zsh - zsh compatibility shim for Autocomplete.sh
# MIT License - ClosedLoop Technologies, Inc.
# Sean Kruzel 2024-2026

setopt no_nomatch 2>/dev/null || true

_ACSH_THIS_FILE=${0:A}
_ACSH_THIS_DIR=${_ACSH_THIS_FILE:h}
_ACSH_BASH_IMPL=${ACSH_BASH_IMPL:-"$_ACSH_THIS_DIR/autocomplete.sh"}

if [[ ! -f "$_ACSH_BASH_IMPL" ]]; then
  _ACSH_BIN=$(command -v autocomplete 2>/dev/null || true)
  if [[ -n "$_ACSH_BIN" && "$_ACSH_BIN" != "$_ACSH_THIS_FILE" ]]; then
    _ACSH_BASH_IMPL="$_ACSH_BIN"
  fi
fi

_acsh_zsh_error() {
  print -u2 -- "Autocomplete.zsh - $*"
}

_autocompletesh_zsh() {
  local -a suggestions
  if [[ ! -x "$_ACSH_BASH_IMPL" && ! -f "$_ACSH_BASH_IMPL" ]]; then
    return 1
  fi
  suggestions=(${(f)$(bash "$_ACSH_BASH_IMPL" __complete "$BUFFER" 2>/dev/null)})
  if (( ${#suggestions[@]} )); then
    compadd -Q -- $suggestions
  fi
}

case "${1:-}" in
  enable)
    autoload -Uz compinit && compinit -u
    compdef _autocompletesh_zsh -default-
    ;;
  disable)
    compdef -d -default- 2>/dev/null || true
    ;;
  *)
    if [[ ! -f "$_ACSH_BASH_IMPL" ]]; then
      _acsh_zsh_error "Could not find autocomplete.sh. Set ACSH_BASH_IMPL=/path/to/autocomplete.sh."
      exit 1
    fi
    exec bash "$_ACSH_BASH_IMPL" "$@"
    ;;
esac
