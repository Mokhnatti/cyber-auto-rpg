extends Control
## Cyber Auto-RPG — болванка №2: РАННЕР-ВИД.
## Отряд "бежит на месте", параллакс-город едет навстречу, волны врагов догоняют →
## бой на месте → победили → марш дальше. Бесконечный поход, считаем волны.
## Болванчики процедурные (без арта). Параметры классов наружу. Ульты = скилл-клапан.

const HEROES := [
	# atk_type: snipe/single/aoe/tank · hpg/dmgg = рост HP/урона за уровень (профиль класса)
	{"name": "СНАЙП", "icon": "🎯", "color": Color("#00f0ff"), "hp": 80,  "dmg": 34, "atk": 2.8, "atk_type": "snipe",  "hpg": 0.09, "dmgg": 0.18, "crit": 0.30, "critx": 2.2, "ult": "burst",  "ult_cd": 9.0,  "wname": "Рельса-винтовка", "wicon": "🔭"},
	{"name": "ШТУРМ", "icon": "🔫", "color": Color("#ffb02e"), "hp": 120, "dmg": 9,  "atk": 0.7, "atk_type": "single", "hpg": 0.13, "dmgg": 0.15, "crit": 0.10, "critx": 1.6, "ult": "barrage","ult_cd": 8.0,  "wname": "Штурм-ган", "wicon": "🔫"},
	{"name": "ТАНК",  "icon": "🦾", "color": Color("#3ad97a"), "hp": 300, "dmg": 6,  "atk": 1.6, "atk_type": "tank",   "hpg": 0.22, "dmgg": 0.10, "crit": 0.05, "critx": 1.5, "ult": "shield", "ult_cd": 11.0, "wname": "Тяж-орудие", "wicon": "💥"},
	{"name": "ХАКЕР", "icon": "💻", "color": Color("#ff2d95"), "hp": 90,  "dmg": 6,  "atk": 1.4, "atk_type": "aoe",    "hpg": 0.13, "dmgg": 0.14, "crit": 0.08, "critx": 1.6, "ult": "hack",   "ult_cd": 10.0, "wname": "Взлом-дрон", "wicon": "📡"},
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
var boss_btn: Button      # кнопка «⚔ К БОССУ»
var qte_t := 0.0          # до следующего QTE-замаха босса
var qte_win := 0.0        # окно реакции на активный QTE (>0 = активен)
var qte_btn: Button       # кнопка «⚡ КОНТЕР!»
var march_t := 0.0
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
var inv_open := false
var hero_rows := []   # строки прокачки по героям: {lvl_btn}
# ИМПЛАНТЫ-СКЕЛЕТ (шмотки) — дают БАЗОВЫЕ статы отряду; уровень потом множит (HP/урон)
var impl_btn: Button
var impl_panel: Control
var impl_open := false
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
	{"name": "—", "col": "#666"},
	{"name": "Серый", "col": "#9aa0a6"},
	{"name": "Зелёный", "col": "#3ad97a"},
	{"name": "Синий", "col": "#3a8bd9"},
	{"name": "Фиолет", "col": "#b46bff"},
]
# роллы значений: каждый стат роллится из 4 ступеней (100/90/80/70% от макс по 25%) — Genshin-модель
const STAT_ROLL := {
	"hp":   {"max": 40, "fmt": "+%d HP"},
	"dmg":  {"max": 8, "fmt": "+%d урон"},
	"crit": {"max": 8, "fmt": "+%d%% крит"},
	"atk":  {"max": 8, "fmt": "+%d%% скор"},
	"ult":  {"max": 10, "fmt": "+%d%% заряд"},
}
const ROLL_TIERS := [1.0, 0.9, 0.8, 0.7]   # по 25% каждая
const STAT_KEYS := ["hp", "dmg", "crit", "atk", "ult"]
var impl_sel := 0          # выбранный боец в экране экипировки
var impl_hero_btns := []   # кнопки-портреты переключения бойца
# СКЕЛЕТ-РАСКЛАДКА: слоты имплантов+оружие на неон-силуэте тела (по анатомии)
var impl_slots := {}       # key -> {btn, sb(стиль рамки), star(★+дубли); weapon ещё ic}
var impl_seln := "core"    # выбранный слот
var impl_selv := ""        # выбранная модель (variant id) для прокачки
var dry_streak := 0        # дропов подряд без редкого (≥3) — bad-luck protection
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

func _new_gear() -> Dictionary:
	var gear := {}
	var equip := {}
	for slot in ITEM_VARIANTS:
		gear[slot] = {}
		var first = ITEM_VARIANTS[slot][0]
		var key := _ik(first["id"], 1)
		gear[slot][key] = {"vid": first["id"], "rarity": 1, "lvl": 1, "dupes": 0, "rolls": [_roll_stat(first["stat"])]}
		equip[slot] = key
	return {"gear": gear, "equip": equip}

func _roll_stat(stat: String) -> Dictionary:
	var tier: float = ROLL_TIERS[randi() % ROLL_TIERS.size()]
	var val: int = max(1, int(round(STAT_ROLL[stat]["max"] * tier)))
	return {"stat": stat, "val": val}

func _variant(slot: String, vid: String) -> Dictionary:
	for v in ITEM_VARIANTS[slot]:
		if v["id"] == vid:
			return v
	return ITEM_VARIANTS[slot][0]

# создать предмет: primary-стат модели + (rarity-1) случайных доп-статов
func _make_item(slot: String, vid: String, rarity: int) -> Dictionary:
	var v := _variant(slot, vid)
	var rolls := [_roll_stat(v["stat"])]
	var others := STAT_KEYS.duplicate()
	others.erase(v["stat"])
	others.shuffle()
	for i in range(min(rarity - 1, others.size())):
		rolls.append(_roll_stat(others[i]))
	return {"vid": vid, "rarity": rarity, "lvl": 1, "dupes": 0, "rolls": rolls}

