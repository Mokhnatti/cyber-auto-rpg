#!/usr/bin/env bash
# Перезапуск 4 ботов-плейтестеров (полностью отвязанные сессии через setsid)
pkill -f "godot.*--bot" 2>/dev/null
sleep 2
GODOT=/home/ramil/godot/godot
PROJ=/home/ramil/projects/cyber-auto-rpg/prototype
for pair in balanced:b rush:r hoard:h skill:s; do
  t=${pair%%:*}; s=${pair##*:}
  setsid "$GODOT" --headless --path "$PROJ" -- --bot --tactic="$t" --slot="$s" >> "/tmp/ttbot_$t.log" 2>&1 < /dev/null &
done
sleep 1
echo "bots launched"
