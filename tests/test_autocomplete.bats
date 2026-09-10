#!/usr/bin/env bats
# Offline, fully isolated observable-contract tests for both distributed runtimes.

load test_helper

setup() {
    setup_test_home
    prepare_shell bash
}

teardown() {
    teardown_test_home
}

runtime_path() {
    printf '%s\n' "$HOME/.local/bin/autocomplete"
}

prepare_shell() {
    local shell="$1"
    rm -rf "$HOME/.autocomplete"
    rm -f "$HOME/.local/bin/autocomplete"
    : > "$HOME/.bashrc"
    : > "$HOME/.zshrc"
    mkdir -p "$HOME/.autocomplete/cache" "$HOME/.local/bin"
    load_runtime "$shell"
    run "$(runtime_path)" install
    if [ "$status" -ne 0 ]; then
        echo "prepare_shell $shell failed: $output" >&2
        return 1
    fi
}

config_set() {
    run "$(runtime_path)" config set "$1" "$2"
    [ "$status" -eq 0 ]
}

use_offline_provider() {
    config_set provider openai-compatible
    config_set endpoint https://api.test.local/v1/chat/completions
}

request_count() {
    local log=${ACSH_TEST_CURL_LOG:-}
    if [ -n "$log" ] && [ -f "$log" ]; then
        wc -l < "$log"
    else
        echo 0
    fi
}

assert_no_usage_log() {
    [ ! -e "$HOME/.autocomplete/autocomplete.log" ] || [ ! -s "$HOME/.autocomplete/autocomplete.log" ]
}

write_openai_commands_fixture() {
    local output_file="$1" commands_json="$2"
    jq -c --argjson commands "$commands_json" \
        '.choices[0].message.tool_calls[0].function.arguments = ({commands: $commands} | tojson)' \
        "$TEST_REPO_ROOT/tests/fixtures/openai-success.json" > "$output_file"
}

@test "autocomplete is installed on PATH and executable" {
    run command -v autocomplete
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.local/bin/autocomplete" ]
    [ -x "$HOME/.local/bin/autocomplete" ]
}

@test "autocomplete banner identifies autocomplete.sh" {
    run autocomplete
    [ "$status" -eq 0 ]
    [[ "$output" =~ [Aa]utocomplete\.sh ]]
}

@test "install builds the default config with every P0 key, mode 0600, one managed block" {
    local config_file="$HOME/.autocomplete/config"
    [ -f "$config_file" ]
    [ "$(stat -c %a "$config_file")" = "600" ]

    grep -q '^context_terminal: false' "$config_file"
    grep -q '^context_environment: false' "$config_file"
    grep -q '^context_history: false' "$config_file"
    grep -q '^context_recent_files: false' "$config_file"
    grep -q '^context_help: false' "$config_file"
    grep -q '^max_environment_names: 50' "$config_file"
    grep -q '^max_history_commands: 10' "$config_file"
    grep -q '^max_recent_files: 10' "$config_file"
    grep -q '^max_help_lines: 40' "$config_file"
    grep -q '^help_timeout_seconds: 0.25' "$config_file"
    grep -q '^request_timeout_seconds: 5' "$config_file"
    grep -q '^request_headers_json: {}' "$config_file"
    grep -q '^extra_body_json: {}' "$config_file"
    grep -q '^openai_compatible_api_key:' "$config_file"
    grep -q '^cache_size: 10' "$config_file"

    [ "$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")" -eq 1 ]
    grep -q 'enable' "$HOME/.bashrc"
    run autocomplete install
    [ "$status" -eq 0 ]
    [ "$(grep -c '# >>> autocomplete.sh >>>' "$HOME/.bashrc")" -eq 1 ]
}

@test "install never interpolates API keys into config" {
    local home2
    home2="$(mktemp -d)"
    run env HOME="$home2" OPENAI_API_KEY=sk-secret-value autocomplete install
    [ "$status" -eq 0 ]
    run grep -E '^openai_api_key:' "$home2/.autocomplete/config"
    [ "$output" = "openai_api_key:" ]
    rm -rf "$home2"
}

@test "autocomplete model openai gpt-4o-mini persists model to config" {
    run env OPENAI_API_KEY=sk-model-test-01 autocomplete model openai gpt-4o-mini
    [ "$status" -eq 0 ]

    run autocomplete config
    [ "$status" -eq 0 ]
    [[ "$output" == *"gpt-4o-mini"* ]]
}

