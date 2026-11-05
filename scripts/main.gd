extends Node
## Точка входа. Режимы:
##   --server                                выделенный сервер
##   --create-account LOGIN PASSWORD         создать учётную запись и выйти
##   --test-client --user L --pass P        headless-проверка входа (см. test_client.gd)
##   (без флагов)                           клиент (UI ещё не написан)

const DEFAULT_HOST := "127.0.0.1"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--create-account" in args:
		_create_account(args)
	elif "--server" in args:
		_start_server()
	elif "--offline-test" in args:
		_run_offline_test()
	elif "--net-combat" in args:
		var nc := preload("res://scripts/net_combat_client.gd").new()
		nc.name = "NetCombat"
		add_child(nc)
	elif "--test-client" in args:
		var c := preload("res://scripts/test_client.gd").new()
		c.name = "TestClient"
		add_child(c)
	else:
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(preload("res://scripts/login_ui.gd").new())


func _run_offline_test() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui = preload("res://scripts/login_ui.gd").new()
	layer.add_child(ui)
	ui.start_offline("OfflineTest", "sword")
	var t := Timer.new()
	t.wait_time = 3.0
	t.one_shot = true
	add_child(t)
	t.timeout.connect(func():
		var info: String = ui.info_text()
		print("[offline] статус: ", ui.status_text())
		print("[offline] инфо: ", info.replace("\n", " | "))
		get_tree().quit(0 if info.contains("HP") and info.contains("Игроков") else 1))
	t.start()


func _create_account(args: PackedStringArray) -> void:
	var i := args.find("--create-account")
	if i + 2 >= args.size():
		print("[account] использование: --create-account LOGIN PASSWORD")
		get_tree().quit(1)
		return
	var ok := Accounts.create(args[i + 1], args[i + 2])
	print("[account] %s: %s" % [args[i + 1], "создан" if ok else "не создан (занят или пароль короче 8 символов)"])
	get_tree().quit(0 if ok else 1)


func _start_server() -> void:
	if not Net.host(Net.PORT):
		push_error("[server] не удалось открыть порт %d" % Net.PORT)
		get_tree().quit(1)
		return
	var world_node := preload("res://scripts/server_world.gd").new()
	world_node.name = "ServerWorld"
	add_child(world_node)
	Net.world = world_node
	print("[server] слушаю порт %d, мобов: %d" % [Net.PORT, world_node.mobs.size()])
