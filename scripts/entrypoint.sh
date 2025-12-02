#!/usr/bin/env bash
set -euo pipefail

echo "-----------------------------------------------"
echo "Initializing electrs container environment..."
echo "-----------------------------------------------"

# Apply umask
umask "${UMASK:-022}"

# Ensure APP_USER_HOME is set
APP_USER_HOME="${APP_USER_HOME:-/home/$APP_USER}"

# Resolve target uid/gid
TARGET_UID="${PUID:-$(id -u "$APP_USER")}"
TARGET_GID="${PGID:-$(id -g "$APP_USER")}"

# Update group if needed
if [ "$(id -g "$APP_USER")" != "$TARGET_GID" ]; then
    echo "Updating GID → $TARGET_GID"
    groupmod -o -g "$TARGET_GID" "$APP_USER"
fi

# Update user if needed
if [ "$(id -u "$APP_USER")" != "$TARGET_UID" ]; then
    echo "Updating UID → $TARGET_UID"
    usermod -o -u "$TARGET_UID" "$APP_USER"
fi

# Ensure datadir exists
mkdir -p "$DATA_DIR/db"

# Fix ownership if empty or ownership mismatch
CURRENT_UID=$(stat -c %u "$FINAL_DATADIR")
CURRENT_GID=$(stat -c %g "$FINAL_DATADIR")

if [ -z "$(ls -A "$DATA_DIR")" ]; then
    echo "Fixing ownership and permissions of DATA_DIR..."
    chown -R "$TARGET_UID:$TARGET_GID" "$DATA_DIR"
    chmod -R "$DATA_PERM" "$DATA_DIR"
fi

# If no command was specified → default = electrs
if [[ $# -eq 0 ]]; then
    set -- electrs --conf /etc/electrs/electrs.toml
fi

# If first arg is a flag, prepend only "electrs"
if [[ "${1:0:1}" == "-" ]]; then
    set -- electrs "$@"
fi

echo "-----------------------------------------------"
echo "Starting electrs as UID:$TARGET_UID GID:$TARGET_GID"
echo "Using DATA_DIR: $DATA_DIR"
echo "Command: $*"
echo "-----------------------------------------------"
exec gosu "$TARGET_UID:$TARGET_GID" "$@"