@test "valid config updates are mode 0600 and invalid values leave both shell configs byte-identical" {
    require_zsh
    local shell config_file baseline key value i
    local -a invalid_keys=(
        provider
        context_terminal
        temperature
        api_prompt_cost
        api_completion_cost
        request_timeout_seconds
        help_timeout_seconds
        cache_size
        max_environment_names
        max_history_commands
        max_recent_files
        max_help_lines
        cache_size
        max_environment_names
        max_history_commands
        max_recent_files
        max_help_lines
        request_headers_json
        extra_body_json
        extra_body_json
        request_headers_json
        request_headers_json
        request_headers_json
        request_headers_json
    )
    local -a invalid_values=(
        unsupported-provider
        True
        -0.1
        -1
        -1
        0
        0
        0
        0
        0
        0
        0
        1.5
        1.5
        1.5
        1.5
        1.5
        '[]'
        '[]'
        '{"model":"forbidden"}'
        '{"Bad Header":"value"}'
        '{"Authorization":"Bearer forbidden"}'
        '{"content-type":"text/plain"}'
        $'{"X-Test":"line\nbreak"}'
    )

    for shell in bash zsh; do
        prepare_shell "$shell"
        config_set provider openai-compatible
        config_set request_headers_json '{"X-Valid":"a b"}'
        config_file="$HOME/.autocomplete/config"
        [ "$(stat -c %a "$config_file")" = "600" ]
        baseline="$TEST_HOME/config-$shell.baseline"
        cp "$config_file" "$baseline"

        for ((i = 0; i < ${#invalid_keys[@]}; i++)); do
            key=${invalid_keys[$i]}
            value=${invalid_values[$i]}
            run "$(runtime_path)" config set "$key" "$value"
            [ "$status" -ne 0 ] || {
                echo "$shell accepted invalid $key=$value" >&2
                return 1
            }
            cmp -s "$baseline" "$config_file" || {
                echo "$shell modified config after rejecting $key=$value" >&2
                return 1
            }
        done
    done
}

@test "OpenAI-compatible headers with spaces, extra body, payload schema, and optional or keyed auth work once per request in both shells" {
    require_zsh
    local shell auth_mode
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set model acsh-test-model
        config_set temperature 0.25
        config_set request_headers_json '{"X-Review":"a b"}'
        config_set extra_body_json '{"metadata":{"review label":"a b"},"max_tokens":256}'

        for auth_mode in optional keyed; do
            rm -rf "$HOME/.autocomplete/cache"
            mkdir -p "$HOME/.autocomplete/cache"
            rm -f "$HOME/.autocomplete/autocomplete.log"
            export ACSH_TEST_CURL_LOG="$TEST_HOME/curl-$shell-$auth_mode.log"
            export ACSH_TEST_HEADERS_FILE="$TEST_HOME/headers-$shell-$auth_mode.txt"
            export ACSH_TEST_BODY_FILE="$TEST_HOME/body-$shell-$auth_mode.json"
            rm -f "$ACSH_TEST_CURL_LOG" "$ACSH_TEST_HEADERS_FILE" "$ACSH_TEST_BODY_FILE"

            if [ "$auth_mode" = keyed ]; then
                config_set openai_compatible_api_key sk-compatible-test
            fi

            run "$(runtime_path)" command "provider request $auth_mode"
            [ "$status" -eq 0 ]
            [[ "$output" == *"systemctl --failed"* ]]
            [ "$(request_count)" -eq 1 ]
            grep -Fxq 'Content-Type: application/json' "$ACSH_TEST_HEADERS_FILE"
            grep -Fxq 'X-Review: a b' "$ACSH_TEST_HEADERS_FILE"
            if [ "$auth_mode" = optional ]; then
                ! grep -q '^Authorization:' "$ACSH_TEST_HEADERS_FILE"
            else
                [ "$(grep -c '^Authorization: Bearer sk-compatible-test$' "$ACSH_TEST_HEADERS_FILE")" -eq 1 ]
            fi

            jq -e '
                .model == "acsh-test-model"
                and .temperature == 0.25
                and (.messages | length) == 2
                and .messages[0].role == "system"
                and .messages[1].role == "user"
                and .response_format.type == "json_object"
                and .tool_choice.function.name == "bash_completions"
                and .tools[0].function.name == "bash_completions"
                and .metadata["review label"] == "a b"
                and .max_tokens == 256
            ' "$ACSH_TEST_BODY_FILE" >/dev/null
        done
    done
}

@test "Anthropic Groq and Ollama use their documented payload response and authentication contracts in both shells" {
    require_zsh
    local shell provider fixture secret
    export ACSH_TEST_STATUS=200

    for shell in bash zsh; do
        for provider in anthropic groq ollama; do
            prepare_shell "$shell"
            config_set provider "$provider"
            config_set endpoint "https://api.test.local/$provider"
            config_set model "acsh-$provider-model"
            secret=""
            case "$provider" in
                anthropic)
                    fixture=anthropic-success.json
                    secret=sk-anthropic-test
                    config_set anthropic_api_key "$secret"
                    ;;
                groq)
                    fixture=groq-success.json
                    secret=sk-groq-test
                    config_set groq_api_key "$secret"
                    ;;
                ollama)
                    fixture=ollama-success.json
                    ;;
            esac

            export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/$fixture"
            export ACSH_TEST_CURL_LOG="$TEST_HOME/curl-$shell-$provider.log"
            export ACSH_TEST_HEADERS_FILE="$TEST_HOME/headers-$shell-$provider.txt"
            export ACSH_TEST_BODY_FILE="$TEST_HOME/body-$shell-$provider.json"
            rm -f "$ACSH_TEST_CURL_LOG" "$ACSH_TEST_HEADERS_FILE" "$ACSH_TEST_BODY_FILE"

            run "$(runtime_path)" command "provider contract $provider"
            [ "$status" -eq 0 ]
            [[ "$output" == *"systemctl --failed"* ]]
            [ "$(request_count)" -eq 1 ]
            if [ -n "$secret" ]; then
                ! grep -Fq "$secret" "$ACSH_TEST_CURL_LOG"
            fi

            case "$provider" in
                anthropic)
                    grep -Fxq 'content-type: application/json' "$ACSH_TEST_HEADERS_FILE"
                    grep -Fxq 'anthropic-version: 2023-06-01' "$ACSH_TEST_HEADERS_FILE"
                    [ "$(grep -c '^x-api-key: sk-anthropic-test$' "$ACSH_TEST_HEADERS_FILE")" -eq 1 ]
                    jq -e '
                        .model == "acsh-anthropic-model"
                        and (.system | type == "string")
                        and (.messages | length == 1)
                        and .messages[0].role == "user"
                        and .max_tokens == 1024
                        and .tool_choice.name == "bash_completions"
                        and .tools[0].name == "bash_completions"
                    ' "$ACSH_TEST_BODY_FILE" >/dev/null
                    ;;
                groq)
                    grep -Fxq 'Content-Type: application/json' "$ACSH_TEST_HEADERS_FILE"
                    [ "$(grep -c '^Authorization: Bearer sk-groq-test$' "$ACSH_TEST_HEADERS_FILE")" -eq 1 ]
                    jq -e '
                        .model == "acsh-groq-model"
                        and .response_format.type == "json_object"
                        and (.messages | length == 2)
                    ' "$ACSH_TEST_BODY_FILE" >/dev/null
                    ;;
                ollama)
                    [ ! -s "$ACSH_TEST_HEADERS_FILE" ]
                    jq -e '
                        .model == "acsh-ollama-model"
                        and .format == "json"
                        and .stream == false
                        and .options.temperature == 0
                        and (.messages | length == 2)
                    ' "$ACSH_TEST_BODY_FILE" >/dev/null
                    ;;
            esac
        done
    done
}

