#!/bin/sh
set -eu

# Autocomplete.sh installer
ACSH_VERSION="v0.6.0"
BRANCH_OR_VERSION=${1:-$ACSH_VERSION}
REPO_RAW="https://raw.githubusercontent.com/closedloop-technologies/autocomplete-sh/${BRANCH_OR_VERSION}"

log() { printf '%s\n' "$*"; }
err() { printf 'ERROR: %s\n' "$*" >&2; }

detect_shell() {
    if [ -n "${ZSH_VERSION:-}" ]; then
        echo "zsh"
    elif [ -n "${BASH_VERSION:-}" ]; then
        echo "bash"
    else
        parent_shell=$(ps -p "${PPID:-0}" -o comm= 2>/dev/null || true)
        case "$parent_shell" in
            *zsh*) echo "zsh" ;;
            *bash*) echo "bash" ;;
            *) basename "${SHELL:-sh}" ;;
        esac
    fi
}

fetch_file() {
    src=$1
    dest=$2
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$src" -o "$dest"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$src"
    else
        err "curl or wget is required to download Autocomplete.sh."
        exit 1
    fi
}

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        err "$1 is required."
        case "$1" in
            jq|bc)
                log "Install on Ubuntu/Debian: sudo apt-get install jq bc"
                log "Install on macOS: brew install jq bc"
                ;;
        esac
        exit 1
    fi
}

install_from_repo_or_local() {
    script_name=$1
    destination=$2
    if [ "$BRANCH_OR_VERSION" = "dev" ]; then
        if [ -f "./$script_name" ]; then
            cp "./$script_name" "$destination"
        else
            err "Local $script_name file not found. Run this installer from the repository root or pass a branch/tag."
            exit 1
        fi
    else
        fetch_file "$REPO_RAW/$script_name" "$destination"
    fi
    chmod +x "$destination"
}

install_zsh_integration() {
    zshrc=${ACSH_ZSHRC:-"$HOME/.zshrc"}
    shim_dir=${ACSH_HOME:-"$HOME/.autocomplete"}
    shim="$shim_dir/autocomplete.zsh"
    mkdir -p "$shim_dir"
    install_from_repo_or_local "autocomplete.zsh" "$shim"
    touch "$zshrc"
    if ! grep -qF '# Autocomplete.sh begin' "$zshrc"; then
        {
            echo "# Autocomplete.sh begin"
            echo "export ACSH_BASH_IMPL=\"$INSTALL_LOCATION\""
            echo "source \"$shim\" enable"
            echo "# Autocomplete.sh end"
        } >> "$zshrc"
        log "Added zsh integration to $zshrc"
    else
        log "Autocomplete.sh zsh integration already exists in $zshrc"
    fi
    log "Run: source $zshrc"
}

SHELL_TYPE=$(detect_shell)
INSTALL_DIR="${ACSH_INSTALL_DIR:-$HOME/.local/bin}"
INSTALL_LOCATION="$INSTALL_DIR/autocomplete"

if [ ! -d "$INSTALL_DIR" ]; then
    if mkdir -p "$INSTALL_DIR" 2>/dev/null; then
        :
    else
        INSTALL_DIR="/usr/local/bin"
        INSTALL_LOCATION="$INSTALL_DIR/autocomplete"
    fi
fi

require_command jq
require_command bc
install_from_repo_or_local "autocomplete.sh" "$INSTALL_LOCATION"

case "$SHELL_TYPE" in
    bash)
        if ! command -v _init_completion >/dev/null 2>&1; then
            if [ -f /usr/share/bash-completion/bash_completion ]; then
                # shellcheck disable=SC1091
                . /usr/share/bash-completion/bash_completion
            elif [ -f /etc/bash_completion ]; then
                # shellcheck disable=SC1091
                . /etc/bash_completion
            else
                log "Warning: bash-completion is not currently sourced. File completion fallback will still work."
            fi
        fi
        "$INSTALL_LOCATION" install
        ;;
    zsh)
        install_zsh_integration
        ;;
    *)
        log "Installed the autocomplete CLI to $INSTALL_LOCATION."
        log "Shell integration currently supports bash and zsh best. Run: autocomplete --help"
        ;;
esac

log "Installed autocomplete CLI to $INSTALL_LOCATION"
