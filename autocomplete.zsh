#!/bin/zsh
# Autocomplete.zsh - LLM Powered Zsh Completion
# MIT License - ClosedLoop Technologies, Inc.
# Sean Kruzel 2024-2025
#
# This script provides zsh completion suggestions using an LLM.
# It has been migrated from the Bash version to work with zsh.
#
# Note: Do not enable “set -euo pipefail” here because it may interfere with shell completion.

###############################################################################
#                    Initialize Zsh Completion Compatibility                  #
###############################################################################
# compinit remains authoritative for ORDINARY completion: Tab is 100%
# native-only and never contacts a language model. LLM suggestions are an
# EXPLICIT action (`autocomplete command "<line>"`), routed through the shared
# completion cache (_cached_completion).
if [[ -n $ZSH_VERSION ]]; then
    autoload -Uz compinit && compinit -u
fi

# Absolute path of this script (shell-specific), used by install/remove.
ACSH_SCRIPT_PATH=${(%):-%x}
if [[ "$ACSH_SCRIPT_PATH" != /* ]]; then
    ACSH_SCRIPT_PATH="${PWD}/${ACSH_SCRIPT_PATH}"
fi
ACSH_SCRIPT_PATH="$(cd "$(dirname "$ACSH_SCRIPT_PATH")" 2>/dev/null && pwd -P 2>/dev/null)/$(basename "$ACSH_SCRIPT_PATH")"
export ACSH_SCRIPT_PATH

###############################################################################
#                         Enhanced Error Handling                             #
###############################################################################


echo_error() {
    echo -e "\e[31mAutocomplete.zsh - $1\e[0m" >&2
}

echo_green() {
    echo -e "\e[32m$1\e[0m"
}

###############################################################################
#                     Global Variables & Model Definitions                    #
###############################################################################

export ACSH_VERSION=0.6.0
export ACSH_CACHE_SCHEMA_VERSION=1

typeset -A _autocomplete_modellist
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
 * Shell: \$SHELL
 * Terminal type: \$TERM
 * Hostname: \$HOSTNAME"
    echo "$terminal_info"
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
    echo "ZSH_VERSION: $ZSH_VERSION"
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

# Bounded history: stops after ACSH_MAX_HISTORY_COMMANDS entries.
_get_command_history() {
    local HISTORY_LIMIT=${ACSH_MAX_HISTORY_COMMANDS:-10}
    history 2>/dev/null | tail -n "$HISTORY_LIMIT"
}

# Refined sanitization: replace long hex sequences, UUIDs, and API-key–like tokens.
# Additionally redacts the VALUES of case-insensitive assignments whose names
# contain KEY/TOKEN/SECRET/PASSWORD/PASS/AUTH, and `Authorization: Bearer …`
# tokens. Only values are redacted — never whole lines.
_get_clean_command_history() {
    local recent_history
    recent_history=$(_get_command_history)
    recent_history=$(print -rn -- "$recent_history" | sed -E 's/\b[[:xdigit:]]{32,40}\b/REDACTED_HASH/g')
    recent_history=$(print -rn -- "$recent_history" | sed -E 's/\b[0-9a-fA-F-]{36}\b/REDACTED_UUID/g')
    recent_history=$(print -rn -- "$recent_history" | sed -E 's/\b[A-Za-z0-9]{16,40}\b/REDACTED_APIKEY/g')
    recent_history=$(print -rn -- "$recent_history" | sed -E 's/(^|[[:space:]])((([A-Za-z_][A-Za-z0-9_]*)?([Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss]|[Aa][Uu][Tt][Hh])[A-Za-z0-9_]*)=)("[^"]*"|[^[:space:]]*)/\1\2REDACTED/g')
    recent_history=$(print -rn -- "$recent_history" | sed -E 's/([Aa][Uu][Tt][Hh][Oo][Rr][Ii][Zz][Aa][Tt][Ii][Oo][Nn]:[[:space:]]*[Bb][Ee][Aa][Rr][Ee][Rr][[:space:]]+)[^[:space:]]+/\1REDACTED/g')
    print -r -- "$recent_history"
}

# At most ACSH_MAX_RECENT_FILES current-directory BASENAMES only — no
# ownership/permission/absolute-path metadata.
_get_recent_files() {
    local FILE_LIMIT=${ACSH_MAX_RECENT_FILES:-10}
    find . -maxdepth 1 -type f -printf '%T@ %f\n' 2>/dev/null | sort -rn | head -n "$FILE_LIMIT" | cut -d ' ' -f 2-
}

# Returns nothing unless the help context is enabled. The first token must
# resolve to a PATH executable (aliases/functions/builtins/unresolved are
# skipped); runs ONLY the resolved executable with `--help`, stdin from
# /dev/null, bounded by ACSH_HELP_TIMEOUT_SECONDS and capped at
# ACSH_MAX_HELP_LINES. Timeout/failure => absent section (no error, no retry).
_get_help_message() {
    if [[ "${ACSH_CONTEXT_HELP:-false}" != "true" ]]; then
        return 0
    fi
    local first_token resolved help_timeout max_help_lines help_output help_rc
    first_token=$(echo "$1" | awk '{print $1}')
    if [[ -z "$first_token" ]]; then
        return 0
    fi
    resolved=$(whence -p "$first_token" 2>/dev/null || true)
    if [[ -z "$resolved" ]]; then
        return 0
    fi
    help_timeout=${ACSH_HELP_TIMEOUT_SECONDS:-0.25}
    max_help_lines=${ACSH_MAX_HELP_LINES:-40}
    help_output=$({ timeout "$help_timeout" "$resolved" --help < /dev/null 2>/dev/null; })
    help_rc=$?
    if (( help_rc == 0 )); then
        echo "$help_output" | head -n "$max_help_lines"
    fi
    return 0
}

# Sorted environment variable NAMES only (never values), no ACSH_* names,
# bounded by ACSH_MAX_ENVIRONMENT_NAMES.
_get_environment_context() {
    local -i env_limit=${ACSH_MAX_ENVIRONMENT_NAMES:-50}
    local record name
    local -a environment_names sorted_names
    local -i index max_count

    while IFS= read -r -d '' record; do
        name=${record%%=*}
        [[ "$name" == ACSH_* ]] && continue
        environment_names+=("$name")
    done < <(env -0)

    sorted_names=("${(@on)environment_names}")
    max_count=${#sorted_names}
    (( max_count > env_limit )) && max_count=$env_limit
    for (( index = 1; index <= max_count; index++ )); do
        print -r -- "${sorted_names[index]}"
    done
}

# Minimal privacy-safe terminal context: physical cwd, OS type, shell, and
# terminal type ONLY. Never username, hostname, home, or previous directory.
_get_prompt_terminal_context() {
    local cwd
    cwd=$(pwd -P 2>/dev/null || echo "$PWD")
    echo " * Current directory: $cwd
 * Operating system: $OSTYPE
 * Shell: $SHELL
 * Terminal type: $TERM"
}

# Prompt base always contains ONLY: mode, active shell, user input, and output
# instructions. Optional context sections are appended ONLY when the matching
# context_* switch is exactly `true` AND the bounded helper produced output.
_build_prompt() {
    local mode="$1" user_input="$2"
    local prompt output_instructions section
    output_instructions=$(_get_output_instructions)
    prompt="mode: $mode
shell: zsh $ZSH_VERSION
user input: $user_input

# Instructions
$output_instructions
"
    if [[ "${ACSH_CONTEXT_TERMINAL:-false}" == "true" ]]; then
        section=$(_get_prompt_terminal_context)
        if [[ -n "$section" ]]; then
            prompt="${prompt}

# Terminal Context
$section
"
        fi
    fi
    if [[ "${ACSH_CONTEXT_ENVIRONMENT:-false}" == "true" ]]; then
        section=$(_get_environment_context)
        if [[ -n "$section" ]]; then
            prompt="${prompt}

## Environment
\`\`\`
$section
\`\`\`
"
        fi
    fi
    if [[ "${ACSH_CONTEXT_HISTORY:-false}" == "true" ]]; then
        section=$(_get_clean_command_history)
        if [[ -n "$section" ]]; then
            prompt="${prompt}

## History
\`\`\`
$section
\`\`\`
"
        fi
    fi
    if [[ "${ACSH_CONTEXT_RECENT_FILES:-false}" == "true" ]]; then
        section=$(_get_recent_files)
        if [[ -n "$section" ]]; then
            prompt="${prompt}

## File system
\`\`\`
$section
\`\`\`
"
        fi
    fi
    if [[ "${ACSH_CONTEXT_HELP:-false}" == "true" ]]; then
        section=$(_get_help_message "$user_input")
        if [[ -n "$section" ]]; then
            prompt="${prompt}

## Help Information
$section
"
        fi
    fi
    echo "$prompt"
}

###############################################################################
#                  Provider and Configuration Validation                      #
###############################################################################

_normalize_provider() {
    local raw="$1" provider
    provider="${(L)raw}"
    case "$provider" in
        openai|anthropic|groq|ollama|openai-compatible)
            print -r -- "$provider"
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
    local provider="$1"
    case "$provider" in
        openai)
            export ACSH_ACTIVE_API_KEY="${ACSH_OPENAI_API_KEY:-}"
            ;;
        anthropic)
            export ACSH_ACTIVE_API_KEY="${ACSH_ANTHROPIC_API_KEY:-}"
            ;;
        groq)
            export ACSH_ACTIVE_API_KEY="${ACSH_GROQ_API_KEY:-}"
            ;;
        ollama)
            export ACSH_ACTIVE_API_KEY="${ACSH_OLLAMA_API_KEY:-}"
            ;;
        openai-compatible)
            export ACSH_ACTIVE_API_KEY="${ACSH_OPENAI_COMPATIBLE_API_KEY:-}"
            ;;
        *)
            echo_error "Unknown provider: $provider"
            return 1
            ;;
    esac
    return 0
}

_normalize_json() {
    local json="$1"
    if ! print -rn -- "$json" | jq -cS . 2>/dev/null; then
        echo_error "Invalid JSON."
        return 1
    fi
}

_validate_headers_json() {
    local json="$1"
    if ! print -rn -- "$json" | jq -e '
        def token: (type == "string") and test("^[A-Za-z0-9!#$%&\\x27*+.^_`|~-]+$");
        def value_ok: (type == "string") and ((test("[\r\n]")) | not);
        def unreserved:
            ((. | ascii_downcase) != "authorization") and
            ((. | ascii_downcase) != "content-type");
        (type == "object") and
        ([to_entries[] |
            select(
                ((.key | token) | not) or
                ((.value | value_ok) | not) or
                ((.key | unreserved) | not)
            )
        ] | length == 0)
    ' >/dev/null 2>&1; then
        echo_error "ACSH_REQUEST_HEADERS_JSON must be a JSON object with HTTP-token field names and string values without CR/LF; Authorization and Content-Type are reserved."
        return 1
    fi
    return 0
}

_validate_extra_body_json() {
    local json="$1"
    if ! print -rn -- "$json" | jq -e '
        (type == "object") and
        ([to_entries[] |
            select(
                .key == "model" or
                .key == "messages" or
                .key == "tools" or
                .key == "tool_choice" or
                .key == "response_format" or
                .key == "stream"
            )
        ] | length == 0)
    ' >/dev/null 2>&1; then
        echo_error "ACSH_EXTRA_BODY_JSON must be a JSON object without reserved keys (model, messages, tools, tool_choice, response_format, stream)."
        return 1
    fi
    return 0
}

_validate_config_value() {
    local key="$1" value="$2"
    case "$key" in
        context_terminal|context_environment|context_history|context_recent_files|context_help)
            if [[ "$value" != "true" && "$value" != "false" ]]; then
                echo_error "Invalid value for $key: expected exact lowercase 'true' or 'false'."
                return 1
            fi
            ;;
        provider)
            _normalize_provider "$value" >/dev/null || return 1
            ;;
        temperature|api_prompt_cost|api_completion_cost)
            if ! print -rn -- "$value" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
                echo_error "Invalid value for $key: expected a nonnegative decimal number."
                return 1
            fi
            ;;
        request_timeout_seconds|help_timeout_seconds)
            if ! print -rn -- "$value" | grep -Eq '^[0-9]+([.][0-9]+)?$' ||
               ! awk -v value="$value" 'BEGIN { exit !(value > 0) }' </dev/null; then
                echo_error "Invalid value for $key: expected a positive decimal number."
                return 1
            fi
            ;;
        cache_size|max_environment_names|max_history_commands|max_recent_files|max_help_lines)
            if ! print -rn -- "$value" | grep -Eq '^[0-9]+$' ||
               ! awk -v value="$value" 'BEGIN { exit !(value > 0) }' </dev/null; then
                echo_error "Invalid value for $key: expected a positive integer."
                return 1
            fi
            ;;
        request_headers_json)
            _validate_headers_json "$value" || return 1
            ;;
        extra_body_json)
            _validate_extra_body_json "$value" || return 1
            ;;
    esac
    return 0
}

_validate_runtime_config() {
    local provider headers extra_body normalized_headers normalized_extra_body key_label
    provider="${ACSH_PROVIDER:-openai}"
    headers=${ACSH_REQUEST_HEADERS_JSON:-'{}'}
    extra_body=${ACSH_EXTRA_BODY_JSON:-'{}'}

    _validate_config_value provider "$provider" || return 1
    _validate_config_value temperature "${ACSH_TEMPERATURE:-0.0}" || return 1
    _validate_config_value api_prompt_cost "${ACSH_API_PROMPT_COST:-0.000005}" || return 1
    _validate_config_value api_completion_cost "${ACSH_API_COMPLETION_COST:-0.000015}" || return 1
    _validate_config_value request_timeout_seconds "${ACSH_REQUEST_TIMEOUT_SECONDS:-5}" || return 1
    _validate_config_value help_timeout_seconds "${ACSH_HELP_TIMEOUT_SECONDS:-0.25}" || return 1
    _validate_config_value cache_size "${ACSH_CACHE_SIZE:-10}" || return 1
    _validate_config_value context_terminal "${ACSH_CONTEXT_TERMINAL:-false}" || return 1
    _validate_config_value context_environment "${ACSH_CONTEXT_ENVIRONMENT:-false}" || return 1
    _validate_config_value context_history "${ACSH_CONTEXT_HISTORY:-false}" || return 1
    _validate_config_value context_recent_files "${ACSH_CONTEXT_RECENT_FILES:-false}" || return 1
    _validate_config_value context_help "${ACSH_CONTEXT_HELP:-false}" || return 1
    _validate_config_value max_environment_names "${ACSH_MAX_ENVIRONMENT_NAMES:-50}" || return 1
    _validate_config_value max_history_commands "${ACSH_MAX_HISTORY_COMMANDS:-10}" || return 1
    _validate_config_value max_recent_files "${ACSH_MAX_RECENT_FILES:-10}" || return 1
    _validate_config_value max_help_lines "${ACSH_MAX_HELP_LINES:-40}" || return 1
    _validate_config_value request_headers_json "$headers" || return 1
    _validate_config_value extra_body_json "$extra_body" || return 1

    normalized_headers=$(_normalize_json "$headers") || return 1
    normalized_extra_body=$(_normalize_json "$extra_body") || return 1
    if [[ "$provider" != "openai-compatible" &&
          ( "$normalized_headers" != "{}" || "$normalized_extra_body" != "{}" ) ]]; then
        echo_error "Custom request headers and extra body fields are only supported for provider 'openai-compatible'."
        return 1
    fi
    if _provider_requires_api_key "$provider" && [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]]; then
        key_label="${(U)provider}"
        key_label="${key_label//-/_}"
        echo_error "ACSH_ACTIVE_API_KEY not set. Please set it with: export ${key_label}_API_KEY=<your-api-key>"
        return 1
    fi
    if [[ "${ACSH_ACTIVE_API_KEY:-}" == *$'\r'* || "${ACSH_ACTIVE_API_KEY:-}" == *$'\n'* ]]; then
        echo_error "ACSH_ACTIVE_API_KEY must not contain CR/LF."
        return 1
    fi
    return 0
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
    local prompt system_message_prompt payload acsh_prompt provider extra_body base_payload
    local model temperature
    model="${ACSH_MODEL:-gpt-4o}"
    temperature="${ACSH_TEMPERATURE:-0.0}"
    provider="${ACSH_PROVIDER:-openai}"

    prompt=$(_build_prompt "$mode" "$user_input")
    system_message_prompt=$(_get_system_message_prompt)

    acsh_prompt="# SYSTEM PROMPT
$system_message_prompt
# USER MESSAGE
$prompt"
    export ACSH_PROMPT="$acsh_prompt"

    prompt_content="$prompt"
    system_prompt="$system_message_prompt"

    base_payload=$(build_common_payload)

    # Validated extra-body fields merge into the COMMON payload BEFORE the
    # provider's structured-output contract below — extra_body may tune the
    # request (max_tokens, chat_template_kwargs, ...) but can never replace
    # its identity fields or the response schema. openai-compatible only.
    extra_body=${ACSH_EXTRA_BODY_JSON:-'{}'}
    if [[ "$extra_body" != "{}" ]]; then
        base_payload=$(print -rn -- "$base_payload" | jq -c --argjson extra "$extra_body" '. + $extra') || return 1
    fi

    case "$provider" in
        "anthropic")
            payload=$(print -rn -- "$base_payload" | jq '. + {
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
            payload=$(print -rn -- "$base_payload" | jq '. + {response_format: {type: "json_object"}}')
            ;;
        "ollama")
            payload=$(print -rn -- "$base_payload" | jq '. + {
                format: "json",
                stream: false,
                options: {temperature: (.temperature | tonumber)}
            }')
            ;;
        *)
            # openai, groq and openai-compatible share the tool-call contract.
            payload=$(print -rn -- "$base_payload" | jq '. + {
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
    print -r -- "$payload"
}

# Absent or non-numeric usage counts are treated as ZERO.
log_request() {
    local user_input response_body user_input_hash log_file prompt_tokens completion_tokens created api_cost
    local prompt_tokens_int completion_tokens_int
    user_input="$1"
    response_body="$2"
    user_input_hash=$(echo -n "$user_input" | md5sum | cut -d ' ' -f 1)

    if [[ "$ACSH_PROVIDER" == "anthropic" ]]; then
        prompt_tokens=$(echo "$response_body" | jq -r '.usage.input_tokens // empty' 2>/dev/null)
        completion_tokens=$(echo "$response_body" | jq -r '.usage.output_tokens // empty' 2>/dev/null)
    else
        prompt_tokens=$(echo "$response_body" | jq -r '.usage.prompt_tokens // empty' 2>/dev/null)
        completion_tokens=$(echo "$response_body" | jq -r '.usage.completion_tokens // empty' 2>/dev/null)
    fi
    prompt_tokens_int=0
    completion_tokens_int=0
    if [[ "$prompt_tokens" =~ ^[0-9]+$ ]]; then
        prompt_tokens_int=$((prompt_tokens))
    fi
    if [[ "$completion_tokens" =~ ^[0-9]+$ ]]; then
        completion_tokens_int=$((completion_tokens))
    fi

    created=$(date +%s)
    created=$(echo "$response_body" | jq -r ".created // $created" 2>/dev/null)
    api_cost=$(echo "$prompt_tokens_int * ${ACSH_API_PROMPT_COST:-0.000005} + $completion_tokens_int * ${ACSH_API_COMPLETION_COST:-0.000015}" | bc)
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    echo "$created,$user_input_hash,$prompt_tokens_int,$completion_tokens_int,$api_cost" >> "$log_file"
}


# Exactly ONE bounded HTTP attempt. Builds the prompt/payload, performs the
# request, maps non-200 to a nonzero status, and writes the UNTOUCHED
# successful response body to stdout. It does NOT parse, validate, cache, log,
# or retry — that all happens in _cached_completion.
_request_completion() {
    local mode="$1" user_input="$2"
    local api_key payload endpoint timeout provider status_code response_body response auth_header=""
    local header_name header_value
    local -a curl_args
    provider="$ACSH_PROVIDER"
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
    timeout=${ACSH_REQUEST_TIMEOUT_SECONDS:-5}
    _validate_runtime_config || return 1
    api_key="${ACSH_ACTIVE_API_KEY:-}"
    payload=$(_build_payload "$mode" "$user_input") || return 1

    # Build one argv vector in wire order. Standard provider headers precede
    # validated custom headers; data and the single endpoint come last.
    curl_args=(-s --max-time "$timeout" -w $'\n%{http_code}')
    case "$provider" in
        "anthropic")
            curl_args+=(-H "content-type: application/json" -H "anthropic-version: 2023-06-01" -H @-)
            auth_header="x-api-key: $api_key"
            ;;
        "ollama")
            ;;
        *)
            curl_args+=(-H "Content-Type: application/json")
            # openai-compatible may run keyless; every keyed OpenAI-style
            # request receives exactly one Authorization header.
            if [[ -n "$api_key" ]]; then
                curl_args+=(-H @-)
                auth_header="Authorization: Bearer $api_key"
            fi
            ;;
    esac

    # Runtime validation restricts custom headers to openai-compatible and
    # guarantees string values. NUL-delimited pairs preserve spaces and tabs.
    if [[ "$provider" == "openai-compatible" && -n "${ACSH_REQUEST_HEADERS_JSON:-}" && "$ACSH_REQUEST_HEADERS_JSON" != "{}" ]]; then
        while IFS= read -r -d $'\0' header_name; do
            IFS= read -r -d $'\0' header_value || return 1
            curl_args+=(-H "$header_name: $header_value")
        done < <(print -rn -- "$ACSH_REQUEST_HEADERS_JSON" | jq -j 'to_entries[] | .key, "\u0000", .value, "\u0000"')
    fi
    curl_args+=(--data "$payload" -- "$endpoint")

    if [[ -n "$auth_header" ]]; then
        response=$(printf '%s\n' "$auth_header" | command curl "${curl_args[@]}") || return 1
    else
        response=$(command curl "${curl_args[@]}") || return 1
    fi
    status_code=$(print -r -- "$response" | tail -n 1)
    response_body=$(print -r -- "$response" | sed '$d')
    if [[ "$status_code" != "200" ]]; then
        return 1
    fi
    print -rn -- "$response_body"
}

###############################################################################
#                        Cache Functions (versioned, validated)              #
###############################################################################


# Serializes NUL-delimited `key=value` records covering every input that can
# change an answer: schema version, shell name/version, mode, line, cursor,
# physical cwd, provider/endpoint/model, normalized custom header/body JSON,
# a SHA-256 digest of the ACTIVE key (never the key itself), and the
# normalized context_*/context-bound config values. Returns the sha256 digest.
_completion_cache_key() {
    local mode="$1" line="$2" cursor="$3"
    local cwd provider endpoint model active_key_digest headers extra_body temperature
    cwd=$(pwd -P 2>/dev/null || print -r -- "$PWD")
    provider="$ACSH_PROVIDER"
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
    model="${ACSH_MODEL:-gpt-4o}"
    active_key_digest=$(printf '%s' "${ACSH_ACTIVE_API_KEY:-}" | sha256sum | cut -d ' ' -f 1)
    headers="${ACSH_REQUEST_HEADERS_JSON-}"
    [[ -n "$headers" ]] || headers='{}'
    extra_body="${ACSH_EXTRA_BODY_JSON-}"
    [[ -n "$extra_body" ]] || extra_body='{}'
    headers=$(_normalize_json "$headers") || return 1
    extra_body=$(_normalize_json "$extra_body") || return 1
    temperature=$(jq -nr --arg value "$ACSH_TEMPERATURE" '$value | tonumber | . + 0' 2>/dev/null) || return 1

    {
        printf 'schema_version=%s\0' "$ACSH_CACHE_SCHEMA_VERSION"
        printf 'shell=zsh %s\0' "$ZSH_VERSION"
        printf 'mode=%s\0' "$mode"
        printf 'line=%s\0' "$line"
        printf 'cursor=%s\0' "$cursor"
        printf 'cwd=%s\0' "$cwd"
        printf 'provider=%s\0' "$provider"
        printf 'endpoint=%s\0' "$endpoint"
        printf 'model=%s\0' "$model"
        printf 'request_headers_json=%s\0' "$headers"
        printf 'extra_body_json=%s\0' "$extra_body"
        printf 'temperature=%s\0' "$temperature"
        printf 'active_key_sha256=%s\0' "$active_key_digest"
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

# Accepts 1-5 nonempty newline-delimited records from stdin; rejects control
# characters and records longer than 4096 chars. Emits all records unchanged
# only after the complete input has passed validation.
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

# Provider-specific extraction followed by a strict structural check: the
# result must be a JSON array of 1-5 nonempty strings, no control characters,
# each at most 4096 chars. Only then is it converted to newline records and
# passed through _validate_completion_lines. Invalid input produces no output.
_parse_and_validate_completions() {
    local provider="$1" response_body="$2"
    local content_json validated
    provider=$(_normalize_provider "$provider") || return 1

    case "$provider" in
        "anthropic")
            content_json=$(print -rn -- "$response_body" |
                jq -c '.content[0].input.commands' 2>/dev/null) || return 1
            ;;
        "groq")
            content_json=$(print -rn -- "$response_body" |
                jq -c '.choices[0].message.content | fromjson | .completions' 2>/dev/null) || return 1
            ;;
        "ollama")
            content_json=$(print -rn -- "$response_body" |
                jq -c '.message.content | fromjson | .completions' 2>/dev/null) || return 1
            ;;
        "openai"|"openai-compatible")
            content_json=$(print -rn -- "$response_body" |
                jq -c '.choices[0].message.tool_calls[0].function.arguments | fromjson | .commands' 2>/dev/null) || return 1
            ;;
        *)
            return 1
            ;;
    esac

    if ! print -rn -- "$content_json" | jq -e '
        type == "array"
        and length >= 1
        and length <= 5
        and all(.[];
            type == "string"
            and length >= 1
            and length <= 4096
            and (explode | all(. >= 32 and . != 127))
        )
    ' >/dev/null 2>&1; then
        return 1
    fi

    validated=$(print -rn -- "$content_json" | jq -r '.[]' |
        _validate_completion_lines) || return 1
    print -r -- "$validated"
}

