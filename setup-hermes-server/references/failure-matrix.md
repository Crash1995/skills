# Failure Matrix

Use this after `scripts/fast_doctor.sh` or when a user reports a symptom. Apply the smallest matching fix and stop after verification.

| Symptom or verdict | Likely cause | Check | Minimal fix | Verify |
| --- | --- | --- | --- | --- |
| `HERMES_NOT_INSTALLED` | Clean VPS or wrong user | `id hermes; ls -l /home/hermes/.local/bin/hermes` | Run `bootstrap_no_docker.sh --yes` after approval | `fast_doctor.sh` shows `HERMES_OK` |
| `GATEWAY_DOWN` | systemd service stopped or stale unit | `systemctl status hermes-gateway --no-pager -l` | `refresh_systemd_unit.sh --yes`; then restart service | `systemctl is-active hermes-gateway` |
| `OPENAI_CODEX_AUTH_MISSING` | Codex login was not completed for `hermes` user | `sudo -iu hermes codex login status` | Read `openai-codex-oauth.md`; run device auth as `hermes` | Hermes minimal smoke returns `OK` |
| `TELEGRAM_ENV_MISSING` | `.env` missing Telegram token or allowlist | `smoke_telegram_bot.sh` | Write `.env` with token and allowed user; `chmod 600`; restart gateway | `TELEGRAM_TOKEN_OK` |
| `TELEGRAM_TOKEN_INVALID` | Bad bot token or revoked bot | `smoke_telegram_bot.sh` | Ask for a fresh token; update `.env`; restart gateway | `TELEGRAM_TOKEN_OK` |
| `BROWSER_NOT_READY` | `agent-browser` or Chromium missing | `smoke_browser_web.sh --browser-only` | Run browser post-setup after install approval | `BROWSER_SMOKE_OK` |
| `WEB_NOT_READY` | Web/search toolset disabled or runtime lacks tool | `smoke_browser_web.sh --web-only` | Enable `web` in selected platform toolsets; restart gateway if needed | `WEB_SMOKE_OK` |
| `DASHBOARD_DOWN` | dashboard process not running | `sudo -iu hermes hermes dashboard --status` | `start_dashboard.sh --yes-build` on loopback | `curl 127.0.0.1:9119` returns HTML |
| `DESKTOP_BRIDGE_DOWN` | SSH tunnel not running or wrong port | `curl http://127.0.0.1:9119/` on local machine | `start_desktop_bridge.sh --host HOST` | local curl returns HTML |
| `HOME_ROOT_MISMATCH` | service generated or started under root env | `systemctl cat hermes-gateway` | refresh unit with `HOME=/home/hermes HERMES_HOME=/home/hermes/.hermes` | terminal tool reports expected workspace |
| `KANBAN_TIMEOUT` | worker waits for approvals or stale task | check task log in `~/.hermes/kanban/logs` | fix only if user requested Kanban; otherwise report as out of scope | assigned smoke task completes |

## Rules

- Do not run full bootstrap for a single repair verdict.
- Do not expose dashboard/API publicly to fix local access.
- Do not switch model providers to bypass OpenAI Codex OAuth.
- Do not ask for more user data unless the matrix fix requires a user-owned token or device auth action.