@test "OpenAI-compatible custom header values preserve tabs in both shells" {
    require_zsh
    local shell headers_json
    headers_json=$(jq -nc --arg value $'left\tright' '{"X-Tab": $value}')
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set request_headers_json "$headers_json"
        export ACSH_TEST_HEADERS_FILE="$TEST_HOME/headers-tab-$shell.txt"
        export ACSH_TEST_CURL_LOG="$TEST_HOME/curl-tab-$shell.log"
        rm -f "$ACSH_TEST_HEADERS_FILE" "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "preserve tab header"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 1 ]
        grep -Fxq $'X-Tab: left\tright' "$ACSH_TEST_HEADERS_FILE"
    done
}

@test "API keys containing CR or LF fail before request in both shells" {
    require_zsh
    local shell
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        export OPENAI_API_KEY=$'sk-test\nInjected: value'
        export ACSH_TEST_CURL_LOG="$TEST_HOME/api-key-injection-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "reject injected API key"
        [ "$status" -ne 0 ]
        [ "$(request_count)" -eq 0 ]
        [ "$(cache_file_count)" -eq 0 ]
        assert_no_usage_log
        unset OPENAI_API_KEY
    done
}

@test "HTTP 500 is one failed attempt with no cache or usage log in both shells" {
    require_zsh
    local shell
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"
    export ACSH_TEST_STATUS=500

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        export ACSH_TEST_CURL_LOG="$TEST_HOME/http-500-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "server failure"
        [ "$status" -ne 0 ]
        [ "$(request_count)" -eq 1 ]
        [ "$(cache_file_count)" -eq 0 ]
        assert_no_usage_log
    done
}

