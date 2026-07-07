# CLAUDE.md

Instructions for Claude Code when working with this Hermes setup skill.

## Start Here

Read in this order:

1. `SKILL.md`
2. the one relevant file in `references/`
3. the one relevant script in `scripts/`

Do not load every reference file unless the task explicitly requires a full audit.

## Intent Router

Select exactly one mode before acting:

- `full-bootstrap`: clean VPS or full rebuild.
- `telegram-only`: Telegram gateway setup or repair.
- `browser-web-only`: browser and web-search setup or repair.
- `desktop-bridge`: local desktop to remote Hermes through SSH tunnel.
- `openai-codex-oauth`: OpenAI Codex device auth for the Hermes runtime user.
- `support-triage`: run `scripts/fast_doctor.sh`, then use `references/failure-matrix.md`.
- `repair`: one named symptom only.

If the user narrows scope, stop unrelated work immediately.

## Subscriber Defaults

For subscriber installs, ask only for:

```text
server_ip
server_password
```

Assume SSH user `root` unless the user says otherwise. Detect OS, firewall, existing Hermes state, and service state after connecting.

## Safety Rules

- Never print `.env`, tokens, passwords, private keys, cookies, seed phrases, or auth files.
- Keep dashboard/API on `127.0.0.1`; use SSH tunnels.
- Use host/no-Docker execution by default.
- Do not alter firewall, SSH access, packages, or systemd without a matching selected mode.
- Use bundled scripts rather than rewriting long shell blocks.

## Claude Code Workflow

Before changes, write:

```text
Selected mode:
Allowed changes:
Forbidden changes:
Verification:
Stop condition:
```

For support:

```bash
scripts/fast_doctor.sh
```

For symptom mapping:

```text
references/failure-matrix.md
```

For installation:

```bash
scripts/bootstrap_no_docker.sh --yes
```

For Telegram:

```bash
scripts/smoke_telegram_bot.sh
```

For browser/web:

```bash
scripts/smoke_browser_web.sh
```

## Editing This Skill

- Keep `SKILL.md` concise.
- Put detailed procedures in `references/`.
- Put repeatable checks or setup steps in `scripts/`.
- Update `README.md` when user-facing usage changes.
- Update `agents/openai.yaml` when the skill's summary or default behavior changes.

## Verification

Run after edits:

```bash
for f in scripts/*.sh; do bash -n "$f" || exit 1; done
python3 -B -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("scripts").glob("*.py")]'
ruby -e 'require "yaml"; YAML.load_file("SKILL.md"); YAML.load_file("agents/openai.yaml")'
rg -n '[[:blank:]]$' .
rg -n '^(<<<<<<<|=======|>>>>>>>)' .
```
