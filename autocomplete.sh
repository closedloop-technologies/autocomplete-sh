#!/bin/bash

# Autocomplete.sh - LLM Powered Bash Completion

# This script provides bash completion suggestions using the OpenAI API.
# MIT License - ClosedLoop Technologies, Inc.
# Sean Kruzel 2024

# Do not use `set -euo pipefail` or similar because this a
# bash completion script and it will change the behavior of the shell invoking it

export ACSH_VERSION=0.3.0

###############################################################################
#
# SUPPORTED MODELS AND MODEL PRICING
#
###############################################################################

declare -A _autocomplete_modellist
# https://openai.com/api/pricing/

_autocomplete_modellist['openai:\tgpt-4o']='{            "completion_cost":0.0000150,"prompt_cost":0.0000050,"endpoint":"https://api.openai.com/v1/chat/completions","model":"gpt-4o",             "provider":"openai"}'
_autocomplete_modellist['openai:\tgpt-3.5-turbo-0125']='{"completion_cost":0.0000015,"prompt_cost":0.0000005,"endpoint":"https://api.openai.com/v1/chat/completions","model":"gpt-3.5-turbo-0125", "provider":"openai"}'
# https://docs.anthropic.com/en/docs/about-claude/models
_autocomplete_modellist['anthropic:\tclaude-3-5-sonnet-20240620']='{"completion_cost":0.0000150,"prompt_cost":0.0000030,"endpoint":"https://api.anthropic.com/v1/messages","model":"claude-3-5-sonnet-20240620", "provider":"anthropic"}'
_autocomplete_modellist['anthropic:\tclaude-3-opus-20240229']='{    "completion_cost":0.0000750,"prompt_cost":0.0000150,"endpoint":"https://api.anthropic.com/v1/messages","model":"claude-3-opus-20240229", "provider":"anthropic"}'
_autocomplete_modellist['anthropic:\tclaude-3-haiku-20240307']='{   "completion_cost":0.00000125,"prompt_cost":0.00000025,"endpoint":"https://api.anthropic.com/v1/messages","model":"claude-3-haiku-20240307", "provider":"anthropic"}'

# https://console.groq.com/docs/models
_autocomplete_modellist['groq:\t\tllama3-8b-8192']='{  "completion_cost":0.0000000,"prompt_cost":0.0000000,"endpoint":"https://api.groq.com/openai/v1/chat/completions",                       "model":"llama3-8b-8192",     "provider":"groq"}'
_autocomplete_modellist['groq:\t\tllama3-70b-8192']='{ "completion_cost":0.0000000,"prompt_cost":0.0000000,"endpoint":"https://api.groq.com/openai/v1/chat/completions",                       "model":"llama3-70b-8192",    "provider":"groq"}'
_autocomplete_modellist['groq:\t\tmixtral-8x7b-32768']='{                    "completion_cost":0.0000000,"prompt_cost":0.0000000,"endpoint":"https://api.groq.com/openai/v1/chat/completions", "model":"mixtral-8x7b-32768", "provider":"groq"}'
_autocomplete_modellist['groq:\t\tgemma-7b-it']='{                           "completion_cost":0.0000000,"prompt_cost":0.0000000,"endpoint":"https://api.groq.com/openai/v1/chat/completions", "model":"gemma-7b-it",        "provider":"groq"}'
_autocomplete_modellist['groq:\t\tgemma2-9b-it']='{                          "completion_cost":0.0000000,"prompt_cost":0.0000000,"endpoint":"https://api.groq.com/openai/v1/chat/completions", "model":"gemma2-9b-it",       "provider":"groq"}'

# https://github.com/ollama/ollama/tree/main?tab=readme-ov-file#model-library
_autocomplete_modellist['ollama:\tcodellama']='{                          "completion_cost":0.0000000,"prompt_cost":0.0000000,"endpoint":"http://localhost:11434/api/chat",                        "model":"codellama", "provider":"ollama"}'

###############################################################################
#
# FORMATTING FUNCTIONS
#
###############################################################################

echo_error() {
	echo -e "\e[31mAutocomplete.sh - $1\e[0m" >&2
}

echo_green() {
	echo -e "\e[32m$1\e[0m"
}

###############################################################################
#
# SYSTEM INFORMATION FUNCTIONS
#
###############################################################################

# Check if jq is installed
if ! command -v jq &>/dev/null; then
	echo_error "jq is not installed. Please install it using the following command: \`sudo apt-get install jq\`"
fi

_get_terminal_info() {
	local terminal_info=" * User name: \$USER=$USER
 * Current directory: \$PWD=$PWD
 * Previous directory: \$OLDPWD=$OLDPWD
 * Home directory: \$HOME=$HOME
 * Operating system: \$OSTYPE=$OSTYPE
 * Shell: \$BASH=$BASH
 * Terminal type: \$TERM=$TERM
 * Hostname: \$HOSTNAME=$HOSTNAME
"
	echo "$terminal_info"
}

# Generate a unique machine signature based on the hash of the uname and user
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
#
# LARGE LANGUAGE MODEL COMPLETION FUNCTIONS
#
###############################################################################

_get_system_message_prompt() {
	echo "You are a helpful bash_completion script. \
Generate relevant and concise auto-complete suggestion for the given user command \
in the context of the current directory, operating system, command history, \
and environment variables. \

The output must be a list of two to five possible completions or rewritten commands. \
Each command must be on a new line and must not span multiple lines. \
Each must be a valid command or set of commands. \
Please focus on the user's intent, recent commands, and the current environment when \
brainstorming completions. \
The output must not contain any backticks or quotes such as \`command\` or \"command\".
"
}

