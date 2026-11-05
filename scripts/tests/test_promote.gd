extends SceneTree
## Серверный тест повышения класса (вторая ступень), офлайн-мир.
## Запуск: xvfb-run godot --headless --path . -s res://scripts/tests/test_promote.gd

const GD := preload("res://scripts/game_data.gd")

var _fails := 0
var _checks := 0
var _world
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


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		_run()
	return false


func _run() -> void:
	_world.start_local("promo%d" % (Time.get_ticks_usec() % 100000), "sword")
	var p: Dictionary = _world.players[1]
	p["moving"] = false
	p["path"] = []
	p["dead_until"] = 0.0

	# далеко от наставника (за пределом радиуса): повышения нет
	p["pos"] = GD.PROMOTE_POS + Vector2(GD.PROMOTE_RANGE * 3.0, 0)
	p["lvl"] = 10
	p["gold"] = 1000
	_world.on_promote(1)
	_check(p["cls"] == "sword", "вдали от наставника класс не меняется")

	# рядом, но низкий уровень
	p["pos"] = GD.PROMOTE_POS
	p["lvl"] = 3
	p["gold"] = 1000
	_world.on_promote(1)
	_check(p["cls"] == "sword", "ниже уровня повышения класс не меняется")

	# рядом, уровень есть, золота нет
	p["lvl"] = GD.PROMOTE_LEVEL
	p["gold"] = GD.PROMOTE_COST - 1
	_world.on_promote(1)
	_check(p["cls"] == "sword", "без золота класс не меняется")
	_check(int(p["gold"]) == GD.PROMOTE_COST - 1, "без золота золото не списано")

	# всё выполнено: повышение и списание
	p["gold"] = GD.PROMOTE_COST + 50
	_world.on_promote(1)
	_check(p["cls"] == "paladin", "повышение меняет класс на paladin (сейчас %s)" % p["cls"])
	_check(int(p["gold"]) == 50, "золото списано за повышение (осталось %d)" % int(p["gold"]))
	_check(int(p["maxhp"]) == GD.CLASSES_T2["paladin"]["hp"] + (GD.PROMOTE_LEVEL - 1) * GD.hp_per_level("paladin"),
		"максимум HP пересчитан по второй ступени (%d)" % int(p["maxhp"]))

	# повторное повышение запрещено
	p["gold"] = 5000
	_world.on_promote(1)
	_check(p["cls"] == "paladin", "повторное повышение не применяется")
	_check(int(p["gold"]) == 5000, "повторное повышение не списывает золото")

	print("проверок повышения: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
