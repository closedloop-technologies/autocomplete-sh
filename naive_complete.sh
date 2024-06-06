#!/bin/bash

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

_completion_vars() {
    echo "BASH_COMPLETION_VERSINFO: ${BASH_COMPLETION_VERSINFO}"
    echo "COMP_CWORD: ${COMP_CWORD}"
    echo "COMP_KEY: ${COMP_KEY}"
    echo "COMP_LINE: ${COMP_LINE}"
    echo "COMP_POINT: ${COMP_POINT}"
    echo "COMP_TYPE: ${COMP_TYPE}"
    echo "COMP_WORDBREAKS: ${COMP_WORDBREAKS}"
    echo "COMP_WORDS: ${COMP_WORDS}"
}


_naive_completion() {
    # Read in the completions from a file /tmp/autocomplete_completions.txt
    local completions=$(cat /tmp/autocomplete_completions.txt | head -n 2)
    completions=$(echo "$completions" | sed 's/:/\\:/g')

    # save the results of _completion_vars to a file
    _completion_vars >> /tmp/autocomplete_vars.txt

    # TODO If COMP_TYPE != 9, then what should we do?
    # echo $COMP_TYPE
    
    # Attempt to get default completions first
    # _default_completion

    # If COMPREPLY is not empty, use it; otherwise, use OpenAI API completions
    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        # num_rows=$(echo "$completions" | wc -l)
        local user_input="${COMP_LINE}"
        COMPREPLY=()

        # Make the autocomplete think it is operating on a blank line
        COMP_CWORD=-1
        COMP_LINE=""
        COMP_POINT=0
        COMP_WORDS=()
        # tput el1
        # tput el
        local user_input_length=${#user_input}
        # echo $user_input_length
        # Shift cursor 22 spots to the left and clear the line
        # tput cub 22
        # tput el
        # set -x
        if [[ COMP_TYPE -eq 9 ]]; then
            # If the completion type is 9, then we need to replace the last word with the longest common substring
            # among the completions
            # split input to get command and comment at the end of the line like "command arg1 arg2 ... argn # this is a comment"
            local user_input_parts
            IFS='#' read -ra user_input_parts <<< "$user_input"
            local command="${user_input_parts[0]}"
            if [[ ${#user_input_parts[@]} -gt 1 ]]; then
                local comments="#$(IFS='#' ; echo "${user_input_parts[*]:1}")"
            else
                local comments=""
            fi

            # echo "Command: $command"
            # echo "Comments: $comments"

            local last_word=$(echo -n "$user_input" | awk '{print $NF}')
            local longest_common_substring=$(echo -n "$completions" | awk '{print $1}' | awk -F' ')
                        
            # if [[ $user_input_length -gt 0 ]]; then
            #     tput cub $user_input_length
            #     tput el
            # fi
            # # echo
            # # echo
            # echo -n "$longest_common_substring$comments"

        # else
        #     # If the completion type is 63, then we just need to display the completions
        #     if [[ $user_input_length -gt 0 ]]; then
        #         tput cub $user_input_length
        #         tput el
        #     fi
        #     echo -e "$completions"
        fi

        # set +x
        
        # _completion_vars

        # if [[ $num_rows -eq 1 ]]; then    
        #     local first_line=$(echo -n "$completions" | head -n 1)
        #     readarray -t COMPREPLY <<< "$(echo -n "$first_line" | sed "s/$command[[:space:]]*//")"
        # else
        #     readarray -t COMPREPLY <<< "$(echo "$completions")"
        # fi
        readarray -t COMPREPLY <<< $completions

        # Scenarios - if comp_type is 9, then it replaces the last word with the longest common substring among the completions
        # If 
        # If comp_type is 63, then it just displays the completions
        # What if there is only one completion?
    fi
}

# Set as the default completion function (-D )
# Also enable for empty commands (-E)
# Allow fallback to default completion function (-o default)
complete -D -E -F _naive_completion -o nospace
