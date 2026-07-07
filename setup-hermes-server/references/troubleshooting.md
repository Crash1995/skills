# Troubleshooting Hermes Server Setup

Use this before changing more than one thing. Read the exact symptom, identify the layer, then run one minimal verification.

For subscriber support, start with:

```bash
scripts/fast_doctor.sh
```

Then use `failure-matrix.md` for the smallest matching fix.

For narrow checks, prefer dedicated smoke scripts:

```bash
scripts/smoke_telegram_bot.sh
scripts/smoke_browser_web.sh
```

## `hermes: command not found` inside Hermes terminal tool

Likely cause: the service PATH does not include `/home/hermes/.local/bin`, or the terminal backend is not using the expected Hermes user environment.

Check from the tool:

```bash
pwd
whoami
echo "$HOME"
command -v hermes || true
```

Expected host/no-Docker baseline:

```text
HOME=/home/hermes
PWD=/srv/hermes-workspace
hermes available through /home/hermes/.local/bin/hermes
```

Verify the host through SSH:

```bash
ssh hermes@HOST '/home/hermes/.local/bin/hermes --version && /home/hermes/.local/bin/hermes gateway status'
```

## `/profile` works but natural-language profile checks look wrong

If `/profile` says `planner`, but a natural-language request says `HOME=/root` or `HERMES_HOME` is empty, the service probably started with the wrong user environment or stale systemd unit.

Use these as source of truth:

```text
/profile
/status
```

Do not use terminal `HOME` as profile-routing proof. Verify systemd `User`, `HOME`, and `HERMES_HOME` separately.

## `Installed gateway service definition is outdated`

Likely cause: system gateway unit was generated from root's environment, or Hermes install paths changed.

Refresh as root with Hermes user's environment:

```bash
sudo HOME=/home/hermes USER=hermes LOGNAME=hermes HERMES_HOME=/home/hermes/.hermes \
  /home/hermes/.local/bin/hermes gateway restart --system
```

Or use:

```bash
sudo scripts/refresh_systemd_unit.sh --yes
```

Verify:

```bash
/home/hermes/.local/bin/hermes gateway status
python3 - <<'PY'
import hermes_cli.gateway as g
print(g.systemd_unit_is_current(system=True))
PY
```

Expected: no outdated warning, `True`.

## Dashboard does not open

Separate the layers:

```bash
/home/hermes/.local/bin/hermes dashboard --status
ss -ltnp | grep ':9119' || true
curl -sS http://127.0.0.1:9119/ | head
tail -120 /home/hermes/.hermes/logs/dashboard.log
```

Common causes:

- dashboard process is not running;
- first web UI build was never allowed;
- tunnel is not open on the Mac;
- another local process uses port `9119`;
- dashboard was bound to server localhost, but browser is trying the Mac without SSH tunnel.

Safe start:

```bash
scripts/start_dashboard.sh --yes-build
```

Mac tunnel:

```bash
ssh -N -L 9119:127.0.0.1:9119 hermes@HOST
```

Open: `http://127.0.0.1:9119`.

## Dashboard page is blank or Kanban does not render

Do not assume Kanban is broken. Prove the failing layer:

```bash
# Local Mac: is the SSH tunnel listening?
lsof -nP -iTCP:9119 -sTCP:LISTEN || true
curl -sS -I http://127.0.0.1:9119/

# Remote host: is dashboard alive?
ssh hermes@HOST '/home/hermes/.local/bin/hermes dashboard --status'
ssh hermes@HOST 'curl -fsS http://127.0.0.1:9119/api/status >/dev/null && echo dashboard_ok'
```

If `/` returns HTML but `/api/*` returns `Unauthorized`, that is normal for raw curl. Extract the injected session token without printing it:

```bash
python3 - <<'PY'
import re, urllib.request
base = "http://127.0.0.1:9119"
html = urllib.request.urlopen(base + "/kanban", timeout=10).read().decode()
token = re.search(r'__HERMES_SESSION_TOKEN__="([^"]+)"', html).group(1)
req = urllib.request.Request(
    base + "/api/plugins/kanban/board",
    headers={"X-Hermes-Session-Token": token},
)
data = urllib.request.urlopen(req, timeout=10).read().decode()
print("html_ok", "assets/index-" in html)
print("board_ok", '"columns"' in data, len(data))
PY
```

