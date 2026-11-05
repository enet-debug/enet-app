#!/usr/bin/env bash
# Consistent SQLite online backup (includes committed WAL content).
set -euo pipefail

DB_PATH="${ENET_DB_PATH:-/var/lib/enet-api/enet.sqlite}"
BACKUP_DIR="${ENET_BACKUP_DIR:-/var/backups/enet-api}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="$BACKUP_DIR/enet-$STAMP.sqlite"

if ! command -v sqlite3 >/dev/null 2>&1; then
  echo "sqlite3 CLI is required for backups." >&2
  exit 1
fi
if [[ ! -f "$DB_PATH" ]]; then
  echo "Database file not found: $DB_PATH" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"
umask 077
sqlite3 "$DB_PATH" ".backup '$BACKUP_FILE'"
test -s "$BACKUP_FILE"
chmod 0600 "$BACKUP_FILE"
find "$BACKUP_DIR" -maxdepth 1 -type f -name 'enet-*.sqlite' -mtime +14 -delete
echo "SQLite backup created: $BACKUP_FILE"
