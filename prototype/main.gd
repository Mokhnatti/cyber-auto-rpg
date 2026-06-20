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
	hack_mult = 1.0
	hack_t = 0.0
	status_label.text = ""
	# спавн отряда
	for i in HEROES.size():
		var h = HEROES[i]
		var d := _make_doll(h["color"], 1, 1.0)
		d.position = Vector2(70 + i * 52, GROUND_Y)
		world.add_child(d)
		heroes.append({
			"data": h, "node": d, "hp": h["hp"], "max": h["hp"],
			"t": h["atk"], "ult_t": h["ult_cd"], "alive": true, "shield": 0.0, "atk_anim": 0.0
		})
	_start_march()
	_refresh_hud()

func _start_march() -> void:
	phase = "march"
	march_t = 2.4
	bg.speed = 220.0

func _spawn_wave() -> void:
	wave += 1
	var boss := (wave % 5 == 0)
	var count := (1 if boss else (1 + (wave % 3)))
	var hpmul := 1.0 + wave * 0.25
	for j in count:
		var col := Color("#ff5050") if not boss else Color("#ff2d95")
		var sc := 1.0 if not boss else 1.7
		var d := _make_doll(col, -1, sc)
		var px := 540.0 - j * 56.0
		d.position = Vector2(680, GROUND_Y)            # въезжают справа
		world.add_child(d)
		var ehp := int((420.0 if boss else 45.0) * hpmul)
		enemies.append({
			"node": d, "hp": ehp, "max": ehp,
			"dmg": int((10 if boss else 7) * (1.0 + wave * 0.12)),
			"atk": 1.5 if boss else 1.1, "t": 1.5, "alive": true,
			"home": Vector2(px, GROUND_Y), "atk_anim": 0.0
		})
		var tw := create_tween()
		tw.tween_property(d, "position:x", px, 0.5)
	phase = "fight"
	bg.speed = 0.0
	_refresh_hud()

func _process(delta: float) -> void:
	if phase == "dead":
		return
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
			hh["t"] = hh["data"]["atk"]
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
		_start_march()
	elif _all_dead(heroes):
		_die()
	_refresh_hud()

func _hero_hit(hh: Dictionary) -> void:
	var e = _first_alive(enemies)
	if e == null: return
	hh["atk_anim"] = 0.18
	var d := int(round(hh["data"]["dmg"] * hack_mult))
	e["hp"] = max(0, e["hp"] - d)
	_popup(str(d), hh["data"]["color"], e["node"].position + Vector2(randf_range(-10,10), -86))
	if e["hp"] <= 0 and e["alive"]:
		e["alive"] = false
		_fall(e["node"])

func _enemy_hit(e: Dictionary) -> void:
	var hh = _first_alive(heroes)
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
				var d := int(hh["data"]["dmg"] * mul * hack_mult)
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
	if not o["alive"]:
		return
	var legL: Control = d.get_node("LegL")
	var legR: Control = d.get_node("LegR")
	var body: Node2D = d.get_node("Body")
	if marching:
		var ph: float = t * 9.0 + d.position.x
		legL.position.y = 14 - max(0.0, sin(ph)) * 8.0
		legR.position.y = 14 - max(0.0, sin(ph + PI)) * 8.0
		body.position.y = -sin(ph * 2.0) * 2.0
	else:
		legL.position.y = 14
		legR.position.y = 14
		var bob := sin(t * 3.0 + d.position.x) * 1.5
		body.position.y = bob
	# выпад при атаке
	if o["atk_anim"] > 0.0:
		o["atk_anim"] = max(0.0, o["atk_anim"] - delta)
		var dir := 1.0 if o.has("data") else -1.0
		body.position.x = dir * (o["atk_anim"] / 0.18) * 12.0
	else:
		body.position.x = 0.0
	# hp-бар
	var bar: ColorRect = d.get_node("HpFill")
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
func _make_doll(col: Color, facing: int, scale: float) -> Node2D:
	var root := Node2D.new()
	root.scale = Vector2(facing * scale, scale)
	# ноги
	root.add_child(_rect("LegL", Vector2(-7, 0), Vector2(6, 16), col.darkened(0.3)))
	root.add_child(_rect("LegR", Vector2(2, 0), Vector2(6, 16), col.darkened(0.3)))
	# тело-капсула
	var body := Node2D.new(); body.name = "Body"
	body.add_child(_rect("T", Vector2(-12, -42), Vector2(24, 42), col))
	body.add_child(_rect("H", Vector2(-9, -60), Vector2(18, 18), col.lightened(0.2)))
	# "глаз"-визор
	body.add_child(_rect("V", Vector2(-7, -54), Vector2(14, 4), Color(1,1,1,0.85)))
	root.add_child(body)
	# hp-бар над головой
	root.add_child(_rect("HpBg", Vector2(-20, -78), Vector2(40, 5), Color(0,0,0,0.6)))
	root.add_child(_rect("HpFill", Vector2(-20, -78), Vector2(40, 5), col.lightened(0.1)))
	return root

func _rect(nm: String, pos: Vector2, size: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = nm; r.position = pos; r.size = size; r.color = col
	return r

# --- HUD ---
func _refresh_hud() -> void:
	wave_label.text = "ВОЛНА  %d" % max(wave, 0) + ("   ⚔ БОЙ" if phase == "fight" else ("   ▶ марш" if phase == "march" else ""))
	for i in heroes.size():
		var hh = heroes[i]
		var ready_ult: bool = hh["alive"] and hh["ult_t"] <= 0.0
		hero_ults[i].disabled = not ready_ult
		hero_ults[i].text = "%s\n%s" % [hh["data"]["icon"], ("УЛЬТА" if ready_ult else "%.0f" % hh["ult_t"])]
		hero_ults[i].modulate = Color(1,1,1,1) if hh["alive"] else Color(0.4,0.4,0.4,1)

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

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(W * 0.5 - 200, 70)
	status_label.custom_minimum_size = Vector2(400, 0)
	status_label.size = Vector2(400, 30)
	hud.add_child(status_label)

	# панель ульт снизу
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.position = Vector2(0, H - 110)
	bar.size = Vector2(W, 70)
	hud.add_child(bar)
	hero_ults.clear()
	for i in HEROES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(128, 60)
		b.add_theme_font_size_override("font_size", 15)
		var idx := i
		b.pressed.connect(func(): _use_ult(idx))
		bar.add_child(b)
		hero_ults.append(b)

	var restart := Button.new()
	restart.text = "↻ РЕСТАРТ"
	restart.custom_minimum_size = Vector2(160, 36)
	restart.position = Vector2(W * 0.5 - 80, H - 38)
	restart.pressed.connect(_reset)
	hud.add_child(restart)
