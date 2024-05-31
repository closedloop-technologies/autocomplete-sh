#!/bin/bash
HISTFILE=~/.bash_history
set +o history
get_recent_history() {
    # local recent_history=$(tail -n 10 "$HISTFILE")
    set -o history
    local recent_history=$(history | tail -n 10)
    set +o history
    echo $recent_history
}
get_recent_history
# echo $(history)
set -o history