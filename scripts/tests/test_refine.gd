extends SceneTree
## Тесты улучшения (refine) и лекаря — механики, перенесённые из rAthena npc/.

var _fails := 0
var _checks := 0
var _frames := 0
var GD


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	# автолоады (GameData, Net) появляются только после первого кадра — ждём в _process
	pass


func _process(_d: float) -> bool:
	_frames += 1
	if _frames != 3:
		return false
	_run()
	return false


func _run() -> void:
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true
	GD = root.get_node_or_null("/root/GameData")
	_check(GD != null, "GameData доступен")

	# ---------- таблицы улучшения ----------
	_check(GD.REFINE_MAX == 20, "максимум улучшения 20")
	for key in ["WeaponLv1", "WeaponLv2", "WeaponLv3", "WeaponLv4", "Armor"]:
		_check(GD.REFINE_RATES.has(key), "таблица %s есть" % key)

	# безопасные уровни: оружие 1 = до +7 (100%), броня до +4
	_check(GD.refine_chance("war_axe", 0) == 100, "WeaponLv1: +1 безопасно")
	_check(GD.refine_chance("war_axe", 6) == 100, "WeaponLv1: +7 безопасно")
	_check(GD.refine_chance("war_axe", 7) == 60, "WeaponLv1: +8 = 60%% (получили %d)" % GD.refine_chance("war_axe", 7))
	_check(GD.refine_chance("troll_club", 6) == 60, "WeaponLv2: +7 = 60%% (получили %d)" % GD.refine_chance("troll_club", 6))
	_check(GD.refine_chance("troll_club", 5) == 100, "WeaponLv2: +6 безопасно (получили %d)" % GD.refine_chance("troll_club", 5))
	_check(GD.refine_chance("plate", 3) == 100, "броня: +4 безопасно (получили %d)" % GD.refine_chance("plate", 3))
	_check(GD.refine_chance("plate", 4) == 60, "броня: +5 = 60%% (получили %d)" % GD.refine_chance("plate", 4))
	_check(GD.refine_chance("war_axe", 20) == 0, "на максимуме шанса нет")

	# ключи по типу предмета
	_check(GD.refine_key("plate") == "Armor", "кираса -> Armor")
	_check(GD.refine_key("blade") == "WeaponLv1", "меч -> WeaponLv1")
	_check(GD.refine_key("troll_club") == "WeaponLv2", "дубина -> WeaponLv2")
	_check(GD.refine_key("potion") == "", "зелье нельзя улучшить")
	_check(GD.refine_key("нет_такого") == "", "неизвестный предмет -> пусто")

	# бонусы
	_check(GD.refine_bonus("blade", 0) == 0, "без улучшения бонуса нет")
	_check(GD.refine_bonus("blade", 3) == 3, "WeaponLv1 +3 = +3 атаки")
	_check(GD.refine_bonus("plate", 2) == 2, "броня +2 = +2 защиты")
	_check(GD.refine_bonus("potion", 5) == 0, "зелье не даёт бонуса")

	# ---------- бонус в статах ----------
	var p := {"eq_weapon": "blade", "eq_armor": "armor", "refine_weapon": 0, "refine_armor": 0}
	var base: Dictionary = GD.equip_bonus(p)
	_check(base["atk"] == 8, "без улучшения атака 8, получили %d" % base["atk"])
	p["refine_weapon"] = 5
	var up: Dictionary = GD.equip_bonus(p)
	_check(up["atk"] == 13, "с +5 атака 13, получили %d" % up["atk"])
	p["refine_armor"] = 4
	_check(GD.equip_bonus(p)["defense"] == 10, "броня +4: защита 10")

	# ---------- сервер: улучшение и лекарь ----------
	var SW = load("res://scripts/server_world.gd")
	var w = SW.new()
	root.add_child(w)
	w._ready()
	w.players[1] = {
		"peer": 1, "name": "T", "cls": "sword", "lvl": 1, "xp": 0, "gold": 100000,
		"hp": 100, "mp": 40, "maxhp": 160, "maxmp": 40, "atk": 16, "def": 8,
		"inv": {"ore": 10}, "quests": {}, "chains": {}, "prof": GD.new_state_prof() if GD.has_method("new_state_prof") else {},
		"eq_weapon": "war_axe", "eq_armor": "", "refine_weapon": 0, "refine_armor": 0,
		"pos": GD.REFINE_POS, "dead": false, "processed_tokens": [], "vip_until": 0,
		"skills": [], "eq_weapon_id": "",
	}
	var pl: Dictionary = w.players[1]

	# не у кузнеца — отказ
	pl["pos"] = Vector2(0, 0)
	w.on_refine(1, "eq_weapon")
	_check(int(pl["refine_weapon"]) == 0, "вдали от кузнеца улучшения нет")
	_check(String(pl["eq_weapon"]) == "war_axe", "оружие не потерялось")

	# у кузнеца: безопасное улучшение
	pl["pos"] = GD.REFINE_POS
	var gold_before := int(pl["gold"])
	var ore_before := int(pl["inv"]["ore"])
	w.on_refine(1, "eq_weapon")
	_check(int(pl["refine_weapon"]) == 1, "первое улучшение прошло: сейчас +%d" % int(pl["refine_weapon"]))
	_check(int(pl["gold"]) == gold_before - GD.REFINE_COST, "золото списано на %d" % GD.REFINE_COST)
	_check(int(pl["inv"]["ore"]) == ore_before - 1, "материал списан")

	# без материала — отказ
	pl["inv"] = {}
	var lvl_before := int(pl["refine_weapon"])
	w.on_refine(1, "eq_weapon")
	_check(int(pl["refine_weapon"]) == lvl_before, "без материала улучшение не идёт")

	# без золота — отказ
	pl["inv"] = {"ore": 5}
	pl["gold"] = 0
	w.on_refine(1, "eq_weapon")
	_check(int(pl["refine_weapon"]) == lvl_before, "без золота улучшение не идёт")

	# максимум
	pl["gold"] = 100000
	pl["refine_weapon"] = GD.REFINE_MAX
	w.on_refine(1, "eq_weapon")
	_check(int(pl["refine_weapon"]) == GD.REFINE_MAX, "выше максимума не поднимается")

	# ---------- лекарь ----------
	var q: Dictionary = w.players[1]
	q["refine_weapon"] = 0
	q["hp"] = 10
	q["mp"] = 5
	q["maxhp"] = 160
	q["maxmp"] = 40
	q["pos"] = Vector2(0, 0)
	w.on_heal(1)
	_check(int(q["hp"]) == 10, "вдали от лекаря лечения нет")
	q["pos"] = GD.HEALER_POS
	w.on_heal(1)
	_check(int(q["hp"]) == int(q["maxhp"]), "лекарь восстановил HP (%d)" % int(q["hp"]))
	_check(int(q["mp"]) == int(q["maxmp"]), "лекарь восстановил MP (%d)" % int(q["mp"]))

	print("проверок улучшения: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
