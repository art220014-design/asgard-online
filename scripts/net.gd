extends Node
## Сетевой слой. Все RPC живут здесь, потому что у автозагрузки путь /root/Net
## одинаковый и на сервере, и на клиенте. Логика делегируется в world.

const PORT := 7777
const MAX_CLIENTS := 128

signal connected_ok
signal connection_failed
signal disconnected

var is_server := false
var offline := false
var world: Node = null


func host(port: int = PORT) -> bool:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(port, MAX_CLIENTS) != OK:
		return false
	multiplayer.multiplayer_peer = peer
	is_server = true
	return true


func join(address: String, port: int = PORT) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = peer
	is_server = false
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.server_disconnected.connect(_on_lost)


func _on_connected() -> void:
	connected_ok.emit()


func _on_failed() -> void:
	connection_failed.emit()


func _on_lost() -> void:
	disconnected.emit()


func _sender() -> int:
	return multiplayer.get_remote_sender_id()


func send_to(peer: int, method: String, args: Array) -> void:
	# RPC на собственный id движок запрещает: в офлайн-мире и на сервере, который
	# отправляет сам себе, доставляем вызов напрямую.
	if offline or peer == multiplayer.get_unique_id():
		callv(method, args)
		return
	match method:
		"s_auth_result":
			s_auth_result.rpc_id(peer, args[0], args[1])
		"s_login_result":
			s_login_result.rpc_id(peer, args[0], args[1], args[2])
		"s_store_result":
			s_store_result.rpc_id(peer, args[0], args[1])
		"s_self":
			s_self.rpc_id(peer, args[0])
		"s_notify":
			s_notify.rpc_id(peer, args[0])
		"s_snapshot":
			s_snapshot.rpc_id(peer, args[0])
		"s_chat":
			s_chat.rpc_id(peer, args[0], args[1])


# ---------------- клиент -> сервер ----------------

@rpc("any_peer", "reliable")
func c_auth(user: String, password: String) -> void:
	if is_server and world:
		world.on_auth(_sender(), user, password)


@rpc("any_peer", "reliable")
func c_login(char_name: String, class_id: String) -> void:
	if is_server and world:
		world.on_login(_sender(), char_name, class_id)


@rpc("any_peer", "unreliable_ordered")
func c_move(target: Vector2) -> void:
	if is_server and world:
		world.on_move(_sender(), target)


@rpc("any_peer", "reliable")
func c_skill(skill_id: String, target_id: int, target_pos: Vector2) -> void:
	if is_server and world:
		world.on_skill(_sender(), skill_id, target_id, target_pos)


@rpc("any_peer", "reliable")
func c_attack(target_id: int) -> void:
	if is_server and world:
		world.on_attack(_sender(), target_id)


@rpc("any_peer", "reliable")
func c_buy(item_id: String) -> void:
	if is_server and world:
		world.on_buy(_sender(), item_id)


@rpc("any_peer", "reliable")
func c_use_item(item_id: String) -> void:
	if is_server and world:
		world.on_use_item(_sender(), item_id)


@rpc("any_peer", "reliable")
func c_unequip(slot: String) -> void:
	if is_server and world:
		world.on_unequip(_sender(), slot)


@rpc("any_peer", "reliable")
func c_refine(slot: String) -> void:
	if is_server and world:
		world.on_refine(_sender(), slot)


@rpc("any_peer", "reliable")
func c_heal() -> void:
	if is_server and world:
		world.on_heal(_sender())


@rpc("any_peer", "reliable")
func c_learn(prof: String) -> void:
	if is_server and world:
		world.on_learn(_sender(), prof)


@rpc("any_peer", "reliable")
func c_gather(node_id: String) -> void:
	if is_server and world:
		world.on_gather(_sender(), node_id)


@rpc("any_peer", "reliable")
func c_craft(recipe_id: String) -> void:
	if is_server and world:
		world.on_craft(_sender(), recipe_id)


@rpc("any_peer", "reliable")
func c_promote() -> void:
	if is_server and world:
		world.on_promote(_sender())


@rpc("any_peer", "reliable")
func c_talk_npc(npc: String) -> void:
	if is_server and world:
		world.on_talk_npc(_sender(), npc)


@rpc("any_peer", "reliable")
func c_chain_claim(chain_id: String) -> void:
	if is_server and world:
		world.on_chain_claim(_sender(), chain_id)


@rpc("any_peer", "reliable")
func c_quest_claim(quest_id: String) -> void:
	if is_server and world:
		world.on_quest_claim(_sender(), quest_id)


@rpc("any_peer", "reliable")
func c_purchase(product_id: String, purchase_token: String) -> void:
	if is_server and world:
		world.on_purchase(_sender(), product_id, purchase_token)


@rpc("any_peer", "reliable")
func c_chat(text: String) -> void:
	if is_server and world:
		world.on_chat(_sender(), text)


# ---------------- сервер -> клиент ----------------

@rpc("authority", "reliable")
func s_auth_result(ok: bool, msg: String) -> void:
	if world:
		world.client_auth_result(ok, msg)


@rpc("authority", "reliable")
func s_login_result(ok: bool, msg: String, self_data: Dictionary) -> void:
	if world:
		world.client_login_result(ok, msg, self_data)


@rpc("authority", "reliable")
func s_snapshot(snap: Dictionary) -> void:
	if world:
		world.client_snapshot(snap)


@rpc("authority", "reliable")
func s_self(data: Dictionary) -> void:
	if world:
		world.client_self(data)


@rpc("authority", "reliable")
func s_notify(text: String) -> void:
	if world:
		world.client_notify(text)


@rpc("authority", "reliable")
func s_store_result(ok: bool, msg: String) -> void:
	if world:
		world.client_store_result(ok, msg)


@rpc("authority", "reliable")
func s_chat(from_name: String, text: String) -> void:
	if world:
		world.client_chat(from_name, text)
