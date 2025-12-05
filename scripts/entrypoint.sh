#!/usr/bin/env bash
set -euo pipefail

echo "-----------------------------------------------"
echo "Initializing electrs container environment..."

# Apply umask early
umask "${UMASK:-022}"

# Defaults
APP_USER="${APP_USER:-electrs}"
APP_USER_HOME="${APP_USER_HOME:-/home/${APP_USER}}"
DATA_DIR="${DATA_DIR:-/data}"
DB_DIR="${DATA_DIR}/db"
CONF_FILE="${DATA_DIR}/electrs.toml"

# Resolve target uid/gid
TARGET_UID="${APP_UID:-$(id -u ${APP_USER})}"
TARGET_GID="${APP_GID:-$(id -g ${APP_USER})}"

echo "-----------------------------------------------"
echo "APP_USER=${APP_USER} UID=${TARGET_UID} GID=${TARGET_GID}"
echo "DATA_DIR=${DATA_DIR} CONF_FILE=${CONF_FILE}"

# Fix home ownership
chown -R "$TARGET_UID:$TARGET_GID" "$APP_USER_HOME"

# Ensure data dir exists and is owned by the image user (ownership already set in Dockerfile)
mkdir -p "${DB_DIR}/bitcoin"
chown -R "${TARGET_UID}:${TARGET_GID}" "${DB_DIR}"

# quick write-test (fail with clear message if host mount not writable)
TESTFILE="${DATA_DIR}/.perm_test"
if ! touch "${TESTFILE}" 2>/dev/null; then
    echo "ERROR: ${DATA_DIR} is not writable by container. On Unraid: chown -R 99:100 ${DATA_DIR} (or set proper permissions)."
    echo "Cannot continue."
    exit 1
fi
rm -f "${TESTFILE}" || true

# If no config present, generate a minimal electrs.toml (non-destructive)
if [ ! -f "${CONF_FILE}" ]; then
    echo "No config found - generating ${CONF_FILE} ..."
    BITCOIND_HOST="${BITCOIND_HOST:-bitcoind}"
    BITCOIND_PORT="${BITCOIND_PORT:-8332}"

    cat > "${CONF_FILE}" <<EOF
network = "bitcoin"
daemon_rpc_addr = "${BITCOIND_HOST}:${BITCOIND_PORT}"
daemon_rpc_user = "${BTC_RPC_USER:-}"
daemon_rpc_pass = "${BTC_RPC_PASS:-}"
db_path = "${DB_DIR}"
electrum_rpc_addr = "0.0.0.0:50001"
EOF

    # set sensible perms for config
    chown ${TARGET_UID}:${TARGET_GID} "${CONF_FILE}" || true
    chmod 0640 "${CONF_FILE}" || true
    echo "Generated ${CONF_FILE}:"
    sed -n '1,200p' "${CONF_FILE}" || true
else
    echo "Using existing ${CONF_FILE}"
fi

# If the first arg is "electrs" (default CMD), replace with full command including --conf.
if [ "${1:-}" = "electrs" ]; then
    set -- electrs --conf "${CONF_FILE}"
fi

# If user passed flags like --help or -v, allow electrs to run with those flags
if [[ "${1:0:1}" = "-" ]]; then
    set -- electrs "$@"
fi
echo "-----------------------------------------------"
echo "Starting command as user ${APP_USER}: $*"
echo "-----------------------------------------------"
cd "${DATA_DIR}"
exec gosu "${TARGET_UID}:${TARGET_GID}" "$@"
