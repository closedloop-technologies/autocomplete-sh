# Functions which help preserve user privacy by sanitizing user data

# Find and replace sensitive information in the command history
sanitize_history() {
    local history="$1"
    local sanitized_history=""

    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/\/[[:alnum:]_.-]\+\/[[:alnum:]_.-]\+/\/path\/to\/file/g')
        line=$(echo "$line" | sed 's/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/IP_ADDRESS/g')
        line=$(echo "$line" | sed 's/[A-Za-z0-9._%+-]\+@[A-Za-z0-9.-]\+\.[A-Z|a-z]\{2,\}/EMAIL_ADDRESS/g')
        line=$(echo "$line" | sed 's/https\?:\/\/[[:alnum:]_.-]\+\.[[:alnum:]_.-]\+/URL/g')
        line=$(echo "$line" | sed 's/[[:alnum:]_-]\+:[[:alnum:]_-]\+/USER:GROUP/g')

        sanitized_history+="$line\n"
    done <<< "$history"

    echo "$sanitized_history"
}