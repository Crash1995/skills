# Hermes VPS Setup Runbook

## Quick Mode Selection

Before running commands, classify the request:

```text
full-bootstrap      complete production server setup
telegram-only       Telegram gateway setup or repair
browser-web-only    browser/web-search setup or repair
desktop-bridge      local/desktop Hermes connects to remote Hermes
repair              one named failure only
```

For any mode except `full-bootstrap`, skip profiles, Kanban, dashboard build, and broad health checks unless they are directly required by the symptom.

For subscriber installs, read `subscriber-intake.md` first. Default intake is only:

```text
server_ip
server_password
```

Do not ask for SSH user, SSH key, OS, or setup preferences upfront. Detect them when connected, using `root` as the default SSH user unless the user says otherwise.

For support cases, run `fast_doctor.sh` before deep debugging:

```bash
ssh root@HOST 'bash -s' < scripts/fast_doctor.sh
```

Then use `failure-matrix.md` to map the verdict or symptom to the minimal repair.

## Scope Checklist

Write this before changes:

```text
Selected mode:
Allowed changes:
Forbidden changes:
Verification:
Stop condition:
```

## Ready Recipes

Use these recipes instead of rebuilding the whole workflow.

### browser-web-only

Goal: enable or repair browser and web-search only.

```bash
ssh hermes@HOST '/home/hermes/.local/bin/hermes tools post-setup agent_browser || true'
ssh hermes@HOST 'bash -s' < scripts/smoke_browser_web.sh
```

Allowed changes: browser runtime, browser/web toolsets, Chromium/browser dependencies.

Forbidden changes: Telegram, Kanban, profiles, firewall, dashboard exposure.

Stop condition: browser smoke and web-search smoke pass, or the exact failing layer is reported.

### telegram-only

Goal: enable or repair Telegram gateway only.

```bash
ssh root@HOST 'bash -s' < scripts/smoke_telegram_bot.sh
ssh hermes@HOST '/home/hermes/.local/bin/hermes gateway status || true'
ssh hermes@HOST 'systemctl status hermes-gateway --no-pager -l || true'
ssh hermes@HOST 'journalctl -u hermes-gateway -n 120 --no-pager || true'
```

Allowed changes: `.env` Telegram fields, gateway config, systemd service restart.

Forbidden changes: model runtime, browser/web, Kanban, profiles, dashboard build.

Stop condition: `/status` works in Telegram or the Bot API/gateway error is isolated.

### desktop-bridge

Goal: connect local/desktop Hermes to the remote Hermes dashboard/API through SSH.

```bash
scripts/start_desktop_bridge.sh --host HOST
curl -sS http://127.0.0.1:9119/ | head
```

Allowed changes: local SSH tunnel process only.

Forbidden changes: reinstall Hermes, Telegram, Kanban, firewall, public bind addresses.

Stop condition: local tunnel URL returns Hermes HTML/health response, or the missing remote listener is reported.

### openai-codex-oauth

Goal: log the `hermes` runtime user into OpenAI Codex with device auth.

```bash
ssh root@HOST 'sudo -iu hermes bash -lc "codex login --device-auth"'
ssh root@HOST 'sudo -iu hermes bash -lc "codex login status"'
ssh root@HOST 'sudo -iu hermes bash -lc "/home/hermes/.local/bin/hermes -z \"Ответь только OK\""'
```

Allowed changes: OpenAI/Codex auth files for the `hermes` user.

Forbidden changes: Telegram, Kanban, dashboard, firewall, model/provider migration unless the auth failure requires it and the user approves.

Stop condition: `codex login status` is logged in and a minimal Hermes model smoke returns `OK`.

### full-bootstrap

Goal: complete production server setup.

```bash
ssh root@HOST 'bash -s' < scripts/inspect_server.sh
ssh root@HOST 'bash -s -- --yes' < scripts/bootstrap_no_docker.sh
ssh root@HOST 'bash -s -- --yes' < scripts/refresh_systemd_unit.sh
ssh hermes@HOST 'bash -s' < scripts/verify_hermes.sh
```

Allowed changes: user/workspace, Hermes install, host/no-Docker config, gateway, profiles, Telegram, dashboard localhost binding.

Forbidden changes: public dashboard/API exposure, broad env passthrough, destructive shell cleanup, Docker unless explicitly requested.

Stop condition: install is verified and remaining warnings are reported.

## Phase 0: Safe Inventory

Run as root or a sudo-capable user, but do not change firewall yet:

Preferred with bundled script:

```bash
ssh hermes@HOST 'bash -s' < scripts/inspect_server.sh
```

Manual equivalent:

```bash
lsb_release -a || cat /etc/os-release
uname -a
free -h
df -h
ss -tulpn
systemctl list-units '*wg*' '*openvpn*' '*vpn*' --no-pager
wg show || true
ufw status verbose || true
iptables-save | sed -n '1,160p' || true
nft list ruleset | sed -n '1,200p' || true
systemctl list-units 'hermes*' --no-pager || true
```

Hermes state:

```bash
whoami
command -v hermes || true
/home/hermes/.local/bin/hermes --version || true
/home/hermes/.local/bin/hermes config check || true
/home/hermes/.local/bin/hermes doctor || true
/home/hermes/.local/bin/hermes gateway status || true
/home/hermes/.local/bin/hermes profile list || true
```