If the browser console says `Failed to resolve module specifier "lucide-react"` or `three`, the dashboard bundle is broken. Common causes:

- dashboard is started with `--skip-build` and serves stale `hermes_cli/web_dist`;
- `node_modules` is incomplete, e.g. `lucide-react` has only `.map` files or `three/build/` is missing;
- a previous failed build still wrote a bad `index-*.js`.

Repair order:

```bash
ssh hermes@HOST 'bash -s' <<'SH'
set -euo pipefail
export PATH="/home/hermes/.hermes/node/bin:/home/hermes/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
cd /home/hermes/.hermes/hermes-agent
backup="/home/hermes/.hermes/backups/web_dist_$(date -u +%Y%m%d%H%M%S)"
mkdir -p /home/hermes/.hermes/backups
cp -a hermes_cli/web_dist "$backup"

# Requires explicit user approval: npm install downloads and runs package code.
npm install --ignore-scripts

if [ ! -f node_modules/lucide-react/dist/esm/lucide-react.js ] || [ ! -f node_modules/three/build/three.module.js ]; then
  rm -rf node_modules/lucide-react node_modules/three web/node_modules/lucide-react web/node_modules/three
  npm cache clean --force
  npm install --ignore-scripts --no-save lucide-react@0.577.0 three@0.180.0
fi

cd web
npm run build
if [ -x /home/hermes/.hermes/scripts/ensure-dashboard.sh ]; then
  /home/hermes/.hermes/scripts/ensure-dashboard.sh --restart
else
  /home/hermes/.local/bin/hermes dashboard --stop || true
  nohup /home/hermes/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open \
    >> /home/hermes/.hermes/logs/dashboard.log 2>&1 &
fi
SH
```

Then verify in a browser, not only curl:

- page text includes `Kanban`;
- `.hermes-kanban` exists;
- plugin JS/CSS loaded from `/dashboard-plugins/kanban/`;
- there are no fresh console errors;
- `hermes kanban diagnostics` is clean.

## Local desktop cannot reach server Hermes

Treat this as `desktop-bridge`, not a full server repair.

Check the remote service:

```bash
ssh hermes@HOST '/home/hermes/.local/bin/hermes dashboard --status || true'
ssh hermes@HOST "ss -ltnp | grep -E ':(9119|9120|3000|8000)' || true"
```

Check the local tunnel:

```bash
curl -sS http://127.0.0.1:9119/ | head
```

Common causes:

- SSH tunnel is not running;
- local port differs from the configured desktop URL;
- remote dashboard/API is not running;
- remote service was bound publicly instead of to localhost;
- the desktop app does not support a remote URL and must use the tunneled dashboard in a browser.

Do not expose remote ports publicly to fix this.

## Telegram topic commands do not respond

Check:

1. Bot is in the group.
2. Bot has permission to read and send topic messages.
3. Topics are enabled.
4. Commands are sent inside the topic, not in the main group.
5. In groups, command may require bot mention:

```text
/status@bot_username
/profile@bot_username
```

Collect IDs without printing the token:

```bash
scripts/collect_telegram_topics.py
```

## Kanban task stays `ready`

Check gateway and dispatcher:

```bash
/home/hermes/.local/bin/hermes gateway status
/home/hermes/.local/bin/hermes kanban stats
journalctl -u hermes-gateway -n 120 --no-pager | grep -Ei 'kanban|dispatch|error|warning' || true
```

Expected log line:

```text
kanban dispatcher: embedded in gateway
```

Run smoke test:

```bash
scripts/smoke_kanban_task.sh --assignee planner
```

## Optional Docker disk quota warning

Warning:

```text
Docker storage driver does not support per-container disk limits
```

This means Docker cannot enforce `container_disk` on this storage driver. CPU/memory limits can still work. Do not treat this as a gateway failure.

## Before risky repair

Always back up first:

```bash
scripts/backup_hermes_config.sh
```

Then apply one repair, restart if needed, and run:

```bash
scripts/verify_hermes.sh
```
