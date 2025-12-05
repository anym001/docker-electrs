#!/usr/bin/env bash
#set -euo pipefail

# Debug
set +e
set -u
set -x
set -o pipefail

echo "-----------------------------------------------"
echo "DEBUG: Starting entrypoint.sh"
echo "-----------------------------------------------"

echo "-----------------------------------------------"
echo "Initializing electrs container environment..."
echo "-----------------------------------------------"

# Apply umask early
umask "${UMASK:-022}"

# Defaults
APP_USER_HOME="${APP_USER_HOME:-/home/$APP_USER}"
DATA_DIR="${DATA_DIR:-/data}"
DB_DIR="${DATA_DIR}/db"
CONF_FILE="${DATA_DIR}/electrs.toml"

# Resolve target uid/gid
TARGET_UID="${PUID:-$(id -u "$APP_USER")}"
TARGET_GID="${PGID:-$(id -g "$APP_USER")}"

# Update group if needed
if [ "$(id -g "$APP_USER")" != "$TARGET_GID" ]; then
    echo "Updating GID -> $TARGET_GID"
    groupmod -o -g "$TARGET_GID" "$APP_USER"
fi

# Update user if needed
if [ "$(id -u "$APP_USER")" != "$TARGET_UID" ]; then
    echo "Updating UID -> $TARGET_UID"
    usermod -o -u "$TARGET_UID" "$APP_USER"
fi

# Fix home ownership
chown -R "$TARGET_UID:$TARGET_GID" "$APP_USER_HOME"

# Ensure datadir exists
mkdir -p "$DB_DIR"

# Fix ownership if mismatch
CURRENT_UID=$(stat -c %u "$DATA_DIR")
CURRENT_GID=$(stat -c %g "$DATA_DIR")

if [ "$CURRENT_UID" != "$TARGET_UID" ] || [ "$CURRENT_GID" != "$TARGET_GID" ]; then
    echo "Fixing ownership and permissions of DATA_DIR..."
    chown -R "$TARGET_UID:$TARGET_GID" "$DATA_DIR"
fi

# Apply permissions (directories only)
find "$DATA_DIR" -type d -exec chmod "$DATA_PERM" {} \;

# Config handling
if [ -f "$CONF_FILE" ]; then
    echo "Using existing electrs.toml at $CONF_FILE"
else
    echo "No config found, generating electrs.toml..."

    BITCOIND_HOST="${BITCOIND_HOST:-bitcoind}"
    BITCOIND_PORT="${BITCOIND_PORT:-8332}"

    cat > "$CONF_FILE" <<EOF
network = "bitcoin"
daemon_rpc_addr = "${BITCOIND_HOST}:${BITCOIND_PORT}"
daemon_rpc_user = "${BTC_RPC_USER:-}"
daemon_rpc_pass = "${BTC_RPC_PASS:-}"
db_path = "${DB_DIR}"
electrum_rpc_addr = "0.0.0.0:50001"
EOF

    chown "$TARGET_UID:$TARGET_GID" "$CONF_FILE"
    chmod 0640 "$CONF_FILE"

    echo "Generated electrs.toml:"
    cat "$CONF_FILE"
fi

# Default command: electrs
if [[ $# -eq 0 ]]; then
    set -- electrs --conf "$CONF_FILE"
fi

# If first argument is a flag, prepend electrs
if [[ "${1:0:1}" == "-" ]]; then
    set -- electrs "$@"
fi

echo "-----------------------------------------------"
echo "Starting electrs as UID:$TARGET_UID GID:$TARGET_GID"
echo "Using DATA_DIR: $DATA_DIR"
echo "Config file: $CONF_FILE"
echo "Command: $*"
echo "-----------------------------------------------"

cd "$DATA_DIR"

exec gosu "$TARGET_UID:$TARGET_GID" "$@"
