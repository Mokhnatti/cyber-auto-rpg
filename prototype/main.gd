extends Control
## Cyber Auto-RPG — болванка №2: РАННЕР-ВИД.
## Отряд "бежит на месте", параллакс-город едет навстречу, волны врагов догоняют →
## бой на месте → победили → марш дальше. Бесконечный поход, считаем волны.
## Болванчики процедурные (без арта). Параметры классов наружу. Ульты = скилл-клапан.

const HEROES := [
	{"name": "СНАЙП", "icon": "🎯", "color": Color("#00f0ff"), "hp": 80,  "dmg": 20, "atk": 2.0, "ult": "burst",  "ult_cd": 9.0},
	{"name": "ШТУРМ", "icon": "🔫", "color": Color("#ffb02e"), "hp": 120, "dmg": 9,  "atk": 0.8, "ult": "barrage","ult_cd": 8.0},
	{"name": "ТАНК",  "icon": "🦾", "color": Color("#3ad97a"), "hp": 260, "dmg": 6,  "atk": 1.6, "ult": "shield", "ult_cd": 11.0},
	{"name": "ХАКЕР", "icon": "💻", "color": Color("#ff2d95"), "hp": 90,  "dmg": 7,  "atk": 1.4, "ult": "hack",   "ult_cd": 10.0},
]
const W := 600.0
const H := 960.0
const GROUND_Y := 0.72 * H
# изо-формация (индекс = HEROES: 0 снайпер, 1 штурм, 2 танк, 3 хакер). y<0 = дальше/выше, s = масштаб
const FORMATION := [
	{"x": 70.0,  "y": -70.0, "s": 0.80},   # снайпер — задняя линия (дальше, мельче)
	{"x": 140.0, "y": -32.0, "s": 0.92},   # штурмовик — мид
	{"x": 220.0, "y": 10.0,  "s": 1.08},   # ТАНК — передняя линия (ближе, крупнее)
	{"x": 158.0, "y": -54.0, "s": 0.86},   # хакер — мид-зад
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
var gold_ps := 2.0          # пассивный доход в секунду
var dmg_mult := 1.0         # глобальный множитель урона (прокачка за золото)
var upg_cost := 50          # цена след. апгрейда урона
var gold_label: Label
var upg_btn: Button
var boss_timer := 0.0       # таймер DPS-гейта на боссе

func _ready() -> void:
	randomize()
	_build()
	_reset()

func _reset() -> void:
	for c in world.get_children():
		c.queue_free()
	heroes.clear()
	enemies.clear()
	wave = 0
	implants_count = 0
	gold = 0.0
	dmg_mult = 1.0
	upg_cost = 50
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
			"t": h["atk"], "ult_t": h["ult_cd"], "alive": true, "shield": 0.0, "atk_anim": 0.0
		})
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
		var es: float = 1.7 if boss else (1.0 - j * 0.07)
		var d := _make_char("enemy", -1, es, glow)
		var px := 430.0 + j * 48.0                          # фронт-враг ближе к центру
		var ey := GROUND_Y - (0.0 if boss else j * 30.0)    # задние выше (изо)
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
			hh["t"] = hh["atk_spd"]
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
	var d := int(round(hh["dmg"] * dmg_mult * hack_mult))
	e["hp"] = max(0, e["hp"] - d)
	_popup(str(d), hh["data"]["color"], e["node"].position + Vector2(randf_range(-10,10), -86))
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

