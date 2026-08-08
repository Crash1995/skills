# OpenAI Codex OAuth

Use this when Hermes needs OpenAI/Codex login. Present the user-facing task as:

```text
подключить OpenAI Codex OAuth
```

## Goal

Authenticate the Linux user that runs Hermes, normally `hermes`, for OpenAI Codex.

## Preconditions

Check the runtime user and Codex CLI:

```bash
ssh root@HOST 'id hermes'
ssh root@HOST 'sudo -iu hermes bash -lc "command -v codex || true"'
ssh root@HOST 'sudo -iu hermes bash -lc "codex login status || true"'
```

If `codex` is missing and the user has approved installs, install it for the `hermes` user or system-wide according to the existing server pattern.

## Device Auth

Run device auth as the `hermes` user:

```bash
ssh root@HOST 'sudo -iu hermes bash -lc "codex login --device-auth"'
```

Give the user only the device URL and code shown by the command. Do not ask for an OpenAI password or API key.

## Verification

```bash
ssh root@HOST 'sudo -iu hermes bash -lc "codex login status"'
ssh root@HOST 'sudo -iu hermes bash -lc "/home/hermes/.local/bin/hermes -z \"Ответь только OK\""'
```

Expected:

```text
codex login status: logged in
Hermes smoke: OK
```

## Common Failures

Wrong user:

```text
OAuth completed under root, but systemd runs Hermes as hermes.
```

Fix: repeat device auth with `sudo -iu hermes`.

Missing Codex CLI:

```text
codex: command not found
```

Fix only after install approval. Do not swap model providers just to bypass OAuth.

Expired device code:

```text
device code expired
```

Fix: rerun device auth and ask the user to complete it immediately.

## Stop Condition

Stop after `codex login status` is logged in and the minimal Hermes smoke returns `OK`. Do not reconfigure Telegram, Kanban, dashboard, browser, or firewall in this mode.
