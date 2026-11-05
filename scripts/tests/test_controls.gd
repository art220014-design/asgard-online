extends SceneTree
## Управление миром: нажатие выбирает моба, игрок идёт и бьёт, пустая земля — только движение.
## Запуск: xvfb-run godot --headless --path . -s res://scripts/tests/test_controls.gd

var main
var ui
var frames := 0
var fails := 0
var checks := 0
var target_mob := 0
var hp_start := 0


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL: ", msg)


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


func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		ui = _find(main, "res://scripts/login_ui.gd")
		ui.start_offline("Ctrl", "sword")
		var w = ui._local
		w.players[1]["pos"] = Vector2(1000, 900)
		w.players[1]["target"] = w.players[1]["pos"]
		w.players[1]["cds"] = {}
		var m = w.mobs[0]
		m["pos"] = Vector2(1040, 900)
		m["home"] = m["pos"]
		m["target"] = m["pos"]
		m["dead"] = false
		m["hp"] = m["maxhp"]
		target_mob = m["id"]
		hp_start = int(m["hp"])
	if frames == 6:
		var view = ui._view
		_check(view != null, "вид открыт")
		var w2 = ui._local
		var mob = w2.mobs[0]
		_check(mob["id"] == target_mob, "моб на месте")
		view.apply_snapshot({
			"players": [{"id": 1, "n": "Ctrl", "c": "sword", "l": 1, "p": w2.players[1]["pos"], "hp": 160, "mhp": 160, "d": false}],
			"mobs": [{"id": target_mob, "t": "slime", "p": mob["pos"], "hp": mob["hp"], "mhp": mob["maxhp"]}],
			"events": []}, 1)
		view._players[1]["pos"] = w2.players[1]["pos"]
		view._mobs[target_mob]["pos"] = mob["pos"]
		# клик по мобу
		view._on_tap(mob["pos"])
		_check(view._selected == target_mob, "клик по мобу выбирает его")
	if frames == 30:
		var w3 = ui._local
		var mob3 = w3.mobs[0]
		_check(int(mob3["hp"]) < hp_start, "игрок ударил моба, hp %d -> %d" % [hp_start, int(mob3["hp"])])
	if frames == 32:
		var view2 = ui._view
		# клик по пустой земле — выделение снимается, движение идёт
		view2._on_tap(Vector2(1300, 1100))
		_check(view2._selected == -1, "клик по пустой земле снимает выбор")
		print("проверок управления: %d, провалов: %d" % [checks, fails])
		quit(1 if fails > 0 else 0)
	return false