func _use_ult(i: int) -> void:
	if phase != "fight": return
	var hh = heroes[i]
	if not hh["alive"] or hh["ult_t"] > 0.0: return
	hh["ult_t"] = hh["data"]["ult_cd"]
	hh["atk_anim"] = 0.25
	match hh["data"]["ult"]:
		"burst", "barrage":
			var e = _first_alive(enemies)
			if e:
				var mul := 6 if hh["data"]["ult"] == "burst" else 8
				var d := int(hh["dmg"] * mul * dmg_mult * hack_mult)
				e["hp"] = max(0, e["hp"] - d)
				_popup("УЛЬТА " + str(d), hh["data"]["color"], e["node"].position + Vector2(0, -100), 40)
				if e["hp"] <= 0 and e["alive"]:
					e["alive"] = false; _fall(e["node"])
		"shield":
			for h2 in heroes:
				if h2["alive"]:
					h2["shield"] = 4.0
					h2["hp"] = min(h2["max"], h2["hp"] + 30)
		"hack":
			hack_mult = 2.0; hack_t = 5.0
			status_label.text = "💻 ВЗЛОМ: урон ×2"
			status_label.modulate = Color("#ff2d95")
			var tw := create_tween()
			tw.tween_interval(2.0)
			tw.tween_callback(func(): if phase != "dead": status_label.text = "")
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
	# неон-платформа/тень под ногами (цвет класса, симметрична → ок при flip)
	root.add_child(_rect("Glow", Vector2(-28, -8), Vector2(56, 13), Color(glow.r, glow.g, glow.b, 0.35)))
	# анимированный спрайт (CC0 RGS_Dev)
	# персонаж в кадре занимает yc 106..174 → ставим ногами на 0 (землю), крупнее
	var spr := AnimatedSprite2D.new()
	spr.name = "Spr"
	spr.sprite_frames = _frames(folder)
	spr.scale = Vector2(0.9, 0.9)
	spr.position = Vector2(0, -66.6)   # ноги (yc174) → ~0, голова (yc106) → ~-61
	spr.animation = "idle"
	spr.play("idle")
	root.add_child(spr)
	# hp-бар над головой — виден ТОЛЬКО когда ранен (управляется в _anim_doll)
	var hbg := _rect("HpBg", Vector2(-20, -74), Vector2(40, 5), Color(0, 0, 0, 0.65))
	hbg.visible = false
	root.add_child(hbg)
	var hf := _rect("HpFill", Vector2(-20, -74), Vector2(40, 5), glow.lightened(0.1))
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
	upg_btn.text = "⬆ УРОН ×%.1f\n%d 💰" % [dmg_mult + 0.5, upg_cost]
	upg_btn.disabled = gold < upg_cost

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
	upg_btn = Button.new()
	upg_btn.add_theme_font_size_override("font_size", 13)
	upg_btn.custom_minimum_size = Vector2(152, 38)
	upg_btn.position = Vector2(W - 168, 100)
	upg_btn.pressed.connect(_buy_upgrade)
	hud.add_child(upg_btn)

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

func _buy_upgrade() -> void:
	if gold >= upg_cost:
		gold -= upg_cost
		dmg_mult += 0.5
		upg_cost = int(upg_cost * 1.6)

# дроп импланта после волны → бафф живому герою (ядро-петля: бой → лут → сильнее)
func _drop_implant() -> void:
	var was_boss := (wave % 5 == 0)
	var r := randf()
	var rarity := "обычный"; var rcol := Color("#9aa0b5"); var mult := 1.0
	if was_boss or r > 0.93:
		rarity = "ЛЕГЕНДА"; rcol = Color("#ffb02e"); mult = 4.0
	elif r > 0.72:
		rarity = "эпик"; rcol = Color("#ff2d95"); mult = 2.5
	elif r > 0.42:
		rarity = "редкий"; rcol = Color("#00f0ff"); mult = 1.6
	var types := [
		{"n": "👁 Оптика", "stat": "dmg"},
		{"n": "🦾 Сервоприводы", "stat": "atk_spd"},
		{"n": "🫀 Реактор", "stat": "max"},
	]
	var t = types[randi() % types.size()]
	var alive := []
	for hh in heroes:
		if hh["alive"]: alive.append(hh)
	if alive.is_empty(): return
	var hero = alive[randi() % alive.size()]
	var label := ""
	match t["stat"]:
		"dmg":
			var a := int(3 * mult)
			hero["dmg"] += a
			label = "+%d урон" % a
		"max":
			var a := int(28 * mult)
			hero["max"] += a; hero["hp"] += a
			label = "+%d HP" % a
		"atk_spd":
			hero["atk_spd"] = max(0.3, hero["atk_spd"] - 0.07 * mult)
			label = "быстрее атака"
	implants_count += 1
	_popup_center("📦 %s [%s]\n%s → %s" % [t["n"], rarity, label, hero["data"]["name"]], rcol)

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
