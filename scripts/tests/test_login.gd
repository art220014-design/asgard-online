extends SceneTree
## Правила логина и имени персонажа: 4–16 латинских букв и цифр, пароль от 8 символов.

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
	var net = root.get_node_or_null("/root/Net")
	if net:
		net.offline = true
		net.is_server = true
	var SW = load("res://scripts/server_world.gd")
	var w = SW.new()
	root.add_child(w)
	w._ready()

	_check(w.NAME_MIN == 4, "минимум имени 4")
	_check(w.NAME_MAX == 16, "максимум имени 16")
	_check(not w._valid_name("abc"), "3 символа отклоняются")
	_check(w._valid_name("abcd"), "4 символа принимаются")
	_check(w._valid_name("admin"), "admin принимается")
	_check(w._valid_name("nettest01"), "буквы с цифрами принимаются")
	_check(w._valid_name("A" .repeat(16)), "16 символов принимаются")
	_check(not w._valid_name("A".repeat(17)), "17 символов отклоняются")
	_check(not w._valid_name("gm_admin"), "подчёркивание отклоняется (правило без изменений)")
	_check(not w._valid_name("Иван123"), "кириллица отклоняется")
	_check(not w._valid_name("ab cd"), "пробел отклоняется")
	_check(not w._valid_name(""), "пустое имя отклоняется")

	# пароль: 8 символов (Accounts.MIN_PASS)
	var Acc = load("res://scripts/accounts.gd")
	_check(Acc.MIN_PASS == 8, "минимум пароля 8")

	print("проверок логина: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
