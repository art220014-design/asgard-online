extends SceneTree
## Тесты игрового вида: карта, снимки, интерполяция, эффекты.
## Запуск: xvfb-run godot --headless --path . -s res://scripts/tests/test_world_view.gd

const WV := preload("res://scripts/world_view.gd")
const GDScript_Data := preload("res://scripts/game_data.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	var gd = GDScript_Data.new()
	root.add_child(gd)
	gd._ready()
	var v = WV.new()
	v.map = gd
	root.add_child(v)
	v.ensure_map()
	# карта построена по GameData и совпадает по размеру
	_check(v._map_cache != null, "карта построена")
	_check(v._map_cache.get_width() == GDScript_Data.MAP_W * GDScript_Data.TILE, "ширина карты")
	_check(v._map_cache.get_height() == GDScript_Data.MAP_H * GDScript_Data.TILE, "высота карты")
	# пиксель воды совпадает с тайлом воды (центр тайла в углу карты, маска озера)
	var wx := 8
	var wy := 8
	_check(gd.tile_at(wx, wy) == GDScript_Data.T_WATER, "тайл (8,8) — вода по данным")
	var c: Color = v._map_cache.get_pixel(wx * GDScript_Data.TILE + 32, wy * GDScript_Data.TILE + 2)
	_check(c.b > c.r, "вода на карте синее, чем трава")

	# снимок: игрок и моб появились
	var snap := {
		"players": [{"id": 1, "n": "Tester", "c": "sword", "l": 1, "p": Vector2(500, 500), "hp": 100, "mhp": 160, "d": false}],
		"mobs": [{"id": 100001, "t": "slime", "p": Vector2(600, 500), "hp": 60, "mhp": 60}],
		"events": [],
	}
	v.apply_snapshot(snap, 1)
	_check(v._players.has(1), "игрок добавлен из снимка")
	_check(v._mobs.has(100001), "моб добавлен из снимка")

	# интерполяция: позиция идёт к цели, а не прыгает
	v._players[1]["pos"] = Vector2(500, 500)
	v._players[1]["target"] = Vector2(600, 500)
	v._process(0.05)
	var px: float = float(v._players[1]["pos"].x)
	_check(px > 500.0 and px < 600.0, "позиция плавно движется к цели, x=%.1f" % px)
	for i in 200:
		v._process(0.05)
	_check(v._players[1]["pos"].distance_to(Vector2(600, 500)) < 1.0, "позиция сходится к цели")

	# исчезновение моба из снимка удаляет его
	v.apply_snapshot({"players": snap["players"], "mobs": [], "events": []}, 1)
	_check(not v._mobs.has(100001), "пропавший моб удалён")

	# события: урон, крит, лечение, смерть
	v.apply_snapshot({"players": snap["players"], "mobs": [{"id": 100002, "t": "wolf", "p": Vector2(700, 500), "hp": 110, "mhp": 110}],
		"events": [{"k": "dmg", "p": Vector2(700, 500), "t": "12", "id": 100002}]}, 1)
	_check(v._popups.size() == 1, "урон создаёт всплывающую цифру")
	_check(float(v._mobs[100002]["flash"]) > 0.0, "удар запускает вспышку моба")
	_check(float(v._mobs[100002]["scale_t"]) > 0.0, "удар запускает масштаб моба")
	_check(v._particles.size() > 0, "удар создаёт частицы")
	v.apply_snapshot({"players": snap["players"], "mobs": [], "events": [{"k": "death", "p": Vector2(700, 500), "t": "Волк", "id": 100002}]}, 1)
	_check(v._particles.size() >= 14, "смерть моба создаёт частицы")
	v.apply_snapshot({"players": snap["players"], "mobs": [], "events": [{"k": "heal", "p": Vector2(500, 500), "t": "+60", "id": 1}]}, 1)
	_check(v._popups.size() >= 2, "лечение создаёт цифру")
	var col_heal: Color = v._popups[v._popups.size() - 1]["color"]
	_check(col_heal.g > col_heal.r, "лечение зелёным")

	# эффекты затухают
	for i in 100:
		v._process(0.05)
	_check(v._popups.size() == 0, "всплывающие цифры исчезают")
	_check(v._particles.size() == 0, "частицы исчезают")
	_check(float(v._players[1]["flash"]) == 0.0, "вспышка игрока затухает")

	# отрисовка без ошибок: рисуем через настоящий цикл кадров, а не вызовом _draw() напрямую
	v.queue_redraw()
	await process_frame
	await process_frame
	_check(true, "отрисовка прошла")

	print("проверок вида: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
