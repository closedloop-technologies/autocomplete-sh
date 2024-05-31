#!/bin/bash
set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "autocomplete.sh - jq is not installed. Please install it using the following command: \`sudo apt-get install jq\`" >&2
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


machine_signature() {
    local signature=$(echo "$(uname -a) $user_name" | md5sum | cut -d ' ' -f 1)
    echo "$signature"
}

# Get the last 20 commands from the bash history
# GOTCHA: The history only populate if you run the command in the same terminal.  If you run it 
# in a ./autocomplete_api.sh, it will not be populated since that runs in a different environment
_get_command_history() {
    local HISTORY_LIMIT=${1:-20}
    echo "$(history | tail -n $HISTORY_LIMIT)"
}

_get_help_message() {
    # Store the output of ffmpeg --help in HELP_INFO
    local USER_INPUT="$1"
    local HELP_INFO=""

    # Attempt to capture the help information
    {
        set +e
        HELP_INFO=$(cat <<EOF
    $($USER_INPUT --help 2>&1)
EOF
    )
        set -e
    } || HELP_INFO="No help information available"
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
Provide a list of two to five possible completions or rewritten commands here
Each on a new line
Each must be a valid command or set of commands
Focus on the user's intent, recent commands, and the current environment.

Completions or rewritten commands here:
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
            echo "autocomplete.sh - Please set the OPENAI_API_KEY environment variable or create a ~/.autocomplete-sh YAML configuration file with the 'api_key' field." >&2
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
                echo "autocomplete.sh - Bad Request: The API request was invalid or malformed." >&2
                ;;
            401)
                echo "autocomplete.sh - Unauthorized: The provided API key is invalid or missing." >&2
                ;;
            429)
                echo "autocomplete.sh - Too Many Requests: The API rate limit has been exceeded." >&2
                ;;
            500)
                echo "autocomplete.sh - Internal Server Error: An unexpected error occurred on the API server." >&2
                ;;
            *)
                echo "autocomplete.sh - Error: Unexpected status code $status_code received from the API." >&2
                ;;
        esac
        echo ""
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
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    
    # Get the default completion function for the command
    local cmd="${COMP_WORDS[0]}"
    local default_func
    default_func=$(_get_default_completion_function "$cmd")
    
    # If a default completion function exists, call it
    if [[ -n "$default_func" ]]; then
        "$default_func"
    else
        # Fallback if no default completion function is found
        COMPREPLY=( $(compgen -f -- "$current_word") )
    fi
}

_custom_completion() {
    local command="${COMP_WORDS[0]}"
    local current="${COMP_WORDS[COMP_CWORD]}"
    
    # Attempt to get default completions first
    _default_completion
    
    # If COMPREPLY is not empty, use it; otherwise, use OpenAI API completions
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        # Prepare input for the language model API
        local user_input="$command $current"

        # Get completions from the OpenAI API (assuming openai_completion is defined)
        local completions
        # completions=$(openai_completion "$user_input" 2>/dev/null)
        completions="FOLLOW THE WHITE RABBIT"
        
        # If OpenAI API returns completions, use them
        if [[ -n "$completions" ]]; then
            readarray -t COMPREPLY <<< "$completions"
        fi
    fi
}

# Register the completion function for a specific command
# complete -F _custom_completion your_command


# # Register the completion function for a specific command
# complete -F _custom_completion your_command


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
complete -D -E -F _custom_completion -o default


# complete -D -F _custom_completion ac
# openai_completion "$@"