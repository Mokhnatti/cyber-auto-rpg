# NATIVE-ANALYTICS-PLAN.md — Этап 1 инвест-роадмапа

> Документ-план. Код игры НЕ трогается. Источник правды — официальные доки (ссылки в каждом разделе).
> Игра: киберпанк auto/idle-RPG на Godot 4.7 (GDScript), сейчас веб-экспорт (HTML5) на GitHub Pages.
> Уже подключён Firebase (Realtime DB для кланов + Anonymous Auth) через JS SDK (JavaScriptBridge) + REST.
> Цель Этапа 1: софт-лонч нативного Android-билда + замер D1/D7/D30, ARPU/ARPPU, конверсии.
> Дата составления: 28.06.2026.

---

# ЧАСТЬ А. Нативная сборка Android (Godot 4.7)

## А.0. Главный архитектурный вывод (читать первым)
На вебе Firebase работает через `JavaScriptBridge` (вызов JS SDK из браузера). **В нативном Android-билде `JavaScriptBridge` НЕ существует** — это веб-only API. Значит весь код, который ходит в Firebase через `JavaScriptBridge.eval(...)`, на Android будет молча падать/ничего не делать.

**Решение (рекомендуемое): перевести весь Firebase-доступ на чистый REST через `HTTPRequest`.**
`HTTPRequest` — кросс-платформенный узел Godot, работает одинаково на web/Android/desktop. Firebase Auth (anonymous) и Realtime Database полностью доступны по REST:
- Anonymous Auth: `POST https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=API_KEY` → возвращает `idToken` + `refreshToken` + `localId` (это и есть anon UID).
- Refresh токена: `POST https://securetoken.googleapis.com/v1/token?key=API_KEY` (grant_type=refresh_token).
- RTDB чтение/запись: `GET/PUT/PATCH/POST/DELETE https://<db>.firebaseio.com/path.json?auth=<idToken>`.

Так один и тот же REST-слой работает и на вебе, и на нативе — убираем зависимость от `JavaScriptBridge` вообще (можно оставить JS-путь только под web как опцию, но проще иметь единый REST). Документация REST: Firebase Auth REST API и RTDB REST API (firebase.google.com/docs/reference/rest/auth, firebase.google.com/docs/database/rest/start).

> Почему не нативный Firebase Android SDK / godot-firebase-плагин: см. раздел А.4 — для нашего набора (anon auth + RTDB) REST проще, надёжнее и не добавляет Gradle/AAR-зависимостей. Нативный SDK понадобится позже ТОЛЬКО под FCM push (раздел А.4в).

---

## А.1. Что нужно установить (toolchain, можно headless на Linux-сервере Aeza)

