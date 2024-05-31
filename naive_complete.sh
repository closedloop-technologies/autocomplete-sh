#!/bin/bash
set -e

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "autocomplete.sh - jq is not installed. Please install it using the following command: \`sudo apt-get install jq\`" >&2
fi

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
        # Generate default completions using the 'compgen' command
        local file_completions
        if [[ -z "$current_word" ]]; then
            file_completions=$(compgen -f --)
        else
            file_completions=$(compgen -f -- "$current_word")
        fi
        if [[ -n "$file_completions" ]]; then
            readarray -t COMPREPLY <<< $(echo "$file_completions")
        # else
        #     echo "no file completions"
        fi
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
        # local user_input="$command $current"
        local completions="FOLLOW THE WHITE RABBIT
WAKE UP NEO"

        # If OpenAI API returns completions, use them
        if [[ -n "$completions" ]]; then
            readarray -t COMPREPLY <<< "$completions"
        fi
    fi
}

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