func _item_power(it: Dictionary) -> int:   # грубая сила для сравнения «перефармить?»
	var s := 0
	for r in it["rolls"]:
		s += int(r["val"])
	return s + it["rarity"] * 8

# гейт редкости по прогрессу (CONCEPT §14, LOOT-RULES): лестница ДЛИННАЯ — топ это chase на недели,
# не на 20 волн. Серое носишь долго; цвет открывается редко и далеко.
func _max_rarity() -> int:
	if wave >= 220: return 4   # Фиолет — очень поздно
	if wave >= 100: return 3   # Синий
	if wave >= 35: return 2    # Зелёный
	return 1                   # старт: только Серый (≈первые 35 волн)

func _min_rarity() -> int:
	# пол поднимается ОЧЕНЬ поздно, чтобы серое/зелёное оставалось актуально долго
	if wave >= 300: return 2
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
		var mult: float = 1.0 + (inst["lvl"] - 1) * 0.25
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
	var tank := false; var snipe := false; var storm := false; var hak := false
	for hh in heroes:
		if not hh["alive"]: continue
		match hh["data"]["atk_type"]:
			"tank": tank = true
			"snipe": snipe = true
			"single": storm = true
			"aoe": hak = true
	aura_hp = 1.0 + (0.10 if tank else 0.0)    # танк → +10% HP всем
	aura_dmg = 1.0 + (0.08 if snipe else 0.0)  # снайпер → +8% урон всем
	aura_atk = 1.0 + (0.10 if storm else 0.0)  # штурм → +10% скор. атаки
	aura_ult = 0.82 if hak else 1.0            # хакер → ульты заряжаются быстрее
	for hh in heroes:
		_recalc_hero(hh)

# пер-героя: УРОВЕНЬ (множитель) × БАЗА (класс + пушка + НАДЕТЫЕ шмотки с роллами)
func _recalc_hero(hh: Dictionary) -> void:
	var lv: int = hh["level"]
	var wbonus: int = (hh["wlvl"] - 1) * int(max(5, hh["data"]["dmg"] * 0.35))   # ОРУЖИЕ = главный урон
	var base_dmg: int = hh["data"]["dmg"] + wbonus + int(_gear_bonus(hh, "dmg"))
	var base_hp: int = hh["data"]["hp"] + int(_gear_bonus(hh, "hp"))
	hh["dmg"] = int(round(base_dmg * (1.0 + (lv - 1) * hh["data"]["dmgg"])))
	hh["max"] = int(base_hp * (1.0 + (lv - 1) * hh["data"]["hpg"]) * aura_hp)
	# крит / скорость атаки / заряд ульты — от надетых шмоток
	hh["crit"] = clamp(hh["data"]["crit"] + _gear_bonus(hh, "crit") / 100.0, 0.0, 0.95)
	hh["atk_mult"] = 1.0 + _gear_bonus(hh, "atk") / 100.0
	hh["ult_cd_eff"] = hh["data"]["ult_cd"] * aura_ult * max(0.4, 1.0 - _gear_bonus(hh, "ult") / 100.0)
	if hh["hp"] > hh["max"]: hh["hp"] = hh["max"]

func _ready() -> void:
	randomize()
	_setup_font()
	_build()
	_reset()

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
	stage = 1
	sub = 1
	in_boss = false
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
		var g: Dictionary = _new_gear()
		heroes.append({
			"data": h, "node": d, "hp": h["hp"], "max": h["hp"],
			"dmg": h["dmg"], "atk_spd": h["atk"],
			"level": 1, "lvl_cost": 30,
			"wlvl": 1, "wdupes": 0, "gear": g["gear"], "equip": g["equip"],
			"crit": h["crit"], "atk_mult": 1.0, "ult_cd_eff": h["ult_cd"],
			"t": h["atk"], "ult_t": h["ult_cd"], "alive": true, "shield": 0.0, "atk_anim": 0.0
		})
	_recalc_auras()
	_start_march()
	_refresh_hud()

func _start_march() -> void:
	# HP восстанавливается между боями (роли в бою, но без накопит. гринда)
	for hh in heroes:
		if not hh["alive"]:
			hh["alive"] = true
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

func _spawn_wave() -> void:
	var boss := in_boss
	wave = (stage - 1) * 5 + (5 if boss else sub)   # сложность по стадии/позиции (фарм НЕ инфлейтит)
	var count := (1 if boss else (1 + (sub % 3)))
	var hpmul := pow(1.12, wave)   # мягко-экспоненциальный рост HP (LOOT-RULES §10) → стена→гринд
	for j in count:
		var glow := Color("#ff5050") if not boss else Color("#ff2d95")
		var es: float = 1.9 if boss else (1.35 - j * 0.1)
		var d := _make_char("enemy", -1, es, glow)
		var px := 420.0 + j * 60.0                          # фронт-враг ближе к центру
		var ey := GROUND_Y + 62.0 - (0.0 if boss else j * 20.0)  # на дороге, задние чуть выше (изо)
		d.position = Vector2(700, ey)                        # въезжают справа
		d.z_index = int(ey)
		world.add_child(d)
		var ehp := int(45.0 * hpmul * (3.0 if boss else 1.0))   # босс = скачок ×3 (стена-пик)
		enemies.append({
			"node": d, "hp": ehp, "max": ehp,
			"dmg": int((10 if boss else 7) * pow(1.075, wave)),   # урон тоже растёт → живучесть = отдельная стена
			"atk": 1.5 if boss else 1.1, "t": 1.5, "alive": true, "boss": boss,
			"home": Vector2(px, ey), "atk_anim": 0.0
		})
		var tw := create_tween()
		tw.tween_property(d, "position:x", px, 0.5)
	phase = "fight"
	bg.speed = 0.0
	_refresh_hud()

