#!/bin/bash

# AutoComplete.sh - brings LLMs into the Terminal
# This install script downloads the latest version of the LLMs

# Copy this file to the appropriate location https://raw.githubusercontent.com/closedloop-technologies/autocomplete-sh/v0.1.0/autocomplete.sh
# Run the script to install the LLMs

# The URL of the latest version of the LLMs
URL="https://raw.githubusercontent.com/closedloop-technologies/autocomplete-sh/v0.2.1/autocomplete.sh"

# The location to install the LLMs
INSTALL_LOCATION="$HOME/.local/bin/autocomplete"

# Download the LLMs using WGET
wget -O "$INSTALL_LOCATION" "$URL"

# Install the LLMs
chmod +x "$INSTALL_LOCATION"
autocomplete install