# Reads pass through _validate_completion_lines; a corrupt file is removed
# and treated as a miss. Only _parse_and_validate_completions output may ever
# reach _cache_write.
_cache_read() {
    local cache_file="$1" content
    if [[ ! -f "$cache_file" ]]; then
        return 1
    fi
    if ! content=$(_validate_completion_lines < "$cache_file" 2>/dev/null); then
        rm -f "$cache_file" 2>/dev/null
        return 1
    fi
    print -r -- "$content"
}

# Atomic write: mktemp in the cache dir, mode 0600, printf, atomic mv.
_cache_write() {
    local cache_file="$1" validated="$2"
    local cache_dir tmp_file
    cache_dir=$(dirname "$cache_file")
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir" 2>/dev/null || return 1
    fi
    tmp_file=$(mktemp "$cache_dir/.acsh-cache.XXXXXX") 2>/dev/null || return 1
    chmod 0600 "$tmp_file" 2>/dev/null
    printf '%s\n' "$validated" > "$tmp_file" || { rm -f "$tmp_file"; return 1; }
    mv -f "$tmp_file" "$cache_file" || { rm -f "$tmp_file"; return 1; }
    chmod 0600 "$cache_file" 2>/dev/null
    return 0
}

# Config -> key -> valid hit (touched for LRU) or: exactly one request, parse
# + validate, log with the SAME raw body, atomic write, oldest-first
# eviction. Provider/config/timeout failures => nonzero, NO log, NO cache
# entry. `autocomplete command` is the sole explicit AI entry point here.
_cached_completion() {
    local mode="$1" line="$2" cursor="$3"
    local cache_dir cache_size cache_file key completions raw_body provider
    acsh_load_config || return 1
    _validate_runtime_config || return 1
    provider="$ACSH_PROVIDER"
    cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    cache_size=${ACSH_CACHE_SIZE:-10}
    key=$(_completion_cache_key "$mode" "$line" "$cursor")
    cache_file="$cache_dir/acsh-v1-$key.txt"
    if [[ -d "$cache_dir" && "$cache_size" -gt 0 && -f "$cache_file" ]]; then
        if completions=$(_cache_read "$cache_file"); then
            touch "$cache_file" 2>/dev/null
            echo "$completions"
            return 0
        fi
    fi
    raw_body=$(_request_completion "$mode" "$line") || return 1
    if [[ -z "$raw_body" ]]; then
        return 1
    fi
    completions=$(_parse_and_validate_completions "$provider" "$raw_body") || return 1
    log_request "$line" "$raw_body"
    if [[ -d "$cache_dir" && "$cache_size" -gt 0 ]]; then
        mkdir -p "$cache_dir" 2>/dev/null
        _cache_write "$cache_file" "$completions"
        # Existing oldest-first eviction against the configured cache size.
        while [[ $(list_cache | wc -l) -gt "$cache_size" ]]; do
            oldest=$(list_cache | head -n 1 | cut -d ' ' -f 2-)
            rm -f "$oldest"
        done
    fi
    echo "$completions"
}

