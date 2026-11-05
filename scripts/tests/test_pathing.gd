extends SceneTree
## Поиск пути и движение игрока в обход препятствий.
## Запуск: xvfb-run godot --headless --path . -s res://scripts/tests/test_pathing.gd

const PF := preload("res://scripts/pathfind.gd")
const GDD := preload("res://scripts/game_data.gd")

var _fails := 0
var _checks := 0
var _world
var gd
var _frames := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	var world_script = load("res://scripts/server_world.gd")
	_world = world_script.new()
	_world.name = "W"
	root.add_child(_world)
	gd = GDD.new()
	gd.name = "GD"
	root.add_child(gd)
	gd._build_map()
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		_run()
	return false


func _grid_block(w: int, h: int, walls: Array) -> Callable:
	return func(t: Vector2i) -> bool:
		return walls.has(t) or t.x < 0 or t.y < 0 or t.x >= w or t.y >= h


func _run() -> void:
	# поиск пути на сетке
	var open := _grid_block(10, 10, [])
	var p1: Array = PF.find(10, 10, open, Vector2i(0, 0), Vector2i(3, 0))
	_check(p1.size() == 3 and p1[p1.size() - 1] == Vector2i(3, 0), "путь по прямой: 3 шага")

	var wall: Array = []
	for y in range(0, 9):
		wall.append(Vector2i(5, y))
	var p2: Array = PF.find(10, 10, _grid_block(10, 10, wall), Vector2i(0, 0), Vector2i(9, 0))
	_check(not p2.is_empty(), "путь обходит стену через проход")
	_check(p2.size() >= 9 + 9, "путь через проход длиннее прямого")
	for t in p2:
		_check(not wall.has(t), "путь не проходит через стену")

	var full: Array = []
	for y in range(10):
		full.append(Vector2i(5, y))
	var p3: Array = PF.find(10, 10, _grid_block(10, 10, full), Vector2i(0, 0), Vector2i(9, 0))
	_check(p3.is_empty(), "полностью закрытая стена — пути нет")

	var p4: Array = PF.find(10, 10, _grid_block(10, 10, [Vector2i(3, 0)]), Vector2i(0, 0), Vector2i(3, 0))
	_check(p4.is_empty(), "занятая цель — пустой путь")

	var p5: Array = PF.find(10, 10, open, Vector2i(2, 2), Vector2i(2, 2))
	_check(p5.is_empty(), "старт равен цели — пустой путь")

	# реальная карта: все точки пути проходимы и соседние точки смежны
	var checked := 0
	for i in range(400):
		var a := Vector2i(_world_rand(0, 63), _world_rand(0, 63))
		var b := Vector2i(_world_rand(0, 63), _world_rand(0, 63))
		if gd.BLOCKING.get(gd.tile_at(a.x, a.y), false) or gd.BLOCKING.get(gd.tile_at(b.x, b.y), false):
			continue
		var path: Array = PF.find(gd.MAP_W, gd.MAP_H, _map_block(), a, b)
		if path.is_empty():
			continue
		checked += 1
		var prev := a
		var ok := true
		for t in path:
			if gd.BLOCKING.get(gd.tile_at(t.x, t.y), false):
				ok = false
			if absi(t.x - prev.x) + absi(t.y - prev.y) != 1:
				ok = false
			prev = t
		_check(ok, "путь %s->%s проходим и связен" % [a, b])
	_check(checked >= 10, "проверено реальных путей: %d" % checked)

	# сервер: игрок доходит до точки за препятствием и не встаёт в блок
	_world.start_local("pt%d" % (Time.get_ticks_usec() % 1000000), "sword")
	var pl: Dictionary = _world.players[1]
	_world.mobs.clear()
	pl["cds"] = {}
	pl["hp"] = pl["maxhp"]
	var pair := _find_blocked_row_pair()
	_check(not pair.is_empty(), "на карте есть пара точек с препятствием на прямой")
	if pair.is_empty():
		print("проверок пути: %d, провалов: %d" % [_checks, _fails])
		quit(1)
		return
	var start: Vector2i = pair[0]
	var end: Vector2i = pair[1]
	pl["pos"] = Vector2(start.x * 64 + 32, start.y * 64 + 32)
	pl["target"] = pl["pos"]
	pl["moving"] = false
	var goal := Vector2(end.x * 64 + 32, end.y * 64 + 32)
	_world.on_move(1, goal)
	var route: Array = pl["path"]
	var route_ok := not route.is_empty()
	for wp in route:
		var wt := Vector2i(int(wp.x) / 64, int(wp.y) / 64)
		if gd.BLOCKING.get(gd.tile_at(wt.x, wt.y), false):
			route_ok = false
	_check(route_ok, "маршрут сервера обходит препятствие")
	_check(pl["moving"], "игрок получил путь")
	var steps := 0
	var on_block := false
	while pl["moving"] and steps < 4000:
		_world._simulate(1.0 / 20.0)
		steps += 1
		var tile := Vector2i(int(pl["pos"].x) / gd.TILE, int(pl["pos"].y) / gd.TILE)
		if gd.BLOCKING.get(gd.tile_at(tile.x, tile.y), false):
			on_block = true
	_check(not on_block, "игрок ни разу не встал на препятствие")
	_check(pl["pos"].distance_to(goal) < 2.0, "игрок дошёл до цели, отклонение %.1f" % pl["pos"].distance_to(goal))

	print("проверок пути: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _find_blocked_row_pair() -> Array:
	for y in range(2, 62):
		for x in range(2, 50):
			var a := Vector2i(x, y)
			var b := Vector2i(x + 12, y)
			if gd.BLOCKING.get(gd.tile_at(a.x, a.y), false) or gd.BLOCKING.get(gd.tile_at(b.x, b.y), false):
				continue
			var crossed := false
			for k in range(1, 12):
				var m := Vector2i(x + k, y)
				if gd.BLOCKING.get(gd.tile_at(m.x, m.y), false):
					crossed = true
					break
			if crossed and not PF.find(gd.MAP_W, gd.MAP_H, _map_block(), a, b).is_empty():
				return [a, b]
	return []


func _world_rand(lo: int, hi: int) -> int:
	return randi_range(lo, hi)


func _map_block() -> Callable:
	return func(t: Vector2i) -> bool:
		return gd.BLOCKING.get(gd.tile_at(t.x, t.y), false)
