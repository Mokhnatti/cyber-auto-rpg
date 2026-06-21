#!/usr/bin/env python3
# Смок-тест всех кнопок игры через Playwright.
# Кликает каждую кнопку, ловит ошибки консоли/JS, скринит ключевые шаги в /tmp/smoke_*.png
import sys, time
from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8779/"
errors = []

with sync_playwright() as p:
    b = p.chromium.launch(headless=True, args=[
        "--use-gl=angle", "--use-angle=swiftshader",
        "--ignore-gpu-blocklist", "--enable-unsafe-swiftshader"])
    pg = b.new_page(viewport={"width": 600, "height": 960})
    pg.on("console", lambda m: errors.append(f"[{m.type}] {m.text}") if m.type in ("error", "warning") else None)
    pg.on("pageerror", lambda e: errors.append(f"[pageerror] {e}"))
    pg.goto(URL, wait_until="load", timeout=60000)
    time.sleep(16)  # загрузка + дать ульты зарядиться

    def shot(n): pg.screenshot(path=f"/tmp/smoke_{n}.png")
    def click(x, y, pause=1.0):
        pg.mouse.click(x, y); time.sleep(pause)

    shot("0_start")
    click(545, 32);  shot("1_speed")          # кнопка скорости x1/x2/x3
    click(508, 120); shot("2_inv_open")        # ПРОКАЧКА (открыть)
    for yy in (162, 264, 366, 468):            # 4 кнопки уровня
        click(360, yy)
    shot("3_levelups")
    click(300, 810); shot("4_after_close")     # ЗАКРЫТЬ (должен вернуть в бой)
    click(86, 880);  shot("5_ult_snipe")       # ульта снайпера → режим прицела
    click(480, 560); shot("6_snipe_shot")      # тап врага → выстрел
    click(228, 880)                            # ульта штурма
    click(370, 880)                            # ульта танка
    click(512, 880); shot("7_ults")            # ульта хакера
    click(300, 940); shot("8_restart")         # РЕСТАРТ
    b.close()

print("=== СМОК-ТЕСТ ===")
print(f"ошибок/предупреждений консоли: {len(errors)}")
for e in errors[:25]:
    print("  -", e[:200])
print("скрины: /tmp/smoke_0..8.png")
