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

    shot("0_nick")
    click(300, 622, 4.0)                        # ▶ ИГРАТЬ — пройти ник-гейт, войти в бой (центр кнопки y≈622; было 590 = промах в зазор → тест не входил в бой)
    shot("0_start")
    click(545, 32);  shot("1_speed")          # скорость x1/x2/x3 (верх-право)
    click(448, 32)                             # 🤖 АВТО вкл (верх-право)
    click(448, 32); shot("1b_auto")            # 🤖 АВТО выкл
    click(114, 930); shot("2_inv_open")        # 📊 ПРОКАЧКА (нижний бар, левая)
    for yy in (162, 264, 366, 468):            # 4 кнопки уровня
        click(360, yy)
    shot("3_levelups")
    click(300, 810); shot("4_after_close")     # ЗАКРЫТЬ (вернуть в бой)
    click(86, 850);  shot("5_ult_snipe")       # ульта снайпера → режим прицела (бар поднят)
    click(480, 560); shot("6_snipe_shot")      # тап врага → выстрел
    click(228, 850)                            # ульта штурма
    click(370, 850)                            # ульта танка
    click(513, 850); shot("7_ults")            # ульта хакера
    click(292, 930); shot("7b_equip")          # 🦾 ЭКИПИРОВКА (сетка 4×3)
    click(300, 810)                            # закрыть экип
    click(33, 30);   shot("8_restart")         # ↻ РЕСТАРТ (лев-верх угол)
    b.close()

print("=== СМОК-ТЕСТ ===")
print(f"ошибок/предупреждений консоли: {len(errors)}")
for e in errors[:25]:
    print("  -", e[:200])
print("скрины: /tmp/smoke_0_nick..8.png")
