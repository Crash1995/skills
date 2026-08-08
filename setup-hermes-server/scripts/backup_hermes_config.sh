#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_HOME_DIR="${HERMES_HOME:-/home/hermes/.hermes}"
BACKUP_ROOT=""

usage() {
  cat <<'EOF'
Usage: backup_hermes_config.sh [--home /home/hermes/.hermes] [--out DIR]

Creates a timestamped backup of Hermes config files, profile configs/SOUL.md,
skills, memories, cron files, and kanban.db when present.

The script does not print .env contents.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --home) HERMES_HOME_DIR="${2:?missing home}"; shift 2 ;;
    --out) BACKUP_ROOT="${2:?missing output dir}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$BACKUP_ROOT" ]; then
  BACKUP_ROOT="$HERMES_HOME_DIR/backups"
fi

STAMP="$(date -u +%Y%m%d-%H%M%S)"
DEST="$BACKUP_ROOT/hermes-config-$STAMP"
mkdir -p "$DEST"
chmod 700 "$DEST"

copy_if_exists() {
  local src="$1"
  local rel="$2"
  if [ -e "$src" ]; then
    mkdir -p "$DEST/$(dirname "$rel")"
    cp -a "$src" "$DEST/$rel"
    echo "copied $rel"
  fi
}

copy_if_exists "$HERMES_HOME_DIR/config.yaml" "config.yaml"
copy_if_exists "$HERMES_HOME_DIR/.env" ".env"
copy_if_exists "$HERMES_HOME_DIR/SOUL.md" "SOUL.md"
copy_if_exists "$HERMES_HOME_DIR/kanban.db" "kanban.db"
copy_if_exists "$HERMES_HOME_DIR/state.db" "state.db"
copy_if_exists "$HERMES_HOME_DIR/profiles" "profiles"
copy_if_exists "$HERMES_HOME_DIR/skills" "skills"
copy_if_exists "$HERMES_HOME_DIR/memories" "memories"
copy_if_exists "$HERMES_HOME_DIR/cron" "cron"

if [ -f "$DEST/.env" ]; then
  chmod 600 "$DEST/.env"
fi

echo "backup_dir=$DEST"
echo "Backup complete. Secret file contents were not printed."
