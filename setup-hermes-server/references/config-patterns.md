# Hermes Config Patterns

## Host / No-Docker Terminal Backend

Use structured YAML edits instead of ad hoc string replacements. Keep secrets in `.env` only.

Before changing live config, create a backup:

```bash
ssh hermes@HOST 'bash -s' < scripts/backup_hermes_config.sh
```

Recommended `~/.hermes/config.yaml` fragments:

```yaml
terminal:
  backend: local
  cwd: /srv/hermes-workspace
  timeout: 180
  env_passthrough: []
  persistent_shell: true
  lifetime_seconds: 300

approvals:
  mode: smart
  cron_mode: deny
  timeout: 60

kanban:
  dispatch_in_gateway: true
  dispatch_interval_seconds: 60
  failure_limit: 2
  worker_log_rotate_bytes: 2097152
  worker_log_backup_count: 1
  auto_decompose: true
  auto_decompose_per_tick: 3
  dispatch_stale_timeout_seconds: 14400
```

## Optional Docker Terminal Backend

Use Docker only when the user explicitly asks for containerized execution:

```yaml
terminal:
  backend: docker
  cwd: /srv/hermes-workspace
  timeout: 180
  env_passthrough: []
  docker_forward_env: []
  docker_env: {}
  docker_mount_cwd_to_workspace: false
  docker_volumes:
    - /home/hermes/.hermes/cache/documents:/output
  container_cpu: 1
  container_memory: 2048
  container_persistent: true
  persistent_shell: true
  lifetime_seconds: 300
```

## Gateway Allowlist

Prefer explicit allowed users:

```dotenv
TELEGRAM_BOT_TOKEN=...
TELEGRAM_ALLOWED_USERS=123456789
GATEWAY_ALLOW_ALL_USERS=false
```

Do not print `.env` content. Check presence only:

```bash
python3 - <<'PY'
from pathlib import Path
p=Path('/home/hermes/.hermes/.env')
print('env_exists=', p.exists())
print('mode=', oct(p.stat().st_mode & 0o777) if p.exists() else 'missing')
PY
```

## Topic To Profile Routing

If Hermes supports topic routing in `platforms.telegram.extra.group_topics`, use this shape:

```yaml
platforms:
  telegram:
    enabled: true
    extra:
      group_topics:
        - chat_id: -1003972922634
          topics:
            - thread_id: 2
              name: Ассистент
              profile: default
            - thread_id: 3
              name: Планирование
              profile: planner
            - thread_id: 4
              name: Код / DevOps
              profile: coder
            - thread_id: 5
              name: Контент
              profile: editor
            - thread_id: 6
              name: Мониторинг
              profile: monitor
            - thread_id: 7
              name: Логи / Ошибки
              profile: monitor
```

If the installed Hermes version does not support this, do not guess. Search the code for existing route support and add tests before patching.

## Dashboard

Dashboard is separate from gateway. Start on loopback only:

Use `scripts/start_dashboard.sh` when available; it refuses non-loopback binds and requires `--yes-build` if the web UI has not been built yet.

```bash
export PATH="/home/hermes/.hermes/node/bin:$PATH"
nohup /home/hermes/.local/bin/hermes dashboard --host 127.0.0.1 --port 9119 --no-open   > /home/hermes/.hermes/logs/dashboard.log 2>&1 &
```

Check:

```bash
/home/hermes/.local/bin/hermes dashboard --status
ss -ltnp | grep ':9119'
curl -sS http://127.0.0.1:9119/ | head
curl -sS http://127.0.0.1:9119/api/dashboard/plugins
```

Mac tunnel:

```sshconfig
Host hermes-dashboard
  HostName 178.105.162.150
  User hermes
  LocalForward 9119 127.0.0.1:9119
  ServerAliveInterval 30
  ServerAliveCountMax 3
```

Run:

```bash
ssh -N hermes-dashboard
```

Open: `http://127.0.0.1:9119`.
