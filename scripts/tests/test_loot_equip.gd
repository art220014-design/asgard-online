extends SceneTree
## Headless-тесты этапа 1: таблицы лута и экипировка.
## Запуск: godot --headless --path . -s res://scripts/tests/test_loot_equip.gd
## Код выхода 0 = все проверки прошли, 1 = есть провалы.

const GD := preload("res://scripts/game_data.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	_test_tables_valid()
	_test_pick_boundaries()
	_test_pick_distribution()
	_test_equip_swap()
	_test_equip_rejects()
	_test_equip_bonus()
	_test_unequip()
	print("проверок: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_tables_valid() -> void:
	for mob in GD.LOOT.keys():
		_check(GD.MOBS.has(mob), "таблица для неизвестного моба %s" % mob)
		var total := 0
		for e in GD.LOOT[mob]:
			var item: String = e[0]
			var w: int = int(e[1])
			_check(w > 0, "%s: вес %d не положительный" % [mob, w])
			_check(item == "" or GD.ITEMS.has(item), "%s: нет предмета %s" % [mob, item])
			total += w
		_check(total == 100, "%s: сумма весов %d, ожидалось 100" % [mob, total])
	for id in GD.ITEMS.keys():
		var it: Dictionary = GD.ITEMS[id]
		if it["kind"] == "weapon" or it["kind"] == "armor":
			_check(int(it["price"]) >= 0, "%s: отрицательная цена" % id)


func _test_pick_boundaries() -> void:
	# slime: potion 0..22 (вес 22), пусто 22..100
	_check(GD.pick_loot("slime", 0.0) == "potion", "slime roll 0 -> potion")
	_check(GD.pick_loot("slime", 0.2199) == "potion", "slime roll чуть ниже 22% -> potion")
	_check(GD.pick_loot("slime", 0.22) == "jellopy", "slime roll 22% -> jellopy")
	_check(GD.pick_loot("poporing", 0.19) == "potion", "poporing roll 19% -> potion")
	_check(GD.pick_loot("poporing", 0.45) == "clover", "poporing roll 45% -> clover")
	_check(GD.pick_loot("poporing", 0.51) == "poring_doll", "poporing roll 51% -> poring_doll")
	_check(GD.pick_loot("poporing", 0.56) == "", "poporing roll 56% -> ничего")
	_check(GD.pick_loot("golem", 0.30) == "steel", "golem roll 30% -> steel")
	_check(GD.pick_loot("golem", 0.36) == "", "golem roll 36% -> ничего")
	_check(GD.pick_loot("boss", 0.71) == "emperium", "boss roll 71% -> emperium")
	_check(GD.pick_loot("boss", 0.74) == "", "boss roll 74% -> ничего")
	_check(GD.pick_loot("slime", 0.3599) == "jellopy", "slime roll чуть ниже 36% -> jellopy")
	_check(GD.pick_loot("slime", 0.36) == "stuffed_doll", "slime roll 36% -> stuffed_doll")
	_check(GD.pick_loot("slime", 0.41) == "", "slime roll 41% -> ничего")
	_check(GD.pick_loot("slime", 0.9999) == "", "slime roll почти 1 -> ничего")
	for mob in GD.LOOT.keys():
		for e in GD.LOOT[mob]:
			if String(e[0]) != "":
				_check(GD.ITEMS.has(String(e[0])), "%s: предмет добычи существует (%s)" % [mob, e[0]])
	_check(GD.pick_loot("slime", 1.0) == "", "roll 1.0 не выходит за таблицу")
	_check(GD.pick_loot("slime", -0.5) == "potion", "отрицательный roll зажимается в 0")
	_check(GD.pick_loot("unknown_mob", 0.1) == "", "неизвестный моб -> ничего")
	# boss: potion 0..30, war_axe 30..45, plate 45..60, troll_club 60..70
	_check(GD.pick_loot("boss", 0.31) == "war_axe", "boss 31% -> war_axe")
	_check(GD.pick_loot("boss", 0.50) == "plate", "boss 50% -> plate")
	_check(GD.pick_loot("boss", 0.65) == "troll_club", "boss 65% -> troll_club")
	_check(GD.pick_loot("boss", 0.80) == "", "boss 80% -> ничего")


func _test_pick_distribution() -> void:
	# Честная проверка: 200000 бросков с фиксированным шагом равномерной сетки.
	var n := 200000
	var counts := {}
	for i in n:
		var r := (float(i) + 0.5) / float(n)
		var got: String = GD.pick_loot("boss", r)
		counts[got] = int(counts.get(got, 0)) + 1
	var expect := {"potion": 0.30, "war_axe": 0.15, "plate": 0.15, "troll_club": 0.10, "emperium": 0.03, "": 0.27}
	for k in expect.keys():
		var frac := float(counts.get(k, 0)) / float(n)
		_check(absf(frac - float(expect[k])) < 0.002,
			"boss %s: доля %.4f, ожидалось %.2f" % [k, frac, expect[k]])


func _mk_player(inv: Dictionary) -> Dictionary:
	return {"inv": inv.duplicate(), "eq_weapon": "", "eq_armor": ""}


func _test_equip_swap() -> void:
	var p := _mk_player({"war_axe": 1, "troll_club": 1, "plate": 1})
	_check(GD.equip(p, "war_axe"), "надеть топор из инвентаря")
	_check(p["eq_weapon"] == "war_axe", "топор стоит в слоте оружия")
	_check(not p["inv"].has("war_axe"), "топор ушёл из инвентаря")
	_check(GD.equip(p, "troll_club"), "надеть дубину поверх топора")
	_check(p["eq_weapon"] == "troll_club", "дубина в слоте оружия")
	_check(int(p["inv"].get("war_axe", 0)) == 1, "старый топор вернулся в инвентарь")
	_check(GD.equip(p, "plate"), "надеть латы")
	_check(p["eq_armor"] == "plate", "латы в слоте брони")
	_check(not p["inv"].has("plate"), "латы ушли из инвентаря")


func _test_equip_rejects() -> void:
	var p := _mk_player({"potion": 2})
	_check(not GD.equip(p, "potion"), "зелье нельзя надеть")
	_check(int(p["inv"]["potion"]) == 2, "зелья не потеряны при попытке надеть")
	_check(not GD.equip(p, "war_axe"), "нельзя надеть предмет которого нет")
	_check(p["eq_weapon"] == "", "слот не изменился при отказе")
	_check(not GD.equip(p, "no_such_item"), "нельзя надеть несуществующий id")


func _test_equip_bonus() -> void:
	var p := _mk_player({})
	_check(GD.equip_bonus(p) == {"atk": 0, "defense": 0}, "без экипировки бонус 0")
	p["eq_weapon"] = "troll_club"
	p["eq_armor"] = "plate"
	var b := GD.equip_bonus(p)
	_check(b["atk"] == 22, "бонус атаки дубины = 22, получили %d" % b["atk"])
	_check(b["defense"] == 11, "бонус защиты латов = 11, получили %d" % b["defense"])
	# Броня старого типа тоже должна давать бонус (проверка ключа "def")
	var q := _mk_player({})
	q["eq_armor"] = "armor"
	_check(GD.equip_bonus(q)["defense"] == 6, "кожаный доспех даёт +6 защиты")


func _test_unequip() -> void:
	var p := _mk_player({})
	_check(not GD.unequip(p, "eq_weapon"), "снять из пустого слота нельзя")
	_check(not GD.unequip(p, "potion"), "неизвестный слот отклоняется")
	_check(not GD.unequip(p, "inv"), "нельзя снять через произвольное поле")
	p["inv"]["troll_club"] = 1
	GD.equip(p, "troll_club")
	_check(GD.unequip(p, "eq_weapon"), "снять надетую дубину")
	_check(p["eq_weapon"] == "", "слот оружия пуст после снятия")
	_check(int(p["inv"].get("troll_club", 0)) == 1, "дубина вернулась в инвентарь")
	_check(GD.equip_bonus(p)["atk"] == 0, "бонус атаки обнулился после снятия")
	_check(not GD.unequip(p, "eq_weapon"), "повторное снятие отклоняется")
	# Снятие не должно создавать лишних предметов
	_check(int(p["inv"]["troll_club"]) == 1, "количество не дублируется при повторе")
