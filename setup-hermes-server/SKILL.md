---
name: setup-hermes-server
description: Configure and harden Hermes Agent on a VPS or remote Linux server. Use when installing Hermes, migrating it off root, protecting a server that already runs VPN, configuring host/no-Docker execution or optional Docker sandboxing, Telegram/Discord gateway, systemd, multiple profiles/agents, topic-to-profile routing, Kanban dispatcher/board/dashboard, local desktop-to-server bridge, SOUL.md role files, AGENTS.md workspace rules, SSH tunnels, and post-install verification.
---

# Setup Hermes Server

## Core Rule

Treat the server as production. Do not expose Hermes dashboard/API publicly, do not print `.env` or tokens, and do not change firewall or SSH access until the current VPN, SSH port, and service state are known.

## Agent Adapters

- **Codex**: this file is the skill entry point. When editing the package itself, also read `AGENTS.md`.
- **Claude Code**: start from `CLAUDE.md`, then use this file for routing and safety rules.
- **Humans**: use `README.md` for overview, scripts, and common workflows.

## Scope Router

Pick exactly one mode before running commands. If the user changes scope, stop unrelated work and restate the new mode.

- **full-bootstrap**: install or rebuild the production server end to end. Includes user, workspace, gateway, profiles, Telegram, optional Kanban, dashboard, and verification.
- **telegram-only**: configure or repair Telegram gateway only. Do not touch Kanban, dashboard, profiles, browser, or model runtime unless the Telegram failure requires it.
- **browser-web-only**: install/repair browser and web-search tools only. Verify with one browser smoke and one web-search smoke. Do not run Kanban smoke unless requested.
- **desktop-bridge**: connect local/desktop Hermes to the remote Hermes instance through localhost-only services and SSH tunnels. Use `references/local-desktop-bridge.md`.
- **openai-codex-oauth**: complete OpenAI Codex device auth for the Linux user that runs Hermes. Use `references/openai-codex-oauth.md`.
- **support-triage**: run `scripts/fast_doctor.sh`, map the verdict through `references/failure-matrix.md`, and apply only the smallest matching repair.
- **repair**: fix one named symptom. Inspect the failing layer, make one minimal change, verify that symptom, then stop.

Default to **repair** for a narrow request and **full-bootstrap** only when the user explicitly asks for a complete production setup.

Before making changes, write this short checklist:

```text
Selected mode:
Allowed changes:
Forbidden changes:
Verification:
Stop condition:
```

## Standard Workflow

1. **Inspect before changing.** Collect OS, resources, VPN, firewall, systemd, Hermes version, gateway status, and existing config. Redact secrets. Check Docker only if the user explicitly wants Docker.
2. **Install/run as non-root.** Prefer user `hermes`, home `/home/hermes/.hermes`, workspace `/srv/hermes-workspace`, system gateway running as `hermes`.
3. **Constrain execution.** Default to host/no-Docker terminal backend when requested, with workspace cwd, empty env passthrough, approvals enabled, and cron dangerous actions denied. Use Docker only when explicitly requested.
4. **Configure communication.** Enable gateway only for allowed users. For Telegram groups/topics, verify routing with `/profile` and `/status` in each topic.
5. **Configure profiles.** Create `planner`, `coder`, `editor`, `monitor`; write concise `SOUL.md` roles; keep `default` as orchestrator.
6. **Enable Kanban.** Initialize board, ensure embedded dispatcher is on, test a real task assigned to a non-default profile.
7. **Run dashboard safely.** Bind dashboard to `127.0.0.1`; access through SSH tunnel. Never use `--host 0.0.0.0 --insecure` unless the user explicitly accepts the risk.
8. **Verify and report.** Run `hermes config check`, `hermes doctor`, `hermes gateway status`, `hermes kanban stats`, and a smoke task. Report remaining warnings.

Run the full workflow only in **full-bootstrap** mode. In other modes, run only the steps required by the selected scope.

## Conversation Pattern

The skill communicates through Codex. Do not silently run the whole setup. Use this cadence:

1. State the next step and whether it is read-only or changes the server.
2. Run read-only inspection without asking when SSH access is already available.
3. Before edits, package installs, firewall/SSH/systemd changes, or dashboard first build, show a short plan and ask for confirmation if the user has not already approved that exact action.
4. After each phase, summarize what changed, what was verified, and what remains.
5. If the user says "only", "just", "быстро", "только", or narrows the request, immediately drop steps outside that scope.
6. If the user provided an official Hermes documentation URL, use that page as the source of truth. Do not browse the wider web unless the page is unavailable or the user asks for current external facts.

## Bundled Scripts

Scripts live in `scripts/` and are meant to be run on the target server or through SSH. Prefer them over rewriting long shell blocks.