###############################################################################
#                        Completion Functions                                 #
###############################################################################

list_cache() {
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    find "$cache_dir" -maxdepth 1 -type f -name "acsh-v1-*.txt" -printf '%T+ %p\n' | sort
}

# Zsh-native completion for the `autocomplete` CLI command (compdef-registered).
_autocompletesh_cli() {
    if (( ${CURRENT:-0} > 2 )); then
        case "${words[2]:-}" in
            config) compadd -- set reset ;;
            command) compadd -- '--dry-run' ;;
        esac
    elif (( ${CURRENT:-0} == 2 )); then
        compadd -- install remove config enable disable clear usage system command model --help
    fi
}

###############################################################################
#                    CLI Commands & Configuration Management                  #
###############################################################################

show_help() {
    echo_green "Autocomplete.zsh - LLM Powered Zsh Completion"
    echo "Usage: autocomplete [options] command"
    echo "       autocomplete [options] install|remove|config|model|enable|disable|clear|usage|system|command|--help"
    echo
    echo "Autocomplete.zsh enhances zsh completion with LLM capabilities."
    echo "Tab is 100% native-only: ordinary completion never contacts a"
    echo "language model. AI suggestions are an EXPLICIT action:"
    echo
    echo "  autocomplete command \"<line>\"           Ask for command suggestions (LLM, cached)"
    echo "  autocomplete command --dry-run \"<line>\"  Show the prompt that WOULD be sent"
    echo "                                            (network-free, no cache I/O)"
    echo
    echo "Commands:"
    echo "  command             Run autocomplete (LLM suggestions, cached)"
    echo "  command --dry-run   Show generated prompt without executing"
    echo "  model               Change language model"
    echo "  usage               Display usage stats"
    echo "  system              Display system information"
    echo "  config              Show or set configuration values"
    echo "    config set <key> <value>  Set a config value"
    echo "    config reset             Reset config to defaults"
    echo "  install             Install autocomplete to .zshrc"
    echo "  remove              Remove installation from .zshrc"
    echo "  enable              Enable autocomplete"
    echo "  disable             Disable autocomplete"
    echo "  clear               Clear cache and log files"
    echo "  --help              Show this help message"
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
    echo_green "Autocomplete.zsh - Configuration and Settings - Version $ACSH_VERSION"
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
    for config_var in ${(k)parameters:#ACSH_*}; do
        if [[ $config_var == "ACSH_INPUT" || $config_var == "ACSH_PROMPT" || $config_var == "ACSH_RESPONSE" ]]; then
            continue
        fi
        config_value="${(P)config_var}"
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
    for config_var in ${(k)parameters:#ACSH_*}; do
        if [[ $config_var == "ACSH_INPUT" || $config_var == "ACSH_PROMPT" || $config_var == "ACSH_RESPONSE" ]]; then
            continue
        fi
        if [[ ${config_var: -8} != "_API_KEY" ]]; then
            continue
        fi
        echo -en "  $config_var:\e[90m"
        if [[ -z ${(P)config_var} ]]; then
            config_value="UNSET"
            echo -en "\e[31m"
        else
            rest=${(P)config_var}
            config_value="${rest:0:4}...${rest[-4,-1]}"
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

# Same-directory temp rewrite + atomic rename (mode 0600). Updates an existing
# normalized key or APPENDS a missing one, so old configs acquire new P0
# settings via `autocomplete config set`. Values are validated BEFORE the
# rewrite; invalid input leaves the file byte-identical.
set_config() {
    local key="$1" value="$2" config_file="$HOME/.autocomplete/config"
    local config_dir tmp_file file_key matched line line_key
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')
    if [[ -z "$key" ]]; then
        echo_error "SyntaxError: expected 'autocomplete config set <key> <value>'"
        return 1
    fi
    if [[ ! -f "$config_file" ]]; then
        echo_error "Configuration file not found: $config_file. Run autocomplete install."
        return 1
    fi

    file_key=$(echo "$key" | tr '[:upper:]' '[:lower:]')
    _validate_config_value "$file_key" "$value" || return 1
    case "$file_key" in
        provider)
            value=$(_normalize_provider "$value") || return 1
            ;;
        request_headers_json|extra_body_json)
            value=$(_normalize_json "$value") || return 1
            ;;
    esac

    config_dir=$(dirname "$config_file")
    tmp_file=$(mktemp "$config_dir/.config.XXXXXX" 2>/dev/null) || {
        echo_error "Failed to create a temporary file for $config_file."
        return 1
    }
    if ! chmod 0600 "$tmp_file" 2>/dev/null; then
        rm -f "$tmp_file"
        echo_error "Failed to secure temporary configuration file."
        return 1
    fi

    matched=0
    if ! while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *:* ]]; then
            line_key="${line%%:*}"
            line_key=$(print -r -- "$line_key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            line_key="${(L)line_key}"
            if [[ "$line_key" == "$file_key" ]]; then
                print -r -- "$file_key: $value"
                matched=1
                continue
            fi
        fi
        print -r -- "$line"
    done < "$config_file" > "$tmp_file"; then
        rm -f "$tmp_file"
        echo_error "Failed to rewrite $config_file."
        return 1
    fi
    if (( matched == 0 )); then
        if ! print -r -- "$file_key: $value" >> "$tmp_file"; then
            rm -f "$tmp_file"
            echo_error "Failed to rewrite $config_file."
            return 1
        fi
    fi
    if ! mv -f "$tmp_file" "$config_file"; then
        rm -f "$tmp_file"
        echo_error "Failed to update $config_file."
        return 1
    fi
    acsh_load_config || return 1
    return 0
}

