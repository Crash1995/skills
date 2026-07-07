# Subscriber Intake

Use this when setting up Hermes for a subscriber or non-technical user.

## Default Intake

Ask only for:

```text
server_ip
server_password
```

Default SSH user is `root`.

Do not ask upfront for:

- SSH user;
- SSH key;
- OS/version;
- package manager;
- firewall type;
- Docker preference;
- Telegram details;
- dashboard preference;
- browser/web preference.

Detect those after connecting. Ask follow-up questions only when a required value cannot be discovered or when the action needs a user-owned external token.

## First Connection Pattern

Use a password login as root unless the user says otherwise:

```bash
ssh root@SERVER_IP
```

After login, run the safe inventory from `runbook.md`.

## Secrets Handling

Do not print passwords, `.env`, tokens, auth files, seed phrases, private keys, or cookies.

If the subscriber pastes secrets into chat, do not repeat them back. Refer to them by purpose:

```text
server password received
Telegram bot token received
OpenAI device auth completed
```

## When More Info Is Allowed

Ask for more only when necessary:

- Telegram bot token: only when configuring Telegram gateway.
- Telegram user ID: only when allowlisting a user.
- OpenAI device code action: only during OpenAI Codex OAuth.
- Domain/DNS: only when the user explicitly wants a public domain.
- SSH key: only if password login is disabled.

## Subscriber-Friendly Stop Report

End with a short status:

```text
Готово:
- Hermes работает
- Telegram работает
- OpenAI Codex подключен
- Browser/Web работает

Проверено:
- команда/проверка

Что нужно от тебя:
- одно действие, если осталось
```
