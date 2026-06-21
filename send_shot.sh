#!/bin/bash
# отправка /tmp/game_shot.png в игровой телеграм-бот
TOKEN=$(cat /home/ramil/.game_bot_token)
CHAT=$(cat /home/ramil/.game_chat_id)
curl -s -F "chat_id=$CHAT" -F "photo=@/tmp/game_shot.png" -F "caption=${1:-🎮 cyber-auto-rpg}" "https://api.telegram.org/bot${TOKEN}/sendPhoto" -o /dev/null -w "tg: %{http_code}\n"
