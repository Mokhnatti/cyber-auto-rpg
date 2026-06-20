extends Control
## Cyber Auto-RPG — болванка №1. Авто-бой 4 классов против босса.
## Цель болванки: пощупать ядро (авто-атаки разных классов + ульты = скилл-клапан).
## Всё серое/плашки, без арта. Параметры классов — наружу (массив HEROES), крутить легко.

# --- ПАРАМЕТРЫ КЛАССОВ (data-driven, крути тут) ---
const HEROES := [
	{"name": "СНАЙПЕР",   "icon": "🎯", "color": Color("#00f0ff"), "hp": 70,  "dmg": 22, "atk": 2.2, "ult": "burst",  "ult_cd": 9.0},
	{"name": "ШТУРМОВИК", "icon": "🔫", "color": Color("#ffb02e"), "hp": 110, "dmg": 9,  "atk": 0.8, "ult": "barrage","ult_cd": 8.0},
	{"name": "ТАНК",      "icon": "🦾", "color": Color("#3ad97a"), "hp": 240, "dmg": 6,  "atk": 1.6, "ult": "shield", "ult_cd": 11.0},
	{"name": "ХАКЕР",     "icon": "💻", "color": Color("#ff2d95"), "hp": 80,  "dmg": 7,  "atk": 1.4, "ult": "hack",   "ult_cd": 10.0},
]
const BOSS := {"name": "КОРП-ОХРАНА «ГОЛИАФ»", "hp": 1400, "dmg": 18, "atk": 1.5}

var heroes := []          # рантайм-состояние бойцов
var boss := {}
var hack_mult := 1.0      # дебафф от хакера (урон по боссу ×)
var hack_timer := 0.0
var battle_over := false

# --- UI-ссылки ---
var boss_bar: ProgressBar
var boss_label: Label
var log_label: Label
var hero_nodes := []      # {panel, hpbar, hplabel, ultbtn, ultlabel}
var status_label: Label
var play_field: Control

func _ready() -> void:
	_build_ui()
	_reset()

func _reset() -> void:
	battle_over = false
	hack_mult = 1.0
	hack_timer = 0.0
	boss = BOSS.duplicate()
	boss["max"] = BOSS["hp"]
	boss["t"] = BOSS["atk"]
	heroes.clear()
	for h in HEROES:
		var s: Dictionary = h.duplicate()
		s["max"] = h["hp"]
		s["t"] = h["atk"]          # таймер до атаки
		s["ult_t"] = h["ult_cd"]   # таймер готовности ульты
		s["alive"] = true
		s["shield"] = 0.0
		heroes.append(s)
	status_label.text = ""
	_log("Контракт принят. Цель: " + str(BOSS["name"]) + ".")
	_refresh()

func _process(delta: float) -> void:
	if battle_over:
		return
	# дебафф хакера
	if hack_timer > 0.0:
		hack_timer -= delta
		if hack_timer <= 0.0:
			hack_mult = 1.0
	# бойцы атакуют
	for i in heroes.size():
		var s = heroes[i]
		if not s["alive"]:
			continue
		s["ult_t"] = max(0.0, s["ult_t"] - delta)
		s["t"] -= delta
		if s["t"] <= 0.0:
			s["t"] = s["atk"]
			_hero_attack(i, s["dmg"])
	# босс атакует случайного живого
	if boss["hp"] > 0:
		boss["t"] -= delta
		if boss["t"] <= 0.0:
			boss["t"] = boss["atk"]
			_boss_attack()
	_refresh()
	_check_end()

func _hero_attack(i: int, dmg: int) -> void:
	var real := int(round(dmg * hack_mult))
	boss["hp"] = max(0, boss["hp"] - real)
	_popup(str(real), heroes[i]["color"], boss_bar.global_position + Vector2(randf_range(40, 220), -10))

func _boss_attack() -> void:
	var alive := []
	for i in heroes.size():
		if heroes[i]["alive"]:
			alive.append(i)
	if alive.is_empty():
		return
	var idx = alive[randi() % alive.size()]
	var s = heroes[idx]
	var dmg: int = boss["dmg"]
	if s["shield"] > 0.0:
		dmg = int(dmg * 0.4)   # танк-щит режет урон
	s["hp"] = max(0, s["hp"] - dmg)
	var panel: Control = hero_nodes[idx]["panel"]
	_popup("-" + str(dmg), Color("#ff4d4d"), panel.global_position + Vector2(30, -6))
	if s["hp"] <= 0:
		s["alive"] = false
		_log(s["icon"] + " " + s["name"] + " выведен из строя!")

# --- УЛЬТЫ (скилл-клапан: жмёшь руками, когда авто не вывозит) ---
func _use_ult(i: int) -> void:
	if battle_over:
		return
	var s = heroes[i]
	if not s["alive"] or s["ult_t"] > 0.0:
		return
	s["ult_t"] = s["ult_cd"]
	match s["ult"]:
		"burst":
			var d := int(s["dmg"] * 6 * hack_mult)
			boss["hp"] = max(0, boss["hp"] - d)
			_popup("УЛЬТА " + str(d), s["color"], boss_bar.global_position + Vector2(90, -20), 46)
			_log("🎯 Снайпер: прицельный выстрел — " + str(d) + "!")
		"barrage":
			var d := int(s["dmg"] * 8 * hack_mult)
			boss["hp"] = max(0, boss["hp"] - d)
			_popup("ШКВАЛ " + str(d), s["color"], boss_bar.global_position + Vector2(90, -20), 46)
			_log("🔫 Штурмовик: шквал огня — " + str(d) + "!")
		"shield":
			for h in heroes:
				if h["alive"]:
					h["shield"] = 4.0
					h["hp"] = min(h["max"], h["hp"] + 25)
			_log("🦾 Танк: щит отряду + латание брони.")
		"hack":
			hack_mult = 2.0
			hack_timer = 5.0
			_log("💻 Хакер: взлом брони — весь урон ×2 на 5 сек!")
	_refresh()

