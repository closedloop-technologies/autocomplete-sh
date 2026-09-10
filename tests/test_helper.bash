#!/usr/bin/env bash
# Shared offline-test harness for the autocomplete-sh P0 suite.
#
# Every test gets a fully isolated HOME (no user config, no runtime binary) so
# the suite is deterministic and never touches the developer's real environment
# or the network. The REPO's own runtime scripts are staged into the temp HOME
# by load_runtime; the installer tests start WITHOUT a staged target and drive
# docs/install.sh directly.

# Directory containing the repo root (the parent of tests/).
TEST_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export TEST_REPO_ROOT

setup_test_home() {
    # Remove any leftover home from a previous test (defensive: setup always
    # pairs with teardown, but a failed teardown must not poison the next test).
    if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
        rm -rf "$TEST_HOME"
    fi
    # Never inherit autocomplete state from the launching environment: config
    # values are exported at `enable` time and would otherwise leak into every
    # subprocess (e.g. a real $HOME/.autocomplete/config).
    unset "${!ACSH_@}" 2>/dev/null || true
    _ACSH_ORIG_HOME="${_ACSH_ORIG_HOME:-$HOME}"
    TEST_HOME="$(mktemp -d "${TMPDIR:-/tmp}/acsh-test.XXXXXX")"
    export TEST_HOME HOME="$TEST_HOME"

    # Fresh, empty rc files as the installer/test would see them.
    : > "$HOME/.bashrc"
    : > "$HOME/.zshrc"

    # Project config/cache locations, empty.
    mkdir -p "$HOME/.autocomplete/cache"
    mkdir -p "$HOME/.local/bin"

    # The fake curl and the staged runtime must win over any system commands.
    export PATH="$TEST_REPO_ROOT/tests/helpers:$HOME/.local/bin:$PATH"
}

# Stage the repo's runtime for one shell into $HOME/.local/bin/autocomplete
# (0755). For bash this also sources it with `enable`, exactly like the managed
# startup block does. Zsh cannot be sourced from a bash bats process: zsh tests
# call `source "$HOME/.local/bin/autocomplete" enable` themselves inside a
# `zsh -f -c '...'` subprocess after calling `load_runtime zsh`.
load_runtime() {
    local shell="$1" script
    case "$shell" in
        bash) script="$TEST_REPO_ROOT/autocomplete.sh" ;;
        zsh)  script="$TEST_REPO_ROOT/autocomplete.zsh" ;;
        *)
            echo "load_runtime: unknown shell '$shell' (expect bash or zsh)" >&2
            return 1
            ;;
    esac
    if [ ! -f "$script" ]; then
        echo "load_runtime: runtime script not found: $script" >&2
        return 1
    fi
    mkdir -p "$HOME/.local/bin"
    cp "$script" "$HOME/.local/bin/autocomplete"
    chmod 0755 "$HOME/.local/bin/autocomplete"
    if [ "$shell" = "bash" ]; then
        # shellcheck disable=SC1090
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || true
    fi
}

# The distributed Zsh artifact uses /bin/zsh in its shebang. Skip when that
# exact interpreter is unavailable; finding an unrelated zsh elsewhere on PATH
# would make direct executable tests fail for the wrong reason.
require_zsh() {
    if [ ! -x /bin/zsh ]; then
        skip "/bin/zsh not installed"
    fi
}

# Run a script in a pristine instance of its matching shell. Only the isolated
# home, controlled PATH, fake transport controls, provider keys, and explicit
# context sentinels cross the env -i boundary.
run_clean_shell() {
    local shell="$1"
    local script="$2"
    local name
    local -a clean_env=(HOME="$TEST_HOME" PATH="$PATH")
    local -a propagated_names=(
        ACSH_TEST_CURL_LOG
        ACSH_TEST_HEADERS_FILE
        ACSH_TEST_BODY_FILE
        ACSH_TEST_RESPONSE_FILE
        ACSH_TEST_STATUS
        ACSH_TEST_DELAY
        OPENAI_API_KEY
        ANTHROPIC_API_KEY
        GROQ_API_KEY
        LLM_API_KEY
        OLLAMA_API_KEY
        OPENAI_COMPATIBLE_API_KEY
        AAA_CONTEXT_FIRST
        BBB_CONTEXT_MULTILINE
        CCC_CONTEXT_LAST
        ACSH_CONTEXT_MUST_HIDE
    )

    for name in "${propagated_names[@]}"; do
        if [[ -v "$name" ]]; then
            clean_env+=("$name=${!name}")
        fi
    done

    case "$shell" in
        bash)
            run env -i "${clean_env[@]}" bash --noprofile --norc -c "$script"
            ;;
        zsh)
            require_zsh
            run env -i "${clean_env[@]}" zsh -f -c "$script"
            ;;
        *)
            echo "run_clean_shell: unknown shell '$shell' (expect bash or zsh)" >&2
            return 2
            ;;
    esac
}

# Count only answer-cache entries, regardless of which runtime created them.
cache_file_count() {
    local cache_dir="$HOME/.autocomplete/cache"
    if [ ! -d "$cache_dir" ]; then
        echo 0
        return
    fi
    find "$cache_dir" -maxdepth 1 -type f -name 'acsh-v1-*.txt' -print 2>/dev/null |
        wc -l
}

teardown_test_home() {
    if [ -n "${TEST_HOME:-}" ] && [ -d "$TEST_HOME" ]; then
        rm -rf "$TEST_HOME"
    fi
    unset TEST_HOME \
        ACSH_TEST_CURL_LOG ACSH_TEST_HEADERS_FILE ACSH_TEST_BODY_FILE \
        ACSH_TEST_RESPONSE_FILE ACSH_TEST_STATUS ACSH_TEST_DELAY \
        OPENAI_API_KEY ANTHROPIC_API_KEY GROQ_API_KEY OLLAMA_API_KEY \
        LLM_API_KEY \
        OPENAI_COMPATIBLE_API_KEY \
        AAA_CONTEXT_FIRST BBB_CONTEXT_MULTILINE CCC_CONTEXT_LAST \
        ACSH_CONTEXT_MUST_HIDE
    # Do not leak runtime state between tests (each test rebuilds its own).
    unset "${!ACSH_@}" 2>/dev/null || true
    if [ -n "${_ACSH_ORIG_HOME:-}" ]; then
        export HOME="$_ACSH_ORIG_HOME"
        unset _ACSH_ORIG_HOME
    fi
}