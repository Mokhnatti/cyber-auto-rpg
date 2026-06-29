# Архитектура F2P live-игры для соло-дева: от прототипа на Firebase RTDB к масштабируемому проду

## TL;DR
- **Первый приоритет — не масштаб, а безопасность денег.** До любого релиза с монетизацией нужно: серверная валидация чеков IAP через Cloud Functions, Firebase App Check (Play Integrity / App Attest / reCAPTCHA), закрытие RTDB security rules. Текущий открытый test-mode RTDB + клиент-авторитет = тривиальный взлом покупок и лидербордов.
- **Firebase RTDB остаётся вашим бэкендом до ~10k DAU; мигрировать тотально не надо.** Жёсткий лимит — 200 000 одновременных соединений на инстанс (на Spark — всего 100), 1000 записей/сек. Лидерборды и клан-боссы через прямые клиентские записи деградируют первыми — их надо вынести на Cloud Functions + денормализованные агрегаты, а не переписывать всё на Firestore/Nakama.
- **Рефакторинг монолита main.gd делается строго инкрементально через autoload-синглтоны и сигналы**, начиная с сетевого слоя и сейвов (которые всё равно меняются ради безопасности), а не «большим взрывом». Бюджет инфраструктуры до 10k DAU реально удержать в районе $0–25/мес, главная статья непредвиденных расходов — egress RTDB и cold-read-амплификация Firestore.

## Key Findings

1. **Лимиты RTDB точны и публичны** (документация Firebase, обновлено 2026-05-06): 200 000 одновременных соединений на инстанс (Spark — 100), ~100 000 ответов/сек, 1000 записей/сек, событие-триггер Cloud Function ≤1 MB, write request ≤256 MB (REST) / 16 MB (SDK). Хранилище $5/GB-месяц, скачивание $1/GB. Официально: «You want to scale beyond the limit of 200,000 simultaneous connections, 1,000 write operations/second» — а дальше шардинг до 1000 инстансов на Blaze-проект.
2. **Firestore дешевле для документоориентированных данных, но платите за операции** (официальная страница Google Cloud Firestore pricing): **$0.06 за 100k чтений документов, $0.18 за 100k записей, $0.02 за 100k удалений, $0.18/GB-месяц хранилища**. Free tier — 50k чтений / 20k записей / 20k удалений в день.
3. **App Check + серверная валидация IAP — это технический минимум перед монетизацией.** Google Play Developer API endpoint `purchases.products.get`, Apple — App Store Server API `GET /inApps/v1/transactions/{transactionId}` (verifyReceipt устарел).
4. **CI/CD: Linux-раннер для web/Android почти бесплатен, macOS-раннер для iOS жжёт квоту в 10 раз быстрее.** 2000 бесплатных минут/мес на приватном репо ≈ всего ~200 минут реальной iOS-сборки (macOS-минуты считаются десятикратно).
5. **Лидерборды на масштабе строятся на Redis sorted sets (O(log N)), а не на реляционках; до 100k DAU достаточно одного инстанса.**

## Details

### 1. BACKEND-АРХИТЕКТУРА И МИГРАЦИЯ

**Где упрётся RTDB (официальные лимиты, обновлено 2026-05-06):**
- Simultaneous connections: **200 000 на инстанс** (на бесплатном Spark — **всего 100**). Один коннект = одно устройство/вкладка. Это не равно DAU: приложения с 10 млн MAU обычно держат <200k одновременных коннектов.
- Simultaneous responses: **~100 000/сек** из одного инстанса.
- Write rate: **1000 записей/сек** на инстанс (мягкий лимит, дальше rate-limiting).
- Один write-триггер Cloud Functions: лимит 1000 функций (или 500/регион для v2), событие ≤1 MB.
- Глубина дерева: 32 уровня; путь с листенером — до 75 млн узлов.

**Цена Blaze (RTDB):** хранилище **$5/GB-месяц**, исходящий трафик **$1/GB**. Бесплатный объём сохраняется и на Blaze: 1 GB хранилища + 10 GB/мес скачивания. Биллинг идёт за ВЕСЬ исходящий трафик включая SSL/протокол-оверхед (~3.5 KB на handshake), поэтому частые мелкие коннекты через REST дороги — SDK держат соединение и экономят.

**Где деградируют ваши текущие структуры:**
- *Лидерборды прямыми клиентскими записями в открытый RTDB* — деградируют первыми: каждый клиент пишет свой счёт, читает топ через сортировку/листенеры на больших узлах, плюс это тривиально читерится. RTDB не умеет эффективный ranking — `orderByChild` + limit отдаёт срез, но «мой ранг среди N» требует чтения всего узла.
- *Клан-боссы с общим HP* через клиентские инкременты — гонки записи и порча состояния (нет атомарности read-modify-write на клиенте). Нужны транзакции или серверные инкременты.

