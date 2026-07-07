# Setup Hermes Server

Skill-пакет для быстрой установки, ремонта и поддержки Hermes Agent на VPS.

Основной сценарий: пользователь дает только IP сервера и пароль, агент сам подключается, диагностирует состояние, выбирает узкий режим работы и не трогает лишние подсистемы.

## Для Чего

- Установка Hermes на чистый VPS без Docker.
- Настройка systemd gateway.
- Подключение Telegram.
- Подключение OpenAI Codex OAuth.
- Проверка browser/web tools.
- Доступ к dashboard через SSH tunnel.
- Связка локального/desktop Hermes с серверным Hermes.
- Быстрая диагностика проблем у пользователей.

## Быстрый Старт Для Пользователя

Запросить только:

```text
server_ip
server_password
```

Дальше по умолчанию:

```bash
ssh root@SERVER_IP
```

Не спрашивать заранее SSH user, SSH key, ОС, Docker, firewall, dashboard или Telegram-настройки. Сначала подключиться и определить состояние сервером.

## Режимы

| Режим | Когда использовать | Первый шаг |
| --- | --- | --- |
| `support-triage` | "что-то не работает" | `scripts/fast_doctor.sh` |
| `full-bootstrap` | чистый VPS, нужна установка с нуля | `scripts/bootstrap_no_docker.sh --yes` |
| `telegram-only` | не работает Telegram | `scripts/smoke_telegram_bot.sh` |
| `browser-web-only` | не работает browser/web search | `scripts/smoke_browser_web.sh` |
| `openai-codex-oauth` | нужно залогинить OpenAI Codex | `references/openai-codex-oauth.md` |
| `desktop-bridge` | локальный Hermes должен открыть серверный Hermes | `scripts/start_desktop_bridge.sh --host HOST` |
| `repair` | один конкретный симптом | `references/failure-matrix.md` |

Перед изменениями агент должен явно зафиксировать:

```text
Selected mode:
Allowed changes:
Forbidden changes:
Verification:
Stop condition:
```

## Скрипты

| Скрипт | Назначение | Меняет сервер |
| --- | --- | --- |
| `inspect_server.sh` | read-only инвентаризация VPS | Нет |
| `fast_doctor.sh` | быстрый вердикт для саппорта | Нет |
| `verify_hermes.sh` | подробная проверка Hermes | Нет |
| `bootstrap_no_docker.sh` | установка Hermes без Docker | Да, только с `--yes` |
| `refresh_systemd_unit.sh` | обновить `hermes-gateway.service` | Да, только с `--yes` |
| `smoke_telegram_bot.sh` | проверить Telegram bot token через Bot API | Нет |
| `smoke_browser_web.sh` | проверить browser/web tools | Нет |
| `start_dashboard.sh` | запустить dashboard на loopback | Да |
| `start_desktop_bridge.sh` | локальный SSH tunnel к серверу | Только локальный tunnel |
| `collect_telegram_topics.py` | собрать Telegram `chat_id/thread_id` | Нет |
| `write_profile_souls.py` | записать `SOUL.md` профилей | Да, кроме `--dry-run` |
| `smoke_kanban_task.sh` | проверить Kanban dispatcher | Да, создает smoke task |
| `backup_hermes_config.sh` | сделать backup конфигов | Да, пишет backup |

## Типовой Flow

Диагностика:

```bash
ssh root@HOST 'bash -s' < scripts/fast_doctor.sh
```

Установка без Docker:

```bash
ssh root@HOST 'bash -s -- --yes' < scripts/bootstrap_no_docker.sh
```

Telegram:

```bash
ssh root@HOST 'bash -s' < scripts/smoke_telegram_bot.sh
```

Browser/Web:

```bash
ssh hermes@HOST 'bash -s' < scripts/smoke_browser_web.sh
```

Desktop bridge:

```bash
scripts/start_desktop_bridge.sh --host HOST
```

## Для Codex

Codex использует [SKILL.md](./SKILL.md) как основной entry point.

При работе с этой папкой как с проектом дополнительно читай [AGENTS.md](./AGENTS.md). Он фиксирует правила редактирования skill-пакета: не раздувать `SKILL.md`, держать сценарии в `references/`, повторяемые команды в `scripts/`, не печатать секреты.

## Для Claude Code

Claude Code должен начинать с [CLAUDE.md](./CLAUDE.md), затем читать [SKILL.md](./SKILL.md).

Правило то же: выбрать один режим, выполнить только его, проверить только выбранный scope.

## References

- `runbook.md` — основные recipes и этапы.
- `user-intake.md` — что спрашивать у пользователя.
- `failure-matrix.md` — симптом -> причина -> проверка -> фикс.
- `openai-codex-oauth.md` — OpenAI Codex device auth.
- `local-desktop-bridge.md` — локальный desktop к серверному Hermes.
- `telegram-topics.md` — Telegram topics и routing.
- `config-patterns.md` — безопасные config snippets.
- `kanban-dashboard.md` — Kanban и dashboard.
- `troubleshooting.md` — подробные разборы проблем.

## Безопасность

- Не печатать `.env`, токены, пароли, приватные ключи, cookies.
- Dashboard/API не открывать наружу; только `127.0.0.1` и SSH tunnel.
- Docker не использовать по умолчанию.
- Для пользователей по умолчанию просить только IP и пароль сервера.
- Любая установка пакетов, systemd-изменения и bootstrap требуют явного подтверждения.

## Проверка Skill-Пакета

Минимальная локальная проверка:

```bash
for f in scripts/*.sh; do bash -n "$f" || exit 1; done
python3 -B -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("scripts").glob("*.py")]'
ruby -e 'require "yaml"; YAML.load_file("SKILL.md"); YAML.load_file("agents/openai.yaml")'
rg -n '[[:blank:]]$' .
rg -n '^(<<<<<<<|=======|>>>>>>>)' .
```

`shellcheck` полезен, но не обязателен, если он не установлен.
