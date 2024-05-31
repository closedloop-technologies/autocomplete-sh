#!/bin/bash
set -e

# File structure
# The script should be placed in
# /usr/bin/autocomplete # if apt-get install autocomplete
# /usr/local/bin/autocomplete # if installed manually

# Configuration Files
# ~/.autocomplete/config
# ~/.autocomplete/cache/...

# Usage
# install
# remove
# config
# config set <key> <value>
# enable
# disable
# command --dry-run # runs the autocomplete command
show_help() {
    echo "autocomplete.sh - LLM Powered Bash Completion"
    echo "Usage: autocomplete [options] command"
    echo "       autocomplete [options] install|remove|config|enable|disable|command|--help"
    echo
    echo "autocomplete.sh is a script to enhance bash completion with LLM capabilities."
    echo
    echo "Once installed and enabled, it will provide suggestions for the current command."
    echo "Just by pressing the Tab key, you can get the most likely completion for the command."
    echo "It provides various commands to manage and configure the autocomplete features."
    echo
    echo "Most used commands:"
    echo "  install             Install the autocomplete script"
    echo "  remove              Remove the autocomplete script"
    echo "  config              Show the configuration file"
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
    local config_file="$HOME/.autocomplete/config"
    if [ ! -f "$config_file" ]; then
        echo "Configuration file not found: $config_file"
        echo "Run autocomplete install"
        return
    fi
}

config_command() {
    local command="${@:2}"
    # If command is empty, show the configuration file
    if [ -z "$command" ]; then
        show_config
        return
    fi
    # If command is set, show the configuration value
    # command should be in the format `set <key> <value>`
    if [ "$2" == "set" ]; then
        local key="$3"
        local value="$4"
        if [ -z "$key" ]; then
            echo "SyntaxError: expected \`autocomplete config set <key> <value>\`" >&2
            return
        fi
        echo "Setting configuration key \`$key\` to value \`$value\`"
        return
    fi
    echo "SyntaxError: expected \`autocomplete config set <key> <value>\`" >&2
}

install_command() {
    echo "install_command"
}

remove_command() {
    echo "remove_command"
}

enable_command() {
    echo "enable_command"
}

disable_command() {
    echo "disable_command"
}

command_command() {
    # Remove the first argument from $@
    local command="${@:2}"

    # Check if second argument is defined
    if [ -z "$command" ]; then
        echo "SyntaxError: expected \`autocomplete command [--dry-run] <command>\`" >&2
        return
    fi

    if [ "$2" == "--dry-run" ]; then
        echo "TODO Dry run"
        return
    fi
    source autocomplete_api.sh "$command"
}

# What is difference between $1 and $@?
# $1 is the first argument passed to the script
# $@ is all the arguments passed to the script

case "$1" in
    "--help")
        show_help 
        ;;
    install)
        install_command
        ;;
    remove)
        remove_command
        ;;
    config)
        config_command $@
        ;;
    enable)
        enable_command
        ;;
    disable)
        disable_command
        ;;
    command)
        command_command $@
        ;;
    *)
        show_help
        ;;
esac