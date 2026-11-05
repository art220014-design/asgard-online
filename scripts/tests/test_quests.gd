extends SceneTree
## Тесты логики квестов-цепочек (этап 2). Без сети.
## Запуск: godot --headless --path . -s res://scripts/tests/test_quests.gd

const GD := preload("res://scripts/game_data.gd")
const QL := preload("res://scripts/quest_logic.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	_test_data_valid()
	_test_talk_gate()
	_test_kill_progress()
	_test_full_chain()
	_test_claim_rules()
	print("проверок: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)


func _test_data_valid() -> void:
	_check(GD.CHAINS.size() == 12, "двенадцать цепочек (3 старых + 9 новых)")
	var ids := {}
	for ch in GD.CHAINS:
		_check(not ids.has(ch["id"]), "id цепочки уникален: %s" % ch["id"])
		ids[ch["id"]] = true
		var steps: Array = ch["steps"]
		_check(steps.size() >= 2, "%s: минимум два шага" % ch["id"])
		_check(steps[0]["type"] == "talk", "%s: первый шаг — разговор" % ch["id"])
		_check(steps[steps.size() - 1]["type"] == "talk", "%s: последний шаг — разговор" % ch["id"])
		for st in steps:
			if st["type"] == "kill":
				_check(GD.MOBS.has(st["target"]), "%s: нет моба %s" % [ch["id"], st["target"]])
				_check(int(st["count"]) >= 1, "%s: count >= 1" % ch["id"])
			elif st["type"] == "talk":
				_check(st["npc"] == "quest", "%s: NPC должен быть quest" % ch["id"])
			elif st["type"] == "collect_any":
				_check(st["npc"] == "quest", "%s: collect_any сдаётся quest" % ch["id"])
				for it in st["items"]:
					_check(GD.ITEMS.has(it), "%s: предмет collect_any существует (%s)" % [ch["id"], it])
				_check(int(st["count"]) >= 1, "%s: collect_any count >= 1" % ch["id"])
			elif st["type"] == "collect":
				_check(st["npc"] == "quest", "%s: collect сдаётся quest" % ch["id"])
				_check(GD.ITEMS.has(st["item"]), "%s: собираемый предмет существует (%s)" % [ch["id"], st["item"]])
				_check(int(st["count"]) >= 1, "%s: collect count >= 1" % ch["id"])
			else:
				_check(false, "%s: неизвестный тип шага %s" % [ch["id"], st["type"]])
		var rw: Dictionary = ch["reward"]
		for pair in rw.get("items", []):
			_check(GD.ITEMS.has(pair[0]), "%s: нет предмета награды %s" % [ch["id"], pair[0]])
			_check(int(pair[1]) >= 1, "%s: количество награды >= 1" % ch["id"])
		_check(int(rw.get("gold", 0)) > 0, "%s: награда золотом" % ch["id"])


func _test_talk_gate() -> void:
	var ch: Dictionary = GD.CHAINS[0]  # ch_village, min_level 1
	var st := QL.new_state()
	_check(not QL.on_talk(ch, st, "shop", 5), "разговор с другим NPC не продвигает")
	_check(QL.on_talk(ch, st, "quest", 1), "разговор с квестодателем запускает цепочку")
	_check(int(st["step"]) == 1, "шаг стал 1 после разговора")
	_check(not QL.on_talk(ch, st, "quest", 1), "второй разговор на шаге убийства не проходит")

	var hi: Dictionary = GD.CHAINS[2]  # ch_chief, min_level 10
	var st2 := QL.new_state()
	_check(not QL.on_talk(hi, st2, "quest", 9), "цепочка с уровнем 10 не стартует на уровне 9")
	_check(int(st2["step"]) == 0, "шаг остался 0 при низком уровне")
	_check(QL.on_talk(hi, st2, "quest", 10), "на уровне 10 цепочка стартует")


func _test_kill_progress() -> void:
	var ch: Dictionary = GD.CHAINS[0]
	var st := QL.new_state()
	QL.on_talk(ch, st, "quest", 1)
	_check(not QL.on_kill(ch, st, "wolf"), "убийство не того моба не засчитывается")
	_check(int(st["count"]) == 0, "счётчик не растёт от чужого моба")
	for i in 4:
		_check(QL.on_kill(ch, st, "slime"), "слайм %d засчитан" % (i + 1))
	_check(int(st["step"]) == 1, "после 4 слаймов ещё шаг убийства")
	_check(int(st["count"]) == 4, "счётчик 4 из 5")
	_check(QL.on_kill(ch, st, "slime"), "пятый слайм засчитан")
	_check(int(st["step"]) == 2, "после 5 слаймов шаг разговора")
	_check(int(st["count"]) == 0, "счётчик сброшен на новом шаге")
	_check(not QL.on_kill(ch, st, "slime"), "убийство на шаге разговора не засчитывается")


func _test_full_chain() -> void:
	var ch: Dictionary = GD.CHAINS[0]
	var st := QL.new_state()
	QL.on_talk(ch, st, "quest", 1)
	for i in 5:
		QL.on_kill(ch, st, "slime")
	_check(not QL.is_complete(ch, st), "цепочка не завершена до финального разговора")
	QL.on_talk(ch, st, "quest", 1)
	_check(QL.is_complete(ch, st), "после финального разговора цепочка завершена")
	_check(QL.current_step(ch, st).is_empty(), "завершённая цепочка не имеет текущего шага")


func _test_claim_rules() -> void:
	var ch: Dictionary = GD.CHAINS[0]
	var st := QL.new_state()
	_check(not QL.can_claim(ch, st, 1), "нельзя сдать незавершённую цепочку")
	_check(not QL.claim(ch, st, 1), "claim незавершённой цепочки отклонён")
	QL.on_talk(ch, st, "quest", 1)
	for i in 5:
		QL.on_kill(ch, st, "slime")
	QL.on_talk(ch, st, "quest", 1)
	_check(QL.claim(ch, st, 1), "claim завершённой цепочки проходит")
	_check(bool(st["claimed"]), "цепочка помечена как полученная")
	_check(not QL.claim(ch, st, 1), "повторный claim отклонён")
	_check(not QL.on_kill(ch, st, "slime"), "после claim убийства не засчитываются")
	_check(not QL.on_talk(ch, st, "quest", 1), "после claim разговор не продвигает")