func _process(delta: float) -> void:
	if phase == "dead":
		return
	gold += gold_ps * delta          # пассивный доход (idle-кор)
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
			hh["t"] = hh["atk_spd"] / spd
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

	if _all_dead(enemies):
		enemies.clear()
		if in_boss:
			# 🏆 БОСС ПРОЙДЕН → шмот (только тут!) + следующая стадия
			_drop_implant()
			stage += 1
			sub = 1
			in_boss = false
			_popup_center("🏆 СТАДИЯ %d ПРОЙДЕНА" % (stage - 1), Color("#ffd24a"))
		else:
			sub = sub + 1 if sub < 4 else 1   # фарм-круг норм-волн стадии (золото, без шмота)
		_start_march()
	elif _all_dead(heroes):
		# ☠ ВАЙП → НЕ рестарт: откат на фарм стадии (отряд воскреснет в _start_march), шмот цел
		_popup_center("☠ Босс не пройден — фарми и возвращайся" if in_boss else "☠ Отряд пал — перегруппировка", Color("#ff5050"))
		in_boss = false
		sub = 1
		_start_march()
	_refresh_hud()

func _hero_hit(hh: Dictionary) -> void:
	var e = _first_alive(enemies)
	if e == null: return
	hh["atk_anim"] = 0.18
	var base := int(round(hh["dmg"] * aura_dmg * hack_mult))
	var crit_ch: float = hh["crit"]   # база крит + надетые шмотки
	var is_crit: bool = randf() < crit_ch
	if is_crit: base = int(base * hh["data"]["critx"])
	if hh["data"]["atk_type"] == "aoe":
		# ХАКЕР: взлом — бьёт ВСЕХ врагов по чуть-чуть
		for en in enemies:
			if en["alive"]:
				_deal(hh, en, max(1, int(base * 0.55)), is_crit)
	else:
		_deal(hh, e, base, is_crit)   # снайпер/штурм/танк — одна цель

func _deal(hh: Dictionary, e: Dictionary, d: int, is_crit := false) -> void:
	e["hp"] = max(0, e["hp"] - d)
	var col: Color = Color("#ffe14d") if is_crit else hh["data"]["color"]
	var sz := 38 if is_crit else 26
	_popup(str(d) + ("!" if is_crit else ""), col, e["node"].position + Vector2(randf_range(-10, 10), -86), sz)
	if e["hp"] <= 0 and e["alive"]:
		e["alive"] = false
		gold += (40.0 if e.get("boss", false) else 5.0) * (1.0 + wave * 0.15)
		_fall(e["node"])

func _enemy_hit(e: Dictionary) -> void:
	var hh = _front_hero()
	if hh == null: return
	e["atk_anim"] = 0.18
	var dmg: int = e["dmg"]
	if hh["shield"] > 0.0: dmg = int(dmg * 0.4)
	hh["hp"] = max(0, hh["hp"] - dmg)
	_popup("-" + str(dmg), Color("#ff4d4d"), hh["node"].position + Vector2(0, -86))
	if hh["hp"] <= 0 and hh["alive"]:
		hh["alive"] = false
		_fall(hh["node"])
		_recalc_auras()   # пал боец → пропала его аура

func _use_ult(i: int) -> void:
	if phase != "fight": return
	var hh = heroes[i]
	if not hh["alive"] or hh["ult_t"] > 0.0: return
	if hh["data"]["ult"] == "burst":
		# СНАЙПЕР: вход в режим прицела (ульта тратится при выстреле)
		aim_mode = true
		aim_hero = hh
		status_label.text = "🎯 ВЫБЕРИ ЦЕЛЬ — тапни врага"
		status_label.modulate = hh["data"]["color"]
		return
	hh["ult_t"] = hh["ult_cd_eff"]
	hh["atk_anim"] = 0.25
	match hh["data"]["ult"]:
		"barrage":
			# ШТУРМ: всем +скорость атаки на время
			atk_buff_t = 6.0
			_popup_center("🔫 ШКВАЛ\nотряд: скорость атаки ↑", hh["data"]["color"])
		"shield":
			# ТАНК: щит всей команде
			for h2 in heroes:
				if h2["alive"]:
					h2["shield"] = 4.0
					h2["hp"] = min(h2["max"], h2["hp"] + 30)
			_popup_center("🦾 ЩИТ ОТРЯДУ", hh["data"]["color"])
		"hack":
			# ХАКЕР: мощная плюха по всем врагам
			for en in enemies:
				if en["alive"]:
					_deal(hh, en, int(hh["dmg"] * 5 * aura_dmg * hack_mult))
			_popup_center("💻 ВЗЛОМ-ПЛЮХА", hh["data"]["color"])
	_refresh_hud()

# выстрел снайпер-ульты по цели (общий для ручного тапа и авто-боя)
func _sniper_fire(sn, target) -> void:
	sn["ult_t"] = sn["ult_cd_eff"]
	sn["atk_anim"] = 0.25
	var d := int(sn["dmg"] * 12 * aura_dmg)
	_deal(sn, target, d, true)
	_popup("🎯 " + str(d), Color("#00f0ff"), target["node"].position + Vector2(0, -115), 46)

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
	if in_boss or phase == "dead":
		return
	in_boss = true
	qte_t = 4.0; qte_win = 0.0
	if qte_btn: qte_btn.visible = false
	for e in enemies:
		if e["node"]: e["node"].queue_free()
	enemies.clear()
	_start_march()   # следующий спавн = босс (in_boss=true)
	_refresh_hud()

# QTE на боссе: периодически замах → окно реакции → контр-бёрст или тяжёлый удар по отряду
func _qte_tick(delta: float) -> void:
	var boss = null
	for e in enemies:
		if e.get("boss", false) and e["alive"]:
			boss = e; break
	if boss == null:
		if qte_btn: qte_btn.visible = false
		return
	if qte_win > 0.0:                       # окно активно
		qte_win -= delta
		if qte_win <= 0.0:                   # прозевал → босс бьёт тяжело
			_qte_miss(boss)
	else:
		qte_t -= delta
		if qte_t <= 0.0:                     # замах → показать кнопку
			qte_win = 1.3
			qte_btn.visible = true
			_popup_center("⚠ ЗАМАХ БОССА — КОНТЕР!", Color("#ffd24a"))

