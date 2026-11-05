extends SceneTree
## Серверный интеграционный тест профессий на локальном мире (офлайн).
## Запуск: godot --headless --path . -s res://scripts/tests/test_prof_server.gd

const GD := preload("res://scripts/game_data.gd")
const PL := preload("res://scripts/profession_logic.gd")

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
	_world.start_local("profTest%d" % (Time.get_ticks_usec() % 100000), "sword")
	var p: Dictionary = _world.players[1]
	p["inv"] = {}
	p["gold"] = 0
	p["moving"] = false

	# Обучение: вдали от мастера не работает
	p["pos"] = GD.SPAWN_POINT
	_world.on_learn(1, "mining")
	_check(not PL.knows(p["prof"], "mining"), "обучение вдали от мастера отклонено")

	# Рядом с мастером обучение работает
	p["pos"] = PL.TRAINER_POS
	_world.on_learn(1, "mining")
	_check(PL.knows(p["prof"], "mining"), "обучение рядом с мастером проходит")
	_world.on_learn(1, "alchemy")
	_check(PL.knows(p["prof"], "alchemy"), "вторая профессия (алхимия) изучена")
	_world.on_learn(1, "herbalism")
	_check(not PL.knows(p["prof"], "herbalism"), "третья профессия отклонена сервером (лимит 2)")

	# Добыча: вдали от узла не работает
	var node := PL.node_by_id("ore_1")
	p["pos"] = GD.SPAWN_POINT
	_world.on_gather(1, "ore_1")
	_check(int(p["inv"].get("ore", 0)) == 0, "добыча вдали от узла отклонена")

	# Добыча рядом: руда выдана, узел истощён
	p["pos"] = node["pos"]
	_world.on_gather(1, "ore_1")
	_check(int(p["inv"].get("ore", 0)) == 4, "добыча рядом с узлом выдаёт руду")
	_world.on_gather(1, "ore_1")
	_check(int(p["inv"].get("ore", 0)) == 4, "истощённый узел не выдаёт повторно")

	# Богатая жила требует уровень 4 на сервере
	p["pos"] = PL.node_by_id("ore_2")["pos"]
	_world.on_gather(1, "ore_2")
	_check(int(p["inv"].get("ore", 0)) == 4, "богатая жила не открыта на низком уровне")

	# Крафт: нужны материалы и профессия
	p["inv"] = {"herb": 2}
	_world.on_craft(1, "potion_alch")
	_check(int(p["inv"].get("potion", 0)) == 1, "крафт зелья выдаёт результат")
	_check(not p["inv"].has("herb"), "трава списана при крафте")

	# Отказ крафта без материалов не списывает ничего
	p["inv"] = {"herb": 1}
	_world.on_craft(1, "potion_alch")
	_check(int(p["inv"].get("herb", 0)) == 1, "при нехватке материалов ничего не списано")

	# Неизвестный рецепт и профессия не падают и ничего не меняют
	var before: Dictionary = p["inv"].duplicate()
	_world.on_craft(1, "no_such_recipe")
	_world.on_learn(1, "no_such_prof")
	_check(p["inv"] == before, "неизвестный рецепт ничего не меняет")

	# Сохранение и загрузка: профессии переживают перезапуск
	_world._save(p)
	var path := "%s/%s.json" % [_world.SAVE_DIR, p["name"].to_lower()]
	var loaded = JSON.parse_string(FileAccess.get_file_as_string(path))
	_check(typeof(loaded) == TYPE_DICTIONARY and loaded.has("prof"), "профессии сохранены в файл")
	if typeof(loaded) == TYPE_DICTIONARY and loaded.has("prof"):
		var learned: Array = loaded["prof"]["learned"]
		_check(learned.has("mining") and learned.has("alchemy"), "изученные профессии в файле")
	DirAccess.remove_absolute(path)

	print("проверок профессий (сервер): %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