@test "a fresh standalone dry-run loads persisted context without curl or cache and Zsh drops the dispatch word" {
    require_zsh
    local shell
    export AAA_CONTEXT_FIRST=visible-name-only
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set context_environment true
        config_set max_environment_names 1
        export ACSH_TEST_CURL_LOG="$TEST_HOME/dry-run-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run_clean_shell "$shell" '"$HOME/.local/bin/autocomplete" command --dry-run "show failed units"'
        [ "$status" -eq 0 ]
        [[ "$output" == *"AAA_CONTEXT_FIRST"* ]]
        [[ "$output" == *"show failed units"* ]]
        [ "$(request_count)" -eq 0 ]
        [ "$(cache_file_count)" -eq 0 ]
        if [ "$shell" = zsh ]; then
            [[ "$output" == *"user input: show failed units"* ]]
            [[ "$output" != *"user input: command show failed units"* ]]
        else
            [[ "$output" == *'User command: `show failed units`'* ]]
        fi
    done
}

@test "Bash AI actions dry-run persisted config preview numbered suggestions and never execute output" {
    local dry_context rewrite_commands rewrite_fixture
    use_offline_provider
    config_set model acsh-p1-model
    export ACSH_TEST_CURL_LOG="$TEST_HOME/p1-curl.log"
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"
    rm -f "$ACSH_TEST_CURL_LOG"

    run autocomplete ai-complete --dry-run "git ch"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mode: ai-completion"* ]]
    [[ "$output" == *"provider: openai-compatible"* ]]
    [[ "$output" == *"model: acsh-p1-model"* ]]
    [[ "$output" == *"current token: ch"* ]]
    dry_context="$output"

    run autocomplete context --mode ai-completion --dry-run "git ch"
    [ "$status" -eq 0 ]
    [ "$output" = "$dry_context" ]

    run autocomplete ai-rewrite --dry-run "show failed units"
    [ "$status" -eq 0 ]
    [[ "$output" == *"mode: ai-rewrite"* ]]
    [ "$(request_count)" -eq 0 ]
    [ "$(cache_file_count)" -eq 0 ]

    run autocomplete ai-complete "sys"
    [ "$status" -eq 0 ]
    [ "$output" = "1. systemctl --failed" ]
    [ "$(request_count)" -eq 1 ]

    rewrite_commands=$(jq -nc --arg command "touch $HOME/ai-must-not-run" '[$command]')
    rewrite_fixture="$TEST_HOME/openai-rewrite.json"
    write_openai_commands_fixture "$rewrite_fixture" "$rewrite_commands"
    export ACSH_TEST_RESPONSE_FILE="$rewrite_fixture"
    run autocomplete ai-rewrite "show failed units"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1. touch $HOME/ai-must-not-run"* ]]
    [ ! -e "$HOME/ai-must-not-run" ]
    [ "$(request_count)" -eq 2 ]
}

