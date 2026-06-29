# Firebase RTDB Security Rules — Инструкция деплоя

## Что это

Файл `firebase-rtdb-rules.json` содержит правила безопасности для Firebase Realtime Database.
Закрывает открытый test-mode (сейчас база полностью открыта для чтения/записи всем).

**После деплоя:**
- Только авторизованные пользователи могут читать/писать
- Каждый пишет только в свой `/players/{uid}`
- Клан-боссов и чат может писать только член клана
- Вклад в босса (`contrib/{uid}`) только владелец uid
- Лишние поля в документах заблокированы

---

## ВАЖНО: ПРЕДВАРИТЕЛЬНОЕ УСЛОВИЕ (обязательно перед деплоем)

Правила требуют `auth != null`. Сейчас `_fb_rest` **не передаёт idToken** в запросы к RTDB (строка 958 main.gd — только `Content-Type`). Если задеплоить правила без этого фикса, **все клан-функции сломаются** (401 Permission Denied).

### Шаг 0 — обновить `_fb_rest` в main.gd

Найди функцию `_fb_rest` (строка ~951) и замени строку запроса:

**Было:**
```gdscript
var headers := PackedStringArray(["Content-Type: application/json"])
http.request(FB_DB_URL + path + ".json", headers, method, body)
```

**Стало:**
```gdscript
var headers := PackedStringArray(["Content-Type: application/json"])
var auth_suffix := ("?auth=%s" % fb_id_token) if fb_id_token != "" else ""
http.request(FB_DB_URL + path + ".json" + auth_suffix, headers, method, body)
```

Это добавляет `?auth=<idToken>` к каждому запросу. Firebase RTDB принимает токен в query-параметре.
После правки — smoke-тест, VERSION-бамп, коммит, пуш, затем деплой правил.

> **Ограничение:** Anonymous Auth idToken живёт 1 час. Если сессия длиннее, запросы после истечения вернут 401. Фикс — добавить обновление токена (можно сделать отдельно позже).

---

## Шаг 1 — Открыть Firebase Console

1. Перейди на https://console.firebase.google.com
2. Выбери проект `cyber-auto-rpg`
3. В левом меню: **Build → Realtime Database**

---

## Шаг 2 — Перейти в Rules

Вкладка **Rules** (рядом с Data, Backups).

Сейчас там что-то вроде:
```json
{
  "rules": {
    ".read": "now < 1234567890000",
    ".write": "now < 1234567890000"
  }
}
```
(test-mode с датой истечения, или полностью открытые `true`/`true`)

---

## Шаг 3 — Вставить новые правила

Скопируй содержимое файла `firebase-rtdb-rules.json` и вставь в редактор Rules, заменив всё что там есть.

Или использовать Firebase CLI:
```bash
# Установить Firebase CLI (если нет)
npm install -g firebase-tools
firebase login

# Из корня репо
firebase use cyber-auto-rpg
firebase database:rules firebase-rtdb-rules.json --force
```

---

## Шаг 4 — Проверить через Simulator

В Firebase Console на вкладке Rules есть кнопка **Simulator**.

Проверь сценарии:

| Операция | Путь | Auth | Ожидание |
|----------|------|------|----------|
| Read | /players/UID123 | anon uid=UID123 | ✅ allow |
| Write | /players/UID123 | anon uid=UID123 | ✅ allow |
| Write | /players/UID456 | anon uid=UID123 | ❌ deny |
| Write | /players/UID123 | не авторизован | ❌ deny |
| Read | /clans/123456 | anon uid=UID123 | ✅ allow |
| Write | /clans/123456/members/UID123 | anon uid=UID123 | ✅ allow |
| Write | /clans/123456/members/UID456 | anon uid=UID123 | ❌ deny |
| Write | /clans/123456/chat/-abc | anon uid=UID123 (член) | ✅ allow |
| Write | /clans/123456/chat/-abc | anon uid=UID999 (не член) | ❌ deny |

---

## Шаг 5 — Publish

Нажми **Publish** в Firebase Console.

---

## Структура данных (справка)

```
/players/{uid}
  id: string "#000123"
  nick: string (1-64 символа)
  power: number >= 0
  best: number >= 0
  clan: string (код клана или "")
  t: number (unix timestamp)

/clans/{code}
  name: string (1-64)
  leader: string (uid)
  created: number (unix timestamp)
  members/
    {uid}/
      nick: string (1-64)
      power: number >= 0
  boss/
    hpMax: number > 0
    started: number > 0
    name: string (1-64)
    fac: string (<=64)
    week: number >= 0
    contrib/
      {uid}/
        nick: string (1-64)
        dmg: number >= 0
  chat/
    {push_key}/
      nick: string (1-64)
      text: string (1-200)
      t: number > 0
```

---

## Логика правил (коротко)

| Путь | Читать | Писать |
|------|--------|--------|
| `/players/$uid` | auth != null | auth.uid == $uid |
| `/clans/$code` (создание) | auth != null | auth != null && клан не существует |
| `/clans/$code` (обновление) | auth != null | auth.uid == leader |
| `/clans/$code/members/$uid` | (через родителя) | auth.uid == $uid |
| `/clans/$code/boss` | (через родителя) | auth != null && uid в members |
| `/clans/$code/boss/contrib/$uid` | (через родителя) | auth.uid == $uid && uid в members |
| `/clans/$code/chat/$msg` | (через родителя) | auth != null && uid в members && msg новый |