func _qte_hit() -> void:
	if qte_win <= 0.0 or not in_boss:
		return
	qte_win = 0.0
	qte_btn.visible = false
	var boss = null
	for e in enemies:
		if e.get("boss", false) and e["alive"]:
			boss = e; break
	if boss == null:
		return
	# контр-бёрст: % от HP босса + залп урона отряда
	var sq := 0
	for hh in heroes:
		if hh["alive"]: sq += int(hh["dmg"])
	var d: int = int(boss["max"] * 0.07) + sq * 3
	var att = _first_alive(heroes)
	if att != null:
		_deal(att, boss, d, true)
	else:
		boss["hp"] = max(0, boss["hp"] - d)
	_popup_center("⚡ КОНТЕР! −%d" % d, Color("#00f0ff"))
	qte_t = 4.5                              # до следующего замаха

func _qte_miss(boss) -> void:
	qte_btn.visible = false
	var fh = _front_hero()
	if fh != null:
		var dmg: int = int(boss["dmg"] * 2.5)
		fh["hp"] -= dmg
		_popup(str(dmg), Color("#ff3030"), fh["node"].position + Vector2(0, -90), 34)
		if fh["hp"] <= 0:
			fh["hp"] = 0; fh["alive"] = false
			_recalc_auras()
	qte_t = 4.5

func _toggle_auto() -> void:
	auto_battle = not auto_battle
	auto_btn.text = "🤖 АВТО on" if auto_battle else "🤖 АВТО off"
	auto_btn.modulate = Color(1.3, 1.3, 0.6) if auto_battle else Color(1, 1, 1)
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
	status_label.text = "☠ ОТРЯД ПАЛ — дошли до волны %d" % wave
	status_label.modulate = Color("#ff4d4d")

# --- АНИМАЦИЯ БОЛВАНЧИКОВ ---
func _animate(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
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
		var want := "hit" if o["atk_anim"] > 0.0 else ("walk" if marching else "idle")
		if spr.animation != want:
			spr.play(want)
		spr.position.x = (o["atk_anim"] / 0.18) * 10.0   # выпад вперёд (local +x = к врагу)
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

func _fall(node: Node2D) -> void:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(node, "rotation", 1.4, 0.3)
	tw.tween_property(node, "modulate:a", 0.25, 0.3)

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
	var hf := _rect("HpFill", Vector2(-20, -86), Vector2(40, 5), glow.lightened(0.1))
	hf.visible = false
	root.add_child(hf)
	return root

func _frames(folder: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	for spec in [["walk", 10.0, true], ["idle", 6.0, true], ["hit", 14.0, false]]:
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
	wave_label.text = ("СТАДИЯ %d · 👹 БОСС" % stage if in_boss else "СТАДИЯ %d · волна %d/4" % [stage, sub]) + ("   ⚔" if phase == "fight" else "   ▶")
	if boss_btn:
		boss_btn.visible = not in_boss   # «К боссу» — только в фарм-режиме
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
		boss_lbl.text = "⚠ БОСС   %d / %d" % [bz["hp"], bz["max"]]
	for i in heroes.size():
		var hh = heroes[i]
		var ready_ult: bool = hh["alive"] and hh["ult_t"] <= 0.0
		hero_ults[i].disabled = not ready_ult
		hero_ults[i].text = "%s %s\n%s" % [hh["data"]["icon"], hh["data"]["name"], ("⚡УЛЬТА" if ready_ult else "%.0f" % hh["ult_t"])]
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
	# прогресс стадии: 4 норм-волны + ворота-босс
	var flags := ""
	for k in range(1, 5):
		flags += "▪" if k <= sub else "▫"
	flags += "  👹" if in_boss else "  ▷"
	stage_label.text = flags
	# золото + прокачка урона
	gold_label.text = "💰 %d   +%d/с" % [int(gold), int(gold_ps)]
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
	speed_btn.custom_minimum_size = Vector2(78, 36)
	speed_btn.position = Vector2(W - 94, 14)
	speed_btn.pressed.connect(_cycle_speed)
	hud.add_child(speed_btn)
	# тумблер АВТОБОЯ
	auto_btn = Button.new()
	auto_btn.text = "🤖 АВТО off"
	auto_btn.add_theme_font_size_override("font_size", 15)
	auto_btn.custom_minimum_size = Vector2(104, 36)
	auto_btn.position = Vector2(W - 204, 14)
	auto_btn.pressed.connect(_toggle_auto)
	hud.add_child(auto_btn)
	# кнопка «К БОССУ» (ворота стадии) — видна в фарм-режиме
	boss_btn = Button.new()
	boss_btn.text = "👹 К БОССУ"
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
	# QTE-кнопка «КОНТЕР!» (скилл-клапан на боссе) — видна только в активном окне
	qte_btn = Button.new()
	qte_btn.text = "⚡ КОНТЕР!"
	qte_btn.add_theme_font_size_override("font_size", 26)
	qte_btn.custom_minimum_size = Vector2(260, 84)
	qte_btn.position = Vector2(W * 0.5 - 130, 470)
	qte_btn.z_index = 50
	var qsb := StyleBoxFlat.new()
	qsb.bg_color = Color(0.95, 0.78, 0.1, 0.96); qsb.set_corner_radius_all(14)
	qsb.border_color = Color("#fff7c0"); qsb.set_border_width_all(3)
	for st in ["normal", "hover", "pressed", "focus"]:
		qte_btn.add_theme_stylebox_override(st, qsb)
	qte_btn.add_theme_color_override("font_color", Color(0.1, 0.05, 0.0))
	qte_btn.pressed.connect(_qte_hit)
	qte_btn.visible = false
	hud.add_child(qte_btn)
	# прогресс этапа (флажки до босса)
	stage_label = Label.new()
	stage_label.add_theme_color_override("font_color", Color("#7a7f99"))
	stage_label.add_theme_font_size_override("font_size", 15)
	stage_label.position = Vector2(20, 80)
	hud.add_child(stage_label)

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
	menubar.position = Vector2(0, H - 50); menubar.size = Vector2(W, 42)
	hud.add_child(menubar)
	inv_btn = Button.new()
	inv_btn.text = "📊 ПРОКАЧКА"
	inv_btn.add_theme_font_size_override("font_size", 14)
	inv_btn.custom_minimum_size = Vector2(168, 42)
	inv_btn.pressed.connect(_toggle_inv)
	menubar.add_child(inv_btn)
	impl_btn = Button.new()
	impl_btn.text = "🦾 ЭКИПИРОВКА"
	impl_btn.add_theme_font_size_override("font_size", 14)
	impl_btn.custom_minimum_size = Vector2(176, 42)
	impl_btn.pressed.connect(_toggle_impl)
	menubar.add_child(impl_btn)
	var settings_btn := Button.new()
	settings_btn.text = "⚙"
	settings_btn.add_theme_font_size_override("font_size", 18)
	settings_btn.custom_minimum_size = Vector2(60, 42)
	settings_btn.pressed.connect(func(): _popup_center("⚙ Настройки — скоро", Color("#7a7f99")))
	menubar.add_child(settings_btn)
	_build_inventory()
	_build_implants()

	# === РЕСТАРТ — в левом верхнем углу (слева от «ВОЛНА»), чтоб не задеть случайно ===
	var restart := Button.new()
	restart.text = "↻"
	restart.add_theme_font_size_override("font_size", 18)
	restart.custom_minimum_size = Vector2(46, 32)
	restart.position = Vector2(10, 14)
	restart.pressed.connect(_reset)
	hud.add_child(restart)

func _cycle_speed() -> void:
	speed_idx = (speed_idx + 1) % 3
	var v: float = [1.0, 2.0, 3.0][speed_idx]
	Engine.time_scale = v
	speed_btn.text = "⏩ x%d" % int(v)

func _toggle_inv() -> void:
	inv_open = not inv_open
	inv_panel.visible = inv_open
	if inv_open: _refresh_inv()

func _upgrade_level(i: int) -> void:
	var hh = heroes[i]
	if gold >= hh["lvl_cost"]:
		gold -= hh["lvl_cost"]
		hh["level"] += 1
		hh["lvl_cost"] = int(hh["lvl_cost"] * 1.5)
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
	title.text = "📊 ПРОКАЧКА ОТРЯДА"
	title.add_theme_color_override("font_color", Color("#ffb02e"))
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40); title.size = Vector2(W, 34)
	inv_panel.add_child(title)

	# по строке на каждого героя: УРОВЕНЬ + ПУШКА
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	rows.position = Vector2(24, 120); rows.size = Vector2(W - 48, 0)
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
		nm.text = h["icon"] + "\n" + h["name"]
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
		hero_rows.append({"lvl_btn": lb})

	var close := Button.new()
	close.text = "✕ ЗАКРЫТЬ"
	close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50)
	close.position = Vector2(W * 0.5 - 100, H - 150)   # выше рестарта (не перекрываются)
	close.pressed.connect(_toggle_inv)
	inv_panel.add_child(close)

