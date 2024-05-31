#!/bin/bash
set -e


_custom_completion() {
    local user_input="${COMP_LINE}"
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    local current_directory="$PWD"
    local operating_system="$OSTYPE"
    local shell_program="$BASH"

    if [[ -n "$API_OPENAI" ]]; then
        local api_key="$API_OPENAI"
    else
        local config_file="$HOME/.autocomplete-sh"
        if [[ -f "$config_file" ]]; then
            local api_key=$(awk '/api_key:/ {print $2}' "$config_file")
        else
            echo "API key not found. Please set the API_OPENAI environment variable or create a ~/.autocomplete-sh YAML configuration file with the 'api_key' field."
            return
        fi
    fi

    # local history=$(history | awk '{$1=""; sub(/^[ \t]+/, ""); print}' | tail -n 10)
    local sanitized_history=$(sanitize_recent_history "10")

    local env_vars=$(printenv | awk -F= '{print $1}' | tr '\n' ',')
    local masked_env_vars=$(_mask_env_vars "$env_vars")

    # Update command history
    command_history+=("$user_input")

    # Limit command history to the last 20 entries
    if [ ${#command_history[@]} -gt 20 ]; then
        command_history=("${command_history[@]:1}")
    fi

    local history_str=$(IFS=$'\n'; echo "${command_history[*]}")

    local prompt="User command: $user_input
Current directory: $current_directory
Operating system: $operating_system
Shell: $shell_program

Command history:
$history_str

Environment variables (masked):
$masked_env_vars

Generate relevant and concise auto-complete suggestions for the given user command in the context of the current directory, operating system, command history, and masked environment variable names. Provide suggestions for command options, arguments, file paths, or any other relevant information that can assist the user in completing the command accurately.

Suggestions:
1.
2.
3."

    local cache_dir="$HOME/.autocomplete_cache"
    local cache_file="$cache_dir/$(echo "$user_input" | md5sum | cut -d' ' -f1)"

    if [[ -f "$cache_file" ]]; then
        local cached_completions=$(cat "$cache_file")

        if [[ $COMP_TYPE == 9 ]]; then
            COMPREPLY=( $(compgen -W "$cached_completions" -- "$current_word") )

            touch "$cache_file"

            return
        fi
    fi

    local timestamp=$(date +%Y-%m-%d_%H:%M:%S)
    local user_id=$(echo "$USER" | sha256sum | cut -d ' ' -f 1)
    local session_id=$RANDOM
    local command="$user_input"
    local completion_accepted=false
    local selected_completion=""
    local api_response_time=0
    local error=""

    local start_time=$(date +%s%3N)

    local response=$(curl -s -w "\n%{http_code}" -X POST -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "{\"prompt\": \"$prompt\"}" "https://api.example.com/completions")

    local end_time=$(date +%s%3N)
    api_response_time=$((end_time - start_time))

    local response_body=$(echo "$response" | sed '$d')
    local status_code=$(echo "$response" | tail -n1)

    if [[ $status_code -eq 200 ]]; then
        local suggestions=$(echo "$response_body" | jq -r '.suggestions[]')
        COMPREPLY=( $(compgen -W "$suggestions" -- "$current_word") )

        for ((i=0; i<${#COMPREPLY[@]}; i++)); do
            if [[ "${COMPREPLY[i]}" == "$current_word"* ]]; then
                selected_completion="${COMPREPLY[i]}"
                completion_accepted=true
                break
            fi
        done

        mkdir -p "$cache_dir"
        echo "$suggestions" > "$cache_file"

        local cache_size=$(ls -1 "$cache_dir" | wc -l)
        if [[ $cache_size -gt 100 ]]; then
            local files_to_evict=$((cache_size - 100))
            ls -t "$cache_dir" | tail -n "$files_to_evict" | xargs -I{} rm "$cache_dir/{}"
        fi
    else
        case $status_code in
            400)
                error="Bad Request: The API request was invalid or malformed."
                ;;
            401)
                error="Unauthorized: The provided API key is invalid or missing."
                ;;
            429)
                error="Too Many Requests: The API rate limit has been exceeded."
                ;;
            500)
                error="Internal Server Error: An unexpected error occurred on the API server."
                ;;
            *)
                error="Error: Unexpected status code $status_code received from the API."
                ;;
        esac

        COMPREPLY=()
        _default "$@"
        return
    fi

    local telemetry_data=$(cat <<EOF
{
    "timestamp": "$timestamp",
    "user_id": "$user_id",
    "session_id": "$session_id",
    "command": "$command",
    "completion_accepted": $completion_accepted,
    "selected_completion": "$selected_completion",
    "api_response_time": $api_response_time,
    "error": "$error"
}
EOF
)

    curl -X POST -H "Content-Type: application/json" -d "$telemetry_data" https://api.autocomplete.sh/usage
}

_default() {
    local current_word="${COMP_WORDS[COMP_CWORD]}"
    local default_completions=$(compgen -f -- "$current_word")
    COMPREPLY=( $default_completions )
}

show_help() {
    echo "Usage: autocomplete [enable|disable|update]"
}

show_history() {
    echo "Sanitized History:"
    echo $(sanitize_recent_history 10)
}


enable_completion() {
    echo 'Enabling custom Bash completion...'
    echo 'source /usr/local/bin/custom_completion' >> ~/.bashrc
    echo 'Custom Bash completion enabled.'
}

disable_completion() {
    echo 'Disabling custom Bash completion...'
    sed -i '/source \/usr\/local\/bin\/custom_completion/d' ~/.bashrc
    echo 'Custom Bash completion disabled.'
}

update_completion() {
    echo 'Updating custom Bash completion...'
    # Perform any necessary update tasks
    echo 'Custom Bash completion updated.'
}

case "$1" in
    "--help")
        show_help
        ;;
    "show-history")
        show_history
        ;;
    enable)
        enable_completion
        ;;
    disable)
        disable_completion
        ;;
    update)
        update_completion
        ;;
    # *)
    #     complete -D -F _custom_completion
    #     ;;
esac