func _process_shields(delta: float) -> void:
	for h in heroes:
		if h["shield"] > 0.0:
			h["shield"] = max(0.0, h["shield"] - delta)

func _check_end() -> void:
	if boss["hp"] <= 0:
		_end(true)
		return
	var any := false
	for h in heroes:
		if h["alive"]:
			any = true
	if not any:
		_end(false)

func _end(win: bool) -> void:
	battle_over = true
	if win:
		status_label.text = "✅ ЦЕЛЬ УСТРАНЕНА"
		status_label.modulate = Color("#3ad97a")
		_log("Контракт выполнен. Чисто.")
	else:
		status_label.text = "☠ ОТРЯД ПАЛ"
		status_label.modulate = Color("#ff4d4d")
		_log("Провал. Рестарт.")

# --- РЕНДЕР СОСТОЯНИЯ ---
func _refresh() -> void:
	_process_shields(get_process_delta_time())
	boss_bar.max_value = boss["max"]
	boss_bar.value = boss["hp"]
	boss_label.text = "%s   %d / %d" % [boss["name"], boss["hp"], boss["max"]]
	for i in heroes.size():
		var s = heroes[i]
		var n = hero_nodes[i]
		n["hpbar"].max_value = s["max"]
		n["hpbar"].value = s["hp"]
		n["hplabel"].text = "%d/%d" % [s["hp"], s["max"]]
		var ready_ult: bool = s["alive"] and s["ult_t"] <= 0.0
		n["ultbtn"].disabled = not ready_ult
		n["ultlabel"].text = "УЛЬТА" if ready_ult else ("%.0f" % s["ult_t"])
		n["panel"].modulate = Color(1,1,1,1) if s["alive"] else Color(0.3,0.3,0.3,1)

# --- ВСПЛЫВАЮЩИЕ ЦИФРЫ УРОНА ---
func _popup(txt: String, col: Color, pos: Vector2, size := 30) -> void:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", size)
	l.position = pos
	l.z_index = 100
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", pos.y - 60, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)

func _log(msg: String) -> void:
	log_label.text = msg

# --- ПОСТРОЕНИЕ UI (программно — без ручных .tscn) ---
func _build_ui() -> void:
	# фон
	var bg := ColorRect.new()
	bg.color = Color("#0a0a12")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 14)
	root.offset_left = 18; root.offset_right = -18
	root.offset_top = 18; root.offset_bottom = -18
	add_child(root)

	# заголовок
	var title := Label.new()
	title.text = "CYBER AUTO-RPG · болванка боя"
	title.add_theme_color_override("font_color", Color("#ffb02e"))
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# босс
	boss_label = Label.new()
	boss_label.add_theme_color_override("font_color", Color("#ff4d4d"))
	boss_label.add_theme_font_size_override("font_size", 16)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(boss_label)
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(0, 26)
	boss_bar.show_percentage = false
	_tint_bar(boss_bar, Color("#ff2d95"))
	root.add_child(boss_bar)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	root.add_child(spacer)

	# статус + лог
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 26)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(status_label)

	log_label = Label.new()
	log_label.add_theme_color_override("font_color", Color("#7a7f99"))
	log_label.add_theme_font_size_override("font_size", 14)
	log_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(log_label)

	# растяжка вниз
	var grow := Control.new()
	grow.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(grow)

	# отряд (4 героя в ряд)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(row)
	hero_nodes.clear()
	for i in HEROES.size():
		var h = HEROES[i]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		box.custom_minimum_size = Vector2(128, 0)

		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(h["color"].r, h["color"].g, h["color"].b, 0.18)
		sb.border_color = h["color"]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		sb.set_content_margin_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		var name_l := Label.new()
		name_l.text = h["icon"] + "\n" + h["name"]
		name_l.add_theme_color_override("font_color", h["color"])
		name_l.add_theme_font_size_override("font_size", 15)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(name_l)
		box.add_child(panel)

		var hpbar := ProgressBar.new()
		hpbar.custom_minimum_size = Vector2(0, 16)
		hpbar.show_percentage = false
		_tint_bar(hpbar, h["color"])
		box.add_child(hpbar)

		var hpl := Label.new()
		hpl.add_theme_font_size_override("font_size", 12)
		hpl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(hpl)

		var ult := Button.new()
		ult.custom_minimum_size = Vector2(0, 34)
		ult.add_theme_font_size_override("font_size", 13)
		var idx := i
		ult.pressed.connect(func(): _use_ult(idx))
		box.add_child(ult)

		row.add_child(box)
		hero_nodes.append({"panel": panel, "hpbar": hpbar, "hplabel": hpl, "ultbtn": ult, "ultlabel": ult})

	# рестарт
	var restart := Button.new()
	restart.text = "↻ РЕСТАРТ"
	restart.custom_minimum_size = Vector2(0, 40)
	restart.pressed.connect(_reset)
	root.add_child(restart)

func _tint_bar(bar: ProgressBar, col: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
