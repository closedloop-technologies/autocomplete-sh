#!/bin/sh

# Autocomplete.sh installer for the Bash and Zsh runtimes.

ACSH_VERSION="v0.6.0"

usage() {
    cat <<EOF
Usage: $0 [options]

Options:
  --shell bash|zsh   Shell to install autocomplete for.
                     Default: detected from the basename of \$SHELL.
  --version REF|dev  Version to install: a git ref/tag (e.g. $ACSH_VERSION) or
                     "dev" to install the local ./autocomplete.sh (bash) or
                     ./autocomplete.zsh (zsh).
                     Default: $ACSH_VERSION.
  -h, --help         Show this help and exit.

Installs the autocomplete executable to \$HOME/.local/bin/autocomplete.
EOF
}

# --- Parse command line ---
SHELL_TYPE=""
VERSION="$ACSH_VERSION"

while [ "$#" -gt 0 ]; do
    case "$1" in
        --shell)
            if [ "$#" -lt 2 ]; then
                echo "ERROR: --shell requires an argument." >&2
                usage >&2
                exit 2
            fi
            SHELL_TYPE="$2"
            shift 2
            ;;
        --version)
            if [ "$#" -lt 2 ]; then
                echo "ERROR: --version requires an argument." >&2
                usage >&2
                exit 2
            fi
            VERSION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [ -z "$VERSION" ]; then
    echo "ERROR: --version must not be empty." >&2
    usage >&2
    exit 2
fi

# --- Resolve the shell (an explicit --shell wins) ---
if [ -z "$SHELL_TYPE" ]; then
    SHELL_TYPE="${SHELL##*/}"
fi

case "$SHELL_TYPE" in
    bash)
        SCRIPT_NAME="autocomplete.sh"
        ;;
    zsh)
        SCRIPT_NAME="autocomplete.zsh"
        ;;
    *)
        echo "ERROR: Unsupported shell '$SHELL_TYPE'. Only bash and zsh are supported." >&2
        echo "Pass --shell bash or --shell zsh explicitly, e.g.:" >&2
        echo "  $0 --shell bash" >&2
        usage >&2
        exit 1
        ;;
esac

# --- Target location (consistent basename; no /usr/local/bin fallback) ---
TARGET_DIR="$HOME/.local/bin"
TARGET="$TARGET_DIR/autocomplete"

# --- PATH prerequisite: fail before any target/startup mutation ---
case ":$PATH:" in
    *":$TARGET_DIR:"*) ;;
    *)
        echo "ERROR: $TARGET_DIR is not in PATH." >&2
        echo "Add it before installing, e.g.:" >&2
        echo "  export PATH=\"$TARGET_DIR:\$PATH\"" >&2
        exit 1
        ;;
esac

# --- Preflight: fail before any target/startup mutation ---
require_tool() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "ERROR: Required tool '$1' was not found in PATH." >&2
        exit 1
    fi
}

for tool in wget curl jq bc sha256sum mktemp timeout head; do
    require_tool "$tool"
done

require_tool "$SHELL_TYPE"

if [ "$SHELL_TYPE" = "bash" ]; then
    # Require a loadable bash-completion providing _comp_load.
    if ! bash -c 'if [ -f /usr/share/bash-completion/bash_completion ]; then . /usr/share/bash-completion/bash_completion; elif [ -f /etc/bash_completion ]; then . /etc/bash_completion; fi; command -v _comp_load >/dev/null 2>&1'; then
        echo "ERROR: bash-completion providing '_comp_load' is not available." >&2
        echo "Install bash-completion (e.g. 'apt-get install bash-completion' or" >&2
        echo "'brew install bash-completion') so that /usr/share/bash-completion/" >&2
        echo "bash_completion or /etc/bash_completion exists." >&2
        exit 1
    fi
fi

# --- Target directory: create if absent ---
if [ ! -d "$TARGET_DIR" ]; then
    if ! mkdir -p "$TARGET_DIR"; then
        echo "ERROR: Could not create $TARGET_DIR" >&2
        exit 1
    fi
fi

# --- Fetch to a temporary file beside the target (same filesystem => atomic mv) ---
STAGED_FILE="$(mktemp "$TARGET_DIR/.autocomplete.XXXXXX")" || {
    echo "ERROR: Could not create a temporary file in $TARGET_DIR" >&2
    exit 1
}
trap 'rm -f "$STAGED_FILE"' EXIT

if [ "$VERSION" = "dev" ]; then
    LOCAL_FILE="./$SCRIPT_NAME"
    if [ ! -f "$LOCAL_FILE" ]; then
        echo "ERROR: Local development file $LOCAL_FILE was not found." >&2
        echo "Run this installer from the repository root, or pass --version REF." >&2
        exit 1
    fi
    if ! cp "$LOCAL_FILE" "$STAGED_FILE"; then
        echo "ERROR: Could not copy $LOCAL_FILE" >&2
        exit 1
    fi
    echo "Copied local development $SCRIPT_NAME"
else
    URL="https://raw.githubusercontent.com/closedloop-technologies/autocomplete-sh/${VERSION}/$SCRIPT_NAME"
    if ! wget -nv -O "$STAGED_FILE" "$URL"; then
        echo "ERROR: wget failed to download $URL" >&2
        exit 1
    fi
    echo "Downloaded $SCRIPT_NAME from $URL"
fi

if [ ! -s "$STAGED_FILE" ]; then
    echo "ERROR: Fetched autocomplete content is empty." >&2
    exit 1
fi

# --- Syntax-check the fetched script with its target shell ---
case "$SHELL_TYPE" in
    bash)
        if ! bash -n "$STAGED_FILE"; then
            echo "ERROR: $SCRIPT_NAME failed the 'bash -n' syntax check." >&2
            exit 1
        fi
        ;;
    zsh)
        if ! zsh -n "$STAGED_FILE"; then
            echo "ERROR: $SCRIPT_NAME failed the 'zsh -n' syntax check." >&2
            exit 1
        fi
        ;;
esac

chmod 0755 "$STAGED_FILE"

# --- Install atomically ---
ROLLBACK_FILE="$TARGET_DIR/.autocomplete.rollback.$$"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
    if ! mv -f "$TARGET" "$ROLLBACK_FILE"; then
        echo "ERROR: Could not back up the existing $TARGET" >&2
        exit 1
    fi
fi

if ! mv -f "$STAGED_FILE" "$TARGET"; then
    if [ -e "$ROLLBACK_FILE" ] || [ -L "$ROLLBACK_FILE" ]; then
        mv -f "$ROLLBACK_FILE" "$TARGET"
    fi
    echo "ERROR: Could not install the executable at $TARGET" >&2
    exit 1
fi

# The runtime installer performs the atomic startup rewrite.
if "$TARGET" install; then
    rm -f "$ROLLBACK_FILE"
    echo "Done. autocomplete installed to $TARGET"
    exit 0
fi

# Runtime install failed: restore the previous version.
if [ -e "$ROLLBACK_FILE" ] || [ -L "$ROLLBACK_FILE" ]; then
    mv -f "$ROLLBACK_FILE" "$TARGET"
else
    rm -f "$TARGET"
fi
echo "ERROR: 'autocomplete install' failed; the previous version was restored." >&2
exit 1
