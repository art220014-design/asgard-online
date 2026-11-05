extends SceneTree
## Проверка цепочек квестов: структура, цели, награды и полное прохождение новых цепочек.

const QL := preload("res://scripts/quest_logic.gd")

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
	var ids := {}
	for ch in gd.CHAINS:
		var cid := String(ch["id"])
		_check(not ids.has(cid), "id цепочки уникален: %s" % cid)
		ids[cid] = true
		_check(int(ch["min_level"]) >= 1, "%s: min_level >= 1" % cid)
		_check((ch["steps"] as Array).size() >= 2, "%s: минимум 2 шага" % cid)
		for st in ch["steps"]:
			var t := String(st["type"])
			if t == "kill":
				_check(gd.MOBS.has(String(st["target"])), "%s: цель-моб существует (%s)" % [cid, st["target"]])
				_check(int(st["count"]) >= 1, "%s: count >= 1" % cid)
			elif t == "talk":
				_check(String(st["npc"]) == "quest", "%s: talk только к Старейшине" % cid)
			elif t == "collect_any":
				_check(String(st["npc"]) == "quest", "%s: collect_any сдаётся Старейшине" % cid)
				for it in st["items"]:
					_check(gd.ITEMS.has(String(it)), "%s: предмет collect_any существует (%s)" % [cid, it])
				_check(int(st["count"]) >= 1, "%s: collect_any count >= 1" % cid)
			elif t == "collect":
				_check(String(st["npc"]) == "quest", "%s: collect сдаётся Старейшине" % cid)
				_check(gd.ITEMS.has(String(st["item"])), "%s: собираемый предмет существует (%s)" % [cid, st["item"]])
				_check(int(st["count"]) >= 1, "%s: collect count >= 1" % cid)
			else:
				_check(false, "%s: неизвестный тип шага %s" % [cid, t])
		var rw: Dictionary = ch["reward"]
		for pair in rw.get("items", []):
			_check(gd.ITEMS.has(String(pair[0])), "%s: награда-предмет существует (%s)" % [cid, pair[0]])

	# ---- полное прохождение новой цепочки по логике квестов ----
	for cid in ["ch_sword_trial", "ch_archer_trial", "ch_herbs", "ch_pelts", "ch_smile", "ch_elin"]:
		var chain: Dictionary = {}
		for ch in gd.CHAINS:
			if ch["id"] == cid:
				chain = ch
		var st := QL.new_state()
		_check(not QL.on_talk(chain, st, "quest", 1), "%s: уровень 1 не берёт цепочку" % cid)
		_check(QL.on_talk(chain, st, "quest", int(chain["min_level"])), "%s: старт с min_level" % cid)
		for step in chain["steps"]:
			if step["type"] == "kill":
				for i in int(step["count"]):
					QL.on_kill(chain, st, String(step["target"]))
			elif step["type"] == "talk":
				QL.on_talk(chain, st, "quest", int(chain["min_level"]))
			elif step["type"] == "collect_any":
				var pick := {String(step["items"][0]): int(step["count"])}
				_check(QL.on_talk(chain, st, "quest", int(chain["min_level"]), pick), "%s: сдача collect_any проходит" % cid)
				_check(pick.is_empty(), "%s: выбранный предмет списан" % cid)
			elif step["type"] == "collect":
				var bag := {String(step["item"]): int(step["count"])}
				_check(QL.on_talk(chain, st, "quest", int(chain["min_level"]), bag), "%s: сдача collect проходит" % cid)
				_check(not bag.has(String(step["item"])), "%s: предметы списаны при сдаче" % cid)
		_check(QL.is_complete(chain, st), "%s: цепочка проходится до конца" % cid)
		_check(QL.claim(chain, st, int(chain["min_level"])), "%s: награда выдаётся" % cid)
		_check(not QL.claim(chain, st, int(chain["min_level"])), "%s: награда однократна" % cid)

	print("проверок квестов: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
