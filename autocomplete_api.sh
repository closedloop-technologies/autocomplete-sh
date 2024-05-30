#!/bin/bash
set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "autocomplete.sh - jq is not installed. Please install it using the following command:" >&2
    echo "sudo apt-get install jq" >&2
    exit 1
fi

# HISTFILE=~/.bash_history   # Or wherever you bash history file is
# set +o history
# command_history=()
SYSTEM_MESSAGE_PROMPT="You are a helpful bash_completion script. \
Generate relevant and concise auto-complete suggestion for the given user command \
in the context of the current directory, operating system, command history, \
and masked environment variable names. \
Only provide the single most likely command for the user given their provided information."


machine_signature() {
    local signature=$(echo "$(uname -a) $user_name" | md5sum | cut -d ' ' -f 1)
    echo "$signature"
}

# Constructs a LLM prompt with the user input and in-terminal contextual information
_build_prompt() {
    # Define contextual information for the completion request
    local other_environment_variables=$(compgen -v | grep -v 'PWD|OSTYPE|BASH|USER|HOME|TERM|OLDPWD|HOSTNAME')

    local user_input="$1"
    
    local command_history=($(history 1 | awk '{print $2}'))
    # local file_system=$(ls -lt | head -n 20)
    # echo "file_system: $file_system"

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

# Suggested completion:
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

_openai_completion() {
    local user_input="$@"

    echo "_openai $user_input"

    # Ensure the API key is set
    if [[ -n "$OPENAI_API_KEY" ]]; then
        local api_key="$OPENAI_API_KEY"
    else
        local config_file="$HOME/.autocomplete-sh"
        if [[ -f "$config_file" ]]; then
            local api_key=$(awk '/api_key:/ {print $2}' "$config_file")
        else
            echo "API key not found. Please set the OPENAI_API_KEY environment variable or create a ~/.autocomplete-sh YAML configuration file with the 'api_key' field."
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
        echo "$content"
    else
        local error=""
        case $status_code in
            400)
                error="autocomplete.sh - Bad Request: The API request was invalid or malformed."
                ;;
            401)
                error="autocomplete.sh - Unauthorized: The provided API key is invalid or missing."
                ;;
            429)
                error="autocomplete.sh - Too Many Requests: The API rate limit has been exceeded."
                ;;
            500)
                error="autocomplete.sh - Internal Server Error: An unexpected error occurred on the API server."
                ;;
            *)
                error="autocomplete.sh - Error: Unexpected status code $status_code received from the API."
                ;;
        esac
        echo "$error" >&2
        return 1 # Error
    fi
}

_openai_completion "$@"