- `inspect_server.sh`: read-only inventory. Safe first command.
- `fast_doctor.sh`: fast redacted support diagnostic that prints concise verdict codes before deeper repair.
- `verify_hermes.sh`: redacted health check for Hermes, gateway, profiles, Kanban, dashboard.
- `bootstrap_no_docker.sh`: idempotent clean-VPS bootstrap for host/no-Docker Hermes; requires `--yes`.
- `write_profile_souls.py`: writes role `SOUL.md` files with timestamped backups; supports `--dry-run`.
- `start_dashboard.sh`: starts dashboard on loopback only; requires `--yes-build` before first web UI build.
- `refresh_systemd_unit.sh`: refreshes `hermes-gateway.service` using the Hermes user's environment; requires `--yes` and root/sudo.
- `collect_telegram_topics.py`: reads the bot token from `.env`, calls Telegram `getUpdates`, and prints `chat_id/thread_id` without printing the token.
- `smoke_telegram_bot.sh`: validates Telegram `.env` and Bot API `getMe` without printing the token.
- `smoke_browser_web.sh`: runs browser and web-search smoke prompts through Hermes.
- `smoke_kanban_task.sh`: creates an idempotent Kanban task and verifies the dispatcher runs the assigned profile.
- `backup_hermes_config.sh`: creates a timestamped backup of config/profile/memory/kanban files without printing secrets.
- `start_desktop_bridge.sh`: starts a local SSH tunnel to a remote loopback-only Hermes dashboard/API and verifies the local URL.

Example remote use:

```bash
ssh hermes@HOST 'bash -s' < scripts/verify_hermes.sh
ssh root@HOST 'bash -s' < scripts/fast_doctor.sh
ssh root@HOST 'bash -s -- --yes' < scripts/bootstrap_no_docker.sh
ssh root@HOST 'bash -s' < scripts/smoke_telegram_bot.sh
ssh hermes@HOST 'bash -s' < scripts/smoke_browser_web.sh
ssh hermes@HOST 'python3 - --dry-run' < scripts/write_profile_souls.py
ssh hermes@HOST 'bash -s -- --yes-build' < scripts/start_dashboard.sh
ssh hermes@HOST 'python3 -' < scripts/collect_telegram_topics.py
ssh hermes@HOST 'bash -s -- --assignee planner' < scripts/smoke_kanban_task.sh
scripts/start_desktop_bridge.sh --host HOST
```

## Read References As Needed

- For exact command sequence and checks, read `references/runbook.md`.
- For host/no-Docker terminal, approvals, gateway, optional Docker, and dashboard config snippets, read `references/config-patterns.md`.
- For Telegram group creation, topics, bot admin setup, and `chat_id/thread_id` collection, read `references/telegram-topics.md`.
- For profile role files and workspace `AGENTS.md`, read `references/profile-templates.md`.
- For Kanban and dashboard operation, read `references/kanban-dashboard.md`.
- For connecting local/desktop Hermes to a remote Hermes server, read `references/local-desktop-bridge.md`.
- For subscriber handoff/intake, read `references/subscriber-intake.md`; ask only for server IP and server password by default.
- For OpenAI Codex login/device auth, read `references/openai-codex-oauth.md`.
- For support triage by symptom, read `references/failure-matrix.md`.
- For common failures and exact recovery commands, read `references/troubleshooting.md`.

## Safety Defaults

Use these defaults unless the user explicitly chooses otherwise:

- SSH command: `ssh hermes@HOST`; `/32` belongs in firewall rules, not SSH.
- Dashboard: `127.0.0.1:9119` plus SSH tunnel.
- API server: disabled unless needed; if enabled, bind to localhost/VPN only and require a key.
- Terminal backend: host/no-Docker unless the user explicitly chooses Docker.
- Environment: no broad env passthrough; keep secrets in `.env` only.
- Secrets: keep in `~/.hermes/.env`, `chmod 600`, never paste into chat/logs.
- Gateway users: allowlist IDs; avoid `GATEWAY_ALLOW_ALL_USERS=true` except temporary debugging.
- Root/sudo: use only for systemd, user creation, firewall, and OS packages.
- Desktop bridge: prefer SSH tunnels to remote localhost ports. Do not expose dashboard/API to `0.0.0.0` for convenience.

## If Something Looks Wrong

Use systematic debugging: read the exact error, check the live process and config path, compare expected vs installed systemd unit, and run one minimal verification before changing more. Common pitfalls:

- `hermes` command exists for user `hermes` but not in the active service PATH.
- Terminal tool inside Hermes may show an unexpected `HOME`; verify systemd `User`, `HOME`, and `HERMES_HOME` before changing config.
- `hermes gateway restart --system` run as `root` may generate a stale unit unless `HOME=/home/hermes HERMES_HOME=/home/hermes/.hermes` are set.
- Dashboard first launch may need bundled Node/npm and a web UI build.
- A blank dashboard or Kanban tab is usually a frontend/tunnel problem, not a Kanban DB problem. Separate SSH tunnel, dashboard process, API auth, plugin assets, and browser console errors before restarting gateway.
- A dashboard watchdog that uses `--skip-build` only restarts the existing `web_dist`; it will not repair a broken frontend bundle. Rebuild `web_dist` explicitly, then restart the watchdog/dashboard.
