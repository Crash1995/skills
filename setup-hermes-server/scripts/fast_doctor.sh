#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_USER="${HERMES_USER:-hermes}"
HERMES_HOME_DIR="${HERMES_HOME:-/home/${HERMES_USER}/.hermes}"
HERMES_BIN="${HERMES_BIN:-/home/${HERMES_USER}/.local/bin/hermes}"
WORKSPACE="${WORKSPACE:-/srv/hermes-workspace}"
DEEP="0"

usage() {
  cat <<'EOF'
Usage: fast_doctor.sh [--deep]

Fast redacted Hermes support diagnostic.
Prints concise verdict codes without printing secrets.

Options:
  --deep     Run slower model/browser/web smoke checks when possible.
  -h, --help Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --deep) DEEP="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

STATUS=0

emit() {
  printf '%s %s\n' "$1" "$2"
}

fail() {
  emit "FAIL" "$1"
  STATUS=1
}

warn() {
  emit "WARN" "$1"
}

ok() {
  emit "OK" "$1"
}

as_hermes() {
  if [ "$(id -u)" = "0" ] && id "$HERMES_USER" >/dev/null 2>&1; then
    su -s /bin/bash - "$HERMES_USER" -c "$*"
  else
    sh -c "$*"
  fi
}

echo "FAST_DOCTOR_START"

if id "$HERMES_USER" >/dev/null 2>&1; then
  ok "USER_PRESENT"
else
  fail "USER_MISSING"
fi

if [ -x "$HERMES_BIN" ]; then
  ok "HERMES_OK"
  "$HERMES_BIN" --version 2>/dev/null | sed 's/^/INFO HERMES_VERSION /' || true
else
  fail "HERMES_NOT_INSTALLED"
fi

if [ -d "$WORKSPACE" ]; then
  ok "WORKSPACE_PRESENT"
else
  warn "WORKSPACE_MISSING"
fi

if command -v systemctl >/dev/null 2>&1; then
  if systemctl is-active --quiet hermes-gateway 2>/dev/null; then
    ok "GATEWAY_ACTIVE"
  else
    fail "GATEWAY_DOWN"
  fi
else
  warn "SYSTEMD_UNAVAILABLE"
fi

if [ -x "$HERMES_BIN" ]; then
  if "$HERMES_BIN" config check >/dev/null 2>&1; then
    ok "CONFIG_OK"
  else
    fail "CONFIG_INVALID"
  fi
fi

ENV_FILE="$HERMES_HOME_DIR/.env"
if [ -f "$ENV_FILE" ]; then
  ok "ENV_PRESENT"
  if grep -q '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null; then
    ok "TELEGRAM_ENV_PRESENT"
  else
    warn "TELEGRAM_ENV_MISSING"
  fi
  if grep -q '^TELEGRAM_ALLOWED_USERS=' "$ENV_FILE" 2>/dev/null; then
    ok "TELEGRAM_ALLOWLIST_PRESENT"
  else
    warn "TELEGRAM_ALLOWLIST_MISSING"
  fi
else
  warn "ENV_MISSING"
  warn "TELEGRAM_ENV_MISSING"
fi

if command -v codex >/dev/null 2>&1 || as_hermes 'command -v codex >/dev/null 2>&1'; then
  if as_hermes 'codex login status >/dev/null 2>&1'; then
    ok "OPENAI_CODEX_AUTH_OK"
  else
    fail "OPENAI_CODEX_AUTH_MISSING"
  fi
else
  warn "CODEX_CLI_MISSING"
fi

if as_hermes 'command -v agent-browser >/dev/null 2>&1'; then
  ok "AGENT_BROWSER_PRESENT"
else
  warn "BROWSER_NOT_READY"
fi

if [ -x "$HERMES_BIN" ]; then
  dashboard_status="$("$HERMES_BIN" dashboard --status 2>&1 || true)"
  if [ -n "$dashboard_status" ]; then
    if printf '%s\n' "$dashboard_status" | grep -qi 'running\|process\|http'; then
      ok "DASHBOARD_STATUS_AVAILABLE"
    else
      warn "DASHBOARD_DOWN"
    fi
  else
    warn "DASHBOARD_DOWN"
  fi
fi

if ss -ltn 2>/dev/null | grep -q ':9119'; then
  ok "DASHBOARD_PORT_LISTENING"
else
  warn "DASHBOARD_PORT_CLOSED"
fi

if [ "$DEEP" = "1" ] && [ -x "$HERMES_BIN" ]; then
  if as_hermes "timeout 45 '$HERMES_BIN' -z 'Ответь только OK' >/dev/null 2>&1"; then
    ok "MODEL_SMOKE_OK"
  else
    fail "MODEL_SMOKE_FAILED"
  fi
fi

if [ "$STATUS" = "0" ]; then
  echo "VERDICT OK"
else
  echo "VERDICT NEED_REPAIR"
fi

echo "FAST_DOCTOR_DONE"
exit "$STATUS"
