extends Node2D
## Процедурный параллакс-фон бегущего неон-города (без ассетов).
## speed ставится извне: марш ~220, бой 0. Слои едут с разной скоростью = глубина.

var scroll := 0.0
var speed := 0.0
const W := 600.0
const H := 960.0
const GROUND_Y := 0.55 * H   # горизонт выше → дорога ещё шире
# палитра локации (неон 3 слоёв + цвет дороги) — ставится через set_palette
var pal := [Color("#ff2d95"), Color("#00f0ff"), Color("#2a3358")]
var ground_col := Color("#ffb02e")
var bg_tex: Texture2D = null      # рисованный фон локации (скролл медленно)
var road_tex: Texture2D = null    # рисованная дорога (скролл быстрее)

func set_palette(neon_arr, ground) -> void:   # neon_arr — массив из 3 hex-строк, ground — hex-строка
	if neon_arr is Array and neon_arr.size() >= 3:
		pal = [Color(neon_arr[0]), Color(neon_arr[1]), Color(neon_arr[2])]
	ground_col = Color(ground)
	queue_redraw()

func set_textures(bg: Texture2D, road: Texture2D) -> void:
	bg_tex = bg; road_tex = road
	queue_redraw()

func _scroll_tex(tex: Texture2D, y0: float, h: float, factor: float, mirror := true) -> void:
	# тайлим текстуру по горизонтали со скроллом. mirror=зеркалить соседние тайлы (хак для НЕшовных текстур).
	# для seamless-текстур (--tile) mirror=false — иначе зеркало даёт уёбанский отражённый стык (фидбэк Рамиля)
	var tw := tex.get_width() * (h / tex.get_height())
	var s := scroll * factor
	var first_idx := int(floor(s / tw))
	var x := -(s - first_idx * tw)
	var idx := first_idx
	while x < W:
		if mirror and (idx % 2 + 2) % 2 == 1:
			draw_texture_rect(tex, Rect2(x + tw, y0, -tw, h), false)   # зеркало по X
		else:
			draw_texture_rect(tex, Rect2(x, y0, tw, h), false)
		x += tw
		idx += 1

func _process(delta: float) -> void:
	scroll += speed * delta
	queue_redraw()

func _draw() -> void:
	# небо
	draw_rect(Rect2(0, 0, W, GROUND_Y), Color("#0b0d18"))
	if bg_tex != null:
		_scroll_tex(bg_tex, 0, GROUND_Y, 0.3)   # рисованный фон-сцена (медленно)
	else:
		# процедурные здания (фолбэк)
		_buildings(0.25, 150.0, 0.34 * H, Color("#11152a"), 7, pal[2])
		_buildings(0.5, 110.0, 0.5 * H, Color("#171a30"), 13, pal[1])
		_buildings(1.0, 90.0, 0.62 * H, Color("#0d1018"), 5, pal[0])
	# дорога
	draw_rect(Rect2(0, GROUND_Y, W, H - GROUND_Y), Color("#070709"))
	if road_tex != null:
		_scroll_tex(road_tex, GROUND_Y, H - GROUND_Y, 1.0, false)   # асфальт seamless (--tile) → без зеркаления, чистый встык
	draw_line(Vector2(0, GROUND_Y), Vector2(W, GROUND_Y), ground_col, 2.0)
	if road_tex == null:
		var dash_off := fmod(scroll * 1.6, 80.0)
		for i in range(-1, int(W / 80.0) + 2):
			var x := i * 80.0 - dash_off
			draw_rect(Rect2(x, GROUND_Y + 30, 40, 4), Color(pal[1].r, pal[1].g, pal[1].b, 0.25))

func _buildings(factor: float, bw: float, base_y: float, col: Color, neon_seed: int, neon: Color) -> void:
	var off := fmod(scroll * factor, bw)
	var n := int(W / bw) + 2
	for i in range(-1, n):
		var x := i * bw - off
		# детерминированная «случайная» высота по индексу
		var k := absi(i * 928371 + neon_seed * 13) % 100
		var h := base_y * (0.5 + 0.5 * (k / 100.0))
		var top := GROUND_Y - h
		draw_rect(Rect2(x + 4, top, bw - 8, h), col)
		# неон-окна
		if (k % 3) == 0:
			for wy in range(int(top) + 14, int(GROUND_Y) - 10, 26):
				draw_rect(Rect2(x + 12, wy, 8, 8), Color(neon.r, neon.g, neon.b, 0.5))
				draw_rect(Rect2(x + bw - 26, wy, 8, 8), Color(neon.r, neon.g, neon.b, 0.35))
