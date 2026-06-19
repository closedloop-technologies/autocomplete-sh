#!/usr/bin/env bash
set -euo pipefail

bash -n autocomplete.sh
sh -n docs/install.sh
if command -v zsh >/dev/null 2>&1; then
  zsh -n autocomplete.zsh
fi

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck autocomplete.sh docs/install.sh run_tests.sh
else
  echo "shellcheck not installed; skipping shellcheck"
fi

if command -v bats >/dev/null 2>&1; then
  bats tests
else
  echo "bats not installed; skipping Bats tests"
fi
