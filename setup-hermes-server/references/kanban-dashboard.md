# Kanban And Dashboard

## Initialize Kanban

```bash
/home/hermes/.local/bin/hermes kanban init
/home/hermes/.local/bin/hermes kanban boards list
/home/hermes/.local/bin/hermes kanban stats
/home/hermes/.local/bin/hermes kanban assignees
```

Ensure dispatcher is embedded in gateway:

```bash
/home/hermes/.local/bin/hermes config set kanban.dispatch_in_gateway true
/home/hermes/.local/bin/hermes gateway restart
/home/hermes/.local/bin/hermes gateway status
```

If system gateway restart requires root:

```bash
sudo HOME=/home/hermes USER=hermes LOGNAME=hermes HERMES_HOME=/home/hermes/.hermes   /home/hermes/.local/bin/hermes gateway restart --system
```

## Smoke Task

Preferred with bundled script:

```bash
ssh hermes@HOST 'bash -s -- --assignee planner' < scripts/smoke_kanban_task.sh
```

Manual equivalent:

Create a deterministic test task:

```bash
/home/hermes/.local/bin/hermes kanban create "test: planner handshake"   --assignee planner   --body "Ответь коротко: Kanban planner worker работает. Ничего не меняй."   --idempotency-key codex-kanban-planner-handshake   --max-runtime 5m   --json
```

Wait one dispatcher interval, then:

```bash
/home/hermes/.local/bin/hermes kanban show <task_id>
/home/hermes/.local/bin/hermes kanban runs <task_id>
/home/hermes/.local/bin/hermes kanban log <task_id> | tail -120
```

Expected: status `done`, run `completed`, profile `planner`.

## Daily CLI Commands

```bash
hermes kanban list
hermes kanban stats
hermes kanban show <task_id>
hermes kanban tail <task_id>
hermes kanban log <task_id>
hermes kanban create "title" --assignee coder --body "..."
```

## Dashboard

The dashboard is a separate web process, not the gateway.

Preferred with bundled script:

```bash
ssh hermes@HOST 'bash -s -- --yes-build' < scripts/start_dashboard.sh
```

The script refuses public bind hosts and requires `--yes-build` before first-run dependency install/build.

Start safely:

```bash
export PATH="/home/hermes/.hermes/node/bin:$PATH"
nohup /home/hermes/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open   > /home/hermes/.hermes/logs/dashboard.log 2>&1 &
```

Verify:

```bash
/home/hermes/.local/bin/hermes dashboard --status
ss -ltnp | grep ':9119'
python3 - <<'PY'
from urllib.request import urlopen
for url in ['http://127.0.0.1:9119/', 'http://127.0.0.1:9119/api/dashboard/plugins']:
    with urlopen(url, timeout=5) as r:
        print(url, r.status, r.headers.get('content-type'))
PY
```

Expected plugin list contains `kanban`.

## Verify Kanban UI, Not Just Backend

The Kanban API can be healthy while the browser page is blank because the dashboard frontend bundle failed. Check in this order:

1. SSH tunnel listens on the Mac.
2. Remote dashboard answers `/api/status`.
3. `/api/dashboard/plugins` lists the `kanban` plugin.
4. `/dashboard-plugins/kanban/dist/index.js` and `style.css` return 200.
5. Browser console has no module-resolution errors.
6. DOM contains `.hermes-kanban` with columns/cards.

Use the injected dashboard token for API probes. Do not print the token:

```bash
python3 - <<'PY'
import re, urllib.request
base = "http://127.0.0.1:9119"
html = urllib.request.urlopen(base + "/kanban", timeout=10).read().decode()
token = re.search(r'__HERMES_SESSION_TOKEN__="([^"]+)"', html).group(1)
headers = {"X-Hermes-Session-Token": token}
for path in ["/api/dashboard/plugins", "/api/plugins/kanban/boards", "/api/plugins/kanban/board"]:
    req = urllib.request.Request(base + path, headers=headers)
    with urllib.request.urlopen(req, timeout=10) as r:
        print(path, r.status, r.headers.get("content-type"))
PY
```

If the dashboard is started by a watchdog with `--skip-build`, treat `web_dist` as an artifact that may go stale. The watchdog can keep the process alive, but it will not repair a broken bundle; rebuild `web_dist` first, then restart the watchdog/dashboard. Back up `web_dist` before rebuilding. If `npm install` is needed, ask for explicit approval and prefer `npm install --ignore-scripts` for dashboard-only repair; native packages such as `node-pty` may otherwise fail when `make` is missing.

Mac tunnel:

```bash
ssh -N -L 9119:127.0.0.1:9119 hermes@HOST
```

Optional `~/.ssh/config`:

```sshconfig
Host hermes-dashboard
  HostName HOST
  User hermes
  LocalForward 9119 127.0.0.1:9119
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Then:

```bash
ssh -N hermes-dashboard
```

Open `http://127.0.0.1:9119`.

Stop:

```bash
/home/hermes/.local/bin/hermes dashboard --stop
```
