extends Control
## Cyber Auto-RPG — болванка №2: РАННЕР-ВИД.
## Отряд "бежит на месте", параллакс-город едет навстречу, волны врагов догоняют →
## бой на месте → победили → марш дальше. Бесконечный поход, считаем волны.
## Болванчики процедурные (без арта). Параметры классов наружу. Ульты = скилл-клапан.

const HEROES := [
	# atk_type: snipe/single/aoe/tank · hpg/dmgg = рост HP/урона за уровень (профиль класса)
	{"name": "СНАЙП", "icon": "🎯", "color": Color("#00f0ff"), "hp": 80,  "dmg": 34, "atk": 2.8, "atk_type": "snipe",  "hpg": 0.09, "dmgg": 0.18, "crit": 0.30, "critx": 2.2, "ult": "burst",  "ult_cd": 9.0,  "wname": "Рельса-винтовка", "wicon": "🔭", "role": "Снайпер · урон по одной цели", "role_en": "Sniper · single-target damage", "desc": "Бьёт ОДНУ цель издалека, огромный крит (30% шанс, ×2.2). В автобою сам выбирает приоритетную цель.\nУЛЬТА «Залп»: тапаешь врага → мега-крит-выстрел.", "desc_en": "Hits ONE target from afar, huge crit (30% chance, ×2.2). In auto-battle it picks the priority target itself.\nULT «Volley»: tap an enemy → mega-crit shot."},
	{"name": "ШТУРМ", "icon": "🔫", "color": Color("#ffb02e"), "hp": 120, "dmg": 9,  "atk": 0.7, "atk_type": "single", "hpg": 0.13, "dmgg": 0.15, "crit": 0.10, "critx": 1.6, "ult": "barrage","ult_cd": 8.0,  "wname": "Штурм-ган", "wicon": "🔫", "role": "Штурмовик · стабильный ДПС", "role_en": "Assault · steady DPS", "desc": "Быстрый одиночный урон, рабочая лошадка отряда. Высокая скорость атаки.\nУЛЬТА «Шквал»: очередь выстрелов по врагам, всплеск урона.", "desc_en": "Fast single-target damage, the squad's workhorse. High attack speed.\nULT «Barrage»: a burst of shots at enemies, a damage spike."},
	{"name": "ТАНК",  "icon": "🦾", "color": Color("#3ad97a"), "hp": 300, "dmg": 6,  "atk": 1.6, "atk_type": "tank",   "hpg": 0.22, "dmgg": 0.10, "crit": 0.05, "critx": 1.5, "ult": "shield", "ult_cd": 11.0, "wname": "Тяж-орудие", "wicon": "💥", "role": "Танк · держит удар", "role_en": "Tank · soaks hits", "desc": "Огромный запас HP (×3.75 от других), принимает урон на себя, защищает сквиши.\nУЛЬТА «Щит»: даёт щит ВСЕМУ отряду — пережить опасный момент.", "desc_en": "Huge HP pool (×3.75 of the others), soaks damage, protects the squishies.\nULT «Shield»: shields the WHOLE squad — survive a dangerous moment."},
	{"name": "ХАКЕР", "icon": "💻", "color": Color("#ff2d95"), "hp": 90,  "dmg": 6,  "atk": 1.4, "atk_type": "aoe",    "hpg": 0.13, "dmgg": 0.14, "crit": 0.08, "critx": 1.6, "ult": "hack",   "ult_cd": 10.0, "wname": "Взлом-дрон", "wicon": "📡", "role": "Хакер · урон по площади", "role_en": "Hacker · area damage", "desc": "Бьёт по ВСЕМ врагам сразу (AoE) — чистит толпы.\nУЛЬТА «Взлом»: мощный импульс урона по площади + отряд бьёт +20% урона 5 сек.", "desc_en": "Hits ALL enemies at once (AoE) — clears crowds.\nULT «Hack»: a powerful AoE damage pulse + the squad deals +20% damage for 5s."},
]
const W := 600.0
const H := 960.0
const GROUND_Y := 0.55 * H   # горизонт выше → дорога ещё шире (под крупные модели + ромб)
# РОМБ-формация (индекс = HEROES: 0 снайпер, 1 штурм, 2 танк, 3 хакер). y относит. центра, s = масштаб
# Гибкая: на будущее отряд набирается сам (3 в ряд) — массив легко расширяется.
const FORMATION := [
	{"x": 95.0,  "y": 56.0,  "s": 1.20},   # СНАЙПЕР — тыл (центр-лево)
	{"x": 195.0, "y": 18.0,  "s": 1.32},   # ШТУРМОВИК — верх-бок (дальняя сторона)
	{"x": 290.0, "y": 58.0,  "s": 1.52},   # ТАНК — остриё/фронт (центр-право, крупный)
	{"x": 195.0, "y": 98.0,  "s": 1.38},   # ХАКЕР — низ-бок (ближняя сторона)
]

var heroes := []
var enemies := []
var phase := "march"      # march | fight | dead
var wave := 0             # эффективный индекс сложности = (stage-1)*5 + (5 если босс, иначе sub)
var stage := 1            # СТАДИЯ (прогресс): 4 норм-волны + босс-ворота; шмот только с босса
var sub := 1             # позиция в стадии: 1..4 норм-волны (фарм-круг)
var in_boss := false      # сейчас бой с боссом
var boss_retry := false   # босс провален на этой стадии → к нему теперь по КНОПКЕ (иначе авто после 4 волн)
var boss_btn: Button      # кнопка «⚔ К БОССУ» (только режим ретрая)
var qte_t := 0.0          # до следующей QTE-серии босса
var qte_seq := 0          # маркеров осталось ЗАСПАВНИТЬ в текущей серии
var qte_idx := 0          # индекс в серии (окно жизни сжимается с ростом)
var qte_total := 0        # всего маркеров в серии (для итога)
var qte_hits := 0         # поймано
var qte_spawn_t := 0.0    # до спавна следующего маркера
var qte_markers := []     # активные маркеры: {node, life}
var march_t := 0.0
var save_t := 5.0         # автосейв-таймер
# ТЕЛЕМЕТРИЯ (тест на друзьях): ник + отправка прогресса в Google-таблицу
const TELEMETRY_URL := "https://ntfy.sh/cyberautorpg-tt-9f3a7k"   # секретный топик ntfy (читаю curl-ом)
const VERSION := "1.9.2" # версия билда (показывается в игре: тестер видит совпадает ли с последней → надо ли обновиться). Бампить КАЖДЫЙ деплой.
var nick := ""
var lang := "ru"   # язык интерфейса (i18n): ru/en, переключатель в настройках
var tele_t := 30.0
var http: HTTPRequest
var nick_panel: Control
var restart_confirm: Control
var _offline_gold := 0
var _offline_secs := 0
var show_dmg := true        # цифры урона над врагами (настройка)
var show_cd := true         # цифры КД ульт (настройка)
var set_cd_btn: Button
var settings_panel: Control
var set_dmg_btn: Button
var lang_btn: Button
var settings_title: Label    # построенные-однажды строки настроек (рефрешим при смене языка)
var settings_ver: Label
var recs_btn: Button
var cache_btn: Button
var nick_lbl: Label
var save_nick_btn: Button
var settings_close: Button
var reboot_title: Label       # заголовок/закрыть панели престижа (build-once → рефреш по языку)
var reboot_close: Button
var nick_show: Label
var set_nick_input: LineEdit
# БОТ-ПЛЕЙТЕСТЕР (godot --headless -- --bot): сам играет, логирует TTSTATE
var bot := false
var bot_tactic := "balanced"
var save_slot := ""       # суффикс файла сейва (для нескольких ботов)
var bot_boss_t := 0.0
var bot_stall_t := 0.0
var bot_last_stage := 1
var bot_psing := 0        # престижей с последней Сингулярности (бот-тест 2-го слоя)
var bot_logf: FileAccess = null   # файловая телеметрия (flush) → /tmp/botstate<slot>.jsonl
var bot_cfg := {}                 # внешний конфиг тактик (hot-reload) → /tmp/bot_tactics.json
var bot_cfg_t := 0.0              # таймер перечитки конфига
var hack_mult := 1.0
var hack_t := 0.0

var bg                      # parallax Node2D
var world: Node2D           # контейнер болванчиков
var hud: Control
var wave_label: Label
var status_label: Label
var hero_ults := []         # кнопки ульт
var boss_bg: ColorRect      # полоса HP босса вверху
var boss_fill: ColorRect
var boss_lbl: Label
var hero_hp := []           # hp-полоски на портретах
var hero_charge := []       # заливка заряда ульты на портретах
var speed_btn: Button
var auto_btn: Button
var auto_battle := false   # АВТОБОЙ: ульты применяются сами, снайпер сам берёт приоритетную цель
var stage_label: Label
var speed_idx := 0
var implants_count := 0
# --- idle-экономика (пассивная модель §4А) ---
var gold := 0.0
var gold_ps := 2.0          # пассивный доход в секунду (база, растит нейрочип)
var gold_label: Label
var inv_btn: Button
var inv_panel: Control
var inv_title: Label
var inv_close: Button
var inv_gold: Label
var inv_open := false
# === ИНВЕНТАРЬ-КОЛЛЕКЦИЯ (п.3): все вещи кучей, фильтры, мультивыбор, избранное, разбор ===
var ic_panel: Control
var ic_open := false
var ic_list: VBoxContainer
var ic_info: Label
var fav := {}              # "i:slot:key" → true : избранное (НЕ разбирается, persist)
var ic_sel := {}           # "i:slot:key" → true : текущее выделение (transient)
var ic_fslot := "all"      # фильтр слота: all/weapon/module
var ic_frar := 0           # фильтр редкости: 0=все, 1..4
var ic_fhero := -1         # фильтр героя: -1=все, 0..3 (оружие у классов разное → Диана)
var ic_fslot_btn: Button
var ic_frar_btn: Button
var ic_fhero_btn: Button
var ic_confirm: Control     # подтверждение разбора
var ic_conf_lbl: Label
var buy_mult := 1          # сколько уровней за тап: 1/10/100/0=MAX
var buy_btns := []         # кнопки выбора множителя
var hero_rows := []   # строки прокачки по героям: {lvl_btn}
# ИМПЛАНТЫ-СКЕЛЕТ (шмотки) — дают БАЗОВЫЕ статы отряду; уровень потом множит (HP/урон)
var impl_btn: Button
var bp_btn: Button
var ach_btn: Button
var more_btn: Button   # «☰ Ещё» — сворачивает баттлпас/ачивки/карту/настройки (UI-редизайн)
var _bp_cache_stage := -1   # кэш счёта батлпас-бейджа (перф)
var _bp_badge_cache := 0
var loot_badge: Label
var impl_panel: Control
var impl_open := false
# статичные строки экрана ЭКИПИРОВКИ (build-once) → рефреш при смене языка
var impl_title: Label
var impl_hdr: Label
var impl_allitems_btn: Button
var impl_hint: Label
var impl_close_btn: Button
var impl_rows := {}
# ИМПЛАНТЫ ПЕР-ПЕРСОНАЖ: у каждого бойца свои 5 слотов. IMPL_DEFS — шаблон (иконка/имя/стат).
# Состояние на героя: hero["impl"][key] = {lvl(звёзды), dupes}. 2 дубля + золото → +1 звезда
const IMPL_DEFS := {
	"core":  {"icon": "🫀", "name": "Реактор · тело", "slot": "+HP"},
	"arms":  {"icon": "🦾", "name": "Сервоприводы · руки", "slot": "+урон"},
	"optic": {"icon": "👁", "name": "Оптика · глаза", "slot": "+крит"},
	"legs":  {"icon": "🦵", "name": "Приводы · ноги", "slot": "+скор.атаки"},
	"neuro": {"icon": "🧠", "name": "Нейрочип · мозг", "slot": "+заряд ульт"},
}
# РЕДИЗАЙН (22.06): спецмодуль на КЛАСС (вместо 5 анатомических слотов). Ключ = индекс героя 0-3.
# Каждый: иконка/имя слота + 3 варианта-модели (primary-стат может отличаться → билды).
const HERO_MODULE := {
	0: {"icon": "👁", "name": "Глаза", "name_en": "Eyes", "variants": [
		{"id": "eye1", "name": "Оптика-MK1", "stat": "crit"},
		{"id": "eye2", "name": "Орлиный глаз", "stat": "crit"},
		{"id": "eye3", "name": "Тепловизор", "stat": "dmg"}]},
	1: {"icon": "🦾", "name": "Сервоприводы", "name_en": "Servos", "variants": [
		{"id": "arm1", "name": "Серво-MK1", "stat": "dmg"},
		{"id": "arm2", "name": "Гидро-усилитель", "stat": "dmg"},
		{"id": "arm3", "name": "Турбо-сервы", "stat": "atk"}]},
	2: {"icon": "🫀", "name": "Реактор", "name_en": "Reactor", "variants": [
		{"id": "core1", "name": "Реактор-MK1", "stat": "hp"},
		{"id": "core2", "name": "Броненосец", "stat": "hp"},
		{"id": "core3", "name": "Ядро-перегрев", "stat": "dmg"}]},
	3: {"icon": "🧠", "name": "Нейрочип", "name_en": "Neurochip", "variants": [
		{"id": "chip1", "name": "Нейро-MK1", "stat": "ult"},
		{"id": "chip2", "name": "Овердрайв", "stat": "ult"},
		{"id": "chip3", "name": "Тихий-протокол", "stat": "crit"}]},
}
# ОРУЖИЕ-КАК-ПРЕДМЕТ (п.А): пушка — полноценный слот gear["weapon"] (редкость/статы/уровень, куча).
# primary-стат "wdmg" = главный урон (отдельная ступень, бьёт сильнее модулей). По 2 модели на класс → билды/куча.
const WEAPON_DEFS := {
	0: {"icon": "🔭", "name": "Оружие", "variants": [
		{"id": "w0a", "name": "Рельса-винтовка", "stat": "wdmg"},
		{"id": "w0b", "name": "Гаусс-длинноствол", "stat": "wdmg"}]},
	1: {"icon": "🔫", "name": "Оружие", "variants": [
		{"id": "w1a", "name": "Штурм-ган", "stat": "wdmg"},
		{"id": "w1b", "name": "Шквал-автомат", "stat": "wdmg"}]},
	2: {"icon": "💥", "name": "Оружие", "variants": [
		{"id": "w2a", "name": "Тяж-орудие", "stat": "wdmg"},
		{"id": "w2b", "name": "Плазма-мортира", "stat": "wdmg"}]},
	3: {"icon": "📡", "name": "Оружие", "variants": [
		{"id": "w3a", "name": "Взлом-дрон", "stat": "wdmg"},
		{"id": "w3b", "name": "Рой-нанитов", "stat": "wdmg"}]},
}
# === ЛУТ-СИСТЕМА (CONCEPT §14) ===
# до 3 моделей на слот (пока 2); у каждой основной стат (может отличаться от дефолта слота → билды)
const ITEM_VARIANTS := {
	"neuro": [
		{"id": "neuro1", "name": "Нейро-MK1", "stat": "ult"},
		{"id": "neuro2", "name": "Овердрайв", "stat": "ult"},
		{"id": "neuro3", "name": "Тихий-протокол", "stat": "crit"},
	],
	"optic": [
		{"id": "optic1", "name": "Оптика-MK1", "stat": "crit"},
		{"id": "optic2", "name": "Орлиный глаз", "stat": "crit"},
		{"id": "optic3", "name": "Тепловизор", "stat": "dmg"},
	],
	"core": [
		{"id": "core1", "name": "Реактор-MK1", "stat": "hp"},
		{"id": "core2", "name": "Броненосец", "stat": "hp"},
		{"id": "core3", "name": "Ядро-перегрев", "stat": "dmg"},
	],
	"arms": [
		{"id": "arms1", "name": "Серво-MK1", "stat": "dmg"},
		{"id": "arms2", "name": "Руки гориллы", "stat": "hp"},
		{"id": "arms3", "name": "Бритвы", "stat": "crit"},
	],
	"legs": [
		{"id": "legs1", "name": "Привод-MK1", "stat": "atk"},
		{"id": "legs2", "name": "Тяж-опоры", "stat": "hp"},
		{"id": "legs3", "name": "Гончая", "stat": "atk"},
	],
}
# редкость = число стат-строк (1..4); индекс 0 не используется
const RARITY := [
	{"name": "—", "name_en": "—", "col": "#666"},
	{"name": "Обычный", "name_en": "Common", "col": "#9aa0a6"},
	{"name": "Необычный", "name_en": "Uncommon", "col": "#3ad97a"},
	{"name": "Редкий", "name_en": "Rare", "col": "#3a8bd9"},
	{"name": "Эпический", "name_en": "Epic", "col": "#b46bff"},
]
# роллы значений: каждый стат роллится из 4 ступеней (100/90/80/70% от макс по 25%) — Genshin-модель
const STAT_ROLL := {
	"hp":   {"max": 40, "fmt": "+%d здоровья", "fmt_en": "+%d HP"},
	"dmg":  {"max": 8, "fmt": "+%d урон", "fmt_en": "+%d dmg"},
	"wdmg": {"max": 16, "fmt": "+%d урон", "fmt_en": "+%d dmg"},
	"crit": {"max": 8, "fmt": "+%d%% крит", "fmt_en": "+%d%% crit"},
	"atk":  {"max": 8, "fmt": "+%d%% скор.атаки", "fmt_en": "+%d%% atk spd"},
	"ult":  {"max": 10, "fmt": "+%d%% заряд ульты", "fmt_en": "+%d%% ult charge"},
}
const ROLL_TIERS := [1.0, 0.9, 0.8, 0.7]   # по 25% каждая
const STAT_KEYS := ["hp", "dmg", "crit", "atk", "ult"]
# === ТИПЫ ВРАГОВ (стат/поведение поверх стат-обмена) ===
# hp/dmg/atk — множители; atk<1 = чаще бьёт; back=бьёт заднюю линию; heal=хилит союзников-врагов; s=масштаб
const ENEMY_TYPES := {
	"grunt":  {"name": "Грунт",      "name_en": "Grunt",    "hp": 1.0, "dmg": 1.0, "atk": 1.0, "col": "#ff5050", "s": 1.0, "icon": ""},
	"armor":  {"name": "Бронебот",   "name_en": "Armorbot", "hp": 3.2, "dmg": 0.6, "atk": 1.4, "col": "#8a96a8", "s": 1.30, "icon": "🛡"},
	"swift":  {"name": "Шустрый",    "name_en": "Speeder",  "hp": 0.5, "dmg": 0.6, "atk": 0.4, "col": "#ffe14d", "s": 0.80, "icon": "⚡"},
	"archer": {"name": "Стрелок",    "name_en": "Shooter",  "hp": 0.7, "dmg": 0.9, "atk": 1.1, "col": "#3a8bd9", "s": 0.95, "back": true, "icon": "🏹"},
	"healer": {"name": "Лекарь",     "name_en": "Medic",    "hp": 1.3, "dmg": 0.3, "atk": 1.3, "col": "#3ad97a", "s": 1.0, "heal": true, "icon": "💚"},
	"shield": {"name": "Щитоносец",  "name_en": "Shielder", "hp": 5.5, "dmg": 0.7, "atk": 1.2, "col": "#4d9bff", "s": 1.18, "icon": "🔵", "shield": true},
	"bomber": {"name": "Взрывной",   "name_en": "Bomber",   "hp": 0.8, "dmg": 1.0, "atk": 1.0, "col": "#ff7a2d", "s": 1.05, "icon": "💣", "bomb": true},
	"swarm":  {"name": "Рой",        "name_en": "Swarm",    "hp": 0.25, "dmg": 0.45, "atk": 0.7, "col": "#c06bff", "s": 0.62, "icon": "🐝", "swarm": true},
}

# КАЛИБРОВКА ПАС4 — модель Clicker Heroes (PROGRESSION-RESEARCH.md): per-STAGE экспонента врагов + ЛИНЕЙНАЯ сила бойца с ×2-изломами каждые N уровней. Зазор линейной силы vs экспон.цены = плавное затухание; ×2-изломы = power-spike «волна».
const ENEMY_HP_BASE := 140.0       # базовое HP врага (рычаг ВРЕМЕНИ: выше = бои дольше = прогресс растягивается, форма кривой та же). Пас4d: 105→140 → ~65-70 мин до 1-го престижа при x1 (Рамиль: «больше часа, с x3-донатом всё равно быстрее»)
const ENEMY_HP_PER_STAGE := 1.34   # HP врага за стадию. 1.28→1.34 (мягкая СТЕНА: 2 нейронки+бот-свип, 27.06): зазор HP-vs-DPS +5.5%/ст → вязко с ст~22 (~80% к гейту-26), доезжает до ст~30 без затыка, гейт не блокирует. √-престиж (10·√макс) делает стену soft-by-design. Не выше 1.38 (жёсткая стена до 26). Боты перекачаны — живой упрётся на 2-4 ст раньше
const ENEMY_DMG_PER_STAGE := 1.20  # умеренный урон врага: есть давление по ХП (низкое ХП опасно у непрокачанного игрока), но потолок не зажат. ХП-фил финально судит живой плейтест (боты перекачаны)
const GOLD_PER_STAGE := 1.20       # золото за стадию — чуть ниже HP (фундирует прокачку, но боец постепенно отстаёт → затухание)
const LVL_COST_GROWTH := 1.12      # цена уровня. Пас4f: →1.12 — ещё медленнее прокачка → ~60 мин до 1-го престижа. Главный рычаг времени.
const DPS_MILESTONE := 25          # ×2 к силе бойца каждые N уровней = регулярный рывок (изломы Clicker Heroes)
const BOSS_HP_CYCLE := [3.0, 4.0, 5.0, 6.0, 10.0]   # множитель HP босса по циклу (stage-1)%5 → каждый 5-й = ×10 (milestone-стена)
# СВИТА БОССА (Рамиль): спец-войска при боссе → тактическая загадка «кого вкачать». Цикл по (stage-1)%size.
const BOSS_ESCORTS := [
	["healer"],          # хил лечит босса → нужен СНАЙПЕР (бьёт хила первым)
	["swarm", "swarm"],  # рой задавит → нужен ХАКЕР (AoE)
	["shield"],          # щит-стена → нужен бурст-СНАЙПЕР
	["bomber"],          # взрыв по отряду → нужен ТАНК/HP
	["healer", "swarm"], # микс
]
const STAT_CAP := 1.0e300          # потолок урона/HP — поднят 1e15→1e300 для бесконечной прогрессии (потолок ~стадия 2300, без float64-overflow 1.8e308). Большие числа → научная запись
const INNATE_WDMG := 16            # вшитый базовый урон «стартового оружия» (слоты на старте ПУСТЫЕ — Диана; боец не слабее)
const STAGE_WAVES := 10        # норм-волн на стадии (потом босс). Кратно 5. Диана/Рамиль: 5→10 — стадия длиннее, темп спокойнее, не суматошно.
const AUG_DIMINISH := 1.0      # 0.88→1.0 для БЕСКОНЕЧНОЙ прогрессии: exp(c·totlvl^1.0) = истинная экспонента (обгоняет HP-экспоненту), а не растянутая (q<1 асимптотит). Главный фикс потолка
const TANK_HP_PER_LVL := 0.11  # уровень ТАНКА → ×(1+это)^ур HP ВСЕМУ отряду (главный источник HP). 0.11 = явный разрыв «с танком/без» (тест). Качаешь танка = живучесть всех; забил = стекляшка. Сweep у ботов (tankhp)
const PRESTIGE_TOTAL_LVL := 350   # престиж: совместный уровень отряда (Пас4f: 200→350 — нельзя рашить престиж голой прокачкой)
const PRESTIGE_STAGE := 26        # ИЛИ достижение этой стадии (Пас4g: 20→26 — позже первый престиж, ~час; кривая плавная → не застрять)

func _max_hero_level() -> int:
	var m := 1
	for hh in heroes:
		if hh["level"] > m: m = hh["level"]
	return m

func _total_levels() -> int:
	var s := 0
	for hh in heroes:
		s += hh["level"]
	return s

func _can_prestige() -> bool:
	# гейт по ТЕКУЩЕЙ стадии/уровням + ОБЯЗАТЕЛЬНО продвинуться выше Memory-Bonus старта (floor(best*0.5)).
	# Иначе после reboot (старт=26 при best≥52) можно спамить престиж за 0 действий (баг-хант R3).
	var advanced: bool = stage > int(floor(float(best_stage) * 0.5))
	return advanced and (_total_levels() >= PRESTIGE_TOTAL_LVL or stage >= PRESTIGE_STAGE)

# === ЛОКАЦИИ (Рамиль): карта → выбор локации → свои враги, фон-палитра, сюжетный квест ===
const LOCATIONS := [
	{"id": "slums",  "name": "Трущобы",     "name_en": "Slums",         "icon": "🏚", "unlock": 1,
	 "pool": ["grunt", "swift", "swarm", "bomber"],
	 "neon": ["#ff2d95", "#b400ff", "#00f0ff"], "ground": "#ffb02e",
	 "desc": "Трущобы — психоз от дешёвых имплантов ZenoCore. Тут начал Вектор.",
	 "desc_en": "Slums — psychosis from cheap ZenoCore implants. Where Vector began.",
	 "quest": {"item": "🔪 Бритва главаря", "item_en": "🔪 Gang Leader's Razor", "boss": "Главарь трущоб", "reward": "weapon", "contact": "🐀 Крыс", "contact_en": "🐀 Rat",
	           "chat": ["Ты тот курьер, которого ZenoCore списали? 🐀 Слыхал.", "Не дёргайся, я свой. Крыс. Тут все так зовут.", "Работа есть. Главарь трущоб таскает фирменную бритву — заказчик за неё отвалит ствол на выбор 🔫", "И гляди в оба: местные звереют от дешёвых имплантов. Психоз. Раньше такого не было...", "Зачисти Трущобы, выбей бритву с босса. Не подведи, Вектор."],
	           "chat_en": ["You're that courier ZenoCore wrote off? 🐀 Heard of you.", "Easy. I'm a friend. Name's Rat. Everyone calls me that here.", "Got a job. The slum boss carries a branded razor — client will pay a weapon of your choice for it 🔫", "And keep your eyes open: locals are going feral from cheap implants. Psychosis. Never used to be this bad...", "Clear the Slums, knock the razor off the boss. Don't let me down, Vector."],
	           "moral": {"id": "batch",
	                     "prompt": "Ещё момент. Тут склад нераспечатанных коробок — те самые импланты ZenoCore. Местные расхватают как «бесплатную силу». Что делать будем?",
	                     "prompt_en": "One more thing. There's a warehouse of unopened boxes here — those very ZenoCore implants. Locals will grab them as 'free power.' What do we do?",
	                     "a": {"label": "🔥 Сжечь партию", "label_en": "🔥 Burn the batch",
	                           "result": "Трущобы остались без «брони», Крыс в ярости — но психоз не расползётся. Ты заплатил репутацией ради чужих.",
	                           "result_en": "The Slums lost their 'armor', Rat is furious — but the psychosis won't spread. You paid with reputation for strangers.",
	                           "karma": 1, "scrap": 0},
	                     "b": {"label": "💰 Дать толкнуть", "label_en": "💰 Let them move it",
	                           "result": "Крыс доволен, карман потяжелел (+400 лом). Но эти импланты ещё вернутся к тебе психами. ⚠️",
	                           "result_en": "Rat's happy, your pocket's heavier (+400 scrap). But those implants will come back to you as psychos. ⚠️",
	                           "karma": -1, "scrap": 400}},
	           "dialog": "Крыс: «Главарь носит фирменную бритву. Достань — заказчик отвалит ствол. И берегись психов: их плодят дешёвые импланты.»"}},
	{"id": "corp",   "name": "Корп-район",   "name_en": "Corp District", "icon": "🏢", "unlock": 8,
	 "pool": ["grunt", "armor", "shield", "archer", "healer"],
	 "neon": ["#00f0ff", "#0077ff", "#7ee08a"], "ground": "#00f0ff",
	 "desc": "Корп-район ZenoCore — где «доступная аугментация» живёт в цифрах.",
	 "desc_en": "ZenoCore Corp District — where 'affordable augmentation' lives on paper.",
	 "quest": {"item": "💳 КПК Холта", "item_en": "💳 Holt's PDA", "boss": "Менеджер Холт", "reward": "weapon", "contact": "💼 Агент Ким", "contact_en": "💼 Agent Kim",
	           "chat": ["Вектор. У меня контракт под тебя 💼", "Я аналитик ZenoCore. Та программа субсидий, что плодит психоз... я визировала отгрузки. Я знала.", "В КПК менеджера Холта — тред «откат партии». Доказательство, что не остановили нарочно.", "Выбей КПК с него. Пушка на выбор твоя.", "И... спасибо, что не спрашиваешь, почему я это сливаю."],
	           "chat_en": ["Vector. I have a contract for you 💼", "I'm a ZenoCore analyst. That subsidy programme that's breeding the psychosis... I signed off on the shipments. I knew.", "In Manager Holt's PDA — a thread called 'batch recall'. Proof they didn't stop it on purpose.", "Knock the PDA off him. A weapon of your choice is yours.", "And... thank you for not asking why I'm leaking this."],
	           "moral": {"id": "holt",
	                     "prompt": "Холт на коленях: «У меня дети. Я подписал «ещё один цикл наблюдений». Один. Дай уйти — я исчезну.» Сдать его публике как лицо скандала — или отпустить?",
	                     "prompt_en": "Holt on his knees: «I have kids. I signed off on 'one more observation cycle.' Just one. Let me go — I'll disappear.» Hand him to the public as the face of the scandal — or let him go?",
	                     "a": {"label": "🤝 Отпустить", "label_en": "🤝 Let him go",
	                           "result": "Ты дал ему уйти. Не монстр — просто человек, что не нажал «стоп». Скандал останется без лица.",
	                           "result_en": "You let him go. Not a monster — just a man who didn't press stop. The scandal will have no face.",
	                           "karma": 1, "scrap": 0},
	                     "b": {"label": "📢 Сдать публике", "label_en": "📢 Expose him",
	                           "result": "Холт — теперь лицо скандала ZenoCore (+500 лом за слив). Но корпа запомнила твоё лицо. ⚠️",
	                           "result_en": "Holt is now the face of the ZenoCore scandal (+500 scrap for the leak). But the corp remembers your face. ⚠️",
	                           "karma": -1, "scrap": 500}},
	           "dialog": "Ким: «В КПК Холта — доказательство, что партию психозных имплантов не отозвали ради премии. Выбей его. Я знала и молчала — хватит.»"}},
	{"id": "docks",  "name": "Доки",         "name_en": "Docks",         "icon": "⚓", "unlock": 16,
	 "pool": ["grunt", "swift", "armor", "bomber", "archer"],
	 "neon": ["#ffb02e", "#00f0ff", "#ff5050"], "ground": "#ffb02e",
	 "desc": "Доки — контрабанда психозных партий, дроны, тяжёлая броня.",
	 "desc_en": "The Docks — contraband psychosis shipments, drones, heavy armor.",
	 "quest": {"item": "📦 Чёрный груз", "item_en": "📦 Black Cargo", "boss": "Босс доков", "reward": "weapon", "contact": "⚓ Боцман", "contact_en": "⚓ Bosun",
	           "chat": ["Слышь, курьер. Боцман на связи ⚓", "На причале — ящик ZenoCore. Та самая партия. Психозная.", "Вожу и для них, и для тебя. Лояльность у меня по прайсу — не обижайся.", "Вышиби ящик с босса доков. Пушка твоя.", "Мне бабки очень нужны. Не спрашивай зачем."],
	           "chat_en": ["Hey, courier. Bosun here ⚓", "There's a crate on the pier — ZenoCore. That very shipment. The psychosis one.", "I haul for both sides. Loyalty's on the price list — no hard feelings.", "Knock the crate off the dock boss. Your weapon.", "I really need the money. Don't ask why."],
	           "moral": {"id": "bosun",
	                     "prompt": "Боцман палится: он слил твой маршрут ZenoCore — за долг дочери в кабале. Прижать его — или понять?",
	                     "prompt_en": "Bosun confesses: he leaked your route to ZenoCore — to pay off his daughter's debt. Squeeze him — or understand?",
	                     "a": {"label": "🫂 Понять", "label_en": "🫂 Understand",
	                           "result": "Ты понял Боцмана. Он сломался от того, что его не убили — теперь он твой, без прайса.",
	                           "result_en": "You understood the Bosun. He broke from the fact they didn't kill him — now he's yours, no price tag.",
	                           "karma": 1, "scrap": 0},
	                     "b": {"label": "🔫 Прижать к стене", "label_en": "🔫 Pin him to the wall",
	                           "result": "Ты выбил из Боцмана компенсацию (+500 лом). Но доверие сожжено — он больше не прикроет.",
	                           "result_en": "You got compensation out of the Bosun (+500 scrap). But the trust is burned — he won't cover for you again.",
	                           "karma": -1, "scrap": 500}},
	           "dialog": "Боцман: «Ящик ZenoCore застрял на причале. Вышиби с босса. Я вожу для всех — кто платит. Не суди.»"}},
	{"id": "core",   "name": "Нео-Ядро",     "name_en": "Neo-Core",      "icon": "🌐", "unlock": 26,
	 "pool": ["grunt", "swift", "armor", "swarm", "archer", "bomber", "healer", "shield"],
	 "neon": ["#ffffff", "#ff2d95", "#00f0ff"], "ground": "#ff2d95",
	 "desc": "Нео-Ядро — здесь живёт то, что сломало Вектору жизнь.",
	 "desc_en": "Neo-Core — where whatever broke Vector's life resides.",
	 "quest": {"item": "🧠 Чип PHANTOM-LIMB", "item_en": "🧠 PHANTOM-LIMB Chip", "boss": "Страж Ядра", "reward": "weapon", "contact": "📡 Сигнал", "contact_en": "📡 Signal",
	           "chat": ["...слышишь меня, Вектор? Это не Крыс и не Ким 📡", "Зови меня Сигнал. Помеха на линии. Шум. Тот, кто слушает.", "В Ядре — чип. Он объяснит твои девять секунд. Те, которых ты не помнишь.", "Дойди до Стража Ядра. Вырви чип. Я проведу.", "...я был там. Когда у тебя в голове всё сломалось. Я помню это изнутри."],
	           "chat_en": ["...can you hear me, Vector? Not Rat, not Kim 📡", "Call me Signal. A glitch on the line. Noise. The one who listens.", "In the Core — a chip. It will explain your nine seconds. The ones you can't remember.", "Reach the Core Guardian. Pull the chip. I'll guide you.", "...I was there. When everything broke inside your head. I remember it from the inside."],
	           "dialog": "Сигнал: «В Ядре — чип, что объяснит твои девять секунд. Дойди до Стража, вырви его. Я проведу — я был там, внутри.»"}},
]
var cur_location := 0       # индекс активной локации
var quest_done := []        # id локаций с закрытым сюжетным квестом
# ТОН ВЕКТОРА — чисто НАРРАТИВНЫЙ выбор реплики (БЕЗ эконом-силы → нет мин-макса, фикс критиков).
# Награда — «Убеждённость»: консистентность одной линии даёт титул-характер, не бафф.
var tone_counts := {"empathy": 0, "anger": 0, "cold": 0}
var moral_choices := {}     # id морального выбора → "a"/"b" (сюжетные развилки)
var karma := 0              # суммарная карма выборов (нарративный счётчик, не бафф)
const TONES := {
	"empathy": {"icon": "🫶", "title": "Сострадающий", "title_en": "Compassionate", "reply": "...Ладно. Но без лишней крови, если выйдет.", "reply_en": "...Alright. But let's keep the bloodshed low, if we can."},
	"anger":   {"icon": "😡", "title": "Яростный",     "title_en": "Furious",       "reply": "Хорошо. Кто-то за это ответит.",             "reply_en": "Fine. Someone's going to answer for this."},
	"cold":    {"icon": "🧊", "title": "Холодный",      "title_en": "Cold",          "reply": "Цена?",                                       "reply_en": "Price?"},
}
func _tone_dominant() -> String:
	var best := ""; var bn := 0; var total := 0
	for k in tone_counts: total += int(tone_counts[k])
	for k in tone_counts:
		if int(tone_counts[k]) > bn: bn = int(tone_counts[k]); best = k
	# Убеждённость = доминирование одной линии (≥60% при ≥3 выборах)
	if total >= 3 and best != "" and float(bn) / float(total) >= 0.6: return best
	return ""

# === ДЕТЕКТИВ «9 СЕКУНД» (фишка игры): фрагменты памяти, среди них подделки ИИ ===
# Фрагменты восстанавливаются по стадиям (front-loaded: ранние часто). 3 из 9 — подделки PHANTOM-LIMB
# с ловимым несоответствием (противоречат известным фактам). Игрок помечает подделки.
const FRAGMENTS := [
	{"unlock": 2,  "fake": false,
	 "text": "Колонна вошла в туннель 14-го этажа. Маршрутизатор гудел ровно. Ты вёл — спокойно, как всегда.",
	 "text_en": "The column entered the 14th floor tunnel. The router hummed steadily. You led — calm, like always."},
	{"unlock": 4,  "fake": false,
	 "text": "В 0:02 кольнуло в виске. Не боль — будто кто-то ВНУТРИ впервые открыл глаза.",
	 "text_en": "At 0:02 a sting in your temple. Not pain — as if someone INSIDE opened their eyes for the first time."},
	{"unlock": 6,  "fake": false,
	 "text": "Тэо крикнул по связи: «Вектор, левый борт!» Ты слышал его. Ты точно его слышал.",
	 "text_en": "Teo shouted over comms: «Vector, port side!» You heard him. You definitely heard him."},
	{"unlock": 9,  "fake": true,
	 "text": "Ты сам убрал руки с управления. Ты хотел, чтобы это случилось.",
	 "text_en": "You took your own hands off the controls. You wanted it to happen.",
	 "tell": "Противоречит: ты СЛЫШАЛ Тэо и реагировал — руки были на управлении.",
	 "tell_en": "Contradicts: you HEARD Teo and were reacting — your hands were on the controls."},
	{"unlock": 12, "fake": false,
	 "text": "Маршрутизатор завис. Экран — белый шум. Девять секунд ты не управлял ничем.",
	 "text_en": "The router froze. Screen — white noise. For nine seconds you controlled nothing."},
	{"unlock": 16, "fake": true,
	 "text": "Тэо успел выпрыгнуть. Ты видел, как он встал и ушёл в дым — живой.",
	 "text_en": "Teo managed to jump out. You saw him stand and walk into the smoke — alive.",
	 "tell": "Противоречит: Тэо погиб, тело не нашли. Этого не было.",
	 "tell_en": "Contradicts: Teo died, the body was never found. This didn't happen."},
	{"unlock": 20, "fake": false,
	 "text": "Картинка вернулась — колонна горела. Тэо не отвечал. Груз исчез.",
	 "text_en": "Vision returned — the column was burning. Teo wasn't answering. The cargo was gone."},
	{"unlock": 25, "fake": true,
	 "text": "Корпа была права: цифры по психозу — просто шум выборки. Твоей вины нет, расслабься.",
	 "text_en": "The corp was right: the psychosis numbers are just sampling noise. It's not your fault, relax.",
	 "tell": "Противоречит: это легенда ZenoCore, а не твоя память. Кто-то вложил её тебе.",
	 "tell_en": "Contradicts: this is ZenoCore's cover story, not your memory. Someone planted it."},
	{"unlock": 30, "fake": false,
	 "text": "Что-то осталось в твоей голове после тех секунд. Оно до сих пор слушает. И иногда — говорит.",
	 "text_en": "Something stayed in your head after those seconds. It still listens. And sometimes — speaks."},
]
var frag_flags := {}        # idx фрагмента → помечен подделкой (bool)
var case_solved := false
var frags_notified := 0     # сколько фрагментов уже показали (для попапа-уведомления)
var milestones_hit := 0     # рубежи стадий (каждые 10) — награда-celebration, БЕЗ DPS (не трогает кривую 1.34)
var power_peak := 0         # ПИК-МОЩЬ (prestige-proof): для клан-боссов — снапшот лучшей силы, не гимпится престижем
func _power_now() -> int:   # текущая мощь отряда + бонус от глубины (best_stage) → база для клан-вклада
	return int(_party_power() * (1.0 + best_stage * 0.04))
func _update_power_peak() -> void:
	power_peak = max(power_peak, _power_now())

# === FIREBASE / КЛАНЫ (мультиплеер) — анонимный auth → #ID игрока ===
const FB_DB_URL := "https://cyber-auto-rpg-default-rtdb.europe-west1.firebasedatabase.app"   # реальный databaseURL (Рамиль, europe-west1)
var fb_uid := ""
var fb_id := ""             # короткий #ID (из uid)
var fb_ready := false
var fb_t := 0.0
var player_clan := ""       # код клана игрока (6 цифр), "" = без клана
var boss_my_dmg := 0        # мой накопленный урон по клан-боссу (локально → пишу свой узел contrib, без гонки)
var boss_atk_cd := 0.0      # кулдаун кнопки «Ударить»
var clan_tokens := 0        # 🎖 клан-жетоны (НЕ продаются за деньги → клан-магаз, награда за клан-боссов)
var boss_claimed := 0       # started-ts последнего босса, с которого забрал награду (анти-дабл-клейм)
# 9 клан-боссов из 3 фракций (имена-заглушки Рамиля), недельная ротация
const CLAN_BOSSES := [
	{"name": "Корпорат Биба Бобович", "fac": "🏢 ZenoCore", "fac_en": "🏢 ZenoCore", "icon": "🏢"},
	{"name": "Топ-Менеджер Квартальный Удой", "fac": "🏢 ZenoCore", "fac_en": "🏢 ZenoCore", "icon": "🏢"},
	{"name": "Директор по Оптимизации Душ", "fac": "🏢 ZenoCore", "fac_en": "🏢 ZenoCore", "icon": "🏢"},
	{"name": "Крыс-Бугор Тройная Доза", "fac": "🔪 Трущобные банды", "fac_en": "🔪 Slum Gangs", "icon": "🔪"},
	{"name": "Психоз-Гена Бензопила", "fac": "🔪 Трущобные банды", "fac_en": "🔪 Slum Gangs", "icon": "🔪"},
	{"name": "Барыга Лысый Череп", "fac": "🔪 Трущобные банды", "fac_en": "🔪 Slum Gangs", "icon": "🔪"},
	{"name": "Боцман Ржавый Крюк", "fac": "⚓ Доковый синдикат", "fac_en": "⚓ Dock Syndicate", "icon": "⚓"},
	{"name": "Контрабандист Жирный Тук", "fac": "⚓ Доковый синдикат", "fac_en": "⚓ Dock Syndicate", "icon": "⚓"},
	{"name": "Док-Барон Мокрый", "fac": "⚓ Доковый синдикат", "fac_en": "⚓ Dock Syndicate", "icon": "⚓"},
]
# локализация фракции босса: значение из Firebase хранится по-русски → маппим в fac_en при EN
func _loc_fac(fac: String) -> String:
	if lang != "en": return fac
	for b in CLAN_BOSSES:
		if str(b.get("fac", "")) == fac: return str(b.get("fac_en", fac))
	return fac
func _week_num() -> int: return int(Time.get_unix_time_from_system() / 604800.0)
func _weekly_boss() -> Dictionary: return CLAN_BOSSES[_week_num() % CLAN_BOSSES.size()]

# === ЛОКАЛИЗАЦИЯ (i18n): _t(key) → строка на текущем языке, фолбэк ru → key ===
const TR := {
	# общие
	"close": {"ru": "✕ закрыть", "en": "✕ close"},
	"ic_all": {"ru": "все", "en": "all"},
	"hud_stage": {"ru": "СТАДИЯ", "en": "STAGE"},
	"hud_wave": {"ru": "волна", "en": "wave"},
	"hud_boss": {"ru": "БОСС", "en": "BOSS"},
	"back": {"ru": "← назад", "en": "← back"},
	"ready": {"ru": "ГОТОВО", "en": "READY"},
	"sec": {"ru": "с", "en": "s"},
	"claim": {"ru": "ЗАБРАТЬ ✨", "en": "CLAIM ✨"},
	"locked": {"ru": "🔒 закрыто", "en": "🔒 locked"},
	# нижнее меню / тултипы
	"tab_upgrade": {"ru": "Прокачка", "en": "Upgrade"},
	"tab_gear": {"ru": "Экипировка", "en": "Gear"},
	"tab_prestige": {"ru": "Престиж", "en": "Prestige"},
	"tab_more": {"ru": "Ещё", "en": "More"},
	# заголовки панелей
	"t_upgrade": {"ru": "📊 ПРОКАЧКА ОТРЯДА", "en": "📊 SQUAD UPGRADE"},
	"t_gear": {"ru": "🦾 ЭКИПИРОВКА БОЙЦА", "en": "🦾 FIGHTER GEAR"},
	"t_prestige": {"ru": "♻ ПРЕСТИЖ", "en": "♻ PRESTIGE"},
	"t_settings": {"ru": "⚙ НАСТРОЙКИ", "en": "⚙ SETTINGS"},
	"t_map": {"ru": "🗺 КАРТА ЛОКАЦИЙ", "en": "🗺 LOCATIONS MAP"},
	# меню «Ещё»
	"m_story": {"ru": "📖 Сюжет", "en": "📖 Story"},
	"m_rewards": {"ru": "🎁 Награды", "en": "🎁 Rewards"},
	"m_map": {"ru": "🗺 Карта локаций", "en": "🗺 Locations map"},
	"m_clans": {"ru": "🛡 Кланы", "en": "🛡 Clans"},
	"m_settings": {"ru": "⚙ Настройки", "en": "⚙ Settings"},
	# панель ПРОКАЧКА
	"u_level": {"ru": "УРОВЕНЬ", "en": "LEVEL"},
	"u_lvl_short": {"ru": "ур", "en": "lv"},
	"u_for": {"ru": "за", "en": "for"},
	"u_need": {"ru": "нужно", "en": "need"},
	"u_need_for": {"ru": "на", "en": "for"},
	"power": {"ru": "Мощь", "en": "Power"},
	"per_sec": {"ru": "/с", "en": "/s"},
	# настройки
	"set_lang": {"ru": "🌐 Язык", "en": "🌐 Language"},
	"set_sci": {"ru": "Научные числа", "en": "Scientific numbers"},
	"set_reset": {"ru": "Сбросить прогресс", "en": "Reset progress"},
	"set_version": {"ru": "версия", "en": "version"},
	"set_lang_btn": {"ru": "🌐 Язык: %s", "en": "🌐 Language: %s"},
	"set_dmg_btn": {"ru": "Цифры урона над врагами: %s", "en": "Damage numbers above enemies: %s"},
	"set_cd_btn": {"ru": "Цифры КД ульт: %s", "en": "Ult cooldown numbers: %s"},
	"on": {"ru": "ВКЛ ✅", "en": "ON ✅"},
	"off": {"ru": "ВЫКЛ ⬜", "en": "OFF ⬜"},
	"set_records": {"ru": "🏆 РЕКОРДЫ / СТАТИСТИКА", "en": "🏆 RECORDS / STATS"},
	"set_refresh": {"ru": "🔄 ОБНОВИТЬ ИГРУ (свежая версия)", "en": "🔄 REFRESH GAME (latest version)"},
	"set_nick_lbl": {"ru": "Твой ник (для теста):", "en": "Your nickname (for testing):"},
	"set_nick_btn": {"ru": "✏ Сменить ник", "en": "✏ Change nickname"},
	"set_nick_saved": {"ru": "Ник: %s", "en": "Nickname: %s"},
	# экран ввода ника (онбординг)
	"nick_title": {"ru": "ВВЕДИ НИК", "en": "ENTER NICKNAME"},
	"nick_sub": {"ru": "для теста (прогресс сохраняется по нику)", "en": "for testing (progress is saved per nickname)"},
	"nick_unset": {"ru": "ник не задан", "en": "nickname not set"},
	"nick_enter_btn": {"ru": "✏ ВВЕСТИ НИК", "en": "✏ ENTER NICKNAME"},
	"nick_play_btn": {"ru": "▶ ИГРАТЬ", "en": "▶ PLAY"},
	"nick_refresh_btn": {"ru": "🔄 обновить версию", "en": "🔄 update version"},
	"guest_nick": {"ru": "гость", "en": "guest"},
	# подтверждение полного сброса
	"reset_title": {"ru": "♻ СБРОСИТЬ ВЕСЬ ПРОГРЕСС?", "en": "♻ RESET ALL PROGRESS?"},
	"reset_body": {"ru": "Сотрёт уровни, шмот, ядра, усиления, стадию.\nЭто новая игра с нуля.", "en": "Wipes levels, gear, cores, augments, stage.\nA brand-new game from scratch."},
	"reset_yes": {"ru": "ДА, СБРОСИТЬ", "en": "YES, RESET"},
	"reset_no": {"ru": "ОТМЕНА", "en": "CANCEL"},
	# панель статистики
	"st_panel_title": {"ru": "🏆 РЕКОРДЫ И СТАТИСТИКА", "en": "🏆 RECORDS AND STATS"},
	"st_power_title": {"ru": "💪 СИЛА ОТРЯДА (сейчас)", "en": "💪 SQUAD POWER (now)"},
	"st_combat_power": {"ru": "⚔ Боевая мощь", "en": "⚔ Combat power"},
	"st_rec_title": {"ru": "🏆 РЕКОРДЫ (за всё время)", "en": "🏆 RECORDS (all time)"},
	"st_best_stage": {"ru": "🌊 Лучшая стадия", "en": "🌊 Best stage"},
	"st_max_lv": {"ru": "⬆ Макс. уровень бойца", "en": "⬆ Max fighter level"},
	"st_prestiges": {"ru": "♻ Престижей сделано", "en": "♻ Prestiges done"},
	"st_maxhit": {"ru": "💥 Самый большой удар", "en": "💥 Biggest hit"},
	"st_stats_title": {"ru": "📊 СТАТИСТИКА", "en": "📊 STATISTICS"},
	"st_col_run": {"ru": "забег", "en": "run"},
	"st_col_all": {"ru": "всего", "en": "total"},
	"st_mobs": {"ru": "☠ Убито мобов", "en": "☠ Mobs killed"},
	"st_bosses": {"ru": "👹 Убито боссов", "en": "👹 Bosses killed"},
	"st_dmg": {"ru": "⚔ Нанесено урона", "en": "⚔ Damage dealt"},
	"st_crits": {"ru": "🎯 Критов нанесено", "en": "🎯 Crits dealt"},
	"st_gold": {"ru": "💰 Золота добыто", "en": "💰 Gold earned"},
	"st_scrap": {"ru": "♻ Лома добыто", "en": "♻ Scrap earned"},
	"st_cores": {"ru": "🧬 Ядер добыто", "en": "🧬 Cores earned"},
	"st_time": {"ru": "⏱ Время в игре", "en": "⏱ Time played"},
	"hr_short": {"ru": "ч", "en": "h"},
	"min_short": {"ru": "м", "en": "m"},
	# панель ЭКИПИРОВКА
	"g_hdr": {"ru": "боец              оружие            спецмодуль", "en": "fighter            weapon            module"},
	"g_allitems": {"ru": "🎒 ВСЕ ВЕЩИ", "en": "🎒 ALL ITEMS"},
	"g_hint": {"ru": "Тап по пушке/спецмодулю → сравнить и надеть. Лут падает с боссов.", "en": "Tap weapon/module → compare & equip. Loot drops from bosses."},
	"g_info": {"ru": "ℹ инфо", "en": "ℹ info"},
	"g_weapon": {"ru": "оружие", "en": "weapon"},
	"g_weapon_caps": {"ru": "ОРУЖИЕ", "en": "WEAPON"},
	"g_module": {"ru": "модуль", "en": "module"},
	"g_empty": {"ru": "— пусто —", "en": "— empty —"},
	"g_compare": {"ru": "— сравни и надень", "en": "— compare & equip"},
	"g_equip": {"ru": "✅ НАДЕТЬ", "en": "✅ EQUIP"},
	"g_equipped": {"ru": "✓ НАДЕТО", "en": "✓ EQUIPPED"},
	"g_back": {"ru": "НАЗАД", "en": "BACK"},
	"lv_dot": {"ru": "ур.", "en": "lv."},
	"close_caps": {"ru": "✕ ЗАКРЫТЬ", "en": "✕ CLOSE"},
	"close_x": {"ru": "× закрыть", "en": "× close"},
	# панель ПРЕСТИЖ (перезагрузка/усиления)
	"rb_title": {"ru": "♻ ПЕРЕЗАГРУЗКА · УСИЛЕНИЯ", "en": "♻ REBOOT · AUGMENTS"},
	"rb_help_t": {"ru": "Престиж и усиления", "en": "Prestige & augments"},
	"rb_help_b": {"ru": "Застрял? ПЕРЕЗАГРУЗКА ♻ обнуляет стадии и уровни, но даёт ЯДРА 🧬 (тем больше, чем глубже зашёл).\n\n• На ядра ОТКРЫВАЕШЬ случайные УСИЛЕНИЯ и качаешь их. Они остаются НАВСЕГДА.\n• Усиления = множители урона/HP/крита/скорости. Следующий заход — сильно мощнее → проходишь дальше.\n• 🎯 КОМБИНИРУЙ разные усиления (урон+крит+скорость+HP) — это выгоднее, чем качать одно. Без HP бойцы дохнут на глубине!\n• Не везёт с усилением — перебрось за алмазы 💎.\n\nСо стадии 40 откроется 🌌 СИНГУЛЯРНОСТЬ — второй слой с вечными мета-бонусами.", "en": "Stuck? REBOOT ♻ wipes stages and levels but grants CORES 🧬 (more the deeper you got).\n\n• Spend cores to UNLOCK random AUGMENTS and level them. They stay FOREVER.\n• Augments = multipliers for damage/HP/crit/speed. Next run is far stronger → you push deeper.\n• 🎯 COMBINE different augments (dmg+crit+speed+HP) — better than maxing one. Without HP your fighters die deep!\n• Bad roll on an augment — reroll it for diamonds 💎.\n\nFrom stage 40 the 🌌 SINGULARITY unlocks — a second layer with permanent meta-bonuses."},
	"rb_reboot_btn": {"ru": "♻ ПЕРЕЗАГРУЗИТЬСЯ", "en": "♻ REBOOT"},
	"rb_info": {"ru": "💪 Мощь: %s    🧬 Ядра: %d", "en": "💪 Power: %s    🧬 Cores: %d"},
	"rb_reboot_gain": {"ru": "♻ ПЕРЕЗАГРУЗИТЬСЯ  (+%d 🧬, старт стадия %d)", "en": "♻ REBOOT  (+%d 🧬, start stage %d)"},
	"rb_lock_above": {"ru": "🔒 Продвинься выше стадии %d, чтобы престижнуть снова", "en": "🔒 Advance past stage %d to prestige again"},
	"rb_lock_req": {"ru": "🔒 Престиж: стадия %d или %d ур.", "en": "🔒 Prestige: stage %d or %d lv."},
	"rb_sng_btn": {"ru": "🌌 СИНГУЛЯРНОСТЬ — мета-прокачка (⚛ %d)%s", "en": "🌌 SINGULARITY — meta upgrades (⚛ %d)%s"},
	"rb_discover": {"ru": "🎲 ОТКРЫТЬ СЛУЧАЙНОЕ УСИЛЕНИЕ  (%d 🧬)", "en": "🎲 UNLOCK RANDOM AUGMENT  (%d 🧬)"},
	"rb_all_open": {"ru": "✓ Все усиления открыты — качай их ниже", "en": "✓ All augments unlocked — level them below"},
	"rb_reroll": {"ru": "🎲 Перебросить «%s» — %d 💎", "en": "🎲 Reroll \"%s\" — %d 💎"},
	"g_upgrade": {"ru": "⬆ Улучшить +10%% (%d🔩)", "en": "⬆ Upgrade +10%% (%d🔩)"},
	"g_upgrade_done": {"ru": "⬆ Улучшено! +10%", "en": "⬆ Upgraded! +10%"},
	"rb_slot": {"ru": "➕ Слот лоадаута %d/%d  (%d 🧬)", "en": "➕ Loadout slot %d/%d  (%d 🧬)"},
	"rb_active": {"ru": "● АКТИВНЫЕ (работают сейчас):", "en": "● ACTIVE (working now):"},
	"rb_spare": {"ru": "○ В ЗАПАСЕ (надень в свободный слот):", "en": "○ SPARE (equip in a free slot):"},
	"rb_eq_on": {"ru": "  ✓надето", "en": "  ✓equipped"},
	"rb_unequip": {"ru": "↩ СНЯТЬ", "en": "↩ UNEQUIP"},
	"rb_slots_full": {"ru": "слоты\nзаняты", "en": "slots\nfull"},
	"rb_lvlup": {"ru": "+ур\n%d🧬", "en": "+lv\n%d🧬"},
	"rb_pop_open": {"ru": "🎲 Открыто: %s %s!\n%s", "en": "🎲 Unlocked: %s %s!\n%s"},
	"rb_pop_reroll": {"ru": "🎲 Переброс → %s %s!\n%s", "en": "🎲 Reroll → %s %s!\n%s"},
	# эффекты усилений
	"ae_dmg": {"ru": "%s урона", "en": "%s damage"},
	"ae_hp": {"ru": "%s здоровья", "en": "%s HP"},
	"ae_gold": {"ru": "+%d%% золота/лома", "en": "+%d%% gold/scrap"},
	"ae_core": {"ru": "+%d%% ядер", "en": "+%d%% cores"},
	"ae_atk": {"ru": "+%d%% скор.атаки", "en": "+%d%% atk speed"},
	"ae_crit": {"ru": "+%.1f%% шанс крита", "en": "+%.1f%% crit chance"},
	"ae_critx": {"ru": "+%.2f× крит-урон", "en": "+%.2f× crit dmg"},
	"ae_ultcd": {"ru": "−%d%% КД ульт", "en": "−%d%% ult CD"},
	"ae_qte": {"ru": "+%.2fс окно QTE", "en": "+%.2fs QTE window"},
	"ae_density": {"ru": "−%d%% HP врагов", "en": "−%d%% enemy HP"},
	# панель СИНГУЛЯРНОСТЬ (2-й слой)
	"sg_title": {"ru": "🌌 СИНГУЛЯРНОСТЬ", "en": "🌌 SINGULARITY"},
	"sg_stat": {"ru": "⚛ Кванты: %d   ·   Сингулярностей: %d", "en": "⚛ Quanta: %d   ·   Singularities: %d"},
	"sg_perma": {"ru": "Мета-бонусы ПЕРМАНЕНТНЫ — не сбрасываются ни Перезагрузкой, ни Сингулярностью.", "en": "Meta-bonuses are PERMANENT — reset by neither Reboot nor Singularity."},
	"sg_max": {"ru": "макс", "en": "max"},
	"sg_row_max": {"ru": "%s — %s%d (%s) · %s", "en": "%s — %s%d (%s) · %s"},
	"sg_row": {"ru": "%s %s%d → %d  ·  %s  ·  %d ⚛", "en": "%s %s%d → %d  ·  %s  ·  %d ⚛"},
	"sg_do": {"ru": "🌌 СДЕЛАТЬ СИНГУЛЯРНОСТЬ  (+%d ⚛)\nсброс 1-го слоя · шмот и алмазы целы", "en": "🌌 TRIGGER SINGULARITY  (+%d ⚛)\nresets layer 1 · gear & diamonds safe"},
	"sg_locked": {"ru": "🔒 Доступно со стадии %d (сейчас %d)", "en": "🔒 Unlocks at stage %d (now %d)"},
	"sg_pop": {"ru": "🌌 СИНГУЛЯРНОСТЬ #%d\n+%d ⚛ КВАНТОВ", "en": "🌌 SINGULARITY #%d\n+%d ⚛ QUANTA"},
	"rb_owned_row": {"ru": "%s %s  %s%d%s", "en": "%s %s  %s%d%s"},
	# панель КЛАНЫ
	"cl_title": {"ru": "🛡 КЛАН", "en": "🛡 CLAN"},
	"cl_web_only": {"ru": "Кланы работают в веб-версии", "en": "Clans are only available in the web version"},
	"cl_connecting": {"ru": "⏳ Подключение к серверу кланов…", "en": "⏳ Connecting to clan server…"},
	"cl_my_id": {"ru": "Твой ID: %s    ник: %s", "en": "Your ID: %s    nick: %s"},
	"cl_peak": {"ru": "⚡ Пик-мощь: %s    🎖 Жетоны: %s", "en": "⚡ Peak power: %s    🎖 Tokens: %s"},
	"cl_no_clan": {"ru": "Ты без клана. Создай свой или вступи по коду друга:", "en": "You have no clan. Create one or join by a friend's code:"},
	"cl_create_btn": {"ru": "🛡 СОЗДАТЬ КЛАН", "en": "🛡 CREATE CLAN"},
	"cl_or_join": {"ru": "— или вступить по коду —", "en": "— or join by code —"},
	"cl_code_ph": {"ru": "код", "en": "code"},
	"cl_join_btn": {"ru": "🤝 ВСТУПИТЬ", "en": "🤝 JOIN"},
	"cl_code_label": {"ru": "Код клана: %s", "en": "Clan code: %s"},
	"cl_share_code": {"ru": "Поделись кодом с друзьями 🤝", "en": "Share the code with friends 🤝"},
	"cl_loading_members": {"ru": "⏳ загрузка состава…", "en": "⏳ loading members…"},
	"cl_disbanded": {"ru": "Клан распался.", "en": "Clan has disbanded."},
	"cl_members": {"ru": "👥 Состав (%d/20):\n", "en": "👥 Members (%d/20):\n"},
	"cl_boss_btn": {"ru": "👹 КЛАН-БОСС", "en": "👹 CLAN BOSS"},
	"cl_chat_btn": {"ru": "💬 ЧАТ КЛАНА", "en": "💬 CLAN CHAT"},
	"cl_leave_btn": {"ru": "🚪 Выйти из клана", "en": "🚪 Leave clan"},
	"cl_no_server": {"ru": "Нет связи с сервером кланов", "en": "No connection to clan server"},
	"cl_no_server_j": {"ru": "Нет связи с сервером", "en": "No server connection"},
	"cl_code_6d": {"ru": "Код = 6 цифр", "en": "Code = 6 digits"},
	"cl_not_found": {"ru": "Клан %s не найден", "en": "Clan %s not found"},
	"cl_full": {"ru": "Клан полон (20/20)", "en": "Clan is full (20/20)"},
	"cl_created": {"ru": "🛡 Клан создан! Код: %s", "en": "🛡 Clan created! Code: %s"},
	"cl_err_create": {"ru": "Ошибка создания (%d)", "en": "Create error (%d)"},
	"cl_joined": {"ru": "🛡 Вступил в клан %s!", "en": "🛡 Joined clan %s!"},
	"cl_err_join": {"ru": "Ошибка вступления (%d)", "en": "Join error (%d)"},
	"cl_left": {"ru": "Вышел из клана", "en": "Left the clan"},
	# клан-босс
	"cl_boss_title": {"ru": "👹 КЛАН-БОСС", "en": "👹 CLAN BOSS"},
	"cl_loading": {"ru": "⏳ загрузка…", "en": "⏳ loading…"},
	"cl_no_boss": {"ru": "Босса нет. Призовите его!", "en": "No boss. Summon one!"},
	"cl_boss_killed": {"ru": "💥 %s ПОВЕРЖЕН!", "en": "💥 %s DEFEATED!"},
	"cl_boss_reward": {"ru": "🏆 Награда клана: +%d💎  +%d🎖", "en": "🏆 Clan reward: +%d💎  +%d🎖"},
	"cl_boss_fac_default": {"ru": "Бейте всем кланом!", "en": "Attack with the whole clan!"},
	"cl_leaderboard": {"ru": "🏆 ЛИДЕРБОРД ВКЛАДА:\n", "en": "🏆 CONTRIBUTION LEADERBOARD:\n"},
	"cl_boss_weekly": {"ru": "👹 Босс недели: %s", "en": "👹 Weekly boss: %s"},
	"cl_spawn_btn": {"ru": "🔮 Призвать босса недели", "en": "🔮 Summon weekly boss"},
	"cl_atk_btn": {"ru": "⚔ УДАРИТЬ", "en": "⚔ ATTACK"},
	"cl_boss_summoned": {"ru": "%s призван! Бейте все!", "en": "%s summoned! Attack!"},
	"cl_boss_hit": {"ru": "⚔ −%s урона боссу!", "en": "⚔ −%s dmg to boss!"},
	# чат клана
	"cl_chat_title": {"ru": "💬 ЧАТ КЛАНА %s", "en": "💬 CLAN CHAT %s"},
	"cl_chat_empty": {"ru": "Сообщений пока нет.\nНапиши первым 👋", "en": "No messages yet.\nBe the first 👋"},
	"cl_chat_ph": {"ru": "сообщение…", "en": "message…"},
	# клан-магаз
	"cls_btn":      {"ru": "🎖 КЛАН-МАГАЗ",           "en": "🎖 CLAN SHOP"},
	"cls_title":    {"ru": "🎖 КЛАН-МАГАЗ",           "en": "🎖 CLAN SHOP"},
	"cls_balance":  {"ru": "Ваши жетоны: %d 🎖",      "en": "Your tokens: %d 🎖"},
	"cls_active":   {"ru": "✅ активен (%dмин)",       "en": "✅ active (%dmin)"},
	"cls_bought":   {"ru": "Куплено! 🎖",              "en": "Purchased! 🎖"},
	"cls_no_tokens":{"ru": "Мало жетонов!",            "en": "Not enough tokens!"},
	"cl_boss_default_name": {"ru": "Клан-босс", "en": "Clan Boss"},
	# дейли-квесты + стрик-награда
	"dq_title":     {"ru": "📋 ЕЖЕДНЕВНЫЕ КВЕСТЫ", "en": "📋 DAILY QUESTS"},
	"dq_subtitle":  {"ru": "Обновляются каждый день. Прогресс — за сегодня.", "en": "Resets daily. Only today's progress counts."},
	"dq_claimed":   {"ru": "✅ Забрано   ", "en": "✅ Claimed   "},
	"dq_done_pop":  {"ru": "✅ Квест выполнен: ", "en": "✅ Quest complete: "},
	"m_daily":      {"ru": "📋  Ежедневные квесты", "en": "📋  Daily quests"},
	"m_battlepass": {"ru": "🎟  Батлпас", "en": "🎟  Battle pass"},
	"m_achieve":    {"ru": "📖  Достижения", "en": "📖  Achievements"},
	"m_rewards_hdr":{"ru": "🎁 НАГРАДЫ", "en": "🎁 REWARDS"},
	"dr_title":     {"ru": "🎁 ЕЖЕДНЕВНАЯ НАГРАДА", "en": "🎁 DAILY REWARD"},
	"dr_streak":    {"ru": "Стрик: день %d из 7   ·   заходи каждый день!", "en": "Streak: day %d of 7   ·   come back every day!"},
	"dr_day_short": {"ru": "Д%d", "en": "D%d"},
	"dr_claim_btn": {"ru": "🎁 ЗАБРАТЬ ДЕНЬ %d (+%s)", "en": "🎁 CLAIM DAY %d (+%s)"},
	"dr_pop":       {"ru": "🎁 День %d: +%s!", "en": "🎁 Day %d: +%s!"},
	# батлпас
	"bp_title":     {"ru": "🎟 БАТЛПАС — награды за стадии", "en": "🎟 BATTLE PASS — stage rewards"},
	"bp_sub":       {"ru": "Текущая лучшая стадия: %d   ·   до след. тира: %d стадий", "en": "Best stage: %d   ·   next tier in: %d stages"},
	"bp_buy_btn":   {"ru": "💎 Премиум-батлпас (жирнее награды) — %d 💎", "en": "💎 Premium pass (better rewards) — %d 💎"},
	"bp_free_hdr":  {"ru": "🆓 БЕСПЛАТНО", "en": "🆓 FREE"},
	"bp_prem_hdr":  {"ru": "💎 ПРЕМИУМ", "en": "💎 PREMIUM"},
	"bp_prem_cost": {"ru": "(за 500💎)", "en": "(for 500💎)"},
	"bp_stage_n":   {"ru": "ст.%d", "en": "stg %d"},
	# ачивки
	"ach_title":     {"ru": "📖 ДОСТИЖЕНИЯ", "en": "📖 ACHIEVEMENTS"},
	"ach_sub":       {"ru": "Готово к забору: %d   ·   награда → 💎/🧬/♻", "en": "Ready to claim: %d   ·   reward → 💎/🧬/♻"},
	"ach_claim_all": {"ru": "✨ ЗАБРАТЬ ВСЁ (%d)", "en": "✨ CLAIM ALL (%d)"},
	"ach_all_done":  {"ru": "✓ ВСЁ ВЫПОЛНЕНО", "en": "✓ ALL COMPLETED"},
	"ach_progress":  {"ru": "%s / %s  → награда %s", "en": "%s / %s  → reward %s"},
	"ach_claim_btn": {"ru": "ЗАБРАТЬ ✨", "en": "CLAIM ✨"},
	"ach_tier":      {"ru": "Тир %d/%d", "en": "Tier %d/%d"},
	"ach_rew_dia":   {"ru": "+%d💎 алмазов", "en": "+%d💎 diamonds"},
	"ach_rew_cores": {"ru": "+%d🧬 ядер", "en": "+%d🧬 cores"},
	"ach_rew_scrap": {"ru": "+%d♻ скрапа", "en": "+%d♻ scrap"},
	# карта локаций
	"map_title":    {"ru": "🗺 КАРТА — ЛОКАЦИИ", "en": "🗺 LOCATIONS MAP"},
	"map_sub":      {"ru": "Выбери район — свои враги, свой вид, свой сюжетный квест", "en": "Choose a district — unique enemies, look & story quest"},
	"map_here":     {"ru": "  ◀ ЗДЕСЬ", "en": "  ◀ HERE"},
	"map_lock":     {"ru": "  🔒 со стадии %d", "en": "  🔒 from stage %d"},
	"map_enemies":  {"ru": "Враги: ", "en": "Enemies: "},
	"map_qdone":    {"ru": "✅ Квест закрыт: %s", "en": "✅ Quest done: %s"},
	"map_qget":     {"ru": "📜 Квест: добыть %s с босса", "en": "📜 Quest: get %s from boss"},
	"map_go":       {"ru": "▶ ОТПРАВИТЬСЯ", "en": "▶ GO THERE"},
	"map_new_msg":  {"ru": "📨 Новое сообщение от %s", "en": "📨 New message from %s"},
	# help-подсказки (кнопка «?»)
	"help_ok":      {"ru": "Понятно 👍", "en": "Got it 👍"},
	"wc_help_t":    {"ru": "Добро пожаловать!", "en": "Welcome!"},
	"wc_help_b":    {"ru": "Твой отряд из 4 бойцов АВТО-бьётся с волнами врагов.\n\n• 📊 ПРОКАЧКА — повышай уровни бойцов за золото 💰\n• 🦾 ЭКИПИРОВКА — надевай выпавший лут (оружие/модули)\n• ⚡ Тапай ульты бойцов внизу когда готовы\n• ♻ ПРЕСТИЖ — когда застрял: сброс ради ЯДЕР → усиления навсегда\n\nЦель: бей волны → собирай лут → прокачивайся → проходи стадии глубже. У каждого экрана есть «?» с подсказкой.", "en": "Your squad of 4 fighters AUTO-fights waves of enemies.\n\n• 📊 UPGRADE — level up fighters for gold 💰\n• 🦾 GEAR — equip dropped loot (weapons/modules)\n• ⚡ Tap fighter ultimates at the bottom when ready\n• ♻ PRESTIGE — when stuck: reset for CORES → permanent upgrades\n\nGoal: beat waves → collect loot → power up → push stages deeper. Every screen has a «?» tip."},
	"upg_help_t":   {"ru": "Прокачка отряда", "en": "Squad Upgrade"},
	"upg_help_b":   {"ru": "Повышай УРОВЕНЬ бойцов за золото 💰. Уровень множит их урон и здоровье — основа силы.\n\n• Чем выше уровень — тем дороже следующий.\n• Кнопка ×1/×10/×100 — сколько уровней брать за раз.\n• Качай отстающих или вливай в любимца под свой билд.\n\nЗолото капает само + падает с врагов. Не хватает — фарми текущую стадию.", "en": "Level up FIGHTERS for gold 💰. Level multiplies their damage and HP — foundation of power.\n\n• Higher level = more expensive next level.\n• ×1/×10/×100 button — how many levels to buy at once.\n• Upgrade laggards or pour into your favorite for your build.\n\nGold trickles in + drops from enemies. Not enough — farm the current stage."},
	"gear_help_t":  {"ru": "Экипировка", "en": "Gear"},
	"gear_help_b":  {"ru": "Надевай выпавший ЛУТ бойцам.\n\n• Выбери бойца портретом слева (подсветка = активный).\n• ОРУЖИЕ 🔫 = урон. МОДУЛЬ 🦾 = защита/утилита (HP, заряд ульты).\n• Тап по предмету в списке → сравнить и надеть лучший.\n• Цвет = редкость (серый→зелёный→синий→фиолет). «НАДЕТО» = то что носишь.\n• ℹ на портрете = описание класса и ульты.\n\nЛут падает с волн и боссов под конкретного бойца.", "en": "Equip dropped LOOT to fighters.\n\n• Choose a fighter by portrait on the left (highlight = active).\n• WEAPON 🔫 = damage. MODULE 🦾 = defense/utility (HP, ult charge).\n• Tap an item → compare and equip the best.\n• Color = rarity (grey→green→blue→purple). «EQUIPPED» = what you're wearing.\n• ℹ on portrait = class and ult description.\n\nLoot drops from waves and bosses for a specific fighter."},
	# сюжет — квест-чат
	"quest_online":      {"ru": "🟢 в сети", "en": "🟢 online"},
	"quest_reply_prompt":{"ru": "— что ответишь? —", "en": "— what's your reply? —"},
	"quest_goal":        {"ru": "🎯 Цель: «%s» с босса «%s» · 🎁 пушка на выбор", "en": "🎯 Target: «%s» from boss «%s» · 🎁 weapon of your choice"},
	"quest_tone_line":   {"ru": "〔 ты держишь линию: %s %s 〕", "en": "〔 you hold the line: %s %s 〕"},
	"no_msgs":           {"ru": "📭 Нет новых сообщений. Открой район на 🗺 карте.", "en": "📭 No new messages. Open a district on the 🗺 map."},
	# досье Вектора
	"dossier_title":     {"ru": "📁 ДОСЬЕ: ВЕКТОР", "en": "📁 DOSSIER: VECTOR"},
	"dossier_bio":       {"ru": "Экс-курьер ZenoCore. Списан после «инцидента на 14-м этаже»: боевой маршрутизатор-имплант завис на 9 секунд, погиб напарник Тэо. Этих девяти секунд Вектор не помнит — и не знает, виноват ли.", "en": "Ex-ZenoCore courier. Written off after the '14th floor incident': a combat router implant froze for 9 seconds, partner Teo was killed. Vector has no memory of those nine seconds — and doesn't know if he's to blame."},
	"dossier_char":      {"ru": "— ХАРАКТЕР —", "en": "— CHARACTER —"},
	"dossier_no_char":   {"ru": "❓ Ещё не определился", "en": "❓ Not decided yet"},
	"dossier_conscience":{"ru": "— СОВЕСТЬ —", "en": "— CONSCIENCE —"},
	"karma_neutral":     {"ru": "⚖️ Прагматик", "en": "⚖️ Pragmatist"},
	"karma_good":        {"ru": "🕊 Милосердный (+%d)", "en": "🕊 Merciful (+%d)"},
	"karma_bad":         {"ru": "💀 Безжалостный (%d)", "en": "💀 Ruthless (%d)"},
	"dossier_decisions": {"ru": "— РЕШЕНИЯ —", "en": "— DECISIONS —"},
	"dossier_no_dec":    {"ru": "Пока ни одного выбора. Иди по сюжету.", "en": "No choices made yet. Follow the story."},
	"dossier_close":     {"ru": "✕ закрыть", "en": "✕ close"},
	# дело «9 секунд»
	"case_title":        {"ru": "📓 ДЕЛО: ДЕВЯТЬ СЕКУНД", "en": "📓 CASE: NINE SECONDS"},
	"case_sub":          {"ru": "Те 9 секунд, которых ты не помнишь. Часть «воспоминаний» подброшена ИИ — помечай подделки 🚩\n🔎 Открыто %d/9 · подделок среди них: %d", "en": "Those 9 seconds you can't remember. Some 'memories' were planted by AI — flag the fakes 🚩\n🔎 Revealed %d/9 · fakes among them: %d"},
	"case_empty":        {"ru": "Память пуста. Зачищай стадии — фрагменты вернутся (1-й со стадии 2).", "en": "Memory empty. Clear stages — fragments will return (1st from stage 2)."},
	"case_frag_hdr":     {"ru": "🧩 Фрагмент %d", "en": "🧩 Fragment %d"},
	"case_fake_lbl":     {"ru": "⚠️ ПОДДЕЛКА ИИ. %s", "en": "⚠️ AI FAKE. %s"},
	"case_flag_on":      {"ru": "🚩 помечено подделкой", "en": "🚩 flagged as fake"},
	"case_flag_off":     {"ru": "помечу подделкой", "en": "mark as fake"},
	"case_check_btn":    {"ru": "🔍 ПРОВЕРИТЬ ВЕРСИЮ", "en": "🔍 CHECK THEORY"},
	"case_solved_title": {"ru": "📓 ДЕЛО РАСКРЫТО — Девять секунд", "en": "📓 CASE SOLVED — Nine Seconds"},
	"case_solved_body":  {"ru": "Ты вычистил подделки ИИ. Правда: ты НЕ трус и не убирал руки. Прототип PHANTOM-LIMB, что тестили в твоём маршрутизаторе, впервые поймал рассинхрон и заклинил — утянув тебя на девять секунд. Тэо погиб не по твоей вине. А часть того ИИ осталась в твоей голове. Оно слушает. Иногда — говорит.", "en": "You cleared the AI fakes. The truth: you were NOT a coward and did not take your hands off the controls. The PHANTOM-LIMB prototype being tested in your router caught a desync for the first time and froze — pulling you under for nine seconds. Teo's death was not your fault. And a part of that AI stayed in your head. It listens. Sometimes — it speaks."},
	"case_ok":           {"ru": "✅ Пока сходится. Жди новых фрагментов памяти.", "en": "✅ Checks out so far. Wait for more memory fragments."},
	"case_fail":         {"ru": "❌ Версия не сходится. Что противоречит фактам?", "en": "❌ Theory doesn't hold. What contradicts the facts?"},
	"case_close":        {"ru": "✕ закрыть", "en": "✕ close"},
	# финал
	"finale_locked":     {"ru": "🏁 Финал откроется после всех 4 актов (%d/4). Иди по сюжету.", "en": "🏁 The finale unlocks after all 4 acts (%d/4). Follow the story."},
	"finale_case_done":  {"ru": "📓 А девять секунд ты раскрыл: ты не был трусом. И часть его — навсегда с тобой.", "en": "📓 And the nine seconds — you solved that: you were no coward. And a part of it is with you forever."},
	"finale_case_open":  {"ru": "(Тайна девяти секунд так и не раскрыта — собери фрагменты в 📓 Деле.)", "en": "(The mystery of the nine seconds remains unsolved — collect fragments in the 📓 Case.)"},
	# кнопка обновления в меню «Ещё»
	"update_btn":        {"ru": "🔄  v%s · обновить игру", "en": "🔄  v%s · update game"},
	# QA-локализация: дочистка пропусков
	"nick_prompt":       {"ru": "Введи ник для теста:", "en": "Enter a nickname (for testing):"},
	"offline_title":     {"ru": "🌙 ОТРЯД РАБОТАЛ БЕЗ ТЕБЯ", "en": "🌙 YOUR SQUAD KEPT WORKING WHILE YOU WERE AWAY"},
	"offline_body":      {"ru": "Тебя не было: %s\n\n💰 Заработано: %s золота", "en": "You were away: %s\n\n💰 Earned: %s gold"},
	"offline_collect":   {"ru": "ЗАБРАТЬ", "en": "COLLECT"},
	"inv_title":         {"ru": "🎒 ИНВЕНТАРЬ", "en": "🎒 INVENTORY"},
	"inv_all":           {"ru": "☑ ВСЁ", "en": "☑ ALL"},
	"inv_fav":           {"ru": "★ ИЗБРАННОЕ", "en": "★ FAVORITES"},
	"inv_scrap":         {"ru": "♻ РАЗОБРАТЬ", "en": "♻ SCRAP"},
	"inv_close":         {"ru": "✕ ЗАКРЫТЬ", "en": "✕ CLOSE"},
	"inv_status":        {"ru": "вещей: %d   выбрано: %d   ♻ лом: %s", "en": "items: %d   selected: %d   ♻ scrap: %s"},
	"inv_equipped":      {"ru": "✓ НАДЕТО", "en": "✓ EQUIPPED"},
	"inv_lvl":           {"ru": "ур.%d", "en": "lv.%d"},
	"scrap_confirm":     {"ru": "Разобрать %d вещей в лом?\n(избранное и надетое пропускаются)", "en": "Scrap %d items?\n(favorites and equipped are skipped)"},
	"scrap_done":        {"ru": "♻ Разобрано → +%s лом", "en": "♻ Scrapped → +%s scrap"},
	"cancel_btn":        {"ru": "ОТМЕНА", "en": "CANCEL"},
	"skipped_loot":      {"ru": "🎁 Лут за %d пропущенных боссов:\n+%d в инвентарь · +%d ♻ лом", "en": "🎁 Loot from %d skipped bosses:\n+%d to inventory · +%d ♻ scrap"},
	"hero_desc_close":   {"ru": "× закрыть", "en": "× close"},
	"reboot_done":       {"ru": "♻ ПЕРЕЗАГРУЗКА +%d 🧬 ЯДЕР", "en": "♻ REBOOT +%d 🧬 CORES"},
	"cls_for_30min":     {"ru": "на 30 мин", "en": "for 30 min"},
	"clan_name_prefix":  {"ru": "Клан ", "en": "Clan "},
	"more_title":        {"ru": "☰ ЕЩЁ", "en": "☰ MORE"},
	"force_update_msg":  {"ru": "🔄 Обновление доступно в веб-версии", "en": "🔄 Update is available in the web version"},
	"story_title":       {"ru": "📖 СЮЖЕТ", "en": "📖 STORY"},
	"story_messages":    {"ru": "📱  Сообщения / квест", "en": "📱  Messages / quest"},
	"story_dossier":     {"ru": "📁  Досье: Вектор", "en": "📁  Dossier: Vector"},
	"story_case":        {"ru": "📓  Дело: 9 секунд", "en": "📓  Case: 9 Seconds"},
	"story_finale":      {"ru": "🏁  Финал", "en": "🏁  Finale"},
	"hud_boss_warn":     {"ru": "⚠ БОСС   %d / %d", "en": "⚠ BOSS   %d / %d"},
	"to_boss":           {"ru": "👹 К БОССУ", "en": "👹 TO BOSS"},
	"new_loot":          {"ru": "🎁 НОВЫЙ ЛУТ ↓", "en": "🎁 NEW LOOT ↓"},
	"hero_snipe":        {"ru": "СНАЙП", "en": "SNIPE"},
	"hero_assault":      {"ru": "ШТУРМ", "en": "ASSAULT"},
	"hero_tank":         {"ru": "ТАНК", "en": "TANK"},
	"hero_hacker":       {"ru": "ХАКЕР", "en": "HACKER"},
	"pick_target":       {"ru": "ВЫБЕРИ ЦЕЛЬ — тапни врага", "en": "PICK A TARGET — tap an enemy"},
	"hack_done":         {"ru": "💻 ВЗЛОМ! Отряд +20% урона", "en": "💻 HACK! Squad +20% damage"},
	"qte_start":         {"ru": "⚡ ТАПАЙ МАРКЕРЫ!", "en": "⚡ TAP THE MARKERS!"},
	"qte_perfect":       {"ru": "⚡ ИДЕАЛЬНЫЙ КОНТЕР! %d/%d", "en": "⚡ PERFECT COUNTER! %d/%d"},
	"qte_counter":       {"ru": "КОНТЕР %d/%d", "en": "COUNTER %d/%d"},
	"squad_down_wave":   {"ru": "☠ ОТРЯД ПАЛ — дошли до волны %d", "en": "☠ SQUAD DOWN — reached wave %d"},
	"you_died":          {"ru": "☠ ТЫ ПОГИБ\nПрокачай отряд и попробуй снова", "en": "☠ YOU DIED\nUpgrade your squad and try again"},
	"squad_wiped":       {"ru": "☠ Отряд пал — перегруппировка", "en": "☠ Squad wiped — regrouping"},
	"stage_cleared":     {"ru": "🏆 СТАДИЯ %d ПРОЙДЕНА", "en": "🏆 STAGE %d CLEARED"},
	"memory_fragment":   {"ru": "🧩 Восстановлен фрагмент памяти — открой 📓 Дело", "en": "🧩 Memory fragment recovered — open the 📓 Case"},
	"milestone_stage":   {"ru": "🏆 РУБЕЖ: СТАДИЯ %d! +%d🔩 +%d💎", "en": "🏆 MILESTONE: STAGE %d! +%d🔩 +%d💎"},
	"hint_tank":         {"ru": "💡 Подкачай отряд или вкачай ТАНКА для живучести всех", "en": "💡 Power up your squad or level the TANK for everyone's survivability"},
	"hint_sniper":       {"ru": "💡 Качай СНАЙПЕРА — он первым бьёт 💊хилеров и 🛡щитоносцев", "en": "💡 Level the SNIPER — he hits 💊healers and 🛡shielders first"},
	"hint_hacker":       {"ru": "💡 Качай ХАКЕРА — его AoE выкосит 🐝рой", "en": "💡 Level the HACKER — his AoE mows down the 🐝swarm"},
	"hint_bomber":       {"ru": "💡 Качай ТАНКА — 💥взрывные бьют по отряду, нужен запас HP", "en": "💡 Level the TANK — 💥bombers hit the whole squad, you need HP reserve"},
	# монетизация: панель скорости
	"spd_title":         {"ru": "⏩ СКОРОСТЬ  (💎 %d)", "en": "⏩ SPEED  (💎 %d)"},
	"spd_x1":            {"ru": "⏩ x1 — обычная (беспл)", "en": "⏩ x1 — normal (free)"},
	"spd_x2_active":     {"ru": "⏩⏩ x2 — активна (%dмин)", "en": "⏩⏩ x2 — active (%d min)"},
	"spd_x2_ad":         {"ru": "▶ x2 на 30 мин — посмотреть рекламу", "en": "▶ x2 for 30 min — watch an ad"},
	"spd_x3_bought":     {"ru": "⏩⏩⏩ x3 — куплена", "en": "⏩⏩⏩ x3 — purchased"},
	"spd_x3_buy":        {"ru": "💎 x3 НАВСЕГДА — 100 алмазов", "en": "💎 x3 FOREVER — 100 diamonds"},
	"spd_pop_x2":        {"ru": "▶ Реклама → x2 на 30 минут!", "en": "▶ Ad → x2 for 30 minutes!"},
	"spd_pop_x3":        {"ru": "⏩⏩⏩ x3 разблокирована навсегда!", "en": "⏩⏩⏩ x3 unlocked forever!"},
	"ad_bonuses":        {"ru": "📺 БОНУСЫ ЗА РЕКЛАМУ", "en": "📺 AD BONUSES"},
	"diamond_shop":      {"ru": "💎 МАГАЗИН АЛМАЗОВ", "en": "💎 DIAMOND SHOP"},
	# панель реклама-бустов
	"ad_subtitle":       {"ru": "Добровольно · 30 мин · чем больше смотришь — тем выше %", "en": "Optional · 30 min · the more you watch, the higher the %"},
	"ad_row_active":     {"ru": "▶ %s: +%d%% активен (%dмин, ур.%d) — ещё реклама → +%d%%", "en": "▶ %s: +%d%% active (%d min, lv.%d) — another ad → +%d%%"},
	"ad_row_idle":       {"ru": "▶ %s — реклама → +%d%% на 30 мин (ур.%d)", "en": "▶ %s — ad → +%d%% for 30 min (lv.%d)"},
	"ad_apply_pop":      {"ru": "📺 %s +%d%% на 30 мин!\n(уровень буста %d)", "en": "📺 %s +%d%% for 30 min!\n(boost level %d)"},
	# магазин алмазов
	"shop_title":        {"ru": "💎 МАГАЗИН АЛМАЗОВ  (есть: %d)", "en": "💎 DIAMOND SHOP  (have: %d)"},
	"shop_note":         {"ru": "(покупка за реал — подключится в сборке под Google Play / App Store)", "en": "(real-money purchase — enabled in the Google Play / App Store build)"},
	"shop_buy_pop":      {"ru": "💎 +%d (стаб покупки)", "en": "💎 +%d (purchase stub)"},
	"shop_gacha_btn":    {"ru": "🎰 ГАЧА — призыв шмота", "en": "🎰 GACHA — summon gear"},
	# гача
	"gacha_title":       {"ru": "🎰 ГАЧА — призыв снаряжения", "en": "🎰 GACHA — summon equipment"},
	"gacha_pity":        {"ru": "💎 %d   ·   до гаранта Эпического: %d пуллов", "en": "💎 %d   ·   to guaranteed Epic: %d pulls"},
	"gacha_rates":       {"ru": "Шансы: Обычный 50% · Необычный 30% · Редкий 15% · Эпический 5%\n(с 74-го пулла шанс Эпического растёт, на 90-м — гарант)", "en": "Rates: Common 50% · Uncommon 30% · Rare 15% · Epic 5%\n(from pull 74 the Epic chance rises, at 90 — guaranteed)"},
	"gacha_pull1":       {"ru": "🎲 ПУЛЛ x1 — %d 💎", "en": "🎲 PULL x1 — %d 💎"},
	"gacha_pull10":      {"ru": "🎲 ПУЛЛ x10 — %d 💎", "en": "🎲 PULL x10 — %d 💎"},
	"gacha_no_diamonds": {"ru": "Недостаточно алмазов 💎", "en": "Not enough diamonds 💎"},
	"gacha_epic":        {"ru": "🎉 ЭПИЧЕСКИЙ!", "en": "🎉 EPIC!"},
	"gacha_rare":        {"ru": "✨ Редкий!", "en": "✨ Rare!"},
	"gacha_got":         {"ru": "Выпало:", "en": "You got:"},
	"gacha_result_foot": {"ru": "(в коллекции бойцов, надень в Экипировке)", "en": "(added to fighters' collection — equip it in Gear)"},
	# квест-награда
	"quest_done":        {"ru": "✅ КВЕСТ ВЫПОЛНЕН", "en": "✅ QUEST COMPLETE"},
	"quest_looted":      {"ru": "Добыто: %s  (с босса «%s»)", "en": "Looted: %s  (from boss \"%s\")"},
	"quest_reward":      {"ru": "Награда: +150 💎  +500 🔩  +  ПУШКА НА ВЫБОР ↓", "en": "Reward: +150 💎  +500 🔩  +  CHOOSE A WEAPON ↓"},
	"quest_pick":        {"ru": "🔫 Выбери пушку одному бойцу (рарность рандом):", "en": "🔫 Choose a weapon for one fighter (random rarity):"},
	"quest_weapon_btn":  {"ru": "%s  %s — пушка", "en": "%s  %s — weapon"},
	"quest_weapon_granted": {"ru": "🔫 Пушка выдана!", "en": "🔫 Weapon granted!"},
	"quest_contact_default": {"ru": "📡 Связной", "en": "📡 Contact"},
	# farm-эхо: район реагирует на прошлые моральные решения
	"echo_slums_b": {"ru": "⚠️ Импланты, что ты толкнул, вернулись психами. Твоя работа.", "en": "⚠️ The implants you pushed came back as psychos. Your doing."},
	"echo_slums_a": {"ru": "Психов в трущобах поубавилось. Крыс всё ещё дуется.", "en": "Fewer psychos in the Slums now. Rat's still sulking."},
	"echo_corp_b":  {"ru": "Корпа узнаёт твоё лицо. Охраны больше.", "en": "The corpo recognizes your face. More guards."},
	"echo_docks_a": {"ru": "⚓ Боцман кивает тебе как своему. Лояльность бесплатно.", "en": "⚓ The Bosun nods to you like one of his own. Loyalty for free."},
}
func _t(k: String) -> String:
	var e: Dictionary = TR.get(k, {})
	return str(e.get(lang, e.get("ru", k)))
# локализованное поле контент-словаря: _tloc(a,"name") → name_en при EN, иначе name
func _tloc(d: Dictionary, key: String) -> String:
	if lang == "en": return str(d.get(key + "_en", d.get(key, "")))
	return str(d.get(key, ""))
# локализованное имя бойца по индексу класса (порядок HEROES: снайп/штурм/танк/хакер)
const HERO_NAME_KEYS := ["hero_snipe", "hero_assault", "hero_tank", "hero_hacker"]
func _hname(i: int) -> String:
	if i >= 0 and i < HERO_NAME_KEYS.size(): return _t(HERO_NAME_KEYS[i])
	return str(HEROES[i]["name"]) if i >= 0 and i < HEROES.size() else ""
# локализованное имя редкости (ru/en) по индексу 0..4
func _rarity_name(i: int) -> String:
	if i < 0 or i >= RARITY.size(): return ""
	return _tloc(RARITY[i], "name")
func _fb_init() -> void:
	if not OS.has_feature("web"): return
	var js := """
	if(!window._fbStart){window._fbStart=true;window._fbUid='';window._fbErr='';
	var c={apiKey:'AIzaSyBPwusg9hSB8k76Uox5DeRLJ6Sb6M3Y3mk',authDomain:'cyber-auto-rpg.firebaseapp.com',databaseURL:'%s',projectId:'cyber-auto-rpg',storageBucket:'cyber-auto-rpg.firebasestorage.app',messagingSenderId:'448585153975',appId:'1:448585153975:web:b699058f1413a61aa63c32'};
	function L(u,cb){var s=document.createElement('script');s.src=u;s.onload=cb;s.onerror=function(){window._fbErr='load '+u;};document.head.appendChild(s);}
	L('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js',function(){
	 L('https://www.gstatic.com/firebasejs/10.12.0/firebase-auth-compat.js',function(){
	  L('https://www.gstatic.com/firebasejs/10.12.0/firebase-database-compat.js',function(){
	   try{firebase.initializeApp(c);firebase.auth().signInAnonymously().then(function(r){window._fbUid=r.user.uid;}).catch(function(e){window._fbErr=String(e);});}catch(e){window._fbErr=String(e);}
	  });});});}
	""" % FB_DB_URL
	JavaScriptBridge.eval(js, true)

# === QA-МОСТ ЛОКАЛИЗАЦИИ: открыть любую панель командой из JS (window._qa="имя") — для скрин-сканера языков ===
func _qa_poll() -> void:
	if bot or not OS.has_feature("web"): return
	var cmd = JavaScriptBridge.eval("window._qa||''", true)
	if typeof(cmd) != TYPE_STRING or cmd == "": return
	JavaScriptBridge.eval("window._qa=''", true)
	cmd = str(cmd)
	if cmd == "close":
		for c in hud.get_children():
			if c is Control and c.z_index >= 2500: c.queue_free()
		if settings_panel: settings_panel.visible = false
		return
	if cmd == "lang":
		lang = ("en" if lang == "ru" else "ru"); _apply_lang(); return
	var m := {
		"upgrade": "_toggle_inv", "gear": "_toggle_impl", "prestige": "_toggle_reboot",
		"singularity": "_open_singularity", "settings": "_toggle_settings", "stats": "_toggle_stats",
		"clan": "_open_clan", "clanboss": "_open_clan_boss", "clanchat": "_open_clan_chat", "clanshop": "_open_clan_shop",
		"speed": "_open_speed_menu", "ads": "_open_ad_boosts", "shop": "_open_shop", "gacha": "_open_gacha",
		"map": "_open_map", "daily": "_open_daily_quests", "messages": "_open_messages",
		"dossier": "_open_dossier", "case": "_open_case", "finale": "_open_finale",
		"battlepass": "_open_battlepass", "achievements": "_open_achievements",
	}
	if m.has(cmd) and has_method(m[cmd]): call(m[cmd])

func _fb_poll(delta: float) -> void:
	if fb_ready or bot or not OS.has_feature("web"): return
	fb_t -= delta
	if fb_t > 0.0: return
	fb_t = 1.0
	var uid = JavaScriptBridge.eval("window._fbUid||''", true)
	if typeof(uid) == TYPE_STRING and uid != "":
		fb_uid = uid
		fb_id = "#%06d" % (abs(hash(uid)) % 1000000)
		fb_ready = true
		print("FB ready uid=%s id=%s" % [fb_uid, fb_id])
		_fb_write_profile()

# REST к Realtime DB (test mode = открыто, токен не нужен). Метод HTTPClient.METHOD_*
func _fb_rest(method: int, path: String, body: String, cb: Callable = Callable()) -> void:
	if not OS.has_feature("web"): return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, code, _h, data):
		if http.is_inside_tree(): http.queue_free()
		if cb.is_valid(): cb.call(int(code), data.get_string_from_utf8()))
	var headers := PackedStringArray(["Content-Type: application/json"])
	http.request(FB_DB_URL + path + ".json", headers, method, body)

func _fb_write_profile() -> void:
	if fb_uid == "": return
	var prof := {"id": fb_id, "nick": (nick if nick != "" else "Вектор"), "power": power_peak, "best": best_stage, "clan": player_clan, "t": Time.get_unix_time_from_system()}
	_fb_rest(HTTPClient.METHOD_PUT, "/players/%s" % fb_uid, JSON.stringify(prof))

func _clan_name() -> String: return (nick if nick != "" else "Вектор")

# ник для ПОКАЗА: гостевой плейсхолдер локализуем под текущий язык (в сейве он хранится литералом «гость»/«guest»)
func _disp_nick() -> String:
	if nick == "" or nick == "гость" or nick == "guest": return _t("guest_nick")
	return nick

func _clan_create() -> void:
	if not fb_ready:
		_popup_center(_t("cl_no_server"), Color("#ff5050"), 2.0); return
	var code := "%06d" % (randi() % 1000000)
	var clan := {"name": _t("clan_name_prefix") + _clan_name(), "leader": fb_uid, "members": {fb_uid: {"nick": _clan_name(), "power": power_peak}}, "created": int(Time.get_unix_time_from_system())}
	_fb_rest(HTTPClient.METHOD_PUT, "/clans/%s" % code, JSON.stringify(clan), func(c, _d):
		if c >= 200 and c < 300:
			player_clan = code; _fb_write_profile(); _save()
			_popup_center(_t("cl_created") % code, Color("#7ee08a"), 3.0)
		else:
			_popup_center(_t("cl_err_create") % c, Color("#ff5050"), 2.0))

func _clan_join(code: String) -> void:
	if not fb_ready:
		_popup_center(_t("cl_no_server_j"), Color("#ff5050"), 2.0); return
	if code.length() != 6:
		_popup_center(_t("cl_code_6d"), Color("#ff5050"), 2.0); return
	_fb_rest(HTTPClient.METHOD_GET, "/clans/%s" % code, "", func(_c, d):
		var clan = JSON.parse_string(d)
		if typeof(clan) != TYPE_DICTIONARY:
			_popup_center(_t("cl_not_found") % code, Color("#ff5050"), 2.2); return
		var members: Dictionary = clan.get("members", {})
		if members.size() >= 20:
			_popup_center(_t("cl_full"), Color("#ff5050"), 2.2); return
		_fb_rest(HTTPClient.METHOD_PATCH, "/clans/%s/members" % code, JSON.stringify({fb_uid: {"nick": _clan_name(), "power": power_peak}}), func(c2, _d2):
			if c2 >= 200 and c2 < 300:
				player_clan = code; _fb_write_profile(); _save()
				_popup_center(_t("cl_joined") % code, Color("#7ee08a"), 3.0)
			else:
				_popup_center(_t("cl_err_join") % c2, Color("#ff5050"), 2.0)))

func _clan_leave() -> void:
	if player_clan == "": return
	_fb_rest(HTTPClient.METHOD_DELETE, "/clans/%s/members/%s" % [player_clan, fb_uid], "")
	player_clan = ""; _fb_write_profile(); _save()
	_popup_center(_t("cl_left"), Color("#9aa0b5"), 1.8)

func _clbl(txt: String, y: int, col := Color("#cfe6ff"), sz := 14) -> Label:
	var l := _lbl(txt, sz, col, HORIZONTAL_ALIGNMENT_CENTER); l.position = Vector2(0, y); l.size = Vector2(W, 24)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _clan_close_btn(panel: Control) -> void:
	var close := Button.new(); close.text = _t("close"); close.custom_minimum_size = Vector2(200, 40)
	close.position = Vector2(W * 0.5 - 100, 770); close.pressed.connect(panel.queue_free); panel.add_child(close)

func _open_clan() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3500; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.9); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var t := _lbl(_t("cl_title"), 22, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER); t.position = Vector2(0, 100); t.size = Vector2(W, 30); panel.add_child(t)
	if not OS.has_feature("web"):
		panel.add_child(_clbl(_t("cl_web_only"), 150)); _clan_close_btn(panel); return
	if not fb_ready:
		panel.add_child(_clbl(_t("cl_connecting"), 160)); _clan_close_btn(panel); return
	panel.add_child(_clbl(_t("cl_my_id") % [fb_id, _disp_nick()], 144))
	panel.add_child(_clbl(_t("cl_peak") % [_gsep(power_peak), _gsep(clan_tokens)], 170, Color("#ffd24a")))
	if player_clan == "":
		panel.add_child(_clbl(_t("cl_no_clan"), 210))
		var bc := Button.new(); bc.text = _t("cl_create_btn"); bc.custom_minimum_size = Vector2(280, 48); bc.position = Vector2(W * 0.5 - 140, 252)
		bc.pressed.connect(func(): _clan_create(); panel.queue_free(); await get_tree().create_timer(0.9).timeout; _open_clan())
		panel.add_child(bc)
		panel.add_child(_clbl(_t("cl_or_join"), 322))
		var inp := LineEdit.new(); inp.placeholder_text = _t("cl_code_ph"); inp.max_length = 6; inp.alignment = HORIZONTAL_ALIGNMENT_CENTER
		inp.custom_minimum_size = Vector2(170, 44); inp.position = Vector2(W * 0.5 - 145, 356); inp.add_theme_font_size_override("font_size", 18)
		panel.add_child(inp)
		var bj := Button.new(); bj.text = _t("cl_join_btn"); bj.custom_minimum_size = Vector2(120, 44); bj.position = Vector2(W * 0.5 + 40, 356)
		bj.pressed.connect(func(): _clan_join(inp.text.strip_edges()); panel.queue_free(); await get_tree().create_timer(1.0).timeout; _open_clan())
		panel.add_child(bj)
	else:
		panel.add_child(_clbl(_t("cl_code_label") % player_clan, 212, Color("#ffd24a"), 19))
		panel.add_child(_clbl(_t("cl_share_code"), 242))
		var ml := _clbl(_t("cl_loading_members"), 290); ml.size = Vector2(W, 240); panel.add_child(ml)
		_fb_rest(HTTPClient.METHOD_GET, "/clans/%s" % player_clan, "", func(_c, d):
			if not is_instance_valid(ml): return
			var clan = JSON.parse_string(d)
			if typeof(clan) != TYPE_DICTIONARY: ml.text = _t("cl_disbanded"); return
			var mem: Dictionary = clan.get("members", {})
			var txt := _t("cl_members") % mem.size()
			for u in mem:
				var m = mem[u]
				txt += "• %s — ⚡%s%s\n" % [str(m.get("nick", "?")), _gsep(int(m.get("power", 0))), ("  👑" if str(clan.get("leader", "")) == str(u) else "")]
			ml.text = txt)
		var bb := Button.new(); bb.text = _t("cl_boss_btn"); bb.custom_minimum_size = Vector2(280, 48); bb.position = Vector2(W * 0.5 - 140, 540)
		bb.add_theme_font_size_override("font_size", 18)
		bb.pressed.connect(func(): panel.queue_free(); _open_clan_boss())
		panel.add_child(bb)
		var bch := Button.new(); bch.text = _t("cl_chat_btn"); bch.custom_minimum_size = Vector2(280, 44); bch.position = Vector2(W * 0.5 - 140, 596)
		bch.add_theme_font_size_override("font_size", 17)
		bch.pressed.connect(func(): panel.queue_free(); _open_clan_chat())
		panel.add_child(bch)
		var bshop := Button.new(); bshop.text = _t("cls_btn"); bshop.custom_minimum_size = Vector2(280, 44); bshop.position = Vector2(W * 0.5 - 140, 648)
		bshop.add_theme_font_size_override("font_size", 17); bshop.add_theme_color_override("font_color", Color("#ffd24a"))
		bshop.pressed.connect(func(): panel.queue_free(); _open_clan_shop())
		panel.add_child(bshop)
		var bl := Button.new(); bl.text = _t("cl_leave_btn"); bl.custom_minimum_size = Vector2(200, 40); bl.position = Vector2(W * 0.5 - 100, 700)
		bl.pressed.connect(func(): _clan_leave(); panel.queue_free(); await get_tree().create_timer(0.6).timeout; _open_clan())
		panel.add_child(bl)
	_clan_close_btn(panel)

# === КЛАН-БОСС: общий HP = hpMax − сумма вкладов (без гонки, каждый пишет свой узел) ===
func _clan_boss_spawn() -> void:
	if player_clan == "" or not fb_ready: return
	var wb := _weekly_boss()
	var hpmax: int = max(100000, power_peak * 1000)  # ~1000 hits to kill: 20min solo / 4min clan-of-5 (bot ppwr peak ~940M → ~940B boss HP)
	_fb_rest(HTTPClient.METHOD_PUT, "/clans/%s/boss" % player_clan, JSON.stringify({"hpMax": hpmax, "started": int(Time.get_unix_time_from_system()), "name": wb["name"], "fac": wb["fac"], "week": _week_num()}), func(c, _d):
		if c >= 200 and c < 300:
			boss_my_dmg = 0
			_popup_center(_t("cl_boss_summoned") % wb["name"], Color("#ff2d95"), 2.8))

func _clan_boss_attack() -> void:
	if player_clan == "" or not fb_ready or boss_atk_cd > 0.0: return
	boss_atk_cd = 1.2
	var hit: int = max(1, int(power_peak * randf_range(0.8, 1.4)))
	boss_my_dmg += hit
	_fb_rest(HTTPClient.METHOD_PUT, "/clans/%s/boss/contrib/%s" % [player_clan, fb_uid], JSON.stringify({"nick": _clan_name(), "dmg": boss_my_dmg}))
	_popup_center(_t("cl_boss_hit") % _gsep(hit), Color("#ff5050"), 0.9)

func _open_clan_boss() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3600; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.92); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	panel.add_child(_clbl(_t("cl_boss_title"), 96, Color("#ff2d95"), 22))
	var info := _clbl(_t("cl_loading"), 140); info.size = Vector2(W, 24); panel.add_child(info)
	# HP-бар
	var barbg := ColorRect.new(); barbg.color = Color(0.1, 0.05, 0.08, 1); barbg.position = Vector2(W * 0.5 - 200, 180); barbg.size = Vector2(400, 30); panel.add_child(barbg)
	var barfill := ColorRect.new(); barfill.color = Color("#ff2d95"); barfill.position = Vector2(W * 0.5 - 200, 180); barfill.size = Vector2(0, 30); panel.add_child(barfill)
	var hplbl := _clbl("", 216, Color("#ffd24a")); panel.add_child(hplbl)
	var lead := _clbl(_t("cl_loading"), 260); lead.size = Vector2(W, 300); panel.add_child(lead)
	var refresh := func():
		if not is_instance_valid(panel): return
		_fb_rest(HTTPClient.METHOD_GET, "/clans/%s/boss" % player_clan, "", func(_c, d):
			if not is_instance_valid(panel): return
			var boss = JSON.parse_string(d)
			if typeof(boss) != TYPE_DICTIONARY:
				info.text = _t("cl_no_boss"); hplbl.text = ""; lead.text = ""; barfill.size = Vector2(0, 30); return
			var hpmax: int = int(boss.get("hpMax", 1))
			var contrib: Dictionary = boss.get("contrib", {})
			if contrib.has(fb_uid): boss_my_dmg = max(boss_my_dmg, int(contrib[fb_uid].get("dmg", 0)))   # синк своего вклада из БД (реоткрытие не обнулит)
			var total := 0
			var ranked := []
			for u in contrib:
				var dm := int(contrib[u].get("dmg", 0))
				total += dm
				ranked.append([str(contrib[u].get("nick", "?")), dm])
			var hp: int = max(0, hpmax - total)
			barfill.size = Vector2(400.0 * float(hp) / float(max(1, hpmax)), 30)
			hplbl.text = "HP: %s / %s" % [_gsep(hp), _gsep(hpmax)]
			var bname := str(boss.get("name", _t("cl_boss_default_name")))
			if hp <= 0:
				info.text = _t("cl_boss_killed") % bname
				var bstarted := int(boss.get("started", 0))
				if bstarted != boss_claimed and total > 0 and boss_my_dmg > 0:   # награда один раз с этого босса, по вкладу
					boss_claimed = bstarted
					var share := float(boss_my_dmg) / float(total)
					var dia: int = clampi(int(round(50.0 * share)) + 5, 5, 50)   # скромные алмазы (5-50, не вредят монетизации)
					var tok: int = int(round(800.0 * share)) + 50               # клан-жетоны щедро
					diamonds += dia; clan_tokens += tok; _save(); _refresh_hud()
					_popup_center(_t("cl_boss_reward") % [dia, tok], Color("#7ee08a"), 3.6)
			else:
				info.text = "%s\n%s" % [bname, _loc_fac(str(boss.get("fac", _t("cl_boss_fac_default"))))]
			ranked.sort_custom(func(a, b): return a[1] > b[1])
			var lt := _t("cl_leaderboard")
			for i in min(ranked.size(), 8):
				lt += "%d. %s — ⚔%s\n" % [i + 1, ranked[i][0], _gsep(ranked[i][1])]
			lead.text = lt)
	refresh.call()
	# кнопка призыва (если босса нет) + бить
	panel.add_child(_clbl(_t("cl_boss_weekly") % _weekly_boss()["name"], 124, Color("#ff9a3c"), 13))
	var bspawn := Button.new(); bspawn.text = _t("cl_spawn_btn"); bspawn.custom_minimum_size = Vector2(260, 44); bspawn.position = Vector2(W * 0.5 - 130, 600)
	bspawn.pressed.connect(func(): _clan_boss_spawn(); await get_tree().create_timer(1.0).timeout; refresh.call())
	panel.add_child(bspawn)
	var batk := Button.new(); batk.text = _t("cl_atk_btn"); batk.custom_minimum_size = Vector2(260, 56); batk.position = Vector2(W * 0.5 - 130, 540); batk.add_theme_font_size_override("font_size", 22)
	batk.pressed.connect(func(): _clan_boss_attack(); await get_tree().create_timer(0.5).timeout; refresh.call())
	panel.add_child(batk)
	# авто-обновление HP-бара каждые 3с (realtime ощущение)
	var tmr := Timer.new(); tmr.wait_time = 3.0; tmr.autostart = true; panel.add_child(tmr)
	tmr.timeout.connect(func(): refresh.call())
	_clan_close_btn(panel)

# === ЧАТ КЛАНА: сообщения в /clans/<код>/chat (push), опрос каждые 3с ===
func _clan_chat_send(txt: String) -> void:
	var t := txt.strip_edges()
	if player_clan == "" or not fb_ready or t == "": return
	_fb_rest(HTTPClient.METHOD_POST, "/clans/%s/chat" % player_clan, JSON.stringify({"nick": _clan_name(), "text": t.substr(0, 200), "t": int(Time.get_unix_time_from_system())}))

func _open_clan_chat() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3600; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.93); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	panel.add_child(_clbl(_t("cl_chat_title") % player_clan, 96, Color("#00f0ff"), 20))
	var box := ColorRect.new(); box.color = Color(0.06, 0.07, 0.1, 0.95); box.position = Vector2(W * 0.5 - 250, 140); box.size = Vector2(500, 560); panel.add_child(box)
	var msgs := _clbl(_t("cl_loading"), 152); msgs.position = Vector2(W * 0.5 - 240, 152); msgs.size = Vector2(480, 540)
	msgs.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM; msgs.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT; panel.add_child(msgs)
	var refresh := func():
		if not is_instance_valid(panel): return
		_fb_rest(HTTPClient.METHOD_GET, "/clans/%s/chat" % player_clan, "", func(_c, d):
			if not is_instance_valid(msgs): return
			var ch = JSON.parse_string(d)
			if typeof(ch) != TYPE_DICTIONARY: msgs.text = _t("cl_chat_empty"); return
			var keys: Array = ch.keys(); keys.sort()
			var start: int = max(0, keys.size() - 18)
			var txt := ""
			for i in range(start, keys.size()):
				var m = ch[keys[i]]
				txt += "%s: %s\n" % [str(m.get("nick", "?")), str(m.get("text", ""))]
			msgs.text = txt)
	refresh.call()
	var inp := LineEdit.new(); inp.placeholder_text = _t("cl_chat_ph"); inp.max_length = 200
	inp.custom_minimum_size = Vector2(360, 44); inp.position = Vector2(W * 0.5 - 250, 712); inp.add_theme_font_size_override("font_size", 15); panel.add_child(inp)
	var send := func():
		if inp.text.strip_edges() == "": return
		_clan_chat_send(inp.text); inp.text = ""
		await get_tree().create_timer(0.6).timeout; refresh.call()
	var bs := Button.new(); bs.text = "▶"; bs.custom_minimum_size = Vector2(80, 44); bs.position = Vector2(W * 0.5 + 120, 712); bs.add_theme_font_size_override("font_size", 20)
	bs.pressed.connect(func(): send.call()); panel.add_child(bs)
	inp.text_submitted.connect(func(_t): send.call())
	var tmr := Timer.new(); tmr.wait_time = 3.0; tmr.autostart = true; panel.add_child(tmr)
	tmr.timeout.connect(func(): refresh.call())
	_clan_close_btn(panel)

func _open_clan_shop() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3500; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.88); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.06, 0.15, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#ffd24a"); sb.set_border_width_all(2); sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 210, 80); card.custom_minimum_size = Vector2(420, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); card.add_child(v)
	v.add_child(_lbl(_t("cls_title"), 20, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("cls_balance") % clan_tokens, 15, Color("#aaa0ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var boost_items := [
		{"key": "dmg",  "cost": 200, "name_ru": "⚔ Урон отряда",    "name_en": "⚔ Team Damage",   "pct": 40},
		{"key": "gold", "cost": 150, "name_ru": "💰 Золото и лом",   "name_en": "💰 Gold & Scrap",  "pct": 100},
		{"key": "atk",  "cost": 150, "name_ru": "⚡ Скорость атаки", "name_en": "⚡ Attack Speed",  "pct": 25},
	]
	for item in boost_items:
		var bk: String = item["key"]
		var cost: int = item["cost"]
		var pct: int = item["pct"]
		var bname: String = item["name_" + lang]
		var row := Button.new(); row.custom_minimum_size = Vector2(0, 60); row.add_theme_font_size_override("font_size", 14)
		if _clan_boost_active(bk):
			var mins := int((float(clan_boosts[bk]["until"]) - Time.get_unix_time_from_system()) / 60.0)
			row.text = "%s +%d%%\n%s" % [bname, pct, _t("cls_active") % mins]
			row.add_theme_color_override("font_color", Color("#3ad97a"))
		else:
			row.text = ("%s\n+%d%% " + _t("cls_for_30min") + "  —  %d🎖") % [bname, pct, cost]
		row.pressed.connect(func():
			if clan_tokens < cost:
				_popup_center(_t("cls_no_tokens"), Color("#ff4444"), 1.5); return
			clan_tokens -= cost
			clan_boosts[bk] = {"until": Time.get_unix_time_from_system() + 1800.0}
			for hh in heroes: _recalc_hero(hh)
			_save(); _refresh_hud()
			_popup_center(_t("cls_bought"), Color("#ffd24a"), 1.5)
			panel.queue_free(); _open_clan_shop())
		v.add_child(row)
	var sep := HSeparator.new(); v.add_child(sep)
	for pack in [[30, 300], [100, 900]]:
		var amt: int = pack[0]; var cost2: int = pack[1]
		var pd := Button.new()
		pd.text = "💎 %d %s  —  %d🎖" % [amt, ("алмазов" if lang == "ru" else "diamonds"), cost2]
		pd.custom_minimum_size = Vector2(0, 50); pd.add_theme_font_size_override("font_size", 15)
		pd.add_theme_color_override("font_color", Color("#ffd24a"))
		pd.pressed.connect(func():
			if clan_tokens < cost2:
				_popup_center(_t("cls_no_tokens"), Color("#ff4444"), 1.5); return
			clan_tokens -= cost2; diamonds += amt; _save(); _refresh_hud()
			_popup_center("💎 +%d  %s" % [amt, _t("cls_bought")], Color("#ffd24a"), 1.5)
			panel.queue_free(); _open_clan_shop())
		v.add_child(pd)
	var bc := Button.new(); bc.text = _t("close"); bc.custom_minimum_size = Vector2(0, 40); bc.pressed.connect(func(): panel.queue_free())
	v.add_child(bc)

# нарративный пульс фарма (анти-выгорание): редкие реплики мира/Сигнала во время гринда
const PULSE_LINES := [
	"📡 Сигнал: «…всё ещё слышу тебя. Не оборачивайся.»",
	"🗞 Сеть: «ZenoCore отрицает связь субсидий с волной психоза.»",
	"🐀 Крыс: «Ты там живой? В трущобах опять психи буянят.»",
	"📡 Сигнал: «Эти девять секунд… я тоже в них застрял. С тобой.»",
	"🗞 Сеть: «Ещё один киберпсихоз в районе. Власти молчат.»",
	"📡 Сигнал: «Чем глубже идёшь — тем громче я. Тебе не страшно?»",
]
const PULSE_LINES_EN := [
	"📡 Signal: «…I still hear you. Don't look back.»",
	"🗞 Net: «ZenoCore denies any link between subsidies and the psychosis wave.»",
	"🐀 Rat: «You alive out there? The slums are going wild again.»",
	"📡 Signal: «Those nine seconds… I got stuck in them too. With you.»",
	"🗞 Net: «Another cyberpsychosis incident in the district. Authorities silent.»",
	"📡 Signal: «The deeper you go, the louder I get. Aren't you scared?»",
]
const PULSE_SOLVED := [
	"📡 Сигнал: «Теперь ты знаешь. И всё равно слушаешь меня. Почему?»",
	"📡 Сигнал: «Я — не Тэо. Я half of you. Половина, которую вырезали.»",
	"🗞 Сеть: «Утечка: прототип PHANTOM-LIMB тестили на курьерах ZenoCore.»",
]
const PULSE_SOLVED_EN := [
	"📡 Signal: «Now you know. And you still listen to me. Why?»",
	"📡 Signal: «I am not Teo. I am half of you. The half they cut out.»",
	"🗞 Net: «Leak: PHANTOM-LIMB prototype was tested on ZenoCore couriers.»",
]
var pulse_t := 0.0
var pulse_idx := 0
# === 3 ФИНАЛА (эндгейм-режимы) — по карме после прохождения всех 4 актов ===
const ENDINGS := {
	"quiet": {"name": "Тихий протокол", "name_en": "Quiet Protocol", "icon": "🕊",
	          "text": "Ты щадил тех, кого мог. ZenoCore замяла скандал, но трущобы дышат свободнее. Ты выбираешь тишину — фарм без войны. PHANTOM-LIMB молчит… почти.",
	          "text_en": "You spared those you could. ZenoCore buried the scandal, but the slums breathe easier. You choose silence — farming without war. PHANTOM-LIMB is quiet… almost.",
	          "pulse": ["🕊 Тихо. Слишком тихо. Сигнал почти не говорит.", "🗞 Ева Кван: «Прогресс не остановить. Но сегодня — меньше крови.»"],
	          "pulse_en": ["🕊 Silence. Too much silence. Signal barely speaks now.", "🗞 Eva Kwan: «Progress can't be stopped. But today — less blood.»"]},
	"wild":  {"name": "Открытый канал", "name_en": "Open Channel", "icon": "🔥",
	          "text": "Ты сжёг мосты и выставил счёт. Сеть знает твоё имя — на тебя открыта охота. Дикий эндшпиль: баунти, перехваты, никакой пощады.",
	          "text_en": "You burned your bridges and settled the score. The net knows your name — there's a hunt open on you. Wild endgame: bounties, intercepts, no mercy.",
	          "pulse": ["🔥 Перехват: за твою голову подняли цену.", "📡 Сеть кипит. Все хотят кусок Вектора."],
	          "pulse_en": ["🔥 Intercept: the bounty on your head just went up.", "📡 The net is boiling. Everyone wants a piece of Vector."]},
	"grey":  {"name": "Серый путь", "name_en": "Grey Path", "icon": "🧠",
	          "text": "Ты не уничтожил и не освободил — ты впустил. PHANTOM-LIMB остаётся в голове: комментирует, иногда врёт, иногда помогает. Кооп-в-голове — вы двое, навсегда.",
	          "text_en": "You didn't destroy it and didn't free it — you let it in. PHANTOM-LIMB stays in your head: commenting, sometimes lying, sometimes helping. Co-op-in-your-head — the two of you, forever.",
	          "pulse": ["🧠 PHANTOM-LIMB: «Левее. Доверься. …или нет. Решай.»", "🧠 PHANTOM-LIMB: «Мы половинки. Я не уйду — и ты это знаешь.»"],
	          "pulse_en": ["🧠 PHANTOM-LIMB: «Left. Trust me. …or don't. You decide.»", "🧠 PHANTOM-LIMB: «We're two halves. I'm not leaving — and you know it.»"]},
}
var endgame_mode := ""
func _all_quests_done() -> bool:
	for loc in LOCATIONS:
		if not (str(loc["id"]) in quest_done): return false
	return true
func _frag_unlocked(i: int) -> bool: return max(best_stage, stage) >= int(FRAGMENTS[i]["unlock"])
func _farm_pulse() -> void:
	var pool: Array
	if endgame_mode != "" and ENDINGS.has(endgame_mode):
		var e: Dictionary = ENDINGS[endgame_mode]
		pool = e.get("pulse_en" if lang == "en" else "pulse", e.get("pulse", []))
	elif case_solved: pool = PULSE_SOLVED_EN if lang == "en" else PULSE_SOLVED
	else: pool = PULSE_LINES_EN if lang == "en" else PULSE_LINES
	_popup_center(str(pool[pulse_idx % pool.size()]), Color("#9ad0ff"), 3.0)
	pulse_idx += 1
func _frags_open() -> int:
	var n := 0
	for i in FRAGMENTS.size():
		if _frag_unlocked(i): n += 1
	return n

func _loc() -> Dictionary: return LOCATIONS[clamp(cur_location, 0, LOCATIONS.size() - 1)]

func _enemy_pool() -> Array:
	# враги = типы локации, гейтнутые по стадии (чтоб на ранней не вылезли все сразу)
	var gate := {"grunt": 1, "swift": 2, "armor": 4, "swarm": 6, "archer": 7, "bomber": 9, "healer": 11, "shield": 14}
	var pool := []
	for t in _loc()["pool"]:
		if stage >= int(gate.get(t, 1)): pool.append(t)
	if pool.is_empty(): pool.append("grunt")
	return pool
# === ПРЕСТИЖ-АУГМЕНТЫ (LOOT-RULES §12): детерминированный выбор, перма-множители ===
const AUGMENTS := [
	{"id": "neuro", "icon": "🧬", "name": "Нейросеть-протокол", "name_en": "Neuralnet Protocol", "stat": "core", "per": 0.15, "desc": "+15%/ур к приходу ЯДЕР"},
	{"id": "qcore", "icon": "🔮", "name": "Квантовое ядро", "name_en": "Quantum Core", "stat": "core", "per": 0.10, "desc": "+10%/ур к приходу ЯДЕР"},
	{"id": "coproc", "icon": "🗲", "name": "Боевой ко-процессор", "name_en": "Combat Coprocessor", "stat": "dmg", "per": 0.12, "desc": "+12%/ур урон всему отряду"},
	{"id": "blade", "icon": "🔪", "name": "Перегрузочный клинок", "name_en": "Overload Blade", "stat": "dmg", "per": 0.10, "desc": "+10%/ур урон всему отряду"},
	{"id": "oclock", "icon": "♨", "name": "Разгон ядра", "name_en": "Core Overclock", "stat": "dmg", "per": 0.08, "desc": "+8%/ур урон всему отряду"},
	{"id": "reactor", "icon": "🛡", "name": "Перегрузка реактора", "name_en": "Reactor Overload", "stat": "hp", "per": 0.10, "desc": "+10%/ур HP отряду"},
	{"id": "armor", "icon": "🧱", "name": "Композитная броня", "name_en": "Composite Armor", "stat": "hp", "per": 0.08, "desc": "+8%/ур HP отряду"},
	{"id": "scope", "icon": "✷", "name": "Оптический прицел", "name_en": "Optical Scope", "stat": "crit", "per": 0.02, "desc": "+2%/ур шанс крита"},
	{"id": "snchip", "icon": "🎯", "name": "Снайпер-чип", "name_en": "Sniper Chip", "stat": "crit", "per": 0.015, "desc": "+1.5%/ур шанс крита"},
	{"id": "burst", "icon": "💥", "name": "Разрывные импланты", "name_en": "Explosive Implants", "stat": "critx", "per": 0.11, "desc": "+11%/ур множитель крит-урона"},
	{"id": "hyper", "icon": "⚙", "name": "Гиперпривод", "name_en": "Hyperdrive", "stat": "atk", "per": 0.11, "desc": "+11%/ур скорость атаки"},
	{"id": "turbo", "icon": "🌀", "name": "Турбо-сервы", "name_en": "Turbo Servos", "stat": "atk", "per": 0.09, "desc": "+9%/ур скорость атаки"},
	{"id": "miner", "icon": "💰", "name": "Майнинг-демон", "name_en": "Mining Daemon", "stat": "gold", "per": 0.15, "desc": "+15%/ур золото и лом"},
	{"id": "scrapc", "icon": "♻", "name": "Скрап-коллектор", "name_en": "Scrap Collector", "stat": "gold", "per": 0.10, "desc": "+10%/ур золото и лом"},
	{"id": "exploit", "icon": "⏱", "name": "Эксплойт ядра", "name_en": "Core Exploit", "stat": "ultcd", "per": 0.04, "desc": "−4%/ур КД ульт"},
	{"id": "recoil", "icon": "🔁", "name": "Контур перезаряда", "name_en": "Reload Circuit", "stat": "ultcd", "per": 0.03, "desc": "−3%/ур КД ульт"},
	{"id": "reflex", "icon": "⚡", "name": "Рефлекс-усилитель", "name_en": "Reflex Booster", "stat": "qte", "per": 0.06, "desc": "+0.06с/ур окно QTE"},
	{"id": "sweep", "icon": "👾", "name": "Эксплойт зачистки", "name_en": "Cleanup Exploit", "stat": "density", "per": 0.04, "desc": "−4%/ур HP врагов"},
]
var impl_sel := 0          # выбранный боец (для окна сравнения)
var impl_grid := []        # ячейки сетки 4×3: на бойца {hpl, wbtn,wlbl,wsb, mbtn,mlbl,msb}
var new_gear := {}         # "героIdx:slot" → true: непросмотренная новая шмотка (подсветка NEW)
var impl_hero_btns := []   # кнопки-портреты переключения бойца
# СКЕЛЕТ-РАСКЛАДКА: слоты имплантов+оружие на неон-силуэте тела (по анатомии)
var impl_slots := {}       # key -> {btn, sb(стиль рамки), star(★+дубли); weapon ещё ic}
var impl_seln := "core"    # выбранный слот
var impl_selv := ""        # выбранная модель (variant id) для прокачки
var dry_streak := 0        # дропов подряд без редкого (≥3) — bad-luck protection
var scrap := 0             # ♻ ЛОМ: валюта с разбора шмота → реролл статов
# ПРЕСТИЖ:
var cores := 0            # 🧬 ЯДРА — валюта престижа (трата на аугменты)
var cores_total := 0.0    # сумма ВСЕХ добытых ядер за всё время → перма-множитель (√-петля AdCap-стиля, unbounded драйвер бесконечной прогрессии)
const PERMA_TAIL_K := 0.010   # ХВОСТ БЕСКОНЕЧНОСТИ: exp-добавка сверх полинома при больших cores_total (калибруется ботами). Полином асимптотит против экспоненты HP-стены → нужен супер-полиномиальный хвост
func _prestige_mult() -> float:   # вечно растущий множитель: полином (ранняя игра, баланс сохранён) × exp-хвост (бесконечность на глубине, бьёт стену 1.34^ст)
	var poly := pow(1.0 + cores_total, 0.6)
	var tail := exp(PERMA_TAIL_K * max(0.0, sqrt(cores_total) - 100.0))  # cores_total>10k → exp(K·√) растёт быстрее ЛЮБОГО полинома → НЕТ плато; √ внутри = мягко (не взрыв), reach D нужно ~D^1.25 престижей (soft-wall, «лезешь но потеешь»)
	return poly * tail
# === МОНЕТИЗАЦИЯ (Фаза А) ===
var diamonds := 999999    # 💎 АЛМАЗЫ — премиум (ВРЕМЕННО: всем 999999 для теста монетизации — Рамиль)
var x3_unlocked := false  # x3-скорость куплена навсегда (за алмазы)
var x2_until := 0.0       # x2-скорость активна до этого ticks_msec/1000 (выдаётся за рекламу, таймер)
# РЕКЛАМА-БУСТЫ (Диана): добровольные, 30 мин, % растёт с числом просмотров. ad_boosts[b] = {"until":sec, "lvl":int}
var ad_boosts := {}
var clan_boosts := {}  # 🎖 клан-магаз бусты: {"dmg": {"until": sec}, ...}
var _ad_buff_on := false  # активен ли dmg/atk-буст (для пересчёта при истечении)
const AD_DUR := 1800.0    # буст на 30 минут
const AD_BOOST := {       # base% + step%/уровень (растёт от числа просмотров)
	"dmg":  {"name": "🗡 Урон отряда",   "name_en": "🗡 Team Damage",  "base": 40, "step": 10},
	"gold": {"name": "💰 Золото и лом",  "name_en": "💰 Gold & Scrap", "base": 100, "step": 25},
	"atk":  {"name": "⚡ Скорость атаки", "name_en": "⚡ Attack Speed", "base": 25, "step": 5},
}
var shop_panel: Control
var daily_t := 0.0        # таймер ежедневной выдачи алмазов (стаб)
var seen_intro := false   # показано ли интро-обучение (1й запуск)
# === АЧИВКИ (Рамиль): журнал-книжка, тиры ×10, награды дрипом (лом→ядра→алмазы). Ретроактив: значения живые.
var ach_claimed := {}     # id → сколько тиров забрано
const ACHIEVEMENTS := [
	{"id": "mobs",    "name": "Истребитель",       "name_en": "Exterminator",    "icon": "🗡", "key": "mobs",     "desc": "Убей врагов в бою",           "desc_en": "Kill enemies in battle",       "tiers": [100, 1000, 10000, 100000]},
	{"id": "bosses",  "name": "Босс-киллер",        "name_en": "Boss Killer",     "icon": "👑", "key": "bosses",   "desc": "Победи боссов",               "desc_en": "Defeat bosses",                "tiers": [10, 50, 250, 1000]},
	{"id": "gold",    "name": "Магнат",             "name_en": "Magnate",         "icon": "💰", "key": "gold",     "desc": "Накопи золота (всего)",        "desc_en": "Earn total gold",              "tiers": [10000, 1000000, 100000000, 10000000000]},
	{"id": "dmg",     "name": "Разрушитель",        "name_en": "Destroyer",       "icon": "⚔", "key": "dmg",      "desc": "Нанеси урона (всего)",         "desc_en": "Deal total damage",            "tiers": [100000, 10000000, 1000000000, 100000000000]},
	{"id": "drops",   "name": "Барахольщик",        "name_en": "Scavenger",       "icon": "🎁", "key": "drops",    "desc": "Собери предметов лута",        "desc_en": "Collect loot items",           "tiers": [50, 500, 5000, 50000]},
	{"id": "ads",     "name": "Рекламный",          "name_en": "Ad Watcher",      "icon": "📺", "key": "ads",      "desc": "Посмотри реклам-бустов",       "desc_en": "Watch ad boosts",              "tiers": [5, 25, 100, 500]},
	{"id": "pulls",   "name": "Гачамен",            "name_en": "Gacha Man",       "icon": "🎰", "key": "pulls",    "desc": "Сделай круток гачи",           "desc_en": "Do gacha pulls",               "tiers": [1, 10, 50, 200]},
	{"id": "stage",   "name": "Покоритель глубин",  "name_en": "Depth Conqueror", "icon": "📈", "key": "stage",    "desc": "Дойди до стадии",              "desc_en": "Reach stage",                  "tiers": [10, 25, 50, 100]},
	{"id": "prestige","name": "Перезагрузка",       "name_en": "Reboot",          "icon": "♻", "key": "prestige", "desc": "Сделай перезагрузок",          "desc_en": "Perform prestiges",            "tiers": [1, 10, 50, 200]},
	{"id": "sing",    "name": "Сингулярность",      "name_en": "Singularity",     "icon": "🌌", "key": "sing",     "desc": "Сделай сингулярностей",        "desc_en": "Perform singularities",        "tiers": [1, 5, 25, 100]},
	{"id": "hlvl",    "name": "Чемпион",            "name_en": "Champion",        "icon": "⭐", "key": "hlvl",     "desc": "Прокачай бойца до уровня",     "desc_en": "Upgrade a fighter to level",   "tiers": [25, 50, 100, 200]},
	{"id": "allhlvl", "name": "Командир",           "name_en": "Commander",       "icon": "🎖", "key": "allhlvl",  "desc": "Прокачай ВСЕХ бойцов до ур.", "desc_en": "Upgrade ALL fighters to lv.", "tiers": [20, 50, 100]},
]
var wipe_streak := 0      # подряд вайпов на одной стадии (для коуч-подсказок)
var last_wipe_stage := 0
# === ДЕЙЛИКИ + СТРИК (Рамиль): награда за заход в новый день, 7-дневный цикл ===
var daily_day := 0        # номер последнего дня когда забрал (unix/86400)
var daily_streak := 0     # текущий день цикла 1..7
const DAILY_REWARDS := [
	{"scrap": 100},                  # день 1
	{"cores": 20, "scrap": 150},     # день 2
	{"cores": 40},                   # день 3
	{"diamonds": 20},                # день 4
	{"cores": 80},                   # день 5
	{"diamonds": 40},                # день 6
	{"diamonds": 100, "cores": 150}, # день 7 — ДЖЕКПОТ
]
# === БАТЛПАС (Рамиль): награды по пройденным стадиям, тир каждые BP_STEP стадий ===
const BP_STEP := 5
var bp_claimed := []      # забранные бесплатные тиры (стадии-вехи)
var bp_claimed_prem := [] # забранные премиум-тиры
var bp_premium := false   # куплен ли премиум-трек
const BP_PREMIUM_COST := 500   # алмазов за премиум-батлпас
var last_discovered := "" # последнее открытое усиление (можно перебросить за алмазы — хук Tap Titans)
const REROLL_COST := 50   # алмазов за переброс усиления
var gacha_pity := 0       # пуллов с последнего Эпического (pity-гарант на 90)
const GACHA_COST1 := 50   # алмазов за 1 пулл
const GACHA_COST10 := 450 # за 10 пуллов (скидка)
var cores_peak := 0.0     # планка: макс. «счёт престижа», за который уже выдали ядра (повтор той же глубины → меньше)
var best_stage := 1       # лучшая достигнутая стадия (для Memory-Bonus старта)
# === 2-Й СЛОЙ ПРЕСТИЖА (Сингулярность) — открывается со стадии 40 ===
var quanta := 0           # ⚛ КВАНТЫ — валюта 2-го слоя (перма, НИКОГДА не сбрасывается)
var meta_lvl := {}        # уровни мета-апгрейдов (перма): mcore/mpow/mslot
var singularity_count := 0
var meta_unlocked := false   # видел ли игрок Сингулярность (раз увидел — кнопка остаётся)
const SINGULARITY_STAGE := 40
const META_UP := {
	"mcore": {"name": "⛏ Квантовый майнинг", "name_en": "⛏ Quantum Mining", "per": 0.5, "desc": "+50%/ур приход ядер", "desc_en": "+50%/lv core income"},
	"mpow":  {"name": "💥 Перегрузка ядра",   "name_en": "💥 Core Overload",   "per": 0.3, "desc": "+30%/ур мощь отряда", "desc_en": "+30%/lv squad power"},
	"mslot": {"name": "🎒 Расширение лоадаута", "name_en": "🎒 Loadout Expansion", "per": 1,  "desc": "+1 слот усилений/ур", "desc_en": "+1 augment slot/lv", "max": 5},
}
var meta_core := 1.0      # вычисленные мета-множители
var meta_pow := 1.0
var meta_slot := 0
# === РЕКОРДЫ/СТАТИСТИКА (п.7) ===
var stats_run := {"dmg": 0.0, "mobs": 0, "bosses": 0, "crits": 0, "gold": 0.0, "scrap": 0, "cores": 0, "time": 0.0, "ads": 0, "pulls": 0, "drops": 0}
var stats_all := {"dmg": 0.0, "mobs": 0, "bosses": 0, "crits": 0, "gold": 0.0, "scrap": 0, "cores": 0, "time": 0.0, "ads": 0, "pulls": 0, "drops": 0}
# === ЕЖЕДНЕВНЫЕ КВЕСТЫ (Рамиль): 3 задачи/день, прогресс = текущий стат − снимок на старте дня ===
const DAILY_QUESTS := [
	{"id": "kill",  "icon": "🗡", "name": "Зачистка",         "name_en": "Sweep",           "stat": "mobs",   "target": 200,    "rew": {"diamonds": 30}},
	{"id": "boss",  "icon": "👑", "name": "Охота на боссов",   "name_en": "Boss Hunt",       "stat": "bosses", "target": 6,      "rew": {"diamonds": 40}},
	{"id": "crit",  "icon": "🎯", "name": "Криткарь",          "name_en": "Critical Strike", "stat": "crits",  "target": 300,    "rew": {"diamonds": 25}},
	{"id": "drops", "icon": "🎁", "name": "Лутер",             "name_en": "Looter",          "stat": "drops",  "target": 12,     "rew": {"diamonds": 25}},
	{"id": "gold",  "icon": "💰", "name": "Золотая лихорадка", "name_en": "Gold Rush",       "stat": "gold",   "target": 100000, "rew": {"scrap": 2000}},
]
var dq_day := 0           # день, для которого выбраны квесты
var dq_idx := []          # индексы 3 квестов на сегодня
var dq_base := {}         # снимок статов на старте дня
var dq_claimed := []      # забранные сегодня (id)
var rec_maxhit := 0       # самый большой удар за всё время
var rec_prestiges := 0    # сколько престижей сделано
var stats_panel: Control
var stats_open := false
var stats_box: VBoxContainer
var aug_lvl := {}         # id аугмента → уровень (persist через перезагрузку)
var equipped_augs := []   # id аугментов в активных слотах (только они действуют)
var draft_offers := []    # 3 случайных аугмента-предложения (рандом-ролл из 3, выбираешь 1) — persist
var slots_bought := 0     # докуплено слотов за ядра
var reboot_panel: Control
var reboot_list: VBoxContainer
var reboot_info: Label
var rb_main: Button
# вычисленные множители аугментов (через _apply_augments)
var aug_dmg := 1.0
var aug_hp := 1.0
var aug_crit := 0.0
var aug_critx := 0.0
var aug_atk := 1.0
var aug_gold := 1.0
var aug_ultcd := 1.0
var aug_core := 1.0
var aug_qte := 0.0
var aug_density := 1.0
var eq_portrait_ic: Label  # портрет бойца слева сверху
var eq_portrait_nm: Label
var eq_wpn_stats: Label     # статы пушки (урон/скоростр/крит)
# ПАНЕЛЬ СЛОТА (A): список моделей слота (открывается тапом по слоту)
var impl_detail: Control
var det_title: Label
var det_list: VBoxContainer
# ПАНЕЛЬ ПРОКАЧКИ (B): открывается кнопкой «поднять уровень»
var impl_confirm: Control
var conf_item: Label
var conf_cost: Label
var conf_btn: Button

# стартовый комплект: каждый боец владеет MK1-моделью каждого слота (серый, ★1) и носит её
# ключ предмета = модель@редкость (редкость и звёзды — РАЗНЫЕ оси, §11)
func _ik(vid: String, rarity: int) -> String:
	return vid + "@" + str(rarity)

func _new_gear(_cls: int) -> Dictionary:
	# ПУСТЫЕ слоты на старте (Диана): первый дроп = явный момент «есть что надеть».
	# Базовый урон стартового оружия вшит в бойца (INNATE_WDMG в _recalc_hero) — боец не слабее.
	return {"gear": {"module": {}, "weapon": {}}, "equip": {"module": "", "weapon": ""}}

func _roll_stat(stat: String) -> Dictionary:
	var tier: float = ROLL_TIERS[randi() % ROLL_TIERS.size()]
	var val: int = max(1, int(round(STAT_ROLL[stat]["max"] * tier)))
	return {"stat": stat, "val": val}

# Primary-ролл слота. ОРУЖИЕ: урон ДЕТЕРМИНИРОВАН (всегда макс) → урон зависит ТОЛЬКО от уровня:
# ур.2 всегда сильнее ур.1 (Рамиль: жёстко привязать урон к уровню). Модули — со случайной ступенью (билды).
func _primary_roll(slot: String, stat: String) -> Dictionary:
	if slot == "weapon":
		return {"stat": stat, "val": STAT_ROLL[stat]["max"]}
	return _roll_stat(stat)

# модели слота: оружие → WEAPON_DEFS, иначе спецмодуль → HERO_MODULE
func _slot_variants(slot: String, cls: int) -> Array:
	return WEAPON_DEFS[cls]["variants"] if slot == "weapon" else HERO_MODULE[cls]["variants"]

func _slot_def(slot: String, cls: int) -> Dictionary:   # иконка/имя слота
	return WEAPON_DEFS[cls] if slot == "weapon" else HERO_MODULE[cls]

func _variant(slot: String, cls: int, vid: String) -> Dictionary:
	for v in _slot_variants(slot, cls):
		if v["id"] == vid:
			return v
	return _slot_variants(slot, cls)[0]

func _module_variant(cls: int, vid: String) -> Dictionary:   # совместимость со старым кодом
	return _variant("module", cls, vid)

# создать предмет слота: primary-стат модели + (rarity-1) случайных доп-статов
func _make_item(cls: int, vid: String, rarity: int, slot: String = "module") -> Dictionary:
	var v := _variant(slot, cls, vid)
	var rolls := [_primary_roll(slot, v["stat"])]
	# РАСПРЕДЕЛЕНИЕ СТАТОВ ПО РОЛЯМ (Диана): оружие = офенс (крит/скор), модуль = защита/утилита (HP/заряд/крит).
	var others: Array = ["crit", "atk"] if slot == "weapon" else ["hp", "ult", "crit"]
	others.erase(v["stat"])   # не дублируем primary
	others.shuffle()
	for i in range(min(rarity - 1, others.size())):
		rolls.append(_roll_stat(others[i]))
	return {"vid": vid, "rarity": rarity, "lvl": 1, "up": 0, "rolls": rolls}

func _item_power(it: Dictionary) -> int:   # грубая сила для сравнения «перефармить?»
	var s := 0
	for r in it["rolls"]:
		s += int(r["val"])
	# уровень весит много → дроп выше уровнем ВСЕГДА считается лучше (жёсткая привязка к уровню)
	return s + it["rarity"] * 8 + (int(it["lvl"]) - 1) * 12

# гейт редкости по прогрессу (CONCEPT §14, LOOT-RULES): лестница ДЛИННАЯ — топ это chase на недели,
# не на 20 волн. Серое носишь долго; цвет открывается редко и далеко.
func _max_rarity() -> int:
	# гейт по СТАДИИ (не волне) — не зависит от STAGE_WAVES. Цвет = событие, серое носишь долго.
	if stage >= 53: return 4   # Эпический — очень поздно
	if stage >= 27: return 3   # Редкий
	if stage >= 13: return 2   # Необычный (зелёный)
	return 1                   # старт: только Обычный (серый) надолго

func _min_rarity() -> int:
	# пол поднимается ОЧЕНЬ поздно (по стадии, не волне)
	if stage >= 50: return 2
	return 1

func _roll_rarity() -> int:
	var hi := _max_rarity()
	var lo: int = min(_min_rarity(), hi)
	if dry_streak >= 6:                 # bad-luck protection: давно без редкого → поднять пол
		lo = min(max(lo, 3), hi)
	var pool := []
	for r in range(lo, hi + 1):
		for _i in range(int(pow(2, hi - r))):   # выше редкость → реже
			pool.append(r)
	var res: int = pool[randi() % pool.size()]
	dry_streak = 0 if res >= 3 else dry_streak + 1
	return res

# суммарный бонус надетых моделей бойца по типу стата (с учётом уровня модели)
func _gear_bonus(hh: Dictionary, stat: String) -> float:
	var total := 0.0
	for slot in hh["equip"]:
		var key: String = hh["equip"][slot]
		if key == "" or not hh["gear"][slot].has(key):
			continue
		var inst = hh["gear"][slot][key]
		# уровень-дропа (×0.25/lvl) × апгрейд за лом (×0.10/up — простой казуал-апгрейд)
		var mult: float = (1.0 + (inst["lvl"] - 1) * 0.25) * (1.0 + 0.10 * int(inst.get("up", 0)))
		for r in inst["rolls"]:
			if r["stat"] == stat:
				total += r["val"] * mult
	return total

# стоимость ★-апа: растёт со звёздами И с редкостью (топ-★ топ-редкости = дорого, §11)
func _merge_cost(hh: Dictionary, slot: String, key: String) -> int:
	var inst = hh["gear"][slot][key]
	return inst["lvl"] * 50 * inst["rarity"]
# пассивные ауры классов (пока боец жив — бафает весь отряд)
var aura_hp := 1.0
var aura_dmg := 1.0
var aura_atk := 1.0
var aura_ult := 1.0
var atk_buff_t := 0.0   # временный бафф скорости атаки от ульты штурма
var aim_mode := false   # снайпер целится (ждём тап по врагу)
var aim_hero = null

func _recalc_auras() -> void:
	var snipe := false; var storm := false; var hak := false
	var tank_lvl := 0
	for hh in heroes:
		match hh["data"]["atk_type"]:
			"tank": tank_lvl = hh["level"]   # уровень ТАНКА (всегда в отряде, не зависит от alive — без death-spiral)
			"snipe": if hh["alive"]: snipe = true
			"single": if hh["alive"]: storm = true
			"aoe": if hh["alive"]: hak = true
	# 🛡 ТАНК = HP-ДВИГАТЕЛЬ ОТРЯДА: его уровень даёт ЭКСПОНЕНЦИАЛЬНЫЙ HP всему отряду (Рамиль).
	# Это главный источник выживаемости → хочешь переть глубже = качай танка; забил = стекляшка.
	aura_hp = pow(1.0 + float(_cfg("tankhp", TANK_HP_PER_LVL)) if bot else 1.0 + TANK_HP_PER_LVL, float(tank_lvl))
	aura_dmg = 1.0 + (0.08 if snipe else 0.0)  # снайпер → +8% урон всем
	aura_atk = 1.0 + (0.10 if storm else 0.0)  # штурм → +10% скор. атаки
	aura_ult = 0.82 if hak else 1.0            # хакер → ульты заряжаются быстрее
	for hh in heroes:
		_recalc_hero(hh)

# уровень аугмента + пересчёт множителей престижа
func _al(id: String) -> int:
	return aug_lvl.get(id, 0)

func _augsum(stat: String) -> float:
	var s := 0.0
	for a in AUGMENTS:
		if a["stat"] == stat and a["id"] in equipped_augs:   # действуют ТОЛЬКО в слотах
			s += _al(a["id"]) * a["per"]
	return s

# МУЛЬТИПЛИКАТИВНАЯ сила усилений (Фикс №1): ×(1+per)^уровень — компаундится, растёт ЭКСПОНЕНЦИАЛЬНО.
# Это пробивает потолок: каждый круг престижа поднимает силу в темпе с экспонентой HP врагов → потолок ползёт вверх.
func _augmul(stat: String) -> float:
	# УБЫВАЮЩАЯ ОТДАЧА на стак ОДНОГО стата: эффективные уровни = totlvl^AUG_DIMINISH.
	# → 3 разных ДПС-стата по чуть-чуть > 1 стат втрое (комбо-билды сильнее тупого моно-стака, скилл/матан рулят).
	var totlvl := 0
	var wlog := 0.0
	for a in AUGMENTS:
		if a["stat"] == stat and a["id"] in equipped_augs:
			var l := _al(a["id"])
			totlvl += l
			wlog += float(l) * log(1.0 + a["per"])
	if totlvl == 0: return 1.0
	var avg_log := wlog / float(totlvl)
	var eff := pow(float(totlvl), AUG_DIMINISH)
	return exp(avg_log * eff)

# всего слотов: база 3 + докупленные + бесплатные за рубежи стадий
func _slot_total() -> int:
	var milestones := 0
	for t in [8, 18, 35, 60]:
		if best_stage >= t: milestones += 1
	return min(12, 3 + slots_bought + milestones + meta_slot)   # +мета-слоты (2-й слой)

func _slot_cost() -> int:
	return int(150 * pow(2, slots_bought))   # дорого, ×2 за каждый купленный

func _buy_slot() -> void:
	if _slot_total() >= 10:
		return
	var c := _slot_cost()
	if cores < c:
		return
	cores -= c
	slots_bought += 1
	_refresh_reboot(); _refresh_hud()

func _equip_aug(id: String) -> void:
	if id in equipped_augs:
		equipped_augs.erase(id)
	elif _al(id) > 0 and equipped_augs.size() < _slot_total():
		equipped_augs.append(id)
	_apply_augments()
	_recalc_auras()
	_refresh_reboot(); _refresh_hud()

func _apply_augments() -> void:
	aug_dmg = _augmul("dmg")     # Фикс №1: УМНОЖЕНИЕ → экспонента → пробивает потолок (СИЛА)
	aug_hp = _augmul("hp")
	aug_crit = _augsum("crit")   # крит-ШАНС — складываем (нельзя >95%)
	aug_critx = _augmul("critx") # крит-МНОЖИТЕЛЬ — УМНОЖАЕМ (билд-разнообразие: крит-билд тоже пробивает потолок)
	aug_atk = _augmul("atk")     # скорость атаки — УМНОЖАЕМ (скорость-билд = альтернативный ДПС-путь)
	aug_gold = 1.0 + _augsum("gold")   # СЛОЖЕНИЕ: иначе экономика взрывается (golf→уровни→golf петля)
	aug_core = 1.0 + _augsum("core")   # СЛОЖЕНИЕ: компаунд ядер = runaway (ядра→ядра, hoard улетел в 1.5e16). Только урон/HP множим.
	aug_ultcd = max(0.4, 1.0 - _augsum("ultcd"))
	aug_qte = _augsum("qte")
	aug_density = max(0.3, 1.0 - _augsum("density"))

# пер-героя: УРОВЕНЬ × БАЗА (класс+пушка+шмот) × АУГМЕНТЫ (престиж)
func _recalc_hero(hh: Dictionary) -> void:
	var lv: int = hh["level"]
	var wbonus: int = int(_gear_bonus(hh, "wdmg"))   # ОРУЖИЕ = главный урон (роллы предмета ×уровень); надетое добавляется СВЕРХУ вшитой базы
	var base_dmg: int = hh["data"]["dmg"] + INNATE_WDMG + wbonus + int(_gear_bonus(hh, "dmg"))
	var base_hp: int = hh["data"]["hp"] + int(_gear_bonus(hh, "hp"))
	# ЛИНЕЙНЫЙ рост ×уровень + ×2-излом каждые DPS_MILESTONE уровней (модель Clicker Heroes).
	# Темп %/уровень убывает (L→L+1: +1/L) = плавное затухание; ×2 на рубежах = power-spike «волна». min()=кламп от переполнения.
	var milestone := pow(2.0, floor(float(lv - 1) / float(DPS_MILESTONE)))
	var is_tank: bool = hh["data"]["atk_type"] == "tank"
	# УРОН: у ТАНКА качается ОТВРАТИТЕЛЬНО (он HP-двигатель, не дамагер); у остальных полный ×уровень×излом
	var dmg_scale: float = (1.0 + lv * 0.04) if is_tank else (lv * milestone)
	hh["dmg"] = int(round(min(base_dmg * dmg_scale * aug_dmg * _ad_mult("dmg") * _clan_boost_mult("dmg") * meta_pow * _prestige_mult(), STAT_CAP)))
	# HP: НЕ от своего уровня, а от АУРЫ ТАНКА (его уровень, экспонента) + аугменты/модуль/surv. Качаешь танка = HP всему отряду.
	hh["max"] = int(min(base_hp * aura_hp * aug_hp * (float(_cfg("surv", 1.0)) if bot else 1.0), STAT_CAP))
	# крит / скорость атаки / заряд ульты — от шмоток + аугментов
	hh["crit"] = clamp(hh["data"]["crit"] + _gear_bonus(hh, "crit") / 100.0 + aug_crit, 0.0, 0.95)
	hh["critx"] = hh["data"]["critx"] * aug_critx   # множитель крита растёт экспонентой (крит-билд)
	hh["atk_mult"] = (1.0 + _gear_bonus(hh, "atk") / 100.0) * aug_atk * _ad_mult("atk") * _clan_boost_mult("atk")   # ×бусты скорости
	hh["ult_cd_eff"] = hh["data"]["ult_cd"] * aura_ult * max(0.4, 1.0 - _gear_bonus(hh, "ult") / 100.0) * aug_ultcd
	if hh["hp"] > hh["max"]: hh["hp"] = hh["max"]

func _aug_cost(id: String) -> int:
	return int(floor(8.0 * pow(1.15, _al(id))))   # Фикс №1: 1.22→1.15 — глубокие уровни усилений доступнее (ядра → сила → пробитие потолка)

func _prestige_score() -> float:
	# «счёт престижа» из ДВУХ осей: стадия (главный вес, квадратично) + суммарный ур. отряда (добавка)
	return stage * stage / 4.0 + float(_total_levels()) * 0.5

func _cores_gain() -> int:
	# ПАС4 (ресёрч): корневая формула — ядра = 10·depth^exp.
	# 0.5→0.65→0.75: плато stадий_за_престиж=0.022-0.050 (норма 2-30) → бодрее рост ядер на глубине.
	# При depth=100: было 199 ядер → стало 316 (+59%). Не трогает стену, только ускоряет cores_total.
	var depth: int = max(best_stage, stage)
	return max(1, int(floor(10.0 * pow(float(depth), 0.75) * aug_core * meta_core)))   # ×мета (2-й слой)

func _buy_aug(id: String) -> void:
	var c := _aug_cost(id)
	if cores < c:
		return
	cores -= c
	aug_lvl[id] = _al(id) + 1
	_apply_augments()
	_recalc_auras()
	_refresh_reboot()
	_refresh_hud()

# === РАНДОМ-3 ДРАФТ аугментов (Диана/Рамиль: выбираешь 1 из 3 случайных) ===
func _aug_def(id: String) -> Dictionary:
	for a in AUGMENTS:
		if a["id"] == id:
			return a
	return AUGMENTS[0]

func _roll_draft() -> void:
	var ids := []
	for a in AUGMENTS:
		ids.append(a["id"])
	ids.shuffle()
	draft_offers = [ids[0], ids[1], ids[2]]

func _take_draft(id: String) -> void:
	if cores < _aug_cost(id):
		return
	_buy_aug(id)        # списывает ядра, +1 уровень, применяет
	# авто-экип в свободный слот (чтоб эффект сразу действовал, без отдельной возни)
	if not id in equipped_augs and equipped_augs.size() < _slot_total():
		equipped_augs.append(id)
		_apply_augments(); _recalc_auras()
	_roll_draft()       # взял один → тройка обновляется
	_save()
	_refresh_reboot(); _refresh_hud()

func _reroll_draft() -> void:
	var c := 2          # небольшая цена, чтоб не фишить бесплатно
	if cores < c:
		return
	cores -= c
	_roll_draft()
	_save()
	_refresh_reboot(); _refresh_hud()

func _reboot() -> void:
	if not _can_prestige():
		return   # престиж заблокирован до достижения уровня PRESTIGE_LVL
	# ПЕРЕЗАГРУЗКА (лор «обнуление кибернетики»): +ЯДРА за забег; сброс уровней/золота/стадии;
	# шмот/лом/ядра/аугменты — ОСТАЮТСЯ. Старт выше по Memory-Bonus.
	var gain := _cores_gain()
	cores += gain
	cores_total += float(gain)      # накопитель для перма-множителя (бесконечная прогрессия)
	_stat_add("cores", gain)        # п.7
	rec_prestiges += 1
	_zero_stats(stats_run)          # новый забег → текущая статистика обнуляется (рекорды/all — нет)
	cores_peak = max(cores_peak, _prestige_score())   # подняли планку (пока уровни/стадия ещё не сброшены)
	best_stage = max(best_stage, stage)
	stage = max(1, int(floor(best_stage * 0.5)))   # Memory-Bonus: старт от лучшей стадии
	_grant_skipped_loot(stage)   # п.5: лут за боссов, пропущенных из-за Memory-Bonus
	sub = 1; in_boss = false; boss_retry = false
	gold = 0.0; gold_ps = 2.0
	for hh in heroes:
		hh["level"] = 1; hh["lvl_cost"] = 30
		hh["alive"] = true
		if hh.get("fall_tw") != null and hh["fall_tw"].is_valid():
			hh["fall_tw"].kill()
		hh["node"].rotation = 0.0
		hh["node"].modulate = Color(1, 1, 1, 1)
	_apply_augments()
	_recalc_auras()
	for hh in heroes:
		hh["hp"] = hh["max"]
	_qte_clear()
	if reboot_panel: reboot_panel.visible = false
	print("TTEVENT reboot gain=%d from_stage=%d -> start=%d cores=%d" % [gain, best_stage, stage, cores])
	_popup_center(_t("reboot_done") % gain, Color("#b46bff"))
	_save()
	_start_march()
	_refresh_hud()

# === 2-Й СЛОЙ ПРЕСТИЖА: СИНГУЛЯРНОСТЬ ===
func _ml(id: String) -> int:
	return int(meta_lvl.get(id, 0))

func _apply_meta() -> void:
	meta_core = 1.0 + _ml("mcore") * float(META_UP["mcore"]["per"])
	meta_pow = 1.0 + _ml("mpow") * float(META_UP["mpow"]["per"])
	meta_slot = _ml("mslot")

func _singularity_ready() -> bool:
	return max(best_stage, stage) >= SINGULARITY_STAGE

func _quanta_gain() -> int:
	# ⚛ кванты от глубины: на стадии 40 → 1, 50 → ~21, 60 → ~52, 80 → ~138
	return int(pow(float(max(0, max(best_stage, stage) - SINGULARITY_STAGE + 1)), 1.3))

func _meta_cost(id: String) -> int:
	return int(floor(2.0 * pow(1.6, _ml(id))))

func _buy_meta(id: String) -> void:
	if META_UP[id].has("max") and _ml(id) >= int(META_UP[id]["max"]): return
	var c := _meta_cost(id)
	if quanta < c: return
	quanta -= c
	meta_lvl[id] = _ml(id) + 1
	_apply_meta()
	for hh in heroes: _recalc_hero(hh)
	_save(); _refresh_hud()

func _singularity() -> void:
	if not _singularity_ready(): return
	var gain := _quanta_gain()
	quanta += gain; singularity_count += 1
	# БОЛЬШОЙ сброс 1-го слоя: стадии/уровни/ядра/усиления. Шмот, кванты, мета, монетизация — ОСТАЮТСЯ.
	best_stage = 1; stage = 1; sub = 1; in_boss = false; boss_retry = false
	gold = 0.0; gold_ps = 2.0; cores = 0; cores_peak = 0.0
	aug_lvl.clear(); equipped_augs.clear(); last_discovered = ""; slots_bought = 0
	_zero_stats(stats_run)
	for hh in heroes:
		hh["level"] = 1; hh["lvl_cost"] = 30; hh["alive"] = true
		if hh.get("fall_tw") != null and hh["fall_tw"].is_valid(): hh["fall_tw"].kill()
		hh["node"].rotation = 0.0; hh["node"].modulate = Color(1, 1, 1, 1)
	_apply_meta(); _apply_augments(); _recalc_auras()
	for hh in heroes: hh["hp"] = hh["max"]
	_qte_clear()
	if reboot_panel: reboot_panel.visible = false
	print("TTEVENT singularity gain=%d total=%d quanta=%d" % [gain, singularity_count, quanta])
	_popup_center(_t("sg_pop") % [singularity_count, gain], Color("#7adfff"), 3.0)
	_save(); _start_march(); _refresh_hud()

func _open_singularity() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3500; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.75); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.04, 0.07, 0.13, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#7adfff"); sb.set_border_width_all(2); sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 215, 90); card.custom_minimum_size = Vector2(430, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 9); card.add_child(v)
	v.add_child(_lbl(_t("sg_title"), 20, Color("#7adfff"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("sg_stat") % [quanta, singularity_count], 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("sg_perma"), 11, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_CENTER))
	# мета-апгрейды
	for id in ["mcore", "mpow", "mslot"]:
		var mid: String = id
		var lvl := _ml(id)
		var capped: bool = META_UP[id].has("max") and lvl >= int(META_UP[id]["max"])
		var c := _meta_cost(id)
		var row := Button.new(); row.custom_minimum_size = Vector2(0, 52); row.add_theme_font_size_override("font_size", 14)
		if capped:
			row.text = _t("sg_row_max") % [_tloc(META_UP[id], "name"), _t("lv_dot"), lvl, _t("sg_max"), _tloc(META_UP[id], "desc")]
			row.disabled = true
		else:
			row.text = _t("sg_row") % [_tloc(META_UP[id], "name"), _t("lv_dot"), lvl, lvl + 1, _tloc(META_UP[id], "desc"), c]
			row.disabled = quanta < c
		row.pressed.connect(func(): _buy_meta(mid); panel.queue_free(); _open_singularity())
		v.add_child(row)
	# кнопка сброса
	var sgn := _quanta_gain()
	var rb := Button.new(); rb.custom_minimum_size = Vector2(0, 56); rb.add_theme_font_size_override("font_size", 15)
	if _singularity_ready():
		rb.text = _t("sg_do") % sgn
		rb.add_theme_color_override("font_color", Color("#7adfff"))
		rb.pressed.connect(func(): panel.queue_free(); _singularity())
	else:
		rb.text = _t("sg_locked") % [SINGULARITY_STAGE, max(best_stage, stage)]
		rb.disabled = true
	v.add_child(rb)
	var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(0, 40); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

func _toggle_reboot() -> void:
	reboot_panel.visible = not reboot_panel.visible
	if reboot_panel.visible: _refresh_reboot()

func _send_telemetry(ev: String) -> void:
	if bot or TELEMETRY_URL == "" or nick == "" or http == null:
		return
	if http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return   # занят предыдущим запросом — пропускаем (fire-and-forget)
	var d := {"nick": nick, "event": ev, "stage": stage, "best": best_stage, "maxlvl": _max_hero_level(), "cores": cores, "scrap": scrap, "gold": int(gold), "ver": "1"}
	http.request(TELEMETRY_URL, ["Content-Type: text/plain"], HTTPClient.METHOD_POST, JSON.stringify(d))

func _build_nick_prompt() -> void:
	nick_panel = Control.new()
	nick_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	nick_panel.visible = false
	nick_panel.z_index = 3000
	hud.add_child(nick_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 1.0); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	nick_panel.add_child(bg)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 16)
	v.position = Vector2(W * 0.5 - 200, 360); v.size = Vector2(400, 0)
	nick_panel.add_child(v)
	var t := Label.new(); t.text = _t("nick_title"); t.add_theme_font_size_override("font_size", 26); t.add_theme_color_override("font_color", Color("#00f0ff")); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var ver := Label.new(); ver.text = _t("set_version") + " " + VERSION; ver.add_theme_font_size_override("font_size", 13); ver.add_theme_color_override("font_color", Color("#5a6a8a")); ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(ver)
	var sub2 := Label.new(); sub2.text = _t("nick_sub"); sub2.add_theme_font_size_override("font_size", 13); sub2.add_theme_color_override("font_color", Color("#7a7f99")); sub2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(sub2)
	nick_show = Label.new(); nick_show.text = _t("nick_unset"); nick_show.add_theme_font_size_override("font_size", 20); nick_show.add_theme_color_override("font_color", Color("#ffd24a")); nick_show.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; nick_show.custom_minimum_size = Vector2(0, 40); v.add_child(nick_show)
	var enter := Button.new(); enter.text = _t("nick_enter_btn"); enter.add_theme_font_size_override("font_size", 18); enter.custom_minimum_size = Vector2(0, 50); v.add_child(enter)
	enter.pressed.connect(func():
		_prompt_nick()
		nick_show.text = nick if nick != "" else _t("nick_unset"))
	var b := Button.new(); b.text = _t("nick_play_btn"); b.add_theme_font_size_override("font_size", 20); b.custom_minimum_size = Vector2(0, 54); v.add_child(b)
	b.pressed.connect(func():
		if nick == "": nick = _t("guest_nick")
		nick_panel.visible = false
		_save()
		_send_telemetry("start")
		if not seen_intro: _show_intro()   # первый запуск → интро-обучение
		elif _daily_available(): _show_daily())
	var upd := Button.new(); upd.text = _t("nick_refresh_btn"); upd.add_theme_font_size_override("font_size", 13); upd.custom_minimum_size = Vector2(0, 40); v.add_child(upd)
	upd.pressed.connect(_clear_cache)

func _clear_cache() -> void:   # очистка service worker + кэша → загрузка свежей версии (фикс «вижу старое»)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(async()=>{try{if('serviceWorker' in navigator){const rs=await navigator.serviceWorker.getRegistrations();for(const r of rs){await r.unregister();}}if(self.caches){const ks=await caches.keys();for(const k of ks){await caches.delete(k);}}}catch(e){}location.reload(true);})();", true)

func _prompt_nick() -> void:   # нативный ввод браузера — надёжно на мобиле (LineEdit в вебе клаву не цепляет)
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("(window.prompt('" + _t("nick_prompt") + "', '') || '').slice(0,20)", true)
		if typeof(r) == TYPE_STRING and r.strip_edges() != "":
			nick = r.strip_edges()
	else:
		nick = "игрок"   # не-веб (бот/десктоп-тест) — заглушка

func _build_reboot() -> void:
	reboot_panel = Control.new()
	reboot_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	reboot_panel.visible = false
	reboot_panel.z_index = 2000
	hud.add_child(reboot_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.09, 0.99); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _toggle_reboot())
	reboot_panel.add_child(bg)
	reboot_title = Label.new()
	reboot_title.text = _t("rb_title")
	reboot_title.add_theme_color_override("font_color", Color("#b46bff")); reboot_title.add_theme_font_size_override("font_size", 21)
	reboot_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reboot_title.position = Vector2(0, 24); reboot_title.size = Vector2(W, 30)
	reboot_panel.add_child(reboot_title)
	_add_help(reboot_panel, _t("rb_help_t"), _t("rb_help_b"))
	reboot_info = Label.new()
	reboot_info.add_theme_font_size_override("font_size", 14); reboot_info.add_theme_color_override("font_color", Color("#cdbbe8"))
	reboot_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reboot_info.position = Vector2(0, 60); reboot_info.size = Vector2(W, 60)
	reboot_panel.add_child(reboot_info)
	var rb := Button.new()
	rb.text = _t("rb_reboot_btn"); rb.add_theme_font_size_override("font_size", 17)
	rb.custom_minimum_size = Vector2(300, 50); rb.position = Vector2(W * 0.5 - 150, 124)
	var rsb := StyleBoxFlat.new(); rsb.bg_color = Color(0.25, 0.1, 0.4, 0.96); rsb.set_corner_radius_all(10)
	rsb.border_color = Color("#b46bff"); rsb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus"]: rb.add_theme_stylebox_override(st, rsb)
	rb.pressed.connect(_reboot)
	rb_main = rb
	reboot_panel.add_child(rb)
	var sc := ScrollContainer.new()
	sc.position = Vector2(W * 0.5 - 270, 190); sc.custom_minimum_size = Vector2(540, 560); sc.size = Vector2(540, 560)
	reboot_panel.add_child(sc)
	reboot_list = VBoxContainer.new(); reboot_list.add_theme_constant_override("separation", 8)
	reboot_list.custom_minimum_size = Vector2(540, 0)
	sc.add_child(reboot_list)
	reboot_close = Button.new()
	reboot_close.text = _t("close_caps"); reboot_close.add_theme_font_size_override("font_size", 16)
	reboot_close.custom_minimum_size = Vector2(200, 48); reboot_close.position = Vector2(W * 0.5 - 100, H - 56)
	reboot_close.pressed.connect(_toggle_reboot)
	reboot_panel.add_child(reboot_close)

func _refresh_reboot() -> void:
	if reboot_title: reboot_title.text = _t("rb_title")   # build-once строки → язык
	if reboot_close: reboot_close.text = _t("close_caps")
	var unlocked := _can_prestige()
	# чисто: только мощь + ядра. Условие перезагрузки — на самой кнопке (не грузим экран).
	reboot_info.text = _t("rb_info") % [_gsep(_party_power()), cores]
	rb_main.disabled = not unlocked
	if unlocked:
		rb_main.text = _t("rb_reboot_gain") % [_cores_gain(), max(1, int(floor(max(best_stage, stage) * 0.5)))]
	else:
		var minst: int = int(floor(float(best_stage) * 0.5))
		if stage <= minst and (stage >= PRESTIGE_STAGE or _total_levels() >= PRESTIGE_TOTAL_LVL):
			rb_main.text = _t("rb_lock_above") % minst
		else:
			rb_main.text = _t("rb_lock_req") % [PRESTIGE_STAGE, PRESTIGE_TOTAL_LVL]
	for c in reboot_list.get_children():
		c.queue_free()
	# === 2-Й СЛОЙ: кнопка Сингулярности — ПОЯВЛЯЕТСЯ только со стадии 40 (новичку не грузим) ===
	if _singularity_ready() or meta_unlocked:
		meta_unlocked = true
		var sng := Button.new(); sng.custom_minimum_size = Vector2(516, 50); sng.add_theme_font_size_override("font_size", 15)
		sng.add_theme_color_override("font_color", Color("#7adfff"))
		var sgn := _quanta_gain()
		sng.text = _t("rb_sng_btn") % [quanta, ("  +%d⚛" % sgn) if _singularity_ready() else ""]
		sng.pressed.connect(_open_singularity)
		reboot_list.add_child(sng)
	# === TAP TITANS-МОДЕЛЬ: открыть СЛУЧАЙНОЕ усиление за ядра ===
	var n_unowned := 0
	var n_owned := 0
	for a in AUGMENTS:
		if _al(a["id"]) == 0: n_unowned += 1
		else: n_owned += 1
	var disc := Button.new(); disc.custom_minimum_size = Vector2(516, 52); disc.add_theme_font_size_override("font_size", 15)
	if n_unowned > 0:
		disc.text = _t("rb_discover") % _discover_cost()
		disc.disabled = cores < _discover_cost()
	else:
		disc.text = _t("rb_all_open"); disc.disabled = true
	disc.pressed.connect(_discover_aug)
	reboot_list.add_child(disc)
	# ПЕРЕРОЛЛ за алмазы (монетизация): не понравилось открытое усиление → перебросить на другое случайное
	if last_discovered != "" and _al(last_discovered) == 1 and n_unowned > 0:
		var rb := Button.new(); rb.custom_minimum_size = Vector2(516, 40); rb.add_theme_font_size_override("font_size", 13)
		rb.text = _t("rb_reroll") % [_tloc(_aug_def(last_discovered), "name"), REROLL_COST]
		rb.disabled = diamonds < REROLL_COST
		rb.pressed.connect(_reroll_discovered)
		reboot_list.add_child(rb)
	# слот-докупка — только когда есть хотя бы одно усиление (Диана: не грузить новичка)
	if n_owned > 0 and _slot_total() < 10:
		var sbtn := Button.new(); sbtn.custom_minimum_size = Vector2(516, 38); sbtn.add_theme_font_size_override("font_size", 12)
		sbtn.text = _t("rb_slot") % [equipped_augs.size(), _slot_total(), _slot_cost()]; sbtn.disabled = cores < _slot_cost()
		sbtn.pressed.connect(_buy_slot); reboot_list.add_child(sbtn)
	# === СПИСОК ВЛАДЕЕМЫХ: два понятных раздела — Активные и В запасе (Диана) ===
	var active := []
	var spare := []
	for a in AUGMENTS:
		if _al(a["id"]) > 0:
			if a["id"] in equipped_augs: active.append(a["id"])
			else: spare.append(a["id"])
	if active.size() > 0:
		reboot_list.add_child(_lbl(_t("rb_active"), 12, Color("#b46bff")))
		for id in active:
			reboot_list.add_child(_owned_aug_row(id))
	if spare.size() > 0:
		reboot_list.add_child(_lbl(_t("rb_spare"), 12, Color("#9a8fb5")))
		for id in spare:
			reboot_list.add_child(_owned_aug_row(id))

# понятный эффект усиления. Множительные статы (Фикс №1) показываем как ×N (компаунд), остальные — сложение.
func _aug_effect(a: Dictionary, lvl: int) -> String:
	var v: float = lvl * a["per"]
	var mul: float = pow(1.0 + a["per"], lvl)   # компаунд для множительных
	var ms: String = ("×%.2f" % mul) if mul < 10.0 else (("×%.0f" % mul) if mul < 1000.0 else "×" + _fmt_n(mul))
	match a["stat"]:
		"dmg": return _t("ae_dmg") % ms
		"hp": return _t("ae_hp") % ms
		"gold": return _t("ae_gold") % int(round(v * 100))
		"core": return _t("ae_core") % int(round(v * 100))
		"atk": return _t("ae_atk") % int(round(v * 100))
		"crit": return _t("ae_crit") % (v * 100)
		"critx": return _t("ae_critx") % v
		"ultcd": return _t("ae_ultcd") % int(round(v * 100))
		"qte": return _t("ae_qte") % v
		"density": return _t("ae_density") % int(round(v * 100))
		_: return "+%d%%" % int(round(v * 100))

# Tap Titans: цена открытия случайного усиления растёт с числом уже открытых
func _discover_cost() -> int:
	var owned := 0
	for a in AUGMENTS:
		if _al(a["id"]) > 0: owned += 1
	return int(8 * pow(1.5, owned))

func _discover_aug() -> void:
	var c := _discover_cost()
	if cores < c: return
	var pool := []
	for a in AUGMENTS:
		if _al(a["id"]) == 0: pool.append(a["id"])
	if pool.is_empty(): return
	cores -= c
	var id: String = pool[randi() % pool.size()]
	aug_lvl[id] = 1
	if equipped_augs.size() < _slot_total():   # авто-надеть в свободный слот
		equipped_augs.append(id)
	last_discovered = id   # можно перебросить за алмазы
	_apply_augments(); _recalc_auras()
	_save(); _refresh_reboot(); _refresh_hud()
	var a := _aug_def(id)
	_popup_center(_t("rb_pop_open") % [a["icon"], _tloc(a, "name"), _aug_effect(a, 1)], Color("#ffd24a"), 2.4)

# ПЕРЕРОЛЛ за алмазы (Tap Titans): снять только что открытое усиление и открыть другое случайное
func _reroll_discovered() -> void:
	if last_discovered == "" or diamonds < REROLL_COST or _al(last_discovered) != 1:
		return
	var pool := []
	for a in AUGMENTS:
		if _al(a["id"]) == 0 and a["id"] != last_discovered: pool.append(a["id"])
	if pool.is_empty(): return   # нечего перебрасывать (всё открыто)
	diamonds -= REROLL_COST
	var old: String = last_discovered
	aug_lvl.erase(old); equipped_augs.erase(old)
	var nid: String = pool[randi() % pool.size()]
	aug_lvl[nid] = 1
	if equipped_augs.size() < _slot_total(): equipped_augs.append(nid)
	last_discovered = nid
	_apply_augments(); _recalc_auras()
	_save(); _refresh_reboot(); _refresh_hud()
	var a := _aug_def(nid)
	_popup_center(_t("rb_pop_reroll") % [a["icon"], _tloc(a, "name"), _aug_effect(a, 1)], Color("#b46bff"), 2.2)

# строка владеемого усиления: надетые — фиолет/СНЯТЬ, в наличии — тускло/НАДЕТЬ; + кнопка «+ур» за ядра
func _owned_aug_row(id: String) -> Control:
	var a := _aug_def(id)
	var lvl := _al(id)
	var eq: bool = id in equipped_augs
	var cost := _aug_cost(id)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.10, 0.18, 0.95) if eq else Color(0.09, 0.09, 0.12, 0.9)
	sb.set_corner_radius_all(10); sb.set_content_margin_all(8)
	sb.border_color = Color("#b46bff") if eq else Color("#44485e"); sb.set_border_width_all(2 if eq else 1)
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(516, 0)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6); card.add_child(hb)
	var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_lbl(_t("rb_owned_row") % [a["icon"], _tloc(a, "name"), _t("lv_dot"), lvl, (_t("rb_eq_on") if eq else "")], 14, Color("#d9c7ff") if eq else Color("#9aa0b5")))
	info.add_child(_lbl(_aug_effect(a, lvl) + "  →  " + _aug_effect(a, lvl + 1), 11, Color("#7fe0a0")))
	hb.add_child(info)
	var aid: String = id
	var eqb := Button.new(); eqb.custom_minimum_size = Vector2(96, 46); eqb.add_theme_font_size_override("font_size", 12)
	if eq: eqb.text = _t("rb_unequip")
	elif equipped_augs.size() >= _slot_total(): eqb.text = _t("rb_slots_full"); eqb.disabled = true
	else: eqb.text = _t("g_equip")
	eqb.pressed.connect(func(): _equip_aug(aid))
	hb.add_child(eqb)
	var ub := Button.new(); ub.custom_minimum_size = Vector2(96, 46); ub.add_theme_font_size_override("font_size", 12)
	ub.text = _t("rb_lvlup") % cost; ub.disabled = cores < cost
	ub.pressed.connect(func(): _buy_aug(aid))
	hb.add_child(ub)
	return card

func _ready() -> void:
	randomize()
	_setup_font()
	_build()
	_fb_init()   # Firebase: анонимный вход (web), даёт #ID для кланов
	for a in OS.get_cmdline_user_args():   # парсинг флагов ДО загрузки
		if a == "--bot":
			bot = true
		elif a.begins_with("--tactic="):
			bot_tactic = a.split("=")[1]
		elif a.begins_with("--slot="):
			save_slot = "_" + a.split("=")[1]
	http = HTTPRequest.new()
	add_child(http)
	_build_nick_prompt()
	_reset()
	_load()   # подхватить сейв (по слоту)
	_apply_location_theme()   # тема фона под активную локацию
	_dq_refresh()   # ежедневные квесты на сегодня
	if bot:
		auto_battle = true
		Engine.max_fps = 0          # снять кап fps → CPU свободен, рисует больше кадров → шаг кадра мелкий даже на высоком time_scale (легитимно)
		Engine.time_scale = 32.0    # ×16: шаг = 16/fps, при ~250fps ≈ 0.06с (мельче прежнего 0.13с) → симуляция точная, вдвое быстрее
		print("TTBOT enabled tactic=%s slot=%s time_scale=32 maxfps=0" % [bot_tactic, save_slot])
	elif nick == "":
		nick_panel.visible = true   # первый вход → спросить ник (ввод через нативный браузерный prompt)
	elif _offline_gold > 0:
		_show_offline()
	if not bot and nick != "" and not seen_intro:   # вернувшийся игрок без интро → показать
		_show_intro()
	elif _daily_available() and nick != "":   # новый день → ежедневная награда (elif: не стакать с интро, фикс R4)
		_show_daily()
	if not bot and _x2_active():   # активный x2 пережил перезаход → вернуть скорость (фикс C2)
		_set_speed(2.0)

func _setup_font() -> void:
	# DejaVu (кириллица) + NotoColorEmoji как fallback → эмодзи рендерятся
	var base: FontFile = load("res://DejaVuSans.ttf")
	var emoji: FontFile = load("res://NotoColorEmoji.ttf")
	if base and emoji:
		base.fallbacks = [emoji]
		var th := Theme.new()
		th.default_font = base
		theme = th

func _reset() -> void:
	for c in world.get_children():
		c.queue_free()
	heroes.clear()
	enemies.clear()
	wave = 0
	implants_count = 0
	gold = 0.0
	gold_ps = 2.0
	impl_sel = 0
	dry_streak = 0
	scrap = 0
	cores = 0
	cores_peak = 0.0
	diamonds = 999999; x3_unlocked = false; x2_until = 0.0; gacha_pity = 0; last_discovered = ""; ad_boosts = {}; clan_boosts = {}
	quanta = 0; meta_lvl = {}; singularity_count = 0; meta_unlocked = false; _apply_meta()
	bp_claimed = []; bp_claimed_prem = []; bp_premium = false; ach_claimed = {}; daily_day = 0; daily_streak = 0
	seen_intro = false; wipe_streak = 0; last_wipe_stage = 0
	aim_mode = false; aim_hero = -1; _qte_clear()   # чистка QTE-маркеров/прицела при hard-restart (баг-хант R2)
	best_stage = 1
	new_gear.clear()
	fav.clear()
	ic_sel.clear()
	_zero_stats(stats_run); _zero_stats(stats_all)
	rec_maxhit = 0; rec_prestiges = 0
	aug_lvl.clear()
	equipped_augs.clear()
	_roll_draft()
	slots_bought = 0
	_apply_augments()
	stage = 1
	sub = 1
	in_boss = false
	boss_retry = false
	hack_mult = 1.0
	hack_t = 0.0
	status_label.text = ""
	# спавн отряда
	for i in HEROES.size():
		var h = HEROES[i]
		var fp = FORMATION[i]
		var d := _make_char("hero%d" % (i + 1), 1, fp["s"], h["color"])
		d.position = Vector2(fp["x"], GROUND_Y + fp["y"])
		d.z_index = int(d.position.y)   # ближние (танк) поверх дальних (снайпер)
		world.add_child(d)
		var g: Dictionary = _new_gear(i)
		heroes.append({
			"data": h, "node": d, "hp": h["hp"], "max": h["hp"], "cls": i,
			"dmg": h["dmg"], "atk_spd": h["atk"],
			"level": 1, "lvl_cost": 30,
			"gear": g["gear"], "equip": g["equip"],
			"crit": h["crit"], "atk_mult": 1.0, "ult_cd_eff": h["ult_cd"],
			"t": h["atk"], "ult_t": h["ult_cd"], "alive": true, "shield": 0.0, "atk_anim": 0.0
		})
	_recalc_auras()
	_start_march()
	_refresh_hud()

# === БОТ-ТЕЛЕМЕТРИЯ: подробная строка в файл с flush (надёжно, без буферизации stdout) ===
func _bot_telemetry() -> void:
	if bot_logf == null:
		bot_logf = FileAccess.open("/tmp/botstate%s.jsonl" % save_slot, FileAccess.WRITE)
	if bot_logf == null:
		return
	var lvls := []
	var wlvls := []     # уровень надетого оружия по бойцам (видно прогресс шмота)
	for hh in heroes:
		lvls.append(hh["level"])
		var wk: String = hh["equip"].get("weapon", "")
		wlvls.append(int(hh["gear"]["weapon"][wk]["lvl"]) if hh["gear"]["weapon"].has(wk) else 0)
	var row := {
		"t": int(Time.get_ticks_msec() / 1000), "tactic": bot_tactic,
		"stage": stage, "best": best_stage, "sub": sub, "boss": (1 if in_boss else 0),
		"lvls": lvls, "maxlvl": _max_hero_level(), "totlvl": _total_levels(), "wlvls": wlvls,
		"gold": int(gold), "scrap": scrap, "cores": cores, "prestiges": rec_prestiges,
		"augs": equipped_augs.size(), "slots": _slot_total(), "auglvls": aug_lvl.size(),
		"dmg": int(stats_run["dmg"]), "mobs": stats_run["mobs"], "bosses": stats_run["bosses"],
		"ppwr": _party_power(),
		"quanta": quanta, "sing": singularity_count, "mpow": _ml("mpow"), "mcore": _ml("mcore"), "mslot": _ml("mslot"),
		"alive": heroes.reduce(func(acc, h): return acc + (1 if h["alive"] else 0), 0),
	}
	bot_logf.store_line(JSON.stringify(row))
	bot_logf.flush()

# грубая «боевая мощь» отряда (сумма урона живых) — для кривой прогресса и показателя силы
func _party_power() -> int:
	var p := 0.0
	for hh in heroes:
		p += float(hh["dmg"]) * float(hh.get("atk_spd", 1.0)) * float(hh.get("atk_mult", 1.0))
	return int(min(p, STAT_CAP))   # float-аккумуляция + кламп → без переполнения

# внешний конфиг тактик (hot-reload каждые ~10с): можно крутить стратегию БЕЗ перезапуска
func _bot_load_cfg() -> void:
	if not FileAccess.file_exists("/tmp/bot_tactics.json"):
		return
	var f := FileAccess.open("/tmp/bot_tactics.json", FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) == TYPE_DICTIONARY:
		bot_cfg = d

func _cfg(key: String, default):
	var t = bot_cfg.get(bot_tactic, {})
	if typeof(t) == TYPE_DICTIONARY and t.has(key):
		return t[key]
	return default

# === СОХРАНЕНИЕ (user://save.json → в web это IndexedDB, переживает перезапуск) ===
# БОТ: сам качает уровни/аугменты, штурмует боссов, престижит при застое
func _bot_tick(delta: float) -> void:
	# hot-reload внешнего конфига тактик (раз в ~10с)
	bot_cfg_t -= delta
	if bot_cfg_t <= 0.0:
		bot_cfg_t = 10.0
		_bot_load_cfg()
	# QTE: бот «жмёт» маркеры (идеальный контр)
	if not qte_markers.is_empty():
		for m in qte_markers.duplicate():
			_qte_marker_hit(m)
	# прокачка уровней за золото
	var skiptank: bool = bool(_cfg("skiptank", false))   # тест: бот игнорит танка → отряд хрупкий (стекляшка)
	# КАЗУАЛ-симуляция: lvl_cap = потолок уровня относительно стадии (казуал отстаёт), lvl_eff = доля прокачки
	var lvl_cap_mult: float = float(_cfg("lvl_cap", 0.0))   # >0: не качать выше stage*lvl_cap (казуал не доинвестит)
	var lvl_eff: float = float(_cfg("lvl_eff", 1.0))         # <1: пропускает часть прокачки
	for i in heroes.size():
		if skiptank and heroes[i]["data"]["atk_type"] == "tank": continue
		if lvl_cap_mult > 0.0 and heroes[i]["level"] >= int(max(best_stage, stage) * lvl_cap_mult): continue
		if heroes[i]["alive"] and gold >= heroes[i]["lvl_cost"] and randf() < lvl_eff:
			_upgrade_level(i)
	# авто-экип лучшего лута (казуал может не оптимизировать шмот: equip=false)
	if bool(_cfg("equip", true)):
		_bot_equip_best()
	# аугменты: экип владеемых в свободные слоты + купить дешёвый уровень
	if cores > 0 or equipped_augs.size() < _slot_total():
		_bot_augments()
	# периодически штурмуем босса
	bot_boss_t -= delta
	if bot_boss_t <= 0.0 and not in_boss and phase == "fight":
		bot_boss_t = 5.0
		_go_boss()
	# застой → престиж (только если престиж ОТКРЫТ; пороги выше → дольше грайндят)
	var stall_lim: float = float(_cfg("stall", {"balanced": 90.0, "rush": 40.0, "hoard": 240.0, "skill": 90.0}.get(bot_tactic, 90.0)))
	if stage > bot_last_stage:
		bot_last_stage = stage; bot_stall_t = 0.0
	else:
		bot_stall_t += delta
	if bot_stall_t > stall_lim and _can_prestige():
		bot_stall_t = 0.0; bot_last_stage = 1
		bot_psing += 1
		# бот-тест 2-го слоя: глубоко зашёл + накопил престижей → Сингулярность + закуп меты
		if _singularity_ready() and bot_psing >= 8 and _quanta_gain() >= 3:
			_singularity(); bot_psing = 0; _bot_buy_meta()
		else:
			_reboot()

# БОТ: надеть лучший предмет в каждом слоте (по _item_power) у каждого бойца
func _bot_equip_best() -> void:
	for hh in heroes:
		for slot in ["weapon", "module"]:
			var cur: String = hh["equip"][slot]
			var best_key: String = cur
			var best_pow: int = _item_power(hh["gear"][slot][cur]) if hh["gear"][slot].has(cur) else -1
			for key in hh["gear"][slot]:
				var p := _item_power(hh["gear"][slot][key])
				if p > best_pow:
					best_pow = p; best_key = key
			if hh["equip"][slot] != best_key:
				hh["equip"][slot] = best_key
				_recalc_hero(hh)

# БОТ: тратит кванты на мета-апгрейды (тест 2-го слоя)
func _bot_buy_meta() -> void:
	for i in 30:
		var bought := false
		for id in ["mpow", "mcore", "mslot"]:
			var capped: bool = META_UP[id].has("max") and _ml(id) >= int(META_UP[id]["max"])
			if not capped and quanta >= _meta_cost(id):
				_buy_meta(id); bought = true
		if not bought: break

func _bot_augments() -> void:
	# приоритет тактики: какие семейства держим в слотах
	var pri: Array = _cfg("augs", {
		"rush": ["neuro", "coproc", "blade", "reactor"],
		"hoard": ["neuro", "coproc", "reactor", "armor"],
		"skill": ["exploit", "reflex", "scope", "neuro"],
		"balanced": ["neuro", "coproc", "reactor", "scope"],
	}.get(bot_tactic, ["neuro", "coproc", "reactor", "scope"]))
	# 1) заполняем слоты приоритетными (открыв при необходимости)
	for id in pri:
		if equipped_augs.size() >= _slot_total():
			break
		if id in equipped_augs:
			continue
		if _al(id) == 0 and cores >= _aug_cost(id):
			_buy_aug(id)   # открыть (0→1)
		if _al(id) > 0 and not id in equipped_augs and equipped_augs.size() < _slot_total():
			equipped_augs.append(id)
	# 2) ГЛУБИНА: качаем самый дешёвый среди НАДЕТЫХ
	var best := ""; var bc := 1 << 30
	for id in equipped_augs:
		var c := _aug_cost(id)
		if c < bc:
			bc = c; best = id
	if best != "" and cores >= bc:
		_buy_aug(best)
	else:
		_apply_augments(); _recalc_auras()

func _save_path() -> String:
	return "user://save%s.json" % save_slot

func _show_death(was_boss: bool) -> void:
	if bot: return
	var msg := _t("you_died") if was_boss else _t("squad_wiped")
	_popup_center(msg, Color("#ff5050"), 3.8)   # висит дольше

func _toggle_settings() -> void:
	if settings_panel == null:
		_build_settings()
	settings_panel.visible = not settings_panel.visible
	_refresh_settings()

func _apply_lang() -> void:   # применить смену языка к постоянному UI (панели берут _t при открытии)
	_refresh_settings()
	if reboot_panel: _refresh_reboot()   # престиж тоже построен однажды — рефрешим строки
	if inv_panel: _refresh_inv()   # прокачка отряда тоже build-once → рефрешим заголовок/имена/закрыть
	if impl_panel: _refresh_impl_static()   # экипировка build-once → рефрешим статичные строки (заголовок/шапка/имена/инфо/хинт/закрыть)
	if inv_btn: inv_btn.tooltip_text = _t("tab_upgrade")
	if impl_btn: impl_btn.tooltip_text = _t("tab_gear")
	if more_btn: more_btn.tooltip_text = _t("tab_more")
	_popup_center("✅ " + ("English" if lang == "en" else "Русский"), Color("#00f0ff"), 1.4)

func _refresh_settings() -> void:
	# статичные строки настроек (build-once) — пере-применяем под текущий язык
	if settings_title: settings_title.text = _t("t_settings")
	if settings_ver: settings_ver.text = _t("set_version") + " " + VERSION
	if recs_btn: recs_btn.text = _t("set_records")
	if cache_btn: cache_btn.text = _t("set_refresh")
	if nick_lbl: nick_lbl.text = _t("set_nick_lbl")
	if save_nick_btn: save_nick_btn.text = _t("set_nick_btn")
	if settings_close: settings_close.text = _t("close_caps")
	if lang_btn:
		lang_btn.text = _t("set_lang_btn") % ("Русский 🇷🇺" if lang == "ru" else "English 🇬🇧")
	if set_dmg_btn:
		set_dmg_btn.text = _t("set_dmg_btn") % (_t("on") if show_dmg else _t("off"))
	if set_cd_btn:
		set_cd_btn.text = _t("set_cd_btn") % (_t("on") if show_cd else _t("off"))
	if set_nick_input and nick != "" and nick != "гость" and nick != "guest":
		set_nick_input.text = nick

func _build_settings() -> void:
	settings_panel = Control.new()
	settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_panel.visible = false
	settings_panel.z_index = 3000
	hud.add_child(settings_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.99); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: settings_panel.visible = false)
	settings_panel.add_child(bg)
	settings_title = Label.new(); settings_title.text = _t("t_settings"); settings_title.add_theme_font_size_override("font_size", 26); settings_title.add_theme_color_override("font_color", Color("#00f0ff")); settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; settings_title.position = Vector2(0, 50); settings_title.size = Vector2(W, 34)
	settings_panel.add_child(settings_title)
	settings_ver = Label.new(); settings_ver.text = _t("set_version") + " " + VERSION; settings_ver.add_theme_font_size_override("font_size", 14); settings_ver.add_theme_color_override("font_color", Color("#ffd24a")); settings_ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; settings_ver.position = Vector2(0, 86); settings_ver.size = Vector2(W, 20)
	settings_panel.add_child(settings_ver)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14)
	v.position = Vector2(30, 130); v.size = Vector2(W - 60, 0)
	settings_panel.add_child(v)
	lang_btn = Button.new(); lang_btn.add_theme_font_size_override("font_size", 16); lang_btn.custom_minimum_size = Vector2(0, 52)
	lang_btn.pressed.connect(func(): lang = ("en" if lang == "ru" else "ru"); _save(); _apply_lang())
	v.add_child(lang_btn)
	set_dmg_btn = Button.new(); set_dmg_btn.add_theme_font_size_override("font_size", 16); set_dmg_btn.custom_minimum_size = Vector2(0, 52)
	set_dmg_btn.pressed.connect(func(): show_dmg = not show_dmg; _save(); _refresh_settings())
	v.add_child(set_dmg_btn)
	set_cd_btn = Button.new(); set_cd_btn.add_theme_font_size_override("font_size", 16); set_cd_btn.custom_minimum_size = Vector2(0, 52)
	set_cd_btn.pressed.connect(func(): show_cd = not show_cd; _save(); _refresh_settings())
	v.add_child(set_cd_btn)
	recs_btn = Button.new(); recs_btn.text = _t("set_records"); recs_btn.add_theme_font_size_override("font_size", 16); recs_btn.custom_minimum_size = Vector2(0, 52)
	recs_btn.pressed.connect(_toggle_stats)
	v.add_child(recs_btn)
	cache_btn = Button.new(); cache_btn.text = _t("set_refresh"); cache_btn.add_theme_font_size_override("font_size", 15); cache_btn.custom_minimum_size = Vector2(0, 50)
	cache_btn.pressed.connect(_clear_cache)
	v.add_child(cache_btn)
	# смена ника (нативный браузерный ввод)
	nick_lbl = Label.new(); nick_lbl.text = _t("set_nick_lbl"); nick_lbl.add_theme_font_size_override("font_size", 14); nick_lbl.add_theme_color_override("font_color", Color("#7a7f99")); v.add_child(nick_lbl)
	save_nick_btn = Button.new(); save_nick_btn.text = _t("set_nick_btn"); save_nick_btn.add_theme_font_size_override("font_size", 15); save_nick_btn.custom_minimum_size = Vector2(0, 46)
	save_nick_btn.pressed.connect(func():
		_prompt_nick()
		_save(); _send_telemetry("nickset"); _refresh_settings(); _popup_center(_t("set_nick_saved") % nick, Color("#00f0ff")))
	v.add_child(save_nick_btn)
	settings_close = Button.new(); settings_close.text = _t("close_caps"); settings_close.add_theme_font_size_override("font_size", 16); settings_close.custom_minimum_size = Vector2(0, 50)
	settings_close.pressed.connect(func(): settings_panel.visible = false)
	v.add_child(settings_close)

# === ОКНО РЕКОРДЫ/СТАТИСТИКА (п.7) ===
func _fmt_time(sec) -> String:
	var s := int(sec)
	var h := s / 3600; var m := (s % 3600) / 60; var ss := s % 60
	if h > 0: return "%d%s %d%s" % [h, _t("hr_short"), m, _t("min_short")]
	if m > 0: return "%d%s %d%s" % [m, _t("min_short"), ss, _t("sec")]
	return "%d%s" % [ss, _t("sec")]

func _fmt_n(n) -> String:
	var v := float(n)
	var neg := v < 0.0
	v = abs(v)
	var s := ""
	if v >= 1.0e15: s = "%.2e" % v       # научная запись (1.23e+18) — большие числа idle
	elif v >= 1.0e12: s = "%.2fT" % (v / 1.0e12)
	elif v >= 1.0e9: s = "%.2fB" % (v / 1.0e9)
	elif v >= 1.0e6: s = "%.2fM" % (v / 1.0e6)
	elif v >= 1.0e3: s = "%.1fk" % (v / 1.0e3)
	else: s = str(int(round(v)))
	return ("-" if neg else "") + s

# разделитель тысяч точкой (Диана): 500000 → 500.000. Очень большие → суффикс/научно (читаемо).
func _gsep(n) -> String:
	var v := float(n)
	if abs(v) >= 1.0e9:
		return _fmt_n(v)        # миллиарды+ → 1.50B / 2.30e+15, а не каша из цифр
	var s := str(int(round(v)))
	var neg := s.begins_with("-")
	if neg: s = s.substr(1)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0: out = "." + out
	return ("-" if neg else "") + out

func _toggle_stats() -> void:
	if stats_panel == null: _build_stats()
	stats_panel.visible = not stats_panel.visible
	if stats_panel.visible: _refresh_stats()

func _build_stats() -> void:
	stats_panel = Control.new()
	stats_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	stats_panel.visible = false
	stats_panel.z_index = 3100
	hud.add_child(stats_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.995); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: stats_panel.visible = false)
	stats_panel.add_child(bg)
	var t := _lbl(_t("st_panel_title"), 22, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(0, 30); t.size = Vector2(W, 32); stats_panel.add_child(t)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 76); scroll.size = Vector2(W - 40, H - 76 - 80)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stats_panel.add_child(scroll)
	stats_box = VBoxContainer.new(); stats_box.add_theme_constant_override("separation", 8); stats_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stats_box)
	var close := Button.new(); close.text = _t("close_caps"); close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50); close.position = Vector2(W * 0.5 - 100, H - 66)
	close.pressed.connect(func(): stats_panel.visible = false); stats_panel.add_child(close)

func _stat_section(txt: String) -> void:
	var l := _lbl(txt, 16, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_LEFT)
	l.custom_minimum_size = Vector2(0, 26); stats_box.add_child(l)

func _stat_3col(name: String, run_v: String, all_v: String, col := Color("#cfe6ff")) -> void:
	var hb := HBoxContainer.new(); hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var a := _lbl(name, 15, col); a.custom_minimum_size = Vector2(250, 22); hb.add_child(a)
	var b := _lbl(run_v, 15, Color.WHITE); b.custom_minimum_size = Vector2(140, 22); b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hb.add_child(b)
	var c := _lbl(all_v, 15, Color("#9aa0a6")); c.custom_minimum_size = Vector2(140, 22); c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT; hb.add_child(c)
	stats_box.add_child(hb)

func _refresh_stats() -> void:
	for c in stats_box.get_children(): c.queue_free()
	# --- Рекорды ---
	_stat_section(_t("st_power_title"))
	_stat_3col(_t("st_combat_power"), "", _gsep(_party_power()), Color("#ff7a3a"))
	_stat_section(_t("st_rec_title"))
	_stat_3col(_t("st_best_stage"), "", str(best_stage), Color("#ffd24a"))
	_stat_3col(_t("st_max_lv"), "", str(_max_hero_level()), Color("#ffd24a"))
	_stat_3col(_t("st_prestiges"), "", str(rec_prestiges), Color("#ffd24a"))
	_stat_3col(_t("st_maxhit"), "", _fmt_n(rec_maxhit), Color("#ffd24a"))
	# --- Статистика (две колонки) ---
	_stat_section(_t("st_stats_title"))
	_stat_3col("", _t("st_col_run"), _t("st_col_all"), Color("#7a7f99"))
	_stat_3col(_t("st_mobs"), _fmt_n(stats_run["mobs"]), _fmt_n(stats_all["mobs"]))
	_stat_3col(_t("st_bosses"), _fmt_n(stats_run["bosses"]), _fmt_n(stats_all["bosses"]))
	_stat_3col(_t("st_dmg"), _fmt_n(stats_run["dmg"]), _fmt_n(stats_all["dmg"]))
	_stat_3col(_t("st_crits"), _fmt_n(stats_run["crits"]), _fmt_n(stats_all["crits"]))
	_stat_3col(_t("st_gold"), _fmt_n(stats_run["gold"]), _fmt_n(stats_all["gold"]))
	_stat_3col(_t("st_scrap"), _fmt_n(stats_run["scrap"]), _fmt_n(stats_all["scrap"]))
	_stat_3col(_t("st_cores"), _fmt_n(stats_run["cores"]), _fmt_n(stats_all["cores"]))
	_stat_3col(_t("st_time"), _fmt_time(stats_run["time"]), _fmt_time(stats_all["time"]))

func _ask_restart() -> void:
	if restart_confirm:
		restart_confirm.visible = true

func _show_offline() -> void:
	var hrs := _offline_secs / 3600
	var mins := (_offline_secs % 3600) / 60
	var away := ("%d%s %d%s" % [hrs, _t("hr_short"), mins, _t("min_short")]) if hrs > 0 else ("%d%s" % [mins, _t("min_short")])
	var panel := Control.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3200
	hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.09, 0.14, 0.99); sb.set_corner_radius_all(14); sb.set_content_margin_all(22)
	sb.border_color = Color("#00f0ff"); sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(W * 0.5 - 200, 400); card.custom_minimum_size = Vector2(400, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); card.add_child(v)
	var t := Label.new(); t.text = _t("offline_title"); t.add_theme_font_size_override("font_size", 20); t.add_theme_color_override("font_color", Color("#00f0ff")); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var d2 := Label.new(); d2.text = _t("offline_body") % [away, _gsep(_offline_gold)]; d2.add_theme_font_size_override("font_size", 16); d2.add_theme_color_override("font_color", Color("#cfe6ff")); d2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(d2)
	var b := Button.new(); b.text = _t("offline_collect"); b.add_theme_font_size_override("font_size", 17); b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(func(): panel.queue_free())
	v.add_child(b)
	_offline_gold = 0

func _build_restart_confirm() -> void:
	restart_confirm = Control.new()
	restart_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	restart_confirm.visible = false
	restart_confirm.z_index = 3500
	hud.add_child(restart_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: restart_confirm.visible = false)
	restart_confirm.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.05, 0.05, 0.99); sb.set_corner_radius_all(14); sb.set_content_margin_all(20)
	sb.border_color = Color("#ff5050"); sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(W * 0.5 - 200, 380); card.custom_minimum_size = Vector2(400, 0)
	restart_confirm.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 14); card.add_child(v)
	var t := Label.new(); t.text = _t("reset_title"); t.add_theme_font_size_override("font_size", 20); t.add_theme_color_override("font_color", Color("#ff6060")); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var d := Label.new(); d.text = _t("reset_body"); d.add_theme_font_size_override("font_size", 13); d.add_theme_color_override("font_color", Color("#c9a0a0")); d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(d)
	var yes := Button.new(); yes.text = _t("reset_yes"); yes.add_theme_font_size_override("font_size", 16); yes.custom_minimum_size = Vector2(0, 50)
	yes.pressed.connect(func(): restart_confirm.visible = false; _hard_restart())
	v.add_child(yes)
	var no := Button.new(); no.text = _t("reset_no"); no.add_theme_font_size_override("font_size", 16); no.custom_minimum_size = Vector2(0, 46)
	no.pressed.connect(func(): restart_confirm.visible = false)
	v.add_child(no)

func _hard_restart() -> void:
	if FileAccess.file_exists(_save_path()):
		DirAccess.remove_absolute(_save_path())
	_reset()

func _save() -> void:
	var hs := []
	for hh in heroes:
		hs.append({"level": hh["level"], "lvl_cost": hh["lvl_cost"], "gear": hh["gear"], "equip": hh["equip"]})
	var d := {
		"v": 1, "ts": int(Time.get_unix_time_from_system()), "nick": nick, "lang": lang, "show_dmg": show_dmg, "show_cd": show_cd, "gold": gold, "gold_ps": gold_ps, "stage": stage, "sub": sub,
		"best_stage": best_stage, "scrap": scrap, "cores": cores, "cores_peak": cores_peak, "cores_total": cores_total, "diamonds": diamonds, "x3_unlocked": x3_unlocked, "x2_until": x2_until, "gacha_pity": gacha_pity, "ad_boosts": ad_boosts, "clan_boosts": clan_boosts, "quanta": quanta, "meta_lvl": meta_lvl, "singularity_count": singularity_count, "meta_unlocked": meta_unlocked, "seen_intro": seen_intro, "bp_claimed": bp_claimed, "bp_claimed_prem": bp_claimed_prem, "bp_premium": bp_premium, "ach_claimed": ach_claimed, "daily_day": daily_day, "daily_streak": daily_streak,
		"cur_location": cur_location, "quest_done": quest_done, "tone_counts": tone_counts, "moral_choices": moral_choices, "karma": karma,
		"frag_flags": frag_flags, "case_solved": case_solved, "endgame_mode": endgame_mode, "milestones_hit": milestones_hit, "power_peak": power_peak, "player_clan": player_clan, "clan_tokens": clan_tokens, "boss_claimed": boss_claimed,
		"dq_day": dq_day, "dq_idx": dq_idx, "dq_base": dq_base, "dq_claimed": dq_claimed,
		"aug_lvl": aug_lvl, "equipped_augs": equipped_augs, "draft_offers": draft_offers, "slots_bought": slots_bought, "new_gear": new_gear, "fav": fav,
		"stats_run": stats_run, "stats_all": stats_all, "rec_maxhit": rec_maxhit, "rec_prestiges": rec_prestiges, "heroes": hs,
	}
	var f := FileAccess.open(_save_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d)); f.close()

func _arr(v) -> Array:   # хардениг: безопасный каст в Array (битый сейв с не-массивом → [], не краш)
	return v if v is Array else []

func _dct(v) -> Dictionary:   # хардениг: безопасный каст в Dictionary (битый сейв с не-словарём → {}, не краш)
	return v if v is Dictionary else {}

func _load() -> void:
	if not FileAccess.file_exists(_save_path()):
		return
	var f := FileAccess.open(_save_path(), FileAccess.READ)
	if not f:
		return
	var txt := f.get_as_text(); f.close()
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return
	# хардениг (save-фаззер): убрать null-значения (тампер/битый сейв) → d.get вернёт дефолт, не null → нет int(null)-краша
	for k in d.keys():
		if d[k] == null: d.erase(k)
	nick = str(d.get("nick", ""))
	lang = str(d.get("lang", "ru"))
	if lang != "ru" and lang != "en": lang = "ru"
	show_dmg = bool(d.get("show_dmg", true))
	show_cd = bool(d.get("show_cd", true))
	gold = float(d.get("gold", 0.0)); gold_ps = float(d.get("gold_ps", 2.0))
	stage = int(d.get("stage", 1)); sub = int(d.get("sub", 1)); in_boss = false
	best_stage = int(d.get("best_stage", 1)); scrap = int(d.get("scrap", 0)); cores = int(d.get("cores", 0)); cores_peak = float(d.get("cores_peak", 0.0)); cores_total = float(d.get("cores_total", 0.0))
	diamonds = max(int(d.get("diamonds", 999999)), 999999); x3_unlocked = bool(d.get("x3_unlocked", false)); x2_until = float(d.get("x2_until", 0.0))   # ВРЕМЕННО: всем 999999 (тест)
	gacha_pity = int(d.get("gacha_pity", 0)); ad_boosts = d.get("ad_boosts", {}); clan_boosts = d.get("clan_boosts", {})
	quanta = int(d.get("quanta", 0)); meta_lvl = d.get("meta_lvl", {}); singularity_count = int(d.get("singularity_count", 0)); meta_unlocked = bool(d.get("meta_unlocked", false))
	seen_intro = bool(d.get("seen_intro", false))
	# ВАЖНО: JSON грузит числа как float → "5 in [5.0]" = false → тиры рекламировались как незабранные (Диана: реклейм каждый заход). Коэрсим в int.
	bp_claimed = _arr(d.get("bp_claimed", [])).map(func(x): return int(x))
	bp_claimed_prem = _arr(d.get("bp_claimed_prem", [])).map(func(x): return int(x))
	bp_premium = bool(d.get("bp_premium", false))
	var ach_raw: Dictionary = _dct(d.get("ach_claimed", {}))   # защита от JSON int→float (как bp_claimed): тиры строго int
	ach_claimed = {}
	for k in ach_raw: ach_claimed[str(k)] = int(ach_raw[k])
	daily_day = int(d.get("daily_day", 0)); daily_streak = int(d.get("daily_streak", 0))
	cur_location = clamp(int(d.get("cur_location", 0)), 0, LOCATIONS.size() - 1)
	quest_done = _arr(d.get("quest_done", [])).map(func(x): return str(x))
	var tc: Dictionary = _dct(d.get("tone_counts", {}))
	for k in tone_counts: tone_counts[k] = int(tc.get(k, 0))
	moral_choices = _dct(d.get("moral_choices", {}))
	karma = int(d.get("karma", 0))
	var ff: Dictionary = _dct(d.get("frag_flags", {}))
	frag_flags = {}
	for k in ff: frag_flags[int(k)] = bool(ff[k])
	case_solved = bool(d.get("case_solved", false))
	endgame_mode = str(d.get("endgame_mode", ""))
	if endgame_mode != "" and not ENDINGS.has(endgame_mode): endgame_mode = ""   # хардениг: невалидный режим (старый сейв) → "" (иначе ENDINGS[mode] краш в меню/финале)
	milestones_hit = int(d.get("milestones_hit", 0))
	power_peak = int(d.get("power_peak", 0))
	player_clan = str(d.get("player_clan", ""))
	clan_tokens = int(d.get("clan_tokens", 0))
	boss_claimed = int(d.get("boss_claimed", 0))
	frags_notified = _frags_open()
	dq_day = int(d.get("dq_day", 0))
	dq_idx = _arr(d.get("dq_idx", [])).map(func(x): return int(x))
	# отбросить невалидные индексы (старый сейв) → _dq_refresh перезаполнит, не крашит DAILY_QUESTS[qi] (фикс пустых дейли — Диана)
	for qi in dq_idx:
		if qi < 0 or qi >= DAILY_QUESTS.size():
			dq_idx = []
			break
	dq_base = _dct(d.get("dq_base", {}))
	dq_claimed = _arr(d.get("dq_claimed", [])).map(func(x): return str(x))
	_apply_meta()
	slots_bought = int(d.get("slots_bought", 0))
	new_gear = d.get("new_gear", {})
	fav = d.get("fav", {})
	draft_offers = d.get("draft_offers", [])
	rec_maxhit = int(d.get("rec_maxhit", 0)); rec_prestiges = int(d.get("rec_prestiges", 0))
	_load_stats(stats_run, d.get("stats_run", {}))
	_load_stats(stats_all, d.get("stats_all", {}))
	equipped_augs = d.get("equipped_augs", [])
	var al := {}
	var sal = d.get("aug_lvl", {})
	for k in sal:
		al[k] = int(sal[k])
	aug_lvl = al
	var hs = d.get("heroes", [])
	for i in min(hs.size(), heroes.size()):
		var s = hs[i]
		heroes[i]["level"] = int(s.get("level", 1)); heroes[i]["lvl_cost"] = int(s.get("lvl_cost", 30))
		if s.has("gear"): heroes[i]["gear"] = _coerce_gear(s["gear"])
		if s.has("equip"): heroes[i]["equip"] = s["equip"]
		# миграция со старой экип-системы (5 слотов) → новый «module»: пересоздать
		if not heroes[i]["gear"].has("module") or not heroes[i]["equip"].has("module"):
			var ng := _new_gear(i)
			heroes[i]["gear"] = ng["gear"]; heroes[i]["equip"] = ng["equip"]
		# п.А-миграция: оружие было числом wlvl → завести стартовый weapon-предмет уровня wlvl
		if not heroes[i]["gear"].has("weapon") or not heroes[i]["equip"].has("weapon"):
			var wf = WEAPON_DEFS[i]["variants"][0]
			var wkey := _ik(wf["id"], 1)
			heroes[i]["gear"]["weapon"] = {wkey: {"vid": wf["id"], "rarity": 1, "lvl": max(1, int(s.get("wlvl", 1))), "rolls": [_primary_roll("weapon", wf["stat"])]}}
			heroes[i]["equip"]["weapon"] = wkey
	_apply_augments()
	_recalc_auras()
	for hh in heroes:
		hh["hp"] = hh["max"]
	# ОФЛАЙН-ДОХОД: пока игрок отсутствовал — начисляем золото (кап 12ч)
	if not bot:
		var last_ts := int(d.get("ts", 0))
		if last_ts > 0:
			var away: int = int(Time.get_unix_time_from_system()) - last_ts
			if away > 60:
				var capped: int = min(away, 43200)   # кап 12 часов
				var rate := _passive_rate()   # пассив (растёт со стадией) — тот же расчёт что и онлайн
				_offline_gold = int(min(rate * capped, STAT_CAP))   # кламп офлайн-дохода от int64-overflow (Godot-ресёрч)
				_offline_secs = capped
				gold += _offline_gold
	_refresh_hud()

# JSON делает числа float — возвращаем int там, где нужны индексы/счётчики
func _coerce_gear(gear: Dictionary) -> Dictionary:
	for slot in gear:
		for key in gear[slot]:
			var it = gear[slot][key]
			it["rarity"] = int(it["rarity"]); it["lvl"] = int(it["lvl"]); it["up"] = int(it.get("up", 0))
			for r in it["rolls"]:
				r["val"] = int(r["val"])
	return gear

func _start_march() -> void:
	# HP восстанавливается между боями (роли в бою, но без накопит. гринда)
	for hh in heroes:
		if not hh["alive"]:
			hh["alive"] = true
			if hh.get("fall_tw") != null and hh["fall_tw"].is_valid():
				hh["fall_tw"].kill()   # убить твин падения, иначе перетрёт сброс → «застрял мёртвым»
			var n = hh["node"]
			n.rotation = 0.0
			n.modulate = Color(1, 1, 1, 1)
		hh["hp"] = hh["max"]
	_recalc_auras()   # отряд в полном составе → ауры вернулись
	for hh in heroes:
		hh["hp"] = hh["max"]
	phase = "march"
	march_t = 2.4
	bg.speed = 220.0

# враги бьют переднюю линию первой: танк(2) → штурм(1)/хакер(3) → снайпер(0)
func _front_hero() -> Variant:
	for idx in [2, 1, 3, 0]:
		if idx < heroes.size() and heroes[idx]["alive"]:
			return heroes[idx]
	return null

# задняя линия (сквиши): снайпер → хакер → штурм → танк
func _back_hero() -> Variant:
	for idx in [0, 3, 1, 2]:
		if idx < heroes.size() and heroes[idx]["alive"]:
			return heroes[idx]
	return null

func _spawn_wave() -> void:
	var boss := in_boss
	# Сложность ФИКСИРОВАНА на стадию: все норм-волны стадии РАВНЫ по HP/урону (нет качелей внутри
	# стадии). Босс — единственный скачок. Прогресс — от стадии к стадии (6 шагов экспоненты/стадию).
	var base_idx := (stage - 1) * (STAGE_WAVES + 1)
	wave = base_idx + ((STAGE_WAVES + 1) if boss else 3)
	var pool := _enemy_pool()
	# СПИСОК на спавн: босс → [босс + СВИТА из спец-войск]; обычная волна → набор по пулу
	var spawn_types := []
	if boss:
		spawn_types.append("boss")
		for e in BOSS_ESCORTS[(stage - 1) % BOSS_ESCORTS.size()]: spawn_types.append(e)
	else:
		var count := clampi(2 + int(stage / 5), 2, 5)
		for j in count: spawn_types.append(pool[(stage * 7 + sub * 3 + j * 2) % pool.size()])
	# чиби-враги под локацию (статика): sprites/enemy_<loc>/, фолбэк на старый "enemy"
	var efolder := "enemy_" + str(_loc()["id"])
	if not ResourceLoader.exists("res://sprites/%s/idle_0.png" % efolder): efolder = "enemy"
	for j in spawn_types.size():
		var etype: String = spawn_types[j]
		var iboss: bool = etype == "boss"
		var et = ENEMY_TYPES.get(etype, ENEMY_TYPES["grunt"])
		var glow := Color("#ff2d95") if iboss else Color(et["col"])
		var es: float = 1.9 if iboss else (1.3 - j * 0.08) * et["s"]
		var d := _make_char(efolder, -1, es, glow)
		# 🏷 значок-тип над головой (грейбокс-читаемость). Контр-флип т.к. враг смотрит влево.
		var eicon: String = "" if iboss else str(et.get("icon", ""))
		if eicon != "":
			var il := Label.new(); il.text = eicon; il.add_theme_font_size_override("font_size", 13)
			il.add_theme_color_override("font_color", Color(et["col"]).lightened(0.35))
			il.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
			il.add_theme_constant_override("outline_size", 7)
			il.scale = Vector2(-1, 1); il.position = Vector2(34, -100); il.z_index = 6
			d.add_child(il)
		if not iboss and etype == "shield":   # полупрозрачный пузырь-щит
			var bub := Polygon2D.new(); bub.polygon = _ellipse_pts(42.0, 52.0); bub.color = Color(0.3, 0.62, 1.0, 0.16)
			bub.position = Vector2(0, -52); bub.z_index = -1; d.add_child(bub)
		# босс впереди-центр, СВИТА позади него (бэклайн); обычные — рядком
		var px: float = (420.0 if iboss else 506.0 + j * 50.0) if boss else 420.0 + j * 60.0
		var ey: float = GROUND_Y + 62.0 - ((0.0 if iboss else 20.0 + j * 12.0) if boss else j * 20.0)
		d.position = Vector2(720, ey); d.z_index = int(ey)
		world.add_child(d)
		var hp_stage := pow(float(_cfg("ehp", ENEMY_HP_PER_STAGE)) if bot else ENEMY_HP_PER_STAGE, stage - 1)   # бот может свипать HP-экспоненту через /tmp/bot_tactics.json (поиск sweet-spot стены)
		var boss_mult: float = BOSS_HP_CYCLE[(stage - 1) % BOSS_HP_CYCLE.size()]
		var ehp := int(min(ENEMY_HP_BASE * hp_stage * (boss_mult if iboss else et["hp"]) * aug_density, STAT_CAP))
		enemies.append({
			"node": d, "hp": ehp, "max": ehp,
			"dmg": int(min((9 if iboss else 5) * pow(float(_cfg("edmg", ENEMY_DMG_PER_STAGE)) if bot else ENEMY_DMG_PER_STAGE, stage - 1) * (1.0 if iboss else et["dmg"]), STAT_CAP)),
			"atk": (1.5 if iboss else 1.1 * et["atk"]), "t": 1.5, "alive": true, "boss": iboss,
			"type": etype, "home": Vector2(px, ey), "atk_anim": 0.0
		})
		var tw := create_tween()
		tw.tween_property(d, "position:x", px, 0.5)
	phase = "fight"
	bg.speed = 0.0
	_refresh_hud()

func _process(delta: float) -> void:
	# игрок: x2-ускорение по таймеру рекламы истекло → откат на x1 (ботов не трогаем — у них x16)
	if not bot and Engine.time_scale >= 2.0 and Engine.time_scale < 3.0 and not _x2_active():
		_set_speed(1.0)
	# нарративный пульс фарма (анти-выгорание): редкая сюжетная реплика во время гринда
	# casual-core: сюжет не лезет к игроку во время геймплея — отключено
	if false and not bot:
		pulse_t += delta
		if pulse_t >= 65.0:
			pulse_t = 0.0
			_farm_pulse()
	_fb_poll(delta)   # Firebase: дождаться анонимного uid → #ID
	_qa_poll()        # QA-мост: открыть панель по команде window._qa (скрин-сканер локализации)
	if boss_atk_cd > 0.0: boss_atk_cd -= delta
	# реклама-бусты урона/скорости истекли → пересчитать героев (золото считается живьём)
	var _adon: bool = _ad_active("dmg") or _ad_active("atk")
	if _adon != _ad_buff_on:
		_ad_buff_on = _adon
		for hh in heroes: _recalc_hero(hh)
	save_t -= delta
	if save_t <= 0.0:
		save_t = 10.0
		_save()
		print("TTSTATE t=%d stage=%d sub=%d boss=%d best=%d cores=%d scrap=%d gold=%d maxlvl=%d slots=%d/%d augs=%d" % [int(Time.get_ticks_msec() / 1000), stage, sub, (1 if in_boss else 0), best_stage, cores, scrap, int(gold), _max_hero_level(), equipped_augs.size(), _slot_total(), aug_lvl.size()])
		if bot: _bot_telemetry()
	if bot:
		_bot_tick(delta)
	else:
		tele_t -= delta
		if tele_t <= 0.0:
			tele_t = 30.0
			_send_telemetry("state")
	if phase == "dead":
		return
	var pg: float = _passive_rate() * delta   # пассивный доход (idle-кор), растёт со стадией
	gold += pg
	_stat_add("gold", pg)
	_stat_add("time", delta)   # п.7: время в игре
	if atk_buff_t > 0.0: atk_buff_t -= delta
	if hack_t > 0.0:
		hack_t -= delta
		if hack_t <= 0.0: hack_mult = 1.0
	_animate(delta)

	if phase == "march":
		march_t -= delta
		if march_t <= 0.0:
			_spawn_wave()
		return

	# FIGHT
	for hh in heroes:
		if not hh["alive"]: continue
		hh["ult_t"] = max(0.0, hh["ult_t"] - delta)
		hh["t"] -= delta
		if hh["t"] <= 0.0:
			var spd: float = aura_atk * hh["atk_mult"] * (1.4 if atk_buff_t > 0.0 else 1.0)
			var interval: float = hh["atk_spd"] / spd
			# скорость-атаки быстрее кадра → не теряем ДПС: «лишние» атаки идут в множитель урона
			if interval < delta:
				hh["hitmult"] = min(delta / max(interval, 0.00001), 1.0e6)
				hh["t"] = delta
			else:
				hh["hitmult"] = 1.0
				hh["t"] = interval
			hh["atk_interval"] = interval   # для привязки скорости анимации выстрела к скорости атаки (Рамиль)
			_hero_hit(hh)
	if auto_battle:
		_auto_cast()
	for e in enemies:
		if not e["alive"]: continue
		e["t"] -= delta
		if e["t"] <= 0.0:
			e["t"] = e["atk"]
			_enemy_hit(e)
	for hh in heroes:
		if hh["shield"] > 0.0: hh["shield"] = max(0.0, hh["shield"] - delta)
	if in_boss:
		_qte_tick(delta)

	if _all_dead(enemies) and not _all_dead(heroes):   # фикс: если 💥взрывной-последний вынес отряд — вайп важнее победы
		enemies.clear()
		if in_boss:
			# 🏆 БОСС ПРОЙДЕН → шмот (только тут!) + следующая стадия (свежий заход → авто-босс)
			print("TTEVENT bosswin stage=%d maxlvl=%d gold=%d" % [stage, _max_hero_level(), int(gold)])
			_qte_clear()
			_drop_implant()
			stage += 1
			sub = 1
			in_boss = false
			boss_retry = false
			_popup_center(_t("stage_cleared") % (stage - 1), Color("#ffd24a"))
			best_stage = max(best_stage, stage)
			_update_power_peak()   # пик-мощь для клан-боссов (prestige-proof)
			if _frags_open() > frags_notified:
				frags_notified = _frags_open()
				# casual-core: нарративное уведомление фрагмента не лезет к игроку (сюжет — опционально через меню)
				# _popup_center(_t("memory_fragment"), Color("#ff2d95"), 2.6)
			# РУБЕЖИ: celebration-награда каждые 10 стадий (positive reinforcement, лом+алмазы, БЕЗ DPS-спайка)
			var ms := int(best_stage / 10)
			if ms > milestones_hit:
				milestones_hit = ms
				var msc := ms * 300
				var msd := ms * 4
				scrap += msc; diamonds += msd
				_popup_center(_t("milestone_stage") % [ms * 10, msc, msd], Color("#ffd24a"), 2.8)
			_check_quest_complete()   # сюжетный квест локации: предмет упал с босса
			_start_march()
		elif sub < STAGE_WAVES:
			sub += 1                          # идём по волнам стадии
			_start_march()
		elif not boss_retry:
			in_boss = true                    # волны 1-4 зачищены, свежий заход → АВТО на босса
			_start_march()
		else:
			_start_march()                    # режим ретрая: фармим волну 4, к боссу по кнопке
	elif _all_dead(heroes):
		# ☠ ВАЙП → НЕ рестарт: откат на фарм стадии (отряд воскреснет), шмот цел
		if in_boss:
			print("TTEVENT bossloss stage=%d maxlvl=%d gold=%d" % [stage, _max_hero_level(), int(gold)])
			boss_retry = true                 # теперь к боссу — по КНОПКЕ
		# 💡 КОУЧ-ПОДСКАЗКА: от чего вайпнулись → кого качать (на 2-й+ вайп на стадии — значит застрял)
		if not bot:
			if stage == last_wipe_stage: wipe_streak += 1
			else: wipe_streak = 1; last_wipe_stage = stage
			if wipe_streak >= 2:
				var th := {}
				for e in enemies: th[e.get("type", "")] = true
				var hint := _t("hint_tank")
				if "healer" in th or "shield" in th: hint = _t("hint_sniper")
				elif "swarm" in th: hint = _t("hint_hacker")
				elif "bomber" in th: hint = _t("hint_bomber")
				_popup_center(hint, Color("#ffd24a"), 3.8)
		for e in enemies:                     # ФИКС стака: убрать оставшихся врагов перед откатом
			if e["node"]: e["node"].queue_free()
		enemies.clear()
		_show_death(in_boss)
		_qte_clear()
		in_boss = false
		sub = STAGE_WAVES if boss_retry else 1   # ретрай — крутимся на последней волне
		_start_march()
	_refresh_hud()

# СНАЙПЕР авто-фокусит приоритет: хилер > щитоносец > бэклайн-стрелок > остальные (Рамиль — «контр» работает сам)
func _priority_target(arr: Array):
	var prio := {"healer": 4, "shield": 3, "archer": 2}
	var best = null; var bestp := -1
	for e in arr:
		if not e["alive"]: continue
		var p: int = prio.get(e.get("type", ""), 0)
		if p > bestp: bestp = p; best = e
	return best if best != null else _first_alive(arr)

func _hero_hit(hh: Dictionary) -> void:
	var e = _priority_target(enemies) if hh["data"]["atk_type"] == "snipe" else _first_alive(enemies)
	if e == null: return
	hh["atk_anim"] = 0.2   # короткий резкий выстрел 0.2с (схема Рамиля); между выстрелами — боевая стойка (idle)
	var base := int(round(min(hh["dmg"] * aura_dmg * hack_mult * hh.get("hitmult", 1.0), STAT_CAP)))   # ×hitmult: overflow скорости-атаки → урон
	var crit_ch: float = hh["crit"]   # база крит + надетые шмотки
	var is_crit: bool = randf() < crit_ch
	if is_crit: base = int(min(float(base) * hh.get("critx", hh["data"]["critx"]), STAT_CAP))   # кламп критового урона от INF/overflow (баг-хант R3)
	if hh["data"]["atk_type"] == "aoe":
		# ХАКЕР: взлом — бьёт ВСЕХ врагов по чуть-чуть
		for en in enemies:
			if en["alive"]:
				_deal(hh, en, max(1, int(base * 0.55)), is_crit)
	else:
		_deal(hh, e, base, is_crit)   # снайпер/штурм/танк — одна цель

func _stat_add(k: String, n) -> void:   # п.7: накопить и в текущий забег, и за всё время
	stats_run[k] = stats_run.get(k, 0) + n
	stats_all[k] = stats_all.get(k, 0) + n

func _zero_stats(d: Dictionary) -> void:
	for k in d.keys():
		d[k] = 0.0 if k in ["dmg", "gold", "time"] else 0

func _load_stats(dst: Dictionary, src) -> void:
	if typeof(src) != TYPE_DICTIONARY:
		return
	for k in dst.keys():
		if src.has(k):
			dst[k] = float(src[k]) if k in ["dmg", "gold", "time"] else int(src[k])

func _deal(hh: Dictionary, e: Dictionary, d: int, is_crit := false) -> void:
	e["hp"] = max(0, e["hp"] - d)
	_stat_add("dmg", d)                     # п.7: статистика урона/критов/рекорд удара
	if is_crit: _stat_add("crits", 1)
	if d > rec_maxhit: rec_maxhit = d
	var col: Color = Color("#ffe14d") if is_crit else hh["data"]["color"]
	var sz := 38 if is_crit else 26
	if show_dmg:
		_popup(str(d) + ("!" if is_crit else ""), col, e["node"].position + Vector2(randf_range(-10, 10), -86), sz)
	if e["hp"] <= 0 and e["alive"]:
		e["alive"] = false
		var kg: float = (50.0 if e.get("boss", false) else 5.0) * pow(GOLD_PER_STAGE, stage - 1) * aug_gold * _ad_mult("gold") * _clan_boost_mult("gold")   # ×бусты золота
		gold += kg
		_stat_add("gold", kg)
		if e.get("boss", false): _stat_add("bosses", 1)
		else: _stat_add("mobs", 1)
		# 💥 ВЗРЫВНОЙ: при смерти бьёт ПО ОТРЯДУ (контр для танк/HP-билдов)
		if e.get("type", "") == "bomber":
			_popup("💥", Color("#ff7a2d"), e["node"].position + Vector2(0, -40), 34)
			var bdmg := int(e["dmg"] * 2.5)
			var any_died := false
			for ph in heroes:
				if ph["alive"]:
					ph["hp"] = max(0, ph["hp"] - bdmg)
					if ph["hp"] <= 0:
						ph["alive"] = false; ph["fall_tw"] = _fall(ph["node"]); any_died = true
			if any_died: _recalc_auras()
		_fall_enemy(e["node"])

func _enemy_hit(e: Dictionary) -> void:
	var et: String = e.get("type", "grunt")
	# ЛЕКАРЬ: вместо удара хилит раненого союзника-врага
	if et == "healer":
		for o in enemies:
			if o["alive"] and o != e and o["hp"] < o["max"]:
				e["atk_anim"] = 0.18
				var heal: int = int(o["max"] * 0.12)
				o["hp"] = min(o["max"], o["hp"] + heal)
				_popup("+" + str(heal), Color("#3ad97a"), o["node"].position + Vector2(0, -86))
				return
		# некого хилить → бьёт как обычный
	# СТРЕЛОК бьёт ЗАДНЮЮ линию (мимо танка), остальные — фронт
	var hh = _back_hero() if et == "archer" else _front_hero()
	if hh == null: return
	e["atk_anim"] = 0.18
	var dmg: int = e["dmg"]
	if hh["shield"] > 0.0: dmg = int(dmg * 0.4)
	hh["hp"] = max(0, hh["hp"] - dmg)
	_popup("-" + str(dmg), Color("#ff4d4d"), hh["node"].position + Vector2(0, -86))
	if hh["hp"] <= 0 and hh["alive"]:
		hh["alive"] = false
		hh["fall_tw"] = _fall(hh["node"])
		_recalc_auras()   # пал боец → пропала его аура

func _use_ult(i: int) -> void:
	if phase != "fight": return
	var hh = heroes[i]
	if not hh["alive"] or hh["ult_t"] > 0.0: return
	if hh["data"]["ult"] == "burst":
		# СНАЙПЕР: вход в режим прицела (ульта тратится при выстреле)
		aim_mode = true
		aim_hero = hh
		status_label.text = _t("pick_target")
		status_label.modulate = hh["data"]["color"]
		return
	hh["ult_t"] = hh["ult_cd_eff"]
	hh["atk_anim"] = 0.25
	match hh["data"]["ult"]:
		"barrage":
			atk_buff_t = 6.0   # ШТУРМ: всем +скорость атаки (без текста — шум)
		"shield":
			for h2 in heroes:   # ТАНК: щит+хил команде
				if h2["alive"]:
					h2["shield"] = 4.0
					h2["hp"] = min(h2["max"], h2["hp"] + 30)
		"hack":
			for en in enemies:  # ХАКЕР: плюха по всем
				if en["alive"]:
					_deal(hh, en, int(hh["dmg"] * 5 * aura_dmg * hack_mult))
			hack_mult = 1.2; hack_t = 5.0   # ВЗЛОМ: отряд бьёт +20% урона 5 сек (Рамиль)
			_popup_center(_t("hack_done"), Color("#ff2d95"), 1.8)
	_refresh_hud()

# выстрел снайпер-ульты по цели (общий для ручного тапа и авто-боя)
func _sniper_fire(sn, target) -> void:
	if sn["ult_t"] > 0.0 or not sn["alive"]: return   # фикс дабл-каста: не стрелять на КД или мёртвым (баг-хант R2)
	sn["ult_t"] = sn["ult_cd_eff"]
	sn["atk_anim"] = 0.25
	var d := int(sn["dmg"] * 12 * aura_dmg)
	_deal(sn, target, d, true)
	if show_dmg:
		_popup(str(d), Color("#00f0ff"), target["node"].position + Vector2(0, -115), 46)   # без эмодзи (шрифт рисовал □)

# приоритетная цель для авто: передовой враг (ближе всех к отряду = меньший x)
func _pick_enemy():
	var best = null
	var bx := 1e9
	for e in enemies:
		if e["alive"] and e["node"].position.x < bx:
			bx = e["node"].position.x; best = e
	return best

# АВТОБОЙ: каждый готовый герой применяет ульту сам; снайпер бьёт по приоритетной цели
func _auto_cast() -> void:
	for i in heroes.size():
		var hh = heroes[i]
		if not hh["alive"] or hh["ult_t"] > 0.0:
			continue
		if hh["data"]["ult"] == "burst":
			var tgt = _pick_enemy()
			if tgt:
				_sniper_fire(hh, tgt)
		else:
			_use_ult(i)
	_refresh_hud()

func _go_boss() -> void:
	if in_boss or phase == "dead" or not boss_retry:
		return   # кнопка работает только в режиме ретрая (свежий заход = авто)
	in_boss = true
	qte_t = 4.0; qte_seq = 0
	_qte_clear()
	for e in enemies:
		if e["node"]: e["node"].queue_free()
	enemies.clear()
	_start_march()   # следующий спавн = босс (in_boss=true)
	_refresh_hud()

func _qte_clear() -> void:
	for m in qte_markers:
		if is_instance_valid(m["node"]): m["node"].queue_free()
	qte_markers.clear()

# QTE: серия маркеров появляется ПО ОДНОМУ в рандомные моменты, окно жизни СЖИМАЕТСЯ к концу серии
func _qte_tick(delta: float) -> void:
	var boss = null
	for e in enemies:
		if e.get("boss", false) and e["alive"]:
			boss = e; break
	if boss == null:
		_qte_clear(); qte_seq = 0
		return
	var active := qte_seq > 0 or not qte_markers.is_empty()
	if active:
		# таймеры жизни активных маркеров (истёк = мимо)
		for m in qte_markers.duplicate():
			m["life"] -= delta
			if m["life"] <= 0.0:
				if is_instance_valid(m["node"]): m["node"].queue_free()
				qte_markers.erase(m)
		# спавн следующего маркера серии
		if qte_seq > 0:
			qte_spawn_t -= delta
			if qte_spawn_t <= 0.0:
				_qte_make_marker()
				qte_idx += 1
				qte_seq -= 1
				qte_spawn_t = randf_range(0.35, 0.8)
		if qte_seq == 0 and qte_markers.is_empty():
			_qte_resolve(boss)
	else:
		qte_t -= delta
		if qte_t <= 0.0:
			qte_seq = 5; qte_idx = 0; qte_total = 5; qte_hits = 0; qte_spawn_t = 0.0
			_popup_center(_t("qte_start"), Color("#ffd24a"))

func _qte_make_marker() -> void:
	var life: float = max(0.45, 1.25 - qte_idx * 0.16) + aug_qte   # окно сжимается, аугмент удлиняет
	var pos := Vector2(randf_range(80, W - 150), randf_range(250, 600))
	var m := Button.new()
	m.custom_minimum_size = Vector2(74, 74); m.size = Vector2(74, 74)
	m.position = pos
	m.pivot_offset = Vector2(37, 37)
	m.text = "⚡"; m.add_theme_font_size_override("font_size", 34)
	m.z_index = 300
	var msb := StyleBoxFlat.new()
	msb.bg_color = Color(0.0, 0.94, 1.0, 0.4); msb.set_corner_radius_all(37)
	msb.border_color = Color("#fff7c0"); msb.set_border_width_all(4)
	for st in ["normal", "hover", "pressed", "focus"]:
		m.add_theme_stylebox_override(st, msb)
	var entry := {"node": m, "life": life}
	m.pressed.connect(func(): _qte_marker_hit(entry))
	hud.add_child(m)
	qte_markers.append(entry)
	var tw := create_tween().set_loops(12)   # вспышка-пульс (конечно — без infinite-loop на ускорении)
	tw.tween_property(m, "scale", Vector2(1.2, 1.2), 0.18)
	tw.tween_property(m, "scale", Vector2(0.92, 0.92), 0.18)

func _qte_marker_hit(entry: Dictionary) -> void:
	if not entry in qte_markers:
		return
	qte_markers.erase(entry)
	if is_instance_valid(entry["node"]): entry["node"].queue_free()
	qte_hits += 1
	var boss = null
	for e in enemies:
		if e.get("boss", false) and e["alive"]:
			boss = e; break
	if boss != null:
		var sq := 0
		for hh in heroes:
			if hh["alive"]: sq += int(hh["dmg"])
		var d: int = int(boss["max"] * 0.03) + sq * 2
		var att = _first_alive(heroes)
		if att != null: _deal(att, boss, d, true)
		else: boss["hp"] = max(0, boss["hp"] - d)

func _qte_resolve(boss) -> void:
	_qte_clear()
	qte_t = 4.5
	if boss == null:
		return
	if qte_hits >= qte_total and qte_total > 0:
		_popup_center(_t("qte_perfect") % [qte_hits, qte_total], Color("#00f0ff"))
	elif qte_hits == 0:
		var fh = _front_hero()       # прозевал всё → босс бьёт тяжело
		if fh != null:
			var dmg: int = int(boss["dmg"] * 2.5)
			fh["hp"] = max(0, fh["hp"] - dmg)
			_popup(str(dmg), Color("#ff3030"), fh["node"].position + Vector2(0, -90), 34)
			if fh["hp"] <= 0:
				fh["alive"] = false; fh["fall_tw"] = _fall(fh["node"]); _recalc_auras()
	else:
		_popup_center(_t("qte_counter") % [qte_hits, qte_total], Color("#ffd24a"))

func _toggle_auto() -> void:
	auto_battle = not auto_battle
	auto_btn.text = "AUTO ✅" if auto_battle else "AUTO ⬜"   # текст вместо иконки; состояние видно
	auto_btn.modulate = Color(1.4, 1.4, 0.5) if auto_battle else Color(0.7, 0.7, 0.7)
	if auto_battle and aim_mode:   # включили во время ручного прицела — выходим из него
		aim_mode = false; aim_hero = null; status_label.text = ""

# тап по врагу в режиме прицела снайпера → мощный выстрел в него
func _unhandled_input(event: InputEvent) -> void:
	if not aim_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos := get_global_mouse_position()
		var best = null
		var bd := 130.0
		for e in enemies:
			if e["alive"]:
				var dd: float = e["node"].position.distance_to(pos)
				if dd < bd:
					bd = dd; best = e
		if best and aim_hero != null:
			_sniper_fire(aim_hero, best)
		aim_mode = false
		aim_hero = null
		status_label.text = ""
		_refresh_hud()

func _die() -> void:
	phase = "dead"
	status_label.text = _t("squad_down_wave") % wave
	status_label.modulate = Color("#ff4d4d")

# --- АНИМАЦИЯ БОЛВАНЧИКОВ ---
func _animate(delta: float) -> void:
	var t := Time.get_unix_time_from_system()
	for hh in heroes:
		_anim_doll(hh, t, phase == "march", delta)
	for e in enemies:
		_anim_doll(e, t, false, delta)

func _anim_doll(o: Dictionary, t: float, marching: bool, delta: float) -> void:
	var d = o["node"]
	if not is_instance_valid(d): return
	if o["atk_anim"] > 0.0:
		o["atk_anim"] = max(0.0, o["atk_anim"] - delta)
	var spr: AnimatedSprite2D = d.get_node("Spr")
	if o["alive"]:
		# 4 состояния (Рамиль): атака → ходьба → боевая-стойка (бой идёт) → спокойный idle
		var has_stance: bool = spr.sprite_frames.has_animation("stance")
		var in_fight: bool = not _all_dead(enemies) and not _all_dead(heroes)
		var want: String
		if o["atk_anim"] > 0.0:
			want = "hit"
		elif marching:
			want = "walk"
		elif has_stance and in_fight:
			want = "stance"
		else:
			want = "idle"
		if spr.animation != want:
			spr.play(want)
		spr.speed_scale = 1.0
		spr.position.x = (o["atk_anim"] / 0.2) * 6.0   # лёгкий выпад-отдача вперёд на время выстрела (local +x = к врагу)
	# hp-бар над головой — только если ранен (и не босс: у него полоса сверху)
	var hbg: ColorRect = d.get_node("HpBg")
	var bar: ColorRect = d.get_node("HpFill")
	var wounded: bool = o["alive"] and o["hp"] < o["max"] and not o.get("boss", false)
	hbg.visible = wounded
	bar.visible = wounded
	bar.size.x = 40.0 * (float(o["hp"]) / float(o["max"]))

# --- УТИЛЫ ---
func _first_alive(arr: Array):
	for x in arr:
		if x["alive"]: return x
	return null

func _all_dead(arr: Array) -> bool:
	for x in arr:
		if x["alive"]: return false
	return true

func _fall(node: Node2D) -> Tween:   # герои: падают/блёкнут (воскрешаются; твин убивается при воскрешении)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "rotation", 1.4, 0.3)
	tw.tween_property(node, "modulate:a", 0.25, 0.3)
	return tw

func _fall_enemy(node: Node2D) -> void:   # враги: падают и ИСЧЕЗАЮТ (труп убирается)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "rotation", 1.4, 0.35)
	tw.tween_property(node, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(node.queue_free)

func _popup(txt: String, col: Color, pos: Vector2, size := 26) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	l.z_index = 50
	world.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 50, 0.7)
	tw.tween_property(l, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(l.queue_free)

# --- КОНСТРУКТОР БОЛВАНЧИКА ---
func _make_char(folder: String, facing: int, scale: float, glow: Color) -> Node2D:
	var root := Node2D.new()
	root.scale = Vector2(facing * scale, scale)
	# неон-кружок/эллипс под ногами (цвет класса)
	var glowp := Polygon2D.new()
	glowp.name = "Glow"
	glowp.polygon = _ellipse_pts(30.0, 9.0)
	glowp.color = Color(glow.r, glow.g, glow.b, 0.38)
	glowp.position = Vector2(0, 1)
	root.add_child(glowp)
	# анимированный спрайт (CC0 RGS_Dev)
	# персонаж в кадре занимает yc 106..174 → ставим ногами на 0 (землю), крупнее
	var spr := AnimatedSprite2D.new()
	spr.name = "Spr"
	spr.sprite_frames = _frames(folder)
	spr.scale = Vector2(1.0, 1.0)
	spr.position = Vector2(0, -74.0)   # ноги (yc174) → 0, голова (yc106) → -68; размер задаёт root.scale
	spr.animation = "idle"
	spr.play("idle")
	root.add_child(spr)
	# hp-бар над головой — виден ТОЛЬКО когда ранен (управляется в _anim_doll)
	var hbg := _rect("HpBg", Vector2(-20, -86), Vector2(40, 5), Color(0, 0, 0, 0.65))
	hbg.visible = false
	root.add_child(hbg)
	var bar_col := Color("#ff4040") if facing < 0 else glow.lightened(0.1)   # враги — красный hp-бар (не путать с тип-цветом)
	var hf := _rect("HpFill", Vector2(-20, -86), Vector2(40, 5), bar_col)
	hf.visible = false
	root.add_child(hf)
	return root

func _frames(folder: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for spec in [["walk", 16.0, true], ["idle", 16.0, true], ["stance", 7.0, true], ["hit", 45.0, false]]:   # 4 состояния (Рамиль): idle/walk/боевая-стойка(прицел)/быстрый-выстрел
		var anim: String = spec[0]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, spec[1])
		sf.set_animation_loop(anim, spec[2])
		var i := 0
		while true:
			var path := "res://sprites/%s/%s_%d.png" % [folder, anim, i]
			if not ResourceLoader.exists(path):
				break
			sf.add_frame(anim, load(path))
			i += 1
	return sf

func _ellipse_pts(rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _rect(nm: String, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = nm; r.position = pos; r.size = size; r.color = col
	return r

# --- HUD ---
func _refresh_hud() -> void:
	var etypes := {}
	for e in enemies:
		if e["alive"] and not e.get("boss", false):
			etypes[_tloc(ENEMY_TYPES.get(e.get("type", "grunt"), ENEMY_TYPES["grunt"]), "name")] = true
	wave_label.text = ("%s %d · 👹 %s" % [_t("hud_stage"), stage, _t("hud_boss")] if in_boss else "%s %d · %s %d/%d" % [_t("hud_stage"), stage, _t("hud_wave"), sub, STAGE_WAVES]) + ("   ⚔" if phase == "fight" else "   ▶")
	if boss_btn:
		boss_btn.visible = boss_retry and not in_boss   # кнопка только для ретрая (свежий заход = авто)
	if impl_btn:
		var nc := 0
		for k in new_gear: nc += int(new_gear[k])   # сумма новых предметов (не слотов)
		impl_btn.text = "🦾" + ("●%d" % nc if nc > 0 else "")
		if nc > 0:
			var ph: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)   # пульс золотом
			impl_btn.modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.7, 1.4, 0.2), ph)
		else:
			impl_btn.modulate = Color(1, 1, 1)
	if more_btn:   # бейдж «Ещё» = сумма незабранных (батлпас + ачивки)
		if best_stage != _bp_cache_stage:   # перф: O(n²) счёт только при смене стадии (баг-хант R4)
			_bp_cache_stage = best_stage; _bp_badge_cache = _bp_unclaimed_count()
		var total := _bp_badge_cache + _ach_claimable() + _dq_ready_count()
		more_btn.text = "☰" + ("●%d" % total if total > 0 else "")
		more_btn.modulate = Color(1.6, 1.4, 0.3) if total > 0 else Color(1, 1, 1)
	if loot_badge:
		loot_badge.visible = new_gear.size() > 0 and not impl_open
		if loot_badge.visible:
			loot_badge.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 180.0)
	# полоса босса
	var bz = null
	for e in enemies:
		if e.get("boss", false) and e["alive"]:
			bz = e; break
	var has_boss: bool = bz != null
	boss_bg.visible = has_boss
	boss_fill.visible = has_boss
	boss_lbl.visible = has_boss
	if has_boss:
		boss_fill.size.x = (W - 66) * (float(bz["hp"]) / float(bz["max"]))
		boss_lbl.text = _t("hud_boss_warn") % [bz["hp"], bz["max"]]
	for i in heroes.size():
		var hh = heroes[i]
		var ready_ult: bool = hh["alive"] and hh["ult_t"] <= 0.0
		hero_ults[i].disabled = not ready_ult
		var cdtxt := ("⚡ " + _t("ready") if ready_ult else "⏱ %.0f%s" % [hh["ult_t"], _t("sec")]) if show_cd else ("⚡" if ready_ult else "")
		hero_ults[i].text = "%s %s\n%s" % [hh["data"]["icon"], _hname(hh["cls"]), cdtxt]
		# свечение когда ульта готова (border ignite à la AFK Arena)
		if not hh["alive"]:
			hero_ults[i].modulate = Color(0.4, 0.4, 0.4, 1)
		elif ready_ult:
			hero_ults[i].modulate = Color(1.3, 1.3, 1.3, 1)
		else:
			hero_ults[i].modulate = Color(0.85, 0.85, 0.85, 1)
		# заливка заряда ульты (снизу вверх)
		var cd: float = hh["ult_cd_eff"]
		var fill: float = clamp((cd - hh["ult_t"]) / cd, 0.0, 1.0)
		var ch: ColorRect = hero_charge[i]
		ch.size.y = 78.0 * fill
		ch.position.y = 78.0 - 78.0 * fill
		ch.color.a = 0.5 if ready_ult else 0.22
		# hp на портрете
		hero_hp[i].size.x = 118.0 * (float(hh["hp"]) / float(hh["max"]))
		hero_hp[i].visible = hh["alive"]
	# прогресс стадии: STAGE_WAVES норм-волн + ворота-босс
	var flags := ""
	for k in range(1, STAGE_WAVES + 1):
		flags += "▪" if k <= sub else "▫"
	flags += "  👹" if in_boss else "  ▷"
	var etxt: String = ("   ⟨%s⟩" % ", ".join(etypes.keys())) if etypes.size() > 0 else ""
	stage_label.text = flags + etxt   # типы врагов — на строке флажков (не налезают на кнопки)
	# золото + прокачка урона
	gold_label.text = "💰 %s  +%s%s   ♻ %s   🧬 %s   💎 %s" % [_gsep(gold), _gsep(_passive_rate()), _t("per_sec"), _gsep(scrap), _gsep(cores), _gsep(diamonds)]
	if inv_open and inv_gold:
		inv_gold.text = "💰 %s   +%s%s    💪 %s: %s" % [_gsep(gold), _gsep(_passive_rate()), _t("per_sec"), _t("power"), _gsep(_party_power())]
	if inv_open: _refresh_inv()
	if impl_open: _refresh_impl()

func _build() -> void:
	# фон
	bg = preload("res://parallax.gd").new()
	add_child(bg)
	# мир болванчиков
	world = Node2D.new()
	add_child(world)
	# HUD поверх
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)

	wave_label = Label.new()
	wave_label.add_theme_color_override("font_color", Color("#ffb02e"))
	wave_label.add_theme_font_size_override("font_size", 22)
	wave_label.position = Vector2(66, 16)
	hud.add_child(wave_label)

	# полоса HP босса вверху (появляется в босс-волне)
	boss_bg = ColorRect.new()
	boss_bg.color = Color(0, 0, 0, 0.55)
	boss_bg.position = Vector2(30, 50); boss_bg.size = Vector2(W - 60, 22)
	boss_bg.visible = false
	hud.add_child(boss_bg)
	boss_fill = ColorRect.new()
	boss_fill.color = Color("#ff2d95")
	boss_fill.position = Vector2(33, 53); boss_fill.size = Vector2(W - 66, 16)
	boss_fill.visible = false
	hud.add_child(boss_fill)
	boss_lbl = Label.new()
	boss_lbl.add_theme_color_override("font_color", Color("#ffffff"))
	boss_lbl.add_theme_font_size_override("font_size", 13)
	boss_lbl.position = Vector2(36, 52)
	boss_lbl.visible = false
	hud.add_child(boss_lbl)

	# кнопка скорости x1/x2/x3 (idle-must)
	speed_btn = Button.new()
	speed_btn.text = "⏩ x1"
	speed_btn.add_theme_font_size_override("font_size", 16)
	speed_btn.custom_minimum_size = Vector2(74, 40)
	speed_btn.position = Vector2(W - 88, 150)   # фидбэк Рамиля: скорость НАВЕРХ (редкая кнопка, не нужна у пальца)
	speed_btn.pressed.connect(_cycle_speed)
	hud.add_child(speed_btn)
	# тумблер АВТОБОЯ — текст «AUTO» рядом со скоростью (наверху, слева от speed_btn)
	auto_btn = Button.new()
	auto_btn.text = "AUTO ⬜"
	auto_btn.add_theme_font_size_override("font_size", 14)
	auto_btn.custom_minimum_size = Vector2(86, 40)
	auto_btn.position = Vector2(W - 178, 150)   # слева от кнопки скорости
	auto_btn.modulate = Color(0.7, 0.7, 0.7)
	auto_btn.pressed.connect(_toggle_auto)
	hud.add_child(auto_btn)
	# кнопка «К БОССУ» (ворота стадии) — видна в фарм-режиме
	boss_btn = Button.new()
	boss_btn.text = _t("to_boss")
	boss_btn.add_theme_font_size_override("font_size", 17)
	boss_btn.custom_minimum_size = Vector2(190, 42)
	boss_btn.position = Vector2(W * 0.5 - 95, 60)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(0.32, 0.05, 0.14, 0.96); bsb.set_corner_radius_all(10)
	bsb.border_color = Color("#ff2d95"); bsb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		boss_btn.add_theme_stylebox_override(st, bsb)
	boss_btn.pressed.connect(_go_boss)
	hud.add_child(boss_btn)
	# прогресс этапа (флажки до босса)
	stage_label = Label.new()
	stage_label.add_theme_color_override("font_color", Color("#7a7f99"))
	stage_label.add_theme_font_size_override("font_size", 15)
	stage_label.position = Vector2(20, 80)
	hud.add_child(stage_label)
	loot_badge = Label.new()
	loot_badge.text = _t("new_loot")
	loot_badge.add_theme_color_override("font_color", Color("#ffd24a"))
	loot_badge.add_theme_font_size_override("font_size", 16)
	loot_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	loot_badge.position = Vector2(W - 230, 78); loot_badge.size = Vector2(220, 22)
	loot_badge.visible = false
	hud.add_child(loot_badge)

	gold_label = Label.new()
	gold_label.add_theme_color_override("font_color", Color("#ffe14d"))
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.position = Vector2(20, 104)
	hud.add_child(gold_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(W * 0.5 - 200, 70)
	status_label.custom_minimum_size = Vector2(400, 0)
	status_label.size = Vector2(400, 30)
	hud.add_child(status_label)

	# панель портретов-кнопок ульт снизу (канон auto-battler: портрет = кнопка ульты)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.position = Vector2(0, H - 150)
	bar.size = Vector2(W, 84)
	hud.add_child(bar)
	hero_ults.clear(); hero_hp.clear(); hero_charge.clear()
	for i in HEROES.size():
		var h = HEROES[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(134, 78)
		b.add_theme_font_size_override("font_size", 14)
		b.clip_contents = true
		var idx := i
		b.pressed.connect(func(): _use_ult(idx))
		# заряд ульты — заливка снизу (цвет класса), управляется в _refresh_hud
		var ch := ColorRect.new()
		ch.color = Color(h["color"].r, h["color"].g, h["color"].b, 0.22)
		ch.position = Vector2(0, 78); ch.size = Vector2(134, 0)
		ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(ch)
		# hp-полоска сверху портрета (цвет класса)
		var hbg := ColorRect.new(); hbg.color = Color(0, 0, 0, 0.5)
		hbg.position = Vector2(8, 6); hbg.size = Vector2(118, 7)
		hbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hbg)
		var hpf := ColorRect.new(); hpf.color = h["color"]
		hpf.position = Vector2(8, 6); hpf.size = Vector2(118, 7)
		hpf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hpf)
		bar.add_child(b)
		hero_ults.append(b); hero_hp.append(hpf); hero_charge.append(ch)

	# === НИЖНИЙ БАР МЕНЮ: Прокачка / Экипировка / Настройки ===
	var menubar := HBoxContainer.new()
	menubar.add_theme_constant_override("separation", 8)
	menubar.alignment = BoxContainer.ALIGNMENT_CENTER
	menubar.position = Vector2(0, H - 56); menubar.size = Vector2(W, 50)
	hud.add_child(menubar)
	# UI-редизайн: навбар 4 кнопки (иконка + подпись), остальное в «☰ Ещё»
	# UI: иконки вместо текста (универсально, без перевода — идея Рамиля)
	inv_btn = Button.new()
	inv_btn.text = "📊"
	inv_btn.tooltip_text = _t("tab_upgrade")
	inv_btn.add_theme_font_size_override("font_size", 26)
	inv_btn.custom_minimum_size = Vector2(112, 48)
	inv_btn.pressed.connect(_toggle_inv)
	menubar.add_child(inv_btn)
	impl_btn = Button.new()
	impl_btn.text = "🦾"
	impl_btn.tooltip_text = _t("tab_gear")
	impl_btn.add_theme_font_size_override("font_size", 26)
	impl_btn.custom_minimum_size = Vector2(112, 48)
	impl_btn.pressed.connect(_toggle_impl)
	menubar.add_child(impl_btn)
	var reboot_mb := Button.new()
	reboot_mb.text = "♻"
	reboot_mb.tooltip_text = _t("tab_prestige")
	reboot_mb.add_theme_font_size_override("font_size", 26)
	reboot_mb.custom_minimum_size = Vector2(112, 48)
	reboot_mb.pressed.connect(_toggle_reboot)
	menubar.add_child(reboot_mb)
	more_btn = Button.new()
	more_btn.text = "☰"
	more_btn.tooltip_text = _t("tab_more")
	more_btn.add_theme_font_size_override("font_size", 26)
	more_btn.custom_minimum_size = Vector2(112, 48)
	more_btn.pressed.connect(_open_more)
	menubar.add_child(more_btn)
	_build_inventory()
	_build_implants()
	_build_invcol()
	_build_reboot()
	_build_restart_confirm()

	# === РЕСТАРТ — в левом верхнем углу (слева от «ВОЛНА»), чтоб не задеть случайно ===
	var restart := Button.new()
	restart.text = "↻"
	restart.add_theme_font_size_override("font_size", 18)
	restart.custom_minimum_size = Vector2(46, 32)
	restart.position = Vector2(10, 14)
	restart.pressed.connect(_ask_restart)
	hud.add_child(restart)

# x2 активна (выдана за рекламу, таймер) / x3 куплена навсегда
func _x2_active() -> bool:
	return x2_until > Time.get_unix_time_from_system()

func _set_speed(v: float) -> void:
	if v >= 3.0 and not x3_unlocked: return
	if v >= 2.0 and v < 3.0 and not _x2_active(): return
	Engine.time_scale = v
	speed_btn.text = "⏩ x%d" % int(v)

func _cycle_speed() -> void:
	# открыть меню скорости (монетизация: x1 беспл / x2 реклама / x3 алмазы)
	_open_speed_menu()

func _open_speed_menu() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.07, 0.09, 0.16, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#00f0ff"); sb.set_border_width_all(2); sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 200, 180); card.custom_minimum_size = Vector2(400, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	v.add_child(_lbl(_t("spd_title") % diamonds, 18, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := Button.new(); b1.text = _t("spd_x1"); b1.custom_minimum_size = Vector2(0, 46); b1.add_theme_font_size_override("font_size", 15)
	b1.pressed.connect(func(): _set_speed(1.0); panel.queue_free()); v.add_child(b1)
	var b2 := Button.new(); b2.custom_minimum_size = Vector2(0, 46); b2.add_theme_font_size_override("font_size", 15)
	if _x2_active(): b2.text = _t("spd_x2_active") % int((x2_until - Time.get_unix_time_from_system()) / 60.0); b2.pressed.connect(func(): _set_speed(2.0); panel.queue_free())
	else: b2.text = _t("spd_x2_ad"); b2.pressed.connect(func(): _watch_ad_x2(); panel.queue_free())
	v.add_child(b2)
	var b3 := Button.new(); b3.custom_minimum_size = Vector2(0, 46); b3.add_theme_font_size_override("font_size", 15)
	if x3_unlocked: b3.text = _t("spd_x3_bought"); b3.pressed.connect(func(): _set_speed(3.0); panel.queue_free())
	else: b3.text = _t("spd_x3_buy"); b3.disabled = diamonds < 100; b3.pressed.connect(func(): _buy_x3(); panel.queue_free())
	v.add_child(b3)
	var bab := Button.new(); bab.text = _t("ad_bonuses"); bab.custom_minimum_size = Vector2(0, 44); bab.add_theme_font_size_override("font_size", 14); bab.add_theme_color_override("font_color", Color("#3ad97a"))
	bab.pressed.connect(func(): panel.queue_free(); _open_ad_boosts()); v.add_child(bab)
	var bs := Button.new(); bs.text = _t("diamond_shop"); bs.custom_minimum_size = Vector2(0, 44); bs.add_theme_font_size_override("font_size", 14); bs.add_theme_color_override("font_color", Color("#ffd24a"))
	bs.pressed.connect(func(): panel.queue_free(); _open_shop()); v.add_child(bs)
	var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(0, 40); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

func _watch_ad_x2() -> void:
	# СТАБ рекламы (на платформе — реальный rewarded-ad SDK). Сейчас выдаём сразу.
	x2_until = Time.get_unix_time_from_system() + 1800.0   # x2 на 30 мин
	_set_speed(2.0); _save()
	_popup_center(_t("spd_pop_x2"), Color("#3ad97a"), 2.0)

func _buy_x3() -> void:
	if diamonds < 100: return
	diamonds -= 100; x3_unlocked = true
	_set_speed(3.0); _save(); _refresh_hud()
	_popup_center(_t("spd_pop_x3"), Color("#b46bff"), 2.2)

# === РЕКЛАМА-БУСТЫ (Диана) ===
func _ad_active(b: String) -> bool:
	var d = ad_boosts.get(b, {})
	return float(d.get("until", 0.0)) > Time.get_unix_time_from_system()

func _ad_lvl(b: String) -> int:
	return int(ad_boosts.get(b, {}).get("lvl", 0))

# множитель активного буста (1.0 если не активен). % = base + step×(lvl-1)
func _ad_mult(b: String) -> float:
	if not _ad_active(b): return 1.0
	var lvl := _ad_lvl(b)
	var pct: float = AD_BOOST[b]["base"] + AD_BOOST[b]["step"] * (lvl - 1)
	return 1.0 + pct / 100.0

func _clan_boost_active(b: String) -> bool:
	return float(clan_boosts.get(b, {}).get("until", 0.0)) > Time.get_unix_time_from_system()

func _clan_boost_mult(b: String) -> float:
	if not _clan_boost_active(b): return 1.0
	var pct: float = {"dmg": 40.0, "gold": 100.0, "atk": 25.0}.get(b, 0.0)
	return 1.0 + pct / 100.0

func _watch_ad_boost(b: String) -> void:
	# СТАБ рекламы. Каждый просмотр: продлевает на 30 мин И поднимает уровень (выше %) — петля Дианы.
	var d = ad_boosts.get(b, {"until": 0.0, "lvl": 0})
	d["until"] = Time.get_unix_time_from_system() + AD_DUR
	d["lvl"] = min(int(d["lvl"]) + 1, 30)
	ad_boosts[b] = d
	_stat_add("ads", 1)   # ачивка: просмотры реклама-бустов
	for hh in heroes: _recalc_hero(hh)
	_save(); _refresh_hud()
	var pct: int = int(AD_BOOST[b]["base"] + AD_BOOST[b]["step"] * (int(d["lvl"]) - 1))
	_popup_center(_t("ad_apply_pop") % [_tloc(AD_BOOST[b], "name"), pct, d["lvl"]], Color("#3ad97a"), 2.2)

func _open_ad_boosts() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.05, 0.12, 0.07, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#3ad97a"); sb.set_border_width_all(2); sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 210, 150); card.custom_minimum_size = Vector2(420, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	v.add_child(_lbl(_t("ad_bonuses"), 19, Color("#3ad97a"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("ad_subtitle"), 11, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_CENTER))
	for b in ["dmg", "gold", "atk"]:
		var bb: String = b
		var lvl := _ad_lvl(b)
		var pct: int = int(AD_BOOST[b]["base"] + AD_BOOST[b]["step"] * max(0, lvl - 1 if lvl > 0 else 0))
		var nextpct: int = int(AD_BOOST[b]["base"] + AD_BOOST[b]["step"] * lvl)   # после след. просмотра
		var row := Button.new(); row.custom_minimum_size = Vector2(0, 56); row.add_theme_font_size_override("font_size", 14)
		if _ad_active(b):
			var mins := int((float(ad_boosts[b]["until"]) - Time.get_unix_time_from_system()) / 60.0)
			row.text = _t("ad_row_active") % [_tloc(AD_BOOST[b], "name"), pct, mins, lvl, nextpct]
		else:
			row.text = _t("ad_row_idle") % [_tloc(AD_BOOST[b], "name"), nextpct, lvl + 1]
		row.pressed.connect(func(): _watch_ad_boost(bb); panel.queue_free(); _open_ad_boosts())
		v.add_child(row)
	var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(0, 40); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

func _open_shop() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.10, 0.08, 0.04, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#ffd24a"); sb.set_border_width_all(2); sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 200, 150); card.custom_minimum_size = Vector2(400, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	v.add_child(_lbl(_t("shop_title") % diamonds, 18, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("shop_note"), 11, Color("#9a8fb5"), HORIZONTAL_ALIGNMENT_CENTER))
	for pack in [[100, "0.99$"], [550, "4.99$"], [1200, "9.99$"], [6500, "49.99$"]]:
		var amt: int = pack[0]
		var bp := Button.new(); bp.text = "💎 %d — %s" % [amt, pack[1]]; bp.custom_minimum_size = Vector2(0, 44); bp.add_theme_font_size_override("font_size", 15)
		bp.pressed.connect(func(): diamonds += amt; _save(); _refresh_hud(); _popup_center(_t("shop_buy_pop") % amt, Color("#ffd24a"), 1.6); panel.queue_free())
		v.add_child(bp)
	# (убрана кнопка «+10💎 ежедневный бонус» — был эксплойт спама алмазов; дейлики покрывает _show_daily)
	var bg := Button.new(); bg.text = _t("shop_gacha_btn"); bg.custom_minimum_size = Vector2(0, 46); bg.add_theme_font_size_override("font_size", 15); bg.add_theme_color_override("font_color", Color("#ff7adf"))
	bg.pressed.connect(func(): panel.queue_free(); _open_gacha()); v.add_child(bg)
	var ba := Button.new(); ba.text = _t("ad_bonuses"); ba.custom_minimum_size = Vector2(0, 46); ba.add_theme_font_size_override("font_size", 15); ba.add_theme_color_override("font_color", Color("#3ad97a"))
	ba.pressed.connect(func(): panel.queue_free(); _open_ad_boosts()); v.add_child(ba)
	var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(0, 40); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

# === ГАЧА (Фаза Б): призыв шмота за алмазы, pity ≤90, прозрачные дропрейты ===
func _gacha_rarity() -> int:
	gacha_pity += 1
	if gacha_pity >= 90:        # хард-pity: гарант Эпического
		gacha_pity = 0; return 4
	var p4 := 0.05              # софт-pity: с 74-го пулла шанс Эпического растёт
	if gacha_pity >= 74: p4 = 0.05 + (gacha_pity - 73) * 0.06
	# ОДИН roll → точные объявленные шансы 50/30/15/5 (баг-хант R3: раньше редкий выходил 19% вместо 15%)
	var r := randf()
	if r < p4: gacha_pity = 0; return 4   # Эпический 5% (+pity-рампа)
	if r < p4 + 0.50: return 1            # Обычный 50%
	if r < p4 + 0.80: return 2            # Необычный 30%
	return 3                              # Редкий 15%

func _gacha_pull(n: int) -> Array:
	var cost: int = GACHA_COST1 if n == 1 else GACHA_COST10
	if diamonds < cost: return []
	diamonds -= cost
	_stat_add("pulls", n)   # ачивка: гача-пуллы
	var results := []
	for k in n:
		var rar := _gacha_rarity()
		var i := randi() % heroes.size()
		var hh = heroes[i]
		var slot: String = "weapon" if randf() < 0.4 else "module"
		var variants := _slot_variants(slot, hh["cls"])
		var vv = variants[randi() % variants.size()]
		var key := _ik(vv["id"], rar)
		var it := _make_item(hh["cls"], vv["id"], rar, slot)
		it["lvl"] = max(1, stage)
		var g = hh["gear"][slot]
		if not g.has(key) or _item_power(it) > _item_power(g[key]):
			g[key] = it
			new_gear["%d:%s" % [i, slot]] = int(new_gear.get("%d:%s" % [i, slot], 0)) + 1
		_recalc_hero(hh)
		results.append({"hero": i, "slot": slot, "rar": rar, "name": vv["name"]})
	_save(); _refresh_hud()
	return results

func _open_gacha() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.12, 0.05, 0.13, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#ff7adf"); sb.set_border_width_all(2); sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 210, 110); card.custom_minimum_size = Vector2(420, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 9); card.add_child(v)
	v.add_child(_lbl(_t("gacha_title"), 19, Color("#ff7adf"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("gacha_pity") % [diamonds, max(0, 90 - gacha_pity)], 13, Color("#d9c7ff"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("gacha_rates"), 11, Color("#9a8fb5"), HORIZONTAL_ALIGNMENT_CENTER))
	var res := _lbl("", 13, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER); res.custom_minimum_size = Vector2(0, 90); res.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; v.add_child(res)
	var p1 := Button.new(); p1.text = _t("gacha_pull1") % GACHA_COST1; p1.custom_minimum_size = Vector2(0, 46); p1.add_theme_font_size_override("font_size", 15)
	p1.pressed.connect(func(): res.text = _gacha_result_text(_gacha_pull(1)); _gacha_refresh_hdr(v)); v.add_child(p1)
	var p10 := Button.new(); p10.text = _t("gacha_pull10") % GACHA_COST10; p10.custom_minimum_size = Vector2(0, 46); p10.add_theme_font_size_override("font_size", 15)
	p10.pressed.connect(func(): res.text = _gacha_result_text(_gacha_pull(10)); _gacha_refresh_hdr(v)); v.add_child(p10)
	var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(0, 40); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

func _gacha_refresh_hdr(v: VBoxContainer) -> void:
	# обновить строку алмазов/pity (2-й ребёнок) после пулла
	if v.get_child_count() > 1 and v.get_child(1) is Label:
		(v.get_child(1) as Label).text = _t("gacha_pity") % [diamonds, max(0, 90 - gacha_pity)]

func _gacha_result_text(results: Array) -> String:
	if results.is_empty(): return _t("gacha_no_diamonds")
	var counts := {1: 0, 2: 0, 3: 0, 4: 0}
	var best := 1
	for r in results:
		counts[r["rar"]] += 1; best = max(best, r["rar"])
	var parts := []
	for rr in [4, 3, 2, 1]:
		if counts[rr] > 0: parts.append("%s ×%d" % [_rarity_name(rr), counts[rr]])
	var head := _t("gacha_epic") if best == 4 else (_t("gacha_rare") if best == 3 else _t("gacha_got"))
	return "%s\n%s\n%s" % [head, ", ".join(parts), _t("gacha_result_foot")]

# === БАТЛПАС: награды по пройденным стадиям ===
func _bp_free_reward(m: int) -> Dictionary:
	var r := {"cores": m}                       # ядра = веха (растёт со стадией)
	if m % 25 == 0: r["diamonds"] = 30          # на круглых тирах — алмазы
	else: r["gold"] = int(min(50.0 * pow(GOLD_PER_STAGE, m), STAT_CAP))   # кламп от int64-переполнения (баг: m>218 → негатив)
	return r

func _bp_prem_reward(m: int) -> Dictionary:
	var r := {"cores": m * 3, "diamonds": 15}   # премиум: жирнее ядра + алмазы
	if m % 25 == 0: r["diamonds"] = 60
	return r

func _bp_apply(r: Dictionary) -> void:
	cores += max(0, int(r.get("cores", 0))); diamonds += max(0, int(r.get("diamonds", 0)))
	gold += max(0.0, float(r.get("gold", 0))); scrap += max(0, int(r.get("scrap", 0)))

func _bp_claim(m: int, prem: bool) -> void:
	if best_stage < m: return
	if prem:
		if not bp_premium or m in bp_claimed_prem: return
		_bp_apply(_bp_prem_reward(m)); bp_claimed_prem.append(m)
	else:
		if m in bp_claimed: return
		_bp_apply(_bp_free_reward(m)); bp_claimed.append(m)
	_bp_cache_stage = -1   # инвалидировать кэш бейджа после забора
	_save(); _refresh_hud()

func _bp_reward_text(r: Dictionary) -> String:
	var p := []
	if r.has("cores"): p.append("%d🧬" % r["cores"])
	if r.has("diamonds"): p.append("%d💎" % r["diamonds"])
	if r.has("gold"): p.append("%s💰" % _gsep(int(r["gold"])))
	return " ".join(p)

func _bp_unclaimed_count() -> int:
	var n := 0
	var m := BP_STEP
	while m <= best_stage:
		if not (m in bp_claimed): n += 1
		if bp_premium and not (m in bp_claimed_prem): n += 1
		m += BP_STEP
	return n

func _bp_claim_all() -> void:
	var m := BP_STEP
	while m <= best_stage:
		if not (m in bp_claimed): _bp_claim(m, false)
		if bp_premium and not (m in bp_claimed_prem): _bp_claim(m, true)
		m += BP_STEP

# === КАРТА ЛОКАЦИЙ (Рамиль) ===
func _open_map() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.88); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var title := _lbl(_t("map_title"), 20, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER); title.position = Vector2(0, 30); title.size = Vector2(W, 30); panel.add_child(title)
	var sub := _lbl(_t("map_sub"), 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER); sub.position = Vector2(0, 60); sub.size = Vector2(W, 20); panel.add_child(sub)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(W * 0.5 - 220, 96); scroll.custom_minimum_size = Vector2(440, 600); scroll.size = Vector2(440, 600); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 8); list.custom_minimum_size = Vector2(440, 0); scroll.add_child(list)
	for i in LOCATIONS.size():
		list.add_child(_map_card(i, panel))
	var close := Button.new(); close.text = _t("close"); close.custom_minimum_size = Vector2(200, 40)
	close.position = Vector2(W * 0.5 - 100, 712); close.pressed.connect(panel.queue_free); panel.add_child(close)

func _map_card(i: int, panel: Control) -> Control:
	var loc: Dictionary = LOCATIONS[i]
	var unlocked: bool = best_stage >= int(loc["unlock"])
	var active: bool = i == cur_location
	var qdone: bool = loc["id"] in quest_done
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.13, 0.20, 0.97) if unlocked else Color(0.06, 0.06, 0.09, 0.9)
	sb.set_corner_radius_all(10); sb.set_content_margin_all(10)
	sb.border_color = Color(loc["neon"][0]) if active else (Color("#2a3358") if unlocked else Color("#1a1d2e"))
	sb.set_border_width_all(3 if active else 1)
	box.add_theme_stylebox_override("panel", sb); box.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); box.add_child(v)
	var head := "%s %s" % [loc["icon"], _tloc(loc, "name")]
	if active: head += _t("map_here")
	if not unlocked: head += _t("map_lock") % int(loc["unlock"])
	v.add_child(_lbl(head, 16, Color(loc["neon"][0]) if unlocked else Color("#5a6a8a"), HORIZONTAL_ALIGNMENT_LEFT))
	v.add_child(_lbl(_tloc(loc, "desc"), 12, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_LEFT))
	var names := []
	for t in loc["pool"]: names.append(_tloc(ENEMY_TYPES[t], "name"))
	v.add_child(_lbl(_t("map_enemies") + ", ".join(names), 11, Color("#7a8095"), HORIZONTAL_ALIGNMENT_LEFT))
	var q: Dictionary = loc["quest"]
	var qitem := _tloc(q, "item")
	var qline := (_t("map_qdone") % qitem) if qdone else (_t("map_qget") % qitem)
	v.add_child(_lbl(qline, 11, Color("#7ee08a") if qdone else Color("#ffd24a"), HORIZONTAL_ALIGNMENT_LEFT))
	if unlocked and not active:
		var b := Button.new(); b.text = _t("map_go"); b.custom_minimum_size = Vector2(0, 34); b.add_theme_font_size_override("font_size", 13)
		var ii := i
		b.pressed.connect(func(): _go_location(ii); panel.queue_free())
		v.add_child(b)
	return box

func _go_location(i: int) -> void:
	cur_location = clamp(i, 0, LOCATIONS.size() - 1)
	_apply_location_theme()
	_save(); _refresh_hud()
	var loc := _loc()
	_popup_center("%s %s" % [loc["icon"], _tloc(loc, "name")], Color(loc["neon"][0]), 1.6)
	# квест-чат: фиксер пишет задание в мессенджер (идея Рамиля)
	if not (str(loc["id"]) in quest_done):
		_popup_center(_t("map_new_msg") % _tloc(loc["quest"], "contact"), Color("#3ad97a"), 1.8)
		_open_quest_chat(cur_location)
	else:
		# farm-эхо: район реагирует на твои прошлые решения
		var lid := str(loc["id"])
		if lid == "slums" and str(moral_choices.get("batch", "")) == "b":
			_popup_center(_t("echo_slums_b"), Color("#ff7050"), 2.4)
		elif lid == "slums" and str(moral_choices.get("batch", "")) == "a":
			_popup_center(_t("echo_slums_a"), Color("#7ee08a"), 2.4)
		elif lid == "corp" and str(moral_choices.get("holt", "")) == "b":
			_popup_center(_t("echo_corp_b"), Color("#ff7050"), 2.4)
		elif lid == "docks" and str(moral_choices.get("bosun", "")) == "a":
			_popup_center(_t("echo_docks_a"), Color("#7ee08a"), 2.4)

func _apply_location_theme() -> void:
	if is_instance_valid(bg) and bg.has_method("set_palette"):
		bg.set_palette(_loc()["neon"], _loc()["ground"])
		# рисованные фон+дорога локации (если есть ассеты) — иначе процедурный фолбэк
		var lid: String = _loc()["id"]
		var bgp := "res://bg/%s_bg.png" % lid
		var rdp := "res://bg/%s_road.png" % lid
		var bt: Texture2D = load(bgp) if ResourceLoader.exists(bgp) else null
		var rt: Texture2D = load(rdp) if ResourceLoader.exists(rdp) else null
		if bg.has_method("set_textures"):
			bg.set_textures(bt, rt)

# сюжетный квест локации закрывается на боссе → награда (пушка на выбор + алмазы)
func _check_quest_complete() -> void:
	var loc := _loc()
	if str(loc["id"]) in quest_done: return
	# предмет квеста падает с босса РАНДОМНО (~28%/босс), а не гарантом на 1-м (фидбэк Рамиля: «органично по ходу фарма»)
	if randf() > 0.28: return
	quest_done.append(str(loc["id"]))
	_save()
	_quest_reward(loc)

func _grant_quest_weapon(i: int) -> void:
	var hh = heroes[i]
	var cls: int = hh["cls"]
	var variants := _slot_variants("weapon", cls)
	var v = variants[randi() % variants.size()]
	var rar: int = _roll_rarity()   # СЛУЧАЙНАЯ рарность по стадии (фидбэк Рамиля: не гарант-эпик, это жирно; эпик пусть с рандом-дропа)
	var it := _make_item(cls, v["id"], rar, "weapon"); it["lvl"] = max(1, stage)
	var key := _ik(v["id"], rar); var g = hh["gear"]["weapon"]
	if not g.has(key) or _item_power(it) > _item_power(g[key]):
		g[key] = it
		new_gear["%d:weapon" % i] = int(new_gear.get("%d:weapon" % i, 0)) + 1
	_recalc_hero(hh); _save(); _refresh_hud()

func _quest_reward(loc: Dictionary) -> void:
	if bot: return
	diamonds += 150; scrap += 500
	var q: Dictionary = loc["quest"]
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3500; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.92); dim.set_anchors_preset(Control.PRESET_FULL_RECT); panel.add_child(dim)
	var t := _lbl(_t("quest_done"), 22, Color("#7ee08a"), HORIZONTAL_ALIGNMENT_CENTER); t.position = Vector2(0, 180); t.size = Vector2(W, 30); panel.add_child(t)
	var it := _lbl(_t("quest_looted") % [_tloc(q, "item"), str(q["boss"])], 14, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER); it.position = Vector2(0, 216); it.size = Vector2(W, 22); panel.add_child(it)
	var rw := _lbl(_t("quest_reward"), 14, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER); rw.position = Vector2(0, 250); rw.size = Vector2(W, 22); panel.add_child(rw)
	var pick := _lbl(_t("quest_pick"), 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER); pick.position = Vector2(0, 286); pick.size = Vector2(W, 20); panel.add_child(pick)
	for i in heroes.size():
		var hh = heroes[i]
		var b := Button.new(); b.text = _t("quest_weapon_btn") % [HEROES[hh["cls"]]["icon"], _hname(hh["cls"])]
		b.custom_minimum_size = Vector2(360, 46); b.add_theme_font_size_override("font_size", 15)
		b.position = Vector2(W * 0.5 - 180, 320 + i * 54)
		var ii := i
		b.pressed.connect(func(): _grant_quest_weapon(ii); _popup_center(_t("quest_weapon_granted"), Color("#ff2d95"), 1.6); panel.queue_free())
		panel.add_child(b)

# === ЕЖЕДНЕВНЫЕ КВЕСТЫ ===
func _dq_stat(s) -> float: return float(stats_all.get(s, 0))

func _dq_refresh() -> void:
	var today := _today_num()
	var n := DAILY_QUESTS.size()
	# валидны ли dq_idx (ровно 3 + в диапазоне) — фикс ПУСТЫХ дейли (Диана: старый сейв, индексы вне диапазона → краш рендера → пусто)
	var valid := dq_idx.size() == 3
	if valid:
		for qi in dq_idx:
			if int(qi) < 0 or int(qi) >= n: valid = false; break
	if dq_day == today and valid: return
	dq_day = today
	dq_idx = []
	for k in 3: dq_idx.append((today + k * 2) % n)
	dq_base = {}
	for qi in dq_idx: dq_base[DAILY_QUESTS[qi]["stat"]] = _dq_stat(DAILY_QUESTS[qi]["stat"])
	dq_claimed = []
	_save()

func _dq_progress(qi: int) -> float:
	var s = DAILY_QUESTS[qi]["stat"]
	return max(0.0, _dq_stat(s) - float(dq_base.get(s, 0)))

func _dq_ready_count() -> int:
	var c := 0
	for qi in dq_idx:
		var q = DAILY_QUESTS[qi]
		if not (str(q["id"]) in dq_claimed) and _dq_progress(qi) >= float(q["target"]): c += 1
	return c

func _dq_rew_text(q) -> String:
	var r = q["rew"]
	return ("+%d💎" % r["diamonds"]) if r.has("diamonds") else ("+%d🔩" % r.get("scrap", 0))

func _dq_claim(qi: int) -> void:
	var q = DAILY_QUESTS[qi]
	if str(q["id"]) in dq_claimed or _dq_progress(qi) < float(q["target"]): return
	dq_claimed.append(str(q["id"]))
	var r = q["rew"]
	if r.has("diamonds"): diamonds += int(r["diamonds"])
	if r.has("scrap"): scrap += int(r["scrap"])
	_save(); _refresh_hud()
	_popup_center(_t("dq_done_pop") + _dq_rew_text(q), Color("#3ad97a"), 1.6)

func _dq_claim_all() -> void:
	for qi in dq_idx: _dq_claim(qi)

func _open_daily_quests() -> void:
	_dq_refresh()
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.88); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var t := _lbl(_t("dq_title"), 20, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER); t.position = Vector2(0, 120); t.size = Vector2(W, 30); panel.add_child(t)
	var s := _lbl(_t("dq_subtitle"), 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER); s.position = Vector2(0, 152); s.size = Vector2(W, 20); panel.add_child(s)
	for n in dq_idx.size():
		var qi: int = dq_idx[n]
		var q = DAILY_QUESTS[qi]
		var prog := _dq_progress(qi)
		var tgt := float(q["target"])
		var claimed: bool = str(q["id"]) in dq_claimed
		var ready: bool = prog >= tgt
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.13, 0.11, 0.04, 0.97) if (ready and not claimed) else Color(0.08, 0.09, 0.13, 0.95)
		sb.set_corner_radius_all(8); sb.set_content_margin_all(10)
		sb.border_color = Color("#ffd24a") if (ready and not claimed) else Color("#2a2f45"); sb.set_border_width_all(2 if (ready and not claimed) else 1)
		box.add_theme_stylebox_override("panel", sb); box.position = Vector2(W * 0.5 - 210, 196 + n * 92); box.custom_minimum_size = Vector2(420, 84)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 3); box.add_child(v)
		v.add_child(_lbl("%s %s" % [q["icon"], _tloc(q, "name")], 15, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_LEFT))
		var pr := "%s / %s   → %s" % [_gsep(int(prog)), _gsep(int(tgt)), _dq_rew_text(q)]
		if claimed: pr = _t("dq_claimed") + _dq_rew_text(q)
		v.add_child(_lbl(pr, 13, Color("#7ee08a") if claimed else Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_LEFT))
		if ready and not claimed:
			var b := Button.new(); b.text = _t("claim"); b.custom_minimum_size = Vector2(0, 30); b.add_theme_font_size_override("font_size", 13)
			var qii := qi
			b.pressed.connect(func(): _dq_claim(qii); panel.queue_free(); _open_daily_quests())
			v.add_child(b)
		panel.add_child(box)   # ← ФИКС: коробки квестов не добавлялись в панель → дейли были ПУСТЫЕ (Диана)
	var dq_ready := _dq_ready_count()
	var by := 196 + 3 * 92 + 16
	if dq_ready > 0:
		var ca := Button.new(); ca.text = _t("ach_claim_all") % dq_ready; ca.add_theme_font_size_override("font_size", 14); ca.add_theme_color_override("font_color", Color("#ffd24a"))
		ca.custom_minimum_size = Vector2(200, 40); ca.position = Vector2(W * 0.5 - 210, by)
		ca.pressed.connect(func(): _dq_claim_all(); panel.queue_free(); _open_daily_quests())
		panel.add_child(ca)
		var close := Button.new(); close.text = _t("close"); close.custom_minimum_size = Vector2(200, 40)
		close.position = Vector2(W * 0.5 + 10, by); close.pressed.connect(panel.queue_free); panel.add_child(close)
	else:
		var close := Button.new(); close.text = _t("close"); close.custom_minimum_size = Vector2(200, 40)
		close.position = Vector2(W * 0.5 - 100, by); close.pressed.connect(panel.queue_free); panel.add_child(close)

# === КВЕСТ-ЧАТ (идея Рамиля): фиксер шлёт задание в мессенджер-облачках ===
func _chat_bubble(text: String, incoming: bool, accent: Color) -> Control:
	var row := HBoxContainer.new(); row.custom_minimum_size = Vector2(360, 0)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if incoming else BoxContainer.ALIGNMENT_END
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.18, 0.26, 0.98) if incoming else Color(accent.r * 0.35, accent.g * 0.35, accent.b * 0.35, 0.97)
	sb.set_corner_radius_all(13); sb.set_content_margin_all(9)
	if incoming: sb.corner_radius_top_left = 3
	else: sb.corner_radius_top_right = 3
	pc.add_theme_stylebox_override("panel", sb)
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; l.custom_minimum_size = Vector2(250, 0)
	l.add_theme_color_override("font_color", Color("#e8ecf5"))
	pc.add_child(l); row.add_child(pc)
	return row

func _open_quest_chat(li: int) -> void:
	var loc: Dictionary = LOCATIONS[li]
	var q: Dictionary = loc["quest"]
	var contact: String = _tloc(q, "contact")
	if contact == "": contact = _t("quest_contact_default")
	var chat_key: String = "chat_en" if lang == "en" else "chat"
	var msgs: Array = q.get(chat_key, q.get("chat", [str(q.get("dialog", ""))]))
	var accent := Color(loc["neon"][0])
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3600; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.9); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var phone := PanelContainer.new()
	var psb := StyleBoxFlat.new(); psb.bg_color = Color(0.05, 0.06, 0.10, 1); psb.set_corner_radius_all(18); psb.border_color = accent; psb.set_border_width_all(2)
	phone.add_theme_stylebox_override("panel", psb)
	phone.position = Vector2(W * 0.5 - 200, 130); phone.custom_minimum_size = Vector2(400, 620); phone.size = Vector2(400, 620)
	panel.add_child(phone)
	var col := VBoxContainer.new(); col.add_theme_constant_override("separation", 0); phone.add_child(col)
	var head := PanelContainer.new()
	var hsb := StyleBoxFlat.new(); hsb.bg_color = Color(accent.r * 0.28, accent.g * 0.28, accent.b * 0.28, 1); hsb.set_corner_radius_all(16); hsb.set_content_margin_all(10)
	head.add_theme_stylebox_override("panel", hsb)
	var hl := Label.new(); hl.text = "📱 " + contact + "    " + _t("quest_online"); hl.add_theme_font_size_override("font_size", 16); hl.add_theme_color_override("font_color", accent.lightened(0.35))
	head.add_child(hl); col.add_child(head)
	var scr := ScrollContainer.new(); scr.custom_minimum_size = Vector2(400, 556); scr.size = Vector2(400, 556)
	col.add_child(scr)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 8); box.custom_minimum_size = Vector2(376, 0)
	var pad := MarginContainer.new(); pad.add_theme_constant_override("margin_left", 10); pad.add_theme_constant_override("margin_right", 10); pad.add_theme_constant_override("margin_top", 10); pad.add_theme_constant_override("margin_bottom", 10)
	pad.add_child(box); scr.add_child(pad)
	var scroll_btm := func(): if is_instance_valid(scr): scr.set_deferred("scroll_vertical", 999999)
	# сообщения по очереди: «печатает...» → облачко
	for m in msgs:
		var typing := _chat_bubble("• • •", true, accent)
		box.add_child(typing); scroll_btm.call()
		await get_tree().create_timer(0.75).timeout
		if not is_instance_valid(panel): return
		typing.queue_free()
		box.add_child(_chat_bubble(str(m), true, accent)); scroll_btm.call()
		await get_tree().create_timer(0.4).timeout
		if not is_instance_valid(panel): return
	# ВЫБОР РЕПЛИКИ Вектора — настоящие фразы (игрок выбирает что сказать). Тон считается за кадром.
	var goal_txt := _t("quest_goal") % [_tloc(q, "item"), str(q["boss"])]
	box.add_child(_lbl(_t("quest_reply_prompt"), 11, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_CENTER))
	var tchoices := VBoxContainer.new(); tchoices.add_theme_constant_override("separation", 6)
	for tk in ["empathy", "anger", "cold"]:
		var reply: String = _tloc(TONES[tk], "reply")
		var key: String = tk
		tchoices.add_child(_reply_choice(reply, accent, func():
			if is_instance_valid(tchoices): tchoices.queue_free()
			tone_counts[key] = int(tone_counts[key]) + 1
			box.add_child(_chat_bubble(reply, false, accent))
			box.add_child(_chat_bubble(goal_txt, true, accent))
			var dom := _tone_dominant()
			if dom != "":
				box.add_child(_chat_bubble(_t("quest_tone_line") % [TONES[dom]["icon"], _tloc(TONES[dom], "title")], true, Color("#ffd24a")))
			_save(); scroll_btm.call()
			_show_moral_choice(box, q, accent, scroll_btm)))
	box.add_child(tchoices); scroll_btm.call()

# тапаемая реплика-выбор (как строка диалога, не кнопка-ярлык)
func _reply_choice(text: String, accent: Color, cb: Callable) -> Control:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(accent.r * 0.20, accent.g * 0.20, accent.b * 0.20, 0.95); sb.set_corner_radius_all(10); sb.set_content_margin_all(9)
	sb.border_color = accent.darkened(0.1); sb.set_border_width_all(1)
	pc.add_theme_stylebox_override("panel", sb); pc.custom_minimum_size = Vector2(360, 0); pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := Label.new(); l.text = "▸ " + text; l.add_theme_font_size_override("font_size", 13); l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(338, 0); l.add_theme_color_override("font_color", accent.lightened(0.45))
	pc.add_child(l)
	pc.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT: cb.call())
	return pc

# моральный микровыбор — сюжетная развилка реальными репликами-действиями (после выбора реплики)
func _show_moral_choice(box: VBoxContainer, q: Dictionary, accent: Color, scroll_btm: Callable) -> void:
	if not q.has("moral"): return
	var mo: Dictionary = q["moral"]
	if str(mo["id"]) in moral_choices: return   # уже решено
	box.add_child(_chat_bubble(_tloc(mo, "prompt"), true, accent)); scroll_btm.call()
	var mchoices := VBoxContainer.new(); mchoices.add_theme_constant_override("separation", 6)
	for opt in ["a", "b"]:
		var o: Dictionary = mo[opt]
		var ch: String = opt
		mchoices.add_child(_reply_choice(_tloc(o, "label"), accent, func():
			if is_instance_valid(mchoices): mchoices.queue_free()
			moral_choices[str(mo["id"])] = ch
			karma += int(o.get("karma", 0))
			var sc := int(o.get("scrap", 0))
			if sc > 0: scrap += sc
			box.add_child(_chat_bubble(_tloc(o, "result"), true, Color("#ffd24a")))
			_save(); _refresh_hud(); scroll_btm.call()))
	box.add_child(mchoices); scroll_btm.call()

func _open_messages() -> void:
	if not (str(_loc()["id"]) in quest_done):
		_open_quest_chat(cur_location)
	else:
		_popup_center(_t("no_msgs"), Color("#9aa0b5"), 2.0)

# ДОСЬЕ ВЕКТОРА — глубокий слой (характер/совесть/решения). Опционально, казуала не грузит.
func _open_dossier() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.9); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var t := _lbl(_t("dossier_title"), 20, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER); t.position = Vector2(0, 86); t.size = Vector2(W, 30); panel.add_child(t)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(W * 0.5 - 215, 128); scroll.custom_minimum_size = Vector2(430, 600); scroll.size = Vector2(430, 600); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 10); list.custom_minimum_size = Vector2(430, 0); scroll.add_child(list)
	var bio := _lbl(_t("dossier_bio"), 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_LEFT)
	bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; bio.custom_minimum_size = Vector2(410, 0); list.add_child(bio)
	list.add_child(_lbl(_t("dossier_char"), 13, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	var dom := _tone_dominant()
	var char_txt := ("%s %s" % [TONES[dom]["icon"], _tloc(TONES[dom], "title")]) if dom != "" else _t("dossier_no_char")
	list.add_child(_lbl(char_txt, 16, Color("#e8ecf5"), HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(_lbl(_t("dossier_conscience"), 13, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	var ktxt := _t("karma_neutral")
	if karma > 0: ktxt = _t("karma_good") % karma
	elif karma < 0: ktxt = _t("karma_bad") % karma
	list.add_child(_lbl(ktxt, 16, Color("#7ee08a") if karma > 0 else (Color("#ff5050") if karma < 0 else Color("#9aa0b5")), HORIZONTAL_ALIGNMENT_CENTER))
	list.add_child(_lbl(_t("dossier_decisions"), 13, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	var any := false
	for loc in LOCATIONS:
		var qq: Dictionary = loc["quest"]
		if qq.has("moral") and str(qq["moral"]["id"]) in moral_choices:
			any = true
			var ch: String = str(moral_choices[str(qq["moral"]["id"])])
			var ml := _lbl("%s %s — %s" % [loc["icon"], _tloc(loc, "name"), _tloc(qq["moral"][ch], "label")], 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_LEFT)
			ml.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ml.custom_minimum_size = Vector2(410, 0); list.add_child(ml)
	if not any: list.add_child(_lbl(_t("dossier_no_dec"), 12, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_CENTER))
	var close := Button.new(); close.text = _t("dossier_close"); close.custom_minimum_size = Vector2(200, 40)
	close.position = Vector2(W * 0.5 - 100, 760); close.pressed.connect(panel.queue_free); panel.add_child(close)

# ДЕТЕКТИВ «9 секунд» — доска фрагментов (фишка игры, глубокий слой)
func _open_case() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3500; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.92); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var t := _lbl(_t("case_title"), 19, Color("#ff2d95"), HORIZONTAL_ALIGNMENT_CENTER); t.position = Vector2(0, 70); t.size = Vector2(W, 28); panel.add_child(t)
	var open_n := _frags_open()
	var fakes_open := 0
	for i in FRAGMENTS.size():
		if _frag_unlocked(i) and bool(FRAGMENTS[i]["fake"]): fakes_open += 1
	var sub := _lbl(_t("case_sub") % [open_n, fakes_open], 12, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(W * 0.5 - 220, 100); sub.size = Vector2(440, 44); panel.add_child(sub)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(W * 0.5 - 220, 150); scroll.custom_minimum_size = Vector2(440, 540); scroll.size = Vector2(440, 540); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 8); list.custom_minimum_size = Vector2(440, 0); scroll.add_child(list)
	if open_n == 0:
		list.add_child(_lbl(_t("case_empty"), 13, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_CENTER))
	for i in FRAGMENTS.size():
		if not _frag_unlocked(i): continue
		var fr: Dictionary = FRAGMENTS[i]
		var flagged: bool = bool(frag_flags.get(i, false))
		var box := PanelContainer.new()
		var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.12, 0.09, 0.14, 0.97); sb.set_corner_radius_all(8); sb.set_content_margin_all(10)
		sb.border_color = Color("#ff2d95") if flagged else Color("#2a3358"); sb.set_border_width_all(2 if flagged else 1)
		box.add_theme_stylebox_override("panel", sb); box.custom_minimum_size = Vector2(420, 0)
		var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 4); box.add_child(v)
		var ftxt := _lbl(_t("case_frag_hdr") % (i + 1) + "\n" + _tloc(fr, "text"), 13, Color("#e8ecf5"), HORIZONTAL_ALIGNMENT_LEFT)
		ftxt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; ftxt.custom_minimum_size = Vector2(400, 0); v.add_child(ftxt)
		if case_solved and bool(fr["fake"]):
			v.add_child(_lbl(_t("case_fake_lbl") % _tloc(fr, "tell"), 12, Color("#ff5050"), HORIZONTAL_ALIGNMENT_LEFT))
		elif not case_solved:
			var fb := Button.new(); fb.text = _t("case_flag_on") if flagged else _t("case_flag_off"); fb.add_theme_font_size_override("font_size", 12); fb.custom_minimum_size = Vector2(0, 30)
			var ii := i
			fb.pressed.connect(func():
				frag_flags[ii] = not bool(frag_flags.get(ii, false)); _save(); panel.queue_free(); _open_case())
			v.add_child(fb)
		list.add_child(box)
	if open_n > 0 and not case_solved:
		var chk := Button.new(); chk.text = _t("case_check_btn"); chk.custom_minimum_size = Vector2(260, 40); chk.add_theme_font_size_override("font_size", 15)
		chk.pressed.connect(func(): _check_case(panel))
		list.add_child(chk)
	var close := Button.new(); close.text = _t("case_close"); close.custom_minimum_size = Vector2(180, 38)
	close.position = Vector2(W * 0.5 - 90, 760); close.pressed.connect(panel.queue_free); panel.add_child(close)

func _check_case(panel: Control) -> void:
	var flagged := []
	var fakes := []
	for i in FRAGMENTS.size():
		if not _frag_unlocked(i): continue
		if bool(frag_flags.get(i, false)): flagged.append(i)
		if bool(FRAGMENTS[i]["fake"]): fakes.append(i)
	flagged.sort(); fakes.sort()
	if flagged == fakes and fakes.size() > 0:
		if _frags_open() >= FRAGMENTS.size():
			case_solved = true; _save()
			if is_instance_valid(panel): panel.queue_free()
			_show_help(_t("case_solved_title"), _t("case_solved_body"))
		else:
			_popup_center(_t("case_ok"), Color("#7ee08a"), 2.2)
	else:
		_popup_center(_t("case_fail"), Color("#ff5050"), 2.2)

# ФИНАЛ — 3 эндгейм-режима по карме после всех 4 актов
func _open_finale() -> void:
	if not _all_quests_done():
		var dn := 0
		for loc in LOCATIONS:
			if str(loc["id"]) in quest_done: dn += 1
		_popup_center(_t("finale_locked") % dn, Color("#9aa0b5"), 2.6)
		return
	if endgame_mode == "":
		if karma >= 2: endgame_mode = "quiet"
		elif karma <= -2: endgame_mode = "wild"
		else: endgame_mode = "grey"
		_save()
	var e: Dictionary = ENDINGS[endgame_mode]
	var body := _tloc(e, "text")
	if case_solved: body += "\n\n" + _t("finale_case_done")
	else: body += "\n\n" + _t("finale_case_open")
	_show_help("%s FINALE: %s" % [str(e["icon"]), _tloc(e, "name")] if lang == "en" else "%s ФИНАЛ: %s" % [str(e["icon"]), _tloc(e, "name")], body)

# ☰ Ещё — СГРУППИРОВАНО в 4 группы (Рамиль: «9 пунктов страшно»). Группа → под-список.
func _open_more() -> void:
	var msg_new: bool = not (str(_loc()["id"]) in quest_done)
	var story_b := "   📨" if msg_new else ("   ✦" if (case_solved or _frags_open() > 0) else "")
	_dq_refresh()
	var rew_n := _dq_ready_count() + _bp_unclaimed_count() + _ach_claimable()
	var rew_b := "   ●%d" % rew_n if rew_n > 0 else ""
	_open_submenu(_t("more_title"), [
		[_t("m_rewards") + rew_b, Callable(self, "_open_rewards_group")],
		[_t("m_clans") + ("   %s" % player_clan if player_clan != "" else ""), Callable(self, "_open_clan")],
		[_t("m_settings"), Callable(self, "_toggle_settings")],
		[_t("update_btn") % VERSION, Callable(self, "_force_update")],
	])

# принудительное обновление до свежего билда (чистка кэша+SW) — нужно на тесте (фидбэк Рамиля «зря убрал»)
func _force_update() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(async()=>{try{if('serviceWorker' in navigator){const rs=await navigator.serviceWorker.getRegistrations();for(const r of rs){await r.unregister();}}if(self.caches){const ks=await caches.keys();for(const k of ks){await caches.delete(k);}}}catch(e){}location.reload(true);})();", true)
	else:
		_popup_center(_t("force_update_msg"), Color("#9aa0b5"), 1.6)

func _open_story_group() -> void:
	var msg_new: bool = not (str(_loc()["id"]) in quest_done)
	_open_submenu(_t("story_title"), [
		[_t("story_messages") + ("   📨" if msg_new else ""), Callable(self, "_open_messages")],
		[_t("story_dossier"), Callable(self, "_open_dossier")],
		[_t("story_case") + ("   ✅" if case_solved else ("   🧩%d" % _frags_open() if _frags_open() > 0 else "")), Callable(self, "_open_case")],
		[_t("story_finale") + ("   %s" % str(ENDINGS[endgame_mode]["icon"]) if endgame_mode != "" else ("   ✦" if _all_quests_done() else "   🔒")), Callable(self, "_open_finale")],
	])

func _open_rewards_group() -> void:
	_dq_refresh()
	var dqn := _dq_ready_count(); var bpn := _bp_unclaimed_count(); var acn := _ach_claimable()
	_open_submenu(_t("m_rewards_hdr"), [
		[_t("m_daily") + ("   ●%d" % dqn if dqn > 0 else ""), Callable(self, "_open_daily_quests")],
		[_t("m_battlepass") + ("   ●%d" % bpn if bpn > 0 else ""), Callable(self, "_open_battlepass")],
		[_t("m_achieve") + ("   ●%d" % acn if acn > 0 else ""), Callable(self, "_open_achievements")],
	])

# универсальный рендер списка-меню (снизу-вверх от навбара, влезает любое кол-во)
func _open_submenu(title: String, items: Array) -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.85); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var n_items := items.size()
	var item_h := 56
	var gap := 8
	# ЦЕНТРИРУЕМ по вертикали (Рамиль): блок = титул(46) + пункты
	var block_h := 46 + n_items * (item_h + gap)
	var top := int((H - block_h) / 2.0) + 46
	var t := _lbl(title, 20, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER); t.position = Vector2(0, top - 46); t.size = Vector2(W, 30); panel.add_child(t)
	for i in n_items:
		var b := Button.new(); b.text = items[i][0]; b.custom_minimum_size = Vector2(320, item_h); b.add_theme_font_size_override("font_size", 18)
		b.position = Vector2(W * 0.5 - 160, top + i * (item_h + gap))
		var cb: Callable = items[i][1]
		b.pressed.connect(func(): panel.queue_free(); cb.call())
		panel.add_child(b)

func _open_battlepass() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.85); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var title := _lbl(_t("bp_title"), 20, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER); title.position = Vector2(0, 30); title.size = Vector2(W, 30); panel.add_child(title)
	var nextm: int = (int(best_stage / BP_STEP) + 1) * BP_STEP
	var sub := _lbl(_t("bp_sub") % [best_stage, nextm - best_stage], 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER); sub.position = Vector2(0, 62); sub.size = Vector2(W, 20); panel.add_child(sub)
	if not bp_premium:
		var pb := Button.new(); pb.text = _t("bp_buy_btn") % BP_PREMIUM_COST; pb.add_theme_font_size_override("font_size", 14); pb.add_theme_color_override("font_color", Color("#ffd24a"))
		pb.position = Vector2(W * 0.5 - 200, 88); pb.size = Vector2(400, 38); pb.disabled = diamonds < BP_PREMIUM_COST
		pb.pressed.connect(func(): if diamonds >= BP_PREMIUM_COST: diamonds -= BP_PREMIUM_COST; bp_premium = true; _bp_cache_stage = -1; _save(); panel.queue_free(); _open_battlepass())
		panel.add_child(pb)
	# заголовки колонок (фидбэк Дианы: непонятно где бесплатно/премиум)
	var fh := _lbl(_t("bp_free_hdr"), 12, Color("#7ee08a"), HORIZONTAL_ALIGNMENT_CENTER); fh.position = Vector2(W * 0.5 - 176, 128); fh.size = Vector2(190, 18); panel.add_child(fh)
	var ph := _lbl(_t("bp_prem_hdr") + (" ✓" if bp_premium else " " + _t("bp_prem_cost")), 12, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER); ph.position = Vector2(W * 0.5 + 22, 128); ph.size = Vector2(190, 18); panel.add_child(ph)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(W * 0.5 - 220, 150); scroll.custom_minimum_size = Vector2(440, 544); scroll.size = Vector2(440, 544); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 6); list.custom_minimum_size = Vector2(440, 0); scroll.add_child(list)
	# показать тиры от 5 до best_stage+25 (несколько вперёд как тизер)
	var m := BP_STEP
	var top: int = (int(best_stage / BP_STEP) + 5) * BP_STEP
	while m <= top:
		list.add_child(_bp_tier_row(m, panel))
		m += BP_STEP
	var bp_unc := _bp_unclaimed_count()
	if bp_unc > 0:
		var ca := Button.new(); ca.text = _t("ach_claim_all") % bp_unc; ca.add_theme_font_size_override("font_size", 14); ca.add_theme_color_override("font_color", Color("#ffd24a"))
		ca.custom_minimum_size = Vector2(200, 42); ca.position = Vector2(W * 0.5 - 210, 706)
		ca.pressed.connect(func(): _bp_claim_all(); panel.queue_free(); _open_battlepass())
		panel.add_child(ca)
		var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(200, 42); bc.position = Vector2(W * 0.5 + 10, 706); bc.pressed.connect(func(): panel.queue_free()); panel.add_child(bc)
	else:
		var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(200, 42); bc.position = Vector2(W * 0.5 - 100, 706); bc.pressed.connect(func(): panel.queue_free()); panel.add_child(bc)

func _bp_tier_row(m: int, panel: Control) -> Control:
	var reached: bool = best_stage >= m
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.10, 0.11, 0.17, 0.95) if reached else Color(0.06, 0.06, 0.09, 0.9); sb.set_corner_radius_all(8); sb.set_content_margin_all(8)
	sb.border_color = Color("#ffd24a") if reached else Color("#2a2f45"); sb.set_border_width_all(1)
	box.add_theme_stylebox_override("panel", sb); box.custom_minimum_size = Vector2(420, 0)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 8); box.add_child(row)
	row.add_child(_lbl(_t("bp_stage_n") % m, 14, Color("#ffd24a") if reached else Color("#5a6a8a"), HORIZONTAL_ALIGNMENT_LEFT))
	# бесплатная награда
	var fclaimed: bool = m in bp_claimed
	var fb := Button.new(); fb.custom_minimum_size = Vector2(190, 40); fb.add_theme_font_size_override("font_size", 12)
	fb.add_theme_color_override("font_color", Color("#6a6f85") if fclaimed else Color("#7ee08a"))   # забранное — серым
	fb.text = ("✓ " if fclaimed else "🆓 ") + _bp_reward_text(_bp_free_reward(m))
	fb.disabled = fclaimed or not reached
	var mm := m
	fb.pressed.connect(func(): _bp_claim(mm, false); panel.queue_free(); _open_battlepass())
	row.add_child(fb)
	# премиум награда
	var pclaimed: bool = m in bp_claimed_prem
	var pbn := Button.new(); pbn.custom_minimum_size = Vector2(190, 40); pbn.add_theme_font_size_override("font_size", 12); pbn.add_theme_color_override("font_color", Color("#6a6f85") if pclaimed else Color("#ffd24a"))   # забранное — серым
	pbn.text = ("✓ " if pclaimed else "💎 ") + _bp_reward_text(_bp_prem_reward(m))
	pbn.disabled = pclaimed or not reached or not bp_premium
	pbn.pressed.connect(func(): _bp_claim(mm, true); panel.queue_free(); _open_battlepass())
	row.add_child(pbn)
	return box

# === АЧИВКИ ===
func _ach_value(key: String) -> int:
	match key:
		"stage": return best_stage
		"prestige": return rec_prestiges
		"sing": return singularity_count
		"hlvl": return _max_hero_level()
		"allhlvl":
			var mn := 999999
			for hh in heroes: mn = min(mn, int(hh["level"]))
			return mn
		_: return int(min(float(stats_all.get(key, 0)), STAT_CAP))   # кламп от int64-переполнения накопит. статов

func _ach_reward(idx: int) -> Dictionary:
	match idx:
		0: return {"scrap": 40}
		1: return {"cores": 20}
		2: return {"diamonds": 25}
		_: return {"diamonds": 100}

# сколько тиров ДОСТИГНУТО (по значению)
func _ach_reached(a: Dictionary) -> int:
	var v := _ach_value(a["key"]); var n := 0
	for t in a["tiers"]:
		if v >= int(t): n += 1
	return n

func _ach_claim_all() -> void:
	for a in ACHIEVEMENTS: _ach_claim(a)

func _ach_claimable() -> int:
	var n := 0
	for a in ACHIEVEMENTS:
		n += max(0, _ach_reached(a) - int(ach_claimed.get(a["id"], 0)))
	return n

func _ach_claim(a: Dictionary) -> void:
	var reached := _ach_reached(a)
	var cl := int(ach_claimed.get(a["id"], 0))
	while cl < reached:
		var r := _ach_reward(cl)
		cores += int(r.get("cores", 0)); diamonds += int(r.get("diamonds", 0)); scrap += int(r.get("scrap", 0))
		cl += 1
	ach_claimed[a["id"]] = cl
	_save(); _refresh_hud()

func _ach_reward_text(idx: int) -> String:
	var r := _ach_reward(idx)
	if r.has("diamonds"): return _t("ach_rew_dia") % r["diamonds"]
	if r.has("cores"): return _t("ach_rew_cores") % r["cores"]
	return _t("ach_rew_scrap") % r.get("scrap", 0)

func _open_achievements() -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3400; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.85); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	panel.add_child(_lbl_at(_t("ach_title"), 20, Color("#ffd24a"), 30))
	var claimable := _ach_claimable()
	panel.add_child(_lbl_at(_t("ach_sub") % claimable, 13, Color("#cfe6ff") if claimable > 0 else Color("#9aa0b5"), 60))
	if claimable > 0:
		var ca := Button.new(); ca.text = _t("ach_claim_all") % claimable; ca.add_theme_font_size_override("font_size", 15); ca.add_theme_color_override("font_color", Color("#ffd24a"))
		ca.position = Vector2(W * 0.5 - 130, 84); ca.size = Vector2(260, 38)
		ca.pressed.connect(func(): _ach_claim_all(); panel.queue_free(); _open_achievements())
		panel.add_child(ca)
	var scroll := ScrollContainer.new(); scroll.position = Vector2(W * 0.5 - 222, 130); scroll.custom_minimum_size = Vector2(444, 580); scroll.size = Vector2(444, 580); panel.add_child(scroll)
	var list := VBoxContainer.new(); list.add_theme_constant_override("separation", 6); list.custom_minimum_size = Vector2(444, 0); scroll.add_child(list)
	for a in ACHIEVEMENTS:
		list.add_child(_ach_row(a, panel))
	var bc := Button.new(); bc.text = _t("close_x"); bc.custom_minimum_size = Vector2(200, 42); bc.position = Vector2(W * 0.5 - 100, 720); bc.pressed.connect(func(): panel.queue_free()); panel.add_child(bc)

func _lbl_at(t: String, sz: int, col: Color, y: float) -> Label:
	var l := _lbl(t, sz, col, HORIZONTAL_ALIGNMENT_CENTER); l.position = Vector2(0, y); l.size = Vector2(W, sz + 8); return l

func _ach_row(a: Dictionary, panel: Control) -> Control:
	var reached := _ach_reached(a)
	var claimed := int(ach_claimed.get(a["id"], 0))
	var canclaim := reached > claimed
	var maxt: int = a["tiers"].size()
	var v := _ach_value(a["key"])
	var box := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.13, 0.11, 0.04, 0.97) if canclaim else Color(0.07, 0.08, 0.12, 0.95); sb.set_corner_radius_all(8); sb.set_content_margin_all(8)
	sb.border_color = Color("#ffd24a") if canclaim else Color("#2a2f45"); sb.set_border_width_all(2 if canclaim else 1)
	box.add_theme_stylebox_override("panel", sb); box.custom_minimum_size = Vector2(424, 0)
	var v2 := VBoxContainer.new(); v2.add_theme_constant_override("separation", 2); box.add_child(v2)
	# тир: сколько уровней достижения уже забрано из всех
	var nextidx: int = min(claimed, maxt - 1)
	var nextt: int = a["tiers"][nextidx]
	var head := "%s %s · %s" % [a["icon"], _tloc(a, "name"), _t("ach_tier") % [claimed, maxt]]
	v2.add_child(_lbl(head, 14, Color("#ffd24a") if canclaim else Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_LEFT))
	v2.add_child(_lbl(_tloc(a, "desc"), 11, Color("#8a90a5"), HORIZONTAL_ALIGNMENT_LEFT))   # что качает достижение (фидбэк Дианы)
	if claimed >= maxt:
		v2.add_child(_lbl(_t("ach_all_done"), 12, Color("#3ad97a"), HORIZONTAL_ALIGNMENT_LEFT))
	else:
		var hrow := HBoxContainer.new(); hrow.add_theme_constant_override("separation", 8); v2.add_child(hrow)
		hrow.add_child(_lbl(_t("ach_progress") % [_gsep(v), _gsep(nextt), _ach_reward_text(nextidx)], 12, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_LEFT))
		if canclaim:
			var cb := Button.new(); cb.text = _t("ach_claim_btn"); cb.custom_minimum_size = Vector2(110, 30); cb.add_theme_font_size_override("font_size", 12)
			var aa: Dictionary = a
			cb.pressed.connect(func(): _ach_claim(aa); panel.queue_free(); _open_achievements())
			hrow.add_child(cb)
	return box

# === ДЕЙЛИКИ ===
func _today_num() -> int:
	return int(Time.get_unix_time_from_system() / 86400.0)

func _daily_available() -> bool:
	return not bot and _today_num() > daily_day

func _daily_next_streak() -> int:
	if _today_num() == daily_day + 1: return (daily_streak % 7) + 1   # подряд → следующий день цикла
	return 1                                                          # пропуск/первый → сброс на день 1

func _daily_reward_text(r: Dictionary) -> String:
	var p := []
	if r.has("diamonds"): p.append("%d💎" % r["diamonds"])
	if r.has("cores"): p.append("%d🧬" % r["cores"])
	if r.has("scrap"): p.append("%d♻" % r["scrap"])
	return " ".join(p)

func _claim_daily(panel: Control) -> void:
	if not _daily_available():
		if panel: panel.queue_free()   # день сменился между открытием и кликом → просто закрыть (фикс soft-lock R4)
		return
	var ns := _daily_next_streak()
	var r: Dictionary = DAILY_REWARDS[ns - 1]
	cores += int(r.get("cores", 0)); diamonds += int(r.get("diamonds", 0)); scrap += int(r.get("scrap", 0))
	daily_day = _today_num(); daily_streak = ns
	_save(); _refresh_hud()
	_popup_center(_t("dr_pop") % [ns, _daily_reward_text(r)], Color("#ffd24a"), 2.4)
	if panel: panel.queue_free()

func _show_daily() -> void:
	var ns := _daily_next_streak()
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3600; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.8); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())   # тап по фону = закрыть (фикс R4)
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.07, 0.13, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#ffd24a"); sb.set_border_width_all(2); sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 210, 200); card.custom_minimum_size = Vector2(420, 0); panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	v.add_child(_lbl(_t("dr_title"), 19, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_t("dr_streak") % ns, 13, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER))
	# трек 7 дней
	var grid := HBoxContainer.new(); grid.add_theme_constant_override("separation", 5); grid.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(grid)
	for day in range(1, 8):
		var cell := PanelContainer.new()
		var csb := StyleBoxFlat.new(); csb.set_corner_radius_all(6); csb.set_content_margin_all(4)
		csb.bg_color = Color(0.18, 0.15, 0.05, 1.0) if day == ns else (Color(0.05, 0.08, 0.06, 1.0) if day < ns else Color(0.06, 0.06, 0.1, 1.0))
		csb.border_color = Color("#ffd24a") if day == ns else Color("#2a2f45"); csb.set_border_width_all(2 if day == ns else 1)
		cell.add_theme_stylebox_override("panel", csb); cell.custom_minimum_size = Vector2(54, 60)
		var cv := VBoxContainer.new(); cell.add_child(cv)
		cv.add_child(_lbl(_t("dr_day_short") % day, 11, Color("#ffd24a") if day == ns else Color("#7a809a"), HORIZONTAL_ALIGNMENT_CENTER))
		cv.add_child(_lbl(_daily_reward_text(DAILY_REWARDS[day - 1]), 9, Color("#cfe6ff") if day == ns else Color("#5a6a8a"), HORIZONTAL_ALIGNMENT_CENTER))
		grid.add_child(cell)
	var cb := Button.new(); cb.text = _t("dr_claim_btn") % [ns, _daily_reward_text(DAILY_REWARDS[ns - 1])]; cb.custom_minimum_size = Vector2(0, 50); cb.add_theme_font_size_override("font_size", 16); cb.add_theme_color_override("font_color", Color("#ffd24a"))
	cb.pressed.connect(func(): _claim_daily(panel)); v.add_child(cb)

# описание класса (Диана: непонятно чем герои различаются / что делают ульты)
func _show_hero_desc(i: int) -> void:
	var h = HEROES[i]
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 3500; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.7); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.06, 0.09, 0.16, 0.99); sb.set_corner_radius_all(14); sb.border_color = h["color"]; sb.set_border_width_all(2); sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 210, 260); card.custom_minimum_size = Vector2(420, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	v.add_child(_lbl("%s %s" % [h["icon"], _hname(i)], 22, h["color"], HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_lbl(_tloc(h, "role"), 14, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var d := _lbl(_tloc(h, "desc"), 14, Color("#c7ccea"), HORIZONTAL_ALIGNMENT_CENTER); d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; d.custom_minimum_size = Vector2(384, 0); v.add_child(d)
	v.add_child(_lbl("🔫 %s   ❤ %d   ⚔ %d   🎯 %d%%" % [h["wname"], h["hp"], h["dmg"], int(h["crit"] * 100)], 12, Color("#9aa0b5"), HORIZONTAL_ALIGNMENT_CENTER))
	var bc := Button.new(); bc.text = _t("hero_desc_close"); bc.custom_minimum_size = Vector2(0, 44); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

# === ОБУЧЕНИЕ / ПОДСКАЗКИ (Рамиль) ===
# маленькая кнопка «?» в углу панели → попап-объяснение
func _add_help(parent: Control, title: String, body: String) -> void:
	var b := Button.new()
	b.text = "?"
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color("#ffd24a"))
	b.custom_minimum_size = Vector2(40, 40)
	b.position = Vector2(14, 40)
	b.pressed.connect(func(): _show_help(title, body))
	parent.add_child(b)

func _show_help(title: String, body: String) -> void:
	var panel := Control.new(); panel.set_anchors_preset(Control.PRESET_FULL_RECT); panel.z_index = 4000; hud.add_child(panel)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.8); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: panel.queue_free())
	panel.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.06, 0.10, 0.17, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#ffd24a"); sb.set_border_width_all(2); sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb); card.position = Vector2(W * 0.5 - 215, 190); card.custom_minimum_size = Vector2(430, 0)
	panel.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); card.add_child(v)
	v.add_child(_lbl("❓ " + title, 20, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER))
	var t := _lbl(body, 15, Color("#d7dcf0"), HORIZONTAL_ALIGNMENT_LEFT); t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; t.custom_minimum_size = Vector2(394, 0); v.add_child(t)
	var bc := Button.new(); bc.text = _t("help_ok"); bc.custom_minimum_size = Vector2(0, 46); bc.add_theme_font_size_override("font_size", 16); bc.pressed.connect(func(): panel.queue_free()); v.add_child(bc)

# первый запуск — короткое интро по основной петле
func _show_intro() -> void:
	_show_help(_t("wc_help_t"), _t("wc_help_b"))
	seen_intro = true; _save()

func _toggle_inv() -> void:
	inv_open = not inv_open
	inv_panel.visible = inv_open
	if inv_open: _refresh_inv()

func _upgrade_level(i: int) -> void:
	var hh = heroes[i]
	if buy_mult == 0:
		# MAX: вкачать столько, на сколько хватает золота (как и было)
		var bought := 0
		while gold >= hh["lvl_cost"]:
			gold -= hh["lvl_cost"]
			hh["level"] += 1
			hh["lvl_cost"] = int(hh["lvl_cost"] * LVL_COST_GROWTH) + 2
			bought += 1
		if bought > 0:
			_recalc_hero(hh)
			_refresh_inv()
		return
	# x1/x10/x100: ВСЁ-ИЛИ-НИЧЕГО — покупаем полную пачку только если хватает на всю
	var n: int = buy_mult
	if gold < _batch_cost(hh, n):
		return
	for k in n:
		gold -= hh["lvl_cost"]
		hh["level"] += 1
		hh["lvl_cost"] = int(hh["lvl_cost"] * LVL_COST_GROWTH) + 2
	_recalc_hero(hh)
	_refresh_inv()

func _build_inventory() -> void:
	inv_panel = Control.new()
	inv_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	inv_panel.visible = false
	inv_panel.z_index = 2000   # поверх боевых спрайтов
	hud.add_child(inv_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.04, 0.08, 0.99)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _toggle_inv())  # тап по фону = закрыть
	inv_panel.add_child(bg)

	var title := Label.new()
	title.text = _t("t_upgrade")
	title.add_theme_color_override("font_color", Color("#ffb02e"))
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40); title.size = Vector2(W, 34)
	inv_panel.add_child(title)
	inv_title = title
	_add_help(inv_panel, _t("upg_help_t"), _t("upg_help_b"))
	inv_gold = Label.new()
	inv_gold.add_theme_color_override("font_color", Color("#ffe14d"))
	inv_gold.add_theme_font_size_override("font_size", 18)
	inv_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inv_gold.position = Vector2(0, 78); inv_gold.size = Vector2(W, 24)
	inv_panel.add_child(inv_gold)
	# переключатель множителя покупки уровней
	var mbar := HBoxContainer.new(); mbar.add_theme_constant_override("separation", 8)
	mbar.alignment = BoxContainer.ALIGNMENT_CENTER
	mbar.position = Vector2(0, 104); mbar.size = Vector2(W, 36)
	inv_panel.add_child(mbar)
	buy_btns.clear()
	for m in [[1, "x1"], [10, "x10"], [100, "x100"], [0, "MAX"]]:
		var mb := Button.new(); mb.text = m[1]; mb.add_theme_font_size_override("font_size", 15); mb.custom_minimum_size = Vector2(74, 34)
		var mv: int = m[0]
		mb.pressed.connect(func(): buy_mult = mv; _refresh_inv())
		mbar.add_child(mb); buy_btns.append([mv, mb])

	# по строке на каждого героя: УРОВЕНЬ + ПУШКА
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	rows.position = Vector2(24, 152); rows.size = Vector2(W - 48, 0)
	inv_panel.add_child(rows)
	hero_rows.clear()
	for i in HEROES.size():
		var h = HEROES[i]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(h["color"].r, h["color"].g, h["color"].b, 0.12)
		sb.border_color = h["color"]; sb.set_border_width_all(2)
		sb.set_corner_radius_all(10); sb.set_content_margin_all(12)
		row.add_theme_stylebox_override("panel", sb)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		row.add_child(hb)
		var nm := Label.new()
		nm.text = h["icon"] + "\n" + _hname(i)
		nm.add_theme_color_override("font_color", h["color"])
		nm.add_theme_font_size_override("font_size", 15)
		nm.custom_minimum_size = Vector2(92, 0)
		hb.add_child(nm)
		var lb := Button.new()
		lb.custom_minimum_size = Vector2(0, 62)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.add_theme_font_size_override("font_size", 16)
		var idx := i
		lb.pressed.connect(func(): _upgrade_level(idx))
		hb.add_child(lb)
		rows.add_child(row)
		hero_rows.append({"lvl_btn": lb, "nm": nm})

	var close := Button.new()
	close.text = _t("close")
	close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50)
	close.position = Vector2(W * 0.5 - 100, H - 150)   # выше рестарта (не перекрываются)
	close.pressed.connect(_toggle_inv)
	inv_panel.add_child(close)
	inv_close = close

func _refresh_inv() -> void:
	if inv_title: inv_title.text = _t("t_upgrade")   # build-once → рефреш при смене языка
	if inv_close: inv_close.text = _t("close")
	if inv_gold:
		inv_gold.text = "💰 %s   +%s%s    💪 %s: %s" % [_gsep(gold), _gsep(_passive_rate()), _t("per_sec"), _t("power"), _gsep(_party_power())]
	for pair in buy_btns:   # подсветка выбранного множителя
		pair[1].modulate = Color(1.4, 1.4, 0.6) if pair[0] == buy_mult else Color(0.7, 0.7, 0.7)
	for i in heroes.size():
		var hh = heroes[i]
		var r = hero_rows[i]
		if r.has("nm"): r["nm"].text = HEROES[hh["cls"]]["icon"] + "\n" + _hname(hh["cls"])   # имя бойца локализуется при смене языка
		if buy_mult == 0:
			var n0 := _affordable_levels(hh)
			r["lvl_btn"].text = "⬆ %s %d  (MAX: %d %s)\n%s %s 💰" % [_t("u_level"), hh["level"], n0, _t("u_lvl_short"), _t("u_for"), _gsep(_batch_cost(hh, n0))]
			r["lvl_btn"].disabled = n0 < 1
		else:
			var n: int = buy_mult
			var bc := _batch_cost(hh, n)
			if gold >= bc:
				r["lvl_btn"].text = "⬆ %s %d  (x%d)\n%s %s 💰" % [_t("u_level"), hh["level"], n, _t("u_for"), _gsep(bc)]
				r["lvl_btn"].disabled = false
			else:
				r["lvl_btn"].text = "⬆ %s %d  (x%d)\n%s %s 💰 %s %d %s" % [_t("u_level"), hh["level"], n, _t("u_need"), _gsep(bc), _t("u_need_for"), n, _t("u_lvl_short")]
				r["lvl_btn"].disabled = true   # не хватает на пачку → тусклая

func _affordable_levels(hh: Dictionary) -> int:
	var g := gold
	var cost: int = hh["lvl_cost"]
	var n := 0
	while g >= cost and n < 100000:
		g -= cost
		cost = int(cost * LVL_COST_GROWTH) + 2
		n += 1
	return n

func _batch_cost(hh: Dictionary, n: int) -> int:
	# суммарная стоимость следующих n уровней (цена растёт ×1.09+2 за уровень)
	var cost: int = hh["lvl_cost"]
	var total := 0
	for k in n:
		total += cost
		cost = int(cost * LVL_COST_GROWTH) + 2
	return total

func _passive_rate() -> float:
	# ПАССИВ/с = (база + надбавка от глубины) × аугмент золота × реклама-буст
	return (gold_ps + float(max(stage, best_stage)) * 1.5) * aug_gold * _ad_mult("gold") * _clan_boost_mult("gold")

# --- ИМПЛАНТ-ИНВЕНТАРЬ (шмотки → база статов; уровень множит) ---
func _toggle_impl() -> void:
	impl_open = not impl_open
	impl_panel.visible = impl_open
	if impl_open: _refresh_impl()

func _equip(slot: String, key: String) -> void:
	var hh = heroes[impl_sel]
	if hh["gear"][slot].has(key):
		hh["equip"][slot] = key
		_recalc_hero(hh)
		_refresh_impl()
		_select_slot(slot)   # перерисовать панель (отметка «надето»)

func _scrap_value(inst: Dictionary) -> int:
	var s: int = inst["rarity"] * 5 + (inst["lvl"] - 1) * 4
	for r in inst["rolls"]:
		s += int(r["val"])
	return s

func _reroll_cost(inst: Dictionary) -> int:
	return inst["rarity"] * 12 + inst["lvl"] * 4

# ПРОСТОЙ АПГРЕЙД за лом (casual-core, заменил реролл): +10% к вкладу предмета за уровень up.
func _gear_upgrade_cost(inst: Dictionary) -> int:
	return int(20 * pow(1.5, int(inst.get("up", 0))))

func _gear_upgrade(slot: String, key: String) -> void:
	var hh = heroes[impl_sel]
	if not hh["gear"][slot].has(key):
		return
	var inst = hh["gear"][slot][key]
	var cost := _gear_upgrade_cost(inst)
	if scrap < cost:
		return
	scrap -= cost
	inst["up"] = int(inst.get("up", 0)) + 1
	_recalc_hero(hh)
	_save()
	_refresh_hud()
	_refresh_impl()
	_refresh_detail()
	_popup_center(_t("g_upgrade_done"), Color("#3ad97a"), 1.4)

func _disassemble(slot: String, key: String) -> void:
	var hh = heroes[impl_sel]
	if hh["equip"][slot] == key or not hh["gear"][slot].has(key):
		return   # надетое не разбираем
	var sv := int(_scrap_value(hh["gear"][slot][key]) * aug_gold)
	scrap += sv
	_stat_add("scrap", sv)
	hh["gear"][slot].erase(key)
	_refresh_impl()
	_select_slot(slot)

# === ИНВЕНТАРЬ-КОЛЛЕКЦИЯ (п.3) ===
func _ic_id(i: int, slot: String, key: String) -> String:
	return "%d:%s:%s" % [i, slot, key]

# вся коллекция кучей: [{i, slot, key, inst, equipped, fav}]
func _all_items() -> Array:
	var out := []
	for i in heroes.size():
		var hh = heroes[i]
		for slot in ["weapon", "module"]:
			for key in hh["gear"][slot]:
				out.append({"i": i, "slot": slot, "key": key, "inst": hh["gear"][slot][key],
					"equipped": hh["equip"][slot] == key, "fav": fav.has(_ic_id(i, slot, key))})
	return out

func _ic_passes(it: Dictionary) -> bool:
	if ic_fslot != "all" and it["slot"] != ic_fslot: return false
	if ic_frar != 0 and int(it["inst"]["rarity"]) != ic_frar: return false
	if ic_fhero != -1 and int(it["i"]) != ic_fhero: return false
	return true

func _toggle_invcol() -> void:
	ic_open = not ic_open
	ic_panel.visible = ic_open
	if ic_open:
		ic_sel.clear()
		_refresh_invcol()

func _build_invcol() -> void:
	ic_panel = Control.new()
	ic_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic_panel.visible = false
	ic_panel.z_index = 2200
	hud.add_child(ic_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.07, 0.995); bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic_panel.add_child(bg)
	var title := _lbl(_t("inv_title"), 22, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 22); title.size = Vector2(W, 30); ic_panel.add_child(title)
	ic_info = _lbl("", 14, Color("#c7ccea"), HORIZONTAL_ALIGNMENT_CENTER)
	ic_info.position = Vector2(0, 54); ic_info.size = Vector2(W, 20); ic_panel.add_child(ic_info)
	# фильтры
	var fbar := HBoxContainer.new(); fbar.add_theme_constant_override("separation", 8); fbar.alignment = BoxContainer.ALIGNMENT_CENTER
	fbar.position = Vector2(0, 80); fbar.size = Vector2(W, 34); ic_panel.add_child(fbar)
	ic_fslot_btn = Button.new(); ic_fslot_btn.add_theme_font_size_override("font_size", 13); ic_fslot_btn.custom_minimum_size = Vector2(150, 32)
	ic_fslot_btn.pressed.connect(_ic_cycle_slot); fbar.add_child(ic_fslot_btn)
	ic_frar_btn = Button.new(); ic_frar_btn.add_theme_font_size_override("font_size", 13); ic_frar_btn.custom_minimum_size = Vector2(150, 32)
	ic_frar_btn.pressed.connect(_ic_cycle_rar); fbar.add_child(ic_frar_btn)
	ic_fhero_btn = Button.new(); ic_fhero_btn.add_theme_font_size_override("font_size", 13); ic_fhero_btn.custom_minimum_size = Vector2(150, 32)
	ic_fhero_btn.pressed.connect(_ic_cycle_hero); fbar.add_child(ic_fhero_btn)
	# действия
	var abar := HBoxContainer.new(); abar.add_theme_constant_override("separation", 6); abar.alignment = BoxContainer.ALIGNMENT_CENTER
	abar.position = Vector2(0, 118); abar.size = Vector2(W, 34); ic_panel.add_child(abar)
	var allb := Button.new(); allb.text = _t("inv_all"); allb.add_theme_font_size_override("font_size", 13); allb.custom_minimum_size = Vector2(96, 32); allb.pressed.connect(_ic_select_all); abar.add_child(allb)
	var favb := Button.new(); favb.text = _t("inv_fav"); favb.add_theme_font_size_override("font_size", 13); favb.custom_minimum_size = Vector2(150, 32); favb.pressed.connect(_ic_fav_selected); abar.add_child(favb)
	var scrb := Button.new(); scrb.text = _t("inv_scrap"); scrb.add_theme_font_size_override("font_size", 13); scrb.custom_minimum_size = Vector2(150, 32); scrb.pressed.connect(_ic_ask_scrap); abar.add_child(scrb)
	# список (скролл)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(16, 158); scroll.size = Vector2(W - 32, H - 158 - 78)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ic_panel.add_child(scroll)
	ic_list = VBoxContainer.new(); ic_list.add_theme_constant_override("separation", 6)
	ic_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ic_list)
	var close := Button.new(); close.text = _t("inv_close"); close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50); close.position = Vector2(W * 0.5 - 100, H - 64)
	close.pressed.connect(_toggle_invcol); ic_panel.add_child(close)
	_build_ic_confirm()

func _ic_cycle_slot() -> void:
	ic_fslot = {"all": "weapon", "weapon": "module", "module": "all"}[ic_fslot]
	_refresh_invcol()

func _ic_cycle_rar() -> void:
	ic_frar = (ic_frar + 1) % (RARITY.size())   # 0..4
	_refresh_invcol()

func _ic_cycle_hero() -> void:
	ic_fhero = ic_fhero + 1
	if ic_fhero >= HEROES.size(): ic_fhero = -1
	_refresh_invcol()

func _refresh_invcol() -> void:
	for c in ic_list.get_children(): c.queue_free()
	var slot_name := {"all": "🔫+✨ " + _t("ic_all"), "weapon": "🔫 " + _t("g_weapon"), "module": "✨ " + _t("g_module")}
	ic_fslot_btn.text = slot_name[ic_fslot]
	ic_frar_btn.text = "⭐ " + _t("ic_all") if ic_frar == 0 else "⭐%d %s" % [ic_frar, _rarity_name(ic_frar)]
	ic_fhero_btn.text = "👥 " + _t("ic_all") if ic_fhero == -1 else "%s %s" % [HEROES[ic_fhero]["icon"], _hname(ic_fhero)]
	var items := _all_items()
	var shown := 0
	for it in items:
		if not _ic_passes(it): continue
		shown += 1
		ic_list.add_child(_ic_card(it))
	ic_info.text = _t("inv_status") % [shown, ic_sel.size(), _gsep(scrap)]

func _ic_card(it: Dictionary) -> Control:
	var i: int = it["i"]; var slot: String = it["slot"]; var key: String = it["key"]
	var inst = it["inst"]; var rar: int = inst["rarity"]
	var id := _ic_id(i, slot, key)
	var selected: bool = ic_sel.has(id)
	var hh = heroes[i]
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 58); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_font_size_override("font_size", 13)
	card.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var sicon: String = "🔫" if slot == "weapon" else "✨"
	var mark := ""
	if it["fav"]: mark += " ★"
	var lvltxt := _t("inv_lvl") % inst["lvl"]
	card.text = "%s %s  %s %s · %s%s\n   %s" % [HEROES[i]["icon"], sicon, _rarity_name(rar), _variant(slot, hh["cls"], inst["vid"])["name"], lvltxt, mark, _rolls_text(inst)]
	# «НАДЕТО» — отдельный бейдж справа, выделен (Диана: не сливать с уровнем/статами)
	if it["equipped"]:
		var badge := Label.new()
		badge.text = _t("inv_equipped")
		badge.add_theme_font_size_override("font_size", 15)
		badge.add_theme_color_override("font_color", Color("#3ad97a"))
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.anchor_left = 1.0; badge.anchor_right = 1.0; badge.anchor_top = 0.0; badge.anchor_bottom = 1.0
		badge.offset_left = -150; badge.offset_right = -14; badge.offset_top = 0; badge.offset_bottom = 0
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(badge)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.20, 0.18, 0.05, 0.95) if selected else Color(0.10, 0.12, 0.18, 0.92)
	sb.set_corner_radius_all(8); sb.set_content_margin_all(8)
	sb.border_color = Color("#ffd24a") if selected else Color(RARITY[rar]["col"])
	sb.set_border_width_all(3 if selected else 2)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]: card.add_theme_stylebox_override(st, sb)
	if it["equipped"]:
		card.disabled = true   # надетое не выделяем (и не разбираем)
		card.modulate = Color(0.7, 0.7, 0.7)
	else:
		card.pressed.connect(func(): _ic_toggle(id))
	return card

func _ic_toggle(id: String) -> void:
	if ic_sel.has(id): ic_sel.erase(id)
	else: ic_sel[id] = true
	_refresh_invcol()

func _ic_select_all() -> void:
	# выделить всё видимое по фильтру, КРОМЕ надетого и избранного (защита)
	for it in _all_items():
		if not _ic_passes(it): continue
		if it["equipped"] or it["fav"]: continue
		ic_sel[_ic_id(it["i"], it["slot"], it["key"])] = true
	_refresh_invcol()

func _ic_fav_selected() -> void:
	# тумблер избранного на выделенных
	for id in ic_sel.keys():
		if fav.has(id): fav.erase(id)
		else: fav[id] = true
	ic_sel.clear()
	_save()
	_refresh_invcol()

func _ic_ask_scrap() -> void:
	var n := 0
	for id in ic_sel:
		if not fav.has(id): n += 1   # избранное пропускаем
	if n <= 0: return
	ic_conf_lbl.text = _t("scrap_confirm") % n
	ic_confirm.visible = true

func _ic_do_scrap() -> void:
	var got := 0
	for id in ic_sel.keys():
		if fav.has(id): continue
		var parts: PackedStringArray = id.split(":")
		var i := int(parts[0]); var slot: String = parts[1]; var key: String = parts[2]
		var hh = heroes[i]
		if not hh["gear"][slot].has(key) or hh["equip"][slot] == key: continue
		got += int(_scrap_value(hh["gear"][slot][key]) * aug_gold)
		hh["gear"][slot].erase(key)
		new_gear.erase("%d:%s" % [i, slot])
	scrap += got
	_stat_add("scrap", got)
	ic_sel.clear()
	ic_confirm.visible = false
	_save()
	_refresh_invcol()
	_refresh_impl()
	_popup_center(_t("scrap_done") % _gsep(got), Color("#3ad97a"), 1.8)

func _build_ic_confirm() -> void:
	ic_confirm = Control.new()
	ic_confirm.set_anchors_preset(Control.PRESET_FULL_RECT); ic_confirm.visible = false; ic_confirm.z_index = 2300
	ic_panel.add_child(ic_confirm)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: ic_confirm.visible = false)
	ic_confirm.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.10, 0.16, 0.99); sb.set_corner_radius_all(14); sb.border_color = Color("#3ad97a"); sb.set_border_width_all(2); sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(W * 0.5 - 180, H * 0.38); card.custom_minimum_size = Vector2(360, 0)
	ic_confirm.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 12); card.add_child(v)
	ic_conf_lbl = _lbl("", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER); v.add_child(ic_conf_lbl)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 10); hb.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_child(hb)
	var no := Button.new(); no.text = _t("cancel_btn"); no.add_theme_font_size_override("font_size", 14); no.custom_minimum_size = Vector2(150, 44); no.pressed.connect(func(): ic_confirm.visible = false); hb.add_child(no)
	var yes := Button.new(); yes.text = _t("inv_scrap"); yes.add_theme_font_size_override("font_size", 14); yes.custom_minimum_size = Vector2(150, 44); yes.pressed.connect(_ic_do_scrap); hb.add_child(yes)

func _reroll(slot: String, key: String) -> void:
	var hh = heroes[impl_sel]
	if not hh["gear"][slot].has(key):
		return
	var inst = hh["gear"][slot][key]
	var cost := _reroll_cost(inst)
	if scrap < cost:
		return
	scrap -= cost
	for r in inst["rolls"]:        # те же статы, новые значения-ступени
		r["val"] = _roll_stat(r["stat"])["val"]
	_recalc_hero(hh)
	_refresh_impl()
	_select_slot(slot)

# строка ролла → текст «+N стат»
func _rolls_text(it: Dictionary) -> String:
	# группируем по формату → одинаковые стат-строки (напр. урон оружия + доп-урон) сливаются в одну (Диана: «2 раза урон»)
	var mult: float = (1.0 + (it["lvl"] - 1) * 0.25) * (1.0 + 0.10 * int(it.get("up", 0)))
	var by_fmt := {}
	var order := []
	for r in it["rolls"]:
		var f: String = _tloc(STAT_ROLL[r["stat"]], "fmt")
		if not by_fmt.has(f):
			by_fmt[f] = 0; order.append(f)
		by_fmt[f] = int(by_fmt[f]) + int(r["val"] * mult)
	var parts := []
	for f in order:
		parts.append(f % by_fmt[f])
	return ", ".join(parts)

func _build_implants() -> void:
	impl_panel = Control.new()
	impl_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	impl_panel.visible = false
	impl_panel.z_index = 2000
	hud.add_child(impl_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.05, 0.09, 0.99)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _toggle_impl())
	impl_panel.add_child(bg)
	var title := Label.new()
	title.text = _t("t_gear")
	title.add_theme_color_override("font_color", Color("#00f0ff"))
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 26); title.size = Vector2(W, 30)
	impl_panel.add_child(title)
	impl_title = title
	_add_help(impl_panel, _t("gear_help_t"), _t("gear_help_b"))
	var hdr := _lbl(_t("g_hdr"), 12, Color("#5a6080"), HORIZONTAL_ALIGNMENT_CENTER)
	hdr.position = Vector2(0, 58); hdr.size = Vector2(W, 18)
	impl_panel.add_child(hdr)
	impl_hdr = hdr
	# кнопка → окно ИНВЕНТАРЬ (вся коллекция кучей, разбор в лом)
	var icb := Button.new(); icb.text = _t("g_allitems"); icb.add_theme_font_size_override("font_size", 13)
	icb.custom_minimum_size = Vector2(140, 32); icb.position = Vector2(W - 156, 24)
	icb.pressed.connect(_toggle_invcol)
	impl_panel.add_child(icb)
	impl_allitems_btn = icb
	# СЕТКА 4×3: строка-боец [персонаж | пушка | спецмодуль]
	impl_grid.clear()
	for i in HEROES.size():   # героев ещё нет при сборке UI → статику берём из константы HEROES
		var ry := 84 + i * 150
		var cell := {}
		var hsb := StyleBoxFlat.new(); hsb.bg_color = Color(0.07, 0.10, 0.18, 0.92); hsb.set_corner_radius_all(10); hsb.border_color = Color(HEROES[i]["color"]); hsb.set_border_width_all(2)
		var hp := Panel.new(); hp.add_theme_stylebox_override("panel", hsb); hp.position = Vector2(16, ry); hp.size = Vector2(168, 134)
		impl_panel.add_child(hp)
		cell["hsb"] = hsb; cell["hcol"] = Color(HEROES[i]["color"])
		var hic := _lbl(HEROES[i]["icon"], 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER); hic.position = Vector2(16, ry + 8); hic.size = Vector2(168, 46); impl_panel.add_child(hic)
		var hnm := _lbl(_hname(i), 15, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER); hnm.position = Vector2(16, ry + 56); hnm.size = Vector2(168, 20); impl_panel.add_child(hnm)
		cell["hnm"] = hnm
		var hlv := _lbl("", 12, Color("#cfe6ff"), HORIZONTAL_ALIGNMENT_CENTER); hlv.position = Vector2(20, ry + 80); hlv.size = Vector2(160, 48); impl_panel.add_child(hlv)
		var hinfo := _lbl(_t("g_info"), 11, Color("#5a6a8a"), HORIZONTAL_ALIGNMENT_CENTER); hinfo.position = Vector2(16, ry + 112); hinfo.size = Vector2(168, 16); hinfo.mouse_filter = Control.MOUSE_FILTER_IGNORE; impl_panel.add_child(hinfo)
		cell["hinfo"] = hinfo
		var hbtn := Button.new(); hbtn.flat = true; hbtn.position = Vector2(16, ry); hbtn.size = Vector2(168, 134); hbtn.custom_minimum_size = Vector2(168, 134)
		var hidx := i
		hbtn.pressed.connect(func(): _show_hero_desc(hidx))
		impl_panel.add_child(hbtn)
		cell["hlv"] = hlv
		var wi := i
		var wsb := StyleBoxFlat.new(); wsb.bg_color = Color(0.13, 0.10, 0.03, 0.96); wsb.set_corner_radius_all(10); wsb.border_color = Color("#ffb02e"); wsb.set_border_width_all(2)
		var wb := Button.new(); wb.position = Vector2(192, ry); wb.size = Vector2(168, 134); wb.custom_minimum_size = Vector2(168, 134); wb.text = ""
		for st in ["normal", "hover", "pressed", "focus", "disabled"]: wb.add_theme_stylebox_override(st, wsb)
		wb.pressed.connect(func(): _open_compare(wi, "weapon"))
		impl_panel.add_child(wb)
		var wlbl := _lbl("", 12, Color("#e0d4b0"), HORIZONTAL_ALIGNMENT_CENTER); wlbl.position = Vector2(196, ry + 8); wlbl.size = Vector2(160, 120); wlbl.autowrap_mode = TextServer.AUTOWRAP_WORD; impl_panel.add_child(wlbl)
		var wbadge := _new_badge(Vector2(192 + 168 - 32, ry + 6)); impl_panel.add_child(wbadge)
		cell["wb"] = wb; cell["wsb"] = wsb; cell["wlbl"] = wlbl; cell["wbadge"] = wbadge
		var msb := StyleBoxFlat.new(); msb.bg_color = Color(0.10, 0.07, 0.16, 0.96); msb.set_corner_radius_all(10); msb.set_border_width_all(2)
		var mb := Button.new(); mb.position = Vector2(368, ry); mb.size = Vector2(168, 134); mb.custom_minimum_size = Vector2(168, 134); mb.text = ""
		for st in ["normal", "hover", "pressed", "focus", "disabled"]: mb.add_theme_stylebox_override(st, msb)
		mb.pressed.connect(func(): _open_compare(wi, "module"))
		impl_panel.add_child(mb)
		var mlbl := _lbl("", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER); mlbl.position = Vector2(372, ry + 8); mlbl.size = Vector2(160, 120); mlbl.autowrap_mode = TextServer.AUTOWRAP_WORD; impl_panel.add_child(mlbl)
		var mbadge := _new_badge(Vector2(368 + 168 - 32, ry + 6)); impl_panel.add_child(mbadge)
		cell["mb"] = mb; cell["msb"] = msb; cell["mlbl"] = mlbl; cell["mbadge"] = mbadge
		impl_grid.append(cell)
	var hint := _lbl(_t("g_hint"), 12, Color("#5a6080"), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 84 + 4 * 150 + 8); hint.size = Vector2(W, 18); impl_panel.add_child(hint)
	impl_hint = hint
	var close := Button.new()
	close.text = _t("close_caps"); close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50); close.position = Vector2(W * 0.5 - 100, H - 110)
	close.pressed.connect(_toggle_impl)
	impl_panel.add_child(close)
	impl_close_btn = close
	_build_impl_detail()

func _hero_has_new(i: int) -> bool:
	for k in new_gear:
		if k.begins_with("%d:" % i):
			return true
	return false

func _refresh_impl_static() -> void:
	# статичные строки экрана ЭКИПИРОВКИ (build-once) → пере-применяем под текущий язык
	if impl_title: impl_title.text = _t("t_gear")
	if impl_hdr: impl_hdr.text = _t("g_hdr")
	if impl_allitems_btn: impl_allitems_btn.text = _t("g_allitems")
	if impl_hint: impl_hint.text = _t("g_hint")
	if impl_close_btn: impl_close_btn.text = _t("close_caps")
	for i in impl_grid.size():
		var cell = impl_grid[i]
		if cell.has("hnm"): cell["hnm"].text = _hname(i)
		if cell.has("hinfo"): cell["hinfo"].text = _t("g_info")

func _refresh_impl() -> void:
	_refresh_impl_static()
	for i in impl_grid.size():
		var hh = heroes[i]
		var cell = impl_grid[i]
		cell["hlv"].text = "%s %d" % [_t("lv_dot"), hh["level"]]
		var hnew: bool = _hero_has_new(i)   # боец с новым лутом → золотая рамка строки
		cell["hsb"].border_color = Color("#ffd24a") if hnew else cell["hcol"]
		cell["hsb"].set_border_width_all(4 if hnew else 2)
		# --- оружие (предмет; слот может быть ПУСТ на старте) ---
		var wcnt: int = int(new_gear.get("%d:weapon" % i, 0))
		var wnew: bool = wcnt > 0
		cell["wbadge"].text = str(wcnt); cell["wbadge"].visible = wnew
		var wkey: String = hh["equip"]["weapon"]
		if wkey != "" and hh["gear"]["weapon"].has(wkey):
			var winst = hh["gear"]["weapon"][wkey]
			var wrar: int = winst["rarity"]
			cell["wlbl"].text = "%s %s\n%s %s · %s%d\n%s" % [hh["data"]["wicon"], ("NEW" if wnew else _t("g_weapon")), _rarity_name(wrar), _variant("weapon", hh["cls"], winst["vid"])["name"], _t("lv_dot"), winst["lvl"], _rolls_text(winst)]
			cell["wsb"].border_color = Color("#ffd24a") if wnew else Color(RARITY[wrar]["col"])
		else:
			cell["wlbl"].text = "%s %s\n%s" % [hh["data"]["wicon"], _t("g_weapon"), _t("g_empty")]
			cell["wsb"].border_color = Color("#ffd24a") if wnew else Color("#3a3f55")
		cell["wsb"].set_border_width_all(4 if wnew else 2)
		# --- спецмодуль (слот может быть ПУСТ) ---
		var mkey: String = hh["equip"]["module"]
		var mdef = HERO_MODULE[hh["cls"]]
		var mcnt: int = int(new_gear.get("%d:module" % i, 0))
		var mnew: bool = mcnt > 0
		cell["mbadge"].text = str(mcnt); cell["mbadge"].visible = mnew
		if mkey != "" and hh["gear"]["module"].has(mkey):
			var inst = hh["gear"]["module"][mkey]
			var rar: int = inst["rarity"]
			cell["mlbl"].text = "%s %s\n%s %s\n%s" % [mdef["icon"], ("NEW" if mnew else _tloc(mdef, "name")), _rarity_name(rar), _module_variant(hh["cls"], inst["vid"])["name"], _rolls_text(inst)]
			cell["msb"].border_color = Color("#ffd24a") if mnew else Color(RARITY[rar]["col"])
		else:
			cell["mlbl"].text = "%s %s\n%s" % [mdef["icon"], _tloc(mdef, "name"), _t("g_empty")]
			cell["msb"].border_color = Color("#ffd24a") if mnew else Color("#3a3f55")
		cell["msb"].set_border_width_all(4 if mnew else 2)

func _circle_pts(c: Vector2, r: float, n: int = 26) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n + 1:
		var a := TAU * i / float(n)
		p.append(c + Vector2(cos(a), sin(a)) * r)
	return p

func _skel_line(pts: PackedVector2Array) -> void:
	var l := Line2D.new()
	l.points = pts
	l.width = 3.0
	l.default_color = Color(0.0, 0.94, 1.0, 0.55)
	l.joint_mode = Line2D.LINE_JOINT_ROUND
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	impl_panel.add_child(l)

func _lbl(txt: String, sz: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = align
	return l

# красный бейдж-счётчик новых вещей в углу слота (Диана) — невидим пока 0
func _new_badge(pos: Vector2) -> Label:
	var b := Label.new()
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var sb := StyleBoxFlat.new(); sb.bg_color = Color("#ff2d3a"); sb.set_corner_radius_all(13)
	b.add_theme_stylebox_override("normal", sb)
	b.position = pos; b.size = Vector2(26, 26); b.custom_minimum_size = Vector2(26, 26)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.z_index = 5
	b.visible = false
	return b

func _arrow(p_from: Vector2, p_to: Vector2) -> void:
	_skel_line(PackedVector2Array([p_from, p_to]))
	var d := (p_to - p_from).normalized()
	var a1 := p_to - d.rotated(0.5) * 12.0
	var a2 := p_to - d.rotated(-0.5) * 12.0
	_skel_line(PackedVector2Array([a1, p_to, a2]))

func _body_outline(cx: float) -> PackedVector2Array:
	# профиль правой половины (dx от центра, y абсолют) → зеркалим в полный силуэт
	var prof := [
		Vector2(13, 178), Vector2(40, 198), Vector2(52, 212),
		Vector2(42, 300), Vector2(29, 300), Vector2(30, 218),
		Vector2(28, 360), Vector2(44, 384), Vector2(38, 474),
		Vector2(32, 590), Vector2(13, 590), Vector2(2, 402),
	]
	var pts := PackedVector2Array()
	for v in prof:
		pts.append(Vector2(cx + v.x, v.y))
	for i in range(prof.size() - 1, -1, -1):
		pts.append(Vector2(cx - prof[i].x, prof[i].y))
	return pts

func _add_slot(key: String, pos: Vector2, sz: float, label: String) -> void:
	var icon: String = "🔫" if key == "weapon" else IMPL_DEFS[key]["icon"]
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(sz, sz); btn.size = Vector2(sz, sz)
	btn.position = pos
	btn.text = icon; btn.add_theme_font_size_override("font_size", int(sz * 0.42))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.18, 0.96); sb.set_corner_radius_all(10)
	sb.border_color = Color("#2a3358"); sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(st, sb)
	var k: String = key
	btn.pressed.connect(func(): _select_slot(k))
	impl_panel.add_child(btn)
	var right := pos.x > W * 0.5
	var nameL := Label.new()
	nameL.text = label
	nameL.add_theme_font_size_override("font_size", 13)
	nameL.add_theme_color_override("font_color", Color("#c7ccea"))
	var star := Label.new()
	star.add_theme_font_size_override("font_size", 12)
	if right:
		nameL.position = Vector2(pos.x + sz + 10, pos.y + 2); nameL.size = Vector2(W - (pos.x + sz + 10) - 8, 34)
		nameL.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		star.position = Vector2(pos.x + sz + 10, pos.y + sz - 18); star.size = Vector2(150, 16)
	else:
		nameL.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nameL.position = Vector2(pos.x + sz * 0.5 - 70, pos.y - 22); nameL.size = Vector2(140, 18)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.position = Vector2(pos.x + sz * 0.5 - 70, pos.y + sz + 2); star.size = Vector2(140, 16)
	impl_panel.add_child(nameL)
	impl_panel.add_child(star)
	impl_slots[key] = {"btn": btn, "sb": sb, "star": star}

func _open_compare(i: int, slot: String) -> void:
	impl_sel = i
	impl_seln = slot
	new_gear.erase("%d:%s" % [i, slot])   # посмотрел → NEW гаснет
	_refresh_impl()
	_refresh_hud()
	impl_detail.visible = true
	_refresh_detail()

func _select_slot(key: String) -> void:   # перерисовать открытое окно сравнения (после надевания)
	impl_seln = key
	_refresh_impl()
	_refresh_detail()

# === ПАНЕЛЬ A: список МОДЕЛЕЙ слота (открывается тапом по слоту) ===
func _build_impl_detail() -> void:
	impl_detail = Control.new()
	impl_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	impl_detail.visible = false
	impl_detail.z_index = 2100
	impl_panel.add_child(impl_detail)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _close_detail())
	impl_detail.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.10, 0.17, 0.99); sb.set_corner_radius_all(14)
	sb.border_color = Color("#00f0ff"); sb.set_border_width_all(2); sb.set_content_margin_all(16)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(W * 0.5 - 212, 178); card.custom_minimum_size = Vector2(424, 0)
	impl_detail.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	det_title = Label.new(); det_title.add_theme_font_size_override("font_size", 18); det_title.add_theme_color_override("font_color", Color("#00f0ff")); det_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(det_title)
	det_list = VBoxContainer.new(); det_list.add_theme_constant_override("separation", 8); v.add_child(det_list)
	var back := Button.new(); back.text = _t("g_back"); back.add_theme_font_size_override("font_size", 14); back.custom_minimum_size = Vector2(0, 40); back.pressed.connect(_close_detail); v.add_child(back)

func _refresh_detail() -> void:
	for c in det_list.get_children():
		c.queue_free()
	var hh = heroes[impl_sel]
	var slot: String = impl_seln
	if slot == "weapon":
		det_title.text = "%s %s %s" % [hh["data"]["wicon"], _t("g_weapon_caps"), _t("g_compare")]
	else:
		var mdef = HERO_MODULE[hh["cls"]]
		det_title.text = "%s %s %s" % [mdef["icon"], _tloc(mdef, "name"), _t("g_compare")]
	# все предметы слота (модель+редкость); надетый — первым, дальше по редкости (окно сравнения)
	var keys: Array = hh["gear"][slot].keys()
	keys.sort_custom(func(a, b):
		if hh["equip"][slot] == a: return true
		if hh["equip"][slot] == b: return false
		return hh["gear"][slot][a]["rarity"] > hh["gear"][slot][b]["rarity"])
	for key in keys:
		det_list.add_child(_variant_row(hh, slot, key))

func _variant_row(hh: Dictionary, slot: String, key: String) -> Control:
	var inst = hh["gear"][slot][key]
	var v := _variant(slot, hh["cls"], inst["vid"])
	var rar: int = inst["rarity"]
	var equipped: bool = hh["equip"][slot] == key
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.2, 0.95); sb.set_corner_radius_all(10); sb.set_content_margin_all(10)
	sb.border_color = Color(RARITY[rar]["col"]); sb.set_border_width_all(3 if equipped else 2)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); card.add_child(box)
	var head := Label.new(); head.add_theme_font_size_override("font_size", 15)
	var up: int = int(inst.get("up", 0))
	head.text = "%s · %s · %s%d%s%s" % [v["name"], _rarity_name(rar), _t("lv_dot"), inst["lvl"], ("  +%d⬆" % up if up > 0 else ""), ("  " + _t("g_equipped") if equipped else "")]
	head.add_theme_color_override("font_color", Color(RARITY[rar]["col"]))
	box.add_child(head)
	var st := Label.new(); st.text = _rolls_text(inst); st.add_theme_font_size_override("font_size", 14); st.add_theme_color_override("font_color", Color("#c7ccea")); box.add_child(st)
	var eqb := Button.new(); eqb.add_theme_font_size_override("font_size", 14); eqb.custom_minimum_size = Vector2(0, 40)
	eqb.text = _t("g_equipped") if equipped else _t("g_equip"); eqb.disabled = equipped
	eqb.pressed.connect(func(): _equip(slot, key))
	box.add_child(eqb)
	# простой апгрейд за лом (casual-core: заменил реролл) — +10% к вкладу предмета
	var ucost := _gear_upgrade_cost(inst)
	var upb := Button.new(); upb.add_theme_font_size_override("font_size", 14); upb.custom_minimum_size = Vector2(0, 40)
	upb.text = _t("g_upgrade") % ucost
	upb.disabled = scrap < ucost
	upb.pressed.connect(func(): _gear_upgrade(slot, key))
	box.add_child(upb)
	return card

func _close_detail() -> void:
	if impl_confirm: impl_confirm.visible = false
	impl_detail.visible = false

# === ДРОП ЛУТА ===
# дроп после волны (босс гарант, обычная волна — шанс) → ПОД КОНКРЕТНОГО бойца (случайного).
# 35% оружие / 65% спецмодуль — оба полноценные предметы (редкость/статы/уровень от стадии).
func _drop_implant() -> void:
	implants_count += 1
	_stat_add("drops", 1)   # ачивка: собрано дропа
	var i := randi() % heroes.size()
	var slot: String = "weapon" if randf() < 0.35 else "module"
	_drop_into(heroes[i], i, slot)

# создать предмет слота под бойца и положить в кучу (лучший по ключу — остаётся)
func _drop_into(hh: Dictionary, i: int, slot: String) -> Dictionary:
	var cls: int = hh["cls"]
	var ilvl: int = max(1, stage)   # УРОВЕНЬ ШМОТКИ ОТ СТАДИИ: глубже фарм = выше уровень = жирнее статы
	var variants := _slot_variants(slot, cls)
	var v = variants[randi() % variants.size()]
	var vid: String = v["id"]
	var rar := _roll_rarity()
	var key := _ik(vid, rar)
	var g = hh["gear"][slot]
	var it := _make_item(cls, vid, rar, slot)
	it["lvl"] = ilvl
	var ic: String = "🔫" if slot == "weapon" else "✨"
	if not g.has(key) or _item_power(it) > _item_power(g[key]):
		g[key] = it
		new_gear["%d:%s" % [i, slot]] = int(new_gear.get("%d:%s" % [i, slot], 0)) + 1   # счётчик новых (бейдж)
		# НЕ авто-надеваем (Диана: игрок сам выбирает). Боты надевают через _bot_equip_best.
		if bot and (hh["equip"][slot] == "" or not g.has(hh["equip"][slot])):
			hh["equip"][slot] = key
		# короткая всплывашка (Диана, вариант Б): редкость + слот, без длинного имени/статов
		var slotn: String = _t("g_weapon") if slot == "weapon" else _t("g_module")
		_popup_center("%s %s %s!" % [ic, _rarity_name(rar), slotn], Color(RARITY[rar]["col"]), 1.8)
	_recalc_hero(hh)
	return it

# п.5: при престиже стартуем сразу на стадии upto (Memory-Bonus) → боссы стадий 1..upto-1 пропущены.
# Их лут НЕ теряем: выдаём пачкой в инвентарь (по дропу за босса, редкость по гейту стадии). Излишек → лом.
func _grant_skipped_loot(upto_stage: int) -> void:
	if upto_stage <= 1:
		return
	var saved_wave := wave
	var saved_dry := dry_streak
	var kept := 0
	var scr := 0
	for s in range(1, upto_stage):
		wave = s * (STAGE_WAVES + 1)   # волна босса стадии s → тот же гейт редкости
		var i := randi() % heroes.size()
		var hh = heroes[i]
		var slot: String = "weapon" if randf() < 0.35 else "module"
		var cls: int = hh["cls"]
		var variants := _slot_variants(slot, cls)
		var v = variants[randi() % variants.size()]
		var rar := _roll_rarity()
		var key := _ik(v["id"], rar)
		var it := _make_item(cls, v["id"], rar, slot)
		it["lvl"] = s
		var g = hh["gear"][slot]
		if not g.has(key) or _item_power(it) > _item_power(g[key]):
			g[key] = it
			new_gear["%d:%s" % [i, slot]] = int(new_gear.get("%d:%s" % [i, slot], 0)) + 1
			kept += 1
		else:
			scr += int(_scrap_value(it) * aug_gold)   # дубль/хуже → излишек в лом
	scrap += scr
	_stat_add("scrap", scr)
	wave = saved_wave
	dry_streak = saved_dry
	for hh in heroes:
		_recalc_hero(hh)
	if kept > 0 or scr > 0:
		_popup_center(_t("skipped_loot") % [upto_stage - 1, kept, scr], Color("#ffd24a"), 2.8)

func _popup_center(txt: String, col: Color, life := 1.4) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 22 if life > 2.0 else 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(W * 0.5 - 200, H * 0.42)
	l.custom_minimum_size = Vector2(400, 0)
	l.size = Vector2(400, 60)
	l.z_index = 80
	hud.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", H * 0.42 - 70, life)   # дрейф вверх
	tw.parallel().tween_property(l, "modulate:a", 0.0, life * 0.5).set_delay(life * 0.5)   # держится, потом тает
	tw.chain().tween_callback(l.queue_free)
