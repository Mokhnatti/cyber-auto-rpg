#!/usr/bin/env python3
# Скриншот веб-сборки игры через Playwright → /tmp/game_shot.png
import sys, time
from playwright.sync_api import sync_playwright

URL = sys.argv[1] if len(sys.argv) > 1 else "https://mokhnatti.github.io/cyber-auto-rpg/play/"
WAIT = int(sys.argv[2]) if len(sys.argv) > 2 else 16

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True, args=[
        "--use-gl=angle", "--use-angle=swiftshader",
        "--ignore-gpu-blocklist", "--enable-unsafe-swiftshader",
    ])
    page = browser.new_page(viewport={"width": 600, "height": 960}, device_scale_factor=1)
    page.goto(URL, wait_until="load", timeout=60000)
    time.sleep(WAIT)  # Godot wasm + coi reload + дать бою пойти
    # опц. клик по canvas-координатам: 3-й арг "click:X,Y"
    if len(sys.argv) > 3 and sys.argv[3].startswith("click:"):
        x, y = sys.argv[3][6:].split(",")
        page.mouse.click(float(x), float(y))
        time.sleep(1.5)
    page.screenshot(path="/tmp/game_shot.png")
    browser.close()
    print("OK saved /tmp/game_shot.png")
