#!/bin/bash

# AutoComplete.sh - brings LLMs into the Terminal
# This install script downloads the latest version of the LLMs

# The URL of the latest version of the LLMs
ACSH_VERSION="0.3.4"
URL="https://raw.githubusercontent.com/closedloop-technologies/autocomplete-sh/v${ACSH_VERSION}/autocomplete.sh"

# The default location to install the LLMs
INSTALL_LOCATION="$HOME/.local/bin/autocomplete"

# Check if INSTALL_LOCATION exists, if not, set to /usr/local/bin
if [ ! -d "$(dirname "$INSTALL_LOCATION")" ]; then
    INSTALL_LOCATION="/usr/local/bin/autocomplete"
fi

# Download the LLMs using WGET
wget -nv -O "$INSTALL_LOCATION" "$URL"

# Install the LLMs
chmod +x "$INSTALL_LOCATION"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed. Please install jq to continue."
    echo "For Ubuntu/Debian: sudo apt-get install jq"
    echo "For CentOS/RHEL: sudo yum install jq"
    echo "For macOS (using Homebrew): brew install jq"
fi

# Source bash-completion if _init_completion function does not exist
if ! type -t _init_completion &> /dev/null; then
    # shellcheck disable=SC1091
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    else
        echo "ERROR: Please ensure you have bash-completion installed and sourced."
        exit 1
    fi
fi

# Proceed with installation
"$INSTALL_LOCATION" install
