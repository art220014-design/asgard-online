extends SceneTree
## Баланс профессий: узлы на проходимых клетках, у каждого материала рецепта есть источник, id уникальны.

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
	gd.activate_map(gd.DEFAULT_MAP)
	var ids := {}
	var sources := {}
	var nodes_per_prof := {}
	var ore_per_cycle := 0
	for n in PL.NODES:
		var nid := String(n["id"])
		_check(not ids.has(nid), "id узла уникален: %s" % nid)
		ids[nid] = true
		var t: Vector2i = n["pos"] / gd.TILE
		_check(not gd.BLOCKING.get(gd.tile_at(t.x, t.y), false), "узел %s на проходимой клетке" % nid)
		_check(gd.ITEMS.has(String(n["item"])), "узел %s даёт известный предмет" % nid)
		_check(PL.PROFS.has(String(n["prof"])), "узел %s относится к известной профессии" % nid)
		sources[String(n["item"])] = true
		nodes_per_prof[n["prof"]] = int(nodes_per_prof.get(n["prof"], 0)) + 1
		if String(n["item"]) == "ore":
			ore_per_cycle += int(n["amount"])
	for pr in ["mining", "herbalism", "woodcutting"]:
		_check(int(nodes_per_prof.get(pr, 0)) >= 4, "у %s не меньше 4 узлов (%d)" % [pr, int(nodes_per_prof.get(pr, 0))])
	for r in PL.RECIPES:
		for pair in r["inputs"]:
			var mat := String(pair[0])
			if mat == "ore" or mat == "herb" or mat == "wood":
				_check(sources.has(mat), "материал %s рецепта %s добывается" % [mat, r["id"]])
	_check(ore_per_cycle >= 20, "железа за цикл всех жил >= 20 (%d), Battle Axe (110) добывается за ~5 циклов" % ore_per_cycle)
	print("проверок баланса профессий: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
