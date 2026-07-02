# CLAUDE.md — cyber-auto-rpg (выделенная игровая сессия)

> 🚨 **ПЕРВЫМ ДЕЛОМ прочитай [SESSION-HANDOFF.md](./SESSION-HANDOFF.md) — там ПОЛНЫЙ снимок контекста** (что сделано, что открыто, инфраструктура, как продолжить). Затем [CONCEPT.md](./CONCEPT.md) — геймдизайн (источник правды).

Киберпанк авто/idle-RPG, Godot 4.7, мобилка, F2P+гача. Прототип → GitHub Pages → итерации по скринам в Telegram.

## Быстрый старт для новой сессии
1. Read `SESSION-HANDOFF.md` (контекст) + `CONCEPT.md` (дизайн).
2. Скажи Рамилю по-русски: «контекст поднят, помню всё» + краткий статус (§2 handoff) + следующая задача (§4.1 — слоты на скелете).
3. Продолжай. Не предлагать «отдохнуть/спать/закончить».

## Жёсткие правила
- **Коммит/пуш как Mokhnatti:** `git -c user.name="Mokhnatti" -c user.email="glukmalai@gmail.com" commit`; push `origin main`. Публичный репо — БЕЗ секретов (токены бота только в `~/.game_bot_token` / `~/.claude/CREDENTIALS.md`).
- **Скрины:** собрать (godot import/export → http.server → `shot.py`) → `Read /tmp/game_shot.png` (самопроверка) → `./send_shot.sh "подпись"` (Рамилю+Диане). Pipeline — §6 handoff.
- **После правок — `smoke_test.py`** (автотест кнопок, должно быть 0 ошибок).
- **Связь:** переходим на официальный Telegram-Channel (§5 handoff). Bun ✓ установлен. tmux-мост НЕ работает (Remote Control).

## Статус (21.06.2026)
Прогресс-система собрана: 4 класса, ауры, ульты (снайпер=тап-таргет), 2-слойный прогресс (уровень=множитель × оружие+импланты=база, мердж дублей), импланты ПЕР-ПЕРСОНАЖ, экран ЭКИПИРОВКИ (выбор бойца+пушка+слоты), дроп под бойца, smoke 0 ошибок. **Следующее: слоты имплантов на схематичном скелете (киберпанк-вид).**

## 🧠 Модель: Fable 5 (до 06.07.2026)
- Эта сессия (game-claude) запущена на **Fable 5** (`--model claude-fable-5`) на бесплатное окно до 06.07.2026. Таймер `game-revert-opus` сам вернёт на **Opus** 06.07 09:00 UTC (с 07.07 Fable платный за usage-кредиты).
- Тяжёлые задачи (архитектура игры, рефактор, разбор багов) — Fable тянет отлично. Мелочь можно и на Opus.
- **Fable-сабагенты:** во frontmatter сабагента `model: fable` → Fable-оркестратор поверх дешёвых Sonnet/Haiku-воркеров.
- Если ответ «Claude Fable 5 is currently unavailable» или сессию отскочило на Opus (слово «cyber» в названии репо может триггерить кибербез-классификатор): рестарт — `sudo -u ramil tmux kill-session -t game-claude` + `sudo systemctl restart game-claude`. Модель задаётся в drop-in `/etc/systemd/system/game-claude.service.d/continue.conf`.
- Нужен Claude Code ≥2.1.170 (стоит 2.1.197).
