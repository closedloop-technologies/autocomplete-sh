#!/bin/bash
set -e

# Requires  sudo apt-get install jq

# HISTFILE=~/.bash_history   # Or wherever you bash history file is
# set +o history
# command_history=()

_build_payload() {
    local user_input="$1"

    # Define contextual information for the completion request
    local current_directory="$PWD"
    local operating_system="$OSTYPE"
    local shell_program="$BASH"

    local system_prompt="You are a helpful bash_completion script.  \
Generate relevant and concise auto-complete suggestion for the given user command \
in the context of the current directory, operating system, command history, \
and masked environment variable names. \
Only provide the single most likely command for the user given their provided information."

    local prompt="User command: $user_input
Current directory: $current_directory
Operating system: $operating_system
Shell: $shell_program

Suggested completion:"

    local escaped_prompt=$(echo "$prompt" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')

    local payload=$(jq -n --arg system_prompt "$system_prompt" --arg prompt_content "$prompt" '{
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

    local response=$(curl -s -w "%{http_code}" https://api.openai.com/v1/chat/completions \
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