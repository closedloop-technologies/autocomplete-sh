#!/usr/bin/env bats
# Isolated installer contract tests.
#
# Installer tests start WITHOUT a staged runtime target: docs/install.sh is
# driven directly with HOME pointed at the isolated temp home, so no real
# configuration, rc file, or executable can ever be touched.

load test_helper

setup() {
    setup_test_home
}

teardown() {
    teardown_test_home
}

# Run docs/install.sh with a given --shell and --version against an isolated
# home. The target directory is on PATH by default; callers can override PATH
# to exercise the installer's mutation-free prerequisite failure.
run_installer() {
    local shell="$1" version="$2" install_home="${3:-$TEST_HOME}"
    local installer_path="${4:-$install_home/.local/bin:$PATH}"
    run env HOME="$install_home" PATH="$installer_path" \
        TEST_REPO_ROOT="$TEST_REPO_ROOT" \
        bash -c 'cd "$TEST_REPO_ROOT" && exec sh docs/install.sh --shell "$1" --version "$2"' \
        _ "$shell" "$version"
}

assert_missing_target_path_is_non_mutating() {
    local shell="$1"
    local bashrc_before="$BATS_TEST_TMPDIR/bashrc.before"
    local zshrc_before="$BATS_TEST_TMPDIR/zshrc.before"

    printf 'export KEEP_BASH=1\n' > "$HOME/.bashrc"
    printf 'export KEEP_ZSH=1\n' > "$HOME/.zshrc"
    cp "$HOME/.bashrc" "$bashrc_before"
    cp "$HOME/.zshrc" "$zshrc_before"
    rm -rf "$HOME/.local" "$HOME/.autocomplete"

    run_installer "$shell" dev "$HOME" "/usr/bin:/bin"

    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR: $HOME/.local/bin is not in PATH."* ]]
    [ ! -e "$HOME/.local" ]
    [ ! -e "$HOME/.autocomplete" ]
    cmp -s "$HOME/.bashrc" "$bashrc_before"
    cmp -s "$HOME/.zshrc" "$zshrc_before"
    [ ! -e "$HOME/.bashrc.autocomplete.bak" ]
    [ ! -e "$HOME/.zshrc.autocomplete.bak" ]
}

assert_unmatched_opener_tail_survives() {
    local shell="$1" rc_file expected
    case "$shell" in
        bash) rc_file="$HOME/.bashrc" ;;
        zsh) rc_file="$HOME/.zshrc" ;;
    esac
    expected="$BATS_TEST_TMPDIR/$shell.expected-rc"

    {
        printf 'export BEFORE_UNMATCHED=1\n'
        printf '# >>> autocomplete.sh >>>\n'
        printf 'export AFTER_UNMATCHED=two\n'
        printf 'printf "tail content survives\\n"\n'
    } > "$rc_file"
    {
        cat "$rc_file"
        printf '\n# >>> autocomplete.sh >>>\n'
        printf 'source %s enable\n' "$HOME/.local/bin/autocomplete"
        printf '# <<< autocomplete.sh <<<\n'
    } > "$expected"

    run_installer "$shell" dev

    [ "$status" -eq 0 ]
    cmp -s "$rc_file" "$expected"
}

assert_quoted_runtime_path_is_sourceable() {
    local shell="$1" rc_file
    local install_home="$TEST_HOME/user's home"
    mkdir -p "$install_home"
    case "$shell" in
        bash) rc_file="$install_home/.bashrc" ;;
        zsh) rc_file="$install_home/.zshrc" ;;
    esac
    : > "$rc_file"

    run_installer "$shell" dev "$install_home"

    [ "$status" -eq 0 ]
    [ -x "$install_home/.local/bin/autocomplete" ]
    [ "$(grep -c '# >>> autocomplete.sh >>>' "$rc_file")" -eq 1 ]

    case "$shell" in
        bash)
            run env HOME="$install_home" \
                PATH="$install_home/.local/bin:$PATH" \
                bash --noprofile --norc -c '
                    source "$HOME/.bashrc" >/dev/null 2>&1 &&
                    [[ "$ACSH_SCRIPT_PATH" == "$HOME/.local/bin/autocomplete" ]] &&
                    [[ "$(command -v autocomplete)" == "$HOME/.local/bin/autocomplete" ]] &&
                    check_if_enabled
                '
            ;;
        zsh)
            run env HOME="$install_home" \
                PATH="$install_home/.local/bin:$PATH" \
                zsh -f -c '
                    source "$HOME/.zshrc" >/dev/null 2>&1 &&
                    [[ "$ACSH_SCRIPT_PATH" == "$HOME/.local/bin/autocomplete" ]] &&
                    [[ "$(command -v autocomplete)" == "$HOME/.local/bin/autocomplete" ]] &&
                    check_if_enabled
                '
            ;;
    esac
    [ "$status" -eq 0 ]
}

@test "dev install (bash) installs one 0755 executable, 0600 config, one managed block" {
    run_installer bash dev
    [ "$status" -eq 0 ]
    [[ "$output" == *"Done."* ]]

    [ -f "$HOME/.local/bin/autocomplete" ]
    [ -x "$HOME/.local/bin/autocomplete" ]
    [ "$(stat -c %a "$HOME/.local/bin/autocomplete")" = "755" ]
    [ "$(stat -c %a "$HOME/.autocomplete/config")" = "600" ]

    [ "$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")" -eq 1 ]
    grep -q 'enable' "$HOME/.bashrc"

    # A second install must not duplicate the managed block.
    run_installer bash dev
    [ "$status" -eq 0 ]
    [ "$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")" -eq 1 ]
}

