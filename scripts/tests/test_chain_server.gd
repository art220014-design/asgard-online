extends SceneTree
## Интеграция серверной логики цепочек на локальном мире (офлайн-режим).
## Запуск: godot --headless --path . -s res://scripts/tests/test_chain_server.gd

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
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true


func _process(_d: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if _frames == 3:
		_run()
	return false


func _run() -> void:
	var name := "ct%d" % (Time.get_ticks_usec() % 1000000)
	_world.start_local(name, "sword")
	var p: Dictionary = _world.players[1]
	p["chains"] = {}
	p["inv"] = {}
	p["gold"] = 0
	p["pos"] = GD.NPC_QUEST_POS
	p["target"] = p["pos"]
	p["moving"] = false

	# Разговор вдали от NPC не работает
	p["pos"] = GD.SPAWN_POINT
	_world.on_talk_npc(1, "quest")
	_check(not p["chains"].has("ch_village") or int(p["chains"]["ch_village"]["step"]) == 0,
		"разговор вдали от NPC не двигает цепочку")

	# Рядом с NPC: первый разговор запускает деревню
	p["pos"] = GD.NPC_QUEST_POS
	_world.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_village"]["step"]) == 1, "разговор запускает деревню, шаг 1")

	# Убийства слаймов через обработчик смерти моба
	for i in 5:
		_world._progress_quests(p, "slime")
	_check(int(p["chains"]["ch_village"]["step"]) == 2, "5 слаймов переводят деревню на разговор")

	# Финальный разговор делает цепочку готовой
	_world.on_talk_npc(1, "quest")
	_check(GD.CHAINS[0]["id"] == "ch_village", "порядок цепочек")
	_check(QLComplete(p), "после финального разговора деревня готова")

	# Сдача: награда один раз
	var gold_before := int(p["gold"])
	_world.on_chain_claim(1, "ch_village")
	_check(int(p["gold"]) == gold_before + 200, "награда 200 золота")
	_check(int(p["inv"].get("potion", 0)) == 2, "награда два зелья")
	_check(bool(p["chains"]["ch_village"]["claimed"]), "цепочка помечена сданной")
	_world.on_chain_claim(1, "ch_village")
	_check(int(p["gold"]) == gold_before + 200, "повторная сдача не даёт награду")

	# Сдача цепочки вдали от NPC не работает
	p["pos"] = GD.SPAWN_POINT
	_world.on_chain_claim(1, "ch_trail")
	_check(not p["chains"].has("ch_trail") or not bool(p["chains"]["ch_trail"].get("claimed", false)),
		"сдача вдали от NPC отклонена")

	# Уровень 10 не открывает цепочку с низким уровнем
	p["pos"] = GD.NPC_QUEST_POS
	p["lvl"] = 1
	_world.on_talk_npc(1, "quest")
	_check(not p["chains"].has("ch_chief") or int(p["chains"]["ch_chief"]["step"]) == 0,
		"ch_chief не стартует на уровне 1")

	print("проверок серверной логики: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func QLComplete(p: Dictionary) -> bool:
	var QL := preload("res://scripts/quest_logic.gd")
	return QL.is_complete(GD.CHAINS[0], p["chains"]["ch_village"])