func _refresh_inv() -> void:
	for i in heroes.size():
		var hh = heroes[i]
		var r = hero_rows[i]
		var prio := "🛡 HP" if hh["data"]["hpg"] > hh["data"]["dmgg"] else "⚔ урон"
		r["lvl_btn"].text = "⬆ УРОВЕНЬ %d   %d 💰\n+HP +урон · приоритет %s" % [hh["level"], hh["lvl_cost"], prio]
		r["lvl_btn"].disabled = gold < hh["lvl_cost"]

# --- ИМПЛАНТ-ИНВЕНТАРЬ (шмотки → база статов; уровень множит) ---
func _toggle_impl() -> void:
	impl_open = not impl_open
	impl_panel.visible = impl_open
	if impl_open: _refresh_impl()

func _merge_gear(idx: int, slot: String, key: String) -> void:
	var hh = heroes[idx]
	if not hh["gear"][slot].has(key):
		return
	var inst = hh["gear"][slot][key]
	var cost := _merge_cost(hh, slot, key)
	if inst["dupes"] >= 2 and gold >= cost:
		inst["dupes"] -= 2
		inst["lvl"] += 1      # +1 звезда ВНУТРИ редкости → роллы этой модели множатся
		gold -= cost
		_recalc_hero(hh)
		_refresh_impl()

func _equip(slot: String, key: String) -> void:
	var hh = heroes[impl_sel]
	if hh["gear"][slot].has(key):
		hh["equip"][slot] = key
		_recalc_hero(hh)
		_refresh_impl()
		_select_slot(slot)   # перерисовать панель (отметка «надето»)