@test "terminal context contains only physical cwd, OS, shell, and terminal fields in both shells" {
    require_zsh
    local shell
    mkdir -p "$HOME/real-context"
    ln -s "$HOME/real-context" "$HOME/logical-context"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set context_terminal true

        run_clean_shell "$shell" '
            cd "$HOME/logical-context"
            export TERM=acsh-terminal-type USER=PRIVATE_USER_VALUE HOSTNAME=PRIVATE_HOST_VALUE OLDPWD=/private/previous
            "$HOME/.local/bin/autocomplete" command --dry-run "inspect terminal"
        '
        [ "$status" -eq 0 ]
        [[ "$output" == *"Current directory: $HOME/real-context"* ]]
        [[ "$output" == *"Operating system:"* ]]
        [[ "$output" == *"Shell:"* ]]
        [[ "$output" == *"Terminal type: acsh-terminal-type"* ]]
        [[ "$output" != *"$HOME/logical-context"* ]]
        [[ "$output" != *"PRIVATE_USER_VALUE"* ]]
        [[ "$output" != *"PRIVATE_HOST_VALUE"* ]]
        [[ "$output" != *"/private/previous"* ]]
        [[ "$output" != *"Username:"* ]]
        [[ "$output" != *"Hostname:"* ]]
        [[ "$output" != *"Home directory:"* ]]
        [[ "$output" != *"Previous directory:"* ]]
    done
}

@test "environment context emits sorted bounded names only and excludes multiline values and ACSH names in both shells" {
    require_zsh
    local shell
    export AAA_CONTEXT_FIRST=alpha-private-value
    export BBB_CONTEXT_MULTILINE=$'first-private-line\nLEAKED_CONTINUATION_LINE'
    export CCC_CONTEXT_LAST=outside-bound-private-value
    export ACSH_CONTEXT_MUST_HIDE=acsh-private-value

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set context_environment true
        config_set max_environment_names 2

        run_clean_shell "$shell" '"$HOME/.local/bin/autocomplete" command --dry-run "inspect environment"'
        [ "$status" -eq 0 ]
        [[ "$output" == *$'AAA_CONTEXT_FIRST\nBBB_CONTEXT_MULTILINE'* ]]
        [[ "$output" != *"CCC_CONTEXT_LAST"* ]]
        [[ "$output" != *"ACSH_CONTEXT_MUST_HIDE"* ]]
        [[ "$output" != *"alpha-private-value"* ]]
        [[ "$output" != *"first-private-line"* ]]
        [[ "$output" != *"LEAKED_CONTINUATION_LINE"* ]]
        [[ "$output" != *"outside-bound-private-value"* ]]
        [[ "$output" != *"acsh-private-value"* ]]
    done
}

@test "history context honors its bound and redacts digit-bearing sensitive assignments and Bearer credentials in both shells" {
    require_zsh
    local shell script

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set context_history true
        config_set max_history_commands 3

        if [ "$shell" = bash ]; then
            script='
                history -c
                history -s "echo OUTSIDE_HISTORY_BOUND"
                history -s "export DEPLOY_KEY9=s3cr3t-value"
                history -s "curl -H \"Authorization: Bearer bearer-private-77\" https://example.invalid"
                history -s "echo NEWEST_HISTORY_ENTRY"
                source "$HOME/.local/bin/autocomplete" command --dry-run "inspect history"
            '
        else
            script='
                fc -p "$HOME/.zsh_history"
                print -s -- "echo OUTSIDE_HISTORY_BOUND"
                print -s -- "export DEPLOY_KEY9=s3cr3t-value"
                print -s -- "curl -H \"Authorization: Bearer bearer-private-77\" https://example.invalid"
                print -s -- "echo NEWEST_HISTORY_ENTRY"
                source "$HOME/.local/bin/autocomplete" command --dry-run "inspect history"
            '
        fi

        run_clean_shell "$shell" "$script"
        [ "$status" -eq 0 ]
        [[ "$output" == *"DEPLOY_KEY9="* ]]
        [[ "$output" == *"Authorization: Bearer REDACTED"* ]]
        [[ "$output" == *"NEWEST_HISTORY_ENTRY"* ]]
        [[ "$output" == *"REDACTED"* ]]
        [[ "$output" != *"s3cr3t-value"* ]]
        [[ "$output" != *"bearer-private-77"* ]]
        [[ "$output" != *"OUTSIDE_HISTORY_BOUND"* ]]
    done
}

@test "recent-files context emits only the two newest bounded basenames in both shells" {
    require_zsh
    local shell work
    work="$HOME/recent-work"
    mkdir -p "$work"
    : > "$work/oldest.txt"
    : > "$work/middle.txt"
    : > "$work/newest.txt"
    touch -t 202001010101 "$work/oldest.txt"
    touch -t 202101010101 "$work/middle.txt"
    touch -t 202201010101 "$work/newest.txt"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set context_recent_files true
        config_set max_recent_files 2

        run_clean_shell "$shell" '
            cd "$HOME/recent-work"
            "$HOME/.local/bin/autocomplete" command --dry-run "inspect recents"
        '
        [ "$status" -eq 0 ]
        [[ "$output" == *$'newest.txt\nmiddle.txt'* ]]
        [[ "$output" != *"oldest.txt"* ]]
        [[ "$output" != *"$work/newest.txt"* ]]
        [[ "$output" != *"$work/middle.txt"* ]]
    done
}

