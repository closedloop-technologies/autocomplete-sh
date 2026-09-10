#!/bin/bash
# Autocomplete.sh - LLM Powered Bash Completion
# MIT License - ClosedLoop Technologies, Inc.
# Sean Kruzel 2024-2025
#
# This script provides bash completion suggestions using an LLM.
# It includes enhanced error handling, refined sanitization, improved configuration parsing,
# streamlined provider-specific payload building, stronger caching eviction, and an updated interactive UX.
#
# Note: Do not enable “set -euo pipefail” here because it may interfere with bash completion.

###############################################################################
#                         Enhanced Error Handling                             #
###############################################################################


echo_error() {
    echo -e "\e[31mAutocomplete.sh - $1\e[0m" >&2
}

echo_green() {
    echo -e "\e[32m$1\e[0m"
}

###############################################################################
#                      Global Variables & Model Definitions                   #
###############################################################################

export ACSH_VERSION=0.6.0

# Cache schema version for the answer cache (acsh-v1-<sha256>.txt).
export ACSH_CACHE_SCHEMA_VERSION=1

# Absolute path to this script (Bash). Used by install/remove_command to
# manage the startup file without depending on PATH lookups.
if [[ -n "${BASH_SOURCE[0]:-}" ]]; then
    _acsh_self="${BASH_SOURCE[0]}"
    if [[ "$_acsh_self" != */* ]]; then
        # Sourced via a PATH lookup (e.g. `source autocomplete enable`).
        _acsh_self=$(type -P "$_acsh_self" 2>/dev/null || true)
    fi
    if [[ -n "$_acsh_self" ]]; then
        _acsh_self_abs=$(readlink -f "$_acsh_self" 2>/dev/null || true)
        if [[ -z "$_acsh_self_abs" ]]; then
            _acsh_self_abs=$(cd "$(dirname "$_acsh_self")" 2>/dev/null && pwd -P)/$(basename "$_acsh_self")
        fi
        if [[ -n "$_acsh_self_abs" ]]; then
            export ACSH_SCRIPT_PATH="$_acsh_self_abs"
        fi
        unset _acsh_self_abs
    fi
    unset _acsh_self
fi

# Explicit AI action key chords (Readline sequences under the \C-x command
# prefix, unbound by default in Bash). Set either variable to an empty string
# before sourcing this file to disable that binding.
export ACSH_AI_COMPLETE_KEY=${ACSH_AI_COMPLETE_KEY-'\C-x\C-a'}
export ACSH_AI_REWRITE_KEY=${ACSH_AI_REWRITE_KEY-'\C-x\C-b'}

# Completion ownership state persists when this file is sourced again in the
# same shell. The capture flag distinguishes an absent -D/-E specification
# from state that has not yet been captured.
: "${_ACSH_SAVED_DEFAULT_COMPLETION=}"
: "${_ACSH_SAVED_EMPTY_COMPLETION=}"
: "${_ACSH_COMPLETION_STATE_CAPTURED=0}"

unset _autocomplete_modellist
declare -A _autocomplete_modellist
# OpenAI models
_autocomplete_modellist['openai:	gpt-4o']='{ "completion_cost":0.0000100, "prompt_cost":0.00000250, "endpoint": "https://api.openai.com/v1/chat/completions", "model": "gpt-4o", "provider": "openai" }'
_autocomplete_modellist['openai:	gpt-4o-mini']='{ "completion_cost":0.0000060, "prompt_cost":0.00000015, "endpoint": "https://api.openai.com/v1/chat/completions", "model": "gpt-4o-mini", "provider": "openai" }'
_autocomplete_modellist['openai:	o1']='{ "completion_cost":0.0000600, "prompt_cost":0.00001500, "endpoint": "https://api.openai.com/v1/chat/completions", "model": "o1", "provider": "openai" }'
_autocomplete_modellist['openai:	o1-mini']='{ "completion_cost":0.0000440, "prompt_cost":0.00001100, "endpoint": "https://api.openai.com/v1/chat/completions", "model": "o1-mini", "provider": "openai" }'
_autocomplete_modellist['openai:	o3-mini']='{ "completion_cost":0.0000440, "prompt_cost":0.00001100, "endpoint": "https://api.openai.com/v1/chat/completions", "model": "o3-mini", "provider": "openai" }'
# Anthropic models
_autocomplete_modellist['anthropic:	claude-3-7-sonnet-20250219']='{ "completion_cost":0.0000150, "prompt_cost":0.0000030, "endpoint": "https://api.anthropic.com/v1/messages", "model": "claude-3-7-sonnet-20240219", "provider": "anthropic" }'
_autocomplete_modellist['anthropic:	claude-3-5-sonnet-20241022']='{ "completion_cost":0.0000150, "prompt_cost":0.0000030, "endpoint": "https://api.anthropic.com/v1/messages", "model": "claude-3-5-sonnet-20241022", "provider": "anthropic" }'
_autocomplete_modellist['anthropic:	claude-3-5-haiku-20241022']='{ "completion_cost":0.0000040, "prompt_cost":0.0000008, "endpoint": "https://api.anthropic.com/v1/messages", "model": "claude-3-5-haiku-20241022", "provider": "anthropic" }'
# Groq models
_autocomplete_modellist['groq:		llama3-8b-8192']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama3-8b-8192", "provider": "groq" }'
_autocomplete_modellist['groq:		llama3-70b-8192']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama3-70b-8192", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.3-70b-versatile']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.3-70b-versatile", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.1-8b-instant']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.1-8b-instant", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-guard-3-8b']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-guard-3-8b", "provider": "groq" }'
_autocomplete_modellist['groq:		mixtral-8x7b-32768']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "mixtral-8x7b-32768", "provider": "groq" }'
_autocomplete_modellist['groq:		gemma2-9b-it']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "gemma2-9b-it", "provider": "groq" }'
# Groq preview models
_autocomplete_modellist['groq:		mistral-saba-24b']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "mistral-saba-24b", "provider": "groq" }'
_autocomplete_modellist['groq:		qwen-2.5-coder-32b']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "qwen-2.5-coder-32b", "provider": "groq" }'
_autocomplete_modellist['groq:		deepseek-r1-distill-qwen-32b']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "deepseek-r1-distill-qwen-32b", "provider": "groq" }'
_autocomplete_modellist['groq:		deepseek-r1-distill-llama-70b-specdec']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "deepseek-r1-distill-llama-70b-specdec", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.3-70b-specdec']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.3-70b-specdec", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.2-1b-preview']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.2-1b-preview", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.2-3b-preview']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.2-3b-preview", "provider": "groq" }'
# Ollama model
_autocomplete_modellist['ollama:	codellama']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "http://localhost:11434/api/chat", "model": "codellama", "provider": "ollama" }'

###############################################################################
#                       System Information Functions                          #
###############################################################################

_get_terminal_info() {
    local terminal_info=" * User name: \$USER=$USER
 * Current directory: \$PWD=$PWD
 * Previous directory: \$OLDPWD=$OLDPWD
 * Home directory: \$HOME=$HOME
 * Operating system: \$OSTYPE=$OSTYPE
 * Shell: \$BASH=$BASH
 * Terminal type: \$TERM=$TERM
 * Hostname: \$HOSTNAME"
    echo "$terminal_info"
}

# Privacy-minimal terminal context for provider prompts (only when the user
# opts in via context_terminal). NEVER emits username, hostname, home, or
# previous-directory information.
_get_prompt_terminal_context() {
    echo "Current directory: $(pwd -P 2>/dev/null || echo "$PWD")"
    echo "Operating system: ${OSTYPE:-}"
    echo "Shell: bash ${BASH_VERSION:-}"
    echo "Terminal type: ${TERM:-}"
}

machine_signature() {
    local signature
    signature=$(echo "$(uname -a)|$$USER" | md5sum | cut -d ' ' -f 1)
    echo "$signature"
}

_system_info() {
    echo "# System Information"
    echo
    uname -a
    echo "SIGNATURE: $(machine_signature)"
    echo
    echo "BASH_VERSION: $BASH_VERSION"
    echo "BASH_COMPLETION_VERSINFO: ${BASH_COMPLETION_VERSINFO}"
    echo
    echo "## Terminal Information"
    _get_terminal_info
}


###############################################################################
#                      LLM Completion Functions                               #
###############################################################################

_get_system_message_prompt() {
    echo "You are a helpful bash_completion script. Generate relevant and concise auto-complete suggestions for the given user command in the context of the current directory, operating system, command history, and environment variables. The output must be a list of two to five possible completions or rewritten commands, each on a new line, without spanning multiple lines. Each must be a valid command or chain of commands. Do not include backticks or quotes."
}

_get_output_instructions() {
    echo "Provide a list of suggested completions or commands that could be run in the terminal. YOU MUST provide a list of two to five possible completions or rewritten commands. DO NOT wrap the commands in backticks or quotes. Each must be a valid command or chain of commands. Focus on the user's intent, recent commands, and the current environment. RETURN A JSON OBJECT WITH THE COMPLETIONS."
}

_get_command_history() {
    local HISTORY_LIMIT=${ACSH_MAX_HISTORY_COMMANDS:-10}
    history | tail -n "$HISTORY_LIMIT"
}

# Emit only exported variable names from NUL-delimited environment records.
# Values are discarded before sorting so embedded newlines can never become
# apparent variable-name records in the prompt.
_get_environment_context() {
    local record name
    local limit=${ACSH_MAX_ENVIRONMENT_NAMES:-50}
    local count=0

    while IFS= read -r -d '' name; do
        printf '%s\n' "$name"
        count=$((count + 1))
        if (( count >= limit )); then
            break
        fi
    done < <(
        while IFS= read -r -d '' record; do
            name=${record%%=*}
            [[ "$name" == ACSH_* ]] && continue
            printf '%s\0' "$name"
        done < <(env -0) | LC_ALL=C sort -z
    )
}

# Refined sanitization: only replace long hex sequences, UUIDs, and API-key–like tokens.
_get_clean_command_history() {
    local recent_history
    recent_history=$(_get_command_history)
    recent_history=$(printf '%s\n' "$recent_history" | sed -E 's/\b[[:xdigit:]]{32,40}\b/REDACTED_HASH/g')
    recent_history=$(printf '%s\n' "$recent_history" | sed -E 's/\b[0-9a-fA-F-]{36}\b/REDACTED_UUID/g')
    recent_history=$(printf '%s\n' "$recent_history" | sed -E 's/\b[A-Za-z0-9]{16,40}\b/REDACTED_APIKEY/g')
    # Redact values assigned to valid shell variable names containing a
    # sensitive marker, and redact Bearer credential values.
    recent_history=$(printf '%s\n' "$recent_history" | sed -E 's/\b([A-Za-z_][A-Za-z0-9_]*(KEY|TOKEN|SECRET|PASSWORD|PASS|AUTH)[A-Za-z0-9_]*)=("[^"]*"|[^[:space:]]*)/\1=REDACTED_VALUE/gi')
    recent_history=$(printf '%s\n' "$recent_history" | sed -E 's/(Authorization:[[:space:]]*Bearer[[:space:]]+)[^[:space:]]*/\1REDACTED/gi')
    printf '%s\n' "$recent_history"
}

_get_recent_files() {
    local FILE_LIMIT=${ACSH_MAX_RECENT_FILES:-10}
    # Current-directory basenames only: no ownership/permission/absolute-path
    # metadata, no traversing outside the cwd.
    find . -maxdepth 1 -type f -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -n "$FILE_LIMIT" | sed 's/^[^ ]* //'
}

# Help text only when help context is enabled. Resolves the first token with
# `type -P` (skipping aliases/functions/builtins/unresolved), runs only the
# resolved executable with `--help` under `timeout`, and caps the output.
# Timeout/failure => no output (section simply absent; no error, no retry).
_get_help_message() {
    [[ "${ACSH_CONTEXT_HELP:-false}" == "true" ]] || return 0
    local cmd resolved help_info
    cmd=$(echo "$1" | awk '{print $1}')
    [[ -n "$cmd" ]] || return 0
    [[ "$cmd" == -* ]] && return 0
    resolved=$(type -P "$cmd" 2>/dev/null) || return 0
    [[ -n "$resolved" && -x "$resolved" ]] || return 0
    help_info=$(timeout "${ACSH_HELP_TIMEOUT_SECONDS:-0.25}" "$resolved" --help < /dev/null 2>&1) || return 0
    [[ -n "$help_info" ]] || return 0
    echo "$help_info" | head -n "${ACSH_MAX_HELP_LINES:-40}"
}

_build_prompt() {
    # $1 = mode, $2 = user input. The prompt ALWAYS contains only: mode,
    # active shell, user input, and output instructions. Optional context
    # sections are appended ONLY when the matching context_* switch is exactly
    # true AND the bounded helper produced nonempty content.
    local mode="$1" user_input="$2"
    local prompt section env_names

    prompt="Mode: $mode
Shell: bash ${BASH_VERSION:-}
User command: \`$user_input\`

# Instructions
$(_get_output_instructions)"

    if [[ "${ACSH_CONTEXT_TERMINAL:-false}" == "true" ]]; then
        section=$(_get_prompt_terminal_context)
        if [[ -n "$section" ]]; then
            prompt="$prompt

## Terminal Context
$section"
        fi
    fi

    if [[ "${ACSH_CONTEXT_ENVIRONMENT:-false}" == "true" ]]; then
        env_names=$(_get_environment_context)
        if [[ -n "$env_names" ]]; then
            prompt="$prompt

## Environment Variables
\`\`\`
$env_names
\`\`\`"
        fi
    fi

    if [[ "${ACSH_CONTEXT_HISTORY:-false}" == "true" ]]; then
        section=$(_get_clean_command_history)
        if [[ -n "$section" ]]; then
            prompt="$prompt

## Command History
\`\`\`
$section
\`\`\`"
        fi
    fi

    if [[ "${ACSH_CONTEXT_RECENT_FILES:-false}" == "true" ]]; then
        section=$(_get_recent_files)
        if [[ -n "$section" ]]; then
            prompt="$prompt

## Recent Files
\`\`\`
$section
\`\`\`"
        fi
    fi

    if [[ "${ACSH_CONTEXT_HELP:-false}" == "true" ]]; then
        section=$(_get_help_message "$user_input")
        if [[ -n "$section" ]]; then
            prompt="$prompt

## Help Information
\`\`\`
$section
\`\`\`"
        fi
    fi

    echo "$prompt"
}

###############################################################################
#                      Payload Building Functions                             #
###############################################################################

build_common_payload() {
    jq -n --arg model "$model" \
          --arg temperature "$temperature" \
          --arg system_prompt "$system_prompt" \
          --arg prompt_content "$prompt_content" \
          '{
             model: $model,
             messages: [
               {role: "system", content: $system_prompt},
               {role: "user", content: $prompt_content}
             ],
             temperature: ($temperature | tonumber)
          }'
}

_build_payload() {
    local mode="$1" user_input="$2"
    local prompt system_message_prompt payload acsh_prompt provider
    local model temperature
    model="${ACSH_MODEL:-gpt-4o}"
    temperature="${ACSH_TEMPERATURE:-0.0}"

    prompt=$(_build_prompt "$mode" "$user_input")
    system_message_prompt=$(_get_system_message_prompt)

    acsh_prompt="# SYSTEM PROMPT
$system_message_prompt
# USER MESSAGE
$prompt"
    export ACSH_PROMPT="$acsh_prompt"

    prompt_content="$prompt"
    system_prompt="$system_message_prompt"

    local base_payload
    base_payload=$(build_common_payload)

    provider="$ACSH_PROVIDER"

    # Merge validated extra_body fields BEFORE the provider's structured-output
    # contract, so openai-compatible extra fields (max_tokens, ...) can coexist
    # but can never replace the identity/response schema (reserved keys were
    # rejected by _validate_extra_body_json before this point).
    if [[ -n "${ACSH_EXTRA_BODY_JSON:-}" && "${ACSH_EXTRA_BODY_JSON:-}" != "{}" ]]; then
        base_payload=$(echo "$base_payload" | jq -c --argjson extra "$ACSH_EXTRA_BODY_JSON" '. + $extra')
    fi

    case "$provider" in
        "anthropic")
            payload=$(echo "$base_payload" | jq '. + {
                system: .messages[0].content,
                messages: [{role:"user", content: .messages[1].content}],
                max_tokens: 1024,
                tool_choice: {type: "tool", name: "bash_completions"},
                tools: [{
                    name: "bash_completions",
                    description: "syntactically correct command-line suggestions",
                    input_schema: {
                        type: "object",
                        properties: {
                            commands: {type: "array", items: {type: "string", description: "A suggested command"}}
                        },
                        required: ["commands"]
                    }
                }]
            }')
            ;;
        "groq")
            payload=$(echo "$base_payload" | jq '. + {response_format: {type: "json_object"}}')
            ;;
        "ollama")
            payload=$(echo "$base_payload" | jq '. + {
                format: "json",
                stream: false,
                options: {temperature: (.temperature | tonumber)}
            }')
            ;;
        *)
            payload=$(echo "$base_payload" | jq '. + {
                response_format: {type: "json_object"},
                tool_choice: {
                    type: "function",
                    function: {
                        name: "bash_completions",
                        description: "syntactically correct command-line suggestions",
                        parameters: {
                            type: "object",
                            properties: {
                                commands: {type: "array", items: {type: "string", description: "A suggested command"}}
                            },
                            required: ["commands"]
                        }
                    }
                },
                tools: [{
                    type: "function",
                    function: {
                        name: "bash_completions",
                        description: "syntactically correct command-line suggestions",
                        parameters: {
                            type: "object",
                            properties: {
                                commands: {type: "array", items: {type: "string", description: "A suggested command"}}
                            },
                            required: ["commands"]
                        }
                    }
                }]
            }')
            ;;
    esac
    echo "$payload"
}

log_request() {
    local user_input response_body user_input_hash log_file prompt_tokens completion_tokens created api_cost
    local prompt_tokens_int completion_tokens_int prompt_cost completion_cost
    user_input="$1"
    response_body="$2"
    user_input_hash=$(echo -n "$user_input" | md5sum | cut -d ' ' -f 1)

    if [[ "$ACSH_PROVIDER" == "anthropic" ]]; then
        prompt_tokens=$(echo "$response_body" | jq -r '.usage.input_tokens' 2>/dev/null || echo 0)
        completion_tokens=$(echo "$response_body" | jq -r '.usage.output_tokens' 2>/dev/null || echo 0)
    else
        prompt_tokens=$(echo "$response_body" | jq -r '.usage.prompt_tokens' 2>/dev/null || echo 0)
        completion_tokens=$(echo "$response_body" | jq -r '.usage.completion_tokens' 2>/dev/null || echo 0)
    fi
    # Missing or non-numeric usage counts count as ZERO.
    if [[ "$prompt_tokens" =~ ^[0-9]+$ ]]; then
        prompt_tokens_int=$((prompt_tokens))
    else
        prompt_tokens_int=0
    fi
    if [[ "$completion_tokens" =~ ^[0-9]+$ ]]; then
        completion_tokens_int=$((completion_tokens))
    else
        completion_tokens_int=0
    fi

    created=$(date +%s)
    created=$(echo "$response_body" | jq -r --argjson now "$created" '.created // $now' 2>/dev/null || echo "$created")
    prompt_cost=${ACSH_API_PROMPT_COST:-0.000005}
    completion_cost=${ACSH_API_COMPLETION_COST:-0.000015}
    api_cost=$(echo "$prompt_tokens_int * $prompt_cost + $completion_tokens_int * $completion_cost" | bc)
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
    echo "$created,$user_input_hash,$prompt_tokens_int,$completion_tokens_int,$api_cost" >> "$log_file"
}

# Emit the normalized provider name, or fail for an unsupported provider.
_normalize_provider() {
    local raw="$1" provider
    provider=$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')
    case "$provider" in
        openai|anthropic|groq|ollama|openai-compatible)
            printf '%s\n' "$provider"
            ;;
        *)
            echo_error "Unknown provider: $raw"
            return 1
            ;;
    esac
}

_provider_requires_api_key() {
    case "$1" in
        openai|anthropic|groq) return 0 ;;
        *) return 1 ;;
    esac
}

_set_active_api_key() {
    case "$1" in
        openai) export ACSH_ACTIVE_API_KEY="${ACSH_OPENAI_API_KEY:-}" ;;
        anthropic) export ACSH_ACTIVE_API_KEY="${ACSH_ANTHROPIC_API_KEY:-}" ;;
        groq) export ACSH_ACTIVE_API_KEY="${ACSH_GROQ_API_KEY:-}" ;;
        ollama) export ACSH_ACTIVE_API_KEY="${ACSH_OLLAMA_API_KEY:-}" ;;
        openai-compatible) export ACSH_ACTIVE_API_KEY="${ACSH_OPENAI_COMPATIBLE_API_KEY:-}" ;;
        *)
            echo_error "Unknown provider: $1"
            return 1
            ;;
    esac
}

_normalize_json() {
    printf '%s' "$1" | jq -cS .
}

# Validate ACSH_REQUEST_HEADERS_JSON: a JSON object whose values are strings
# without CR/LF and whose keys match the HTTP field-name token grammar.
# Rejects case-insensitive Authorization / Content-Type (client-managed).
_validate_headers_json() {
    local json="$1" entry name value lower token_re
    printf '%s' "$json" | jq -e 'type == "object"' >/dev/null 2>&1 || {
        echo_error "ACSH_REQUEST_HEADERS_JSON must be a JSON object."
        return 1
    }
    token_re="^[A-Za-z0-9!#\$%&'*+.^_\`|~-]+\$"
    while IFS= read -r entry; do
        [[ -n "$entry" ]] || continue
        name=$(printf '%s' "$entry" | jq -r '.key' 2>/dev/null || true)
        value=$(printf '%s' "$entry" | jq -r '.value' 2>/dev/null || true)
        if ! printf '%s' "$entry" | jq -e '(.value | type) == "string"' >/dev/null 2>&1; then
            echo_error "request header value for '$name' must be a string."
            return 1
        fi
        if [[ "$value" == *$'\r'* || "$value" == *$'\n'* ]]; then
            echo_error "request header value for '$name' must not contain CR/LF."
            return 1
        fi
        if [[ ! "$name" =~ $token_re ]]; then
            echo_error "invalid HTTP header field name: '$name'"
            return 1
        fi
        lower=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
        if [[ "$lower" == "authorization" || "$lower" == "content-type" ]]; then
            echo_error "request header '$name' is reserved (managed by autocomplete)."
            return 1
        fi
    done < <(printf '%s' "$json" | jq -c 'to_entries[]' 2>/dev/null)
}

# Emit each validated custom header as NUL-delimited name/value records.
_headers_to_curl() {
    local json="$1"
    printf '%s' "$json" | jq -j 'to_entries[] | .key, "\u0000", .value, "\u0000"' 2>/dev/null
}

# Validate ACSH_EXTRA_BODY_JSON: a JSON object that must not override reserved
# payload keys (model/messages/tools/tool_choice/response_format/stream).
_validate_extra_body_json() {
    local json="$1" key
    printf '%s' "$json" | jq -e 'type == "object"' >/dev/null 2>&1 || {
        echo_error "ACSH_EXTRA_BODY_JSON must be a JSON object."
        return 1
    }
    while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        case "$key" in
            model|messages|tools|tool_choice|response_format|stream)
                echo_error "ACSH_EXTRA_BODY_JSON must not override reserved key: '$key'"
                return 1
                ;;
        esac
    done < <(printf '%s' "$json" | jq -r 'keys[]' 2>/dev/null)
}

_validate_config_value() {
    local key="$1" value="$2"
    case "$key" in
        provider)
            _normalize_provider "$value" >/dev/null
            ;;
        context_terminal|context_environment|context_history|context_recent_files|context_help)
            if [[ "$value" != "true" && "$value" != "false" ]]; then
                echo_error "$key must be 'true' or 'false'."
                return 1
            fi
            ;;
        temperature|api_prompt_cost|api_completion_cost)
            if [[ ! "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
                echo_error "$key must be a non-negative decimal."
                return 1
            fi
            ;;
        request_timeout_seconds|help_timeout_seconds)
            if [[ ! "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] \
                || ! awk -v number="$value" 'BEGIN { exit !(number > 0) }' </dev/null 2>/dev/null; then
                echo_error "$key must be a positive decimal."
                return 1
            fi
            ;;
        cache_size|max_*)
            if [[ ! "$value" =~ ^[0-9]+$ ]] || ! (( 10#$value > 0 )); then
                echo_error "$key must be a positive integer."
                return 1
            fi
            ;;
        request_headers_json)
            _validate_headers_json "$value"
            ;;
        extra_body_json)
            _validate_extra_body_json "$value"
            ;;
    esac
}

_validate_runtime_config() {
    local provider headers body key
    provider=$(_normalize_provider "${ACSH_PROVIDER:-openai}") || return 1
    export ACSH_PROVIDER="$provider"

    while IFS= read -r key; do
        case "$key" in
            temperature) _validate_config_value "$key" "${ACSH_TEMPERATURE:-0.0}" || return 1 ;;
            api_prompt_cost) _validate_config_value "$key" "${ACSH_API_PROMPT_COST:-0.000005}" || return 1 ;;
            api_completion_cost) _validate_config_value "$key" "${ACSH_API_COMPLETION_COST:-0.000015}" || return 1 ;;
            request_timeout_seconds) _validate_config_value "$key" "${ACSH_REQUEST_TIMEOUT_SECONDS:-5}" || return 1 ;;
            context_terminal) _validate_config_value "$key" "${ACSH_CONTEXT_TERMINAL:-false}" || return 1 ;;
            context_environment) _validate_config_value "$key" "${ACSH_CONTEXT_ENVIRONMENT:-false}" || return 1 ;;
            context_history) _validate_config_value "$key" "${ACSH_CONTEXT_HISTORY:-false}" || return 1 ;;
            context_recent_files) _validate_config_value "$key" "${ACSH_CONTEXT_RECENT_FILES:-false}" || return 1 ;;
            context_help) _validate_config_value "$key" "${ACSH_CONTEXT_HELP:-false}" || return 1 ;;
            max_environment_names) _validate_config_value "$key" "${ACSH_MAX_ENVIRONMENT_NAMES:-50}" || return 1 ;;
            max_history_commands) _validate_config_value "$key" "${ACSH_MAX_HISTORY_COMMANDS:-10}" || return 1 ;;
            max_recent_files) _validate_config_value "$key" "${ACSH_MAX_RECENT_FILES:-10}" || return 1 ;;
            max_help_lines) _validate_config_value "$key" "${ACSH_MAX_HELP_LINES:-40}" || return 1 ;;
            help_timeout_seconds) _validate_config_value "$key" "${ACSH_HELP_TIMEOUT_SECONDS:-0.25}" || return 1 ;;
            cache_size) _validate_config_value "$key" "${ACSH_CACHE_SIZE:-10}" || return 1 ;;
        esac
    done <<'EOF'
temperature
api_prompt_cost
api_completion_cost
request_timeout_seconds
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
cache_size
EOF

    _validate_config_value provider "$provider" || return 1
    headers=${ACSH_REQUEST_HEADERS_JSON:-'{}'}
    body=${ACSH_EXTRA_BODY_JSON:-'{}'}
    _validate_config_value request_headers_json "$headers" || return 1
    _validate_config_value extra_body_json "$body" || return 1
    headers=$(_normalize_json "$headers") || return 1
    body=$(_normalize_json "$body") || return 1
    if [[ "$provider" != "openai-compatible" && "$headers" != "{}" ]]; then
        echo_error "request_headers_json is only supported for provider 'openai-compatible'."
        return 1
    fi
    if [[ "$provider" != "openai-compatible" && "$body" != "{}" ]]; then
        echo_error "extra_body_json is only supported for provider 'openai-compatible'."
        return 1
    fi
    if _provider_requires_api_key "$provider" && [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]]; then
        echo_error "ACSH_ACTIVE_API_KEY not set. Please set it with: export ${provider^^}_API_KEY=<your-api-key>"
        return 1
    fi
    if [[ "${ACSH_ACTIVE_API_KEY:-}" == *$'\r'* || "${ACSH_ACTIVE_API_KEY:-}" == *$'\n'* ]]; then
        echo_error "ACSH_ACTIVE_API_KEY must not contain CR/LF."
        return 1
    fi
}

# ONE bounded provider attempt: builds the prompt/payload, performs EXACTLY
# ONE HTTP request, maps non-200 to a nonzero status, and writes the untouched
# response body to stdout. It does NOT parse, validate, cache, log, or retry
# (those live in _cached_completion / _run_ai_request).
_request_completion() {
    local mode="$1" user_input="$2"
    local endpoint timeout api_key payload response status_code body provider auth_header=""
    local hname hvalue
    local -a curl_args

    _validate_runtime_config || return 1
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
    timeout=${ACSH_REQUEST_TIMEOUT_SECONDS:-5}
    provider="$ACSH_PROVIDER"
    api_key="${ACSH_ACTIVE_API_KEY:-}"
    payload=$(_build_payload "$mode" "$user_input") || return 1

    curl_args=(-s --max-time "$timeout" -w $'\n%{http_code}')
    case "$provider" in
        anthropic)
            curl_args+=(
                -H "content-type: application/json"
                -H "anthropic-version: 2023-06-01"
                -H @-
            )
            auth_header="x-api-key: $api_key"
            ;;
        ollama)
            ;;
        *)
            curl_args+=(-H "Content-Type: application/json")
            if [[ -n "$api_key" ]]; then
                curl_args+=(-H @-)
                auth_header="Authorization: Bearer $api_key"
            fi
            ;;
    esac

    if [[ "$provider" == "openai-compatible" && -n "${ACSH_REQUEST_HEADERS_JSON:-}" && "${ACSH_REQUEST_HEADERS_JSON:-}" != "{}" ]]; then
        while IFS= read -r -d '' hname; do
            IFS= read -r -d '' hvalue || return 1
            curl_args+=(-H "$hname: $hvalue")
        done < <(_headers_to_curl "$ACSH_REQUEST_HEADERS_JSON")
    fi
    curl_args+=(--data "$payload" -- "$endpoint")

    if [[ -n "$auth_header" ]]; then
        response=$(printf '%s\n' "$auth_header" | command curl "${curl_args[@]}" 2>/dev/null) || return 1
    else
        response=$(command curl "${curl_args[@]}" 2>/dev/null) || return 1
    fi
    status_code=$(printf '%s' "$response" | tail -n1)
    body=$(printf '%s' "$response" | sed '$d')
    if [[ "$status_code" != "200" ]]; then
        printf '%s' "$body"
        return 1
    fi
    printf '%s' "$body"
}

###############################################################################
#                      AI Request Orchestration (explicit actions)            #
###############################################################################

# Resolve the interactive AI deadline in milliseconds from $ACSH_AI_DEADLINE
# (seconds, >0). Invalid/absent -> 1500. The provider's general HTTP timeout
# stays in $ACSH_REQUEST_TIMEOUT_SECONDS; this knob is the interactive wait
# ceiling only.
_acsh_deadline_ms() {
    local d="${ACSH_AI_DEADLINE:-1.5}"
    if [[ "$d" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v d="$d" 'BEGIN{exit !(d>0)}' /dev/null; then
        awk -v d="$d" 'BEGIN{printf "%d", d*1000}'
    else
        echo 1500
    fi
}

# Negative-cache check: skip a provider call within $ACSH_NEG_TTL seconds of a
# prior failure for the same (mode,line).
_acsh_neg_cached() {
    local mode="$1" line="$2" neg_dir neg_hash neg_file neg_ts now_ts
    neg_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    neg_hash=$(echo -n "$mode|$line" | md5sum | cut -d ' ' -f 1)
    neg_file="$neg_dir/acsh-neg-$mode-$neg_hash.fail"
    [[ -f "$neg_file" ]] || return 1
    neg_ts=$(cat "$neg_file" 2>/dev/null || echo 0)
    now_ts=$(date +%s)
    (( now_ts - neg_ts < ${ACSH_NEG_TTL:-3} ))
}

# Record a provider failure for negative caching.
_acsh_neg_mark() {
    local mode="$1" line="$2" neg_dir neg_hash
    neg_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    mkdir -p "$neg_dir" 2>/dev/null || true
    neg_hash=$(echo -n "$mode|$line" | md5sum | cut -d ' ' -f 1)
    date +%s > "$neg_dir/acsh-neg-$mode-$neg_hash.fail"
}

# Validate AI-completion candidates (insertions) against the current line.
#   $1 = full line, $2 = cursor, remaining args = candidate insertions.
# stdout: validated insertions, one per line. Minimal inline checks in T2;
# consolidated into _validate_candidates in T4 (never executes candidates).
_validate_ai_completion() {
    local line="$1" cursor="$2"; shift 2
    local prefix="${line:0:cursor}" prefix_token cand cand_line arg whitespace suffix
    # token being completed = everything after the last whitespace before cursor
    prefix="${line:0:cursor}"
    prefix_token="${prefix##* }"
    whitespace="${prefix%"${prefix_token}"}"
    suffix="${line:cursor}"
    local -a out=()
    for cand in "$@"; do
        # reject empty
        [[ -z "$cand" ]] && continue
        # reject control chars / multiline
        if [[ "$cand" == *$'\n'* || "$cand" == *$'\r'* ]]; then continue; fi
        if [[ "$cand" =~ $'[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]' ]]; then continue; fi
        # must start with the current (incomplete) token -> nonempty insertion
        [[ "$cand" == "$prefix_token"* ]] || continue
        # reject identical to the incomplete input (no insertion)
        [[ "$cand" == "$prefix_token" ]] && continue
        # reconstruct candidate line; candidate must not clobber the suffix
        cand_line="${whitespace}${cand}${suffix}"
        # compile-only syntax check; never executes
        bash -n -c "$cand_line" 2>/dev/null || continue
        out+=("$cand")
    done
    printf '%s\n' "${out[@]}"
}

# Validate AI-rewrite candidates (whole-line commands).
#   $1 = mode, remaining args = candidate commands.
# stdout: validated candidates, one per line.
_validate_ai_rewrite() {
    local cand cmd
    shift   # $1 = mode, not a candidate
    local -a out=()
    for cand in "$@"; do
        [[ -z "$cand" ]] && continue
        if [[ "$cand" == *$'\n'* || "$cand" == *$'\r'* ]]; then continue; fi
        if [[ "$cand" =~ $'[\x01-\x08\x0b\x0c\x0e-\x1f\x7f]' ]]; then continue; fi
        cmd="${cand#"${cand%%[![:space:]]*}"}"
        # complete single command required (no leading incomplete token)
        [[ -n "$cmd" ]] || continue
        # compound/pipeline handling
        if [[ "$cmd" == *'|'* || "$cmd" == *';'* || "$cmd" == *'&&'* || "$cmd" == *'||'* ]]; then
            [[ "${ACSH_ALLOW_COMPOUND:-false}" == "true" ]] || continue
        fi
        # destructive commands are marked for display, NOT removed here
        # compile-only syntax check; never executes
        bash -n -c "$cmd" 2>/dev/null || continue
        out+=("$cand")
    done
    printf '%s\n' "${out[@]}"
}

# Return 0/1 whether a candidate command is destructive (display metadata only).
_acsh_is_destructive() {
    local cmd="$1"
    if echo "$cmd" | grep -Eq '^(sudo[[:space:]]+)?(rm[[:space:]]+(-[a-zA-Z]+[[:space:]]+)*\-rf|>|mkfs|dd|shutdown|reboot)'; then
        return 0
    fi
    return 1
}

# Run one explicit AI request with a strict deadline, no sync retry, no execute.
#   $1 = mode (ai-completion|ai-rewrite)
#   $2 = line   $3 = cursor   $4 = cwd
# stdout: raw provider candidate lines on success; rc=0 if any candidate text
#         was produced, rc=1 on timeout/failure/stale/neg-cached/empty.
_run_ai_request() {
    local mode="$1" line="$2" cursor="$3" cwd="$4"
    local sig_before sig_now deadline tmp pid deadline_ms rc result candidates

    case "$mode" in
        ai-completion|ai-rewrite) ;;
        *) echo_error "unknown AI mode '$mode'"; return 1 ;;
    esac
    acsh_load_config || return 1
    _validate_runtime_config || return 1


    # skip a provider that failed within the negative-cache TTL
    if _acsh_neg_cached "$mode" "$line"; then
        return 1
    fi

    deadline_ms=$(_acsh_deadline_ms)
    sig_before="$line|$cursor|$PWD|$mode|${ACSH_PROVIDER:-}|${ACSH_MODEL:-}"
    deadline=$(( $(date +%s%N) / 1000000 + deadline_ms ))
    tmp=$(mktemp)

    # backgrounded provider subshell writes its raw result to $tmp; the parent
    # polls and kills on deadline. Only an async design can observe mid-flight
    # input changes, which makes the stale-guard meaningful.
    ( _request_completion "$mode" "$line" > "$tmp" 2>/dev/null ) &
    pid=$!
    while kill -0 "$pid" 2>/dev/null; do
        if (( $(date +%s%N)/1000000 > deadline )); then
            kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
            _acsh_neg_mark "$mode" "$line"
            rm -f "$tmp"
            return 1
        fi
        sleep 0.05   # poll tick, bounded by the deadline; not a retry or a block
    done
    wait "$pid" 2>/dev/null
    rc=$?

    # stale check: in a bind -x widget, the live line re-read detects input
    # changes while the request was in flight; a CLI subprocess has no live
    # line, so fall back to the fixed args.
    if [[ -n "${READLINE_LINE+x}" ]]; then
        sig_now="$READLINE_LINE|$READLINE_POINT|$PWD|$mode|${ACSH_PROVIDER:-}|${ACSH_MODEL:-}"
    else
        sig_now="$line|$cursor|$PWD|$mode|${ACSH_PROVIDER:-}|${ACSH_MODEL:-}"
    fi
    if [[ "$sig_now" != "$sig_before" ]]; then
        rm -f "$tmp"
        return 1
    fi

    result=$(cat "$tmp" 2>/dev/null || true)
    rm -f "$tmp"
    if [[ -z "$result" ]]; then
        _acsh_neg_mark "$mode" "$line"
        return 1
    fi
    # _request_completion emits the raw response body; parse and validate it
    # into candidate lines before returning.
    candidates=$(_parse_and_validate_completions "$ACSH_PROVIDER" "$result")
    if [[ -z "$candidates" ]]; then
        _acsh_neg_mark "$mode" "$line"
        return 1
    fi
    log_request "$line" "$result"
    echo "$candidates"
}

# Print the exact context that WOULD be sent, labeling local vs remote, with no
# request performed. Shared by `context` and the --dry-run forms of ai-complete
# / ai-rewrite (single internal printer, no duplication).
_print_context() {
    local mode="$1" line="$2" endpoint host
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
    echo "# AI context for mode: $mode"
    echo "shell: bash $BASH_VERSION"
    echo "mode: $mode"
    echo "line: $line"
    echo "cursor: ${#line}"
    echo "cwd: $PWD"
    echo "provider: ${ACSH_PROVIDER:-openai}"
    echo "model: ${ACSH_MODEL:-gpt-4o}"
    echo "current token: ${line##* }"
    host=$(echo "$endpoint" | awk -F/ '{print $3}')
    case "$host" in
        "localhost"|"127.0.0.1"|"::1"|"10."*|"192.168."*|"172."*|"127."*)
            echo "endpoint destination: LOCAL ($endpoint)" ;;
        *)
            echo "endpoint destination: REMOTE ($endpoint)" ;;
    esac
}

###############################################################################
#                        Completion Functions                                 #
###############################################################################

list_cache() {
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    find "$cache_dir" -maxdepth 1 -type f -name "acsh-v1-*.txt" -printf '%T+ %p\n' 2>/dev/null | sort
}

# 100% native-only default/empty-line completion. Never loads config, reads
# cache, builds context, or contacts a provider. If bash-completion's _comp_load
# exists AND no command-specific spec is registered, lazily load the real native
# spec; return 124 ONLY when a real spec was loaded (Bash retries with it).
_acsh_native_complete() {
    local command_name="${COMP_WORDS[0]:-}"
    if declare -F _comp_load >/dev/null 2>&1 && ! complete -p -- "$command_name" 2>/dev/null; then
        if _comp_load -- "$command_name" 2>/dev/null; then
            return 124
        fi
    fi
    return 1
}

###############################################################################
#                      Answer Cache (explicit AI commands)                    #
###############################################################################

# Serialize NUL-delimited key=value records identifying the cache answer, hash
# them, and return the sha256 digest used as the cache filename stem.
_completion_cache_key() {
    local mode="$1" line="$2" cursor="$3"
    local provider endpoint model headers body temperature key_digest cwd
    provider="$ACSH_PROVIDER"
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
    model=${ACSH_MODEL:-gpt-4o}
    headers=${ACSH_REQUEST_HEADERS_JSON:-'{}'}
    body=${ACSH_EXTRA_BODY_JSON:-'{}'}
    temperature=${ACSH_TEMPERATURE:-0.0}
    headers=$(_normalize_json "$headers") || return 1
    body=$(_normalize_json "$body") || return 1
    temperature=$(jq -nr --arg value "$temperature" '$value | tonumber | . + 0') || return 1
    # SHA-256 digest of the ACTIVE key (never the key itself).
    key_digest=$(printf '%s' "${ACSH_ACTIVE_API_KEY:-}" | sha256sum | cut -d ' ' -f 1)
    cwd=$(pwd -P 2>/dev/null || echo "$PWD")
    {
        printf 'schema_version=%s\0' "$ACSH_CACHE_SCHEMA_VERSION"
        printf 'shell=%s\0' "bash $BASH_VERSION"
        printf 'mode=%s\0' "$mode"
        printf 'line=%s\0' "$line"
        printf 'cursor=%s\0' "$cursor"
        printf 'cwd=%s\0' "$cwd"
        printf 'provider=%s\0' "$provider"
        printf 'endpoint=%s\0' "$endpoint"
        printf 'model=%s\0' "$model"
        printf 'headers=%s\0' "$headers"
        printf 'body=%s\0' "$body"
        printf 'temperature=%s\0' "$temperature"
        printf 'active_key_sha256=%s\0' "$key_digest"
        printf 'context_terminal=%s\0' "${ACSH_CONTEXT_TERMINAL:-false}"
        printf 'context_environment=%s\0' "${ACSH_CONTEXT_ENVIRONMENT:-false}"
        printf 'context_history=%s\0' "${ACSH_CONTEXT_HISTORY:-false}"
        printf 'context_recent_files=%s\0' "${ACSH_CONTEXT_RECENT_FILES:-false}"
        printf 'context_help=%s\0' "${ACSH_CONTEXT_HELP:-false}"
        printf 'max_environment_names=%s\0' "${ACSH_MAX_ENVIRONMENT_NAMES:-50}"
        printf 'max_history_commands=%s\0' "${ACSH_MAX_HISTORY_COMMANDS:-10}"
        printf 'max_recent_files=%s\0' "${ACSH_MAX_RECENT_FILES:-10}"
        printf 'max_help_lines=%s\0' "${ACSH_MAX_HELP_LINES:-40}"
        printf 'help_timeout_seconds=%s\0' "${ACSH_HELP_TIMEOUT_SECONDS:-0.25}"
    } | sha256sum | cut -d ' ' -f 1
}

# Accept 1..5 nonempty newline-delimited records from stdin; reject control
# characters (including NUL, tab, CR, and DEL) and records longer than 4096
# characters. A single final newline is a terminator, not an empty record.
# Validate the complete input before emitting any accepted records unchanged.
_validate_completion_lines() {
    jq -Rrs '
        (if endswith("\n") then .[0:-1] else . end | split("\n")) as $records
        | (
            ($records | length) >= 1
            and ($records | length) <= 5
            and all(
                $records[];
                (length >= 1)
                and (length <= 4096)
                and (
                    explode
                    | all(.[]; . >= 32 and (. < 127 or . > 159))
                )
            )
        ) as $valid
        | if $valid then $records[] else error("invalid completion records") end
    ' 2>/dev/null
}

# Parse a provider response body into validated completion records. Preserves
# the provider-specific JSON paths; requires a JSON array of 1..5 strings with
# no control characters and <=4096 chars; routes the result through
# _validate_completion_lines. Malformed JSON / missing paths / empty arrays /
# invalid elements => nonzero, no output.
_parse_and_validate_completions() {
    local provider="$1" body="$2" extracted
    case "$provider" in
        "anthropic")
            extracted=$(printf '%s' "$body" | jq -ce '.content[0].input.commands' 2>/dev/null) || return 1
            ;;
        "groq")
            extracted=$(printf '%s' "$body" | jq -ce '.choices[0].message.content | fromjson | .completions' 2>/dev/null) || return 1
            ;;
        "ollama")
            extracted=$(printf '%s' "$body" | jq -ce '.message.content | fromjson | .completions' 2>/dev/null) || return 1
            ;;
        "openai"|"openai-compatible")
            extracted=$(printf '%s' "$body" | jq -ce '.choices[0].message.tool_calls[0].function.arguments | fromjson | .commands' 2>/dev/null) || return 1
            ;;
        *)
            return 1
            ;;
    esac
    if ! printf '%s' "$extracted" | jq -e '
        type == "array"
        and length >= 1
        and length <= 5
        and all(
            .[];
            type == "string"
            and length >= 1
            and length <= 4096
            and (
                explode
                | all(.[]; . >= 32 and (. < 127 or . > 159))
            )
        )
    ' >/dev/null 2>&1; then
        return 1
    fi
    printf '%s' "$extracted" | jq -r '.[]' | _validate_completion_lines
}

# Read a cache file through _validate_completion_lines. Corrupt entries are
# removed and treated as a miss.
_cache_read() {
    local cache_file="$1" valid
    [[ -f "$cache_file" ]] || return 1
    if ! valid=$(_validate_completion_lines < "$cache_file" 2>/dev/null); then
        rm -f "$cache_file" 2>/dev/null || true
        return 1
    fi
    printf '%s\n' "$valid"
}

# Atomic cache write: mktemp in the cache dir, mode 0600, printf, atomic mv.
# Only _parse_and_validate_completions output may reach this function.
_cache_write() {
    local cache_file="$1" validated="$2" cache_dir tmp
    cache_dir=$(dirname "$cache_file")
    mkdir -p "$cache_dir" 2>/dev/null || return 1
    tmp=$(mktemp "$cache_dir/.acsh-tmp-XXXXXX") 2>/dev/null || return 1
    chmod 600 "$tmp" 2>/dev/null || true
    printf '%s\n' "$validated" > "$tmp" || { rm -f "$tmp" 2>/dev/null || true; return 1; }
    mv -f "$tmp" "$cache_file" 2>/dev/null || { rm -f "$tmp" 2>/dev/null || true; return 1; }
    return 0
}

# Evict oldest-first cache entries beyond max_size (LRU via mtime).
_evict_cache() {
    local cache_dir="$1" max_size="$2" count old
    max_size=${max_size:-10}
    count=$(find "$cache_dir" -maxdepth 1 -type f -name 'acsh-v1-*.txt' 2>/dev/null | wc -l)
    if (( count > max_size )); then
        old=$((count - max_size))
        find "$cache_dir" -maxdepth 1 -type f -name 'acsh-v1-*.txt' -printf '%T@ %p\n' 2>/dev/null \
            | sort -n | head -n "$old" | cut -d ' ' -f 2- | xargs -r rm -f
    fi
}

# Cached explicit AI completion for "$mode" "$line" at "$cursor". Loads config,
# computes the answer-isolating key, returns a valid hit (LRU touch), otherwise
# performs ONE request, parses+validates, logs the raw body, writes the
# validated result atomically, and evicts oldest-first. Provider/config/timeout
# or validation failures => nonzero with NO log and NO cache entry.
_cached_completion() {
    local mode="$1" line="$2" cursor="$3"
    local cache_dir max_size key cache_file hit body rc validated
    acsh_load_config || return 1
    _validate_runtime_config || return 1
    cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    max_size=${ACSH_CACHE_SIZE:-10}

    key=$(_completion_cache_key "$mode" "$line" "$cursor") || return 1
    [[ -n "$key" ]] || return 1
    cache_file="$cache_dir/acsh-v1-$key.txt"

    hit=$(_cache_read "$cache_file")
    local read_rc=$?
    if [[ $read_rc -eq 0 && -n "$hit" ]]; then
        touch "$cache_file" 2>/dev/null || true   # LRU touch on a valid hit
        export ACSH_INPUT="$line"
        export ACSH_RESPONSE="$hit"
        echo "$hit"
        return 0
    fi

    body=$(_request_completion "$mode" "$line")
    rc=$?
    if [[ $rc -ne 0 ]]; then
        return 1
    fi
    validated=$(_parse_and_validate_completions "$ACSH_PROVIDER" "$body")
    if [[ $? -ne 0 || -z "$validated" ]]; then
        return 1
    fi
    log_request "$line" "$body"
    _cache_write "$cache_file" "$validated" || true
    _evict_cache "$cache_dir" "$max_size"
    export ACSH_INPUT="$line"
    export ACSH_RESPONSE="$validated"
    echo "$validated"
    return 0
}

###############################################################################
#                     CLI Commands & Configuration Management                 #
###############################################################################

show_help() {
    echo_green "Autocomplete.sh - LLM Powered Bash Completion"
    echo "Usage: autocomplete [options] command"
    echo "       autocomplete [options] install|remove|config|model|enable|disable|clear|usage|system|command|ai-complete|ai-rewrite|context|--help"
    echo
    echo "Autocomplete.sh enhances bash completion. Tab completion is 100%"
    echo "shell-native and provider-free: it uses the shell's own completion"
    echo "machinery (bash-completion specs, lazy loading, file fallback) and"
    echo "never contacts a language model on Tab. AI assistance is an explicit,"
    echo "opt-in action:"
    echo
    echo "Commands:"
    echo "  command <line>...            One-shot AI command-line completion for"
    echo "                               <line> (explicit single provider request, cached)."
    echo "  command --dry-run <line>...  Print the exact prompt that WOULD be sent"
    echo "                               (no request, no cache I/O)"
    echo "  ai-complete [--dry-run] <line>   AI completion (prefix-preserving), numbered preview, no execution"
    echo "  ai-rewrite  [--dry-run] <line>   AI rewrite (whole-line), numbered preview, no execution"
    echo "  context --mode <ai-completion|ai-rewrite> [--dry-run]"
    echo "                                   Show the exact context that WOULD be sent (no request)"
    echo "  model               Change language model"
    echo "  usage               Display usage stats"
    echo "  system              Display system information"
    echo "  config              Show or set configuration values"
    echo "    config set <key> <value>  Set a config value"
    echo "    config reset             Reset config to defaults"
    echo "  install             Install autocomplete to .bashrc"
    echo "  remove              Remove installation from .bashrc"
    echo "  enable              Enable autocomplete (native-only shell completion)"
    echo "  disable             Disable autocomplete"
    echo "  clear               Clear cache and log files"
    echo "  --help              Show this help message"
    echo
    echo "AI key bindings (defaults, under the \\C-x command prefix):"
    echo "  ${ACSH_AI_COMPLETE_KEY:-\C-x\C-a}  AI completion of the live line"
    echo "  ${ACSH_AI_REWRITE_KEY:-\C-x\C-b}  AI rewrite of the live line"
    echo "  Set ACSH_AI_COMPLETE_KEY or ACSH_AI_REWRITE_KEY to an empty string before sourcing to disable."
    echo
    echo "Submit issues at: https://github.com/closedloop-technologies/autocomplete-sh/issues"
}

is_subshell() {
    if [[ "$$" != "$BASHPID" ]]; then
        return 0
    else
        return 1
    fi
}

show_config() {
    local config_file="$HOME/.autocomplete/config" term_width small_table
    echo_green "Autocomplete.sh - Configuration and Settings - Version $ACSH_VERSION"
    if is_subshell; then
        echo "  STATUS: Unknown. Run 'autocomplete config' in an interactive shell to check status."
        return
    elif check_if_enabled; then
        echo -e "  STATUS: \033[32;5mEnabled\033[0m"
    else
        echo -e "  STATUS: \033[31;5mDisabled\033[0m - Run 'source autocomplete enable' to activate this shell."
    fi
    if [ ! -f "$config_file" ]; then
        echo_error "Configuration file not found: $config_file. Run autocomplete install."
        return
    fi
    acsh_load_config
    term_width=$(tput cols)
    if [[ $term_width -gt 70 ]]; then
        term_width=70; small_table=0
    fi
    if [[ $term_width -lt 40 ]]; then
        term_width=70; small_table=1
    fi
    for config_var in $(compgen -v | grep ACSH_); do
        if [[ $config_var == "ACSH_INPUT" || $config_var == "ACSH_PROMPT" || $config_var == "ACSH_RESPONSE" ]]; then
            continue
        fi
        config_value="${!config_var}"
        if [[ ${config_var: -8} == "_API_KEY" ]]; then
            continue
        fi
        echo -en "  $config_var:\e[90m"
        if [[ $small_table -eq 1 ]]; then
            echo -e "\n  $config_value\e[0m"
        else
            printf '%s%*s' "" $((term_width - ${#config_var} - ${#config_value} - 3)) ''
            echo -e "$config_value\e[0m"
        fi
    done
    echo -e "  ===================================================================="
    for config_var in $(compgen -v | grep ACSH_); do
        if [[ $config_var == "ACSH_INPUT" || $config_var == "ACSH_PROMPT" || $config_var == "ACSH_RESPONSE" ]]; then
            continue
        fi
        if [[ ${config_var: -8} != "_API_KEY" ]]; then
            continue
        fi
        echo -en "  $config_var:\e[90m"
        if [[ -z ${!config_var} ]]; then
            config_value="UNSET"
            echo -en "\e[31m"
        else
            rest=${!config_var:4}
            config_value="${!config_var:0:4}...${rest: -4}"
            echo -en "\e[32m"
        fi
        if [[ $small_table -eq 1 ]]; then
            echo -e "\n  $config_value\e[0m"
        else
            printf '%s%*s' "" $((term_width - ${#config_var} - ${#config_value} - 3)) ''
            echo -e "$config_value\e[0m"
        fi
    done
}

set_config() {
    local key="$1" value="$2" config_file="$HOME/.autocomplete/config"
    local file_key tmp matched=0 line line_key
    key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    key=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')
    if [[ -z "$key" ]]; then
        echo_error "SyntaxError: expected 'autocomplete config set <key> <value>'"
        return 1
    fi
    if [[ ! -f "$config_file" ]]; then
        echo_error "Configuration file not found: $config_file. Run autocomplete install."
        return 1
    fi
    file_key=$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')

    # Reject and normalize values before creating any temporary state.
    _validate_config_value "$file_key" "$value" || return 1
    case "$file_key" in
        provider)
            value=$(_normalize_provider "$value") || return 1
            ;;
        request_headers_json|extra_body_json)
            value=$(_normalize_json "$value") || {
                echo_error "$file_key must be valid JSON."
                return 1
            }
            ;;
    esac

    tmp=$(mktemp "$config_file.tmp.XXXXXX") 2>/dev/null || {
        echo_error "Failed to create a temporary file for $config_file."
        return 1
    }
    if ! chmod 600 "$tmp" 2>/dev/null; then
        rm -f "$tmp" 2>/dev/null || true
        echo_error "Failed to secure temporary file for $config_file."
        return 1
    fi
    if ! while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*([A-Za-z0-9_]+)[[:space:]]*: ]]; then
            line_key=${BASH_REMATCH[1]}
            line_key=$(printf '%s' "$line_key" | tr '[:upper:]' '[:lower:]')
            if [[ "$line_key" == "$file_key" ]]; then
                printf '%s: %s\n' "$file_key" "$value"
                matched=1
                continue
            fi
        fi
        printf '%s\n' "$line"
    done < "$config_file" > "$tmp"; then
        rm -f "$tmp" 2>/dev/null || true
        echo_error "Failed to rewrite $config_file."
        return 1
    fi
    if [[ $matched -eq 0 ]] && ! printf '%s: %s\n' "$file_key" "$value" >> "$tmp"; then
        rm -f "$tmp" 2>/dev/null || true
        echo_error "Failed to append configuration to $config_file."
        return 1
    fi
    if ! mv -f "$tmp" "$config_file"; then
        rm -f "$tmp" 2>/dev/null || true
        echo_error "Failed to update $config_file."
        return 1
    fi
    acsh_load_config || return 1
}

config_command() {
    local command config_file="$HOME/.autocomplete/config"
    command="${*:2}"
    if [ -z "$command" ]; then
        show_config
        return
    fi
    if [ "$2" == "set" ]; then
        local key="$3" value="$4"
        echo "Setting configuration key '$key' to '$value'"
        if ! set_config "$key" "$value"; then
            return 1
        fi
        echo_green "Configuration updated. Run 'autocomplete config' to view changes."
        return 0
    fi
    if [[ "$command" == "reset" ]]; then
        echo "Resetting configuration to default values."
        rm "$config_file" || true
        build_config
        return
    fi
    echo_error "SyntaxError: expected 'autocomplete config set <key> <value>' or 'autocomplete config reset'"
}

build_config() {
    local config_file="$HOME/.autocomplete/config" default_config config_dir tmp
    if [ ! -f "$config_file" ]; then
        echo "Creating default configuration file at ~/.autocomplete/config"
        default_config="# ~/.autocomplete/config

# OpenAI API Key
openai_api_key:

# Anthropic API Key
anthropic_api_key:

# Groq API Key
groq_api_key:

# Custom API Key for Ollama
custom_api_key:

# OpenAI-compatible API Key (optional; the OPENAI_COMPATIBLE_API_KEY env var is also used)
openai_compatible_api_key:

# Provider configuration
provider: openai
model: gpt-4o
temperature: 0.0
endpoint: https://api.openai.com/v1/chat/completions
api_prompt_cost: 0.000005
api_completion_cost: 0.000015

# Request configuration
request_timeout_seconds: 5
request_headers_json: {}
extra_body_json: {}

# Optional prompt context sections (all off by default)
context_terminal: false
context_environment: false
context_history: false
context_recent_files: false
context_help: false
max_environment_names: 50
max_history_commands: 10
max_recent_files: 10
max_help_lines: 40
help_timeout_seconds: 0.25

# Cache settings
cache_dir: $HOME/.autocomplete/cache
cache_size: 10

# Logging settings
log_file: $HOME/.autocomplete/autocomplete.log"
        # umask 077 + atomic rename => mode 0600, never a world-readable stage.
        config_dir=$(dirname "$config_file")
        mkdir -p "$config_dir" 2>/dev/null || true
        tmp=$(mktemp "$config_dir/config.XXXXXX") 2>/dev/null || return 1
        (
            umask 077
            echo "$default_config" > "$tmp"
        )
        chmod 600 "$tmp" 2>/dev/null || true
        if ! mv -f "$tmp" "$config_file"; then
            rm -f "$tmp" 2>/dev/null || true
            return 1
        fi
    fi
}

acsh_load_config() {
    local config_file="$HOME/.autocomplete/config" key value provider
    if [[ ! -f "$config_file" ]]; then
        echo_error "Configuration file not found: $config_file"
        return 1
    fi

    while IFS=':' read -r key value; do
        if [[ "$key" =~ ^# ]] || [[ -z "$key" ]]; then
            continue
        fi
        key=$(printf '%s' "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(printf '%s' "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        key=$(printf '%s' "$key" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')
        if [[ -n "$value" ]]; then
            export "ACSH_$key"="$value"
        fi
    done < "$config_file" || {
        echo_error "Failed to read configuration file: $config_file"
        return 1
    }

    if [[ -z "${ACSH_OPENAI_API_KEY:-}" && -n "${OPENAI_API_KEY:-}" ]]; then
        export ACSH_OPENAI_API_KEY="$OPENAI_API_KEY"
    fi
    if [[ -z "${ACSH_ANTHROPIC_API_KEY:-}" && -n "${ANTHROPIC_API_KEY:-}" ]]; then
        export ACSH_ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
    fi
    if [[ -z "${ACSH_GROQ_API_KEY:-}" && -n "${GROQ_API_KEY:-}" ]]; then
        export ACSH_GROQ_API_KEY="$GROQ_API_KEY"
    fi
    if [[ -z "${ACSH_OLLAMA_API_KEY:-}" && -n "${LLM_API_KEY:-}" ]]; then
        export ACSH_OLLAMA_API_KEY="$LLM_API_KEY"
    fi
    if [[ -z "${ACSH_OLLAMA_API_KEY:-}" && -n "${ACSH_CUSTOM_API_KEY:-}" ]]; then
        export ACSH_OLLAMA_API_KEY="$ACSH_CUSTOM_API_KEY"
    fi
    if [[ -z "${ACSH_OPENAI_COMPATIBLE_API_KEY:-}" && -n "${OPENAI_COMPATIBLE_API_KEY:-}" ]]; then
        export ACSH_OPENAI_COMPATIBLE_API_KEY="$OPENAI_COMPATIBLE_API_KEY"
    fi

    provider=$(_normalize_provider "${ACSH_PROVIDER:-openai}") || return 1
    export ACSH_PROVIDER="$provider"
    _set_active_api_key "$provider" || return 1
}

# Print $1 with ONLY the project's exact legacy lines and any existing managed
# block removed. Every unrelated line (including lines that merely mention
# autocomplete) is preserved byte-for-byte.
_filter_autocomplete_lines() {
    local file="$1" line read_status has_newline in_block=0 index
    local -a buffered_lines=() buffered_newlines=()
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    while true; do
        IFS= read -r line
        read_status=$?
        if [[ $read_status -ne 0 && -z "$line" ]]; then
            break
        fi
        if [[ $read_status -eq 0 ]]; then
            has_newline=1
        else
            has_newline=0
        fi

        if [[ $in_block -eq 1 ]]; then
            buffered_lines+=("$line")
            buffered_newlines+=("$has_newline")
            if [[ "$line" == "# <<< autocomplete.sh <<<" ]]; then
                in_block=0
                buffered_lines=()
                buffered_newlines=()
            fi
        elif [[ "$line" == "# >>> autocomplete.sh >>>" ]]; then
            in_block=1
            buffered_lines=("$line")
            buffered_newlines=("$has_newline")
        else
            case "$line" in
                "# Autocomplete.sh"|"# Autocomplete.zsh"|"source autocomplete enable"|"# Autocomplete.sh CLI"|"# Autocomplete.zsh CLI"|"complete -F _autocompletesh_cli autocomplete"|"compdef _autocompletesh_cli autocomplete")
                    if [[ $read_status -ne 0 ]]; then
                        break
                    fi
                    continue
                    ;;
            esac
            printf '%s' "$line"
            if [[ $has_newline -eq 1 ]]; then
                printf '\n'
            fi
        fi

        if [[ $read_status -ne 0 ]]; then
            break
        fi
    done < "$file"

    if [[ $in_block -eq 1 ]]; then
        for index in "${!buffered_lines[@]}"; do
            printf '%s' "${buffered_lines[$index]}"
            if [[ ${buffered_newlines[$index]} -eq 1 ]]; then
                printf '\n'
            fi
        done
    fi
}

install_command() {
    local bashrc_file="$HOME/.bashrc"
    if [[ -z "${ACSH_SCRIPT_PATH:-}" ]]; then
        echo_error "Could not determine the autocomplete.sh script path (ACSH_SCRIPT_PATH)."
        return 1
    fi
    # Resolve a symlinked rc file through the link (keeps atomic-rename semantics).
    if command -v readlink >/dev/null 2>&1; then
        bashrc_file=$(readlink -f "$bashrc_file" 2>/dev/null || echo "$bashrc_file")
    fi
    if [[ ! -d "$HOME/.autocomplete" ]]; then
        echo "Creating ~/.autocomplete directory"
        mkdir -p "$HOME/.autocomplete"
    fi
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir"
    fi
    build_config
    acsh_load_config

    # Back up an existing startup file once (never overwrite a prior backup).
    if [[ -f "$bashrc_file" && ! -f "$bashrc_file.autocomplete.bak" ]]; then
        cp -p "$bashrc_file" "$bashrc_file.autocomplete.bak" 2>/dev/null || true
    fi

    # Exactly ONE managed block containing only the source line; the CLI
    # completion registration lives inside enable_command, not in the block.
    local quoted_path source_line tmp rc_dir
    printf -v quoted_path '%q' "$ACSH_SCRIPT_PATH"
    source_line="source $quoted_path enable"
    rc_dir=$(dirname "$bashrc_file")
    mkdir -p "$rc_dir" 2>/dev/null || true
    tmp=$(mktemp "$rc_dir/.bashrc.acsh.XXXXXX") 2>/dev/null || {
        echo_error "Failed to create a temporary file in $rc_dir."
        return 1
    }
    {
        if [[ -f "$bashrc_file" ]]; then
            _filter_autocomplete_lines "$bashrc_file"
        fi
        echo ""
        echo "# >>> autocomplete.sh >>>"
        echo "$source_line"
        echo "# <<< autocomplete.sh <<<"
    } > "$tmp"
    if [[ -f "$bashrc_file" ]]; then
        chmod --reference="$bashrc_file" "$tmp" 2>/dev/null || true
    fi
    if ! mv -f "$tmp" "$bashrc_file"; then
        rm -f "$tmp" 2>/dev/null || true
        echo_error "Failed to update $bashrc_file."
        return 1
    fi
    echo "Added Autocomplete.sh managed block to $bashrc_file"
    echo
    echo_green "Autocomplete.sh - Version $ACSH_VERSION installation complete."
    echo -e "Run: source $bashrc_file to enable autocomplete."
    echo -e "Then run: autocomplete model to select a language model."
}

remove_command() {
    local config_file="$HOME/.autocomplete/config" cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"} log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"} bashrc_file="$HOME/.bashrc"
    echo_green "Removing Autocomplete.sh installation..."
    disable_command
    if command -v readlink >/dev/null 2>&1; then
        bashrc_file=$(readlink -f "$bashrc_file" 2>/dev/null || echo "$bashrc_file")
    fi
    if [[ -f "$bashrc_file" ]]; then
        local tmp rc_dir changed=0
        rc_dir=$(dirname "$bashrc_file")
        tmp=$(mktemp "$rc_dir/.bashrc.acsh.XXXXXX") 2>/dev/null || tmp=""
        if [[ -n "$tmp" ]]; then
            _filter_autocomplete_lines "$bashrc_file" > "$tmp"
            if ! cmp -s "$bashrc_file" "$tmp"; then
                changed=1
            fi
            if [[ $changed -eq 1 ]]; then
                chmod --reference="$bashrc_file" "$tmp" 2>/dev/null || true
                if mv -f "$tmp" "$bashrc_file" 2>/dev/null; then
                    echo "Removed autocomplete.sh setup from $bashrc_file"
                else
                    rm -f "$tmp" 2>/dev/null || true
                fi
            else
                rm -f "$tmp" 2>/dev/null || true
            fi
        fi
    fi
    [ -f "$config_file" ] && { rm "$config_file"; echo "Removed: $config_file"; }
    [ -d "$cache_dir" ] && { rm -rf "$cache_dir"; echo "Removed: $cache_dir"; }
    [ -f "$log_file" ] && { rm "$log_file"; echo "Removed: $log_file"; }
    if [ -d "$HOME/.autocomplete" ]; then
        if [ -z "$(ls -A "$HOME/.autocomplete")" ]; then
            rmdir "$HOME/.autocomplete"
            echo "Removed: $HOME/.autocomplete"
        else
            echo "Skipped removing $HOME/.autocomplete (not empty)"
        fi
    fi
    # Remove ONLY the script path we own, after confirmation (or -y).
    local remove_script=0 arg
    for arg in "$@"; do
        if [[ "$arg" == "-y" ]]; then
            remove_script=1
        fi
    done
    if [[ $remove_script -eq 0 && -n "${ACSH_SCRIPT_PATH:-}" && -f "$ACSH_SCRIPT_PATH" ]]; then
        read -r -p "Remove the autocomplete script ($ACSH_SCRIPT_PATH)? (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            remove_script=1
        fi
    fi
    if [[ $remove_script -eq 1 && -n "${ACSH_SCRIPT_PATH:-}" && -f "$ACSH_SCRIPT_PATH" ]]; then
        echo "Autocomplete script is at: $ACSH_SCRIPT_PATH"
        rm -f "$ACSH_SCRIPT_PATH"
        echo "Removed: $ACSH_SCRIPT_PATH"
    fi
    echo "Uninstallation complete."
}

_acsh_completion_slot_is_ours() {
    local slot="${1:-}" spec option handler=""

    case "$slot" in
        -D|-E) ;;
        *) return 2 ;;
    esac

    spec=$(complete -p "$slot" 2>/dev/null) || return 1
    # `complete -p` emits shell-quoted, reusable input. Decode it so option
    # arguments containing spaces or strings such as "-F" cannot be mistaken
    # for the actual function option.
    eval "set -- ${spec#complete }" || return 1
    while (( $# > 0 )); do
        option=$1
        shift
        case "$option" in
            -F)
                (( $# > 0 )) || return 1
                handler=$1
                shift
                ;;
            -A|-C|-G|-P|-S|-W|-X)
                (( $# > 0 )) || return 1
                shift
                ;;
        esac
    done

    [[ "$handler" == "_acsh_native_complete" ]]
}

check_if_enabled() {
    _acsh_completion_slot_is_ours -D &&
        _acsh_completion_slot_is_ours -E
}

_autocompletesh_cli() {
    if [[ -n "${COMP_WORDS[*]}" ]]; then
        command="${COMP_WORDS[0]}"
        if [[ -n "$COMP_CWORD" && "$COMP_CWORD" -lt "${#COMP_WORDS[@]}" ]]; then
            current="${COMP_WORDS[COMP_CWORD]}"
        fi
    fi
    if [[ $current == "config" ]]; then
        readarray -t COMPREPLY <<< "set
reset"
        return
    elif [[ $current == "command" ]]; then
        readarray -t COMPREPLY <<< "command --dry-run"
        return
    fi
    if [[ -z "$current" ]]; then
        readarray -t COMPREPLY <<< "install
remove
config
enable
disable
clear
usage
system
command
ai-complete
ai-rewrite
context
model
--help"
    fi
}

enable_command() {
    local had_owned_slot=0

    if _acsh_completion_slot_is_ours -D ||
        _acsh_completion_slot_is_ours -E; then
        had_owned_slot=1
        echo_green "Reloading Autocomplete.sh..."
    fi

    # Finish any previous ownership cycle before taking a new snapshot. This
    # also clears stale saved state when the user replaced both slots.
    if [[ "$_ACSH_COMPLETION_STATE_CAPTURED" == "1" ||
        "$had_owned_slot" == "1" ]]; then
        disable_command
    fi

    acsh_load_config
    if [[ "$_ACSH_COMPLETION_STATE_CAPTURED" != "1" ]]; then
        _ACSH_SAVED_DEFAULT_COMPLETION=$(complete -p -D 2>/dev/null || true)
        _ACSH_SAVED_EMPTY_COMPLETION=$(complete -p -E 2>/dev/null || true)
        _ACSH_COMPLETION_STATE_CAPTURED=1
    fi

    # One native-only default/empty-line completion: never provider-backed.
    complete -D -E -F _acsh_native_complete -o bashdefault -o default
    # Bash 5.x honors only -D from a combined -D -E invocation, so register the
    # empty-line spec explicitly to keep Tab on an empty prompt native-only.
    complete -E -F _acsh_native_complete -o bashdefault -o default
    # CLI completion for the `autocomplete` command itself.
    complete -F _autocompletesh_cli autocomplete 2>/dev/null || true
    # Register the explicit AI readline actions (configurable, free chords
    # under the \C-x command prefix). Only meaningful in an interactive
    # readline shell; inert under `bats` and in scripts.
    if [[ -n "${ACSH_AI_COMPLETE_KEY:-}" ]]; then
        bind -x "\"${ACSH_AI_COMPLETE_KEY}\":_ai_complete_key" 2>/dev/null || true
    fi
    if [[ -n "${ACSH_AI_REWRITE_KEY:-}" ]]; then
        bind -x "\"${ACSH_AI_REWRITE_KEY}\":_ai_rewrite_key" 2>/dev/null || true
    fi
}

disable_command() {
    # Treat -D and -E independently. A user replacement made after enable is
    # not ours to remove and must not be overwritten by a stale saved spec.
    if _acsh_completion_slot_is_ours -D; then
        complete -r -D 2>/dev/null || true
        if [[ "$_ACSH_COMPLETION_STATE_CAPTURED" == "1" &&
            -n "$_ACSH_SAVED_DEFAULT_COMPLETION" ]]; then
            eval "$_ACSH_SAVED_DEFAULT_COMPLETION" 2>/dev/null || true
        fi
    fi
    if _acsh_completion_slot_is_ours -E; then
        complete -r -E 2>/dev/null || true
        if [[ "$_ACSH_COMPLETION_STATE_CAPTURED" == "1" &&
            -n "$_ACSH_SAVED_EMPTY_COMPLETION" ]]; then
            eval "$_ACSH_SAVED_EMPTY_COMPLETION" 2>/dev/null || true
        fi
    fi

    _ACSH_SAVED_DEFAULT_COMPLETION=""
    _ACSH_SAVED_EMPTY_COMPLETION=""
    _ACSH_COMPLETION_STATE_CAPTURED=0

    # Remove the `autocomplete` CLI completion ONLY when it is still ours.
    local cli_fn
    cli_fn=$(complete -p -- autocomplete 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="-F") {print $(i+1); exit}}')
    cli_fn=${cli_fn#\'}; cli_fn=${cli_fn%\'}
    if [[ "$cli_fn" == "_autocompletesh_cli" ]]; then
        complete -r autocomplete 2>/dev/null || true
    fi
    if [[ -n "${ACSH_AI_COMPLETE_KEY:-}" ]]; then
        bind -r "${ACSH_AI_COMPLETE_KEY}" 2>/dev/null || true
    fi
    if [[ -n "${ACSH_AI_REWRITE_KEY:-}" ]]; then
        bind -r "${ACSH_AI_REWRITE_KEY}" 2>/dev/null || true
    fi
}

_ai_complete_key() {
    # bind -x widget: capture the live line, request AI completion (prefix
    # preserving). Prints an inline preview; never modifies READLINE_LINE.
    local line="$READLINE_LINE"
    if [[ -z "$line" ]]; then return 0; fi
    _run_ai_command ai-completion ai-complete "$line"
}

_ai_rewrite_key() {
    # bind -x widget: capture the live line, request a whole-line AI rewrite.
    # Prints an inline preview; never modifies READLINE_LINE.
    local line="$READLINE_LINE"
    if [[ -z "$line" ]]; then return 0; fi
    _run_ai_command ai-rewrite ai-rewrite "$line"
}

command_command() {
    # Explicit AI entry point: `autocomplete command "..."` performs ONE
    # provider request routed through the answer-isolating cache
    # (_cached_completion, mode=command). --dry-run prints the exact prompt
    # that WOULD be sent and performs no request and no cache I/O.
    shift
    local arg user_input="" dry_run=0
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            dry_run=1
        else
            user_input="$user_input $arg"
        fi
    done
    user_input="${user_input# }"
    if [[ -z "$user_input" ]]; then
        echo_error "autocomplete command requires a command line argument"
        echo "Usage: autocomplete command [--dry-run] <line>..."
        echo "NOTE: AI completion of the LIVE command line is bound to ${ACSH_AI_COMPLETE_KEY:-\C-x\C-a} in an interactive shell."
        return 1
    fi
    if [[ $dry_run -eq 1 ]]; then
        acsh_load_config || return 1
        _validate_runtime_config || return 1
        _build_prompt "command" "$user_input"
        return 0
    fi
    local completions rc
    completions=$(_cached_completion "command" "$user_input" "${#user_input}")
    rc=$?
    if [[ $rc -ne 0 || -z "$completions" ]]; then
        echo_error "No completions returned for: $user_input"
        return 1
    fi
    export ACSH_INPUT="$user_input"
    export ACSH_RESPONSE="$completions"
    echo "$completions"
    return 0
}

# Shared driver for the explicit AI actions. Handles flag parsing (--dry-run
# precedes the line; no `--` separator; remaining args joined with spaces),
# calls the request orchestrator, validates, and prints a numbered preview.
#   $1 = mode (ai-completion|ai-rewrite)
#   $2 = user-facing action name (ai-complete|ai-rewrite)
#   rest = flags + line
_run_ai_command() {
    local mode="$1" action="$2" dry_run=0 arg line cand flag
    shift 2
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            dry_run=1
        else
            line="$line $arg"
        fi
    done
    line="${line# }"
    if [[ -z "$line" ]]; then
        echo_error "$action requires a command line argument"
        echo "Usage: autocomplete $action [--dry-run] <line>..."
        echo "NOTE: AI completion of the LIVE command line is bound to ${ACSH_AI_COMPLETE_KEY:-\C-x\C-a} in an interactive shell."
        return 1
    fi
    if [[ "$dry_run" -eq 1 ]]; then
        acsh_load_config || return 1
        _validate_runtime_config || return 1
        _print_context "$mode" "$line"
        return 0
    fi
    local result candidates dest_i
    result=$(_run_ai_request "$mode" "$line" "${#line}" "$PWD" 2>/dev/null)
    if [[ -z "$result" ]]; then
        echo "No AI result within ${ACSH_AI_DEADLINE:-1.5}s."
        return 1
    fi
    # Provider returns one candidate per line; preserve that boundary when
    # passing to the validators (never whitespace-split a whole command).
    local -a raw=() c
    while IFS= read -r c; do
        [[ -n "$c" ]] && raw+=("$c")
    done <<< "$result"
    if [[ "$mode" == "ai-completion" ]]; then
        candidates=$(_validate_ai_completion "$line" "${#line}" "${raw[@]}")
    else
        candidates=$(_validate_ai_rewrite "$mode" "${raw[@]}")
    fi
    if [[ -z "$candidates" ]]; then
        echo "No valid AI suggestions."
        return 1
    fi
    dest_i=0
    while IFS= read -r cand; do
        [[ -z "$cand" ]] && continue
        dest_i=$((dest_i + 1))
        flag=""
        if _acsh_is_destructive "$cand"; then flag=" [DESTRUCTIVE]"; fi
        echo "$dest_i. $cand$flag"
    done <<< "$candidates"
    return 0
}

ai_complete_command() {
    shift   # drop the subcommand word (dispatched by the CLI case)
    _run_ai_command ai-completion ai-complete "$@"
}

ai_rewrite_command() {
    shift   # drop the subcommand word (dispatched by the CLI case)
    _run_ai_command ai-rewrite ai-rewrite "$@"
}

context_command() {
    shift   # drop the subcommand word (dispatched by the CLI case)
    local mode="" line="" arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) ;;
            --mode) ;;
            --mode=*) mode="${arg#--mode=}" ;;
            ai-completion|ai-rewrite) mode="$arg" ;;
            *) line="$line $arg" ;;
        esac
    done
    line="${line# }"
    if [[ -z "$mode" ]]; then
        echo_error "context requires --mode ai-completion|ai-rewrite"
        return 1
    fi
    acsh_load_config || return 1
    _validate_runtime_config || return 1
    _print_context "$mode" "$line"
}

clear_command() {
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"} log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    echo "This will clear the cache and log file."
    echo -e "Cache directory: \e[31m$cache_dir\e[0m"
    echo -e "Log file: \e[31m$log_file\e[0m"
    read -r -p "Are you sure? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "Aborted."
        return
    fi
    if [ -d "$cache_dir" ]; then
        local cache_files
        cache_files=$(list_cache)
        if [ -n "$cache_files" ]; then
            while read -r line; do
                file=$(echo "$line" | cut -d ' ' -f 2-)
                rm "$file"
                echo "Removed: $file"
            done <<< "$cache_files"
        else
            echo "Cache is empty."
        fi
        # Also drop negative-cache (failure) markers from the P1 orchestrator.
        while IFS= read -r -d '' file; do
            rm -f "$file"
            echo "Removed: $file"
        done < <(find "$cache_dir" -maxdepth 1 -type f -name 'acsh-neg-*.fail' -print0 2>/dev/null)
        if [[ -n "$cache_files" ]]; then
            echo "Cleared cache in: $cache_dir"
        fi
    fi
    [ -f "$log_file" ] && { rm "$log_file"; echo "Removed: $log_file"; }
}

usage_command() {
    local log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"} cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    local cache_size number_of_lines api_cost avg_api_cost
    cache_size=$(list_cache | wc -l)
    echo_green "Autocomplete.sh - Usage Information"
    echo
    echo -n "Log file: "; echo -e "\e[90m$log_file\e[0m"
    if [ ! -f "$log_file" ]; then
        number_of_lines=0
        api_cost=0
        avg_api_cost=0
    else
        number_of_lines=$(wc -l < "$log_file")
        api_cost=$(awk -F, '{sum += $5} END {print sum}' "$log_file")
        avg_api_cost=$(echo "$api_cost / $number_of_lines" | bc -l)
    fi
    echo
    echo -e "\tUsage count:\t\e[32m$number_of_lines\e[0m"
    echo -e "\tAvg Cost:\t\$$(printf "%.4f" "$avg_api_cost")"
    echo -e "\tTotal Cost:\t\e[31m\$$(printf "%.4f" "$api_cost")\e[0m"
    echo
    echo -n "Cache Size: $cache_size of ${ACSH_CACHE_SIZE:-10} in "; echo -e "\e[90m$cache_dir\e[0m"
    echo "To clear log and cache, run: autocomplete clear"
}

###############################################################################
#                      Enhanced Interactive Menu UX                           #
###############################################################################

get_key() {
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key == $'\x1b' ]]; then
        read -rsn2 key
        if [[ $key == [A ]]; then echo up; fi
        if [[ $key == [B ]]; then echo down; fi
        if [[ $key == q ]]; then echo q; fi
    elif [[ $key == "q" ]]; then
        echo q
    else
        echo "$key"
    fi
}

menu_selector() {
    options=("$@")
    selected=0
    show_menu() {
        echo
        echo "Select a Language Model (Up/Down arrows, Enter to select, 'q' to quit):"
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "\e[1;32m> ${options[i]}\e[0m"
            else
                echo "  ${options[i]}"
            fi
        done
    }
    tput sc
    while true; do
        tput rc; tput ed
        show_menu
        key=$(get_key)
        case $key in
            up)
                ((selected--))
                if ((selected < 0)); then
                    selected=$((${#options[@]} - 1))
                fi
                ;;
            down)
                ((selected++))
                if ((selected >= ${#options[@]})); then
                    selected=0
                fi
                ;;
            q)
                echo "Selection canceled."
                return 1
                ;;
            "")
                break
                ;;
        esac
    done
    clear
    return $selected
}

model_command() {
    clear
    local selected_model options=()
    if [[ $# -ne 3 ]]; then
        mapfile -t sorted_keys < <(for key in "${!_autocomplete_modellist[@]}"; do echo "$key"; done | sort)
        for key in "${sorted_keys[@]}"; do
            options+=("$key")
        done
        echo -e "\e[1;32mAutocomplete.sh - Model Configuration\e[0m"
        menu_selector "${options[@]}"
        selected_option=$?
        if [[ $selected_option -eq 1 ]]; then
            return
        fi
        selected_model="${options[selected_option]}"
        selected_value="${_autocomplete_modellist[$selected_model]}"
    else
        provider="$2"
        model_name="$3"
        selected_value="${_autocomplete_modellist["$provider:	$model_name"]}"
        if [[ -z "$selected_value" ]]; then
            echo "ERROR: Invalid provider or model name."
            return 1
        fi
    fi
    set_config "model" "$(echo "$selected_value" | jq -r '.model')"
    set_config "endpoint" "$(echo "$selected_value" | jq -r '.endpoint')"
    set_config "provider" "$(echo "$selected_value" | jq -r '.provider')"
    prompt_cost=$(echo "$selected_value" | jq -r '.prompt_cost' | awk '{printf "%.8f", $1}')
    completion_cost=$(echo "$selected_value" | jq -r '.completion_cost' | awk '{printf "%.8f", $1}')
    set_config "api_prompt_cost" "$prompt_cost"
    set_config "api_completion_cost" "$completion_cost"
    if [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]] && _provider_requires_api_key "$ACSH_PROVIDER"; then
        echo -e "\e[34mSet ${ACSH_PROVIDER^^}_API_KEY\e[0m"
        echo "Stored in ~/.autocomplete/config"
        if [[ "$ACSH_PROVIDER" == "openai" ]]; then
            echo "Create a new one: https://platform.openai.com/settings/profile?tab=api-keys"
        elif [[ "$ACSH_PROVIDER" == "anthropic" ]]; then
            echo "Create a new one: https://console.anthropic.com/settings/keys"
        elif [[ "$ACSH_PROVIDER" == "groq" ]]; then
            echo "Create a new one: https://console.groq.com/keys"
        fi
        echo -n "Enter your ${ACSH_PROVIDER^^} API Key: "
        read -sr user_api_key_input < /dev/tty
        clear
        echo -e "\e[1;32mAutocomplete.sh - Model Configuration\e[0m"
        if [[ -n "$user_api_key_input" ]]; then
            export ACSH_ACTIVE_API_KEY="$user_api_key_input"
            set_config "${ACSH_PROVIDER//-/_}_api_key" "$user_api_key_input"
        fi
    fi
    model="${ACSH_MODEL:-ERROR}"
    temperature=$(echo "${ACSH_TEMPERATURE:-0.0}" | awk '{printf "%.3f", $1}')
    echo -e "Provider:\t\e[90m$ACSH_PROVIDER\e[0m"
    echo -e "Model:\t\t\e[90m$model\e[0m"
    echo -e "Temperature:\t\e[90m$temperature\e[0m"
    echo
    echo -e "Cost/token:\t\e[90mprompt: \$$ACSH_API_PROMPT_COST, completion: \$$ACSH_API_COMPLETION_COST\e[0m"
    echo -e "Endpoint:\t\e[90m$ACSH_ENDPOINT\e[0m"
    echo -n "API Key:"
    if [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]]; then
        if _provider_requires_api_key "$ACSH_PROVIDER"; then
            echo -e "\t\e[31mUNSET\e[0m"
        else
            echo -e "\t\e[90mNot Used\e[0m"
        fi
    else
        rest=${ACSH_ACTIVE_API_KEY:4}
        config_value="${ACSH_ACTIVE_API_KEY:0:4}...${rest: -4}"
        echo -e "\t\e[32m$config_value\e[0m"
    fi
    if [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]] && _provider_requires_api_key "$ACSH_PROVIDER"; then
        echo "To set the API Key, run:"
        echo -e "\t\e[31mautocomplete config set api_key <your-api-key>\e[0m"
        echo -e "\t\e[31mexport ${ACSH_PROVIDER^^}_API_KEY=<your-api-key>\e[0m"
    fi
    if [[ "$ACSH_PROVIDER" == "openai-compatible" ]]; then
        echo "OpenAI-compatible provider configured. Optional key (env: OPENAI_COMPATIBLE_API_KEY):"
        echo -e "\t\e[34mautocomplete config set openai_compatible_api_key <your-key>\e[0m"
        echo "Custom request headers / extra body (JSON, openai-compatible only):"
        echo -e "\t\e[34mautocomplete config set request_headers_json '{\"User-Agent\":\"my-app\"}'\e[0m"
        echo -e "\t\e[34mautocomplete config set extra_body_json '{\"max_tokens\":2048}'\e[0m"
    fi
    if [[ "$ACSH_PROVIDER" == "ollama" ]]; then
        echo "To set a custom endpoint:"
        echo -e "\t\e[34mautocomplete config set endpoint <your-url>\e[0m"
        echo "Other models can be set with:"
        echo -e "\t\e[34mautocomplete config set model <model-name>\e[0m"
    fi
    echo "To change temperature:"
    echo -e "\t\e[90mautocomplete config set temperature <temperature>\e[0m"
    echo "To change the request timeout (seconds):"
    echo -e "\t\e[90mautocomplete config set request_timeout_seconds <seconds>\e[0m"
    echo
}

###############################################################################
#                              CLI ENTRY POINT                                #
###############################################################################

case "${1:-}" in
    "--help")
        show_help
        ;;
    system)
        _system_info
        ;;
    install)
        install_command
        ;;
    remove)
        remove_command "$@"
        ;;
    clear)
        clear_command
        ;;
    usage)
        usage_command
        ;;
    model)
        model_command "$@"
        ;;
    config)
        config_command "$@"
        ;;
    enable)
        enable_command
        ;;
    disable)
        disable_command
        ;;
    command)
        command_command "$@"
        ;;
    ai-complete)
        ai_complete_command "$@"
        ;;
    ai-rewrite)
        ai_rewrite_command "$@"
        ;;
    context)
        context_command "$@"
        ;;
    *)
        if [[ -n "${1:-}" ]]; then
            echo_error "Unknown command $1 - run 'autocomplete --help' for usage or visit https://autocomplete.sh"
        else
            echo_green "Autocomplete.sh - LLM Powered Bash Completion - Version $ACSH_VERSION - https://autocomplete.sh"
        fi
        ;;
esac