## Phase 1: User, Workspace, Host Execution

Preferred layout:

```text
user:       hermes
home:       /home/hermes/.hermes
workspace:  /srv/hermes-workspace
service:    hermes-gateway.service running as hermes
```

Create workspace and ownership:

```bash
sudo mkdir -p /srv/hermes-workspace /home/hermes/.hermes/cache/documents
sudo chown -R hermes:hermes /srv/hermes-workspace /home/hermes/.hermes
```

For host/no-Docker installs, keep Hermes command execution in the dedicated workspace and do not broadly pass environment variables into agent shells. Configure this after install:

```bash
/home/hermes/.local/bin/hermes config set terminal.backend local
/home/hermes/.local/bin/hermes config set terminal.cwd /srv/hermes-workspace
/home/hermes/.local/bin/hermes config set terminal.env_passthrough '[]'
```

## Phase 2: Install Hermes Without Root Data Home

Avoid `curl | bash` as root for the main install. Download the script, inspect it, then run as `hermes`:

```bash
sudo -iu hermes
curl -fsSL https://hermes-agent.nousresearch.com/install.sh -o /tmp/hermes-install.sh
sed -n '1,180p' /tmp/hermes-install.sh
bash /tmp/hermes-install.sh --skip-browser
~/.local/bin/hermes doctor
~/.local/bin/hermes setup
```

If already installed, do not reinstall blindly. Inspect first:

```bash
/home/hermes/.local/bin/hermes --version
/home/hermes/.local/bin/hermes doctor
```

## Phase 3: Gateway Service

Install or refresh the system gateway as root, but force the Hermes user environment:

```bash
sudo HOME=/home/hermes USER=hermes LOGNAME=hermes HERMES_HOME=/home/hermes/.hermes   /home/hermes/.local/bin/hermes gateway restart --system
```

Or use the bundled script after explicit confirmation:

```bash
ssh root@HOST 'bash -s -- --yes' < scripts/refresh_systemd_unit.sh
```

Verify:

```bash
/home/hermes/.local/bin/hermes gateway status
systemctl cat hermes-gateway
systemctl status hermes-gateway --no-pager -l
journalctl -u hermes-gateway -n 120 --no-pager
```

If status says the unit is outdated, compare generated vs installed unit and refresh with the same `HOME/HERMES_HOME` environment.

## Phase 4: Profiles

```bash
/home/hermes/.local/bin/hermes profile create planner --clone default || true
/home/hermes/.local/bin/hermes profile create coder --clone default || true
/home/hermes/.local/bin/hermes profile create editor --clone default || true
/home/hermes/.local/bin/hermes profile create monitor --clone default || true
/home/hermes/.local/bin/hermes profile list
```

Write profile `SOUL.md` files from `profile-templates.md`, or use the bundled script:

```bash
ssh hermes@HOST 'python3 - --dry-run' < scripts/write_profile_souls.py
ssh hermes@HOST 'python3 - --workspace-agents /srv/hermes-workspace/AGENTS.md' < scripts/write_profile_souls.py
```

Use `--dry-run` first unless the user has already approved writing the role files.

## Phase 4b: Telegram Group Topics

If the user wants topic-to-profile routing, stop and ask them to create the Telegram group/topics manually. Use `telegram-topics.md` for the exact user-facing checklist, ID collection, config mapping, restart, and validation.

## Phase 4c: Desktop Bridge

Use only for `desktop-bridge` mode. Read `local-desktop-bridge.md` and keep the work narrow:

```bash
ssh hermes@HOST '/home/hermes/.local/bin/hermes dashboard --status || true'
ssh hermes@HOST "ss -ltnp | grep -E ':(9119|9120|3000|8000)' || true"
scripts/start_desktop_bridge.sh --host HOST
curl -sS http://127.0.0.1:9119/ | head
```

Do not change Telegram, Kanban, model runtime, or firewall for this mode.

## Phase 5: Verification

Minimum final checks:

Preferred with bundled script:

```bash
ssh hermes@HOST 'bash -s' < scripts/verify_hermes.sh
```

Optional Kanban dispatcher smoke:

```bash
ssh hermes@HOST 'bash -s -- --assignee planner' < scripts/smoke_kanban_task.sh
```

Manual equivalent:

```bash
/home/hermes/.local/bin/hermes config check
/home/hermes/.local/bin/hermes doctor
/home/hermes/.local/bin/hermes gateway status
/home/hermes/.local/bin/hermes profile list
/home/hermes/.local/bin/hermes kanban stats || true
```

For narrow modes, verify only that mode:

```text
telegram-only:    /status in Telegram or gateway status plus Bot API check
browser-web-only: one browser smoke plus one web-search smoke
desktop-bridge:  local curl/browser through SSH tunnel
repair:          the exact failed command or symptom
```

In Telegram topics, send commands separately:

```text
/profile
/status
```

Expected profile map:

```text
Ассистент      -> default
Планирование  -> planner
Код / DevOps  -> coder
Контент       -> editor
Мониторинг    -> monitor
Логи / Ошибки -> monitor
```