@test "help context honors line and time bounds and omits timeout or failure output in both shells" {
    require_zsh
    local shell

    for shell in bash zsh; do
        prepare_shell "$shell"
        cat > "$HOME/.local/bin/acsh-help-ok" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' HELP_LINE_1 HELP_LINE_2 HELP_LINE_3 HELP_LINE_4
SCRIPT
        cat > "$HOME/.local/bin/acsh-help-slow" <<'SCRIPT'
#!/usr/bin/env bash
sleep 0.3
printf '%s\n' LATE_HELP_OUTPUT
SCRIPT
        cat > "$HOME/.local/bin/acsh-help-fail" <<'SCRIPT'
#!/usr/bin/env bash
printf '%s\n' FAILURE_HELP_OUTPUT >&2
exit 7
SCRIPT
        chmod 0755 "$HOME/.local/bin/acsh-help-ok" "$HOME/.local/bin/acsh-help-slow" "$HOME/.local/bin/acsh-help-fail"

        use_offline_provider
        config_set context_help true
        config_set max_help_lines 2
        config_set help_timeout_seconds 0.05

        run_clean_shell "$shell" '"$HOME/.local/bin/autocomplete" command --dry-run "acsh-help-ok"'
        [ "$status" -eq 0 ]
        [[ "$output" == *$'HELP_LINE_1\nHELP_LINE_2'* ]]
        [[ "$output" != *"HELP_LINE_3"* ]]
        [[ "$output" != *"HELP_LINE_4"* ]]

        run_clean_shell "$shell" '"$HOME/.local/bin/autocomplete" command --dry-run "acsh-help-slow"'
        [ "$status" -eq 0 ]
        [[ "$output" != *"LATE_HELP_OUTPUT"* ]]

        run_clean_shell "$shell" '"$HOME/.local/bin/autocomplete" command --dry-run "acsh-help-fail"'
        [ "$status" -eq 0 ]
        [[ "$output" != *"FAILURE_HELP_OUTPUT"* ]]
    done
}

@test "identical commands cache and cache_size evicts oldest entries in both shells" {
    require_zsh
    local shell i
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set cache_size 2
        export ACSH_TEST_CURL_LOG="$TEST_HOME/cache-basic-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "same request"
        [ "$status" -eq 0 ]
        run "$(runtime_path)" command "same request"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 1 ]
        [ "$(cache_file_count)" -eq 1 ]

        for i in 1 2 3; do
            run "$(runtime_path)" command "unique request number $i"
            [ "$status" -eq 0 ] || return 1
        done
        [ "$(cache_file_count)" -eq 2 ]
    done
}

@test "cwd, provider, endpoint, model, active key, temperature, and schema version each independently miss cache in both shells" {
    require_zsh
    local shell expected work
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"
    export OPENAI_API_KEY=sk-openai-cache-key

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set cache_size 20
        export ACSH_TEST_CURL_LOG="$TEST_HOME/cache-scalars-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"
        expected=0

        run "$(runtime_path)" command "scalar cache identity"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        work="$HOME/cwd-$shell"
        mkdir -p "$work"
        run bash -c 'cd "$1" && "$2" command "scalar cache identity"' _ "$work" "$(runtime_path)"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        config_set endpoint https://second.test.local/v1/chat/completions
        run "$(runtime_path)" command "scalar cache identity"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        config_set model second-model
        run "$(runtime_path)" command "scalar cache identity"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        config_set openai_compatible_api_key sk-compatible-cache-key
        run "$(runtime_path)" command "scalar cache identity"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        config_set temperature 0.75
        run "$(runtime_path)" command "scalar cache identity"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        config_set provider openai
        run "$(runtime_path)" command "scalar cache identity"
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]

        run_clean_shell "$shell" '
            source "$HOME/.local/bin/autocomplete" >/dev/null
            export ACSH_CACHE_SCHEMA_VERSION=2
            command_command command "scalar cache identity"
        '
        [ "$status" -eq 0 ]
        expected=$((expected + 1)); [ "$(request_count)" -eq "$expected" ]
        [ "$(cache_file_count)" -eq "$expected" ]
    done
}

