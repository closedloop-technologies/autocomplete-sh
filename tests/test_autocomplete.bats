#!/usr/bin/env bats

setup() {
    export TEST_HOME
    TEST_HOME="$(mktemp -d)"
    export HOME="$TEST_HOME"
    export ACSH_CONFIG_FILE="$TEST_HOME/.autocomplete/config"
    export PATH="$TEST_HOME/bin:$BATS_TEST_DIRNAME/..:$PATH"
    mkdir -p "$TEST_HOME/bin"
    cp "$BATS_TEST_DIRNAME/../autocomplete.sh" "$TEST_HOME/bin/autocomplete"
    chmod +x "$TEST_HOME/bin/autocomplete"

    cat > "$TEST_HOME/bin/curl" <<'MOCK_CURL'
#!/usr/bin/env bash
case "$*" in
  *api.anthropic.com*)
    cat <<'JSON'
{"usage":{"input_tokens":11,"output_tokens":7},"content":[{"type":"tool_use","name":"bash_completions","input":{"commands":["git status --short","git log --oneline -5"]}}]}
JSON
    ;;
  *localhost:11434*)
    cat <<'JSON'
{"message":{"content":"{\"commands\":[\"pwd\",\"ls\"]}"}}
JSON
    ;;
  *)
    cat <<'JSON'
{"created_at":1710000000,"usage":{"input_tokens":10,"output_tokens":6},"output":[{"type":"message","content":[{"type":"output_text","text":"{\"commands\":[\"ls -lah\",\"ls -lt\"]}"}]}]}
JSON
    ;;
esac
printf '\n200'
MOCK_CURL
    chmod +x "$TEST_HOME/bin/curl"
    export OPENAI_API_KEY="test-openai-key"
    export ANTHROPIC_API_KEY="test-anthropic-key"
    export GROQ_API_KEY="test-groq-key"
}

teardown() {
    rm -rf "$TEST_HOME"
}

@test "autocomplete command is installed from local script" {
    run autocomplete --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Autocomplete.sh" ]]
    [[ "$output" =~ "gpt-5.4-mini" ]]
}

@test "install writes config and shell integration block" {
    run autocomplete install
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.autocomplete/config" ]
    grep -q "model: gpt-5.4-mini" "$TEST_HOME/.autocomplete/config"
    grep -q "# Autocomplete.sh begin" "$TEST_HOME/.bashrc"
}

@test "model command can select latest OpenAI Responses model" {
    autocomplete install >/dev/null
    run autocomplete model openai gpt-5.5
    [ "$status" -eq 0 ]
    [[ "$output" =~ "gpt-5.5" ]]
    grep -q "api_type: responses" "$TEST_HOME/.autocomplete/config"
    grep -q "model: gpt-5.5" "$TEST_HOME/.autocomplete/config"
}

@test "config set preserves multi-word values and appends missing keys" {
    autocomplete install >/dev/null
    run autocomplete config set custom_note "hello world from bats"
    [ "$status" -eq 0 ]
    grep -q "custom_note: hello world from bats" "$TEST_HOME/.autocomplete/config"
}

@test "OpenAI Responses parser returns commands without a live API" {
    autocomplete install >/dev/null
    run autocomplete command "ls # largest files"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ls -lah" ]]
    [[ "$output" =~ "ls -lt" ]]
}

@test "Anthropic tool-use parser returns commands" {
    autocomplete install >/dev/null
    autocomplete model anthropic claude-sonnet-4-6 >/dev/null
    run autocomplete command "git # inspect repo"
    [ "$status" -eq 0 ]
    [[ "$output" =~ "git status --short" ]]
}

@test "usage handles an empty or missing log without division by zero" {
    autocomplete install >/dev/null
    : > "$TEST_HOME/.autocomplete/autocomplete.log"
    run autocomplete usage
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Usage count" ]]
}

@test "remove only removes the managed shell block" {
    autocomplete install >/dev/null
    echo "# user autocomplete note should survive" >> "$TEST_HOME/.bashrc"
    run autocomplete remove -y
    [ "$status" -eq 0 ]
    grep -q "user autocomplete note should survive" "$TEST_HOME/.bashrc"
    ! grep -q "# Autocomplete.sh begin" "$TEST_HOME/.bashrc"
}
