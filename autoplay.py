#!/usr/bin/env python3
# Автоигрок-плейтестер cyber-auto-rpg. Гоняет web-сборку на ПОСТОЯННОМ профиле
# (прогресс копится через сейв), логирует TTSTATE из консоли с временем.
# Стратегия: авто+x3, спам «К БОССУ», периодически прокачка/престиж.
# usage: autoplay.py [URL] [minutes]
import sys, time, datetime
from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8781/"
MINUTES = float(sys.argv[2]) if len(sys.argv) > 2 else 12.0
LOG = "/tmp/ttbot.log"
PROFILE = "/tmp/ttbot_profile"
ARGS = ["--use-gl=angle", "--use-angle=swiftshader", "--ignore-gpu-blocklist", "--enable-unsafe-swiftshader"]


def log(msg):
    line = f"{datetime.datetime.now().strftime('%H:%M:%S')} {msg}"
    print(line, flush=True)
    with open(LOG, "a") as f:
        f.write(line + "\n")


def main():
    deadline = time.time() + MINUTES * 60
    with sync_playwright() as p:
        ctx = p.chromium.launch_persistent_context(PROFILE, headless=True, viewport={"width": 600, "height": 960}, args=ARGS)
        pg = ctx.pages[0] if ctx.pages else ctx.new_page()
        pg.on("console", lambda m: (log("STATE " + m.text.split("TTSTATE", 1)[1].strip()) if "TTSTATE" in m.text else None))
        pg.on("pageerror", lambda e: log("PAGEERR " + str(e)[:120]))
        pg.goto(URL, wait_until="load", timeout=60000)
        time.sleep(13)
        log("=== started ===")
        # настройка: x3 + авто
        for _ in range(2):
            pg.mouse.click(545, 32); time.sleep(0.3)
        pg.mouse.click(448, 32); time.sleep(0.3)
        t_prokach = 0.0
        t_prestige = 0.0
        loop = 0
        while time.time() < deadline:
            loop += 1
            try:
                pg.mouse.click(300, 80); time.sleep(3.0)   # К БОССУ (прогресс/ретрай)
                t_prokach += 3; t_prestige += 3
                if t_prokach >= 25:                         # прокачка уровней за золото
                    t_prokach = 0
                    pg.mouse.click(114, 932); time.sleep(0.8)   # ПРОКАЧКА
                    for yy in (162, 264, 366, 468):
                        for _ in range(3):
                            pg.mouse.click(360, yy); time.sleep(0.15)
                    pg.mouse.click(300, 810); time.sleep(0.5)   # закрыть
                if t_prestige >= 180:                       # престиж + аугменты
                    t_prestige = 0
                    pg.mouse.click(450, 932); time.sleep(0.8)   # ПРЕСТИЖ
                    pg.mouse.click(300, 149); time.sleep(0.8)   # ПЕРЕЗАГРУЗИТЬСЯ
                    pg.mouse.click(450, 932); time.sleep(0.6)   # снова открыть
                    for yy in (300, 375, 450):                  # купить топ-аугменты
                        pg.mouse.click(540, yy); time.sleep(0.2)
                        pg.mouse.click(415, yy); time.sleep(0.2)   # экип
                    pg.mouse.click(300, 904); time.sleep(0.5)   # закрыть
            except Exception as e:
                log("ERR " + str(e)[:100])
                break
        log(f"=== done ({loop} loops) ===")
        try:
            ctx.close()
        except Exception:
            pass


main()