@test "dev install (zsh) installs the target and one managed block" {
    require_zsh
    run_installer zsh dev
    [ "$status" -eq 0 ]
    [ -f "$HOME/.local/bin/autocomplete" ]
    [ -x "$HOME/.local/bin/autocomplete" ]

    [ "$(grep -c '# >>> autocomplete' "$HOME/.zshrc")" -eq 1 ]
    grep -q 'enable' "$HOME/.zshrc"
}

@test "missing target PATH aborts Bash install before any home mutation" {
    assert_missing_target_path_is_non_mutating bash
}

@test "missing target PATH aborts Zsh install before any home mutation" {
    require_zsh
    assert_missing_target_path_is_non_mutating zsh
}

@test "Bash install preserves an unmatched managed-block opener and its entire tail" {
    assert_unmatched_opener_tail_survives bash
}

@test "Zsh install preserves an unmatched managed-block opener and its entire tail" {
    require_zsh
    assert_unmatched_opener_tail_survives zsh
}

@test "Bash install quotes a runtime path containing spaces and an apostrophe" {
    assert_quoted_runtime_path_is_sourceable bash
}

@test "Zsh install quotes a runtime path containing spaces and an apostrophe" {
    require_zsh
    assert_quoted_runtime_path_is_sourceable zsh
}

@test "a missing dependency aborts preflight with the install untouched" {
    run_installer bash dev
    [ "$status" -eq 0 ]
    cp "$HOME/.local/bin/autocomplete" "$TEST_HOME/before-script"
    blocks_before=$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")

    # PATH with every system tool except bc: preflight must fail before any
    # mutation (target ls, startup block, config).
    strip_dir="$TEST_HOME/depbin"
    mkdir -p "$strip_dir"
    for tool in /usr/bin/*; do
        [ -x "$tool" ] || continue
        name=${tool##*/}
        [ "$name" = "bc" ] && continue
        ln -s "$tool" "$strip_dir/$name" 2>/dev/null || true
    done

    run bash -c "cd \"\$TEST_REPO_ROOT\" && exec env HOME=\"\$TEST_HOME\" PATH=\"\$TEST_HOME/.local/bin:$strip_dir:\$TEST_REPO_ROOT/tests/helpers\" /bin/sh docs/install.sh --shell bash --version dev"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Required tool"* ]]

    cmp -s "$HOME/.local/bin/autocomplete" "$TEST_HOME/before-script"
    [ "$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")" -eq "$blocks_before" ]
}

@test "a syntax-invalid staged executable leaves the prior install unchanged" {
    run_installer bash dev
    [ "$status" -eq 0 ]
    cp "$HOME/.local/bin/autocomplete" "$TEST_HOME/before-script"
    blocks_before=$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")

    broken_dir="$TEST_HOME/broken"
    mkdir -p "$broken_dir"
    printf '#!/bin/bash\nif [[\n' > "$broken_dir/autocomplete.sh"

    run bash -c "cd \"$broken_dir\" && exec env HOME=\"\$TEST_HOME\" sh \"\$TEST_REPO_ROOT/docs/install.sh\" --shell bash --version dev"
    [ "$status" -ne 0 ]
    [[ "$output" == *"syntax check"* ]]

    cmp -s "$HOME/.local/bin/autocomplete" "$TEST_HOME/before-script"
    [ "$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")" -eq "$blocks_before" ]
}

@test "autocomplete remove cleans project files and the managed block but keeps unrelated lines" {
    run_installer bash dev
    [ "$status" -eq 0 ]
    [ -f "$HOME/.autocomplete/config" ]
    [ -d "$HOME/.autocomplete/cache" ]

    # An unrelated line that merely CONTAINS the word autocomplete must survive.
    echo 'export ACSH_STYLE="fancy-autocomplete-mode"' >> "$HOME/.bashrc"

    run env HOME="$TEST_HOME" "$HOME/.local/bin/autocomplete" remove -y
    [ "$status" -eq 0 ]

    [ ! -e "$HOME/.local/bin/autocomplete" ]
    [ ! -e "$HOME/.autocomplete/config" ]
    [ ! -e "$HOME/.autocomplete/cache" ]
    [ ! -e "$HOME/.autocomplete/autocomplete.log" ]

    if grep -q '# >>> autocomplete.sh >>>' "$HOME/.bashrc"; then
        return 1
    fi
    grep -q -F 'export ACSH_STYLE="fancy-autocomplete-mode"' "$HOME/.bashrc"
}

@test "Zsh remove cleans project files and its managed block but keeps unrelated lines" {
    require_zsh
    run_installer zsh dev
    [ "$status" -eq 0 ]
    [ -f "$HOME/.autocomplete/config" ]
    [ -d "$HOME/.autocomplete/cache" ]
    printf 'cached\n' > "$HOME/.autocomplete/cache/acsh-v1-test.txt"
    printf 'usage\n' > "$HOME/.autocomplete/autocomplete.log"
    echo 'export ACSH_STYLE="fancy-autocomplete-mode"' >> "$HOME/.zshrc"

    run env HOME="$TEST_HOME" PATH="$HOME/.local/bin:$PATH" \
        "$HOME/.local/bin/autocomplete" remove -y
    [ "$status" -eq 0 ]

    [ ! -e "$HOME/.local/bin/autocomplete" ]
    [ ! -e "$HOME/.autocomplete/config" ]
    [ ! -e "$HOME/.autocomplete/cache" ]
    [ ! -e "$HOME/.autocomplete/autocomplete.log" ]
    if grep -q '# >>> autocomplete.sh >>>' "$HOME/.zshrc"; then
        return 1
    fi
    grep -q -F 'export ACSH_STYLE="fancy-autocomplete-mode"' "$HOME/.zshrc"
}