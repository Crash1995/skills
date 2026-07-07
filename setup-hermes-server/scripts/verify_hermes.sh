#!/usr/bin/env bash
set -Eeuo pipefail

section() {
  printf '\n=== %s ===\n' "$1"
}

redact() {
  sed -E \
    -e 's/(token=|access_token=|session=)[^[:space:]]+/\1[redacted]/g' \
    -e 's/(TELEGRAM_BOT_TOKEN=).+/\1[redacted]/g' \
    -e 's/(API_SERVER_KEY=).+/\1[redacted]/g' \
    -e 's/([A-Za-z0-9_]*(API_KEY|TOKEN|SECRET|PASSWORD)[A-Za-z0-9_]*: )[A-Za-z0-9._~+\/=-]+/\1[redacted]/g'
}

run() {
  printf '$ %s\n' "$*"
  "$@" 2>&1 | redact || true
}

run_sh() {
  printf '$ %s\n' "$*"
  sh -c "$*" 2>&1 | redact || true
}

HERMES_BIN="${HERMES_BIN:-/home/hermes/.local/bin/hermes}"

section "binary"
if [ ! -x "$HERMES_BIN" ]; then
  echo "Hermes binary not found at $HERMES_BIN"
  exit 1
fi
run "$HERMES_BIN" --version

section "config"
run "$HERMES_BIN" config check

section "doctor"
run "$HERMES_BIN" doctor

section "gateway"
run "$HERMES_BIN" gateway status
run_sh 'systemctl is-active hermes-gateway || true'

section "profiles"
run "$HERMES_BIN" profile list
for profile in default planner coder editor monitor; do
  if [ "$profile" = "default" ]; then
    soul="/home/hermes/.hermes/SOUL.md"
  else
    soul="/home/hermes/.hermes/profiles/$profile/SOUL.md"
  fi
  if [ -f "$soul" ]; then
    printf '%s SOUL.md: present\n' "$profile"
  else
    printf '%s SOUL.md: missing\n' "$profile"
  fi
done

section "kanban"
run "$HERMES_BIN" kanban boards list
run "$HERMES_BIN" kanban stats
run "$HERMES_BIN" kanban assignees

section "dashboard"
run "$HERMES_BIN" dashboard --status
run_sh "ss -ltnp 2>/dev/null | grep ':9119' || true"
run_sh "python3 - <<'PY'
from urllib.request import urlopen
for url in ['http://127.0.0.1:9119/', 'http://127.0.0.1:9119/api/dashboard/plugins']:
    try:
        with urlopen(url, timeout=5) as r:
            print(url, r.status, r.headers.get('content-type'))
    except Exception as e:
        print(url, 'unavailable:', e)
PY"

section "recent gateway logs"
run_sh "journalctl -u hermes-gateway -n 80 --no-pager | grep -Ei 'telegram connected|kanban dispatcher|error|warning' || true"

section "result"
echo "Verification complete. Review warnings above before declaring the server ready."
