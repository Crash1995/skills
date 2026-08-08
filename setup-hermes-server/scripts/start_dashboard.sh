#!/usr/bin/env bash
set -Eeuo pipefail

HOST="127.0.0.1"
PORT="9119"
YES_BUILD="0"
HERMES_BIN="${HERMES_BIN:-/home/hermes/.local/bin/hermes}"
HERMES_HOME_DIR="${HERMES_HOME:-/home/hermes/.hermes}"
LOG_FILE="$HERMES_HOME_DIR/logs/dashboard.log"
PID_FILE="$HERMES_HOME_DIR/dashboard.pid"

usage() {
  cat <<'EOF'
Usage: start_dashboard.sh [--host 127.0.0.1] [--port 9119] [--yes-build]

Starts Hermes dashboard safely on loopback.

Options:
  --host HOST      Bind host. Default: 127.0.0.1. Public hosts are rejected.
  --port PORT      Bind port. Default: 9119.
  --yes-build      Allow first-run web UI dependency install/build.

The dashboard is accessed through an SSH tunnel:
  ssh -N -L 9119:127.0.0.1:9119 hermes@HOST
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --host) HOST="${2:?missing host}"; shift 2 ;;
    --port) PORT="${2:?missing port}"; shift 2 ;;
    --yes-build) YES_BUILD="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$HOST" in
  127.0.0.1|localhost|::1) ;;
  *)
    echo "Refusing to bind dashboard to non-loopback host: $HOST" >&2
    echo "Use an SSH tunnel instead of exposing the dashboard." >&2
    exit 2
    ;;
esac

if [ ! -x "$HERMES_BIN" ]; then
  echo "Hermes binary not found at $HERMES_BIN" >&2
  exit 1
fi

PROJECT_ROOT="$HERMES_HOME_DIR/hermes-agent"
DIST_INDEX="$PROJECT_ROOT/hermes_cli/web_dist/index.html"
if [ ! -f "$DIST_INDEX" ] && [ "$YES_BUILD" != "1" ]; then
  cat >&2 <<EOF
Web UI dist is missing: $DIST_INDEX
First dashboard start may run npm ci and npm run build.
Re-run with --yes-build after confirming this is allowed.
EOF
  exit 3
fi

mkdir -p "$HERMES_HOME_DIR/logs"
export PATH="$HERMES_HOME_DIR/node/bin:$PATH"

if "$HERMES_BIN" dashboard --status 2>/dev/null | grep -q "dashboard process"; then
  echo "Hermes dashboard already appears to be running:"
  "$HERMES_BIN" dashboard --status
  exit 0
fi

: > "$LOG_FILE"
nohup "$HERMES_BIN" dashboard --host "$HOST" --port "$PORT" --no-open > "$LOG_FILE" 2>&1 &
echo "$!" > "$PID_FILE"

echo "started_pid=$(cat "$PID_FILE")"
echo "log=$LOG_FILE"

for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if ss -ltn 2>/dev/null | grep -q ":$PORT"; then
    echo "dashboard_listening=$HOST:$PORT"
    exit 0
  fi
  sleep 5
done

echo "Dashboard process started but port did not open within 60s." >&2
echo "Recent log:" >&2
tail -80 "$LOG_FILE" >&2 || true
exit 1
