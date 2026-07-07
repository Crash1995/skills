# Local Desktop Bridge

Use this when the user wants local/desktop Hermes on their computer to work with a remote Hermes server.

## Goal

Connect the desktop to the server without exposing Hermes dashboard/API publicly. The default bridge is:

```text
local desktop -> SSH tunnel -> remote 127.0.0.1 Hermes service
```

Do not turn this into a full server bootstrap unless the server is missing Hermes or gateway entirely.

Prefer the bundled local script:

```bash
scripts/start_desktop_bridge.sh --host HOST
```

It performs remote read-only checks, starts a local SSH tunnel, and verifies the local URL.

## Scope

Do:

- verify remote Hermes is running;
- verify the remote dashboard/API is bound to `127.0.0.1`;
- create or explain the SSH tunnel;
- configure the local desktop/client URL if a local Hermes desktop config is present;
- verify the local URL opens through the tunnel.

Do not:

- reinstall Hermes;
- reconfigure Telegram;
- run Kanban smoke;
- expose ports publicly;
- change firewall rules unless the user explicitly asks.

## Remote Checks

Run read-only checks first:

```bash
ssh hermes@HOST '/home/hermes/.local/bin/hermes --version'
ssh hermes@HOST '/home/hermes/.local/bin/hermes gateway status || true'
ssh hermes@HOST '/home/hermes/.local/bin/hermes dashboard --status || true'
ssh hermes@HOST "ss -ltnp | grep -E ':(9119|9120|3000|8000)' || true"
```

Expected safe state:

```text
dashboard/API listens on 127.0.0.1 or localhost only
gateway service is active when messaging integrations are needed
```

If the dashboard is missing, start it with the existing dashboard script from the main skill. Keep it on `127.0.0.1`.

## SSH Tunnel

Use the dashboard port that exists on the server. Default dashboard port is `9119`:

```bash
scripts/start_desktop_bridge.sh --host HOST
```

If local `9119` is busy:

```bash
scripts/start_desktop_bridge.sh --host HOST --local-port 19119
```

Then open:

```text
http://127.0.0.1:9119
```

or:

```text
http://127.0.0.1:19119
```

## Local Desktop Configuration

First inspect local Hermes config locations without printing secrets:

```bash
ls -la ~/.hermes ~/.config 2>/dev/null || true
find ~/.hermes ~/.config -maxdepth 3 -iname '*hermes*' -print 2>/dev/null
```

If a desktop config contains a server/base URL field, set it to the tunnel URL:

```text
http://127.0.0.1:9119
```

Do not invent a config key. If the local desktop app has no obvious remote URL setting, report that the supported path is the SSH tunnel plus browser access to the remote dashboard.

## Verification

Verify the tunnel from the Mac:

```bash
curl -sS http://127.0.0.1:9119/ | head
```

If the local port was changed:

```bash
curl -sS http://127.0.0.1:19119/ | head
```

A valid response is HTML or a JSON health response from Hermes. If the response is empty, check that the tunnel process is still running and the remote service listens on the expected port.

## Failure Modes

- `connection refused` locally: tunnel is not running or wrong local port.
- `channel open failed`: remote service is not listening on the forwarded port.
- browser opens but desktop app does not connect: the desktop app may not support remote server URLs; use dashboard through the tunnel or inspect the desktop app config.
- public IP works but localhost tunnel fails: close the public exposure first, then restore localhost binding and tunnel.
