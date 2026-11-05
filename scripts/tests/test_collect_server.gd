extends SceneTree
## Сдача предметов NPC на сервере: без предметов — отказ с подсказкой, с предметами — шаг и списание.

var _fails := 0
var _checks := 0
var _frames := 0
var _msgs: Array = []


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
	var p := {"peer": 1, "name": "Collector", "cls": "sword", "lvl": 2, "xp": 0, "gold": 0,
		"hp": 100, "mp": 40, "maxhp": 160, "maxmp": 40, "atk": 16, "def": 8,
		"inv": {}, "quests": {}, "chains": {}, "prof": PL.new_state(), "eq_weapon": "", "eq_armor": "",
		"refine_weapon": 0, "refine_armor": 0, "skills": ["slash"], "cds": {}, "path": [],
		"moving": false, "dead_until": 0.0, "map": gd.DEFAULT_MAP,
		"pos": gd.NPC_QUEST_POS, "target": gd.NPC_QUEST_POS, "processed_tokens": [], "vip_until": 0.0}
	w.players[1] = p

	# ch_herbs: talk → collect 4 herb (talk у Старейшины) → kill slime 3 → talk
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"].get("ch_herbs", {}).get("step", 0)) == 1, "первый разговор открывает ch_herbs (шаг 1)")

	# без трав — отказ, шаг не меняется
	var before := int(p["chains"]["ch_herbs"]["step"])
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_herbs"]["step"]) == before, "без трав сдача не проходит")

	# с 2 травами — всё ещё мало
	p["inv"]["herb"] = 2
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_herbs"]["step"]) == before, "2 травы из 4 — сдача не проходит")
	_check(int(p["inv"].get("herb", 0)) == 2, "при отказе травы не списываются")

	# 4 травы — сдача проходит, травы списаны
	p["inv"]["herb"] = 5
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_herbs"]["step"]) == before + 1, "с 5 травами сдача проходит")
	_check(int(p["inv"].get("herb", 0)) == 1, "списано ровно 4 травы, осталась 1")

	# полное прохождение: убить 3 слайма, сдать, claim
	var st: Dictionary = p["chains"]["ch_herbs"]
	st["step"] = 2
	st["count"] = 0
	var ch: Dictionary = {}
	for c in gd.CHAINS:
		if c["id"] == "ch_herbs":
			ch = c
	var QL = load("res://scripts/quest_logic.gd")
	for i in 3:
		QL.on_kill(ch, st, "slime")
	_check(int(st["step"]) == 3, "после 3 слаймов шаг 3")
	w.on_talk_npc(1, "quest")
	_check(QL.is_complete(ch, st), "цепочка завершена после финального разговора")

	# ch_pelts: talk → collect jellopy 5 → talk → collect feather 3 → talk
	p["inv"] = {}
	p["lvl"] = 3
	p["chains"].erase("ch_pelts")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_pelts"]["step"]) == 1, "ch_pelts открывается с 3 уровня")
	p["inv"]["jellopy"] = 4
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_pelts"]["step"]) == 1, "4 желейки из 5 — сдача не проходит")
	_check(int(p["inv"].get("jellopy", 0)) == 4, "при отказе желейки не списываются")
	p["inv"]["jellopy"] = 6
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_pelts"]["step"]) == 2, "5 желеек сданы, шаг 2 (talk)")
	_check(int(p["inv"].get("jellopy", 0)) == 1, "списано ровно 5 желеек")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_pelts"]["step"]) == 3, "разговор переводит к сбору перьев")
	p["inv"]["feather"] = 3
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_pelts"]["step"]) == 4, "3 пера сданы")
	_check(not p["inv"].has("feather"), "перья списаны полностью")
	w.on_talk_npc(1, "quest")
	var pelts: Dictionary = {}
	for c in gd.CHAINS:
		if c["id"] == "ch_pelts":
			pelts = c
	_check(QL.is_complete(pelts, p["chains"]["ch_pelts"]), "ch_pelts завершена")

	# ch_smile: talk → jellopy 10 → talk → fluff 10 → talk → clover 10 → talk
	p["inv"] = {}
	p["lvl"] = 5
	p["chains"].erase("ch_smile")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 1, "ch_smile открывается с 5 уровня")
	p["inv"]["jellopy"] = 10
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 2, "10 желеек сданы")
	_check(not p["inv"].has("jellopy"), "желейки списаны полностью")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 3, "разговор переводит к пуху")
	p["inv"]["fluff"] = 9
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 3, "9 пуха из 10 — сдача не проходит")
	_check(int(p["inv"].get("fluff", 0)) == 9, "при отказе пух не списывается")
	p["inv"]["fluff"] = 10
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 4, "10 пуха сданы")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 5, "разговор переводит к клеверу")
	p["inv"]["clover"] = 10
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_smile"]["step"]) == 6, "10 клеверов сданы")
	_check(not p["inv"].has("clover"), "клеверы списаны полностью")
	w.on_talk_npc(1, "quest")
	var smile: Dictionary = {}
	for c in gd.CHAINS:
		if c["id"] == "ch_smile":
			smile = c
	_check(QL.is_complete(smile, p["chains"]["ch_smile"]), "ch_smile завершена")

	# ch_elin: talk → collect_any (любая кукла) → talk
	p["inv"] = {}
	p["lvl"] = 2
	p["chains"].erase("ch_elin")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_elin"]["step"]) == 1, "ch_elin открывается со 2 уровня")
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_elin"]["step"]) == 1, "без кукол сдача не проходит")
	p["inv"]["spore_doll"] = 1
	p["inv"]["poring_doll"] = 1
	w.on_talk_npc(1, "quest")
	_check(int(p["chains"]["ch_elin"]["step"]) == 2, "любая кукла из списка сдаёт шаг")
	_check(not p["inv"].has("poring_doll"), "первая подходящая кукла списана")
	_check(int(p["inv"].get("spore_doll", 0)) == 1, "остальные куклы не трогаются")
	w.on_talk_npc(1, "quest")
	var elin: Dictionary = {}
	for c in gd.CHAINS:
		if c["id"] == "ch_elin":
			elin = c
	_check(QL.is_complete(elin, p["chains"]["ch_elin"]), "ch_elin завершена")

	print("проверок сдачи предметов: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
