extends Node
## Сетевой проверочный клиент: вход, движение и удар по настоящему серверу через RPC.
## Запуск: godot --headless --path . -- --net-combat --user LOGIN --pass PASS
## Выход: 0 — движение и удар дошли по сети; иначе код ошибки и сообщение.

const TIMEOUT := 60.0
const ATTACK_RANGE := 76.0
const MAX_ATTACKS := 12
const MAX_MOVE_TICKS := 400

var _user := ""
var _pass := ""
var _elapsed := 0.0
var _my_id := 0
var _state := "connect"

var _mob_id := -1
var _mob_now := Vector2.ZERO
var _mob_hp_start := -1
var _mob_hp_now := -1
var _my_pos := Vector2.ZERO

var _attacks_sent := 0
var _move_ticks := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_user = _arg(args, "--user")
	_pass = _arg(args, "--pass")
	Net.world = self
	Net.connected_ok.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.join("127.0.0.1", Net.PORT)


static func _arg(args: PackedStringArray, key: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""


func _on_connected() -> void:
	_my_id = multiplayer.get_unique_id()
	Net.c_auth.rpc_id(1, _user, _pass)


func _on_failed() -> void:
	_finish(2, "соединение не установлено")


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > TIMEOUT:
		_finish(3, "таймаут на этапе %s" % _state)


func client_auth_result(ok: bool, msg: String) -> void:
	if not ok:
		_finish(5, "вход отклонён: %s" % msg)
		return
	_state = "login"
	Net.c_login.rpc_id(1, _user, "sword")


func client_login_result(ok: bool, msg: String, _data: Dictionary) -> void:
	if not ok:
		_finish(6, "персонаж не создан: %s" % msg)
		return
	_state = "snap"


func client_snapshot(snap: Dictionary) -> void:
	for p in snap["players"]:
		if int(p["id"]) == _my_id:
			_my_pos = p["p"]
	if _state == "snap":
		_pick_nearest_mob(snap)
		return
	for m in snap["mobs"]:
		if int(m["id"]) == _mob_id:
			_mob_now = m["p"]
			_mob_hp_now = int(m["hp"])
	match _state:
		"moving":
			_tick_moving()
		"attacking":
			_tick_attacking()


func _pick_nearest_mob(snap: Dictionary) -> void:
	var best := 1e9
	for m in snap["mobs"]:
		var d: float = Vector2(m["p"]).distance_to(_my_pos)
		if d < best:
			best = d
			_mob_id = int(m["id"])
			_mob_now = m["p"]
			_mob_hp_start = int(m["hp"])
			_mob_hp_now = int(m["hp"])
	if _mob_id == -1:
		_finish(7, "в снимке нет мобов")
		return
	_state = "moving"
	Net.c_move.rpc_id(1, _mob_now)


func _tick_moving() -> void:
	_move_ticks += 1
	if _my_pos.distance_to(_mob_now) <= ATTACK_RANGE:
		_state = "attacking"
		_attacks_sent = 0
		return
	if _move_ticks % 10 == 0:
		Net.c_move.rpc_id(1, _mob_now)
	if _move_ticks > MAX_MOVE_TICKS:
		_finish(9, "игрок не дошёл до моба, позиция %s, моб %s" % [str(_my_pos), str(_mob_now)])


func _tick_attacking() -> void:
	if _my_pos.distance_to(_mob_now) > ATTACK_RANGE:
		_state = "moving"
		_move_ticks = 0
		Net.c_move.rpc_id(1, _mob_now)
		return
	if _mob_hp_now < _mob_hp_start:
		_finish(0, "движение и удар по сети: моб %d -> %d HP, игрок %s" % [_mob_hp_start, _mob_hp_now, str(_my_pos)])
		return
	_attacks_sent += 1
	Net.c_attack.rpc_id(1, _mob_id)
	if _attacks_sent > MAX_ATTACKS:
		_finish(8, "удар не снизил HP моба (%d -> %d)" % [_mob_hp_start, _mob_hp_now])


func client_self(_data: Dictionary) -> void:
	pass


func client_notify(text: String) -> void:
	print("[net] notify: ", text)


func client_chat(_from: String, _text: String) -> void:
	pass


func client_store_result(_ok: bool, _msg: String) -> void:
	pass


func _finish(code: int, msg: String) -> void:
	print("[net] %s: %s" % ["OK" if code == 0 else "FAIL", msg])
	get_tree().quit(code)