@test "every context switch and bound independently changes cache identity in both shells" {
    require_zsh
    local shell expected i
    local -a keys=(
        context_terminal
        context_environment
        context_history
        context_recent_files
        context_help
        max_environment_names
        max_history_commands
        max_recent_files
        max_help_lines
        help_timeout_seconds
    )
    local -a values=(true true true true true 1 1 1 1 0.1)
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set cache_size 20
        export ACSH_TEST_CURL_LOG="$TEST_HOME/cache-policy-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "policy cache identity"
        [ "$status" -eq 0 ]
        expected=1

        for ((i = 0; i < ${#keys[@]}; i++)); do
            config_set "${keys[$i]}" "${values[$i]}"
            run "$(runtime_path)" command "policy cache identity"
            [ "$status" -eq 0 ] || {
                echo "$shell failed policy ${keys[$i]}" >&2
                return 1
            }
            expected=$((expected + 1))
            [ "$(request_count)" -eq "$expected" ]
        done
        [ "$(cache_file_count)" -eq "$expected" ]
    done
}

@test "canonical custom JSON key order hits cache while spaced and unspaced string values never collide in both shells" {
    require_zsh
    local shell
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set request_headers_json '{"X-B":"2","X-A":"1"}'
        config_set extra_body_json '{"metadata":{"z":2,"a":1},"max_tokens":64}'
        export ACSH_TEST_CURL_LOG="$TEST_HOME/cache-json-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "JSON cache identity"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 1 ]

        config_set request_headers_json '{ "X-A" : "1", "X-B" : "2" }'
        config_set extra_body_json '{ "max_tokens" : 64, "metadata" : { "a" : 1, "z" : 2 } }'
        run "$(runtime_path)" command "JSON cache identity"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 1 ]
        [ "$(cache_file_count)" -eq 1 ]

        config_set request_headers_json '{"X-Space":"a b"}'
        run "$(runtime_path)" command "JSON cache identity"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 2 ]

        config_set request_headers_json '{"X-Space":"ab"}'
        run "$(runtime_path)" command "JSON cache identity"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 3 ]
        [ "$(cache_file_count)" -eq 3 ]
    done
}

@test "corrupt cache entries are removed and regenerated by exactly one request in both shells" {
    require_zsh
    local shell cache_file
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        export ACSH_TEST_CURL_LOG="$TEST_HOME/cache-corrupt-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "repair corrupt cache"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 1 ]
        cache_file="$(find "$HOME/.autocomplete/cache" -maxdepth 1 -type f -name 'acsh-v1-*.txt' -print -quit)"
        [ -n "$cache_file" ]
        printf '\n' > "$cache_file"

        run "$(runtime_path)" command "repair corrupt cache"
        [ "$status" -eq 0 ]
        [[ "$output" == *"systemctl --failed"* ]]
        [ "$(request_count)" -eq 2 ]
        [ "$(cache_file_count)" -eq 1 ]
    done
}

@test "malformed and empty-element provider completions fail without usage log or cache in both shells" {
    require_zsh
    local shell fixture

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider

        for fixture in openai-invalid.json openai-empty-element.json; do
            rm -rf "$HOME/.autocomplete/cache"
            mkdir -p "$HOME/.autocomplete/cache"
            rm -f "$HOME/.autocomplete/autocomplete.log"
            export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/$fixture"
            export ACSH_TEST_CURL_LOG="$TEST_HOME/parser-$shell-$fixture.log"
            rm -f "$ACSH_TEST_CURL_LOG"

            run "$(runtime_path)" command "reject $fixture"
            [ "$status" -ne 0 ]
            [ "$(request_count)" -eq 1 ]
            [ "$(cache_file_count)" -eq 0 ]
            assert_no_usage_log
        done
    done
}