**Миграционный путь по этапам DAU:**

- **100 → 1000 DAU (этап софт-лонча):** Остаёмся на RTDB. Закрываем rules, добавляем App Check, переводим запись очков/клан-вклада/HP-боссов на Cloud Functions (callable). Чтение лидерборда — оставляем клиентским, но из отдельного денормализованного узла `leaderboards/{board}/top100`, который пересчитывает Cloud Function по расписанию (агрегация), а не клиент.
- **1000 → 10k DAU:** Профили/сейвы/инвентарь — кандидаты на Firestore (документная модель, security rules, App Check enforcement для Android/iOS). Лидерборды и счётчики кланов — sharded counters (Firestore Distributed Counter extension) или периодическая агрегация. RTDB оставляем только для того, что реально realtime (чат, presence, live-HP боссов).
- **10k → 100k DAU:** Если социалка/лидерборды становятся ядром — выделенный бэкенд. Тут реальная развилка (ниже).

**Firestore vs PlayFab vs Nakama vs свой бэкенд (вердикт для соло-дева):**
- **Firestore** — путь наименьшего сопротивления, вы уже в экосистеме Firebase. Минус: pay-per-operation, «read amplification» при listener-heavy экранах может взорвать счёт; нет хард-капа на Blaze.
- **PlayFab (Microsoft, Azure)** — готовые building blocks (лидерборды, экономика, LiveOps, аналитика). Development Mode бесплатен до 1000 lifetime-аккаунтов на title, free-to-start примерно до 100k игроков; модель оплаты перешла на consumption-based meters (Events / Profile / CloudScript GB-s), а не фиксированный $99/мес (старая цифра $99 на актуальном прайсинге не подтверждается). Минус: только HTTP-поллинг (нет realtime push из коробки), привязка к Azure, медленные апдейты.
- **Nakama (Heroic Labs)** — open-source, можно self-host бесплатно (есть встроенная серверная валидация IAP для Google/Apple, лидерборды, кланы, WebSocket realtime). Минус: нужен DevOps, Go/TS/Lua для серверной логики, крутая кривая обучения. Heroic Cloud (managed) — дорого для соло (enterprise-прайсинг исторически от высоких сумм).
- **Свой бэкенд** — не для соло-дева на этом этапе.

**Вердикт:** для киберпанк auto/idle-RPG соло-дева — **оставаться на Firebase (RTDB + Firestore гибрид) минимум до 10k DAU**, и только если социалка станет ядром монетизации и счета Firestore начнут болеть — рассматривать **self-host Nakama** (а не PlayFab) ради predictable cost и встроенного IAP/leaderboards.

