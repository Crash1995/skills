# AGENTS.md

Инструкции для Codex при работе с этим skill-пакетом.

## Основной Entry Point

Сначала читать:

1. `SKILL.md`
2. нужный файл из `references/`
3. нужный скрипт из `scripts/`

Не читать все references подряд без причины.

## Режим Работы

Перед командами выбрать один режим:

- `full-bootstrap`
- `telegram-only`
- `browser-web-only`
- `desktop-bridge`
- `openai-codex-oauth`
- `support-triage`
- `repair`

Если пользователь сужает задачу словами `только`, `быстро`, `just`, `only`, сбросить лишний scope.

## Правила Правок

- `SKILL.md` держать коротким: маршрутизация, safety, список scripts/references.
- Длинные инструкции класть в `references/`.
- Повторяемые команды класть в `scripts/`.
- Не добавлять новые режимы, если хватает `repair` или `support-triage`.
- Не дублировать одно и то же между README, SKILL и references.

## Безопасность

- Не печатать `.env`, токены, пароли, приватные ключи, cookies.
- Не открывать dashboard/API на `0.0.0.0`.
- Не включать Docker по умолчанию.
- Не менять firewall/SSH/systemd без явного scope.
- Для пользователя спрашивать только `server_ip` и `server_password`, если пользователь не дал другое.

## Проверки После Правок

```bash
for f in scripts/*.sh; do bash -n "$f" || exit 1; done
python3 -B -c 'import pathlib; [compile(p.read_text(), str(p), "exec") for p in pathlib.Path("scripts").glob("*.py")]'
ruby -e 'require "yaml"; YAML.load_file("SKILL.md"); YAML.load_file("agents/openai.yaml")'
rg -n '[[:blank:]]$' .
rg -n '^(<<<<<<<|=======|>>>>>>>)' .
```

Если `shellcheck` установлен, прогнать его по `scripts/*.sh`.