# строка ролла → текст «+N стат»
func _rolls_text(it: Dictionary) -> String:
	var parts := []
	var mult: float = 1.0 + (it["lvl"] - 1) * 0.25
	for r in it["rolls"]:
		parts.append(STAT_ROLL[r["stat"]]["fmt"] % int(r["val"] * mult))
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
	title.text = "🦾 ЭКИПИРОВКА БОЙЦА"
	title.add_theme_color_override("font_color", Color("#00f0ff"))
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 26); title.size = Vector2(W, 30)
	impl_panel.add_child(title)
	# селектор бойца (4 портрета): переключает чьи импланты смотрим
	var sel := HBoxContainer.new()
	sel.add_theme_constant_override("separation", 6)
	sel.position = Vector2(W * 0.5 - 288, 70); sel.size = Vector2(576, 0)
	impl_panel.add_child(sel)
	impl_hero_btns.clear()
	for i in HEROES.size():
		var pb := Button.new()
		pb.text = HEROES[i]["icon"] + "\n" + HEROES[i]["name"]
		pb.custom_minimum_size = Vector2(138, 50)
		pb.add_theme_font_size_override("font_size", 13)
		var idx := i
		pb.pressed.connect(func(): impl_sel = idx; _refresh_impl())
		sel.add_child(pb)
		impl_hero_btns.append(pb)
	impl_slots.clear()
	# === СЛЕВА СВЕРХУ: ПОРТРЕТ БОЙЦА (сменный через селектор сверху) ===
	var pb := Panel.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(0.07, 0.10, 0.18, 0.92); psb.set_corner_radius_all(10)
	psb.border_color = Color("#00f0ff"); psb.set_border_width_all(1)
	pb.add_theme_stylebox_override("panel", psb)
	pb.position = Vector2(16, 138); pb.size = Vector2(168, 92)
	impl_panel.add_child(pb)
	eq_portrait_ic = _lbl("", 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	eq_portrait_ic.position = Vector2(16, 144); eq_portrait_ic.size = Vector2(168, 48)
	impl_panel.add_child(eq_portrait_ic)
	eq_portrait_nm = _lbl("", 15, Color("#00f0ff"), HORIZONTAL_ALIGNMENT_CENTER)
	eq_portrait_nm.position = Vector2(16, 198); eq_portrait_nm.size = Vector2(168, 22)
	impl_panel.add_child(eq_portrait_nm)
	# === СЛЕВА НИЖЕ: ПУШКА (прямоугольник + статы), отдельный предмет ===
	var wpos := Vector2(16, 246); var wsz := Vector2(168, 200)
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.13, 0.10, 0.03, 0.96); wsb.set_corner_radius_all(10)
	wsb.border_color = Color("#ffb02e"); wsb.set_border_width_all(2)
	var wbtn := Button.new()
	wbtn.position = wpos; wbtn.custom_minimum_size = wsz; wbtn.size = wsz; wbtn.text = ""
	for st in ["normal", "hover", "pressed", "focus"]:
		wbtn.add_theme_stylebox_override(st, wsb)
	wbtn.pressed.connect(func(): _select_slot("weapon"))
	impl_panel.add_child(wbtn)
	var wic := _lbl("", 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	wic.position = Vector2(wpos.x, wpos.y + 10); wic.size = Vector2(wsz.x, 52)
	impl_panel.add_child(wic)
	var wstar := _lbl("", 13, Color("#ffd24a"), HORIZONTAL_ALIGNMENT_CENTER)
	wstar.position = Vector2(wpos.x, wpos.y + 64); wstar.size = Vector2(wsz.x, 18)
	impl_panel.add_child(wstar)
	eq_wpn_stats = _lbl("", 13, Color("#e0d4b0"), HORIZONTAL_ALIGNMENT_CENTER)
	eq_wpn_stats.position = Vector2(wpos.x + 6, wpos.y + 88); eq_wpn_stats.size = Vector2(wsz.x - 12, 104)
	impl_panel.add_child(eq_wpn_stats)
	impl_slots["weapon"] = {"btn": wbtn, "sb": wsb, "star": wstar, "ic": wic}
	# === ЦЕНТР: ТЕЛО (силуэт) ===
	var bcx := 322.0
	var body := Polygon2D.new()
	body.polygon = _body_outline(bcx); body.color = Color(0.0, 0.94, 1.0, 0.10)
	impl_panel.add_child(body)
	var bout := Line2D.new()
	bout.points = _body_outline(bcx); bout.closed = true
	bout.width = 2.5; bout.default_color = Color(0.0, 0.94, 1.0, 0.5)
	bout.joint_mode = Line2D.LINE_JOINT_ROUND
	impl_panel.add_child(bout)
	var head := Polygon2D.new()
	head.polygon = _circle_pts(Vector2(bcx, 150), 30); head.color = Color(0.0, 0.94, 1.0, 0.12)
	impl_panel.add_child(head)
	_skel_line(_circle_pts(Vector2(bcx, 150), 30))
	# === СПРАВА: ИМПЛАНТЫ + СТРЕЛКИ к частям тела ===
	var short := {"neuro": "Мозг", "optic": "Глаза", "core": "Тело", "arms": "Руки", "legs": "Ноги"}
	var anchors := {
		"neuro": Vector2(bcx, 150), "optic": Vector2(bcx, 186),
		"core": Vector2(bcx, 300), "arms": Vector2(bcx + 46, 300), "legs": Vector2(bcx, 478),
	}
	var ytop := {"neuro": 125, "optic": 178, "core": 278, "arms": 340, "legs": 452}
	for key in ["neuro", "optic", "core", "arms", "legs"]:
		var y: int = ytop[key]
		_arrow(Vector2(466, y + 25), anchors[key])
		_add_slot(key, Vector2(470, y), 50, short[key])
	var hint := Label.new()
	hint.text = "Тапни пушку или слот импланта"
	hint.add_theme_color_override("font_color", Color("#5a6080"))
	hint.add_theme_font_size_override("font_size", 13)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(0, 636); hint.size = Vector2(W, 20)
	impl_panel.add_child(hint)
	var close := Button.new()
	close.text = "✕ ЗАКРЫТЬ"; close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50); close.position = Vector2(W * 0.5 - 100, H - 150)
	close.pressed.connect(_toggle_impl)
	impl_panel.add_child(close)
	_build_impl_detail()
	_build_impl_confirm()

