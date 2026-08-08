#!/usr/bin/env bash
set -Eeuo pipefail

ASSIGNEE="planner"
WAIT_SECONDS="90"
TITLE="test: kanban handshake"
BODY="Ответь коротко: Kanban worker работает. Ничего не меняй."
IDEMPOTENCY_KEY="codex-kanban-handshake"
HERMES_BIN="${HERMES_BIN:-/home/hermes/.local/bin/hermes}"

usage() {
  cat <<'EOF'
Usage: smoke_kanban_task.sh [--assignee planner] [--wait 90]

Creates an idempotent Kanban smoke task, waits for the embedded dispatcher,
then verifies the task reached done/completed.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --assignee) ASSIGNEE="${2:?missing assignee}"; shift 2 ;;
    --wait) WAIT_SECONDS="${2:?missing seconds}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [ ! -x "$HERMES_BIN" ]; then
  echo "Hermes binary not found at $HERMES_BIN" >&2
  exit 1
fi

TASK_JSON="$("$HERMES_BIN" kanban create "$TITLE" \
  --assignee "$ASSIGNEE" \
  --body "$BODY" \
  --idempotency-key "$IDEMPOTENCY_KEY-$ASSIGNEE" \
  --max-runtime 5m \
  --json)"

TASK_ID="$(TASK_JSON="$TASK_JSON" python3 - <<'PY'
import json
import os
print(json.loads(os.environ["TASK_JSON"])["id"])
PY
)"

echo "task_id=$TASK_ID"
"$HERMES_BIN" kanban show "$TASK_ID" | sed -n '1,120p'

echo "waiting_seconds=$WAIT_SECONDS"
sleep "$WAIT_SECONDS"

SHOW="$("$HERMES_BIN" kanban show "$TASK_ID")"
printf '%s\n' "$SHOW" | sed -n '1,180p'

if printf '%s\n' "$SHOW" | grep -q 'status:    done'; then
  echo "kanban_smoke=ok"
  "$HERMES_BIN" kanban runs "$TASK_ID" | sed -n '1,120p' || true
  exit 0
fi

echo "kanban_smoke=failed" >&2
"$HERMES_BIN" kanban runs "$TASK_ID" | sed -n '1,120p' >&2 || true
"$HERMES_BIN" kanban log "$TASK_ID" 2>&1 | tail -120 >&2 || true
exit 1
