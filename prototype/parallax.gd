extends Node2D
## Процедурный параллакс-фон бегущего неон-города (без ассетов).
## speed ставится извне: марш ~220, бой 0. Слои едут с разной скоростью = глубина.

var scroll := 0.0
var speed := 0.0
const W := 600.0
const H := 960.0
const GROUND_Y := 0.55 * H   # горизонт выше → дорога ещё шире

func _process(delta: float) -> void:
	scroll += speed * delta
	queue_redraw()

func _draw() -> void:
	# небо
	draw_rect(Rect2(0, 0, W, GROUND_Y), Color("#0b0d18"))
	# дальние здания (медленно)
	_buildings(0.25, 150.0, 0.34 * H, Color("#11152a"), 7, Color("#2a3358"))
	# средние здания (быстрее, с неон-окнами)
	_buildings(0.5, 110.0, 0.5 * H, Color("#171a30"), 13, Color("#00f0ff"))
	# ближние силуэты (ещё быстрее)
	_buildings(1.0, 90.0, 0.62 * H, Color("#0d1018"), 5, Color("#ff2d95"))
	# дорога
	draw_rect(Rect2(0, GROUND_Y, W, H - GROUND_Y), Color("#070709"))
	draw_line(Vector2(0, GROUND_Y), Vector2(W, GROUND_Y), Color("#ffb02e"), 2.0)
	# бегущие неон-штрихи на дороге (ощущение скорости)
	var dash_off := fmod(scroll * 1.6, 80.0)
	for i in range(-1, int(W / 80.0) + 2):
		var x := i * 80.0 - dash_off
		draw_rect(Rect2(x, GROUND_Y + 30, 40, 4), Color(0, 0.94, 1, 0.25))

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