func _refresh_impl() -> void:
	var hh = heroes[impl_sel]
	for i in impl_hero_btns.size():
		impl_hero_btns[i].modulate = Color(1, 1, 1) if i == impl_sel else Color(0.5, 0.5, 0.56)
	# портрет бойца слева
	eq_portrait_ic.text = hh["data"]["icon"]
	eq_portrait_nm.text = hh["data"]["name"]
	# статы пушки (база; % от шмоток наложатся позже — система статов пушки в CONCEPT)
	var rof: float = 1.0 / float(hh["data"]["atk"])
	eq_wpn_stats.text = "%s\n⚔ урон %d\n⏱ скоростр %.1f/с\n✷ крит %d%%" % [
		hh["data"]["wname"], int(hh["data"]["dmg"]), rof, int(hh["data"]["crit"] * 100)]
	# слоты: ★ надетой модели, цвет рамки = редкость надетого; ● = есть дубли для прокачки
	for key in impl_slots:
		var s = impl_slots[key]
		var lvl: int; var dupes: int; var rar := 1
		if key == "weapon":
			lvl = hh["wlvl"]; dupes = hh["wdupes"]
			s["ic"].text = hh["data"]["wicon"]
			s["sb"].border_color = Color("#ffb02e"); s["sb"].set_border_width_all(2)
		else:
			var vid: String = hh["equip"][key]
			var inst = hh["gear"][key][vid]
			lvl = inst["lvl"]; dupes = inst["dupes"]; rar = inst["rarity"]
			s["sb"].border_color = Color(RARITY[rar]["col"]); s["sb"].set_border_width_all(2)
		s["star"].text = "★%d" % lvl + ("  %d●" % dupes if dupes > 0 else "")
		s["star"].add_theme_color_override("font_color", Color("#ffd24a") if dupes >= 2 else Color("#7a7f99"))

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

func _select_slot(key: String) -> void:
	impl_seln = key
	_refresh_impl()
	impl_confirm.visible = false
	impl_detail.visible = true
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
	var back := Button.new(); back.text = "НАЗАД"; back.add_theme_font_size_override("font_size", 14); back.custom_minimum_size = Vector2(0, 40); back.pressed.connect(_close_detail); v.add_child(back)

func _refresh_detail() -> void:
	for c in det_list.get_children():
		c.queue_free()
	var hh = heroes[impl_sel]
	var slot: String = impl_seln
	if slot == "weapon":
		det_title.text = "%s %s · ОРУЖИЕ" % [hh["data"]["wicon"], hh["data"]["wname"]]
		det_list.add_child(_weapon_row(hh))
		return
	det_title.text = "%s %s — что наденем" % [IMPL_DEFS[slot]["icon"], IMPL_DEFS[slot]["name"]]
	# все ПРЕДМЕТЫ (модель+редкость) этого слота; надетый — первым, дальше по редкости
	var keys: Array = hh["gear"][slot].keys()
	keys.sort_custom(func(a, b):
		if hh["equip"][slot] == a: return true
		if hh["equip"][slot] == b: return false
		return hh["gear"][slot][a]["rarity"] > hh["gear"][slot][b]["rarity"])
	for key in keys:
		det_list.add_child(_variant_row(hh, slot, key))

func _variant_row(hh: Dictionary, slot: String, key: String) -> Control:
	var inst = hh["gear"][slot][key]
	var v := _variant(slot, inst["vid"])
	var rar: int = inst["rarity"]
	var equipped: bool = hh["equip"][slot] == key
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.11, 0.13, 0.2, 0.95); sb.set_corner_radius_all(10); sb.set_content_margin_all(10)
	sb.border_color = Color(RARITY[rar]["col"]); sb.set_border_width_all(3 if equipped else 2)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); card.add_child(box)
	var head := Label.new(); head.add_theme_font_size_override("font_size", 15)
	head.text = "%s · %s ★%d%s" % [v["name"], RARITY[rar]["name"], inst["lvl"], ("  ✓ НАДЕТО" if equipped else "")]
	head.add_theme_color_override("font_color", Color(RARITY[rar]["col"]))
	box.add_child(head)
	var st := Label.new(); st.text = _rolls_text(inst); st.add_theme_font_size_override("font_size", 13); st.add_theme_color_override("font_color", Color("#c7ccea")); box.add_child(st)
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 6); box.add_child(hb)
	var eqb := Button.new(); eqb.add_theme_font_size_override("font_size", 13); eqb.custom_minimum_size = Vector2(190, 38)
	eqb.text = "НАДЕТО" if equipped else "НАДЕТЬ"; eqb.disabled = equipped
	eqb.pressed.connect(func(): _equip(slot, key))
	hb.add_child(eqb)
	var upb := Button.new(); upb.add_theme_font_size_override("font_size", 13); upb.custom_minimum_size = Vector2(190, 38)
	upb.text = "⬆ УРОВЕНЬ (%d/2)" % inst["dupes"]; upb.disabled = inst["dupes"] < 2
	upb.pressed.connect(func(): impl_selv = key; _open_confirm())
	hb.add_child(upb)
	return card

func _weapon_row(hh: Dictionary) -> Control:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.10, 0.04, 0.96); sb.set_corner_radius_all(10); sb.set_content_margin_all(10)
	sb.border_color = Color("#ffb02e"); sb.set_border_width_all(2)
	card.add_theme_stylebox_override("panel", sb)
	var box := VBoxContainer.new(); box.add_theme_constant_override("separation", 4); card.add_child(box)
	var head := Label.new(); head.add_theme_font_size_override("font_size", 15); head.add_theme_color_override("font_color", Color("#ffb02e"))
	head.text = "%s ★%d · главный урон" % [hh["data"]["wname"], hh["wlvl"]]; box.add_child(head)
	var upb := Button.new(); upb.add_theme_font_size_override("font_size", 13); upb.custom_minimum_size = Vector2(0, 38)
	upb.text = "⬆ УРОВЕНЬ (%d/2)" % hh["wdupes"]; upb.disabled = hh["wdupes"] < 2
	upb.pressed.connect(func(): _open_confirm())
	box.add_child(upb)
	return card

func _close_detail() -> void:
	impl_confirm.visible = false
	impl_detail.visible = false