**Схемы данных, которые не деградируют:**
- Лидерборд: не пишите ранги в дерево. Денормализованный `top100` узел (write через серверную агрегацию), а полный ranking при росте — Redis sorted set (`ZADD`/`ZREVRANK`, O(log N), один инстанс держит 100 млн членов ≈ 6 GB [Levelop](https://levelop.dev/blog/100m-players-updating-scores-every-second-redis-gets-you-to-v1) и 100k+ ops/sec). Шардить по региону/сезону, а не по игроку (иначе глобальный ранг требует merge всех шардов).
- Клан-вклад/счётчики: sharded counters (несколько дочерних узлов-шардов, инкремент случайного шарда, сумма при чтении) — снимает write-contention на «горячих» узлах.
- Клан-босс HP: транзакция (RTDB transaction / Firestore transaction) или серверный инкремент через Cloud Function.

### 2. АНТИ-ЧИТ И БЕЗОПАСНОСТЬ (приоритет №1 перед монетизацией)

Открытый RTDB в test-mode + клиент-авторитет = любой может через REST/devtools переписать баланс, очки, клан-вклад, и (хуже всего) выдать себе платный контент без оплаты.

**Что РЕАЛЬНО защищать (прагматичная граница для соло-дева):**
- ✅ **Покупки IAP** — критично, прямой слив выручки. Серверная валидация обязательна.
- ✅ **Лидерборды и клан-вклад** — серверная запись через Cloud Functions, клиент не пишет напрямую.
- ✅ **Облачные сейвы / ключевые поля** (премиум-валюта, уровень престижа) — серверная валидация/подпись.
- ⚠️ **НЕ стоит защищать для соло-дева:** локальную оффлайн-прогрессию idle-числа (стадии, обычная мягкая валюта) — в idle-игре клиент по сути авторитетен над оффлайн-расчётом, тотальный серверный пересчёт нерентабелен. Грань: защищаем то, что (а) стоит реальных денег, (б) видно другим игрокам (лидерборды/кланы). Остальное — клиентское с базовой обфускацией.

**Firebase App Check — первый барьер.** Гарантирует, что запросы идут из вашего настоящего, неизменённого приложения. Провайдеры: Android — **Play Integrity** (Standard tier бесплатен до 10 000 запросов/день; поднять лимит можно по заявке при условии «correct implementation of API logic including retries» и опубликованного на Google Play приложения), iOS — **App Attest / DeviceCheck**, Web — **reCAPTCHA Enterprise** (бесплатно 10 000 оценок/мес) или reCAPTCHA v3. TTL токена настраивается 30 мин – 7 дней (дефолт 1 час, refresh на половине TTL). Включается enforcement отдельно для RTDB, Firestore, Storage, Cloud Functions. **Важно:** включать enforcement только после того, как метрики в консоли покажут, что большинство запросов «verified» — иначе сломаете старые версии клиента.

App Check enforcement в Cloud Functions (v2, Node):
```js
const { onCall } = require("firebase-functions/v2/https");
exports.submitScore = onCall(
  { enforceAppCheck: true }, // Reject requests with missing/invalid App Check tokens
  (request) => {
    // request.app — данные App Check; request.auth.uid — пользователь
    // ... серверная логика записи очка
  }
);
```

**Security Rules для RTDB (закрыть test-mode):**
```json
{
  "rules": {
    ".read": false,
    ".write": false,
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid",
        "premium_currency": { ".write": false },
        "save": { ".validate": "newData.hasChildren(['version','checksum'])" }
      }
    },
    "leaderboards": {
      ".read": "auth != null",
      ".write": false
    },
    "clan_boss": {
      "$bossId": {
        "hp": { ".write": false }
      }
    }
  }
}
```
Ключевая идея: всё, что про деньги/очки/HP-босса (`premium_currency`, `leaderboards`, `clan_boss/hp`) — `".write": false` для клиента, пишется только Admin SDK из Cloud Functions (Admin SDK обходит rules). Клиент пишет только свои данные под своим `auth.uid`. Валидация структуры через `.validate` + `newData.hasChildren([...])`. (Практика индустрии: большую часть валидации держат в Cloud Functions / admin-only узлах, а security rules — для контроля доступа; `.validate` — для критичных полей.)

**Серверная валидация IAP — пошагово (Google Play):**
1. Клиент покупает через Play Billing, получает `purchaseToken` + `productId`.
2. Клиент шлёт их в Cloud Function (с App Check + Auth).
3. Cloud Function через сервис-аккаунт (роль в Play Console: «View financial data», scope `androidpublisher`) вызывает `GET https://androidpublisher.googleapis.com/androidpublisher/v3/applications/{packageName}/purchases/products/{productId}/tokens/{token}`.
4. Проверяет `purchaseState == 0` (purchased), что токен не использован ранее (защита от replay — хранит токены в БД), затем выдаёт товар и **acknowledge** покупку.
5. Записывает entitlement в защищённый узел (write только сервером).

**Apple (App Store Server API, StoreKit 2):**
1. Клиент получает `transactionId` (`jwsRepresentation`).
2. Бэкенд формирует JWT (Issuer ID + Key ID + `.p8` приватный ключ из App Store Connect, alg ES256) и вызывает `GET https://api.storekit.itunes.apple.com/inApps/v1/transactions/{transactionId}`.
3. Ответ — подписанный JWS (`JWSTransactionDecodedPayload`), проверяете цепочку сертификатов Apple и поля. `verifyReceipt` устарел — не использовать.
4. Защита от replay: храните `transactionId`/`originalTransactionId`, не выдавайте товар дважды.
Рекомендация: настроить **Real-Time Developer Notifications (RTDN, Google Pub/Sub)** и **App Store Server Notifications V2**, чтобы не поллить API и ловить рефанды/чарджбэки (Voided Purchases API у Google).

### 3. CLOUD-СЕЙВЫ + ЛИНКОВКА АККАУНТОВ

Сейчас сейвы только локальные (`user://save.json` / IndexedDB в web), линковки нет → смена устройства = потеря прогресса. Это и retention-killer, и (без серверной валидации) дыра.

**Анонимный → Google/Apple линковка (Firebase Auth account linking):** анонимный uid сохраняется при линковке, данные остаются доступны. Базовый паттерн (web SDK):
```js
import { getAuth, linkWithCredential, GoogleAuthProvider } from "firebase/auth";
const auth = getAuth();
const credential = GoogleAuthProvider.credential(googleIdToken);
linkWithCredential(auth.currentUser, credential)
  .then((usercred) => { /* Anonymous account upgraded, uid сохранён */ })
  .catch((error) => {
    if (error.code === "credential-already-in-use") {
      // аккаунт уже существует на другом устройстве → конфликт-резолюция
    }
  });
```
**Конфликт-резолюция (ключевой случай `credential-already-in-use`):** когда линкуемый Google-аккаунт уже привязан к другому uid (играл на другом устройстве), `linkWithCredential` падает. Тогда: (1) сохранить данные текущего анонимного uid, (2) `signInWithCredential` в существующий аккаунт, (3) смерджить прогресс по вашей бизнес-логике (для idle-RPG: брать максимум по стадии/престижу/валютам — «выигрывает более прогрессивный сейв», а не слепая перезапись), (4) записать смердженные данные. Включите авто-очистку анонимных аккаунтов старше 30 дней (не считаются в биллинге Identity Platform). [Firebase](https://firebase.google.com/docs/auth/web/anonymous-auth)

**Анти-чит сейвов:** ключевые поля (премиум-валюта, престиж) хранить серверно (write только Cloud Function), а локальный сейв — с checksum/HMAC-подписью, которую сервер сверяет при синхронизации. Полная серверная авторитетность idle-чисел не нужна (см. п.2), но «скачок» премиум-валюты должен ловиться сервером.

### 4. LIVEOPS-ИНФРА (server-driven)

**Firebase Remote Config** — основной инструмент server-driven баланса/событий/офферов БЕЗ апдейта приложения. Параметры — строковые key-value (кастятся в типы), условные значения по аудиториям/user properties (нужен Google Analytics). Связка с A/B Testing: значения эксперимента перекрывают conditional values.

**Лимиты Remote Config (критично для idle с частым релогином):**
- Дефолтный **minimum fetch interval — 12 часов** (конфиг не тянется из бэкенда чаще раза в 12ч независимо от числа вызовов fetch). Для прода НЕ ставить низкий интервал — при тысячах юзеров упрётесь в server-side throttling (`FirebaseRemoteConfigFetchThrottledException`).
- Realtime Remote Config (push-обновления) обходит кэш при изменении на сервере.
- Не храните в Remote Config секреты — значения видны клиенту.

**Как раздавать LiveOps-календарь + гача-баннеры server-side:** держите JSON-описание событий/баннеров (даты старта/конца, пул гачи, дропрейты, оффер) как Remote Config параметр или как узел в Firestore/RTDB, читаемый клиентом. Клиент рендерит UI из этого описания. Активные дропрейты гачи и pity-логику валидируйте серверно (Cloud Function крутит сам ролл и пишет результат), иначе гача читерится как лидерборд.

**Альтернативы для соло:** Remote Config бесплатен и достаточен. GameAnalytics и ByteBrew дают свой remote config / LiveOps в составе бесплатных SDK (см. п.5). PlayFab/Nakama имеют LiveOps-движки, но это уже миграция бэкенда.

### 5. АНАЛИТИКА-ПАЙПЛАЙН

**ByteBrew vs GameAnalytics vs свой пайплайн:**
- **ByteBrew** — бесплатный (модель free-to-start), заточен под мобильные игры: real-time аналитика, монетизация, LiveOps, push, атрибуция, кросс-промо. [Bytebrew](https://bytebrew.io/) Минусы (по обзорам): относительно молодой, мало проверен на огромных объёмах, вопрос долгосрочной коммерческой устойчивости при полностью бесплатной модели.
- **GameAnalytics** — бесплатный entry, prebuilt-дашборды (retention, прогрессия, монетизация, funnel), сегментация, A/B-тесты, event stream ~каждые 15 сек, [Keewano](https://keewano.com/blog/best-game-analytics-solutions/) бенчмарки рынка. Минусы: отдельные проекты под iOS/Android (мешает кросс-платформенному сравнению), UI местами неудобный. [Keewano](https://keewano.com/blog/best-game-analytics-solutions/)
- **Свой пайплайн (events → BigQuery)** — Firebase Analytics бесплатно стримит в BigQuery; максимальная гибкость, но требует SQL и инфраструктуры. Для соло-дева — избыточно на старте, оправдано после 10k+ DAU.

**Вердикт:** на софт-лонче — **GameAnalytics или ByteBrew** (готовый SDK, бесплатно, idle/gacha-метрики из коробки). Параллельно подключить **Firebase Analytics → BigQuery** бесплатно «на вырост».

**Какие события трекать для idle/gacha:**
- Retention: D1/D7/D30 (через identify первой сессии).
- Монетизация: ARPDAU, conversion (% платящих), first-purchase, ARPPU.
- Гача: pull (single/multi), rarity результата, pity-trigger, потраченная валюта.
- Прогрессия: вход/выход со стадии (где чёрчатся — `stage_reached`, `prestige`, `singularity`), время до престижа.
- Churn-точки: последняя достигнутая стадия перед оттоком, баланс валюты на оттоке.

**Оффлайн-устойчивость (idle-игры часто оффлайн):** SDK должны буферизовать события локально и досылать при появлении сети — это базовая фича ByteBrew/GameAnalytics/Firebase. Свой пайплайн обязан реализовать локальную очередь с дедупликацией (event_id) и retry. Не шлите событие синхронно в момент действия — пишите в локальный буфер.

**GDPR/consent (требования 2025-2026):**
- iOS: **App Tracking Transparency (ATT)** — явный prompt перед трекингом через IDFA; [TheCafeApp](https://www.thecafeapp.com/post/ensuring-gdpr-compliance-for-mobile-apps-insights-into-the-app-store-and-google-play-store) с мая 2024 обязателен **Privacy Manifest** (`PrivacyInfo.xcprivacy`) с декларацией data types, третьесторонних SDK и reasons; Xcode блокирует загрузку без него.
- Android: **Data Safety form** (политика April 2025: Android ID теперь явно device identifier; «sharing» = любая передача третьей стороне, включая ваш SDK, если он использует данные для своих целей). С 31 августа 2025 новые приложения должны таргетить **API level 35 (Android 15)**.
- **Google Consent Mode v2** (параметры `ad_user_data`, `ad_personalization`) для интеграции с Firebase/AdMob.
- Любой analytics SDK должен инициализироваться ПОСЛЕ получения согласия (типичный провал — «privacy theater», когда SDK шлёт данные до баннера; были штрафы, напр. кейс Tractor Supply $1.35M).

**Связка с Remote Config:** метрики из аналитики → аудитории/user properties в Google Analytics → conditional values в Remote Config → data-driven баланс/офферы без релиза.

### 6. CI/CD МУЛЬТИ-ПЛАТФОРМА

**Готовая основа:** `barichello/godot-ci` (Docker-образ, поддерживает Godot 4.7, шаблоны `.github/workflows/godot-ci.yml` для web/Pages/Itch) и `firebelley/godot-export` (читает `export_presets.cfg`, делает релизы). Для Android — `dulvui/godot-android-export`.

**Ключевые факты по стоимости GitHub Actions (официально, в силе с 1 января 2026):**
- Бесплатные минуты/мес на приватных репо: **GitHub Free — 2000** (+500 MB artifact storage), Pro — 3000, Team — 3000, Enterprise — 50 000.
- Per-minute rates: **Linux 2-core $0.006/мин, Windows $0.010/мин, macOS (3-4 core) $0.062/мин** (снижение до 39% с 1 января 2026: Linux $0.008→$0.006, Windows $0.016→$0.010, macOS $0.080→$0.062).
- macOS ≈ **в 10 раз дороже** Linux. Конкретный пример (toolradar, июнь 2026): «macOS runners jump to $0.062/minute — 10x more. A 30-minute iOS build costs $1.86 — run that 20 times/day and you are spending $1,116/month on macOS CI alone». Против квоты: Windows-минуты считаются ×2, macOS-минуты ×10.
- **Public-репозитории — бесплатно/безлимитно** для стандартных раннеров.
- **Следствие для iOS:** 2000 бесплатных минут ÷ 10 ≈ **только ~200 минут реальной macOS-сборки в месяц** на Free. Минуты списываются с владельца репо. GitHub округляет каждую job до целой минуты вверх.

**Web (деплой на Pages) и Android (AAB) — Linux-раннер, почти бесплатно.** Android keystore: base64-кодировать и положить в Secrets; в Godot 4 использовать **абсолютный путь** к keystore (`~` не разворачивается в YAML — частая ошибка «Release keystore incorrectly configured»); добавить `permissions: contents: write` для аплоада артефакта; полезен fail-fast через `keytool -list ... | grep "Alias name:"`. Web-экспорт с многопоточным WASM требует HTTP-заголовков **COOP/COEP** (`Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp`) — GitHub Pages их не шлёт по умолчанию (ограничение для SharedArrayBuffer/threads; либо single-thread, либо хостинг с заголовками).

**iOS (macOS-раннер):** Godot экспортирует **Xcode-проект, не готовый .ipa**, и только на macOS («You must export for iOS from a computer running macOS with Xcode installed»). Пайплайн: Godot `--headless --export-release "iOS"` → `.xcodeproj` → **fastlane** (`setup_ci` создаёт временный keychain → `match` тянет сертификаты/профили из приватного git-репо read-only → `gym`/`build_app` компилит и подписывает → `upload_to_testflight`). Нужен **Apple Developer Program — $99/год** («The Apple Developer Program is 99 USD per membership year»), distribution-сертификат (`.p12`, base64 в secrets) + provisioning profile + App Store Connect API key (обход 2FA в CI). Готового официального Godot-iOS-action, делающего подписанный .ipa, нет; есть community-проект `mak448a/build-ios` (не production-гарантия) и канонический паттерн GameCI (`build` job на `ubuntu-latest` + `releaseToAppStore` job на `macos-latest`). Apple агрессивно rate-лимитит частые аплоады — триггерить TestFlight-аплоад вручную, не на каждый push.

**Базовый workflow (web на Pages, тег-триггер):**
```yaml
on: { push: { tags: ["v*"] } }
jobs:
  export-web:
    runs-on: ubuntu-latest
    permissions: { contents: write }
    container: { image: barichello/godot-ci:4.7-stable }
    steps:
      - uses: actions/checkout@v5
      - name: Setup templates
        run: |
          mkdir -p ~/.local/share/godot/export_templates
          mv /root/.local/share/godot/export_templates/4.7.stable ~/.local/share/godot/export_templates/
      - name: Web export
        run: |
          mkdir -p build/web
          godot --headless --export-release "Web" build/web/index.html
      - name: Deploy to Pages
        uses: peaceiris/actions-gh-pages@v4
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: build/web
```

**Versioning / staged rollout:** семантические теги `vX.Y.Z` → триггер; Google Play — staged rollout (1%→5%→...→100%) через Play Console / Publishing API; App Store — phased release (7-дневный авто-rollout) + TestFlight для бета.

### 7. КОД-АРХИТЕКТУРА (рефакторинг монолита)

`main.gd` на ~5500 строк — реальный риск, но **рефакторинг для соло-дева оправдан только инкрементальный** (большой rewrite = высокий риск сломать работающую игру при нулевой выгоде для игрока).

**Стоит ли вообще:** да, но не ради «чистоты» — а потому что (а) безопасность (п.2-3) всё равно требует переписать сетевой слой и сейвы, (б) монолит на 5500 строк станет неподдерживаемым при добавлении LiveOps/гачи. Делаем рефакторинг как побочный продукт обязательных изменений.

**Godot-паттерны (официальная документация):**
- **Autoload-синглтоны** — для глобального состояния и API, переживающего смену сцен (прогрессия, аудио, сетевой менеджер). Godot создаёт инстанс в корне дерева, доступен по имени из любого скрипта. Осторожно: синглтоны = глобально мутируемое состояние, легко наплодить трудноотслеживаемые баги; держать read-only data и широко используемые API.
- **Custom Resources** (`extends Resource`, `@export` поля) — для data-driven баланса (таблицы стадий, скиллы, гача-пулы, конфиги врагов). Отделяет данные от кода, сериализуется (`ResourceSaver.save`/`load`).
- **Signal-based decoupling** — компоненты общаются через сигналы / глобальный Signal Bus (autoload с сигналами), а не прямыми ссылками. Снижает связность.
- **Сцены-компоненты** — UI/бой/враги как отдельные `.tscn`, инстанцируемые и переиспользуемые.

**Что выделять первым (порядок — ниже отдельный раздел):** сетевой слой и сейвы (всё равно меняются ради безопасности) → прогрессия → бой → UI.

**Тест-стратегия (GDScript):**
- **GUT (Godot Unit Test)** — стандарт; GUT 9.x требует Godot 4. [Readthedocs](https://gut.readthedocs.io/) Ставится из AssetLib, [Medium](https://stephan-bester.medium.com/unit-testing-gdscript-with-gut-01c11918e12f) тесты в `res://test/`, файлы с префиксом `test_`, классы `extends GutTest`. [UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/gut-unit-testing/) AAA-паттерн (Arrange-Act-Assert), `assert_eq`, `watch_signals`+`assert_signal_emitted` для сигналов, `double()`/`stub()` для моков. [UhiyamaLab](https://uhiyama-lab.com/en/notes/godot/gut-unit-testing/)
- Запуск в CI headless: `godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit` — встроить отдельной job на Linux-раннере (дёшево).
- Альтернатива: **GdUnit4** (встроенный inspector, GDScript+C#, генерация тестов из редактора). [GitHub](https://github.com/godot-gdunit-labs/gdUnit4)
- Приоритет покрытия для idle-RPG: чистая логика прогрессии/боя/гача-роллов (детерминируемые функции легко тестируются), не UI.

### 8. СТОИМОСТЬ / МАСШТАБ

**Бесплатные лимиты (Spark и no-cost квоты Blaze):**
- RTDB: 1 GB хранилища + 10 GB/мес скачивания; на Spark — 100 одновременных коннектов (это упрётся самым первым при росте!).
- Firestore: 1 GB + 50k чтений / 20k записей / 20k удалений в **день**.
- Cloud Functions: **2 млн вызовов/мес + 400 000 GB-сек + 200 000 GHz/CPU-сек + 5 GB egress** бесплатно; дальше $0.40/млн вызовов, главный драйвер цены — GB-сек/CPU-сек, не число вызовов.
- Hosting: 10 GB/мес egress (далее ~$0.15/GB).
- Auth: 10k верификаций/мес; phone auth платный (SMS $0.01–0.06).
- **Spark жёсткий: при превышении дневной квоты продукт отключается до следующего цикла. Blaze не имеет хард-капа — «один плохой день» = счёт.**

**Помесячная оценка по этапам DAU (порядок величин):**
- **100–1000 DAU:** в пределах free tier или **<$10/мес**. Cloud Functions для IAP-валидации и записи очков — в пределах 2 млн вызовов. RTDB-трафик мал.
- **1000–10k DAU:** **~$10–50/мес**. Начинают капать Firestore reads/writes сверх дневной квоты + Cloud Functions compute + RTDB egress. Главные «дорогие операции»: (1) realtime-листенеры на больших узлах RTDB (egress), (2) Firestore read amplification при listener-heavy экранах и reconnect-ах (>30 мин оффлайна с offline persistence = повторное billed-чтение всех документов при реконнекте), (3) частые fetch Remote Config (но throttle защищает).
- **10k–100k DAU:** **сотни $/мес** без оптимизации; легко уходит за $1000 при «грязной» архитектуре (heavy realtime/chat). Здесь и оправдан переход части нагрузки на self-host Nakama / Redis sorted sets для лидербордов.

**Где именно соло-дев попадёт на деньги:**
1. **Egress RTDB** ($1/GB) — частые мелкие realtime-апдейты, listener на «толстых» узлах, REST вместо SDK.
2. **Firestore reads** ($0.06/100k) — listener, который переподключается, и «прочитать коллекцию, чтобы показать один экран».
3. **Cloud Functions compute** (GB-сек) — не число вызовов, а память×время; держать функции лёгкими и быстрыми.
4. **Phone Auth SMS** — если включите; используйте бесплатные методы (Google/Apple/anonymous).

**Главный совет по деньгам:** на Blaze сразу настроить **budget alerts** (они не капают расход, только уведомляют) и при желании — программное отключение биллинга по порогу.

## МИНИМАЛЬНАЯ АРХИТЕКТУРА ДЛЯ СОФТ-ЛОНЧА (что КРИТИЧНО до релиза с монетизацией)

Приоритет №1 — не слить выручку и репутацию. По убыванию важности:

1. **Закрыть RTDB security rules** (убрать test-mode): `.read/.write: false` по умолчанию, доступ только под своим `auth.uid`, всё про деньги/очки/HP — `".write": false` (пишет только сервер). **Без этого монетизация = открытый сейф.**
2. **Серверная валидация IAP** через Cloud Functions + Google Play Developer API (`purchases.products.get`) и App Store Server API (`/inApps/v1/transactions/{id}`). Хранить токены против replay, acknowledge, выдавать товар только после валидации, entitlement — в серверный узел. RTDN/ASSN V2 для рефандов.
3. **App Check + enforcement** (Play Integrity / App Attest / reCAPTCHA) на RTDB, Firestore и Cloud Functions — включать после прогрева метрик «verified».
4. **Cloud-сейвы + account linking** (анонимный → Google/Apple), конфликт-резолюция «по максимуму прогресса», подпись/серверная валидация премиум-полей. Иначе теряете прогресс игроков и retention.
5. **Запись очков/клан-вклада/HP-боссов — только через Cloud Functions** (callable, с App Check + Auth), денормализованный `top100` для чтения.
6. **Базовая аналитика + consent** (GameAnalytics/ByteBrew SDK после согласия; ATT + Privacy Manifest на iOS; Data Safety + target API 35 на Android). Без consent — отклонят в сторах.
7. **Remote Config для баланса/событий** — чтобы крутить экономику без релиза (особенно важно после лонча).
8. **CI/CD** хотя бы для web (Pages) и Android (AAB) на Linux-раннере; iOS добавить позже (macOS-раннер дорог).

То, что НЕ делаем перед лончем: тотальный серверный пересчёт idle-прогрессии, миграция на Firestore/Nakama, полный рефакторинг монолита, свой аналитический пайплайн.

## ПОРЯДОК РЕФАКТОРИНГА (чтобы не сломать работающую игру)

Инкрементально, каждый шаг — отдельная ветка + GUT-тесты + ручной regress, мерж только при зелёном билде:

1. **Подключить GUT и покрыть тестами чистую логику** прогрессии/боя/гача-роллов ДО рефакторинга (страховочная сетка).
2. **Выделить сетевой слой в autoload** (`Net`/`Backend` синглтон): все HTTPRequest к RTDB/Auth/Functions — туда. Это всё равно переписывается ради безопасности (п.2 минимальной архитектуры), поэтому совмещаем рефакторинг с обязательной работой.
3. **Выделить систему сейвов в autoload** (`SaveManager`): локальный сейв + облако + конфликт-резолюция + подпись. Тоже обязательная работа.
4. **Вынести баланс в Custom Resources** (таблицы стадий/скиллов/гачи как `.tres`) — данные отдельно от кода, упрощает LiveOps и Remote Config.
5. **Выделить прогрессию в autoload** (`GameState`/`PlayerData`) с сигналами об изменениях; UI подписывается на сигналы, а не лезет в переменные напрямую.
6. **Выделить боевую систему** в отдельную сцену/скрипт, общение через сигналы.
7. **Разнести UI на сцены-компоненты**, подписанные на Signal Bus.

Правило безопасности рефакторинга: не трогать больше одной подсистемы за коммит; держать старый код рабочим, пока новый не покрыт тестами и не проверен на web+Android билдах.

## Recommendations

**Сейчас (0–2 недели, перед любой монетизацией):**
1. Закрыть RTDB rules (test-mode → деньги/очки `write:false`). Это бесплатно и устраняет самый большой риск.
2. Написать 2 Cloud Functions: `validatePurchaseGoogle` и `validatePurchaseApple`. Включить `enforceAppCheck: true`.
3. Подключить App Check (debug-провайдер для разработки, Play Integrity/App Attest/reCAPTCHA для прода), enforcement — после прогрева метрик.
4. Подключить GUT, покрыть тестами прогрессию/гачу.

**Этап софт-лонча (2–8 недель):**
5. Cloud-сейвы + account linking + конфликт-резолюция «по максимуму».
6. Перенести запись очков/клан-вклада/HP-боссов на Cloud Functions; денормализованный `top100`.
7. GameAnalytics или ByteBrew + consent (ATT/Privacy Manifest/Data Safety, API 35).
8. Remote Config для экономики. CI/CD web+Android на Linux.
9. Включить budget alerts на Blaze.

**Рост (после лонча, по триггерам DAU):**
10. **Триггер ~1000–5000 DAU или счёт Firestore/RTDB начинает болеть:** вынести профили/инвентарь в Firestore, счётчики — sharded counters.
11. **Триггер ~10k+ DAU и социалка = ядро монетизации:** рассмотреть self-host Nakama (IAP/leaderboards/clans из коробки) и Redis sorted sets для лидербордов. PlayFab — только если нужен готовый LiveOps-движок и приемлемы Azure-привязка и consumption-модель оплаты.
12. **Триггер 100k DAU:** шардинг RTDB (до 1000 инстансов на проект) или полноценный выделенный бэкенд; iOS CI на macOS-раннере (или платный CI).

**Пороги, меняющие решения:**
- Spark 100 коннектов исчерпан → переход на Blaze (неизбежно перед лончем).
- Месячный счёт Firebase > стоимости managed-альтернативы → считать TCO Nakama/PlayFab.
- macOS CI-минуты > ~200/мес → платный CI или ручные iOS-сборки.

## Caveats
- **Цены и лимиты меняются.** Цифры Firebase (RTDB $5/GB, Firestore $0.06/100k чтений, $0.18/100k записей, $0.18/GB хранилища) и GitHub Actions ($0.062/мин macOS) актуальны на 2025–2026 по официальным страницам, но проверяйте перед решениями. Ранний черновик содержал ошибочную цену чтений Firestore ($0.18) — исправлено на официальные $0.06/100k.
- **Помесячные оценки $/DAU — порядок величины, не гарантия.** Реальный счёт зависит от паттерна (realtime-интенсивность, listener-дизайн, размер сейвов). Один и тот же DAU может стоить $10 или $200.
- **Цены managed Nakama (Heroic Cloud) и PlayFab — по вторичным источникам/обзорам**; PlayFab перешёл на consumption-based meters (фиксированный $99/мес на актуальном прайсинге не подтверждён). Уточняйте у вендоров — прайсинг непрозрачен и менялся.
- **«10× macOS» — эффективное соотношение** ($0.062/$0.006 ≈ 10.3×); GitHub с 2026 публикует raw per-minute rates, а не множители.
- **Community CI-инструменты (mak448a/build-ios)** — не официальные, не production-гарантия; для iOS надёжнее канонический fastlane+match паттерн.
- **Privacy/consent-регуляции (GDPR, ATT, Data Safety, API level floor) ужесточаются** ежегодно; перед релизом сверяйтесь с актуальными требованиями сторов (API 36 станет floor к 31 августа 2026).