config_command() {
    local command config_file="$HOME/.autocomplete/config"
    command="${*:2}"
    if [ -z "$command" ]; then
        show_config
        return
    fi
    if [ "$2" = "set" ]; then
        local key="$3" value="$4"
        echo "Setting configuration key '$key' to '$value'"
        if set_config "$key" "$value"; then
            echo_green "Configuration updated. Run 'autocomplete config' to view changes."
            return 0
        fi
        return 1
    fi
    if [[ "$command" == "reset" ]]; then
        echo "Resetting configuration to default values."
        rm "$config_file" || true
        build_config
        return
    fi
    echo_error "SyntaxError: expected 'autocomplete config set <key> <value>' or 'autocomplete config reset'"
}

# Deterministic default config: run under umask 077, blank API-key fields
# (NEVER interpolate secrets), staged in the config dir and atomically renamed
# to ~/.autocomplete/config (mode 0600).
build_config() {
    local config_dir="$HOME/.autocomplete" config_file="$HOME/.autocomplete/config" default_config tmp_config
    if [ ! -f "$config_file" ]; then
        echo "Creating default configuration file at ~/.autocomplete/config"
        if [[ ! -d "$config_dir" ]]; then
            mkdir -p "$config_dir"
        fi
        default_config="# ~/.autocomplete/config

# API Keys (leave blank; resolved from the environment at runtime)
openai_api_key:
anthropic_api_key:
groq_api_key:
custom_api_key:
openai_compatible_api_key:

# Model configuration
provider: openai
model: gpt-4o
temperature: 0.0
endpoint: https://api.openai.com/v1/chat/completions
api_prompt_cost: 0.000005
api_completion_cost: 0.000015

# Context (opt-in; all disabled by default)
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

# Provider request settings
request_timeout_seconds: 5
request_headers_json: {}
extra_body_json: {}

# Cache settings
cache_dir: $HOME/.autocomplete/cache
cache_size: 10

# Logging settings
log_file: $HOME/.autocomplete/autocomplete.log"
        tmp_config=$(mktemp "$config_dir/.config.XXXXXX") 2>/dev/null || return 1
        ( umask 077
          printf '%s\n' "$default_config" > "$tmp_config" )
        chmod 0600 "$tmp_config" 2>/dev/null
        mv -f "$tmp_config" "$config_file" || { rm -f "$tmp_config"; return 1; }
        chmod 0600 "$config_file" 2>/dev/null
    fi
}

