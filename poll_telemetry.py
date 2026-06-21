#!/usr/bin/env python3
# Долговременный поллер телеметрии: тянет ntfy-топик каждые 5 мин,
# дописывает НОВЫЕ записи (дедуп по id) в постоянный CSV. Копит бессрочно.
import time, json, urllib.request, os, csv

TOPIC = "https://ntfy.sh/cyberautorpg-tt-9f3a7k/json?poll=1"
OUT = "/home/ramil/cyber-telemetry.csv"
SEEN = "/home/ramil/.cyber-telemetry-seen"
FIELDS = ["ts", "id", "nick", "event", "stage", "best", "maxlvl", "cores", "scrap", "gold", "ver"]


def load_seen():
    if os.path.exists(SEEN):
        return set(open(SEEN).read().split())
    return set()


def main():
    if not os.path.exists(OUT):
        with open(OUT, "w", newline="") as f:
            csv.writer(f).writerow(FIELDS)
    seen = load_seen()
    while True:
        try:
            req = urllib.request.Request(TOPIC, headers={"User-Agent": "tt-poller"})
            data = urllib.request.urlopen(req, timeout=20).read().decode()
            new = 0
            for line in data.splitlines():
                if not line.strip():
                    continue
                m = json.loads(line)
                if m.get("event") != "message":
                    continue
                mid = m.get("id", "")
                if mid in seen:
                    continue
                seen.add(mid)
                try:
                    d = json.loads(m.get("message", "{}"))
                except Exception:
                    d = {}
                row = [m.get("time", ""), mid, d.get("nick", ""), d.get("event", ""), d.get("stage", ""),
                       d.get("best", ""), d.get("maxlvl", ""), d.get("cores", ""), d.get("scrap", ""),
                       d.get("gold", ""), d.get("ver", "")]
                with open(OUT, "a", newline="") as f:
                    csv.writer(f).writerow(row)
                with open(SEEN, "a") as f:
                    f.write(mid + "\n")
                new += 1
            if new:
                print(time.strftime("%H:%M:%S"), "+%d записей" % new, flush=True)
        except Exception as e:
            print(time.strftime("%H:%M:%S"), "ERR", str(e)[:80], flush=True)
        time.sleep(300)


main()
