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

error_exit() {
    echo -e "\e[31mAutocomplete.sh - $1\e[0m" >&2
    exit 1
}

echo_error() {
    echo -e "\e[31mAutocomplete.sh - $1\e[0m" >&2
}

echo_green() {
    echo -e "\e[32m$1\e[0m"
}

###############################################################################
#                      Global Variables & Model Definitions                   #
###############################################################################

export ACSH_VERSION=0.4.3

# Supported models defined in an associative array.
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
# Production Models
_autocomplete_modellist['groq:		llama3-8b-8192']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama3-8b-8192", "provider": "groq" }'
_autocomplete_modellist['groq:		llama3-70b-8192']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama3-70b-8192", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.3-70b-versatile']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.3-70b-versatile", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-3.1-8b-instant']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-3.1-8b-instant", "provider": "groq" }'
_autocomplete_modellist['groq:		llama-guard-3-8b']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "llama-guard-3-8b", "provider": "groq" }'
_autocomplete_modellist['groq:		mixtral-8x7b-32768']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "mixtral-8x7b-32768", "provider": "groq" }'
_autocomplete_modellist['groq:		gemma2-9b-it']='{ "completion_cost":0.0000000, "prompt_cost":0.0000000, "endpoint": "https://api.groq.com/openai/v1/chat/completions", "model": "gemma2-9b-it", "provider": "groq" }'
# Groq models
# Preview Models
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
 * Hostname: \$HOSTNAME=$HOSTNAME"
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
    echo "BASH_VERSION: $BASH_VERSION"
    echo "BASH_COMPLETION_VERSINFO: ${BASH_COMPLETION_VERSINFO}"
    echo
    echo "## Terminal Information"
    _get_terminal_info
}

_completion_vars() {
    echo "BASH_COMPLETION_VERSINFO: ${BASH_COMPLETION_VERSINFO}"
    echo "COMP_CWORD: ${COMP_CWORD}"
    echo "COMP_KEY: ${COMP_KEY}"
    echo "COMP_LINE: ${COMP_LINE}"
    echo "COMP_POINT: ${COMP_POINT}"
    echo "COMP_TYPE: ${COMP_TYPE}"
    echo "COMP_WORDBREAKS: ${COMP_WORDBREAKS}"
    echo "COMP_WORDS: ${COMP_WORDS[*]}"
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
    local HISTORY_LIMIT=${ACSH_MAX_HISTORY_COMMANDS:-20}
    history | tail -n "$HISTORY_LIMIT"
}

# Refined sanitization: only replace long hex sequences, UUIDs, and API-key–like tokens.
_get_clean_command_history() {
    local recent_history
    recent_history=$(_get_command_history)
    recent_history=$(echo "$recent_history" | sed -E 's/\b[[:xdigit:]]{32,40}\b/REDACTED_HASH/g')
    recent_history=$(echo "$recent_history" | sed -E 's/\b[0-9a-fA-F-]{36}\b/REDACTED_UUID/g')
    recent_history=$(echo "$recent_history" | sed -E 's/\b[A-Za-z0-9]{16,40}\b/REDACTED_APIKEY/g')
    echo "$recent_history"
}

_get_recent_files() {
    local FILE_LIMIT=${ACSH_MAX_RECENT_FILES:-20}
    find . -maxdepth 1 -type f -exec ls -ld {} + | sort -r | head -n "$FILE_LIMIT"
}

_get_help_message() {
    local COMMAND HELP_INFO
    COMMAND=$(echo "$1" | awk '{print $1}')
    HELP_INFO=""
    {
        set +e
        HELP_INFO=$($COMMAND --help 2>&1 || true)
        set -e
    } || HELP_INFO="Error: '$COMMAND --help' not available"
    echo "$HELP_INFO"
}

