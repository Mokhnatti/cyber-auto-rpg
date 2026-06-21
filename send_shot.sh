#!/bin/bash
# отправка /tmp/game_shot.png всем chat_id игрового бота (Рамиль + Диана)
TOKEN=$(cat /home/ramil/.game_bot_token)
CAP="${1:-🎮 cyber-auto-rpg}"
while read CID; do
  [ -z "$CID" ] && continue
  curl -s -F "chat_id=$CID" -F "photo=@/tmp/game_shot.png" -F "caption=$CAP" "https://api.telegram.org/bot${TOKEN}/sendPhoto" -o /dev/null -w "tg $CID: %{http_code}\n"
done < /home/ramil/.game_chat_ids
