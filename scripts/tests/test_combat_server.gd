extends SceneTree
## Серверная проверка базовой атаки: кулдаун, мёртвая цель, дальность.
## Запуск: xvfb-run godot --headless --path . -s res://scripts/tests/test_combat_server.gd

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
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true


func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 3:
		_run()
	return false


func _run() -> void:
	_world.start_local("ca%d" % (Time.get_ticks_usec() % 1000000), "sword")
	var p: Dictionary = _world.players[1]
	var mob: Dictionary = _world.mobs[0]
	mob["dead"] = false
	mob["hp"] = 60
	mob["maxhp"] = 60
	mob["aggro_peer"] = 0
	p["pos"] = mob["pos"]
	p["target"] = p["pos"]
	p["moving"] = false
	p["cds"] = {}
	p["hp"] = p["maxhp"]
	var basic: String = p["skills"][0]

	_world.on_attack(1, mob["id"])
	var hp1: int = int(mob["hp"])
	_check(hp1 < 60, "первый удар наносит урон")

	_world.on_attack(1, mob["id"])
	_check(int(mob["hp"]) == hp1, "второй удар сразу после первого отклонён кулдауном")

	p["cds"][basic] = 0.0
	_world.on_attack(1, mob["id"])
	_check(int(mob["hp"]) < hp1, "удар после окончания кулдауна проходит")
	var hp2: int = int(mob["hp"])

	mob["dead"] = true
	p["cds"][basic] = 0.0
	_world.on_attack(1, mob["id"])
	_check(int(mob["hp"]) == hp2, "мёртвую цель нельзя ударить")
	mob["dead"] = false

	p["pos"] = mob["pos"] + Vector2(500, 0)
	p["cds"][basic] = 0.0
	_world.on_attack(1, mob["id"])
	_check(int(mob["hp"]) == hp2, "удар с дальнего расстояния отклонён")

	print("проверок боя: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