acsh_load_config() {
    local config_file="$HOME/.autocomplete/config" key value normalized_provider
    if [[ ! -f "$config_file" ]]; then
        echo_error "Configuration file not found: $config_file"
        return 1
    fi

    while IFS=':' read -r key value; do
        if [[ $key =~ ^# ]] || [[ -z $key ]]; then
            continue
        fi
        key=$(print -rn -- "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(print -rn -- "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        key=$(print -rn -- "$key" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')
        if [[ -n $value ]]; then
            export "ACSH_$key"="$value"
        fi
    done < "$config_file"

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
    if [[ -z "${ACSH_OPENAI_COMPATIBLE_API_KEY:-}" && -n "${OPENAI_COMPATIBLE_API_KEY:-}" ]]; then
        export ACSH_OPENAI_COMPATIBLE_API_KEY="$OPENAI_COMPATIBLE_API_KEY"
    fi
    if [[ -z "${ACSH_OLLAMA_API_KEY:-}" && -n "${ACSH_CUSTOM_API_KEY:-}" ]]; then
        export ACSH_OLLAMA_API_KEY="$ACSH_CUSTOM_API_KEY"
    fi

    normalized_provider=$(_normalize_provider "${ACSH_PROVIDER:-openai}") || return 1
    export ACSH_PROVIDER="$normalized_provider"
    _set_active_api_key "$normalized_provider" || return 1
    return 0
}

# Remove ONLY the managed startup block and the exact legacy lines this
# project previously emitted; every other line is preserved verbatim (lines
# merely CONTAINING "autocomplete" are untouched).
_acsh_strip_rc_block() {
    local line read_status has_newline in_block=0 index
    local -a buffered_lines=() buffered_newlines=()

    while true; do
        IFS= read -r line
        read_status=$?
        if (( read_status != 0 )) && [[ -z "$line" ]]; then
            break
        fi
        if (( read_status == 0 )); then
            has_newline=1
        else
            has_newline=0
        fi

        if (( in_block )); then
            buffered_lines+=("$line")
            buffered_newlines+=("$has_newline")
            if [[ "$line" == "# <<< autocomplete.sh <<<" ]]; then
                buffered_lines=()
                buffered_newlines=()
                in_block=0
            fi
        elif [[ "$line" == "# >>> autocomplete.sh >>>" ]]; then
            buffered_lines=("$line")
            buffered_newlines=("$has_newline")
            in_block=1
        else
            case "$line" in
                "# Autocomplete.sh"|"# Autocomplete.zsh"|"source autocomplete enable"|"# Autocomplete.sh CLI"|"# Autocomplete.zsh CLI"|"compdef _autocompletesh_cli autocomplete"|"complete -F _autocompletesh_cli autocomplete")
                    if (( read_status != 0 )); then
                        break
                    fi
                    continue
                    ;;
            esac
            print -rn -- "$line"
            (( has_newline )) && printf '\n'
        fi

        (( read_status != 0 )) && break
    done

    if (( in_block )); then
        for (( index = 1; index <= ${#buffered_lines[@]}; index++ )); do
            print -rn -- "${buffered_lines[$index]}"
            (( buffered_newlines[$index] )) && printf '\n'
        done
    fi
    return 0
}

# Writes EXACTLY ONE managed block (`# >>> autocomplete.sh >>>` ... source
# line ... `# <<< autocomplete.sh <<<`) to .zshrc. The block contains ONLY
# the shell-quoted source line (CLI completion registration lives in
# enable_command). A stale block and the old legacy lines are removed first;
# the startup file is backed up once and rewritten via same-directory temp +
# atomic rename preserving mode. Uses ACSH_SCRIPT_PATH, never `command -v`.
install_command() {
    local rc_file="$HOME/.zshrc" tmp_file orig_mode quoted_path
    if [[ -z "$ACSH_SCRIPT_PATH" || ! -f "$ACSH_SCRIPT_PATH" ]]; then
        echo_error "autocomplete.zsh script path not found ($ACSH_SCRIPT_PATH). Follow install instructions at https://github.com/closedloop-technologies/autocomplete-sh"
        return
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
    if [[ ! -f "$rc_file" ]]; then
        touch "$rc_file" 2>/dev/null || true
    fi
    # Back up the existing startup file once (never clobber an earlier backup).
    if [[ -f "$rc_file" && ! -f "$rc_file.autocomplete.bak" ]]; then
        cp -p "$rc_file" "$rc_file.autocomplete.bak"
    fi
    orig_mode=$(stat -c %a "$rc_file" 2>/dev/null || echo 644)
    tmp_file=$(mktemp "$(dirname "$rc_file")/.acsh-rc.XXXXXX") || return 1
    _acsh_strip_rc_block < "$rc_file" > "$tmp_file"
    quoted_path=${(q)ACSH_SCRIPT_PATH}
    printf '\n# >>> autocomplete.sh >>>\n' >> "$tmp_file"
    printf 'source %s enable\n' "$quoted_path" >> "$tmp_file"
    printf '# <<< autocomplete.sh <<<\n' >> "$tmp_file"
    chmod "$orig_mode" "$tmp_file" 2>/dev/null
    mv -f "$tmp_file" "$rc_file" || { rm -f "$tmp_file"; return 1; }
    echo
    echo_green "Autocomplete.zsh - Version $ACSH_VERSION installation complete."
    echo -e "Run: source $rc_file to enable autocomplete."
    echo -e "Then run: autocomplete model to select a language model."
}

# Unregisters the live plugin, then removes ONLY the managed block and exact
# legacy lines (preserving unrelated content), then the project config/cache/
# log paths; after confirmation (or -y) removes ONLY ACSH_SCRIPT_PATH.
remove_command() {
    local config_file="$HOME/.autocomplete/config" cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"} log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"} rc_file="$HOME/.zshrc"
    local tmp_file orig_mode confirm remove_script=0 arg
    echo_green "Removing Autocomplete.zsh installation..."
    disable_command
    if [ -f "$rc_file" ]; then
        tmp_file=$(mktemp "$(dirname "$rc_file")/.acsh-rc.XXXXXX") || return 1
        orig_mode=$(stat -c %a "$rc_file" 2>/dev/null || echo 644)
        _acsh_strip_rc_block < "$rc_file" > "$tmp_file"
        chmod "$orig_mode" "$tmp_file" 2>/dev/null
        mv -f "$tmp_file" "$rc_file" || { rm -f "$tmp_file"; return 1; }
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
    for arg in "$@"; do
        if [[ "$arg" == "-y" ]]; then
            remove_script=1
        fi
    done
    if [[ $remove_script -eq 0 && -n "${ACSH_SCRIPT_PATH:-}" && -f "$ACSH_SCRIPT_PATH" ]]; then
        print -n "Remove the autocomplete script ($ACSH_SCRIPT_PATH)? (y/n): "
        read confirm
        if [[ "$confirm" == "y" ]]; then
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

check_if_enabled() {
    [[ "${_comps[autocomplete]-}" == "_autocompletesh_cli" ]]
}

enable_command() {
    if check_if_enabled; then
        echo_green "Reloading Autocomplete.zsh..."
        disable_command
    fi
    acsh_load_config
    compdef _autocompletesh_cli autocomplete
}

disable_command() {
    if check_if_enabled; then
        compdef -d autocomplete
    fi
}

# Explicit AI entry point: joins the remaining args into `user_input`, then
# routes through _cached_completion with mode=command and cursor at end-of-
# line. `--dry-run` prints _build_prompt directly (network-free, no cache I/O).
command_command() {
    local dry_run=0 user_input="" arg
    shift
    for arg in "$@"; do
        if [[ "$arg" == "--dry-run" ]]; then
            dry_run=1
        elif [[ -n "$user_input" ]]; then
            user_input="$user_input $arg"
        else
            user_input="$arg"
        fi
    done
    if [[ -z "$user_input" ]]; then
        echo_error "command requires a command line argument"
        echo "Usage: autocomplete command [--dry-run] <line>..."
        return 1
    fi
    if [[ "$dry_run" -eq 1 ]]; then
        acsh_load_config || return 1
        _validate_runtime_config || return 1
        _build_prompt "command" "$user_input"
        return $?
    fi
    export ACSH_INPUT="$user_input"
    export ACSH_PROMPT=
    export ACSH_RESPONSE=
    local completions
    completions=$(_cached_completion "command" "$user_input" "${#user_input}")
    if [[ -z "$completions" ]]; then
        return 1
    fi
    export ACSH_RESPONSE="$completions"
    echo "$completions"
}

clear_command() {
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"} log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    echo "This will clear the cache and log file."
    echo -e "Cache directory: \e[31m$cache_dir\e[0m"
    echo -e "Log file: \e[31m$log_file\e[0m"
    print -n "Are you sure? (y/n): "
    read confirm
    if [[ $confirm != "y" ]]; then
        echo "Aborted."
        return
    fi
    if [ -d "$cache_dir" ]; then
        local cache_files
        cache_files=$(list_cache)
        if [[ -n "$cache_files" ]]; then
            while IFS= read -r line; do
                file=$(echo "$line" | cut -d ' ' -f 2-)
                rm "$file"
                echo "Removed: $file"
            done <<< "$cache_files"
            echo "Cleared cache in: $cache_dir"
        else
            echo "Cache is empty."
        fi
    fi
    [ -f "$log_file" ] && { rm "$log_file"; echo "Removed: $log_file"; }
}

usage_command() {
    local log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"} cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    local cache_size number_of_lines api_cost avg_api_cost
    cache_size=$(list_cache | wc -l)
    echo_green "Autocomplete.zsh - Usage Information"
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
            if (( i == selected )); then
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
                if (( selected < 0 )); then
                    selected=$((${#options[@]} - 1))
                fi
                ;;
            down)
                ((selected++))
                if (( selected >= ${#options[@]} )); then
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
    local selected_model selected_value selected_option requested_provider model_name
    local prompt_cost completion_cost provider provider_label user_api_key_input
    local model temperature rest config_value key
    local -a options=() sorted_keys
    if [[ $# -ne 3 ]]; then
        # In zsh, use a simple for-loop to build an array of sorted keys.
        sorted_keys=($(for key in ${(k)_autocomplete_modellist}; do echo "$key"; done | sort))
        for key in "${sorted_keys[@]}"; do
            options+=("$key")
        done
        echo -e "\e[1;32mAutocomplete.zsh - Model Configuration\e[0m"
        menu_selector "${options[@]}"
        selected_option=$?
        if [[ $selected_option -eq 1 ]]; then
            return
        fi
        selected_model="${options[selected_option]}"
        selected_value="${_autocomplete_modellist[$selected_model]}"
    else
        requested_provider="$2"
        model_name="$3"
        selected_value="${_autocomplete_modellist["$requested_provider:	$model_name"]}"
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

    provider="${(L)ACSH_PROVIDER}"
    provider_label="${(U)provider}"
    if [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]] && _provider_requires_api_key "$provider"; then
        echo -e "\e[34mSet ${provider_label}_API_KEY\e[0m"
        echo "Stored in ~/.autocomplete/config"
        if [[ "$provider" == "openai" ]]; then
            echo "Create a new one: https://platform.openai.com/settings/profile?tab=api-keys"
        elif [[ "$provider" == "anthropic" ]]; then
            echo "Create a new one: https://console.anthropic.com/settings/keys"
        elif [[ "$provider" == "groq" ]]; then
            echo "Create a new one: https://console.groq.com/keys"
        fi
        print -n "Enter your ${provider_label} API Key: "
        read -sr user_api_key_input < /dev/tty
        clear
        echo -e "\e[1;32mAutocomplete.zsh - Model Configuration\e[0m"
        if [[ -n "$user_api_key_input" ]]; then
            export ACSH_ACTIVE_API_KEY="$user_api_key_input"
            set_config "${provider//-/_}_api_key" "$user_api_key_input"
        fi
    fi
    model="${ACSH_MODEL:-ERROR}"
    temperature=$(echo "${ACSH_TEMPERATURE:-0.0}" | awk '{printf "%.3f", $1}')
    echo -e "Provider:\t\e[90m$provider\e[0m"
    echo -e "Model:\t\t\e[90m$model\e[0m"
    echo -e "Temperature:\t\e[90m$temperature\e[0m"
    echo
    echo -e "Cost/token:\t\e[90mprompt: \$$ACSH_API_PROMPT_COST, completion: \$$ACSH_API_COMPLETION_COST\e[0m"
    echo -e "Endpoint:\t\e[90m$ACSH_ENDPOINT\e[0m"
    echo -n "API Key:"
    if [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]]; then
        if _provider_requires_api_key "$provider"; then
            echo -e "\t\e[31mUNSET\e[0m"
        else
            echo -e "\t\e[90mOPTIONAL (unset)\e[0m"
        fi
    else
        rest=${ACSH_ACTIVE_API_KEY:4}
        config_value="${ACSH_ACTIVE_API_KEY:0:4}...${rest: -4}"
        echo -e "\t\e[32m$config_value\e[0m"
    fi
    if [[ -z "${ACSH_ACTIVE_API_KEY:-}" ]] && _provider_requires_api_key "$provider"; then
        echo "To set the API Key, run:"
        echo -e "\t\e[31mautocomplete config set api_key <your-api-key>\e[0m"
        echo -e "\t\e[31mexport ${provider_label}_API_KEY=<your-api-key>\e[0m"
    fi
    if [[ "$provider" == "openai-compatible" ]]; then
        echo "Configure an OpenAI-compatible endpoint and model:"
        echo -e "\t\e[34mautocomplete config set endpoint http://localhost:8080/v1/chat/completions\e[0m"
        echo -e "\t\e[34mautocomplete config set model your-model-name\e[0m"
        echo "Optional key (env: OPENAI_COMPATIBLE_API_KEY):"
        echo -e "\t\e[34mautocomplete config set openai_compatible_api_key <your-key>\e[0m"
        echo "Custom request headers / extra body (JSON, openai-compatible only):"
        echo -e "\t\e[34mautocomplete config set request_headers_json '{\"User-Agent\":\"my-app\"}'\e[0m"
        echo -e "\t\e[34mautocomplete config set extra_body_json '{\"max_tokens\":2048}'\e[0m"
    fi
    if [[ "$provider" == "ollama" ]]; then
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
    *)
        if [[ -n "${1:-}" ]]; then
            echo_error "Unknown command $1 - run 'autocomplete --help' for usage or visit https://autocomplete.sh"
        else
            echo_green "Autocomplete.zsh - LLM Powered Zsh Completion - Version $ACSH_VERSION - https://autocomplete.sh"
        fi
        ;;
esac