_get_output_instructions() {
	echo "Provide a list of suggested completions or commands that could be run in the terminal.
YOU MUST provide a list of two to five possible completions or rewritten commands here
DO NOT wrap the commands in backticks or quotes such as \`command\` or \"command\" or \`\`\`command\`\`\`
Each must be a valid command or set of commands somehow chained together that could be run in the terminal
Please focus on the user's intent, recent commands, and the current environment when brainstorming completions.
Take a deep breath. You got this!
RETURN A JSON OBJECT WITH THE COMPLETIONS"
}


_get_command_history() {
	local HISTORY_LIMIT
    HISTORY_LIMIT=${ACSH_MAX_HISTORY_COMMANDS:-20}
	history | tail -n "$HISTORY_LIMIT"
}

# Find and replace sensitive information in the command history
_get_clean_command_history() {
    # Note: The following regex patterns are not exhaustive and may need to be updated
    local recent_history
    recent_history=$(_get_command_history)
    recent_history=$(echo "$recent_history" | sed -E 's/:[[:xdigit:]]\{36,40\}/REDACTED_HASH/' )
    recent_history="${recent_history//[A-Za-z0-9-]\{36\}/REDACTED_UUID}"
    recent_history="${recent_history//[A-Za-z0-9]\{16,40\}/REDACTED_APIKEY}"
    echo -e "$recent_history"
}
# Get the last 20 commands from the bash history
# GOTCHA: The history only populate if you run the command in the same terminal.  If you run it
# in a ./autocomplete_api.sh, it will not be populated since that runs in a different environment
# Functions which help preserve user privacy by sanitizing user data

_get_recent_files() {
	local FILE_LIMIT
    FILE_LIMIT=${ACSH_MAX_RECENT_FILES:-20}
	find . -maxdepth 1 -type f -exec ls -ld {} + | sort -r | head -n "$FILE_LIMIT"
}

# Attempts to get the help message for a given command
_get_help_message() {
	# Extract the first word from the user input
	local COMMAND HELP_INFO
	COMMAND=$(echo "$1" | awk '{print $1}')

	# Attempt to capture the help information
	HELP_INFO=""
	{
		set +e
		HELP_INFO=$(
			cat <<EOF
    $($COMMAND --help 2>&1 || true)
EOF
		)
		set -e
	} || HELP_INFO="\`$COMMAND --help\` not available"
	echo "$HELP_INFO"
}

# Constructs a LLM prompt with the user input and in-terminal contextual information
_build_prompt() {
	# Define contextual information for the completion request
	local user_input command_history terminal_context help_message recent_files output_instructions other_environment_variables prompt
	user_input="$*"
	command_history=$(_get_clean_command_history)
	terminal_context=$(_get_terminal_info)
	help_message=$(_get_help_message "$user_input")
	recent_files=$(_get_recent_files)
	output_instructions=$(_get_output_instructions)

	# compgen lists environmental variables without the
    other_environment_variables=$(env | grep '=' | grep -v 'ACSH_' | awk -F= '{print $1}' | grep -v 'PWD|OSTYPE|BASH|USER|HOME|TERM|OLDPWD|HOSTNAME')

	prompt="User command: \`$user_input\`

# Terminal Context
## Environment variables
$terminal_context

Other defined environment variables
\`\`\`
$other_environment_variables
\`\`\`

## History
Recently run commands (in order) - Note some information is REDACTED
\`\`\`
$command_history
\`\`\`

## File system
Most recently modified files in the current directory:
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

# Constructs the payload for the OpenAI API request
_build_payload() {
	local user_input prompt system_message_prompt payload acsh_prompt
    local model temperature
    model="${ACSH_MODEL:-"gpt-4o"}"
    temperature=${ACSH_TEMPERATURE:-0.0}

	user_input="$1"
	prompt=$(_build_prompt "$@")
	system_message_prompt=$(_get_system_message_prompt)

	# EXPORT PROMPT TO #ACSH_PROMPT
	acsh_prompt="# SYSTEM PROMPT\n"
	acsh_prompt+=$system_message_prompt
	acsh_prompt+="\n# USER MESSAGE\n"
	acsh_prompt+=$prompt
	export ACSH_PROMPT=$acsh_prompt

    if [[ ${ACSH_PROVIDER^^} == "ANTHROPIC" ]]; then
        payload=$(jq -cn --arg model "$model" --arg temperature "$temperature" --arg system_prompt "$system_message_prompt" --arg prompt_content "$prompt" '{
        model: $model,
        system: $system_prompt,
        messages: [
            {role: "user", content: $prompt_content}
        ],
        temperature: ($temperature | tonumber),
        "max_tokens": 1024,
        tool_choice: {"type": "tool", "name": "bash_completions"},
        tools:[
            {
                "name": "bash_completions",
                "description": "syntacticly correct command-line suggestions based on the users input",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "commands": {
                            "type": "array",
                            "items": {
                                "type": "string",
                                "description": "A suggested command"
                            }
                        },
                    },
                    "required": ["commands"],
                },
            }
        ]
        }')
    elif [[ ${ACSH_PROVIDER^^} == "GROQ" ]]; then
        payload=$(jq -cn --arg model "$model" --arg temperature "$temperature" --arg system_prompt "$system_message_prompt" --arg prompt_content "$prompt" '{
            model: $model,
            messages: [
                {role: "system", content: $system_prompt},
                {role: "user", content: $prompt_content}
            ],
            temperature: ($temperature | tonumber),
            response_format: { "type": "json_object" }
        }')
    elif [[ ${ACSH_PROVIDER^^} == "OLLAMA" ]]; then
        payload=$(jq -cn --arg model "$model" --arg temperature "$temperature" --arg system_prompt "$system_message_prompt" --arg prompt_content "$prompt" '{
            model: $model,
            system: $system_prompt,
            messages: [
                {role: "user", content: $prompt_content}
            ],
            "format": "json",
            stream: false,
            "options": {
                "temperature": ($temperature | tonumber),
            }
        }')
    else
        payload=$(jq -cn --arg model "$model" --arg temperature "$temperature" --arg system_prompt "$system_message_prompt" --arg prompt_content "$prompt" '{
            model: $model,
            messages: [
                {role: "system", content: $system_prompt},
                {role: "user", content: $prompt_content}
            ],
            temperature: ($temperature | tonumber),
            response_format: { "type": "json_object" },
            tool_choice: {"type": "function", "function": {"name": "bash_completions"}},
            tools:[
            {
                "type": "function",
                "function": {
                    "name": "bash_completions",
                    "description": "syntacticly correct command-line suggestions based on the users input",
                    "parameters": {
                        "type": "object",
                        "properties": {
                            "commands": {
                                "type": "array",
                                "items": {
                                    "type": "string",
                                    "description": "A suggested command"
                                }
                            },
                        },
                        "required": ["commands"],
                    },
                },
            }
        ]
        }')
    fi
	echo "$payload"
}

log_request() {
    local user_input response_body user_input_hash log_file
    local prompt_tokens prompt_tokens_int completion_tokens completion_tokens_int created api_cost

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

    # or set the created time to the current time
    created=$(date +%s)
    created=$(echo "$response_body" | jq -r ".created // $created")

    api_cost=$(echo "$prompt_tokens_int * $ACSH_API_PROMPT_COST + $completion_tokens_int * $ACSH_API_COMPLETION_COST" | bc)

    # Log the response (request time, response time, prompt tokens, completion tokens, completion time, completion length, completion tokens per second, completion tokens per prompt token, completion tokens per second per prompt token, completion tokens per second per completion token)
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    echo "$created,$user_input_hash,$prompt_tokens_int,$completion_tokens_int,$api_cost" >> "$log_file"
}

openai_completion() {
	local content status_code response_body default_user_input user_input
    local api_key config_file payload response completions endpoint timeout
    local prompt_tokens completion_tokens created api_cost prompt_tokens_int completion_tokens_int

    #  Settings
    endpoint=${ACSH_ENDPOINT:-"https://api.openai.com/v1/chat/completions"}

    # Add 30 second timeout to the curl command
    timeout=${ACSH_TIMEOUT:-30}

    # Inputs and Defaults
	default_user_input="Write two to six most likely commands given the provided information"
	user_input=${*:-$default_user_input}

    # First check if the ACSH_ACTIVE_API_KEY is set
    if [[ -z "$ACSH_ACTIVE_API_KEY" && ${ACSH_PROVIDER^^} != "OLLAMA" ]]; then
        echo ""
        echo_error "ACSH_ACTIVE_API_KEY not set"
        echo -e "Please set it using the following command: \e[90mexport ${ACSH_PROVIDER^^}_API_KEY=<your-api-key>\e[0m"
        echo -e "or set it in the ~/.autocomplete/config configuration file via: \e[90mautocomplete config set ${ACSH_PROVIDER^^}_API_KEY <your-api-key>\e[0m"
        return
    fi
    api_key="${ACSH_ACTIVE_API_KEY:-$OPENAI_API_KEY}"
	payload=$(_build_payload "$user_input")

    if [[ "${ACSH_PROVIDER^^}" == "ANTHROPIC" ]]; then
        response=$(curl -s -m "$timeout" -w "\n%{http_code}" "$endpoint" \
        -H "content-type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "x-api-key: $api_key" \
        --data "$payload")
    elif [[ "${ACSH_PROVIDER^^}" == "OLLAMA" ]]; then
        response=$(curl -s -m "$timeout" -w "\n%{http_code}" "$endpoint" \
        --data "$payload")
    else  # OpenAI and GROQ have the same API design
        response=$(\curl -s -m "$timeout" -w "%{http_code}" "$endpoint" \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $api_key" \
		-d "$payload")
    fi

    status_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')

	if [[ $status_code -eq 200 ]]; then
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

		# Map the commands to a list of completions and remove empty lines
		completions=$(echo "$content" | jq -r '.[]' | grep -v '^$')
		echo -n "$completions"

        # Usage
        log_request "$user_input" "$response_body"
	else
        echo
		case $status_code in
		400)
			echo_error "Bad Request: The API request was invalid or malformed."
			;;
		401)
			echo_error "Unauthorized: The provided API key is invalid or missing."
			;;
		429)
			echo_error "Too Many Requests: The API rate limit has been exceeded."
			;;
		500)
			echo_error "Internal Server Error: An unexpected error occurred on the API server."
			;;
		*)
			echo_error "Unknown Error: Unexpected status code $status_code received from the API - $response_body \n$payload"
			;;
		esac
	fi
}

###############################################################################
#
# Completion Functions
#
###############################################################################

# Get the default completion function for a command
_get_default_completion_function() {
	local cmd="$1"
	complete -p "$cmd" 2>/dev/null | awk -F' ' '{ for(i=1;i<=NF;i++) { if ($i ~ /^-F$/) { print $(i+1); exit; } } }'
}

_default_completion() {
	# Get the current word being completed
	# Check if COMP_WORDS is empty
	local current_word=""
	local first_word=""
	local default_func

	# Check it COMP_WORDS IS NOT EMPTY
	if [[ -n "${COMP_WORDS[*]}" ]]; then
		first_word="${COMP_WORDS[0]}"
		# Check if COMP_CWORD is defined and is valid for COMP_WORDS
		if [[ -n "$COMP_CWORD" && "$COMP_CWORD" -lt "${#COMP_WORDS[@]}" ]]; then
			current_word="${COMP_WORDS[COMP_CWORD]}"
		fi
	fi

	# Get the default completion function for the command
	default_func=$(_get_default_completion_function "$first_word")

	# If a default completion function exists, call it
	if [[ -n "$default_func" ]]; then
		"$default_func"
	else
		# fall back to file completions
		local file_completions
		# compgen has non-zero exit codes if no match and so we need || true
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
    local cache_dir cache_files
    cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    cache_files=$(find "$cache_dir" -maxdepth 1 -type f -name "acsh-*" -printf '%T+ %p\n' | sort)
    echo "$cache_files"
}

_autocompletesh() {

	# defines prev and cur
	_init_completion || return

	# Attempt to get default completions first
	_default_completion

	if [[ ${#COMPREPLY[@]} -eq 0 && $COMP_TYPE -eq 63 ]]; then

		local completions
		local user_input
        local user_input_hash

        load_config

        # CHECK API KEY is set
        if [[ -z "$ACSH_ACTIVE_API_KEY" ]]; then
            provider_key="${ACSH_PROVIDER:-openai}_API_KEY"
            provider_key=${provider_key^^}
            echo_error "${provider_key} is not set
Please set it using the following command: \e[0mexport ${provider_key}=<your-api-key>\e[31m
or set it in the ~/.autocomplete/config configuration file via \e[0mautocomplete config set ${provider_key} <your-api-key>\e[31m
or disable autocomplete via \e[0mautocomplete disable\e[31m"
            echo
            return
        fi

		# Prepare input for the language model API
        if [[ -n "${COMP_WORDS[*]}" ]]; then
            command="${COMP_WORDS[0]}"
            # Check if COMP_CWORD is defined and is valid for COMP_WORDS
            if [[ -n "$COMP_CWORD" && "$COMP_CWORD" -lt "${#COMP_WORDS[@]}" ]]; then
                current="${COMP_WORDS[COMP_CWORD]}"
            fi
        fi
		user_input="${COMP_LINE-"$command $current"}"
        user_input_hash=$(echo -n "$user_input" | md5sum | cut -d ' ' -f 1)

		# Set and clear
		export ACSH_INPUT="$user_input"
		export ACSH_PROMPT=
		export ACSH_RESPONSE=

		# Advance to the next line
        # change the color of the blinking cursor

        # ACSH_CACHE_DIR: ~/.autocomplete/cache
        # cache_dir is ACSH_CACHE_DIR or default "$HOME/.autocomplete/cache"
        local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
        local cache_size=${ACSH_CACHE_SIZE:-100}

        # Check if user_input_hash is in the cache and cache is enabled
        local cache_file="$cache_dir/acsh-$user_input_hash.txt"
        if [[ -d "$cache_dir" && "$cache_size" -gt 0 && -f "$cache_file" ]]; then
            completions=$(cat "$cache_file" || true)
            touch "$cache_file"
        else
            # CALL API
            echo -en "\e]12;green\a"
            completions=$(openai_completion "$user_input" || true)
            # If Completions is empty, fall back to the current word
            if [[ -z "$completions" ]]; then
                echo -en "\e]12;red\a"
                sleep 1
                completions=$(openai_completion "$user_input" || true)
            fi
            echo -en "\e]12;white\a"

            # If the cache size is greater than the cache size, remove the oldest file
            if [[ -d "$cache_dir" && "$cache_size" -gt 0 ]]; then
                echo "$completions" > "$cache_file"
                if [[ $(list_cache | wc -l) -gt "$cache_size" ]]; then
                    rm "$(list_cache | head -n 1 | cut -d ' ' -f 2-)" || true
                fi
            fi
        fi
		export ACSH_RESPONSE=$completions

		# If OpenAI API returns completions, use them
		if [[ -n "$completions" ]]; then
			num_rows=$(echo "$completions" | wc -l)
			COMPREPLY=()
			if [[ $num_rows -eq 1 ]]; then
				# remove the leading command if it is present
				# find and replace all : in $completions with an escaped version
				readarray -t COMPREPLY <<<"$(echo -n "${completions}" | sed "s/${command}[[:space:]]*//" | sed 's/:/\\:/g')"
			else
				# Add a counter to the completions so that autocomplete
                # can display them in the block format
				completions=$(echo "$completions" | awk '{print NR". "$0}')
				readarray -t COMPREPLY <<< "$completions"
			fi
		fi
		# If the completions are empty, fall back to $current
		if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
			COMPREPLY=("$current")
		fi
	fi
}

###############################################################################
#
# CLI ENTRY POINT
#
###############################################################################

show_help() {
	echo_green "Autocomplete.sh - LLM Powered Bash Completion"
	echo "Usage: autocomplete [options] command"
	echo "       autocomplete [options] install|remove|config|model|enable|disable|clear|usage|system|command|--help"
	echo
	echo "autocomplete.sh is a script to enhance bash completion with LLM capabilities."
	echo
	echo "Once installed and enabled, it will provide suggestions for the current command."
	echo "Just by pressing the Tab key, you can get the most likely completion for the command."
	echo "It provides various commands to manage and configure the autocomplete features."
	echo
	echo "Most used:"
	echo "  command             Run the autocomplete command same a pressing <tab><tab>"
	echo "  command --dry-run   Only show the prompt without running the command"
    echo
    echo "Configuration and Settings:"
    echo "  model               Change the language model used for completion"
    echo "  usage               Display usage information including cost"
    echo "  system              Displays system information"
    echo "  config              Displays status and config values"
	echo "  config set <key> <value>  Set a configuration value"
	echo "  config reset        Reset configuration to default values"
	echo
    echo "Installation / Removal / Cache Reset:"
    echo "  install             Install the autocomplete script from .bashrc"
	echo "  remove              Remove the autocomplete script from .bashrc"
	echo "  enable              Enable the autocomplete script"
	echo "  disable             Disable the autocomplete script"
    echo "  clear               Clear the cache directory and log file"
	echo
	echo "Submit bugs or feedback here: https://github.com/closedloop-technologies/autocomplete-sh/issues"
	echo "For more information, visit: https://autocomplete.sh"
}

show_config() {
	local is_enabled config_file config_value
    local term_width small_table rest

	is_enabled=$(check_if_enabled)
	echo_green "Autocomplete.sh - Configuration and Settings - Version $ACSH_VERSION"
	if [[ "$is_enabled" = "enabled" ]]; then
		# echo enabled in green
        echo -e "  STATUS: \033[32;5mEnabled\033[0m \033[0m"
	else
		# echo disabled in red
        echo -e "  STATUS: \033[31;5mDisabled\033[0m \033[0m"
	fi
	config_file="$HOME/.autocomplete/config"
	if [ ! -f "$config_file" ]; then
		echo_error "Configuration file not found: $config_file"
		echo_error "Run autocomplete install"
		return
	fi
    load_config
    echo
    term_width=$(tput cols)
    if [[ term_width -gt 70 ]]; then
        term_width=70
        small_table=0
    fi
    if [[ term_width -lt 40 ]]; then
        term_width=70
        small_table=1
    fi

    for config_var in $(compgen -v | grep ACSH_); do
        if [[ $config_var == "ACSH_INPUT" ]] || [[ $config_var == "ACSH_PROMPT" ]] || [[ $config_var == "ACSH_RESPONSE" ]]; then
            continue
        fi
        config_value="${!config_var}"
        if [[ ${config_var: -8}  == "_API_KEY" ]]; then
            continue
        fi
        echo -en "  $config_var:\e[90m"
        if [[ small_table -eq 1 ]]; then
            echo -e "\n  $config_value\e[0m"
        else
            printf '%s%*s' "" $((term_width - ${#config_var} - ${#config_value} - 3)) ''
            echo -e "$config_value\e[0m"
        fi
    done
    echo -e "  ===================================================================="
    for config_var in $(compgen -v | grep ACSH_); do
        if [[ $config_var == "ACSH_INPUT" ]] || [[ $config_var == "ACSH_PROMPT" ]] || [[ $config_var == "ACSH_RESPONSE" ]]; then
            continue
        fi
        config_value="${!config_var}"
        if [[ ${config_var: -8}  != "_API_KEY" ]]; then
            continue
        fi
        # show the first 2 characters of the api key and the last 4 characters
        echo -en "  $config_var:\e[90m"
        if [[ -z ${!config_var} ]]; then
            echo -en "\e[31m"
            config_value="UNSET"
        else
            echo -en "\e[32m"
            rest=${!config_var:4}
            config_value="${!config_var:0:4}...${rest: -4}"
        fi
        # echo -en "  $config_var:\e[90m"
        if [[ small_table -eq 1 ]]; then
            echo -e "\n  $config_value\e[0m"
        else
            printf '%s%*s' "" $((term_width - ${#config_var} - ${#config_value} - 3)) ''
            echo -e "$config_value\e[0m"
        fi

    done
}

# Function to set a configuration key-value pair
set_config() {
    local key="$1"
    local value="$2"
    local config_file="$HOME/.autocomplete/config"

    key=${key,,}  # Convert to lowercase
    key=${key//[^a-zA-Z0-9]/_}  # Replace non-alphanumeric characters with _

    if [ -z "$key" ]; then
        echo_error "SyntaxError: expected \`autocomplete config set <key> <value>\`"
        return
    fi

    if [ ! -f "$config_file" ]; then
        echo_error "Configuration file not found: $config_file"
        echo_error "Run autocomplete install"
        return
    fi

    # Find the key in the config file and replace it with the new value
    # sed -i "s/\(^$key:\).*/\1 $value/" "$config_file"
    sed -i "s|^\($key:\).*|\1 $value|" "$config_file"

    # Display the new value by loading the config
    load_config
}

# Function to handle config commands
config_command() {
    local command config_file

    config_file="$HOME/.autocomplete/config"
    command="${*:2}"

    if [ -z "$command" ]; then
        show_config
        return
    fi
    # If command is set, show the configuration value
    # command should be in the format `set <key> <value>`
    if [ "$2" == "set" ]; then
        local key="$3"
        local value="$4"
        echo -e "Setting configuration key \`$key\` to value \`$value\`"
        set_config "$key" "$value"
        echo_green "Configuration updated: run \`autocomplete config\` to see the changes"
        return
    fi
    if [[ "$command" == "reset" ]]; then
        echo "Resetting configuration to default values"
        # Remove the config file if it exists
        rm "$config_file" || true
        build_config
        return
    fi
    echo_error "SyntaxError: expected \`autocomplete config set <key> <value>\ or autocomplete config reset\`"
}

build_config() {
    local config_file default_config api_key
    config_file="$HOME/.autocomplete/config"

    if [ ! -f "$config_file" ]; then
        echo "Creating the ~/.autocomplete/config file with default values"
        api_key="${ACSH_ACTIVE_API_KEY:-$OPENAI_API_KEY}"
        default_config="# ~/.autocomplete/config

# OpenAI API Key set here or as an environment variable named OPENAI_API_KEY
# https://platform.openai.com/api-keys
openai_api_key: $OPENAI_API_KEY

# Anthropic/Claude API Key set here or as an environment variable ANTHROPIC_API_KEY
# https://console.anthropic.com/settings/keys
anthropic_api_key: $ANTHROPIC_API_KEY

# Groq API Key set here or as en environment variable GROQ_API_KEY
# https://console.groq.com/keys
groq_api_key: $GROQ_API_KEY

# If your custom deployment like Ollama needs a key set it here or LLM_API_KEY
custom_api_key: $LLM_API_KEY

# Model configuration
## Model List https://platform.openai.com/docs/models
provider: openai
model: gpt-4o
temperature: 0.0
endpoint: https://api.openai.com/v1/chat/completions
# If pricing is outdated, submit issue: https://github.com/closedloop-technologies/autocomplete-sh/issues
# Sources: https://openai.com/api/pricing/
api_prompt_cost: 0.000005
api_completion_cost: 0.000015

# Max number of history commands and recent files to include in the prompt
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

load_config() {
    local config_file key value

    config_file="$HOME/.autocomplete/config"

    if [ -f "$config_file" ]; then
        # Read the config file line by line
        while IFS=':' read -r key value; do
            # Skip comments and empty lines
            if [[ $key == \#* ]] || [[ -z $key ]]; then
                continue
            fi

            # Remove leading/trailing whitespace from key and value
            key=$(echo "$key" | tr -d '[:space:]')
            value=$(echo "$value" | tr -d '[:space:]')

            # Convert the key to uppercase and replace non-alphanumeric characters with underscores
            key=${key^^}
            key=${key//[^[:alnum:]]/_}

            # Set the variable dynamically if it's not api_key or if api_key is not empty
            if [[ $key != "api_key" ]] || [[ -n $value ]]; then
                export "ACSH_$key"="$value"
            fi
        done < "$config_file"

        # Now assign ACSH_ACTIVE_API_KEY based on ACSH_PROVIDER
        case "${ACSH_PROVIDER:-openai}" in
            "openai")
                export ACSH_ACTIVE_API_KEY="$ACSH_OPENAI_API_KEY"
                ;;
            "anthropic")
                export ACSH_ACTIVE_API_KEY="$ACSH_ANTHROPIC_API_KEY"
                ;;
            "groq")
                export ACSH_ACTIVE_API_KEY="$ACSH_GROQ_API_KEY"
                ;;
            "ollama")
                export ACSH_ACTIVE_API_KEY="$ACSH_CUSTOM_API_KEY"
                ;;
            *)
                echo_error "Unknown provider: $ACSH_PROVIDER"
                ;;
        esac
    else
        echo "Configuration file not found: $config_file"
    fi
}

install_command() {
    local bashrc_file autocomplete_setup autocomplete_cli_setup

    bashrc_file="$HOME/.bashrc"
    autocomplete_setup="source autocomplete enable"
    autocomplete_cli_setup="complete -F _autocompletesh_cli autocomplete"

    # Confirm that autocomplete exists and is in the path
    if ! command -v autocomplete &>/dev/null; then
        echo_error "autocomplete.sh is not in the PATH
Please follow the install instructions on https://github.com/closedloop-technologies/autocomplete-sh"
        return
    fi

    # Create the ~/.autocomplete directory if it does not exist
    if [[ ! -d "$HOME/.autocomplete" ]]; then
        echo "Creating the ~/.autocomplete directory"
        mkdir -p "$HOME/.autocomplete"
    fi

    # TODO select a model on install

    # If OPENAI_API_KEY is not set, prompt the user to set it
    if [[ -z "$ACSH_ACTIVE_API_KEY" ]]; then
        # PROMPT USER TO enter API KEY
        echo_green "Autocomplete.sh - Installation"
        echo "To install autocomplete.sh, you need an OpenAI API Key"
        echo "This is stored locally in the ~/.autocomplete/config file"
        echo "Create a new one here: https://platform.openai.com/settings/profile?tab=api-keys"

        echo -n "Enter OpenAI API Key: "
        read -sr user_api_key_input < /dev/tty
        echo

        if [[ -z "$user_api_key_input" ]]; then
            echo_error "API Key not set"
            echo -e "Please set it later using the following command: export OPENAI_API_KEY=<your-api-key>"
            echo -e "or set it in the ~/.autocomplete/config configuration file via: autocomplete config set api_key <your-api-key>"
        else
            export ACSH_ACTIVE_API_KEY="$user_api_key_input"
        fi
    else
        echo_green "OpenAPI key is loaded from the environment variable"
    fi

    # Create $HOME/.autocomplete/cache/ if it does not exist
    local cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    if [[ ! -d "$cache_dir" ]]; then
        mkdir -p "$cache_dir"
    fi

    # $HOME/.autocomplete/config
    build_config

    # Append autocomplete.sh setup to .bashrc if it doesn't exist
    if ! grep -qF "$autocomplete_setup" "$bashrc_file"; then
        echo -e "# Autocomplete.sh" >> "$bashrc_file"
        echo -e "$autocomplete_setup\n" >> "$bashrc_file"
        echo "Added autocomplete.sh setup to $bashrc_file"
    else
        echo "Autocomplete.sh setup already exists in $bashrc_file"
    fi

    # Append Generic autocomplete
    if ! grep -qF "$autocomplete_cli_setup" "$bashrc_file"; then
        echo -e "# Autocomplete.sh CLI" >> "$bashrc_file"
        echo -e "$autocomplete_cli_setup\n" >> "$bashrc_file"
        echo "Added autocomplete cli autocomplete to $bashrc_file"
    fi
    echo "Completed installing autocomplete.sh"
}

remove_command() {
    local config_file cache_dir log_file bashrc_file

    config_file="$HOME/.autocomplete/config"
    cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    bashrc_file="$HOME/.bashrc"

    echo_green "Autocomplete.sh - Removing files, directories, and bashrc setup..."

    # Remove the configuration file
    if [ -f "$config_file" ]; then
        rm "$config_file"
        echo "Removed: $config_file"
    fi

    # Remove the cache directory and its contents
    if [ -d "$cache_dir" ]; then
        rm -rf "$cache_dir"
        echo "Removed: $cache_dir"
    fi

    # Remove the log file
    if [ -f "$log_file" ]; then
        rm "$log_file"
        echo "Removed: $log_file"
    fi

    # Remove the ~/.autocomplete directory if it is empty
    if [ -d "$HOME/.autocomplete" ]; then
        if [ -z "$(ls -A "$HOME/.autocomplete")" ]; then
            rmdir "$HOME/.autocomplete"
            echo "Removed: $HOME/.autocomplete"
        else
            echo "Skipped removing $HOME/.autocomplete (directory not empty)"
        fi
    fi

    # Remove the autocomplete.sh setup line from .bashrc
    if [ -f "$bashrc_file" ]; then
        if grep -qF "source autocomplete enable" "$bashrc_file"; then

            # remove lines that start with # Autocomplete.sh
            sed -i '/# Autocomplete.sh/d' "$bashrc_file"

            # remove lines that contain source autocomplete enable
            sed -i '/autocomplete/d' "$bashrc_file"

            echo "Removed autocomplete.sh setup from $bashrc_file"
        fi
    fi

    echo "Completed uninstalling autocomplete.sh"
}

check_if_enabled() {
	# run complete -p | grep _autocompletesh and if it returns a value, it is enabled
	local is_enabled
	is_enabled=$(complete -p | grep _autocompletesh)
	if [ "$is_enabled" ]; then
		echo "enabled"
	fi
}

_autocompletesh_cli() {

    if [[ -n "${COMP_WORDS[*]}" ]]; then
        command="${COMP_WORDS[0]}"
        # Check if COMP_CWORD is defined and is valid for COMP_WORDS
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
	local is_enabled
	is_enabled=$(check_if_enabled)
	if [ "$is_enabled" ]; then
		echo_green "Autocomplete.sh - reloading"
		disable_command
	fi
	# Set as the default completion function (-D )
	# Also enable for empty commands (-E)
	complete -D -E -F _autocompletesh -o nospace
}

disable_command() {
	# Remove the completion function by installing the default completion function
	local is_enabled
	is_enabled=$(check_if_enabled)
	if [ "$is_enabled" ]; then
		complete -F _completion_loader -D
	fi
}

command_command() {
    local args=("$@") # Convert positional parameters to an array
    for ((i = 0; i < ${#args[@]}; i++)); do
        if [ "${args[i]}" == "--dry-run" ]; then
            args[i]="" # Remove --dry-run by setting it to an empty string
            _build_prompt "${args[@]}"
            return
        fi
    done
	openai_completion "$@" || true
    echo
}

clear_command() {
    # Clear the cache directory and log file
    local cache_dir log_file
    load_config
    cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}

    # Prompt user to confirm
    echo "This will remove the cache directory and log file"
    # Make cache_dir show in red
    echo -e "Cache dir:\t\e[31m$cache_dir\e[0m"
    echo -e "Log file:\t\e[31m$log_file\e[0m"
    read -r -p "Are you sure you want to continue? (y/n): " confirm
    if [[ $confirm != "y" ]]; then
        echo "Aborted"
        return
    fi
    if [ -d "$cache_dir" ]; then
        cache_files=$(list_cache)
        echo "$cache_file"
        if [ -n "$cache_files" ]; then
            for last_update_and_filename in $cache_files; do
                file=$(echo "$last_update_and_filename" | cut -d ' ' -f 2)
                rm "$file"
                echo "Removed: $file"
            done
            echo "Removed files in: $cache_dir"
        else
            echo "Cache directory is empty"
        fi

        echo "Removed: $cache_dir"
    fi
    if [ -f "$log_file" ]; then
        rm "$log_file"
        echo "Removed: $log_file"
    fi
}

usage_command() {
    local log_file number_of_lines api_cost cache_dir
    log_file=${ACSH_LOG_FILE:-"$HOME/.autocomplete/autocomplete.log"}
    cache_dir=${ACSH_CACHE_DIR:-"$HOME/.autocomplete/cache"}

    cache_size=$(list_cache | wc -l)

    echo_green "Autocomplete.sh - Usage Information"
    echo
    echo -n "Log file: "
    echo -en "\e[90m"
    echo "$log_file"
    echo -en "\e[0m"

    # If log_file does not exist, return
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
    echo -e "API Calls:\t"

    # Date analysis
    if [[ $number_of_lines -eq 0 ]]; then
        echo_error "No usage data found"
        return
    else
        earliest_date=$(awk -F, '{print $1}' "$log_file" | sort | head -n 1)
        if [[ -n "$earliest_date" ]]; then
            # format earliest_date to human readable date
            earliest_date=$(date -d@"$earliest_date")
            echo -en "\e[90m"
            echo "Since $earliest_date"
            echo -en "\e[0m"
        fi
    fi
    echo
    echo -en "\tUsage count:\t"
    echo -en "\e[32m"
    printf "%9s\n" "$number_of_lines"
    echo -en "\e[0m"
    echo -en "\tAvg Cost:\t$"
    printf "%8.4f\n" "$avg_api_cost"
    echo -e "\e[90m\t-------------------------\e[0m"
    echo -en "\tTotal Cost:\t$"
    echo -en "\e[31m"
    printf "%8.4f\n" "$api_cost"
    echo -en "\e[0m"
    echo
    echo
    echo -n "Cache Size: ${cache_size} of ${ACSH_CACHE_SIZE:-10} in "
    echo -e "\e[90m$cache_dir\e[0m"
    echo
    echo -e "To clear the log file and cache directory, run: \e[90mautocomplete clear\e[0m"
}

# Function to capture key presses
get_key() {
  IFS= read -rsn1 key 2>/dev/null >&2
  if [[ $key == $'\x1b' ]]; then
    read -rsn2 key
    if [[ $key == [A ]]; then echo up; fi
    if [[ $key == [B ]]; then echo down; fi
  fi
}

# Function to display a menu and let the user select an option using arrow keys
menu_selector() {

  # Build the options array from the models object
  options=("$@")
  # Initial selected option
  selected=0

  # Function to display the menu
  show_menu() {
    echo
    echo "Select a Language Model:"
    echo
    for i in "${!options[@]}"; do
      if [[ $i == "$selected" ]]; then
        echo -e "\e[1;32m> ${options[i]}\e[0m"
      else
        echo -e "  ${options[i]}"
      fi
    done
    echo
    echo -ne "Press Enter to select the model\t"
  }

  # Save the current cursor position
  tput sc

  # Infinite loop to handle user input
  while true; do
    # Restore the cursor position and clear to the end of the screen
    tput rc
    tput ed
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
      "")
        break
        ;;
    esac
  done
  clear
  return $selected
}

# Example function to demonstrate using the menu_selector
model_command() {
  clear
  local selected_model options=()

  # Collect and sort the keys
  mapfile -t sorted_keys < <(for key in "${!_autocomplete_modellist[@]}"; do echo "$key"; done | sort)

  for key in "${sorted_keys[@]}"; do
      options+=("$key")
  done
  echo -e "\e[1;32mAutocomplete.sh - Model Configuration\e[0m"
  menu_selector "${options[@]}"
  selected_option=$?
  echo -e "\e[1;32mAutocomplete.sh - Model Configuration\e[0m"
  selected_model="${options[selected_option]}"
  selected_value="${_autocomplete_modellist[$selected_model]}"
  set_config "model" "$(echo "$selected_value" | jq -r '.model')"
  set_config "endpoint" "$(echo "$selected_value" | jq -r '.endpoint')"
  set_config "provider" "$(echo "$selected_value" | jq -r '.provider')"

  prompt_cost=$(echo "$selected_value" | jq -r '.prompt_cost' | awk '{printf "%.8f", $1}' )
  completion_cost=$(echo "$selected_value" | jq -r '.completion_cost' | awk '{printf "%.8f", $1}')

  set_config "api_prompt_cost" "$prompt_cost"
  set_config "api_completion_cost" "$completion_cost"

  model="${ACSH_MODEL:-"ERROR"}"
  temperature=$(echo "${ACSH_TEMPERATURE:-0.0}" | awk '{printf "%.3f", $1}' )

  echo
  echo -e "Provider:\t\e[90m$ACSH_PROVIDER\e[0m"
  echo -e "Model:\t\t\e[90m$model\e[0m"
  echo -e "Temperature:\t\e[90m$temperature\e[0m"
  echo
  echo -e "Cost/token:\t\e[90mprompt:    \t\$$ACSH_API_PROMPT_COST\e[0m"
  echo -e "            \t\e[90mcompletion:\t\$$ACSH_API_COMPLETION_COST\e[0m"
  echo
  echo -e "Endpoint:   \t\e[90m$ACSH_ENDPOINT\e[0m"
  echo -en "API Key:    \t"

  if [[ -z $ACSH_ACTIVE_API_KEY ]]; then
      if [[ ${ACSH_PROVIDER^^} == "OLLAMA" ]]; then
          echo -en "\e[90mNot Used\e[0m"
      else
          echo -en "\e[31mUNSET"
      fi
  else
      rest=${ACSH_ACTIVE_API_KEY:4}
      config_value="${ACSH_ACTIVE_API_KEY:0:4}...${rest: -4}"
      echo -en "\e[32m${config_value}"
  fi
  echo -e "\e[0m"

  if [[ -z $ACSH_ACTIVE_API_KEY && ${ACSH_PROVIDER^^} != "OLLAMA" ]]; then
        echo
        echo -e "To set the API Key, run:\t\e[31mautocomplete config set api_key <your-api>\e[0m"
  else
        echo
  fi

  if [[ ${ACSH_PROVIDER^^} == "OLLAMA" ]]; then
        echo
        echo -e "To set a custom endpoint:\t\e[34mautocomplete config set endpoint <your-url>\e[0m"
        echo -e "Other models can be set:\t\e[34mautocomplete config set model <model-name>\e[0m"
  fi
  echo -e "To change the temperature:\t\e[90mautocomplete config set temperature <temperature>\e[0m"
  echo
}

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
	remove_command
	;;
clear)
	clear_command
	;;
usage)
    usage_command
    ;;
model)
    model_command
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
	echo_error "Unknown command $1 - run \`autocomplete --help\` or goto https://autocomplete.sh for more information"
	;;
esac
