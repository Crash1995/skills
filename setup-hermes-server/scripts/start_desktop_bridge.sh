#!/usr/bin/env bash
set -Eeuo pipefail

SSH_USER="hermes"
HOST=""
LOCAL_PORT="9119"
REMOTE_PORT="9119"
PID_FILE=""
FOREGROUND="0"
SKIP_REMOTE_CHECK="0"

usage() {
  cat <<'EOF'
Usage: start_desktop_bridge.sh --host HOST [options]

Starts a local SSH tunnel from desktop to a remote loopback-only Hermes dashboard/API.
This script does not change remote files, firewall, Telegram, Kanban, or Hermes config.

Options:
  --host HOST              Remote host or IP. Required.
  --user USER              SSH user. Default: hermes.
  --local-port PORT        Local port. Default: 9119.
  --remote-port PORT       Remote loopback port. Default: 9119.
  --pid-file PATH          PID file. Default: /tmp/hermes-desktop-bridge-PORT.pid.
  --foreground             Run ssh tunnel in foreground after checks.
  --skip-remote-check      Skip remote read-only listener checks.
  -h, --help               Show this help.

Examples:
  start_desktop_bridge.sh --host 146.103.116.11
  start_desktop_bridge.sh --host 146.103.116.11 --local-port 19119
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?missing host}"; shift 2 ;;
    --user) SSH_USER="${2:?missing user}"; shift 2 ;;
    --local-port) LOCAL_PORT="${2:?missing local port}"; shift 2 ;;
    --remote-port) REMOTE_PORT="${2:?missing remote port}"; shift 2 ;;
    --pid-file) PID_FILE="${2:?missing pid file}"; shift 2 ;;
    --foreground) FOREGROUND="1"; shift ;;
    --skip-remote-check) SKIP_REMOTE_CHECK="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ -z "$HOST" ]; then
  echo "--host is required" >&2
  usage
  exit 2
fi

case "$LOCAL_PORT" in
  *[!0-9]*|"") echo "Invalid --local-port: $LOCAL_PORT" >&2; exit 2 ;;
esac

case "$REMOTE_PORT" in
  *[!0-9]*|"") echo "Invalid --remote-port: $REMOTE_PORT" >&2; exit 2 ;;
esac

if [ -z "$PID_FILE" ]; then
  PID_FILE="/tmp/hermes-desktop-bridge-${LOCAL_PORT}.pid"
fi

TARGET="${SSH_USER}@${HOST}"
LOCAL_URL="http://127.0.0.1:${LOCAL_PORT}/"

if [ "$SKIP_REMOTE_CHECK" != "1" ]; then
  echo "remote_check=$TARGET"
  ssh "$TARGET" "ss -ltn 2>/dev/null | grep -E '127\\.0\\.0\\.1:${REMOTE_PORT}|\\[::1\\]:${REMOTE_PORT}|localhost:${REMOTE_PORT}' || ss -ltn 2>/dev/null | grep ':${REMOTE_PORT}' || true"
fi

if command -v curl >/dev/null 2>&1; then
  if curl -fsS --max-time 2 "$LOCAL_URL" >/dev/null 2>&1; then
    echo "already_available=$LOCAL_URL"
    exit 0
  fi
fi

if command -v lsof >/dev/null 2>&1; then
  if lsof -nP -iTCP:"$LOCAL_PORT" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Local port $LOCAL_PORT is already in use." >&2
    echo "Use --local-port 19119 or stop the existing listener." >&2
    exit 3
  fi
fi

SSH_ARGS=(
  -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
  "$TARGET"
)

if [ "$FOREGROUND" = "1" ]; then
  echo "open=$LOCAL_URL"
  exec ssh -N "${SSH_ARGS[@]}"
fi

ssh -fN "${SSH_ARGS[@]}"

SSH_PID=""
if command -v pgrep >/dev/null 2>&1; then
  SSH_PID="$(pgrep -f "ssh .*${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}.*${TARGET}" | tail -1 || true)"
fi

if [ -n "$SSH_PID" ]; then
  echo "$SSH_PID" > "$PID_FILE"
  echo "pid=$SSH_PID"
  echo "pid_file=$PID_FILE"
fi

if command -v curl >/dev/null 2>&1; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    if curl -fsS --max-time 3 "$LOCAL_URL" >/dev/null 2>&1; then
      echo "ready=$LOCAL_URL"
      exit 0
    fi
    sleep 1
  done
  echo "Tunnel started, but $LOCAL_URL did not respond within 10s." >&2
  echo "Check remote listener on 127.0.0.1:$REMOTE_PORT." >&2
  exit 1
fi

echo "started=$LOCAL_URL"
