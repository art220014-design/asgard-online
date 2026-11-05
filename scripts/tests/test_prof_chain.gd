extends SceneTree
## Сквозная проверка профессий на сервере: обучение → сбор → инвентарь → крафт.

var _fails := 0
var _checks := 0
var _frames := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames != 3:
		return false
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true
	var gd = root.get_node_or_null("/root/GameData")
	var PL = load("res://scripts/profession_logic.gd")
	var SW = load("res://scripts/server_world.gd")
	var w = SW.new()
	root.add_child(w)
	w._ready()
	var p := {"peer": 1, "name": "T", "cls": "sword", "lvl": 1, "xp": 0, "gold": 0,
		"hp": 100, "mp": 40, "maxhp": 160, "maxmp": 40, "atk": 16, "def": 8,
		"inv": {}, "quests": {}, "chains": {}, "prof": PL.new_state(), "eq_weapon": "", "eq_armor": "",
		"refine_weapon": 0, "refine_armor": 0, "skills": ["slash"], "cds": {}, "path": [],
		"moving": false, "dead_until": 0.0, "map": gd.DEFAULT_MAP,
		"pos": PL.TRAINER_POS, "target": PL.TRAINER_POS, "processed_tokens": []}
	w.players[1] = p

	# обучение только у наставника
	p["pos"] = Vector2(0, 0)
	w.on_learn(1, "herbalism")
	_check(not PL.knows(p["prof"], "herbalism"), "вдали от наставника не учится")
	p["pos"] = PL.TRAINER_POS
	w.on_learn(1, "herbalism")
	w.on_learn(1, "alchemy")
	_check(PL.knows(p["prof"], "herbalism") and PL.knows(p["prof"], "alchemy"), "у наставника учатся две профессии")
	w.on_learn(1, "mining")
	_check(not PL.knows(p["prof"], "mining"), "лимит MAX_LEARNED соблюдается")

	# сбор трав: узел доступен, предмет попадает в инвентарь, опыт растёт
	var node: Dictionary = PL.node_by_id("herb_1")
	p["pos"] = node["pos"]
	w.on_gather(1, "herb_1")
	_check(int(p["inv"].get("herb", 0)) == 1, "трава попала в инвентарь (получили %d)" % int(p["inv"].get("herb", 0)))
	_check(int(p["prof"]["xp"].get("herbalism", 0)) == PL.GATHER_XP, "опыт за сбор начислен")
	w.on_gather(1, "herb_1")
	_check(int(p["inv"].get("herb", 0)) == 1, "повторный сбор того же узла во время восстановления запрещён")
	# сбор не с узла — отказ
	var before := int(p["inv"].get("herb", 0))
	p["pos"] = Vector2(0, 0)
	w.on_gather(1, "herb_2")
	_check(int(p["inv"].get("herb", 0)) == before, "вдали от узла сбора нет")

	# набрать траву с обоих узлов (сброс восстановления для теста)
	for i in 3:
		w._node_depleted.clear()
		p["pos"] = PL.node_by_id("herb_2")["pos"]
		w.on_gather(1, "herb_2")
		w._node_depleted.clear()
		p["pos"] = PL.node_by_id("herb_1")["pos"]
		w.on_gather(1, "herb_1")
	var herbs := int(p["inv"].get("herb", 0))
	_check(herbs >= 5, "набрано трав достаточно для крафта (%d)" % herbs)

	# крафт зелья: нужен уровень алхимии 1 и 2 травы
	p["prof"]["xp"]["alchemy"] = 0
	w.on_craft(1, "potion_alch")
	_check(int(p["inv"].get("potion", 0)) >= 1 + 0, "зелье создано из 2 трав")
	_check(int(p["inv"].get("herb", 0)) == herbs - 2, "травы списаны (2 шт.)")

	# крафт синего зелья требует алхимию 3 уровня (80 опыта)
	var prev_herb := int(p["inv"].get("herb", 0))
	w.on_craft(1, "mana_alch")
	_check(int(p["inv"].get("herb", 0)) == prev_herb, "без уровня алхимии 3 крафт не идёт")
	p["prof"]["xp"]["alchemy"] = 100
	w.on_craft(1, "mana_alch")
	_check(int(p["inv"].get("mana", 0)) >= 1, "с уровнем алхимии 3 синее зелье создаётся")

	# кузница не изучена — рецепт не работает
	p["inv"]["ore"] = 10
	p["inv"]["wood"] = 5
	w.on_craft(1, "blade_smith")
	_check(not p["inv"].has("blade"), "без кузнечного дела рецепт не работает")

	print("проверок сквозной цепочки профессий: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
