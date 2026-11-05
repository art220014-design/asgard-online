extends Node
## Тестовый клиент: авторизация, вход, снимок. Запуск:
##   godot --headless --path . -- --test-client --user LOGIN --pass PASS [--purchase-test]
## Сам узел принимает серверные RPC (Net.world).

const TIMEOUT := 15.0

var _user := ""
var _pass := ""
var _purchase := false
var _got_login := false
var _got_snap := false
var _got_self := false
var _elapsed := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_user = _arg(args, "--user")
	_pass = _arg(args, "--pass")
	_purchase = "--purchase-test" in args
	Net.world = self
	Net.connected_ok.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.join("127.0.0.1", Net.PORT)


static func _arg(args: PackedStringArray, key: String) -> String:
	var i := args.find(key)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else ""


func _on_connected() -> void:
	print("[client] соединение установлено, авторизуюсь")
	Net.c_auth.rpc_id(1, _user, _pass)


func _on_failed() -> void:
	print("[client] FAIL: соединение не установлено")
	get_tree().quit(2)


func _process(delta: float) -> void:
	_elapsed += delta
	if _got_login and _got_snap and _got_self:
		print("[client] OK: авторизация, вход, снимок и личные данные получены")
		get_tree().quit(0)
	elif _elapsed > TIMEOUT:
		print("[client] TIMEOUT login=%s snap=%s self=%s" % [_got_login, _got_snap, _got_self])
		get_tree().quit(3)


func client_auth_result(ok: bool, msg: String) -> void:
	print("[client] auth ok=%s msg=%s" % [ok, msg])
	if ok:
		Net.c_login.rpc_id(1, _user, "sword")
	else:
		get_tree().quit(5)


func client_login_result(ok: bool, msg: String, self_data: Dictionary) -> void:
	print("[client] login ok=%s msg=%s" % [ok, msg])
	_got_login = ok
	if not ok:
		return
	_got_self = true
	print("[client] self: %s lvl=%d hp=%d/%d gold=%d" % [self_data["name"], self_data["lvl"], self_data["hp"], self_data["maxhp"], self_data["gold"]])
	if _purchase:
		Net.c_purchase.rpc_id(1, "gold_small", "FAKE-TOKEN-123")


func client_snapshot(snap: Dictionary) -> void:
	_got_snap = true
	print("[client] snapshot: игроков=%d мобов=%d" % [snap["players"].size(), snap["mobs"].size()])


func client_self(data: Dictionary) -> void:
	print("[client] self: %s gold=%d" % [data["name"], data["gold"]])


func client_notify(text: String) -> void:
	print("[client] notify: ", text)


func client_chat(from_name: String, text: String) -> void:
	print("[client] chat %s: %s" % [from_name, text])


func client_store_result(ok: bool, msg: String) -> void:
	print("[client] store ok=%s msg=%s" % [ok, msg])
