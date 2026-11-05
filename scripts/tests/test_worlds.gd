extends SceneTree
## Проверка мира: 1265 карт rAthena, порталы, точки прибытия, переход игрока, спавн мобов.

var _fails := 0
var _checks := 0
var _frames := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _walkable(gd, mp: String, pos: Vector2) -> bool:
	gd.activate_map(mp)
	var t: int = gd.tile_at_world(pos)
	return not gd.BLOCKING.get(t, false)


func _process(_d: float) -> bool:
	_frames += 1
	if _frames != 3:
		return false
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true
	var gd = root.get_node_or_null("/root/GameData")
	_check(gd != null, "GameData доступен")

	# ---- реестр ----
	var names: Array = gd.map_names()
	_check(names.size() == 1265, "карт 1265 (получили %d)" % names.size())
	_check(gd.map_exists("prontera"), "prontera есть")
	_check(gd.map_category("prontera") == "city", "prontera — город")
	_check(gd.map_category("prt_fild01") == "field", "prt_fild01 — поле")
	_check(gd.map_category("gl_dun01") == "dungeon" or gd.map_category("gl_dun01") != "", "подземелье классифицировано")
	var cats := {}
	for n in names:
		cats[gd.map_category(n)] = true
	_check(cats.has("city") and cats.has("field") and cats.has("dungeon") and cats.has("indoor") and cats.has("pvp"),
		"все категории карт представлены")

	# ---- тайлы: размер и детерминированность ----
	var t1: PackedByteArray = gd.map_tiles("prontera")
	var t2: PackedByteArray = gd.map_tiles("prontera")
	_check(t1.size() == gd.MAP_W * gd.MAP_H, "карта 64x64")
	_check(t1 == t2, "тайлы детерминированы")
	_check(gd.map_tiles("prontera") != gd.map_tiles("geffen"), "разные карты — разные тайлы")

	# ---- порталы и варпы ----
	var maps_with_portals := 0
	var total_portals := 0
	var bad_dst := 0
	var bad_arrival := 0
	var checked_arrivals := 0
	var returns := 0
	var pairs := 0
	var sample := 0
	for n in names:
		var pts: Array = gd.portals_for(n)
		if pts.size() > 0:
			maps_with_portals += 1
		total_portals += pts.size()
		for pt in pts:
			var dst := String(pt["dst"])
			if not gd.map_exists(dst):
				bad_dst += 1
				continue
			pairs += 1
			# обратный портал: в dst есть портал обратно в n
			var back := false
			for q in gd.portals_for(dst):
				if String(q["dst"]) == n:
					back = true
					break
			if back:
				returns += 1
			# точка прибытия проходима (проверяем выборку, чтобы тест был быстрым)
			if sample < 400:
				sample += 1
				checked_arrivals += 1
				var arr: Vector2 = gd.arrival_pos(dst, n)
				if not _walkable(gd, dst, arr):
					bad_arrival += 1
	_check(maps_with_portals > 600, "карт с порталами больше 600 (получили %d)" % maps_with_portals)
	_check(total_portals > 2000, "порталов больше 2000 (получили %d)" % total_portals)
	_check(bad_dst == 0, "все цели порталов существуют (ошибок %d)" % bad_dst)
	_check(bad_arrival == 0, "точки прибытия проходимы (%d из %d плохих)" % [bad_arrival, checked_arrivals])
	_check(float(returns) / float(max(pairs, 1)) > 0.5, "обратные порталы есть у большинства (%d из %d)" % [returns, pairs])
	print("порталов: %d, карт с порталами: %d, пар с обратным: %d/%d" % [total_portals, maps_with_portals, returns, pairs])

	# ---- спавны ----
	var sp_maps := 0
	for n in names:
		if gd.spawns_for(n).size() > 0:
			sp_maps += 1
	_check(sp_maps > 300, "карт со спавнами больше 300 (получили %d)" % sp_maps)
	_check(gd.mob_type_for_level(1) == "slime", "уровень 1 -> слизень")
	_check(gd.mob_type_for_level(45) == "orc", "уровень 45 -> орк")
	_check(gd.mob_type_for_level(91) == "orc", "уровень 91 -> ближайший (орк)")

	# ---- сервер: переход через портал и спавн ----
	var SW = load("res://scripts/server_world.gd")
	var w = SW.new()
	root.add_child(w)
	w._ready()
	var src := "prontera"
	var pts0: Array = gd.portals_for(src)
	_check(pts0.size() > 0, "у prontera есть порталы")
	if pts0.size() > 0:
		var pt: Dictionary = pts0[0]
		var dst := String(pt["dst"])
		var p := {"peer": 1, "name": "T", "cls": "sword", "lvl": 1, "xp": 0, "gold": 0,
			"hp": 100, "mp": 40, "maxhp": 160, "maxmp": 40, "atk": 16, "def": 8,
			"inv": {}, "quests": {}, "chains": {}, "prof": {}, "eq_weapon": "", "eq_armor": "",
			"refine_weapon": 0, "refine_armor": 0, "skills": ["slash"], "cds": {}, "path": [],
			"moving": false, "dead_until": 0.0, "map": src,
			"pos": gd.tile_center(pt["tile"]), "target": gd.tile_center(pt["tile"])}
		w.players[1] = p
		w._check_portal(p)
		_check(String(p["map"]) == dst, "портал переносит на карту %s (получили %s)" % [dst, p["map"]])
		_check(_walkable(gd, dst, p["pos"]), "после перехода игрок стоит на проходимой клетке")
		_check(gd.portal_at(dst, p["pos"]).is_empty(), "после перехода игрок не на портале (нет цикла)")
		_check(w._mapped.has(dst), "карта назначения заспавнена")
		var mobs_there := 0
		for m in w.mobs:
			if String(m.get("map", "")) == dst:
				mobs_there += 1
		_check(mobs_there > 0 or gd.spawns_for(dst).is_empty(), "на карте назначения есть мобы (%d)" % mobs_there)
		# игрок не должен переходить сам, если стоит не на портале
		p["pos"] = gd.SPAWN_POINT
		var before := String(p["map"])
		w._check_portal(p)
		_check(String(p["map"]) == before, "вне портала переход не происходит")

	print("проверок мира: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
