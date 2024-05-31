#!/bin/bash

# Do not use `set -euo pipefail` or similar because this a 
# bash completion script and it will change the behavior of the shell

echo_error() {
    echo -e "\n\e[31mautocomplete.sh - $1\e[0m" >&2
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo_error "jq is not installed. Please install it using the following command: \`sudo apt-get install jq\`"
fi

###############################################################################
#
# LARGE LANGUAGE MODEL COMPLETION FUNCTIONS
#
###############################################################################

SYSTEM_MESSAGE_PROMPT="You are a helpful bash_completion script. \
Generate relevant and concise auto-complete suggestion for the given user command \
in the context of the current directory, operating system, command history, \
and masked environment variable names. \
Only provide the single most likely command for the user given their provided information."


# Get the last 20 commands from the bash history
# GOTCHA: The history only populate if you run the command in the same terminal.  If you run it 
# in a ./autocomplete_api.sh, it will not be populated since that runs in a different environment
_get_command_history() {
    local HISTORY_LIMIT=${1:-20}
    echo "$(history | tail -n $HISTORY_LIMIT)"
}

# Attempts to get the help message for a given command
_get_help_message() {
    # Extract the first word from the user input
    local COMMAND=$(echo "$1" | awk '{print $1}')

    # Attempt to capture the help information
    local HELP_INFO=""
    {
        set +e
        HELP_INFO=$(cat <<EOF
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
    local other_environment_variables=$(compgen -v | grep -v 'PWD|OSTYPE|BASH|USER|HOME|TERM|OLDPWD|HOSTNAME')

    local user_input="$1"
    local command_history=$(_get_command_history 20)
    local help_message=$(_get_help_message "$user_input")
    local prompt="User command: \`$user_input\`

# Terminal Context
## Environment variables
 * User name: \$USER=$USER
 * Current directory: \$PWD=$PWD
 * Previous directory: \$OLDPWD=$OLDPWD
 * Home directory: \$HOME=$HOME
 * Operating system: \$OSTYPE=$OSTYPE
 * Shell: \$BASH=$BASH
 * Terminal type: \$TERM=$TERM
 * Hostname: \$HOSTNAME=$HOSTNAME

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
$(ls -lt | head -n 20)
\`\`\`

## Help Information
$help_message

# List of suggested completions or commands:

YOU MUST provide a list of two to five possible completions or rewritten commands here
DO NOT wrap the commands in backticks or quotes such as \`command\` or "command" or ```command```

Each command must be on a new line and must not span multiple lines
Each must be a valid command or set of commands

Please focus on the user's intent, recent commands, and the current environment when brainstorming completions.

Begin your list of completions, suggestions, or rewritten commands below this line:
"
    echo "$prompt"

}

# Constructs the payload for the OpenAI API request
_build_payload() {
    local user_input="$1"
    local prompt=$(_build_prompt "$user_input")

    local payload=$(jq -cn --arg system_prompt "$SYSTEM_MESSAGE_PROMPT" --arg prompt_content "$prompt" '{
        model: "gpt-3.5-turbo",
        messages: [
            {role: "system", content: $system_prompt},
            {role: "user", content: $prompt_content}
        ],
        temperature: 0.0
    }')
    echo "$payload"
}


openai_completion() {
    local default_user_input="write the three most likely commands for the user given their provided information"
    local user_input=${@:-$default_user_input}

    # Ensure the API key is set
    if [[ -n "$OPENAI_API_KEY" ]]; then
        local api_key="$OPENAI_API_KEY"
    else
        local config_file="$HOME/.autocomplete-sh"
        if [[ -f "$config_file" ]]; then
            local api_key=$(awk '/api_key:/ {print $2}' "$config_file")
        else
            echo_error "Please set the OPENAI_API_KEY environment variable or create a ~/.autocomplete-sh YAML configuration file with the 'api_key' field."
            return
        fi
    fi
    local payload=$(_build_payload "$user_input")
    local response=$(\curl -s -w "%{http_code}" https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $api_key" \
  -d "$payload")

    local status_code=$(echo "$response" | tail -n1)
    if [[ $status_code -eq 200 ]]; then
        local response_body=$(echo "$response" | sed '$d')
        local content=$(echo "$response_body" | jq -r '.choices[0].message.content')
        # for each line in content, remove any lines starting with ``` or blank lines
        local processed_content=$(echo "$content" | grep -v '^\s*```'  | sed '/^\s*$/d')
        echo $processed_content
    else
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
                echo_error "Error: Unexpected status code $status_code received from the API."
                ;;
        esac
        echo ""
    fi
}


###############################################################################
#
# Telemetry Functions
#
###############################################################################
# These are opt-in functions that collect data to help improve the tool
# No personal information is collected and the data is anonymized to the best of our ability
# This is not implemented yet but will be in the future

machine_signature() {
    local signature=$(echo "$(uname -a) $user_name" | md5sum | cut -d ' ' -f 1)
    echo "$signature"
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
    local current_word="${COMP_WORDS[COMP_CWORD]}"

    # Get the default completion function for the command
    local cmd="${COMP_WORDS[0]}"
    local default_func
    default_func=$(_get_default_completion_function "$cmd")

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
            readarray -t COMPREPLY <<< $(echo "$file_completions")
        fi
    fi
}

_autocompletesh() {
    local command="${COMP_WORDS[0]}"
    local current="${COMP_WORDS[COMP_CWORD]}"
    
    # Attempt to get default completions first
    _default_completion
    
    # If COMPREPLY is not empty, use it; otherwise, use OpenAI API completions
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        # Prepare input for the language model API
        local user_input="$command $current"
        local completions=$(openai_completion "$user_input" || true)

        # If OpenAI API returns completions, use them
        if [[ -n "$completions" ]]; then
            # Clean up the results, if there is only one line in $completions
            # and that line starts with $command, 
            # remove the $command from the line beggining of the line
            if [[ $(echo "$completions" | wc -l) -eq 1 ]]; then
                local first_line=$(echo "$completions" | head -n 1)
                if [[ "$first_line" == "$command"* ]]; then
                    readarray -t COMPREPLY <<< "$(echo "$first_line" | sed "s/$command[[:space:]]*//")"
                else
                    readarray -t COMPREPLY <<< "$completions"
                fi
            else
                readarray -t COMPREPLY <<< "$completions"
            fi
        fi
    fi
}


###############################################################################
#
# CLI ENTRY POINT
#
###############################################################################


###############################################################################
#
# ENABLE CLI COMPLETION
#
###############################################################################

# Set as the default completion function (-D )
# Also enable for empty commands (-E)
# Allow fallback to default completion function (-o default)
complete -D -E -F _autocompletesh -o default
