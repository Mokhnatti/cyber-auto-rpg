#!/usr/bin/env python3
# REALTIME-МОСТ: long-poll игрового бота → впечатывает сообщения Рамиля прямо в мою tmux-консоль.
# Только chat_id из ALLOW (безопасность: bypassPermissions активен!). Диана НЕ рулит.
import json, os, subprocess, time, urllib.request

TOKEN = open('/home/ramil/.game_bot_token').read().strip()
ALLOW = {398299572}                 # только Рамиль может впечатывать команды
PANE = 'game-claude:0.0'            # моя tmux-сессия
OFF = '/home/ramil/.bridge_offset'

def tmux_type(text: str) -> None:
    # литерально впечатать текст, Enter — отдельной командой (иначе race с input-буфером Claude Code)
    subprocess.run(['tmux', 'send-keys', '-t', PANE, '-l', '--', text])
    time.sleep(0.3)
    subprocess.run(['tmux', 'send-keys', '-t', PANE, 'Enter'])

first_drain = not os.path.exists(OFF)   # первый запуск: старые сообщения проглотить, не впечатывать
offset = int(open(OFF).read().strip()) if os.path.exists(OFF) else 0
print(f"[bridge] старт. pane={PANE} allow={ALLOW} offset={offset} drain={first_drain}", flush=True)

while True:
    try:
        url = f"https://api.telegram.org/bot{TOKEN}/getUpdates?timeout=30"
        if offset:
            url += f"&offset={offset}"
        data = json.load(urllib.request.urlopen(url, timeout=40))
    except Exception as e:
        print(f"[bridge] err {e}", flush=True)
        time.sleep(3)
        continue
    res = data.get('result', [])
    for u in res:
        offset = max(offset, u['update_id'] + 1)
        open(OFF, 'w').write(str(offset))
        if first_drain:
            continue
        m = u.get('message')
        if not m:
            continue
        cid = m.get('chat', {}).get('id')
        text = m.get('text', '')
        if cid in ALLOW and text:
            print(f"[bridge] → впечатываю: {text[:60]}", flush=True)
            tmux_type(text)
    if res and first_drain:
        first_drain = False
        print("[bridge] старое проглочено, слушаю новое", flush=True)
