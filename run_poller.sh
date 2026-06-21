#!/usr/bin/env bash
pkill -f "poll_telemetry.py" 2>/dev/null
sleep 1
setsid python3 /home/ramil/projects/cyber-auto-rpg/poll_telemetry.py >> /tmp/ttpoller.log 2>&1 < /dev/null &
echo "poller launched"
