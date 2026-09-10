#!/usr/bin/env bats
# Completion-behavior contract tests.
#
# Bash: `enable` must install the native-only `_acsh_native_complete` default
# handler (lazy-loading real definitions only, returning 124 ONLY for them),
# never `_comp_complete_minimal`, and restore pre-existing -D/-E specs. Zsh:
# ordinary (native) completion stays intact; only `_autocompletesh_cli` is
# registered for the `autocomplete` command. Tab never touches a provider.
#
# Every assertion runs in a pristine child shell (`env -i`) so no completion
# state or environment variable leaks between tests.

load test_helper

setup() {
    setup_test_home
    load_runtime bash
}

teardown() {
    unset OPENAI_API_KEY
    teardown_test_home
}

run_clean_bash() {
    local -a envs=(HOME="$TEST_HOME" PATH="$PATH")
    if [ -n "${ACSH_TEST_CURL_LOG:-}" ]; then
        envs+=(ACSH_TEST_CURL_LOG="$ACSH_TEST_CURL_LOG")
    fi
    run env -i "${envs[@]}" bash -c "$1"
}

run_clean_zsh() {
    require_zsh
    local -a envs=(HOME="$TEST_HOME" PATH="$PATH")
    if [ -n "${ACSH_TEST_CURL_LOG:-}" ]; then
        envs+=(ACSH_TEST_CURL_LOG="$ACSH_TEST_CURL_LOG")
    fi
    run env -i "${envs[@]}" zsh -f -c "$1"
}

@test "bash enable registers _acsh_native_complete with bashdefault/default options" {
    run_clean_bash '
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        complete -p -D
        complete -p -E
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"_acsh_native_complete"* ]]
    [[ "$output" == *"-o bashdefault"* ]]
    [[ "$output" == *"-o default"* ]]
}

@test "Bash AI bindings honor custom sequences unregister cleanly and allow empty disable" {
    run_clean_bash '
        ACSH_AI_COMPLETE_KEY="\C-x\C-c"
        ACSH_AI_REWRITE_KEY="\C-x\C-r"
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        enabled=$(bind -X 2>/dev/null)
        [[ "$enabled" == *"_ai_complete_key"* && "$enabled" == *"\C-x\C-c"* ]] &&
            echo complete=present
        [[ "$enabled" == *"_ai_rewrite_key"* && "$enabled" == *"\C-x\C-r"* ]] &&
            echo rewrite=present

        source "$HOME/.local/bin/autocomplete" disable >/dev/null 2>&1 || exit 10
        disabled=$(bind -X 2>/dev/null)
        [[ "$disabled" != *"_ai_complete_key"* && "$disabled" != *"_ai_rewrite_key"* ]] &&
            echo disabled=clean

        ACSH_AI_COMPLETE_KEY=
        ACSH_AI_REWRITE_KEY=
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 11
        empty=$(bind -X 2>/dev/null)
        [[ "$empty" != *"_ai_complete_key"* && "$empty" != *"_ai_rewrite_key"* ]] &&
            echo empty=clean
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"complete=present"* ]]
    [[ "$output" == *"rewrite=present"* ]]
    [[ "$output" == *"disabled=clean"* ]]
    [[ "$output" == *"empty=clean"* ]]
}

@test "check_if_enabled identifies only the native -D handler and follows disable" {
    run_clean_bash '
        _pre_default() { COMPREPLY=(); }
        complete -D -F _pre_default
        if check_if_enabled; then echo state1=on; else echo state1=off; fi
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        if check_if_enabled; then echo state2=on; else echo state2=off; fi
        source "$HOME/.local/bin/autocomplete" disable >/dev/null 2>&1 || exit 9
        if check_if_enabled; then echo state3=on; else echo state3=off; fi
    '
    [[ "$output" == *"state1=off"* ]]
    [[ "$output" == *"state2=on"* ]]
    [[ "$output" == *"state3=off"* ]]
}

@test "disable restores pre-existing -D/-E specs and deregisters the CLI completion" {
    run_clean_bash '
        _pre_default() { COMPREPLY=(d); }
        _pre_empty() { COMPREPLY=(e); }
        complete -D -F _pre_default
        complete -E -F _pre_empty
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        during_default=$(complete -p -D)
        echo "during=$during_default"
        source "$HOME/.local/bin/autocomplete" disable >/dev/null 2>&1 || exit 9
        echo "default=$(complete -p -D)"
        echo "empty=$(complete -p -E)"
        if complete -p autocomplete >/dev/null 2>&1; then echo "cli=present"; else echo "cli=absent"; fi
    '
    [[ "$output" == *"_acsh_native_complete -D"* ]]
    [[ "$output" == *"-o bashdefault"* && "$output" == *"-o default"* ]]
    [[ "$output" == *"default=complete"* ]]
    [[ "$output" == *"_pre_default -D"* ]]
    [[ "$output" == *"_pre_empty -E"* ]]
    [[ "$output" == *"cli=absent"* ]]
}

@test "disable preserves independent user -D/-E replacements made after enable" {
    run_clean_shell bash '
        _pre_default() { COMPREPLY=(stale-default); }
        _pre_empty() { COMPREPLY=(stale-empty); }
        complete -o default -F _pre_default -D
        complete -o bashdefault -F _pre_empty -E

        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9

        _user_default() { COMPREPLY=(current-default); }
        _user_empty() { COMPREPLY=(current-empty); }
        complete -o nospace -F _user_default -D
        complete -o filenames -F _user_empty -E

        source "$HOME/.local/bin/autocomplete" disable >/dev/null 2>&1 || exit 9
        printf "default=%s\n" "$(complete -p -D)"
        printf "empty=%s\n" "$(complete -p -E)"
    '
    [ "$status" -eq 0 ]
    [[ "$output" == *"default=complete -o nospace -F _user_default -D"* ]]
    [[ "$output" == *"empty=complete -o filenames -F _user_empty -E"* ]]
    [[ "$output" != *"_pre_default"* ]]
    [[ "$output" != *"_pre_empty"* ]]
}

