extends SceneTree
## Тесты логики профессий (этап 3). Без сети.
## Запуск: godot --headless --path . -s res://scripts/tests/test_professions.gd

const PL := preload("res://scripts/profession_logic.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	_test_data()
	_test_levels()
	_test_learn_limit()
	_test_gather()
	_test_craft()
	print("проверок: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_data() -> void:
	var GD := preload("res://scripts/game_data.gd")
	for n in PL.NODES:
		_check(PL.PROFS.has(n["prof"]), "узел %s: нет профессии" % n["id"])
		_check(GD.ITEMS.has(n["item"]), "узел %s: нет предмета %s" % [n["id"], n["item"]])
		_check(int(n["min_level"]) >= 1 and int(n["min_level"]) <= PL.MAX_LEVEL, "узел %s: уровень в диапазоне" % n["id"])
	for r in PL.RECIPES:
		_check(PL.PROFS.has(r["prof"]), "рецепт %s: нет профессии" % r["id"])
		_check(PL.PROFS[r["prof"]]["kind"] == "craft", "рецепт %s: профессия крафтовая" % r["id"])
		for pair in r["inputs"]:
			_check(GD.ITEMS.has(pair[0]), "рецепт %s: нет ингредиента %s" % [r["id"], pair[0]])
		_check(GD.ITEMS.has(r["output"][0]), "рецепт %s: нет результата" % r["id"])
	var ids := {}
	for n in PL.NODES:
		_check(not ids.has(n["id"]), "id узла уникален: %s" % n["id"])
		ids[n["id"]] = true


func _test_levels() -> void:
	_check(PL.level_for_xp(0) == 1, "0 опыта -> уровень 1")
	_check(PL.level_for_xp(19) == 1, "19 опыта -> уровень 1")
	_check(PL.level_for_xp(20) == 2, "20 опыта -> уровень 2")
	_check(PL.level_for_xp(80) == 3, "80 опыта -> уровень 3")
	_check(PL.level_for_xp(10000000) == PL.MAX_LEVEL, "уровень не выше максимума")
	var last := 1
	for x in range(0, 2000, 7):
		var l := PL.level_for_xp(x)
		_check(l >= last, "уровень не убывает при росте опыта (%d)" % x)
		last = l


func _test_learn_limit() -> void:
	var st := PL.new_state()
	_check(PL.learn(st, "mining") == "", "первая профессия изучается")
	_check(PL.learn(st, "mining") != "", "повторное изучение отклоняется")
	_check(PL.learn(st, "alchemy") == "", "вторая профессия изучается")
	_check(PL.learn(st, "smithing") != "", "третья профессия отклоняется (лимит 2)")
	_check((st["learned"] as Array).size() == 2, "в списке ровно две профессии")
	_check(PL.learn(st, "no_such") != "", "неизвестная профессия отклоняется")


func _test_gather() -> void:
	var node: Dictionary = PL.node_by_id("ore_1")
	var st := PL.new_state()
	var inv := {}
	var far: Vector2 = node["pos"] + Vector2(500, 0)
	_check(PL.gather_check(node, st, node["pos"], false) != "", "без профессии добыча запрещена")
	PL.learn(st, "mining")
	_check(PL.gather_check(node, st, far, false) != "", "вдали от узла добыча запрещена")
	_check(PL.gather_check(node, st, node["pos"], true) != "", "истощённый узел недоступен")
	_check(PL.gather_check(node, st, node["pos"], false) == "", "рядом с узлом добыча разрешена")
	var got := PL.gather(node, st, inv)
	_check(got == 4, "добыча выдаёт 4 руды")
	_check(int(inv.get("ore", 0)) == 4, "руда попала в инвентарь")
	_check(int(st["xp"]["mining"]) == PL.GATHER_XP, "добыча начисляет опыт")

	var rich: Dictionary = PL.node_by_id("ore_2")
	_check(PL.gather_check(rich, st, rich["pos"], false) != "", "богатая жила требует уровень 4")
	st["xp"]["mining"] = PL.level_for_xp(0)
	st["xp"]["mining"] = 60 # уровень 1 + sqrt(3) -> 2, нужен 4
	_check(PL.gather_check(rich, st, rich["pos"], false) != "", "уровень 2 не открывает богатую жилу")
	st["xp"]["mining"] = 720 # 1 + sqrt(36) = 7
	_check(PL.gather_check(rich, st, rich["pos"], false) == "", "уровень 7 открывает богатую жилу")
	_check(PL.gather(rich, st, inv) == 8, "богатая жила даёт 8 руды")


func _test_craft() -> void:
	var rec: Dictionary = PL.recipe_by_id("blade_smith")
	var st := PL.new_state()
	var inv := {"ore": 2, "wood": 1}
	_check(PL.craft_check(rec, st, inv) != "", "без профессии крафт запрещён")
	PL.learn(st, "smithing")
	_check(PL.craft(rec, st, inv) == "", "крафт клинка проходит с материалами")
	_check(int(inv.get("blade", 0)) == 1, "клинок в инвентаре")
	_check(not inv.has("ore") and not inv.has("wood"), "материалы списаны полностью")
	_check(int(st["xp"]["smithing"]) == PL.CRAFT_XP, "крафт начисляет опыт")

	var inv2 := {"ore": 1}
	_check(PL.craft(rec, st, inv2) != "", "не хватает материалов -> отказ")
	_check(int(inv2["ore"]) == 1, "при отказе материалы не списаны")

	var axe: Dictionary = PL.recipe_by_id("war_axe_smith")
	_check(PL.craft_check(axe, st, {"ore": 4, "wood": 2}) != "", "топор требует уровень 5")

	var alch := PL.new_state()
	PL.learn(alch, "alchemy")
	var inv3 := {"herb": 2}
	_check(PL.craft(PL.recipe_by_id("potion_alch"), alch, inv3) == "", "зелье из двух трав")
	_check(int(inv3.get("potion", 0)) == 1, "зелье в инвентаре")
	_check(PL.craft(PL.recipe_by_id("mana_alch"), alch, {"herb": 3}) != "", "эликсир маны требует уровень 3")
