# Telegram Group Topics Setup

This phase requires the user in Telegram. Do not pretend it can be fully done from the server.

## What To Tell The User

Ask the user to do these steps in the Telegram client:

1. Create a new group or use an existing private work group.
2. Convert it to a supergroup if Telegram asks.
3. Enable Topics:
   `Group Info -> Edit -> Topics -> On`.
4. Add the Hermes bot to the group.
5. Make the bot admin, or at minimum allow it to read and send messages in topics.
6. Create topics:
   - `Ассистент`
   - `Планирование`
   - `Код / DevOps`
   - `Контент`
   - `Мониторинг`
   - `Логи / Ошибки`
7. In each topic, send:
   ```text
   ping
   /status
   /title Hermes Control / <название топика>
   ```
8. Then send `/profile` and `/status` separately in every topic after routing is configured.

Important: Telegram commands may need bot mention in groups, for example:

```text
/status@your_bot_username
/profile@your_bot_username
```

If one message contains two commands like `/profile\n/status`, Hermes may process only the first one. Ask the user to send them separately.

## Getting chat_id And thread_id

Use the safest available method.

### Option A: Hermes logs

After the user sends `ping` in every topic:

```bash
journalctl -u hermes-gateway -n 300 --no-pager | grep -Ei 'telegram|chat|thread|topic|message' || true
tail -300 /home/hermes/.hermes/logs/gateway.log | grep -Ei 'telegram|chat|thread|topic|message' || true
```

Look for:

```text
chat_id=-100...
thread_id=...
```

### Option B: Bot API getUpdates

Only if it can be done without printing the bot token. Do not paste the token into chat. Run it on the server using `.env`:

Preferred with bundled script:

```bash
ssh hermes@HOST 'python3 -' < scripts/collect_telegram_topics.py
```

Manual equivalent:

```bash
python3 - <<'PY'
from pathlib import Path
from urllib.request import urlopen
from urllib.parse import quote
import json

env = Path('/home/hermes/.hermes/.env').read_text(encoding='utf-8')
token = None
for line in env.splitlines():
    if line.startswith('TELEGRAM_BOT_TOKEN='):
        token = line.split('=', 1)[1].strip().strip('"').strip("'")
        break
if not token:
    raise SystemExit('TELEGRAM_BOT_TOKEN not found')
url = f'https://api.telegram.org/bot{quote(token)}/getUpdates'
data = json.load(urlopen(url, timeout=10))
for item in data.get('result', []):
    msg = item.get('message') or item.get('edited_message') or {}
    chat = msg.get('chat') or {}
    print({
        'chat_id': chat.get('id'),
        'chat_title': chat.get('title'),
        'thread_id': msg.get('message_thread_id'),
        'text': (msg.get('text') or '')[:80],
    })
PY
```

This prints IDs and message snippets, not the token.

## Mapping Topics To Profiles

Expected mapping:

```text
Ассистент      -> default
Планирование  -> planner
Код / DevOps  -> coder
Контент       -> editor
Мониторинг    -> monitor
Логи / Ошибки -> monitor
```

Example config shape:

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

Use a YAML parser for edits. Back up config first:

```bash
cp /home/hermes/.hermes/config.yaml /home/hermes/.hermes/config.yaml.before-telegram-topics-$(date -u +%Y%m%d-%H%M%S)
```

## Restart And Validate

Restart gateway:

```bash
/home/hermes/.local/bin/hermes gateway restart
```

If this is a system gateway and restart requires root:

```bash
sudo HOME=/home/hermes USER=hermes LOGNAME=hermes HERMES_HOME=/home/hermes/.hermes \
  /home/hermes/.local/bin/hermes gateway restart --system
```

Ask the user to send in every topic, one command per message:

```text
/profile
/status
```

Expected:

```text
Ассистент      -> Profile: default
Планирование  -> Profile: planner
Код / DevOps  -> Profile: coder
Контент       -> Profile: editor
Мониторинг    -> Profile: monitor
Логи / Ошибки -> Profile: monitor
```

If natural-language prompts report `HOME=/root` or `HERMES_HOME` empty, verify the systemd user environment and terminal backend. `/profile` and `/status` are the source of truth for route/profile.
