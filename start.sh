#! /bin/bash

# see https://github.com/Kilo-Org/kilocode/blob/main/apps/playwright-e2e/docker-entrypoint.sh

set -euo pipefail

git config --global user.name "$GH_USERNAME"
git config --global user.email "$GH_EMAIL"
git config --global credential.helper store
jj config set --user user.name "$GH_USERNAME" && jj config set --user user.email "$GH_EMAIL"

echo "https://${GH_USERNAME}:${GH_TOKEN}@github.com" > /root/.git-credentials

echo "Setting up environment..."

# Initialize D-Bus machine ID if it doesn't exist
if [[ ! -f /var/lib/dbus/machine-id ]]; then
    dbus-uuidgen > /var/lib/dbus/machine-id 2>/dev/null || true
fi

####### Set up D-Bus ######
# This is necessary to enable IPC messaging between core and webview
runtime_dir="/tmp/runtime-$(id -u)"
if [[ ! -d "$runtime_dir" ]]; then
    mkdir -p "$runtime_dir"
    chmod 700 "$runtime_dir"
fi
export XDG_RUNTIME_DIR="$runtime_dir"

# Start D-Bus session
if command -v dbus-launch >/dev/null 2>&1; then
    if dbus_output=$(dbus-launch --sh-syntax 2>/dev/null); then
        eval "$dbus_output"
        export DBUS_SESSION_BUS_ADDRESS
    else
        echo "Failed to start D-Bus session, continuing anyway"
    fi
else
    echo "dbus-launch not available, continuing anyway"
fi

echo "Setting up keyring services for VS Code secrets API..."

####### Set up Keyrings ######
# This is needed for VS Code secret storage to work properly
mkdir -p ~/.cache ~/.local/share/keyrings

# Set environment variables for keyring
export XDG_CURRENT_DESKTOP=Unity
export GNOME_KEYRING_CONTROL=1

# Start gnome-keyring with empty password (headless mode)
if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    # Initialize keyring with empty password
    if keyring_output=$(printf '\n' | gnome-keyring-daemon --unlock 2>/dev/null); then
        eval "$keyring_output" 2>/dev/null || true
    fi
    
    # Start keyring daemon
    if keyring_start=$(printf '\n' | gnome-keyring-daemon --start 2>/dev/null); then
        eval "$keyring_start" 2>/dev/null || true
        export GNOME_KEYRING_CONTROL
        echo "Keyring services initialized"
    else
        echo "Failed to start keyring daemon - VS Code will fall back to environment variables"
        export VSCODE_SECRETS_FALLBACK=true
    fi
else
    echo "gnome-keyring-daemon not available - VS Code will fall back to environment variables"
    export VSCODE_SECRETS_FALLBACK=true
fi

# Test keyring functionality (optional debugging)
if command -v secret-tool >/dev/null 2>&1 && [[ "${VSCODE_SECRETS_FALLBACK:-}" != "true" ]]; then
    if secret-tool store --label="test" test-key test-value 2>/dev/null; then
        secret-tool clear test-key test-value 2>/dev/null || true
        echo "Keyring functionality verified"
    else
        echo "Keyring test failed - enabling fallback mode"
        export VSCODE_SECRETS_FALLBACK=true
    fi
fi

# calude code does not respect the .claude folder and has no args to set it
ln -sf /root/.claude/claude.json /root/.claude.json  

# docker compose -f /stacks/*/docker-compose.yaml up -d

./stacks.js

/workspace/sync-setup.sh orchestrator

./sync-loop.sh both &

# watch -n 2 'jj git push --remote sync --allow-empty-description -c @-' &

# --ignore-last-opened --socket=/socket
#d tach -n /workspace/dtach/code-server 
# --user-data-dir=/workspace/code-server/data --extensions-dir=/workspace/code-server/extensions --auth=none

export VSCODE_CLI_USE_FILE_KEYCHAIN=1
export GITHUB_TOKEN=$GH_TOKEN

code-server --disable-telemetry --bind-addr=0.0.0.0:8086 --auth none --enable-proposed-api=true --disable-workspace-trust --app-name=darc --disable-getting-started-override /workspace/.vscode/orchestrator.code-workspace &

# dtach -c /workspace/dtach/main
pnpm dev
