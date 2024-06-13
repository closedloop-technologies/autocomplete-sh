#!/bin/bash

# AutoComplete.sh - brings LLMs into the Terminal
# This install script downloads the latest version of the LLMs

# The URL of the latest version of the LLMs
ACSH_VERSION="0.2.7b"
URL="https://raw.githubusercontent.com/closedloop-technologies/autocomplete-sh/v${ACSH_VERSION}/autocomplete.sh"

# The location to install the LLMs
INSTALL_LOCATION="$HOME/.local/bin/autocomplete"

# Download the LLMs using WGET
wget -nv -O "$INSTALL_LOCATION" "$URL"

# Install the LLMs
chmod +x "$INSTALL_LOCATION"
autocomplete install
