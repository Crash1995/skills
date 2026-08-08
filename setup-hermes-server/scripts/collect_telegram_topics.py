#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from urllib.parse import quote
from urllib.request import urlopen


def read_env_token(env_path: Path) -> str | None:
    if not env_path.exists():
        return None
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.strip() == "TELEGRAM_BOT_TOKEN":
            return value.strip().strip('"').strip("'")
    return None


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Print Telegram chat_id/thread_id records from getUpdates without printing the bot token."
    )
    parser.add_argument("--env", default="/home/hermes/.hermes/.env", help="Path to Hermes .env")
    parser.add_argument("--limit", type=int, default=100, help="getUpdates limit")
    args = parser.parse_args()

    token = os.environ.get("TELEGRAM_BOT_TOKEN") or read_env_token(Path(args.env))
    if not token:
        raise SystemExit("TELEGRAM_BOT_TOKEN not found in environment or .env")

    url = f"https://api.telegram.org/bot{quote(token)}/getUpdates?limit={args.limit}"
    data = json.load(urlopen(url, timeout=15))
    rows: list[tuple[str, str, str, str, str]] = []

    for item in data.get("result", []):
        msg = item.get("message") or item.get("edited_message") or {}
        if not msg:
            continue
        chat = msg.get("chat") or {}
        chat_id = str(chat.get("id", ""))
        chat_title = str(chat.get("title") or chat.get("username") or chat.get("first_name") or "")
        thread_id = str(msg.get("message_thread_id") or "")
        text = str(msg.get("text") or msg.get("caption") or "").replace("\n", " ")[:100]
        rows.append((chat_id, thread_id, chat_title, text, str(item.get("update_id", ""))))

    print("chat_id\tthread_id\tchat_title\tlast_text\tupdate_id")
    seen = set()
    for row in rows:
        key = (row[0], row[1], row[3])
        if key in seen:
            continue
        seen.add(key)
        print("\t".join(row))

    if not rows:
        print("No updates returned. Send 'ping' in each Telegram topic, then run again.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
