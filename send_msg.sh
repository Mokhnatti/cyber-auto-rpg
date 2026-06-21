#!/bin/bash
# Текстовое сообщение в игрового бота всем получателям (.game_chat_ids).
# Использование: ./send_msg.sh "текст"  |  ./send_msg.sh "текст" 398299572 (конкретному)
TOKEN=$(cat /home/ramil/.game_bot_token)
MSG="$1"
TARGET="$2"
if [ -n "$TARGET" ]; then
  curl -s -F "chat_id=$TARGET" -F "text=$MSG" "https://api.telegram.org/bot${TOKEN}/sendMessage" -o /dev/null -w "tg $TARGET: %{http_code}\n"
else
  while read CID; do
    [ -z "$CID" ] && continue
    curl -s -F "chat_id=$CID" -F "text=$MSG" "https://api.telegram.org/bot${TOKEN}/sendMessage" -o /dev/null -w "tg $CID: %{http_code}\n"
  done < /home/ramil/.game_chat_ids
fi
