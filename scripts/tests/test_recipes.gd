extends SceneTree
## Проверка рецептов, импортированных из rAthena produce_db: только наши материалы, выход — оружие из ITEMS.

const PL := preload("res://scripts/profession_logic.gd")

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
	var gd = root.get_node_or_null("/root/GameData")
	_check(gd != null, "GameData доступен")
	var mats := {"ore": true, "herb": true, "wood": true}
	var ids := {}
	var imported := []
	for r in PL.RECIPES:
		var rid := String(r["id"])
		_check(not ids.has(rid), "id рецепта уникален: %s" % rid)
		ids[rid] = true
		if not rid.begins_with("rA_"):
			continue
		imported.append(r)
		for pair in r["inputs"]:
			_check(mats.has(String(pair[0])), "%s: материал есть у нас (%s)" % [rid, pair[0]])
			_check(int(pair[1]) >= 1, "%s: количество >= 1" % rid)
		var out := String(r["output"][0])
		_check(gd.ITEMS.has(out), "%s: выход есть в ITEMS (%s)" % [rid, out])
		if gd.ITEMS.has(out):
			var it: Dictionary = gd.ITEMS[out]
			_check(String(it["kind"]) == "weapon", "%s: выход — оружие" % rid)
			_check(int(it["atk"]) > 0, "%s: атака > 0" % rid)
			_check(int(it["weapon_level"]) >= 1 and int(it["weapon_level"]) <= 4, "%s: уровень оружия 1..4" % rid)
			_check(int(it["price"]) == 0, "%s: не продаётся в магазине" % rid)
	_check(imported.size() == 9, "импортировано 9 рецептов (получили %d)" % imported.size())
	_check(not ids.has("rA_sword") and not ids.has("rA_falchion"), "дубликаты blade/war_axe не импортированы")

	# крафт: достаточно ресурсов — успех и списание; не хватает — отказ
	for r in imported:
		var st := {"learned": ["smithing"], "xp": {"smithing": 100000}}
		var need := {}
		for pair in r["inputs"]:
			need[String(pair[0])] = int(pair[1])
		var inv := need.duplicate()
		var err := PL.craft(r, st, inv)
		_check(err == "", "%s: крафт проходит при достатке (%s)" % [r["id"], err])
		_check(int(inv.get(String(r["output"][0]), 0)) == 1, "%s: предмет выдан" % r["id"])
		var short := need.duplicate()
		var first := String(r["inputs"][0][0])
		short[first] = int(short[first]) - 1
		var inv2 := short
		_check(PL.craft(r, st, inv2) != "", "%s: при нехватке крафт отклоняется" % r["id"])

	print("проверок рецептов: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