# === ПАНЕЛЬ B: подтверждение прокачки (кнопка «поднять уровень») ===
func _build_impl_confirm() -> void:
	impl_confirm = Control.new()
	impl_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	impl_confirm.visible = false
	impl_confirm.z_index = 2200
	impl_panel.add_child(impl_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6); dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev): if ev is InputEventMouseButton and ev.pressed: _close_confirm())
	impl_confirm.add_child(dim)
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.04, 0.99); sb.set_corner_radius_all(14)
	sb.border_color = Color("#ffb02e"); sb.set_border_width_all(2); sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	card.position = Vector2(W * 0.5 - 190, 340); card.custom_minimum_size = Vector2(380, 0)
	impl_confirm.add_child(card)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 10); card.add_child(v)
	var t := Label.new(); t.text = "Выбери вещь для прокачки"; t.add_theme_font_size_override("font_size", 17); t.add_theme_color_override("font_color", Color("#ffb02e")); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	conf_item = Label.new(); conf_item.add_theme_font_size_override("font_size", 15); conf_item.add_theme_color_override("font_color", Color("#e8e0c8")); conf_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(conf_item)
	conf_cost = Label.new(); conf_cost.add_theme_font_size_override("font_size", 14); conf_cost.add_theme_color_override("font_color", Color("#cdb27a")); conf_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(conf_cost)
	conf_btn = Button.new(); conf_btn.add_theme_font_size_override("font_size", 16); conf_btn.custom_minimum_size = Vector2(0, 50); conf_btn.pressed.connect(_do_merge_selected); v.add_child(conf_btn)
	var back := Button.new(); back.text = "НАЗАД"; back.add_theme_font_size_override("font_size", 14); back.custom_minimum_size = Vector2(0, 40); back.pressed.connect(_close_confirm); v.add_child(back)

func _open_confirm() -> void:
	impl_confirm.visible = true
	_refresh_confirm()

func _refresh_confirm() -> void:
	var hh = heroes[impl_sel]
	var nm: String; var dupes: int; var cost: int
	if impl_seln == "weapon":
		nm = "%s %s" % [hh["data"]["wicon"], hh["data"]["wname"]]
		dupes = hh["wdupes"]; cost = hh["wlvl"] * 50
	else:
		var inst = hh["gear"][impl_seln][impl_selv]
		var v := _variant(impl_seln, inst["vid"])
		nm = "%s %s · %s" % [IMPL_DEFS[impl_seln]["icon"], v["name"], RARITY[inst["rarity"]]["name"]]
		dupes = inst["dupes"]; cost = _merge_cost(hh, impl_seln, impl_selv)
	conf_item.text = "%s   (дублей: %d / 2)" % [nm, dupes]
	conf_cost.text = "Сумма прокачки: %d 💰" % cost
	var ready := dupes >= 2 and gold >= cost
	conf_btn.text = "ОБЪЕДИНИТЬ ★+1" if ready else ("НУЖНО 2 ДУБЛЯ (%d)" % dupes if dupes < 2 else "НЕ ХВАТАЕТ ЗОЛОТА")
	conf_btn.disabled = not ready

func _close_confirm() -> void:
	impl_confirm.visible = false

func _do_merge_selected() -> void:
	if impl_seln == "weapon":
		_merge_weapon(impl_sel)
	else:
		_merge_gear(impl_sel, impl_seln, impl_selv)
	_refresh_impl()
	_refresh_detail()
	_refresh_confirm()

# дроп дубликата после волны (босс гарант 2, обычная волна шанс) → копишь → мерджишь.
# 40% оружие / 60% имплант — всё ПОД КОНКРЕТНОГО бойца (случайного)
func _drop_implant() -> void:
	var amount := 2   # награда ТОЛЬКО за босса (обычные волны шмот не дают)
	implants_count += 1
	var i := randi() % heroes.size()
	var hh = heroes[i]
	if randf() < 0.4:
		hh["wdupes"] += amount
		_popup_center("🔫 ОРУЖИЕ: %s · %s %s\n+%d дубль" % [hh["data"]["name"], hh["data"]["wicon"], hh["data"]["wname"], amount], Color("#ffb02e"))
	else:
		# случайный слот+модель; редкость по прогрессу; предмет = модель@редкость
		var slot: String = IMPL_DEFS.keys()[randi() % IMPL_DEFS.size()]
		var variants = ITEM_VARIANTS[slot]
		var v = variants[randi() % variants.size()]
		var vid: String = v["id"]
		var rar := _roll_rarity()
		var key := _ik(vid, rar)
		var g = hh["gear"][slot]
		if g.has(key):
			# дубль ТОЙ ЖЕ модели И редкости → для ★-апа; роллы держим лучшие (перефарм внутри редкости)
			g[key]["dupes"] += amount
			var fresh := _make_item(slot, vid, rar)
			if _item_power(fresh) > _item_power(g[key]):
				fresh["dupes"] = g[key]["dupes"]; fresh["lvl"] = g[key]["lvl"]
				g[key] = fresh
				_popup_center("📦 %s · %s %s\nЛУЧШИЙ РОЛЛ!" % [hh["data"]["name"], RARITY[rar]["name"], v["name"]], Color(RARITY[rar]["col"]))
			else:
				_popup_center("📦 %s · %s %s\n+%d дубль" % [hh["data"]["name"], RARITY[rar]["name"], v["name"], amount], Color(RARITY[rar]["col"]))
		else:
			var it := _make_item(slot, vid, rar)
			it["dupes"] = amount - 1
			g[key] = it
			_popup_center("✨ НОВАЯ: %s · %s %s\n%s" % [hh["data"]["name"], RARITY[rar]["name"], v["name"], _rolls_text(it)], Color(RARITY[rar]["col"]))
	_recalc_hero(hh)

func _merge_weapon(i: int) -> void:
	var hh = heroes[i]
	var cost: int = hh["wlvl"] * 50
	if hh["wdupes"] >= 2 and gold >= cost:
		hh["wdupes"] -= 2
		hh["wlvl"] += 1      # +1 звезда оружия → главный урон вырос
		gold -= cost
		_recalc_hero(hh)
		_refresh_inv()

func _popup_center(txt: String, col: Color) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(W * 0.5 - 200, H * 0.42)
	l.custom_minimum_size = Vector2(400, 0)
	l.size = Vector2(400, 60)
	l.z_index = 80
	hud.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", H * 0.42 - 70, 1.4)
	tw.tween_property(l, "modulate:a", 0.0, 1.4)
	tw.chain().tween_callback(l.queue_free)
