#!/bin/bash

# autocomplete.sh - LLM Powered Bash Completion
# acsh
# This script provides bash completion suggestions using the OpenAI API.
# MIT License - ClosedLoop Technologies, Inc.
# Sean Kruzel 2024

## TODO
# autocompletecli_completion()
# Install via curl like https://github.com/nvm-sh/nvm/tree/master
# tests coverage via https://github.com/nvm-sh/nvm/tree/master

# Do not use `set -euo pipefail` or similar because this a
# bash completion script and it will change the behavior of the shell invoking it

###############################################################################
#
# FORMATTING FUNCTIONS
#
###############################################################################

echo_error() {
	echo -e "\n\e[31mautocomplete.sh - $1\e[0m" >&2
}

echo_green() {
	echo -e "\e[32m$1\e[0m"
}

echo_searching() {
	local padding=${1:-0}
	echo -en "\033[32;5mSearching\033[0m \033[32m..."
	local padding=${1:-0}
	if [[ $padding -gt 0 ]]; then
		for _ in $(seq 1 "$padding"); do
			echo -n "."
		done
	fi
	echo -en "\033[0m"
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

# Get the last 20 commands from the bash history
# GOTCHA: The history only populate if you run the command in the same terminal.  If you run it
# in a ./autocomplete_api.sh, it will not be populated since that runs in a different environment
_get_command_history() {
	local HISTORY_LIMIT
	HISTORY_LIMIT=${1:-20}
	history | tail -n "$HISTORY_LIMIT"
}

_get_recent_files() {
	local FILE_LIMIT
	FILE_LIMIT=${1:-20}
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
	command_history=$(_get_command_history 20)
	terminal_context=$(_get_terminal_info)
	help_message=$(_get_help_message "$user_input")
	recent_files=$(_get_recent_files 20)
	output_instructions=$(_get_output_instructions)

	# compgen lists environmental variables without the
	other_environment_variables=$(compgen -v | grep -v 'PWD|OSTYPE|BASH|USER|HOME|TERM|OLDPWD|HOSTNAME')

	prompt="User command: \`$user_input\`

# Terminal Context
## Environment variables
$terminal_context

Other defined environment variables
\`\`\`
$other_environment_variables
\`\`\`

## History
Recently run commands (in order):
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
	user_input="$1"
	prompt=$(_build_prompt "$@")
	system_message_prompt=$(_get_system_message_prompt)

	# EXPORT PROMPT TO #ACSH_PROMPT
	acsh_prompt="# SYSTEM PROMPT\n"
	acsh_prompt+=$system_message_prompt
	acsh_prompt+="\n# USER MESSAGE\n"
	acsh_prompt+=$prompt
	export ACSH_PROMPT=$acsh_prompt

	payload=$(jq -cn --arg system_prompt "$system_message_prompt" --arg prompt_content "$prompt" '{
        model: "gpt-4o",
        messages: [
            {role: "system", content: $system_prompt},
            {role: "user", content: $prompt_content}
        ],
        temperature: 0.0,
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
	echo "$payload" >/tmp/autocomplete_payload.txt
	echo "$payload"
}

openai_completion() {
	local content status_code response_body default_user_input user_input api_key config_file payload response completions

	default_user_input="Write two to six most likely commands given the provided information"
	user_input=${*:-$default_user_input}

	# Ensure the API key is set
	if [[ -n "$OPENAI_API_KEY" ]]; then
		api_key="$OPENAI_API_KEY"
	else
		config_file="$HOME/.autocomplete-sh"
		if [[ -f "$config_file" ]]; then
			api_key=$(awk '/api_key:/ {print $2}' "$config_file")
		else
			echo_error "Please set the OPENAI_API_KEY environment variable or create a ~/.autocomplete-sh YAML configuration file with the 'api_key' field."
			return
		fi
	fi
	payload=$(_build_payload "$user_input")
	# Add 5 second timeout to the curl command
	response=$(\curl -s -m 30 -w "%{http_code}" https://api.openai.com/v1/chat/completions \
		-H "Content-Type: application/json" \
		-H "Authorization: Bearer $api_key" \
		-d "$payload")

	echo "$response" >/tmp/autocomplete_response.txt
	status_code=$(echo "$response" | tail -n1)
	response_body=$(echo "$response" | sed '$d')
	if [[ $status_code -eq 200 ]]; then
		content=$(echo "$response_body" | jq -r '.choices[0].message.tool_calls[0].function.arguments')
		content=$(echo "$content" | jq -r '.commands')

		# Map the commands to a list of completions and remove empty lines
		completions=$(echo "$content" | jq -r '.[]' | grep -v '^$')

		# TODO is this -n or no?
		echo -n "$completions"
	else
		# TODO RETRY once on unknown error or 429
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
			echo_error "Unknown Error: Unexpected status code $status_code received from the API - $response_body"
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

_autocompletesh() {

	# defines prev and cur
	_init_completion || return
	# _completion_vars
	# local current=""
	# local first_word=""

	# Check it COMP_WORDS IS NOT EMPTY
	if [[ -n "${COMP_WORDS[*]}" ]]; then
		command="${COMP_WORDS[0]}"
		# Check if COMP_CWORD is defined and is valid for COMP_WORDS
		if [[ -n "$COMP_CWORD" && "$COMP_CWORD" -lt "${#COMP_WORDS[@]}" ]]; then
			current="${COMP_WORDS[COMP_CWORD]}"
		fi
	fi

	# TODO If COMP_TYPE != 9, then what should we do?

	# Attempt to get default completions first
	_default_completion

	# If COMPREPLY is not empty, use it; otherwise, use OpenAI API completions
	if [[ ${#COMPREPLY[@]} -eq 0 &&  $COMP_TYPE -eq 63 ]]; then

		local completions
		local user_input
        local user_input_hash

		# Prepare input for the language model API
		user_input="${COMP_LINE-"$command $current"}"
        user_input_hash=$(echo -n "$user_input" | md5sum | cut -d ' ' -f 1)

		# Set and clear
		export ACSH_INPUT=$user_input
		export ACSH_PROMPT=
		export ACSH_RESPONSE=

		# Advance to the next line
        # change the color of the blinking cursor

        # Check if user_input_hash is in the cache
        if [[ -f "/tmp/autocomplete_cache/$user_input_hash" ]]; then
            completions=$(cat "/tmp/autocomplete_cache/$user_input_hash")
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
            echo "$completions" > "/tmp/autocomplete_cache/$user_input_hash"
        fi
		export ACSH_RESPONSE=$completions


		# If OpenAI API returns completions, use them
		if [[ -n "$completions" ]]; then
			# write $completions to a file for debugging
			echo "$completions" >/tmp/autocomplete_completions.txt

			num_rows=$(echo "$completions" | wc -l)
			COMPREPLY=()
			if [[ $num_rows -eq 1 ]]; then
				# remove the leading command if it is present
				# find and replace all : in $completions with an escaped version
				readarray -t COMPREPLY <<<"$(echo -n "${completions}" | sed "s/${command}[[:space:]]*//" | sed 's/:/\\:/g')"
			else
				# Add a counter to the completions
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
	echo_green "autocomplete.sh - LLM Powered Bash Completion"
	echo "Usage: autocomplete [options] command"
	echo "       autocomplete [options] install|remove|info|config|enable|disable|command|--help"
	echo
	echo "autocomplete.sh is a script to enhance bash completion with LLM capabilities."
	echo
	echo "Once installed and enabled, it will provide suggestions for the current command."
	echo "Just by pressing the Tab key, you can get the most likely completion for the command."
	echo "It provides various commands to manage and configure the autocomplete features."
	echo
	echo "Most used commands:"
	echo "  install             Install the autocomplete script from .bashrc"
	echo "  remove              Remove the autocomplete script from .bashrc"
	echo "  info                Displays status and config values"
	echo "  system              Displays system information"
	echo "  config set <key> <value>  Set a configuration value"
	echo "  enable              Enable the autocomplete script"
	echo "  disable             Disable the autocomplete script"
	echo "  command             Run the autocomplete command"
	echo "  command --dry-run   Only show the prompt without running the command"
	echo
	echo "Submit bugs or feedback here: https://github.com/closedloop-technologies/autocomplete-sh/issues"
	echo "For more information, visit: https://autocomplete.sh"
}

show_config() {
	local is_enabled config_file
	is_enabled=$(check_if_enabled)
	echo "autocomplete.sh - LLM Powered Bash Completion"
	echo
	if [ "$is_enabled" ]; then
		# echo enabled in green
		echo -e "  STATUS: \e[32mEnabled\e[0m"
	else
		# echo disabled in red
		echo -e "  STATUS: \e[31mDisabled\e[0m"
	fi
	config_file="$HOME/.autocomplete/config"
	if [ ! -f "$config_file" ]; then
		echo_error "Configuration file not found: $config_file"
		echo_error "Run autocomplete install"
		return
	fi
}

config_command() {
	local command="${*:2}"

	if [ -z "$command" ]; then
		echo_error "SyntaxError: expected \`autocomplete config set <key> <value>\`"
		return
	fi
	# If command is set, show the configuration value
	# command should be in the format `set <key> <value>`
	if [ "$2" == "set" ]; then
		local key="$3"
		local value="$4"
		if [ -z "$key" ]; then
			echo_error "SyntaxError: expected \`autocomplete config set <key> <value>\`"
			return
		fi
		echo "Setting configuration key \`$key\` to value \`$value\`"
		return
	fi
	echo_error "SyntaxError: expected \`autocomplete config set <key> <value>\`"
}

install_command() {
	echo "install_command"

    # Create /tmp/autocomplete_cache if it does not exist
    if [[ ! -d "/tmp/autocomplete_cache" ]]; then
        mkdir -p "/tmp/autocomplete_cache"
    fi
}

remove_command() {
	echo "remove_command"
}

check_if_enabled() {
	# run complete -p | grep _autocompletesh and if it returns a value, it is enabled
	local is_enabled
	is_enabled=$(complete -p | grep _autocompletesh)
	if [ "$is_enabled" ]; then
		echo "enabled"
	fi
}

enable_command() {
	local is_enabled
	is_enabled=$(check_if_enabled)
	if [ "$is_enabled" ]; then
		echo_green "autocomplete.sh - reloading"
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

	for arg in "$@"; do
		if [ "$arg" == "--dry-run" ]; then
			_build_prompt "${@:2}"
			return
		fi
	done
	openai_completion "$@" || true
}

case "$1" in
"--help")
	show_help
	;;
info)
	show_config
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
