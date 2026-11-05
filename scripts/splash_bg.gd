extends Control
## Фон экрана входа: вечернее небо с пульсирующей луной, горами и плывущими искрами.
## Рисуется процедурно, без внешних картинок.

var _t := 0.0
var _embers: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 2024
	for i in 70:
		_embers.append({
			"p": Vector2(rnd.randf() * 1280.0, rnd.randf() * 720.0),
			"v": rnd.randf_range(8.0, 34.0),
			"r": rnd.randf_range(1.0, 2.6),
			"ph": rnd.randf() * TAU,
		})


func _process(delta: float) -> void:
	_t += delta
	var s := _area()
	for e in _embers:
		e["p"].y -= e["v"] * delta
		e["p"].x += sin(_t + e["ph"]) * 12.0 * delta
		if e["p"].y < -6.0:
			e["p"] = Vector2(randf() * s.x, s.y + 6.0)
	queue_redraw()


func _area() -> Vector2:
	return size if size.x > 0.0 else get_viewport_rect().size


func _draw() -> void:
	var s := _area()
	var top := Color(0.04, 0.06, 0.16)
	var mid := Color(0.16, 0.10, 0.26)
	var bot := Color(0.34, 0.16, 0.22)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), Vector2(s.x, s.y * 0.6), Vector2(0, s.y * 0.6)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(0, s.y * 0.6), Vector2(s.x, s.y * 0.6), s, Vector2(0, s.y)]),
		PackedColorArray([mid, mid, bot, bot]))
	var mc := Vector2(s.x * 0.78, s.y * 0.2)
	var pulse := 0.5 + 0.5 * sin(_t * 1.2)
	for i in 7:
		draw_circle(mc, 150.0 - i * 18.0, Color(0.85, 0.8, 1.0, 0.025 + 0.02 * pulse))
	draw_circle(mc, 48.0, Color(0.96, 0.93, 0.84))
	draw_circle(mc + Vector2(-14, -6), 9.0, Color(0.88, 0.85, 0.76))
	var far := PackedVector2Array([Vector2(0, s.y)])
	var x := 0.0
	while x <= s.x:
		far.append(Vector2(x, s.y * 0.66 - sin(x * 0.006) * 46.0 - sin(x * 0.017) * 20.0))
		x += 16.0
	far.append(Vector2(s.x, s.y))
	draw_colored_polygon(far, Color(0.12, 0.08, 0.2))
	var near := PackedVector2Array([Vector2(0, s.y)])
	x = 0.0
	while x <= s.x:
		near.append(Vector2(x, s.y * 0.82 - sin(x * 0.011 + 1.3) * 34.0 - sin(x * 0.031) * 12.0))
		x += 16.0
	near.append(Vector2(s.x, s.y))
	draw_colored_polygon(near, Color(0.05, 0.04, 0.10))
	for e in _embers:
		draw_circle(e["p"], e["r"], Color(1.0, 0.72, 0.38, 0.55))
	# Название с мягким свечением и пульсацией.
	var font := ThemeDB.fallback_font
	var title := "АСГАРД"
	var fs := 64
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var pos := Vector2(s.x * 0.5 - tw * 0.5, s.y * 0.13)  # выше панели входа
	var glow := 0.5 + 0.5 * sin(_t * 1.6)
	for i in 4:
		draw_string(font, pos + Vector2(0, 0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + i * 3,
			Color(1.0, 0.7, 0.3, (0.05 + 0.03 * glow) * (4 - i)))
	draw_string(font, pos + Vector2(3, 3), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.5))
	draw_string(font, pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.92, 0.7, 0.85 + 0.15 * glow))
	draw_string(font, Vector2(s.x * 0.5 - 150.0, pos.y + 26.0), "Сказание о героях", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.85, 0.8, 0.95, 0.8))
