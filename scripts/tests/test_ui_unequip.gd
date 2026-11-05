extends SceneTree
## Интеграционная проверка: офлайн-вход, надевание, снятие через UI-обработчик.
## Запуск: xvfb-run godot --path . -s res://scripts/tests/test_ui_unequip.gd

var main
var frames := 0
var fails := 0


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _find(n: Node, p: String) -> Node:
	if n.get_script() and n.get_script().resource_path == p:
		return n
	for c in n.get_children():
		var f := _find(c, p)
		if f:
			return f
	return null


func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL: ", msg)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		var ui := _find(main, "res://scripts/login_ui.gd")
		_check(ui != null, "экран входа создан")
		ui.start_offline("Tester", "sword")
		_check(ui._stage == "play", "офлайн-вход переводит в стадию play, стадия: %s" % ui._stage)
		_check(ui._unequip_weapon.visible, "кнопка снятия оружия видна в игре")
		_check(ui._unequip_weapon.disabled, "снять пустое оружие нельзя (кнопка отключена)")
		_check(ui._equip.text.contains("нет"), "в панели экипировки написано «нет»")

		var w = ui._local
		w.players[1]["inv"]["troll_club"] = 1
		w.on_use_item(1, "troll_club")
		_check(w.players[1]["eq_weapon"] == "troll_club", "дубина надета на сервере")
		_check(ui._equip.text.contains("Дробитель тролля"), "панель показывает надетую дубину: %s" % ui._equip.text.replace("\n", " | "))
		_check(not ui._unequip_weapon.disabled, "кнопка снятия оружия активна")

		ui._on_unequip("eq_weapon")
		_check(w.players[1]["eq_weapon"] == "", "оружие снято на сервере")
		_check(int(w.players[1]["inv"].get("troll_club", 0)) == 1, "дубина вернулась в инвентарь")
		_check(ui._unequip_weapon.disabled, "после снятия кнопка снова отключена")
		_check(ui._equip.text.contains("Оружие: нет"), "панель после снятия: %s" % ui._equip.text.replace("\n", " | "))

		print("проверок UI: интеграция, провалов: %d" % fails)
		quit(1 if fails > 0 else 0)
	return false