@test "completion validation accepts exact limits and rejects controls oversize and excess records in both shells" {
    require_zsh
    local shell fixture commands_json oversized at_limit i
    local -a invalid_commands
    printf -v at_limit '%*s' 4096 ''
    at_limit=${at_limit// /x}
    printf -v oversized '%*s' 4097 ''
    oversized=${oversized// /x}
    invalid_commands=(
        '["echo\tbad"]'
        '["echo\u000dbad"]'
        '["echo\u007fbad"]'
        '["echo\u0000bad"]'
        "$(jq -nc --arg command "$oversized" '[$command]')"
        '["one","two","three","four","five","six"]'
    )

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        export ACSH_TEST_CURL_LOG="$TEST_HOME/validator-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        fixture="$TEST_HOME/validator-$shell-boundary.json"
        commands_json=$(jq -nc --arg command "$at_limit" '[$command, "two", "three", "four", "five"]')
        write_openai_commands_fixture "$fixture" "$commands_json"
        export ACSH_TEST_RESPONSE_FILE="$fixture"
        run "$(runtime_path)" command "accept validator boundary"
        [ "$status" -eq 0 ]
        [ "$(request_count)" -eq 1 ]
        [ "$(cache_file_count)" -eq 1 ]

        rm -rf "$HOME/.autocomplete/cache"
        mkdir -p "$HOME/.autocomplete/cache"
        rm -f "$HOME/.autocomplete/autocomplete.log" "$ACSH_TEST_CURL_LOG"
        i=0
        for commands_json in "${invalid_commands[@]}"; do
            i=$((i + 1))
            fixture="$TEST_HOME/validator-$shell-$i.json"
            write_openai_commands_fixture "$fixture" "$commands_json"
            export ACSH_TEST_RESPONSE_FILE="$fixture"

            run "$(runtime_path)" command "reject validator case $i"
            [ "$status" -ne 0 ]
            [ "$(request_count)" -eq "$i" ]
            [ "$(cache_file_count)" -eq 0 ]
            assert_no_usage_log
        done
    done
}

@test "missing provider usage logs literal zero tokens and cost and usage reporting succeeds in both shells" {
    require_zsh
    local shell log_file created input_hash prompt_tokens completion_tokens cost
    jq 'del(.usage)' "$TEST_REPO_ROOT/tests/fixtures/openai-success.json" > "$TEST_HOME/openai-no-usage.json"
    export ACSH_TEST_RESPONSE_FILE="$TEST_HOME/openai-no-usage.json"

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        export ACSH_TEST_CURL_LOG="$TEST_HOME/missing-usage-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        run "$(runtime_path)" command "missing usage fields"
        [ "$status" -eq 0 ]
        log_file="$HOME/.autocomplete/autocomplete.log"
        [ -s "$log_file" ]
        IFS=, read -r created input_hash prompt_tokens completion_tokens cost < "$log_file"
        [ -n "$created" ]
        [ -n "$input_hash" ]
        [ "$prompt_tokens" = 0 ]
        [ "$completion_tokens" = 0 ]
        [ "$cost" = 0 ]

        run "$(runtime_path)" usage
        [ "$status" -eq 0 ]
        [[ "$output" == *"Usage count:"*"1"* ]]
        [[ "$output" == *"Total Cost:"*"0.0000"* ]]
    done
}

@test "provider request deadline is enforced once without caching in both shells" {
    require_zsh
    local shell start end
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"
    export ACSH_TEST_DELAY=2

    for shell in bash zsh; do
        prepare_shell "$shell"
        use_offline_provider
        config_set request_timeout_seconds 0.2
        export ACSH_TEST_CURL_LOG="$TEST_HOME/timeout-$shell.log"
        rm -f "$ACSH_TEST_CURL_LOG"

        start=$(date +%s%N)
        run "$(runtime_path)" command "timed out request"
        end=$(date +%s%N)
        [ "$status" -ne 0 ]
        [ "$(((end - start) / 1000000))" -lt 1500 ]
        [ "$(request_count)" -eq 1 ]
        [ "$(cache_file_count)" -eq 0 ]
        assert_no_usage_log
    done
}

@test "autocomplete clear removes the answer cache and usage log" {
    export ACSH_TEST_RESPONSE_FILE="$TEST_REPO_ROOT/tests/fixtures/openai-success.json"
    use_offline_provider
    run autocomplete command "seed the cache"
    [ "$status" -eq 0 ]
    [ "$(cache_file_count)" -eq 1 ]

    run bash -c 'printf "y\n" | autocomplete clear'
    [ "$status" -eq 0 ]
    [ "$(cache_file_count)" -eq 0 ]
    [ ! -e "$HOME/.autocomplete/autocomplete.log" ]
}
