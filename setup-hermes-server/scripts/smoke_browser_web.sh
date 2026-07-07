#!/usr/bin/env bash
set -Eeuo pipefail

HERMES_USER="${HERMES_USER:-hermes}"
HERMES_BIN="${HERMES_BIN:-/home/${HERMES_USER}/.local/bin/hermes}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-120}"
RUN_BROWSER="1"
RUN_WEB="1"

usage() {
  cat <<'EOF'
Usage: smoke_browser_web.sh [options]

Runs Hermes browser and web-search smoke checks.

Options:
  --browser-only       Run only browser smoke.
  --web-only           Run only web-search smoke.
  --timeout SECONDS    Per-smoke timeout. Default: 120.
  --hermes-bin PATH    Hermes binary path.
  -h, --help           Show this help.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --browser-only) RUN_BROWSER="1"; RUN_WEB="0"; shift ;;
    --web-only) RUN_BROWSER="0"; RUN_WEB="1"; shift ;;
    --timeout) TIMEOUT_SECONDS="${2:?missing timeout}"; shift 2 ;;
    --hermes-bin) HERMES_BIN="${2:?missing hermes bin}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

case "$TIMEOUT_SECONDS" in
  *[!0-9]*|"") echo "Invalid timeout: $TIMEOUT_SECONDS" >&2; exit 2 ;;
esac

STATUS=0

emit() {
  printf '%s %s\n' "$1" "$2"
}

run_as_hermes() {
  if [ "$(id -u)" = "0" ] && id "$HERMES_USER" >/dev/null 2>&1; then
    su -s /bin/bash - "$HERMES_USER" -c "$*"
  else
    sh -c "$*"
  fi
}

if [ ! -x "$HERMES_BIN" ]; then
  emit "FAIL" "HERMES_NOT_INSTALLED"
  exit 1
fi

if [ "$RUN_BROWSER" = "1" ]; then
  browser_prompt='Use browser tools to open https://example.com and reply only with the page title.'
  if browser_output="$(run_as_hermes "timeout '$TIMEOUT_SECONDS' '$HERMES_BIN' -z '$browser_prompt'" 2>&1)"; then
    if printf '%s\n' "$browser_output" | grep -qi 'Example Domain'; then
      emit "OK" "BROWSER_SMOKE_OK"
    else
      emit "FAIL" "BROWSER_SMOKE_UNEXPECTED_OUTPUT"
      STATUS=1
    fi
  else
    emit "FAIL" "BROWSER_SMOKE_FAILED"
    STATUS=1
  fi
fi

if [ "$RUN_WEB" = "1" ]; then
  web_prompt='Use web search and tell me only the current stable OpenAI Codex CLI version string.'
  if web_output="$(run_as_hermes "timeout '$TIMEOUT_SECONDS' '$HERMES_BIN' -z '$web_prompt'" 2>&1)"; then
    if printf '%s\n' "$web_output" | grep -Eq '[0-9]+\.[0-9]+\.[0-9]+'; then
      emit "OK" "WEB_SMOKE_OK"
    else
      emit "FAIL" "WEB_SMOKE_UNEXPECTED_OUTPUT"
      STATUS=1
    fi
  else
    emit "FAIL" "WEB_SMOKE_FAILED"
    STATUS=1
  fi
fi

if [ "$STATUS" = "0" ]; then
  emit "VERDICT" "OK"
else
  emit "VERDICT" "NEED_REPAIR"
fi

exit "$STATUS"