_build_prompt() {
    local user_input command_history terminal_context help_message recent_files output_instructions other_environment_variables prompt
    user_input="$*"
    command_history=$(_get_clean_command_history)
    terminal_context=$(_get_terminal_info)
    help_message=$(_get_help_message "$user_input")
    recent_files=$(_get_recent_files)
    output_instructions=$(_get_output_instructions)
    other_environment_variables=$(env | grep '=' | grep -v 'ACSH_' | awk -F= '{print $1}' | grep -v 'PWD\|OSTYPE\|BASH\|USER\|HOME\|TERM\|OLDPWD\|HOSTNAME')
    
    prompt="User command: \`$user_input\`

# Terminal Context
## Environment variables
$terminal_context

Other defined environment variables
\`\`\`
$other_environment_variables
\`\`\`

## History
Recently run commands (some information redacted):
\`\`\`
$command_history
\`\`\`

## File system
Most recently modified files:
\`\`\`
$recent_files
\`\`\`

## Help Information
$help_message

# Instructions
$output_instructions
"
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
    local user_input prompt system_message_prompt payload acsh_prompt
    local model temperature
    model="${ACSH_MODEL:-gpt-4o}"
    temperature="${ACSH_TEMPERATURE:-0.0}"

    user_input="$1"
    prompt=$(_build_prompt "$@")
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

    case "${ACSH_PROVIDER^^}" in
        "ANTHROPIC")
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
        "GROQ")
            payload=$(echo "$base_payload" | jq '. + {response_format: {type: "json_object"}}')
            ;;
        "OLLAMA")
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
    local prompt_tokens_int completion_tokens_int
    user_input="$1"
    response_body="$2"
    user_input_hash=$(echo -n "$user_input" | md5sum | cut -d ' ' -f 1)

    if [[ "${ACSH_PROVIDER^^}" == "ANTHROPIC" ]]; then
        prompt_tokens=$(echo "$response_body" | jq -r '.usage.input_tokens')
        prompt_tokens_int=$((prompt_tokens))
        completion_tokens=$(echo "$response_body" | jq -r '.usage.output_tokens')
        completion_tokens_int=$((completion_tokens))
    else
        prompt_tokens=$(echo "$response_body" | jq -r '.usage.prompt_tokens')
        prompt_tokens_int=$((prompt_tokens))
        completion_tokens=$(echo "$response_body" | jq -r '.usage.completion_tokens')
        completion_tokens_int=$((completion_tokens))
    fi

    created=$(date +%s)
    created=$(echo "$response_body" | jq -r ".created // $created")
    api_cost=$(echo "$prompt_tokens_int * $ACSH_API_PROMPT_COST + $completion_tokens_int * $ACSH_API_COMPLETION_COST" | bc)
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    echo "$created,$user_input_hash,$prompt_tokens_int,$completion_tokens_int,$api_cost" >> "$log_file"
}

openai_completion() {
    local content status_code response_body default_user_input user_input api_key payload endpoint timeout attempt max_attempts
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}
    timeout=${ACSH_TIMEOUT:-30}
    default_user_input="Write two to six most likely commands given the provided information"
    user_input=${*:-$default_user_input}

    if [[ -z "$ACSH_ACTIVE_API_KEY" && ${ACSH_PROVIDER^^} != "OLLAMA" ]]; then
        error_exit "ACSH_ACTIVE_API_KEY not set. Please set it with: export ${ACSH_PROVIDER^^}_API_KEY=<your-api-key>"
    fi
    api_key="${ACSH_ACTIVE_API_KEY:-$OPENAI_API_KEY}"
    payload=$(_build_payload "$user_input")
    
    max_attempts=2
    attempt=1
    while [ $attempt -le $max_attempts ]; do
        if [[ "${ACSH_PROVIDER^^}" == "ANTHROPIC" ]]; then
            response=$(curl -s -m "$timeout" -w "\n%{http_code}" "$endpoint" \
                -H "content-type: application/json" \
                -H "anthropic-version: 2023-06-01" \
                -H "x-api-key: $api_key" \
                --data "$payload")
        elif [[ "${ACSH_PROVIDER^^}" == "OLLAMA" ]]; then
            response=$(curl -s -m "$timeout" -w "\n%{http_code}" "$endpoint" --data "$payload")
        else
            response=$(curl -s -m "$timeout" -w "\n%{http_code}" "$endpoint" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $api_key" \
                -d "$payload")
        fi
        status_code=$(echo "$response" | tail -n1)
        response_body=$(echo "$response" | sed '$d')
        if [[ $status_code -eq 200 ]]; then
            break
        else
            echo_error "API call failed with status $status_code. Retrying... (Attempt $attempt of $max_attempts)"
            sleep 1
            attempt=$((attempt+1))
        fi
    done

    if [[ $status_code -ne 200 ]]; then
        case $status_code in
            400) echo_error "Bad Request: The API request was invalid or malformed." ;;
            401) echo_error "Unauthorized: The provided API key is invalid or missing." ;;
            429) echo_error "Too Many Requests: The API rate limit has been exceeded." ;;
            500) echo_error "Internal Server Error: An unexpected error occurred on the API server." ;;
            *) echo_error "Unknown Error: Unexpected status code $status_code received. Response: $response_body" ;;
        esac
        return
    fi

    if [[ "${ACSH_PROVIDER^^}" == "ANTHROPIC" ]]; then
        content=$(echo "$response_body" | jq -r '.content[0].input.commands')
    elif [[ "${ACSH_PROVIDER^^}" == "GROQ" ]]; then
        content=$(echo "$response_body" | jq -r '.choices[0].message.content')
        content=$(echo "$content" | jq -r '.completions')
    elif [[ "${ACSH_PROVIDER^^}" == "OLLAMA" ]]; then
        content=$(echo "$response_body" | jq -r '.message.content')
        content=$(echo "$content" | jq -r '.completions')
    else
        content=$(echo "$response_body" | jq -r '.choices[0].message.tool_calls[0].function.arguments')
        content=$(echo "$content" | jq -r '.commands')
    fi

    local completions
    completions=$(echo "$content" | jq -r '.[]' | grep -v '^$')
    echo -n "$completions"
    log_request "$user_input" "$response_body"
}

###############################################################################
#                        Completion Functions                                 #
###############################################################################

_get_default_completion_function() {
    local cmd="$1"
    complete -p "$cmd" 2>/dev/null | awk -F' ' '{ for(i=1;i<=NF;i++) { if ($i ~ /^-F$/) { print $(i+1); exit; } } }'
}

_default_completion() {
    local current_word="" first_word="" default_func
    if [[ -n "${COMP_WORDS[*]}" ]]; then
        first_word="${COMP_WORDS[0]}"
        if [[ -n "$COMP_CWORD" && "$COMP_CWORD" -lt "${#COMP_WORDS[@]}" ]]; then
            current_word="${COMP_WORDS[COMP_CWORD]}"
        fi
    fi

    default_func=$(_get_default_completion_function "$first_word")
    if [[ -n "$default_func" ]]; then
        "$default_func"
    else
        local file_completions
        if [[ -z "$current_word" ]]; then
            file_completions=$(compgen -f -- || true)
        else
            file_completions=$(compgen -f -- "$current_word" || true)
        fi
        if [[ -n "$file_completions" ]]; then
            readarray -t COMPREPLY <<<"$file_completions"
        fi
    fi
}

list_cache() {
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    find "$cache_dir" -maxdepth 1 -type f -name "acsh-*" -printf '%T+ %p\n' | sort
}

_autocompletesh() {
    _init_completion || return
    _default_completion
    if [[ ${#COMPREPLY[@]} -eq 0 && $COMP_TYPE -eq 63 ]]; then
        local completions user_input user_input_hash
        acsh_load_config
        if [[ -z "$ACSH_ACTIVE_API_KEY" && ${ACSH_PROVIDER^^} != "OLLAMA" ]]; then
            local provider_key="${ACSH_PROVIDER:-openai}_API_KEY"
            provider_key=$(echo "$provider_key" | tr '[:lower:]' '[:upper:]')
            echo_error "${provider_key} is not set. Please set it using: export ${provider_key}=<your-api-key> or disable autocomplete via: autocomplete disable"
            echo
            return
        fi
        if [[ -n "${COMP_WORDS[*]}" ]]; then
            command="${COMP_WORDS[0]}"
            if [[ -n "$COMP_CWORD" && "$COMP_CWORD" -lt "${#COMP_WORDS[@]}" ]]; then
                current="${COMP_WORDS[COMP_CWORD]}"
            fi
        fi
        user_input="${COMP_LINE:-"$command $current"}"
        user_input_hash=$(echo -n "$user_input" | md5sum | cut -d ' ' -f 1)
        export ACSH_INPUT="$user_input"
        export ACSH_PROMPT=
        export ACSH_RESPONSE=
        local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
        local cache_size=${ACSH_CACHE_SIZE:-100}
        local cache_file="$cache_dir/acsh-$user_input_hash.txt"
        if [[ -d "$cache_dir" && "$cache_size" -gt 0 && -f "$cache_file" ]]; then
            completions=$(cat "$cache_file" || true)
            touch "$cache_file"
        else
            echo -en "\e]12;green\a"
            completions=$(openai_completion "$user_input" || true)
            if [[ -z "$completions" ]]; then
                echo -en "\e]12;red\a"
                sleep 1
                completions=$(openai_completion "$user_input" || true)
            fi
            echo -en "\e]12;white\a"
            if [[ -d "$cache_dir" && "$cache_size" -gt 0 ]]; then
                echo "$completions" > "$cache_file"
                while [[ $(list_cache | wc -l) -gt "$cache_size" ]]; do
                    oldest=$(list_cache | head -n 1 | cut -d ' ' -f 2-)
                    rm "$oldest" || true
                done
            fi
        fi
        export ACSH_RESPONSE=$completions
        if [[ -n "$completions" ]]; then
            local num_rows
            num_rows=$(echo "$completions" | wc -l)
            COMPREPLY=()
            if [[ $num_rows -eq 1 ]]; then
                readarray -t COMPREPLY <<<"$(echo -n "${completions}" | sed "s/${command}[[:space:]]*//" | sed 's/:/\\:/g')"
            else
                completions=$(echo "$completions" | awk '{print NR". "$0}')
                readarray -t COMPREPLY <<< "$completions"
            fi
        fi
        if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
            COMPREPLY=("$current")
        fi
    fi
}

###############################################################################
#                     CLI Commands & Configuration Management                 #
###############################################################################

show_help() {
    echo_green "Autocomplete.sh - LLM Powered Bash Completion"
    echo "Usage: autocomplete [options] command"
    echo "       autocomplete [options] install|remove|config|model|enable|disable|clear|usage|system|command|--help"
    echo
    echo "Autocomplete.sh enhances bash completion with LLM capabilities."
    echo "Press Tab twice for suggestions."
    echo "Commands:"
    echo "  command             Run autocomplete (simulate double Tab)"
    echo "  command --dry-run   Show prompt without executing"
    echo "  model               Change language model"
    echo "  usage               Display usage stats"
    echo "  system              Display system information"
    echo "  config              Show or set configuration values"
    echo "    config set <key> <value>  Set a config value"
    echo "    config reset             Reset config to defaults"
    echo "  install             Install autocomplete to .bashrc"
    echo "  remove              Remove installation from .bashrc"
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
    echo_green "Autocomplete.sh - Configuration and Settings - Version $ACSH_VERSION"
    if is_subshell; then
        echo "  STATUS: Unknown. Run 'source autocomplete config' to check status."
        return
    elif check_if_enabled; then
        echo -e "  STATUS: \033[32;5mEnabled\033[0m"
    else
        echo -e "  STATUS: \033[31;5mDisabled\033[0m - Run 'source autocomplete config' to verify."
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
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')
    if [ -z "$key" ]; then
        echo_error "SyntaxError: expected 'autocomplete config set <key> <value>'"
        return
    fi
    if [ ! -f "$config_file" ]; then
        echo_error "Configuration file not found: $config_file. Run autocomplete install."
        return
    fi
    sed -i "s|^\($key:\).*|\1 $value|" "$config_file"
    acsh_load_config
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
        set_config "$key" "$value"
        echo_green "Configuration updated. Run 'autocomplete config' to view changes."
        return
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
    local config_file="$HOME/.autocomplete/config" default_config
    if [ ! -f "$config_file" ]; then
        echo "Creating default configuration file at ~/.autocomplete/config"
        default_config="# ~/.autocomplete/config

# OpenAI API Key
openai_api_key: $OPENAI_API_KEY

# Anthropic API Key
anthropic_api_key: $ANTHROPIC_API_KEY

# Groq API Key
groq_api_key: $GROQ_API_KEY

# Custom API Key for Ollama
custom_api_key: $LLM_API_KEY

# Model configuration
provider: openai
model: gpt-4o
temperature: 0.0
endpoint: https://api.openai.com/v1/chat/completions
api_prompt_cost: 0.000005
api_completion_cost: 0.000015

# Max history and recent files
max_history_commands: 20
max_recent_files: 20

# Cache settings
cache_dir: $HOME/.autocomplete/cache
cache_size: 10

# Logging settings
log_file: $HOME/.autocomplete/autocomplete.log"
        echo "$default_config" > "$config_file"
    fi
}

acsh_load_config() {
    local config_file="$HOME/.autocomplete/config" key value
    if [ -f "$config_file" ]; then
        while IFS=':' read -r key value; do
            if [[ $key =~ ^# ]] || [[ -z $key ]]; then
                continue
            fi
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            key=$(echo "$key" | tr '[:lower:]' '[:upper:]' | sed 's/[^A-Z0-9]/_/g')
            if [[ -n $value ]]; then
                export "ACSH_$key"="$value"
            fi
        done < "$config_file"
        if [[ -z "$ACSH_OPENAI_API_KEY" && -n "$OPENAI_API_KEY" ]]; then
            export ACSH_OPENAI_API_KEY="$OPENAI_API_KEY"
        fi
        if [[ -z "$ACSH_ANTHROPIC_API_KEY" && -n "$ANTHROPIC_API_KEY" ]]; then
            export ACSH_ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY"
        fi
        if [[ -z "$ACSH_GROQ_API_KEY" && -n "$GROQ_API_KEY" ]]; then
            export ACSH_GROQ_API_KEY="$GROQ_API_KEY"
        fi
        if [[ -z "$ACSH_OLLAMA_API_KEY" && -n "$LLM_API_KEY" ]]; then
            export ACSH_OLLAMA_API_KEY="$LLM_API_KEY"
        fi
        case "${ACSH_PROVIDER:-openai}" in
            "openai") export ACSH_ACTIVE_API_KEY="$ACSH_OPENAI_API_KEY" ;;
            "anthropic") export ACSH_ACTIVE_API_KEY="$ACSH_ANTHROPIC_API_KEY" ;;
            "groq") export ACSH_ACTIVE_API_KEY="$ACSH_GROQ_API_KEY" ;;
            "ollama") export ACSH_ACTIVE_API_KEY="$ACSH_OLLAMA_API_KEY" ;;
            *) error_exit "Unknown provider: $ACSH_PROVIDER" ;;
        esac
    else
        echo "Configuration file not found: $config_file"
    fi
}

install_command() {
    local bashrc_file="$HOME/.bashrc" autocomplete_setup="source autocomplete enable" autocomplete_cli_setup="complete -F _autocompletesh_cli autocomplete"
    if ! command -v autocomplete &>/dev/null; then
        echo_error "autocomplete.sh not in PATH. Follow install instructions at https://github.com/closedloop-technologies/autocomplete-sh"
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
    if ! grep -qF "$autocomplete_setup" "$bashrc_file"; then
        echo -e "# Autocomplete.sh" >> "$bashrc_file"
        echo -e "$autocomplete_setup\n" >> "$bashrc_file"
        echo "Added autocomplete.sh setup to $bashrc_file"
    else
        echo "Autocomplete.sh setup already exists in $bashrc_file"
    fi
    if ! grep -qF "$autocomplete_cli_setup" "$bashrc_file"; then
        echo -e "# Autocomplete.sh CLI" >> "$bashrc_file"
        echo -e "$autocomplete_cli_setup\n" >> "$bashrc_file"
        echo "Added autocomplete CLI completion to $bashrc_file"
    fi
    echo
    echo_green "Autocomplete.sh - Version $ACSH_VERSION installation complete."
    echo -e "Run: source $bashrc_file to enable autocomplete."
    echo -e "Then run: autocomplete model to select a language model."
}

remove_command() {
    local config_file="$HOME/.autocomplete/config" cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"} log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"} bashrc_file="$HOME/.bashrc"
    echo_green "Removing Autocomplete.sh installation..."
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
    if [ -f "$bashrc_file" ]; then
        if grep -qF "source autocomplete enable" "$bashrc_file"; then
            sed -i '/# Autocomplete.sh/d' "$bashrc_file"
            sed -i '/autocomplete/d' "$bashrc_file"
            echo "Removed autocomplete.sh setup from $bashrc_file"
        fi
    fi
    local autocomplete_script
    autocomplete_script=$(command -v autocomplete)
    if [ -n "$autocomplete_script" ]; then
        echo "Autocomplete script is at: $autocomplete_script"
        read -r -p "Remove the autocomplete script? (y/n): " confirm
        if [[ $confirm == "y" ]]; then
            rm "$autocomplete_script"
            echo "Removed: $autocomplete_script"
        fi
    fi
    echo "Uninstallation complete."
}

check_if_enabled() {
    local is_enabled
    is_enabled=$(complete -p | grep _autocompletesh | grep -cv _autocompletesh_cli)
    (( is_enabled > 0 )) && return 0 || return 1
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
model
--help"
    fi
}

enable_command() {
    if check_if_enabled; then
        echo_green "Reloading Autocomplete.sh..."
        disable_command
    fi
    acsh_load_config
    complete -D -E -F _autocompletesh -o nospace
}

disable_command() {
    if check_if_enabled; then
        complete -F _completion_loader -D
    fi
}

command_command() {
    local args=("$@")
    for ((i = 0; i < ${#args[@]}; i++)); do
        if [ "${args[i]}" == "--dry-run" ]; then
            args[i]=""
            _build_prompt "${args[@]}"
            return
        fi
    done
    openai_completion "$@" || true
    echo
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
    if [[ -z "$ACSH_ACTIVE_API_KEY" && ${ACSH_PROVIDER^^} != "OLLAMA" ]]; then
        echo -e "\e[34mSet ${ACSH_PROVIDER^^}_API_KEY\e[0m"
        echo "Stored in ~/.autocomplete/config"
        if [[ ${ACSH_PROVIDER^^} == "OPENAI" ]]; then
            echo "Create a new one: https://platform.openai.com/settings/profile?tab=api-keys"
        elif [[ ${ACSH_PROVIDER^^} == "ANTHROPIC" ]]; then
            echo "Create a new one: https://console.anthropic.com/settings/keys"
        elif [[ ${ACSH_PROVIDER^^} == "GROQ" ]]; then
            echo "Create a new one: https://console.groq.com/keys"
        fi
        echo -n "Enter your ${ACSH_PROVIDER^^} API Key: "
        read -sr user_api_key_input < /dev/tty
        clear
        echo -e "\e[1;32mAutocomplete.sh - Model Configuration\e[0m"
        if [[ -n "$user_api_key_input" ]]; then
            export ACSH_ACTIVE_API_KEY="$user_api_key_input"
            set_config "${ACSH_PROVIDER,,}_api_key" "$user_api_key_input"
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
    if [[ -z $ACSH_ACTIVE_API_KEY ]]; then
        if [[ ${ACSH_PROVIDER^^} == "OLLAMA" ]]; then
            echo -e "\t\e[90mNot Used\e[0m"
        else
            echo -e "\t\e[31mUNSET\e[0m"
        fi
    else
        rest=${ACSH_ACTIVE_API_KEY:4}
        config_value="${ACSH_ACTIVE_API_KEY:0:4}...${rest: -4}"
        echo -e "\t\e[32m$config_value\e[0m"
    fi
    if [[ -z $ACSH_ACTIVE_API_KEY && ${ACSH_PROVIDER^^} != "OLLAMA" ]]; then
        echo "To set the API Key, run:"
        echo -e "\t\e[31mautocomplete config set api_key <your-api-key>\e[0m"
        echo -e "\t\e[31mexport ${ACSH_PROVIDER^^}_API_KEY=<your-api-key>\e[0m"
    fi
    if [[ ${ACSH_PROVIDER^^} == "OLLAMA" ]]; then
        echo "To set a custom endpoint:"
        echo -e "\t\e[34mautocomplete config set endpoint <your-url>\e[0m"
        echo "Other models can be set with:"
        echo -e "\t\e[34mautocomplete config set model <model-name>\e[0m"
    fi
    echo "To change temperature:"
    echo -e "\t\e[90mautocomplete config set temperature <temperature>\e[0m"
    echo
}

###############################################################################
#                              CLI ENTRY POINT                                #
###############################################################################

case "$1" in
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
        if [[ -n "$1" ]]; then
            echo_error "Unknown command $1 - run 'autocomplete --help' for usage or visit https://autocomplete.sh"
        else
            echo_green "Autocomplete.sh - LLM Powered Bash Completion - Version $ACSH_VERSION - https://autocomplete.sh"
        fi
        ;;
esac
