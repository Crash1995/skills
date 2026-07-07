#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_USER="${HERMES_USER:-hermes}"
HERMES_HOME_DIR="${HERMES_HOME:-/home/${HERMES_USER}/.hermes}"
ENV_FILE="${ENV_FILE:-$HERMES_HOME_DIR/.env}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-15}"

usage() {
  cat <<'EOF'
Usage: smoke_telegram_bot.sh [--env-file PATH] [--timeout SECONDS]

Validates Telegram bot configuration without printing the bot token.
Reads TELEGRAM_BOT_TOKEN and TELEGRAM_ALLOWED_USERS from the Hermes .env file.

Options:
  --env-file PATH      .env path. Default: /home/hermes/.hermes/.env.
  --timeout SECONDS    HTTP timeout. Default: 15.
  -h, --help           Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --env-file) ENV_FILE="${2:?missing env file}"; shift 2 ;;
    --timeout) TIMEOUT_SECONDS="${2:?missing timeout}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$TIMEOUT_SECONDS" in
  *[!0-9]*|"") echo "Invalid timeout: $TIMEOUT_SECONDS" >&2; exit 2 ;;
esac

if [ ! -f "$ENV_FILE" ]; then
  echo "FAIL TELEGRAM_ENV_MISSING"
  exit 1
fi

python3 - "$ENV_FILE" "$TIMEOUT_SECONDS" <<'PY'
import json
import sys
from pathlib import Path
from urllib import error, request

env_path = Path(sys.argv[1])
timeout = int(sys.argv[2])

values = {}
for line in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
    line = line.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    values[key.strip()] = value.strip().strip('"').strip("'")

token = values.get("TELEGRAM_BOT_TOKEN", "")
allowed = values.get("TELEGRAM_ALLOWED_USERS", "")

if not token:
    print("FAIL TELEGRAM_TOKEN_MISSING")
    sys.exit(1)

if not allowed:
    print("WARN TELEGRAM_ALLOWLIST_MISSING")
else:
    print("OK TELEGRAM_ALLOWLIST_PRESENT")

url = f"https://api.telegram.org/bot{token}/getMe"
try:
    with request.urlopen(url, timeout=timeout) as response:
        payload = json.loads(response.read().decode("utf-8", errors="replace"))
except error.HTTPError as exc:
    if exc.code in {401, 404}:
        print("FAIL TELEGRAM_TOKEN_INVALID")
    else:
        print(f"FAIL TELEGRAM_API_HTTP_{exc.code}")
    sys.exit(1)
except Exception as exc:
    print(f"FAIL TELEGRAM_API_UNAVAILABLE {exc.__class__.__name__}")
    sys.exit(1)

if payload.get("ok") is True:
    result = payload.get("result") or {}
    username = result.get("username") or "unknown"
    print("OK TELEGRAM_TOKEN_OK")
    print(f"INFO TELEGRAM_BOT_USERNAME @{username}")
    sys.exit(0)

print("FAIL TELEGRAM_TOKEN_INVALID")
sys.exit(1)
PY
