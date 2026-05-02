#!/usr/bin/env bash
set -euo pipefail

echo "-----------------------------------------------"
echo "Initializing electrs container environment..."
echo "-----------------------------------------------"

# Unraid-style dynamic user/group
PUID=${PUID:-99}
PGID=${PGID:-100}
UMASK=${UMASK:-002}

if ! [[ "$PUID" =~ ^[0-9]+$ ]] || ! [[ "$PGID" =~ ^[0-9]+$ ]]; then
    echo "Error: PUID and PGID must be integers (got PUID='$PUID' PGID='$PGID')" >&2
    exit 1
fi

APP_USER=electrs
APP_HOME=/home/electrs

# Apply umask
umask "$UMASK"

# Ensure a group with PGID exists; create one named $APP_USER if not
if ! getent group "$PGID" >/dev/null; then
    echo "Creating group $APP_USER with GID $PGID"
    groupadd -g "$PGID" "$APP_USER"
fi

# Ensure user $APP_USER exists with the correct UID/GID
if id -u "$APP_USER" >/dev/null 2>&1; then
    # User exists: update UID and primary group if required
    if [ "$(id -u "$APP_USER")" != "$PUID" ]; then
        echo "Updating UID of $APP_USER → $PUID"
        usermod -o -u "$PUID" "$APP_USER"
    fi
    if [ "$(id -g "$APP_USER")" != "$PGID" ]; then
        echo "Updating primary group of $APP_USER → $PGID"
        usermod -g "$PGID" "$APP_USER"
    fi
else
    echo "Creating user $APP_USER with UID $PUID GID $PGID"
    useradd -K UID_MIN=1 -K UID_MAX=65535 -u "$PUID" -g "$PGID" -d "$APP_HOME" -s /usr/sbin/nologin "$APP_USER"
fi

# Ensure folders exist
mkdir -p /data "$APP_HOME"

# Fix ownership of /data only if needed
CURRENT_UID=$(stat -c %u /data || echo 0)
CURRENT_GID=$(stat -c %g /data || echo 0)

if [ "$CURRENT_UID" != "$PUID" ] || [ "$CURRENT_GID" != "$PGID" ]; then
    echo "Correcting ownership of /data ..."
    chown -R "$PUID:$PGID" /data || echo "Warning: chown /data failed (read-only mount?)"
fi

echo "-----------------------------------------------"
echo "Starting electrs as UID:$PUID GID:$PGID"
echo "Using DATA_DIR: /data"
echo "Command: $*"
echo "-----------------------------------------------"
exec gosu "$PUID:$PGID" electrs "$@"
