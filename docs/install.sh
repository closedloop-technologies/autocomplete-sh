#!/bin/bash

# AutoComplete.sh - brings LLMs into the Terminal
# This install script downloads the latest version of the LLMs

# The URL of the latest version of the LLMs
ACSH_VERSION="0.3.2"
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

# Check if the _init_completion function exists
if ! command -v _init_completion &> /dev/null; then
    echo "ERROR: Please ensure you have bash-completion installed and sourced."
else
    "$INSTALL_LOCATION" install
fi
