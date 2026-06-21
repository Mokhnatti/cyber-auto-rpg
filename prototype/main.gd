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
var wave := 0
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
var impl_sel := 0          # выбранный боец в имплант-экране
var impl_hero_btns := []   # кнопки-портреты переключения бойца

func _new_impl() -> Dictionary:
	var d := {}
	for k in IMPL_DEFS:
		d[k] = {"lvl": 1, "dupes": 0}
	return d

func _impl_lv(hh: Dictionary, key: String) -> int:
	return hh["impl"][key]["lvl"] - 1   # вклад импланта ЭТОГО бойца (1 звезда = базовый)

func _merge_cost(hh: Dictionary, key: String) -> int:
	return hh["impl"][key]["lvl"] * 50   # золото за объединение (растёт со звёздами)
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

# пер-героя прокачка: УРОВЕНЬ (все статы) + ПУШКА (урон). Просто и понятно.
func _recalc_hero(hh: Dictionary) -> void:
	var lv: int = hh["level"]
	var wbonus: int = (hh["wlvl"] - 1) * int(max(5, hh["data"]["dmg"] * 0.35))   # ОРУЖИЕ = главный урон (база)
	var base_dmg: int = hh["data"]["dmg"] + wbonus + _impl_lv(hh, "arms") * 3   # база = класс + оружие + руки
	var base_hp: int = hh["data"]["hp"] + _impl_lv(hh, "core") * 25     # база = класс + реактор(шмотка)
	hh["dmg"] = int(round(base_dmg * (1.0 + (lv - 1) * hh["data"]["dmgg"])))   # × множитель уровня
	hh["max"] = int(base_hp * (1.0 + (lv - 1) * hh["data"]["hpg"]) * aura_hp)
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
		heroes.append({
			"data": h, "node": d, "hp": h["hp"], "max": h["hp"],
			"dmg": h["dmg"], "atk_spd": h["atk"],
			"level": 1, "lvl_cost": 30,
			"wlvl": 1, "wdupes": 0, "impl": _new_impl(),
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
	wave += 1
	var boss := (wave % 5 == 0)
	var count := (1 if boss else (1 + (wave % 3)))
	var hpmul := 1.0 + wave * 0.25
	for j in count:
		var glow := Color("#ff5050") if not boss else Color("#ff2d95")
		var es: float = 1.9 if boss else (1.35 - j * 0.1)
		var d := _make_char("enemy", -1, es, glow)
		var px := 420.0 + j * 60.0                          # фронт-враг ближе к центру
		var ey := GROUND_Y + 62.0 - (0.0 if boss else j * 20.0)  # на дороге, задние чуть выше (изо)
		d.position = Vector2(700, ey)                        # въезжают справа
		d.z_index = int(ey)
		world.add_child(d)
		var ehp := int((420.0 if boss else 45.0) * hpmul)
		enemies.append({
			"node": d, "hp": ehp, "max": ehp,
			"dmg": int((10 if boss else 7) * (1.0 + wave * 0.12)),
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
			var spd := aura_atk * (1.0 + _impl_lv(hh, "legs") * 0.04) * (1.4 if atk_buff_t > 0.0 else 1.0)
			hh["t"] = hh["atk_spd"] / spd
			_hero_hit(hh)
	for e in enemies:
		if not e["alive"]: continue
		e["t"] -= delta
		if e["t"] <= 0.0:
			e["t"] = e["atk"]
			_enemy_hit(e)
	for hh in heroes:
		if hh["shield"] > 0.0: hh["shield"] = max(0.0, hh["shield"] - delta)

	if _all_dead(enemies):
		enemies.clear()
		if _all_dead(heroes):
			return
		_drop_implant()
		_start_march()
	elif _all_dead(heroes):
		_die()
	_refresh_hud()

func _hero_hit(hh: Dictionary) -> void:
	var e = _first_alive(enemies)
	if e == null: return
	hh["atk_anim"] = 0.18
	var base := int(round(hh["dmg"] * aura_dmg * hack_mult))
	var crit_ch: float = hh["data"]["crit"] + _impl_lv(hh, "optic") * 0.02   # база крит + оптика(шмотка)
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
	hh["ult_t"] = hh["data"]["ult_cd"] * aura_ult
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
			var sn = aim_hero
			sn["ult_t"] = sn["data"]["ult_cd"] * aura_ult
			sn["atk_anim"] = 0.25
			var d := int(sn["dmg"] * 12 * aura_dmg)
			_deal(sn, best, d, true)
			_popup("🎯 " + str(d), Color("#00f0ff"), best["node"].position + Vector2(0, -115), 46)
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
	wave_label.text = "ВОЛНА  %d   📦 %d" % [max(wave, 0), implants_count] + ("   ⚔" if phase == "fight" else ("   ▶" if phase == "march" else ""))
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
		var cd: float = hh["data"]["ult_cd"]
		var fill: float = clamp((cd - hh["ult_t"]) / cd, 0.0, 1.0)
		var ch: ColorRect = hero_charge[i]
		ch.size.y = 78.0 * fill
		ch.position.y = 78.0 - 78.0 * fill
		ch.color.a = 0.5 if ready_ult else 0.22
		# hp на портрете
		hero_hp[i].size.x = 118.0 * (float(hh["hp"]) / float(hh["max"]))
		hero_hp[i].visible = hh["alive"]
	# прогресс этапа (флажки, 5-я волна = босс)
	if wave > 0:
		var win: int = ((wave - 1) % 5) + 1
		var st: int = ((wave - 1) / 5) + 1
		var flags := ""
		for k in range(1, 6):
			if k <= win:
				flags += "⚑" if k == 5 else "▪"
			else:
				flags += "▫"
		stage_label.text = "ЭТАП %d   %s" % [st, flags]
	else:
		stage_label.text = ""
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
	wave_label.position = Vector2(20, 16)
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
	inv_btn = Button.new()
	inv_btn.text = "📊 ПРОКАЧКА"
	inv_btn.add_theme_font_size_override("font_size", 14)
	inv_btn.custom_minimum_size = Vector2(152, 40)
	inv_btn.position = Vector2(W - 168, 100)
	inv_btn.pressed.connect(_toggle_inv)
	hud.add_child(inv_btn)
	_build_inventory()
	impl_btn = Button.new()
	impl_btn.text = "🦾 ИМПЛАНТЫ"
	impl_btn.add_theme_font_size_override("font_size", 14)
	impl_btn.custom_minimum_size = Vector2(152, 40)
	impl_btn.position = Vector2(W - 168, 146)
	impl_btn.pressed.connect(_toggle_impl)
	hud.add_child(impl_btn)
	_build_implants()

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
	bar.position = Vector2(0, H - 118)
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

	var restart := Button.new()
	restart.text = "↻ РЕСТАРТ"
	restart.custom_minimum_size = Vector2(160, 36)
	restart.position = Vector2(W * 0.5 - 80, H - 38)
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
		var wb := Button.new()   # ОРУЖИЕ пер-класс (мердж дублей → главный урон)
		wb.custom_minimum_size = Vector2(156, 62)
		wb.add_theme_font_size_override("font_size", 12)
		wb.pressed.connect(func(): _merge_weapon(idx))
		hb.add_child(wb)
		rows.add_child(row)
		hero_rows.append({"lvl_btn": lb, "wpn_btn": wb})

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
		var wc: int = hh["wlvl"] * 50
		r["wpn_btn"].text = "%s %s\n★%d · дубл %d\n⚙ мердж +%d💰" % [hh["data"]["wicon"], hh["data"]["wname"], hh["wlvl"], hh["wdupes"], wc]
		r["wpn_btn"].disabled = hh["wdupes"] < 2 or gold < wc

# --- ИМПЛАНТ-ИНВЕНТАРЬ (шмотки → база статов; уровень множит) ---
func _toggle_impl() -> void:
	impl_open = not impl_open
	impl_panel.visible = impl_open
	if impl_open: _refresh_impl()

func _merge_impl(idx: int, key: String) -> void:
	var hh = heroes[idx]
	var sl = hh["impl"][key]
	var cost := _merge_cost(hh, key)
	if sl["dupes"] >= 2 and gold >= cost:
		sl["dupes"] -= 2
		sl["lvl"] += 1      # +1 звезда → база статов ЭТОГО бойца выросла
		gold -= cost
		_recalc_hero(hh)
		_refresh_impl()

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
	title.text = "🦾 ИМПЛАНТЫ — на каждого бойца"
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
	# 5 слотов выбранного бойца
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 9)
	rows.position = Vector2(W * 0.5 - 250, 150); rows.size = Vector2(500, 0)
	impl_panel.add_child(rows)
	impl_rows.clear()
	for key in IMPL_DEFS:
		var im = IMPL_DEFS[key]
		var row := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.12, 0.2, 0.92)
		sb.set_corner_radius_all(8); sb.set_content_margin_all(8)
		sb.border_color = Color("#2a3358"); sb.set_border_width_all(1)
		row.add_theme_stylebox_override("panel", sb)
		row.custom_minimum_size = Vector2(496, 0)
		var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation", 8); row.add_child(hb)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var nm := Label.new(); nm.text = im["icon"] + " " + im["name"]; nm.add_theme_font_size_override("font_size", 14); info.add_child(nm)
		var st := Label.new(); st.add_theme_color_override("font_color", Color("#7a7f99")); st.add_theme_font_size_override("font_size", 12); info.add_child(st)
		hb.add_child(info)
		var ab := Button.new(); ab.custom_minimum_size = Vector2(108, 48); ab.add_theme_font_size_override("font_size", 12)
		var k: String = key
		ab.pressed.connect(func(): _merge_impl(impl_sel, k))
		hb.add_child(ab)
		rows.add_child(row)
		impl_rows[key] = {"stat": st, "btn": ab}
	var close := Button.new()
	close.text = "✕ ЗАКРЫТЬ"; close.add_theme_font_size_override("font_size", 16)
	close.custom_minimum_size = Vector2(200, 50); close.position = Vector2(W * 0.5 - 100, H - 150)
	close.pressed.connect(_toggle_impl)
	impl_panel.add_child(close)

func _refresh_impl() -> void:
	var hh = heroes[impl_sel]
	for i in impl_hero_btns.size():
		impl_hero_btns[i].modulate = Color(1, 1, 1) if i == impl_sel else Color(0.5, 0.5, 0.56)
	for key in IMPL_DEFS:
		var im = IMPL_DEFS[key]
		var sl = hh["impl"][key]
		var r = impl_rows[key]
		r["stat"].text = "★%d · %s · дублей: %d" % [sl["lvl"], im["slot"], sl["dupes"]]
		var cost := _merge_cost(hh, key)
		r["btn"].text = "⚙ ОБЪЕДИНИТЬ\n2 дубля + %d 💰" % cost
		r["btn"].disabled = sl["dupes"] < 2 or gold < cost

# дроп дубликата после волны (босс гарант 2, обычная волна шанс) → копишь → мерджишь.
# 40% оружие / 60% имплант — всё ПОД КОНКРЕТНОГО бойца (случайного)
func _drop_implant() -> void:
	var was_boss := (wave % 5 == 0)
	if not was_boss and randf() > 0.5:
		return
	var amount := 2 if was_boss else 1
	implants_count += 1
	var i := randi() % heroes.size()
	var hh = heroes[i]
	if randf() < 0.4:
		hh["wdupes"] += amount
		_popup_center("🔫 ОРУЖИЕ: %s · %s %s\n+%d дубль" % [hh["data"]["name"], hh["data"]["wicon"], hh["data"]["wname"], amount], Color("#ffb02e"))
	else:
		var keys := IMPL_DEFS.keys()
		var key: String = keys[randi() % keys.size()]
		hh["impl"][key]["dupes"] += amount
		var im = IMPL_DEFS[key]
		_popup_center("📦 ИМПЛАНТ: %s · %s %s\n+%d дубль" % [hh["data"]["name"], im["icon"], im["name"], amount], Color("#00f0ff"))

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