Да — нативную Android-сборку можно делать headless на Linux-сервере БЕЗ Android Studio. Нужны только командные компоненты. (Источник: Godot docs «Exporting for Android» + issue godotengine/godot#78412 «export for Android in CI».)

Чеклист установки на сервере:
- [ ] **JDK 17** (OpenJDK 17). Godot 4.x Android build-template на Gradle требует именно JDK 17 (выше — рискованно). `sudo apt install openjdk-17-jdk`. (Источник: docs.godotengine.org exporting_for_android; issue godot-docs#7902 «SdkManagerCli requires OpenJDK 17».)
- [ ] **Android SDK command-line tools** (без Studio): скачать `commandlinetools-linux-*.zip` с developer.android.com, распаковать в `~/android-sdk/cmdline-tools/latest/`.
- [ ] Через `sdkmanager` поставить пакеты:
  - `platform-tools` (≥ 35.0.0)
  - `build-tools;35.0.0` (под target SDK 35)
  - `platforms;android-35`
  - `cmdline-tools;latest`
  - `ndk;<версия из доков под 4.7>` — нужен, если есть нативные модули; для чистого GDScript часто не критичен, но build-template может требовать. Ставить ту версию NDK, что указана в Godot docs для конкретной версии (Editor → Project → Install Android Build Template подтянет требование).
  - `cmake;<версия>` — аналогично, по требованию build-template.
- [ ] Принять лицензии: `yes | sdkmanager --licenses`.
- [ ] **Godot export templates** под ровно ту же версию редактора (4.7.x). Headless: положить в `~/.local/share/godot/export_templates/4.7.<...>/` (или `--export` сам подскажет, что шаблонов нет). Скачиваются с tuxfamily/github releases Godot.
- [ ] **Android build template для проекта**: в редакторе это «Install Android Build Template» (создаёт `res://android/build/`). Для CI это надо один раз сгенерить (через GUI-редактор локально или `--install-android-build-template`-флоу) и закоммитить папку `android/build` в репо. Без неё custom-сборка/плагины не соберутся.
- [ ] **Keystore для подписи** (см. А.2).
- [ ] Прописать пути в Editor Settings (на CI — через файл `editor_settings-4.tres` или env): `export/android/android_sdk_path`, `export/android/java_sdk_path`, debug/release keystore. (Источник: docs «Exporting for Android», раздел Editor settings.)

Готовые рецепты: репо `myood/godot-ci-android-export` (Docker + GitLab pipeline, debug/release, APK/AAB) — взять как образец Dockerfile для нашего сервиса сборки.

---

## А.2. Keystore (подпись) — debug vs release

- **Debug keystore** — для internal-тестов/сайдлоада. Godot может сгенерить дефолтный debug.keystore автоматически; для воспроизводимости лучше создать свой и прописать в Editor Settings (`export/android/debug_keystore`).
- **Release keystore (upload key)** — обязателен для Google Play. Генерим один раз и НИКОГДА не теряем (потеря = невозможность обновлять приложение, если не включён Play App Signing с recovery):
  ```
  keytool -genkey -v -keystore upload.keystore -alias upload \
    -keyalg RSA -keysize 2048 -validity 10000
  ```
- [ ] Хранить `upload.keystore` + пароли ВНЕ публичного репо (`~/.android-release-keys/`, бэкап). В CI — через секреты/переменные окружения, не в git.
- [ ] Включить **Google Play App Signing** (Google хранит app signing key, мы подписываем upload-ключом). Это страховка от потери ключа.

---

## А.3. Шаги экспорта APK/AAB из Godot 4.7

Через GUI один раз настраиваем preset, дальше CI гонит из командной строки.

1. **Создать Export Preset «Android»** (Project → Export → Add → Android). Заполнить:
   - Package → Unique Name: `com.mokhnatti.cyberautorpg` (обратный домен, фиксируется навсегда для Play).
   - Version Code (целое, инкрементить каждый билд) + Version Name (строка «1.7.11»).
   - Keystore: debug — для тестов; release + alias/пароли — для Play.
   - Architectures: оставить `arm64-v8a` (обязательно для Play 64-bit) + опц. `armeabi-v7a`. `x86_64` — для эмулятора (можно выключить для прод, уменьшит размер).
   - Включить **«Use Gradle Build»** (Use Custom Build) — нужно для AAB, плагинов и target SDK 35.
2. **Командная строка (headless, на сервере):**
   - Debug APK (сайдлоад/тест):
     `godot --headless --export-debug "Android" build/cyberrpg-debug.apk`
   - Release APK:
     `godot --headless --export-release "Android" build/cyberrpg.apk`
   - Release AAB (для Google Play): в preset включить формат AAB (Gradle Build → Export Format = AAB), затем:
     `godot --headless --export-release "Android" build/cyberrpg.aab`
   (Источник: docs «Exporting for Android» / «Command line tutorial»; strayspark/summerengine 2026-гайды.)
3. **Важно про headless reimport:** известная бага — `--headless --export` иногда не переимпортит ресурсы. Workaround: прогнать `godot --headless --editor --quit` (или `--import`) ПЕРЕД экспортом, чтобы `.godot/imported` собрался. (Источник: godotengine/godot#69511, #78412.) В CI добавить этот шаг обязательно.
4. **Самопроверка:** установить APK на реальный телефон (`adb install -r build/cyberrpg-debug.apk`) и проверить, что Firebase (кланы/auth) реально работает на нативе (это и есть тест перевода на REST из А.0).

---

## А.4. Firebase без JavaScriptBridge — варианты (детально)

| Вариант | Что это | Плюсы | Минусы | Вердикт |
|---|---|---|---|---|
| **(а) Чистый REST через `HTTPRequest`** | Сами шлём HTTPS-запросы к Identity Toolkit + RTDB | Кросс-платформенно (web/Android/desktop одним кодом), нет Gradle/AAR, полный контроль, уже частично есть (у нас REST уже используется) | Ручной refresh токена; нет realtime-стрима (RTDB `.json` REST = polling, не live socket); push не покрывает | **РЕКОМЕНДОВАНО** для anon auth + RTDB |
| **(б) GodotNuts/GodotFirebase (GDScript-плагин)** | Готовая GDScript-обёртка над Firebase REST (Auth anonymous, RTDB, Firestore, Storage) | Не надо писать REST руками; чистый GDScript = кросс-платформенно; anonymous login из коробки | Сторонняя зависимость, поддержка под 4.7 не гарантирована, тащит лишний функционал, внутри всё равно REST | Запасной вариант, если не хочется писать REST-слой самим |
| **(в) Нативный Firebase Android SDK через Godot Android-плагин** (напр. syntaxerror247/GodotFirebaseAndroid, cengiz Firebase Plugin) | Реальный Firebase Android SDK (AAR) обёрнут Godot Android plugin | Нативный realtime-сокет RTDB, **FCM push**, Google Sign-In, нативная аналитика | Только Android (на вебе не работает — снова раздвоение платформ), нужен Gradle custom build, `google-services.json`, версии плагина под Godot, сложнее CI | Брать ТОЛЬКО когда дойдём до **push-уведомлений (FCM)** |

**Решение для Этапа 1:** вариант **(а) — чистый REST**. Anon auth + RTDB-кланы полностью покрываются, один код на все платформы, минимум инфраструктуры. (б) — если лень писать REST. (в) — отложить до фичи push.

Полезно: у нас RTDB-кланы сейчас, возможно, на live-листенерах JS SDK. По REST realtime «из коробки» нет — либо периодический поллинг `GET .json`, либо позже EventSource/streaming REST (RTDB поддерживает `Accept: text/event-stream`, но в Godot это надо городить руками). Для кланов polling раз в N секунд обычно достаточно.

Источники: docs JavaScriptBridge (web-only), Firebase Auth REST API, Firebase RTDB REST API, GodotNuts/GodotFirebase (GitHub), syntaxerror247/GodotFirebaseAndroid (GitHub).

---

## А.5. Подводные камни нативного билда (актуально на 2026)

- [ ] **Target SDK 35 (Android 15) обязателен.** С 31 августа 2025 новые приложения и апдейты на Google Play должны таргетить API level 35+. Godot 4.7 / build-template это поддерживает; проверить в preset, что target = 35. (Источник: support.google.com/.../answer/11926878 + developer.android.com/google/play/requirements/target-sdk.)
- [ ] **minSdkVersion**: Godot 4.x минимум обычно Android 5.0 (API 21); для RTDB/HTTPS норм. Можно поднять до 24, чтобы упростить TLS. Чем ниже min — тем шире охват, но больше теста.
- [ ] **64-bit (arm64-v8a) обязателен** для Play.
- [ ] **Разрешения (permissions):** Godot по умолчанию может добавлять кучу разрешений — оставить ТОЛЬКО `INTERNET` (нужно для Firebase REST). Снять лишние (микрофон, камера, локация) в Export preset → Permissions, иначе Data Safety и ревью усложнятся.
- [ ] **Иконки**: legacy + adaptive (foreground/background) + Play Store icon 512×512. Splash: настроить boot splash, под мобилку проверить тёмный фон (киберпанк).
- [ ] **Размер**: Godot-APK базово ~25–40 МБ. Следить, чтобы AAB < лимитов; Play App Bundle сам режет по архитектурам.
- [ ] **Что ломается при web→native:**
  - `JavaScriptBridge` (Firebase JS, любой `eval`, доступ к `window`, localStorage) — нет на нативе → переводим на `HTTPRequest` + `user://` сейвы (А.0).
  - Сейвы: web использует IndexedDB через `user://`; на Android `user://` = внутреннее хранилище приложения, работает, но это ДРУГОЕ хранилище — у тестера прогресс с веба не перенесётся (для софт-лонча ок, заметить в патчноуте).
  - Ввод: проверить тач-таргеты (снайпер-ульта = тап по цели), масштаб UI на разных DPI.
  - Реклама/IAP: если веб-монетизация была заглушками — нативные IAP (Google Play Billing) это отдельная интеграция (вне Этапа 1, но события покупки в аналитике заложить заранее).
- [ ] **Gradle-ошибки** (классика): несовпадение JDK/SDK версий, не установлен build-template, кривые пути. (Источник: bugnet.io «Fix Godot Export to Android Gradle Errors».)

---

## А.6. Google Play Console — выкладка и софт-лонч

- [ ] **Аккаунт разработчика**: единоразово **$25**. Personal vs Organization — важно: для **personal-аккаунтов, созданных после 13.11.2023**, действует требование **закрытого теста: ≥12 тестеров, непрерывно opted-in ≥14 дней**, прежде чем откроют production-доступ. Organization-аккаунты освобождены. (Источник: support.google.com/.../answer/14151465; politика 12 testers/14 days, снижено с 20 в декабре 2024.)
  - Вывод: либо заранее собрать 12 тестеров (Диана + знакомые + чаты), либо рассмотреть organization-аккаунт (нужен D-U-N-S, дольше верификация).
- [ ] **Треки тестирования**: Internal testing (до 100 тестеров, мгновенно, без ревью-очереди — идеально для первых итераций) → Closed testing (тот самый 12/14 для разблокировки прода) → Open testing → Production.
- [ ] **Листинг (store listing):** название, краткое+полное описание, иконка 512×512, feature graphic 1024×500, мин. 2–8 скриншотов (телефон), категория (Games → Role Playing / Casual), контакт-email, политика конфиденциальности (URL обязателен).
- [ ] **Политики/анкеты:** Content rating (IARC-опросник), Target audience & content (возраст; если не для детей — проще), **Data safety** (см. Б.5), News/COVID — нет, Ads-декларация (есть ли реклама), Government apps — нет.
- [ ] **Подпись:** загрузить AAB, включить Play App Signing.
- [ ] Стратегия софт-лонча: выкатить в Closed testing на 1–2 страны/узкую группу, копить 14 дней метрик через аналитику (Часть Б), потом решать про Production.

---

# ЧАСТЬ Б. Аналитика / KPI

## Б.1. Выбор SDK (что бесплатно и достаточно соло-разработчику)

| SDK | Цена | Заточка | Godot 4 интеграция | IAP/Ad revenue | Атрибуция UA | Вердикт для нас |
|---|---|---|---|---|---|---|
| **ByteBrew** | Бесплатно (all-in-one) | Игры/рост | **Официальный Godot Android SDK** (ByteBrewIO/ByteBrewGoDotSDK) | Да (IAP + ad revenue, server-side валидация) | Да (встроенная attribution) + Remote Config + A/B | **РЕКОМЕНДОВАНО** — максимум функций бесплатно, нативный Godot SDK |
| **GameAnalytics** | Бесплатно (щедрый free tier) | Игры (отраслевой стандарт) | Официальный Godot 4 SDK (GDExtension; Android/iOS/macOS) | Business/Resource events | Нет атрибуции (нужен отдельный) | Сильная альтернатива; лучшие бенчмарки-дашборды |
| **Firebase Analytics** | Бесплатно (безлимит событий) | Общая (не игры) | Только community Android-плагины (DrMoriarty, FeatureKillersGames) — нужен нативный Android plugin, на вебе отдельно | Через события | Нет (нужен GA4+attribution) | Уже есть Firebase-проект, но Godot-обвязка возни больше; retention-дашборды не игровые |
| **Adjust / AppsFlyer** | Платно (от объёма) | Атрибуция UA | SDK есть, но Godot — через Android-плагин | — | Да (профи-атрибуция) | **Не сейчас** — нужно только при платном трафике |

**Решение:** основной — **ByteBrew** (бесплатно, нативный Godot SDK, сразу есть retention/ARPU/монетизация/прогрессия/атрибуция/remote-config). Если упрёмся в интеграцию — fallback **GameAnalytics** (официальный Godot 4 GDExtension, лучшая бенчмарк-база по жанрам).

> Важно: оба — нативные Android SDK (GDExtension/Android plugin). На **вебе** они работать не будут или потребуют отдельной обвязки. Для Этапа 1 это ОК: KPI меряем на нативном Android-софт-лонче, веб остаётся витриной. Не плодить двойную интеграцию.

Источники: ByteBrewIO/ByteBrewGoDotSDK + docs.bytebrew.io/sdk/godot; GameAnalytics/GA-SDK-GODOT + docs.gameanalytics.com/integrations/sdk/godot; firebase Godot community-плагины (GitHub).

---

## Б.2. Какие СОБЫТИЯ трекать (под наши KPI)

Модель событий ByteBrew = custom events с параметрами (+ встроенные new_user/session для retention, и progression/IAP-хелперы). Если GameAnalytics — мапим на его 5 типов: **business / progression / resource / design / error** (docs.gameanalytics.com event-types).

**Базовые (retention/сессии) — обычно автоматом SDK:**
- `new_user` / first_open — установка (для D1/D7/D30 retention считает сам дашборд по cohort).
- `session_start` / `session_end` (с длительностью) — DAU/MAU, сессии/день, длина сессии.

**Онбординг-воронка (где отваливаются новички):**
- `tutorial_step` — param: `step` (1..N), `step_name`. Считаем drop-off по шагам.
- `tutorial_complete`.
- `first_combat_start` / `first_combat_win` — первый бой пройден.
- `first_hero_equipped` — впервые экипировал бойца (наш экран экипировки).

**Прогрессия по стадиям (ключевое для idle — где стопорятся):**
- GA progression: `Start/Complete/Fail` с иерархией `world:stage:level`. ByteBrew: `progression_event` param `stage`, `result(start/complete/fail)`, `power`, `time_spent`.
- `stage_reached` — param: `stage_id`, `player_level`, `total_power`, `playtime_sec`. Главная кривая отвала.
- `stage_failed` — param: `stage_id`, `attempts`, `enemy_hp` — где стена сложности.
- `level_up` — param: `new_level`.

**Престиж (частота волн-ритма — наша фаза 2 прогрессии):**
- `prestige` — param: `prestige_count`, `stage_at_prestige`, `time_since_last_prestige_sec`, `prestige_currency_gained`. Меряем частоту и здоровье луп-ритма.

**Гача / дроп (pity, пуллы):**
- `gacha_pull` — param: `pull_type(single/multi)`, `currency_spent`, `currency_type(soft/hard)`, `rarity_result`, `pity_counter`, `is_pity_hit(bool)`. Считаем экономику и pity-баланс.
- `item_drop` — param: `item_id`, `rarity`, `hero_target`.
- `merge_dupe` — param: `item_id`, `new_level` (наш мердж дублей).

**Экономика (баланс валют — resource events GA):**
- `currency_earned` — param: `currency_type`, `amount`, `source(combat/idle/quest/ad/prestige)`.
- `currency_spent` — param: `currency_type`, `amount`, `sink(gacha/upgrade/speed/reroll)`.
  (Источник vs sink даёт инфляцию/дефляцию валют.)

**Монетизация (ARPU/ARPPU/конверсия — business events / ByteBrew IAP):**
- `iap_purchase` — param: `product_id`, `price_usd`, `currency`, `store(google_play)`. Реальные деньги → ARPU/ARPPU/конверсия платящих. (Server-side валидация у ByteBrew — против фрода.)
- `iap_initiated` / `iap_failed` — воронка покупки.
- `store_open` — param: `source` (откуда зашёл в магазин).
- `diamonds_spent` — param: `amount`, `sink` (наш хард-валютный sink: гача/скорость/реролл).

**Реклама (idle = много rewarded; ad ARPU):**
- `ad_impression` — param: `placement(speedup/double_reward/revive)`, `ad_type(rewarded/interstitial)`, `ad_revenue` (если доступно).
- `ad_reward_claimed` — param: `placement`.
  (Idle-игры показывают в среднем ~73 rewarded-видео на юзера — это серьёзная доля выручки, мерить обязательно.)

**Кланы (вовлечённость мультиплеера):**
- `clan_joined` / `clan_created` / `clan_left`.
- `clan_boss_attack` — param: `boss_id`, `damage_dealt`.
- `clan_chat_message` (факт активности, без контента).

**Технические:**
- `error` / `crash` — param: `severity`, `message` (GA error events / ByteBrew). Стабильность нативки.

> Старт минимум (если время поджимает): `session`, `tutorial_step`, `stage_reached`, `prestige`, `gacha_pull`, `iap_purchase`, `ad_impression`. Этого хватает на D1/D7/D30, ARPU, конверсию, воронку и точку отвала. (Источник по приоритету событий: gameanalytics.com/blog «what events should you track first».)

---

## Б.3. Бенчмарки idle/гача 2025–2026 (для сравнения)

Реальность 2025 жёстче «учебных» цифр — медианы по рынку ниже, чем хотелось бы:
- **D1 retention:** средняя по всем жанрам ~**27%**; топ-25% ~26–28%, низ-25% ~10–12%. Целевой ориентир для нас на софт-лонче: **D1 ≥ 30–35%** = хороший знак, **< 20%** = онбординг/первая сессия сломаны. (Источник: GameAnalytics Mobile Gaming Benchmarks 2025; Mistplay; maf.ad.)
- **D7 retention:** медиана низкая (~3–4% across-genre), топ-25% ~**7–8%**. Для idle/RPG целимся **D7 ≥ 10–12%** (RPG держит лучше казуалок за счёт прогрессии). Idle RPG — самый быстрорастущий саб-жанр (CAGR ~13.7%, ~31% доходов idle-сегмента в 2025, ядро = hero-collection + гача).
- **D30 retention:** среднее ~**5%**; цель idle/RPG **D30 ≥ 6%** = здоровый кор-луп.
- **Конверсия платящих:** классические 2–5% по индустрии остаются ориентиром, но реально у многих **1–3%**; основная выручка — узкая прослойка «китов» + реклама. Цель софт-лонча: измерить базовую конверсию, не гнаться за абсолютом.
- **ARPU/монетизация:** сильно зависит от жанра; RPG IAP ARPMAU рос ~$5.4→$6.5; гипер-казуалки ~$0.86 ARPU; ad-ARPU выше всего у merge (~$14.8). Idle-RPG монетизируется и IAP, и rewarded-рекламой одновременно — мерить обе.

> Вывод: на closed-тесте важны не абсолюты, а **дельты между итерациями билдов** и **точка отвала на кривой stage_reached**. (Источники: GameAnalytics 2025 benchmarks; Mistplay retention benchmarks; Adjust Mobile Games Insights 2025; Tenjin/maf.ad.)

---

## Б.4. Атрибуция UA — нужна ли сейчас
**Нет, не для closed-теста.** Атрибуция (Adjust/AppsFlyer) нужна, когда ЛЬЁМ платный трафик и хотим знать, какой канал даёт качественных юзеров (ROAS/LTV по источникам). На закрытом тесте трафик = ручные приглашения, источник известен.
- Сейчас: хватит встроенной атрибуции **ByteBrew** (бесплатно, базовый install attribution).
- Позже, при платном UA: добавить Adjust/AppsFlyer ИЛИ остаться на ByteBrew, если объёмы малы. Заложить событие `iap_purchase` с `price_usd` уже сейчас, чтобы LTV считался задним числом, когда атрибуция появится.

---

## Б.5. Приватность / согласие (GDPR + Google Play Data Safety)

Любой аналитический SDK = передача данных третьей стороне → **обязательно задекларировать в Data safety** (Play Console). Порог низкий: «передаёшь что-либо с устройства» = «да». (Источник: support.google.com/.../answer/10787469; апрель-2025 апдейт ужесточил классификацию device IDs.)

Чеклист Data Safety под наш стек (ByteBrew/GameAnalytics + Firebase):
- [ ] **Device or other IDs** — собирается (аналитика юзает device/install ID). С апреля-2025 Android ID явно = device identifier, декларировать обязательно.
- [ ] **App activity / In-app actions** — да (events: прогрессия, покупки, сессии).
- [ ] **App info & performance / Crash logs & diagnostics** — да (error/crash events).
- [ ] **Purchase history** — если трекаем IAP — да.
- [ ] **Data shared with third parties** — ДА (данные уходят в ByteBrew/GameAnalytics/Firebase для их обработки). Указать «shared».
- [ ] **Шифрование при передаче** — да (HTTPS/TLS).
- [ ] **Удаление данных по запросу** — указать механизм (email-запрос → удаляем из RTDB/просим SDK-провайдера).
- [ ] **Политика конфиденциальности** — нужен публичный URL (можно простую страницу на GitHub Pages рядом с игрой). Обязателен для листинга.
- [ ] **GDPR / consent**: для EU-пользователей нужен consent перед сбором аналитики/рекламы. Минимум для closed-теста: простой consent-экран на первом запуске (Accept/Decline аналитики) ИЛИ ограничить тест не-EU странами на старте. SDK (ByteBrew/GA) поддерживают «disable/consent» режим — не слать события до согласия.
- [ ] Если данные собираются по-разному в EU — упомянуть в «About this app» (рекомендация Google).

(Источники: support.google.com Data safety; developers.google.com/android/guides/play-data-disclosure; respectlytics/applander 2026-гайды.)

---

# РЕКОМЕНДОВАННЫЙ МИНИМАЛЬНЫЙ ПУТЬ (самый простой стек, чтобы быстро собрать нативку + замерить базовые KPI)

**Цель: за минимум шагов получить работающий Android-AAB в closed-тесте с базовыми KPI.**

### Стек
- **Firebase на нативе:** чистый **REST через `HTTPRequest`** (anon auth + RTDB). Один код на web+Android, ноль Gradle-зависимостей, убираем `JavaScriptBridge`. (Нативный Firebase SDK — отложить до push.)
- **Сборка:** headless на сервере Aeza — JDK 17 + Android cmdline-tools + SDK 35 + Godot 4.7 export templates + Android build template (закоммичен) + release keystore (+ Play App Signing). Образец CI: `myood/godot-ci-android-export`.
- **Аналитика:** **ByteBrew** (бесплатно, нативный Godot SDK, сразу retention + ARPU + IAP/ad + базовая атрибуция + remote config). Fallback: GameAnalytics.
- **Дистрибуция:** Google Play, $25, Internal testing → Closed testing (12 тестеров / 14 дней) → решение про Production.

### Топ-7 событий (хватает на все базовые KPI)
`session` (D1/D7/D30 авто) · `tutorial_step` (онбординг-воронка) · `stage_reached` (точка отвала) · `prestige` (ритм лупа) · `gacha_pull` (гача-экономика) · `iap_purchase` + `price_usd` (ARPU/ARPPU/конверсия) · `ad_impression` (ad-выручка).

### Порядок действий
1. **Рефактор Firebase → REST** (`HTTPRequest`), убрать `JavaScriptBridge`-путь; проверить кланы/auth на ПК и в debug-APK на телефоне.
2. **Toolchain на сервере**: JDK 17 + Android SDK 35 + templates + build-template; собрать **debug APK**, `adb install`, прогнать smoke на телефоне.
3. **Подключить ByteBrew SDK** (autoload), зашить 7 событий, проверить, что события долетают в дашборд.
4. **Release keystore** + Play App Signing; собрать **release AAB** (target SDK 35, только INTERNET-permission, иконки/сплеш).
5. **Play Console**: аккаунт $25, листинг, политика конфиденциальности (URL на GitHub Pages), **Data Safety**-анкета, content rating; залить AAB в Internal testing.
6. **Собрать 12 тестеров** (Диана + знакомые/чаты) → Closed testing, держать 14 дней.
7. **Снимать KPI** через дашборд ByteBrew: D1/D7/D30, ARPU/ARPPU, конверсия, воронка онбординга, кривая `stage_reached` (где отвал). Сравнивать дельты между билдами, не абсолюты.

### Что отложить (НЕ Этап 1)
Нативный Firebase Android SDK · FCM push · Adjust/AppsFlyer атрибуция · Google Play Billing (реальные IAP) · open testing/прод. Заложить `iap_purchase` с `price_usd` заранее — чтобы LTV считался задним числом.

---

## Ключевые источники
- Godot — Exporting for Android: https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html
- Godot CI Android export (issue/рецепты): https://github.com/godotengine/godot/issues/78412 · https://github.com/myood/godot-ci-android-export
- JDK 17 требование: https://github.com/godotengine/godot-docs/issues/7902
- Firebase Auth REST: https://firebase.google.com/docs/reference/rest/auth · RTDB REST: https://firebase.google.com/docs/database/rest/start
- GodotNuts/GodotFirebase (GDScript): https://github.com/GodotNuts/GodotFirebase · нативный Android: https://github.com/syntaxerror247/GodotFirebaseAndroid
- Target SDK 35 / Play: https://support.google.com/googleplay/android-developer/answer/11926878 · https://developer.android.com/google/play/requirements/target-sdk
- Closed testing 12/14: https://support.google.com/googleplay/android-developer/answer/14151465
- ByteBrew Godot SDK: https://github.com/ByteBrewIO/ByteBrewGoDotSDK · https://docs.bytebrew.io/sdk/godot
- GameAnalytics Godot + event types: https://github.com/GameAnalytics/GA-SDK-GODOT · https://docs.gameanalytics.com/events-metrics-and-filtering/event-types/event-types-introduction/
- Что трекать первым: https://www.gameanalytics.com/blog/what-events-should-you-track-first-game-analytics
- Бенчмарки 2025: https://gamedevreports.substack.com/p/gameanalytics-mobile-gaming-benchmarks · https://business.mistplay.com/resources/mobile-game-retention-benchmarks
- Data Safety: https://support.google.com/googleplay/android-developer/answer/10787469 · https://developers.google.com/android/guides/play-data-disclosure
