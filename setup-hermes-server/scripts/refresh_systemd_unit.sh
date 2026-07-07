#!/usr/bin/env bash
set -Eeuo pipefail

RUN_AS_USER="hermes"
HOME_DIR="/home/hermes"
YES="0"
HERMES_BIN=""

usage() {
  cat <<'EOF'
Usage: refresh_systemd_unit.sh --yes [--user hermes] [--home /home/hermes] [--hermes-bin PATH]

Refreshes the systemd hermes-gateway.service definition using the Hermes user's
environment, then restarts the system gateway.

This changes a system service and should be run as root or through sudo.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --yes) YES="1"; shift ;;
    --user) RUN_AS_USER="${2:?missing user}"; shift 2 ;;
    --home) HOME_DIR="${2:?missing home}"; shift 2 ;;
    --hermes-bin) HERMES_BIN="${2:?missing hermes bin}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$HERMES_BIN" ]; then
  HERMES_BIN="$HOME_DIR/.local/bin/hermes"
fi

if [ "$YES" != "1" ]; then
  cat >&2 <<EOF
Refusing to change systemd without --yes.

Will run:
  HOME=$HOME_DIR USER=$RUN_AS_USER LOGNAME=$RUN_AS_USER HERMES_HOME=$HOME_DIR/.hermes \\
    $HERMES_BIN gateway restart --system
EOF
  exit 3
fi

if [ ! -x "$HERMES_BIN" ]; then
  echo "Hermes binary not found or not executable: $HERMES_BIN" >&2
  exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo HOME="$HOME_DIR" USER="$RUN_AS_USER" LOGNAME="$RUN_AS_USER" HERMES_HOME="$HOME_DIR/.hermes" \
      "$HERMES_BIN" gateway restart --system
  fi
  echo "Root is required and sudo is not available." >&2
  exit 1
fi

HOME="$HOME_DIR" USER="$RUN_AS_USER" LOGNAME="$RUN_AS_USER" HERMES_HOME="$HOME_DIR/.hermes" \
  "$HERMES_BIN" gateway restart --system

HOME="$HOME_DIR" USER="$RUN_AS_USER" LOGNAME="$RUN_AS_USER" HERMES_HOME="$HOME_DIR/.hermes" \
  "$HERMES_BIN" gateway status