@test "tab on an unknown command lazy-loads a real completion definition (rc 124)" {
    mkdir -p "$HOME/.local/share/bash-completion/completions"
    cat > "$HOME/.local/share/bash-completion/completions/acshfixture" <<'EOF'
_acshfixture_complete() { COMPREPLY=(alpha beta); }
complete -F _acshfixture_complete acshfixture
EOF
    run_clean_bash '
        export BASH_COMPLETION_USER_FILE="$HOME/.local/share/bash-completion/completions"
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        if ! declare -F _comp_load >/dev/null 2>&1; then
            [ -f /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion
            [ -f /etc/bash_completion ] && source /etc/bash_completion
        fi
        if ! declare -F _comp_load >/dev/null 2>&1; then
            echo "NO_COMP_LOAD"
            exit 0
        fi
        COMP_WORDS=(acshfixture)
        COMP_CWORD=1
        _acsh_native_complete
        echo "rc=$?"
        complete -p acshfixture 2>/dev/null || echo "no-spec"
    '
    [[ "$output" != *"NO_COMP_LOAD"* ]]
    [[ "$output" == *"rc=124"* ]]
    [[ "$output" == *"complete -F _acshfixture_complete acshfixture"* ]]
}

@test "double-Tab on an unknown command never installs minimal completion or calls a provider" {
    export ACSH_TEST_CURL_LOG="$TEST_HOME/curl.log"
    run_clean_bash '
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        COMP_WORDS=(nosuchcmd_xyz_42)
        COMP_CWORD=1
        _acsh_native_complete
        r1=$?
        _acsh_native_complete
        r2=$?
        echo "r1=$r1"
        echo "r2=$r2"
        echo "minimal=$(complete -p | grep -c _comp_complete_minimal)"
        echo "curl=$(wc -l < "$ACSH_TEST_CURL_LOG" 2>/dev/null || echo 0)"
    '
    [[ "$output" != *"r1=0"* ]]
    [[ "$output" != *"r1=124"* ]]
    [[ "$output" != *"r2=0"* ]]
    [[ "$output" != *"r2=124"* ]]
    [[ "$output" == *"minimal=0"* ]]
    [[ "$output" == *"curl=0"* ]]
}

@test "existing -F and -C specs keep their options and are not lazy-loaded on tab" {
    run_clean_bash '
        _myfunc() { COMPREPLY=(x); }
        complete -o nospace -F _myfunc myfunc
        complete -C "printf x" extcmd
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        COMP_WORDS=(myfunc)
        COMP_CWORD=1
        _acsh_native_complete
        r1=$?
        COMP_WORDS=(extcmd)
        _acsh_native_complete
        r2=$?
        echo "r1=$r1"
        echo "r2=$r2"
        echo "spec1=$(complete -p myfunc)"
        echo "spec2=$(complete -p extcmd)"
    '
    [[ "$output" != *"r1=124"* ]]
    [[ "$output" != *"r2=124"* ]]
    [[ "$output" == *"nospace"* ]]
    [[ "$output" == *"_myfunc myfunc"* ]]
    [[ "$output" == *"spec2=complete -C"* ]]
    [[ "$output" == *"extcmd"* ]]
}

@test "the autocomplete CLI command gets _autocompletesh_cli completion (and only while enabled)" {
    run_clean_bash '
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        echo "spec=$(complete -p autocomplete)"
        source "$HOME/.local/bin/autocomplete" disable >/dev/null 2>&1 || exit 9
        if complete -p autocomplete >/dev/null 2>&1; then echo "cli=present"; else echo "cli=removed"; fi
    '
    [[ "$output" == *"spec=complete -F _autocompletesh_cli autocomplete"* ]]
    [[ "$output" == *"cli=removed"* ]]
}

@test "zsh keeps native compdefs, registers only _autocompletesh_cli, zero provider requests" {
    export ACSH_TEST_CURL_LOG="$TEST_HOME/curl.log"
    load_runtime zsh
    run_clean_zsh '
        autoload -Uz compinit
        compinit -u
        source "$HOME/.local/bin/autocomplete" enable >/dev/null 2>&1 || exit 9
        printf "cli=%s\n" "${_comps[autocomplete]-NONE}"
        printf "ls=%s\n" "${_comps[ls]-NONE}"
        count=0
        for k in "${(k)_comps[@]}"; do
            [[ "${_comps[$k]}" == "_autocompletesh_cli" ]] && count=$((count + 1))
        done
        printf "cli_users=%d\n" "$count"
        autocomplete --help >/dev/null 2>&1
    '
    [[ "$output" == *"cli=_autocompletesh_cli"* ]]
    [[ "$output" != *"cli=NONE"* ]]
    [[ "$output" == *"ls="* ]]
    [[ "$output" != *"ls=_autocompletesh_cli"* ]]
    [[ "$output" == *"cli_users=1"* ]]
    if [ -e "$ACSH_TEST_CURL_LOG" ]; then
        [ ! -s "$ACSH_TEST_CURL_LOG" ]
    fi
}