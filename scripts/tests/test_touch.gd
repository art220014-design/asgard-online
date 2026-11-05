extends SceneTree
## Касание через реальный конвейер ввода: InputEventScreenTouch -> Input.parse_input_event.
## Проверяет, что касание по мобу выбирает его и запускает бой (как на телефоне).
## Запуск: xvfb-run godot --headless --path . -s res://scripts/tests/test_touch.gd

const ZOOM := 1.6  # должен совпадать с world_view.ZOOM
var main
var ui
var frames := 0
var fails := 0
var checks := 0
var mob_id := 0


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
		ui.start_offline("Touch", "sword")
		var w = ui._local
		w.players[1]["pos"] = Vector2(1000, 900)
		w.players[1]["target"] = w.players[1]["pos"]
		w.players[1]["cds"] = {}
		w.players[1]["path"] = []
		var m = w.mobs[0]
		m["pos"] = Vector2(1040, 900)
		m["home"] = m["pos"]
		m["target"] = m["pos"]
		m["dead"] = false
		m["hp"] = m["maxhp"]
		mob_id = m["id"]
	if frames == 6:
		var view = ui._view
		_check(view != null, "вид открыт")
		var w2 = ui._local
		view.apply_snapshot({
			"players": [{"id": 1, "n": "Touch", "c": "sword", "l": 1, "p": w2.players[1]["pos"], "hp": 160, "mhp": 160, "d": false}],
			"mobs": [{"id": mob_id, "t": "slime", "p": w2.mobs[0]["pos"], "hp": w2.mobs[0]["hp"], "mhp": w2.mobs[0]["maxhp"]}],
			"events": []}, 1)
		# Палец касается экрана над мобом. Событие InputEventScreenTouch подаётся
		# напрямую в обработчик вида: Input.parse_input_event в headless-окружении
		# масштабирует координаты (окно 0x0), поэтому системный конвейер здесь не проверяем.
		var touch_at: Vector2 = Vector2(view.position) + Vector2(1040, 900) * ZOOM
		var down := InputEventScreenTouch.new()
		down.index = 0
		down.pressed = true
		down.position = touch_at
		view._unhandled_input(down)
		var up := InputEventScreenTouch.new()
		up.index = 0
		up.pressed = false
		up.position = touch_at
		view._unhandled_input(up)
	if frames == 12:
		var view2 = ui._view
		_check(view2._selected == mob_id, "касание по мобу выбирает его (selected=%d)" % view2._selected)
		var w3 = ui._local
		_check(int(w3.mobs[0]["hp"]) < int(w3.mobs[0]["maxhp"]), "касание запускает бой: hp моба %d/%d" % [w3.mobs[0]["hp"], w3.mobs[0]["maxhp"]])
		print("проверок касания: %d, провалов: %d" % [checks, fails])
		quit(1 if fails > 0 else 0)
	return false
