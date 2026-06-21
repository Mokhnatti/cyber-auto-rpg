#!/usr/bin/env python3
# Читает НОВЫЕ сообщения игрового бота (getUpdates с offset) и печатает их.
# offset хранится в /home/ramil/.game_bot_offset — повторный запуск не дублирует.
import json, os, sys, urllib.request

TOKEN = open('/home/ramil/.game_bot_token').read().strip()
OFF = '/home/ramil/.game_bot_offset'
offset = int(open(OFF).read().strip()) if os.path.exists(OFF) else 0

url = f"https://api.telegram.org/bot{TOKEN}/getUpdates?timeout=0"
if offset:
    url += f"&offset={offset}"
try:
    data = json.load(urllib.request.urlopen(url, timeout=30))
except Exception as e:
    print("ERR", e); sys.exit(1)

maxid = offset
msgs = []
for u in data.get('result', []):
    maxid = max(maxid, u['update_id'] + 1)
    m = u.get('message') or u.get('edited_message')
    if not m:
        continue
    name = m.get('from', {}).get('first_name', '?')
    cid = m.get('chat', {}).get('id')
    text = m.get('text', '') or '[не-текст]'
    msgs.append(f"[{cid} · {name}] {text}")

if maxid != offset:
    open(OFF, 'w').write(str(maxid))

if msgs:
    print("\n".join(msgs))
else:
    print("(нет новых сообщений)")
