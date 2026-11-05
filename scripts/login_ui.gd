extends Control
## Экран входа клиента: адрес сервера, логин, пароль, класс. После входа показывает состояние персонажа.

var _host: LineEdit
var _user: LineEdit
var _pass: LineEdit
var _cls: OptionButton
var _connect: Button
var _status: Label
var _info: Label
var _equip: Label
var _unequip_weapon: Button
var _unequip_armor: Button
var _refine_weapon_btn: Button
var _refine_armor_btn: Button
var _heal_btn: Button
var _shop_btn: Button
var _shop_box: VBoxContainer
var _quest_label: Label
var _talk_btn: Button
var _claim_btn: Button
var _promote_btn: Button
var _quest_ready_id := ""
var _view: Node2D = null
var _scroll: ScrollContainer = null
const WORLD_VIEW := preload("res://scripts/world_view.gd")
var _prof_label: Label
var _prof_box: VBoxContainer
var _prof_buttons := {}
var _timeout: Timer
var _stage := ""
var _login_user := ""
var _login_class := ""
var _local: Node = null

const CLASS_IDS := ["sword", "mage", "archer"]
const QL := preload("res://scripts/quest_logic.gd")
const PL := preload("res://scripts/profession_logic.gd")
const CLASS_NAMES := ["Мечник", "Маг", "Лучник"]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	size = get_viewport_rect().size
	_build()
	Net.world = self
	Net.connected_ok.connect(_on_connected)
	Net.connection_failed.connect(_on_failed)
	Net.disconnected.connect(_on_lost)
	_timeout = Timer.new()
	_timeout.one_shot = true
	_timeout.wait_time = 12.0
	_timeout.timeout.connect(_on_timeout)
	add_child(_timeout)


var _bg: Control
var _my_id := 1


func _build() -> void:
	_bg = preload("res://scripts/splash_bg.gd").new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var scroll := _scroll

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(440, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Asgard Online — тест"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_host = _field(box, "Адрес сервера (IP или домен)", "")
	_user = _field(box, "Логин", "")
	_pass = _field(box, "Пароль", "")
	_pass.secret = true

	_cls = OptionButton.new()
	for i in CLASS_NAMES.size():
		_cls.add_item(CLASS_NAMES[i], i)
	_cls.custom_minimum_size = Vector2(0, 56)
	box.add_child(_cls)

	_connect = Button.new()
	_connect.text = "Войти"
	_connect.custom_minimum_size = Vector2(0, 64)
	_connect.add_theme_font_size_override("font_size", 22)
	_connect.pressed.connect(_on_connect_pressed)
	box.add_child(_connect)

	var offline_btn := Button.new()
	offline_btn.text = "Играть офлайн (без сервера)"
	offline_btn.custom_minimum_size = Vector2(0, 56)
	offline_btn.pressed.connect(_on_offline_pressed)
	box.add_child(offline_btn)

	_status = Label.new()
	_status.text = "Введите адрес сервера, логин и пароль"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_status)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_info)

	_equip = Label.new()
	_equip.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_equip)

	_unequip_weapon = Button.new()
	_unequip_weapon.text = "Снять оружие"
	_unequip_weapon.custom_minimum_size = Vector2(0, 48)
	_unequip_weapon.pressed.connect(_on_unequip.bind("eq_weapon"))
	box.add_child(_unequip_weapon)

	_unequip_armor = Button.new()
	_unequip_armor.text = "Снять броню"
	_unequip_armor.custom_minimum_size = Vector2(0, 48)
	_unequip_armor.pressed.connect(_on_unequip.bind("eq_armor"))
	box.add_child(_unequip_armor)

	_refine_weapon_btn = Button.new()
	_refine_weapon_btn.text = "Улучшить оружие"
	_refine_weapon_btn.custom_minimum_size = Vector2(0, 48)
	_refine_weapon_btn.pressed.connect(_on_refine.bind("eq_weapon"))
	box.add_child(_refine_weapon_btn)

	_refine_armor_btn = Button.new()
	_refine_armor_btn.text = "Улучшить броню"
	_refine_armor_btn.custom_minimum_size = Vector2(0, 48)
	_refine_armor_btn.pressed.connect(_on_refine.bind("eq_armor"))
	box.add_child(_refine_armor_btn)

	_heal_btn = Button.new()
	_heal_btn.text = "Лечиться у лекаря"
	_heal_btn.custom_minimum_size = Vector2(0, 48)
	_heal_btn.pressed.connect(_on_heal)
	box.add_child(_heal_btn)

	_shop_btn = Button.new()
	_shop_btn.text = "Магазин"
	_shop_btn.custom_minimum_size = Vector2(0, 48)
	_shop_btn.pressed.connect(_on_shop_toggle)
	box.add_child(_shop_btn)

	_shop_box = VBoxContainer.new()
	_shop_box.visible = false
	box.add_child(_shop_box)

	_quest_label = Label.new()
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_quest_label)

	_talk_btn = Button.new()
	_talk_btn.text = "Поговорить со Старейшиной"
	_talk_btn.custom_minimum_size = Vector2(0, 48)
	_talk_btn.pressed.connect(_on_talk_quest)
	box.add_child(_talk_btn)

	_claim_btn = Button.new()
	_claim_btn.text = "Сдать квест"
	_claim_btn.custom_minimum_size = Vector2(0, 48)
	_claim_btn.pressed.connect(_on_claim_chain)
	box.add_child(_claim_btn)

	_promote_btn = Button.new()
	_promote_btn.text = "Повысить класс (5 ур., 300 зол.)"
	_promote_btn.custom_minimum_size = Vector2(0, 48)
	_promote_btn.pressed.connect(_on_promote)
	box.add_child(_promote_btn)

	_prof_label = Label.new()
	_prof_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(_prof_label)

	_prof_box = VBoxContainer.new()
	_prof_box.add_theme_constant_override("separation", 6)
	box.add_child(_prof_box)
	_set_play_controls(false)


func _field(parent: Node, placeholder: String, value: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.text = value
	e.custom_minimum_size = Vector2(0, 56)
	parent.add_child(e)
	return e


func _on_connect_pressed() -> void:
	var host := _host.text.strip_edges()
	var user := _user.text.strip_edges()
	var pw := _pass.text
	if host.is_empty():
		_set_status("Введите адрес сервера")
		return
	if user.is_empty() or pw.is_empty():
		_set_status("Введите логин и пароль")
		return
	_login_user = user
	_login_class = CLASS_IDS[_cls.selected]
	_stage = "connect"
	_connect.disabled = true
	_set_status("Подключение к %s..." % host)
	_timeout.start()
	Net.join(host, Net.PORT)


func _on_offline_pressed() -> void:
	var who := _user.text.strip_edges()
	if who.is_empty():
		who = "Hero"
	start_offline(who, CLASS_IDS[_cls.selected])


func start_offline(char_name: String, class_id: String) -> void:
	_stop_local()
	_open_view()
	Net.offline = true
	Net.is_server = true
	_local = preload("res://scripts/server_world.gd").new()
	_local.name = "LocalWorld"
	add_child(_local)
	_set_status("Офлайн-мир запущен")
	_local.start_local(char_name, class_id)


func _open_view() -> void:
	if _bg:
		_bg.visible = false
	if _scroll:
		_scroll.anchor_right = 0.0
		_scroll.offset_right = PANEL_WIDTH
	if _view == null:
		_view = WORLD_VIEW.new()
		_view.name = "WorldView"
		add_child(_view)
		move_child(_view, 0)
		_view.move_requested.connect(_on_view_move)
		_view.attack_requested.connect(_on_view_attack)


func _close_view() -> void:
	if _bg:
		_bg.visible = true
	if _scroll:
		_scroll.anchor_right = 1.0
		_scroll.offset_right = 0.0
	if _view:
		_view.queue_free()
		_view = null


func _stop_local() -> void:
	_close_view()
	if _local:
		_local.queue_free()
		_local = null
	Net.offline = false
	Net.is_server = false


func status_text() -> String:
	return _status.text


func info_text() -> String:
	return _info.text


func _on_connected() -> void:
	_set_status("Проверка логина...")
	Net.c_auth.rpc_id(1, _login_user, _pass.text)


func _on_failed() -> void:
	_fail("Не удалось подключиться к серверу")


func _on_lost() -> void:
	_fail("Соединение с сервером потеряно")


func _on_timeout() -> void:
	if _stage == "connect":
		_fail("Сервер не отвечает")


func _fail(text: String) -> void:
	_timeout.stop()
	_stop_local()
	_stage = ""
	_connect.disabled = false
	_set_status(text)
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func _set_status(text: String) -> void:
	_status.text = text


func client_auth_result(ok: bool, msg: String) -> void:
	if not ok:
		_fail(msg)
		return
	_stage = "login"
	_set_status("Вход в мир...")
	Net.c_login.rpc_id(1, _login_user, _login_class)


func client_login_result(ok: bool, msg: String, data: Dictionary) -> void:
	_timeout.stop()
	if not ok:
		_fail(msg)
		return
	_my_id = int(data.get("id", 1))
	_open_view()
	_stage = "play"
	_connect.text = "Выйти"
	_connect.disabled = false
	if _connect.pressed.is_connected(_on_connect_pressed):
		_connect.pressed.disconnect(_on_connect_pressed)
	_connect.pressed.connect(_on_logout)
	_set_status("В игре: %s, ур. %d" % [data["name"], data["lvl"]])
	_set_play_controls(true)
	_show_self(data)


func _on_logout() -> void:
	_stage = ""
	_stop_local()
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_connect.text = "Войти"
	_connect.pressed.disconnect(_on_logout)
	_connect.pressed.connect(_on_connect_pressed)
	_set_status("Вы вышли из игры")
	_info.text = ""
	_set_play_controls(false)


func _show_self(d: Dictionary) -> void:
	_info.text = "HP %d/%d   MP %d/%d   золото %d\nКарта: %s" % [d["hp"], d["maxhp"], d["mp"], d["maxmp"], d["gold"], String(d.get("map", "prontera"))]
	_show_equip(d)
	_show_quests(d)
	_show_profs(d)


func _show_profs(d: Dictionary) -> void:
	var st: Dictionary = d.get("prof", PL.new_state())
	var learned: Array = st.get("learned", [])
	var lines := PackedStringArray()
	for prof_id in PL.PROFS.keys():
		if learned.has(prof_id):
			var lvl := PL.level_of(st, prof_id)
			lines.append("%s: ур. %d" % [PL.PROFS[prof_id]["name"], lvl])
	_prof_label.text = "Профессии: " + (", ".join(lines) if lines.size() > 0 else "не изучены")

	# Кнопки пересобираются из данных каждый раз, чтобы не копить старые
	for c in _prof_box.get_children():
		c.queue_free()
	_prof_buttons.clear()
	for prof_id in PL.PROFS.keys():
		if learned.has(prof_id):
			continue
		var b := Button.new()
		b.text = "Изучить: %s" % PL.PROFS[prof_id]["name"]
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(_on_learn.bind(prof_id))
		_prof_box.add_child(b)
		_prof_buttons[prof_id] = b
	for node in PL.NODES:
		if learned.has(node["prof"]):
			var g := Button.new()
			g.text = "Добыть: %s" % node["name"]
			g.custom_minimum_size = Vector2(0, 44)
			g.pressed.connect(_on_gather.bind(node["id"]))
			_prof_box.add_child(g)
	for r in PL.RECIPES:
		if learned.has(r["prof"]):
			var cbtn := Button.new()
			cbtn.text = "Создать: %s" % r["name"]
			cbtn.custom_minimum_size = Vector2(0, 44)
			cbtn.pressed.connect(_on_craft.bind(r["id"]))
			_prof_box.add_child(cbtn)


func _on_learn(prof_id: String) -> void:
	_send_prof("learn", prof_id)


func _on_gather(node_id: String) -> void:
	_send_prof("gather", node_id)


func _on_craft(recipe_id: String) -> void:
	_send_prof("craft", recipe_id)


func _send_prof(action: String, arg: String) -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		match action:
			"learn": _local.on_learn(1, arg)
			"gather": _local.on_gather(1, arg)
			"craft": _local.on_craft(1, arg)
	else:
		match action:
			"learn": Net.c_learn.rpc_id(1, arg)
			"gather": Net.c_gather.rpc_id(1, arg)
			"craft": Net.c_craft.rpc_id(1, arg)


func _show_quests(d: Dictionary) -> void:
	var chains: Dictionary = d.get("chains", {})
	var lvl := int(d.get("lvl", 1))
	var text := ""
	_quest_ready_id = ""
	for ch in GameData.CHAINS:
		var st: Dictionary = chains.get(ch["id"], QL.new_state())
		if bool(st.get("claimed", false)):
			continue
		if int(ch["min_level"]) > lvl and int(st.get("step", 0)) == 0:
			continue
		if QL.can_claim(ch, st, lvl):
			_quest_ready_id = ch["id"]
			text = "%s: готово к сдаче" % ch["title"]
			break
		var step := QL.current_step(ch, st)
		if step.is_empty():
			continue
		text = "%s: %s" % [ch["title"], step["text"]]
		if step["type"] == "kill":
			text += " (%d/%d)" % [int(st.get("count", 0)), int(step["count"])]
		break
	if text == "":
		text = "Новых квестов нет"
	_quest_label.text = "Квест: " + text
	_claim_btn.disabled = _quest_ready_id == ""


const PANEL_WIDTH := 460.0


func _on_view_move(pos: Vector2) -> void:
	if Net.offline and _local:
		_local.on_move(1, pos)
	else:
		Net.c_move.rpc_id(1, pos)


func _on_view_attack(mob_id: int) -> void:
	if Net.offline and _local:
		_local.on_attack(1, mob_id)
	else:
		Net.c_attack.rpc_id(1, mob_id)


func _on_talk_quest() -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		_local.on_talk_npc(1, "quest")
	else:
		Net.c_talk_npc.rpc_id(1, "quest")


func _on_promote() -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		_local.on_promote(1)
	else:
		Net.c_promote.rpc_id(1)


func _on_claim_chain() -> void:
	if _stage != "play" or _quest_ready_id == "":
		return
	if Net.offline and _local:
		_local.on_chain_claim(1, _quest_ready_id)
	else:
		Net.c_chain_claim.rpc_id(1, _quest_ready_id)


func _show_equip(d: Dictionary) -> void:
	var w: String = String(d.get("eq_weapon", ""))
	var a: String = String(d.get("eq_armor", ""))
	var wn: String = GameData.ITEMS[w]["name"] if w != "" else "нет"
	var an: String = GameData.ITEMS[a]["name"] if a != "" else "нет"
	var rw := int(d.get("refine_weapon", 0))
	var ra := int(d.get("refine_armor", 0))
	_equip.text = "Оружие: %s%s\nБроня: %s%s" % [wn, (" +%d" % rw) if rw > 0 else "", an, (" +%d" % ra) if ra > 0 else ""]
	_unequip_weapon.disabled = w == ""
	_unequip_armor.disabled = a == ""
	_refine_weapon_btn.disabled = w == ""
	_refine_armor_btn.disabled = a == ""


func _set_play_controls(on: bool) -> void:
	_prof_label.visible = on
	_prof_box.visible = on
	_unequip_weapon.visible = on
	_unequip_armor.visible = on
	_refine_weapon_btn.visible = on
	_refine_armor_btn.visible = on
	_heal_btn.visible = on
	_shop_btn.visible = on
	if not on:
		_shop_box.visible = false
	_equip.visible = on
	_quest_label.visible = on
	_talk_btn.visible = on
	_claim_btn.visible = on


func _on_unequip(slot: String) -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		_local.on_unequip(1, slot)
	else:
		Net.c_unequip.rpc_id(1, slot)


func _on_refine(slot: String) -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		_local.on_refine(1, slot)
	else:
		Net.c_refine.rpc_id(1, slot)


func _on_shop_toggle() -> void:
	if _stage != "play":
		return
	_shop_box.visible = not _shop_box.visible
	if not _shop_box.visible:
		return
	for c in _shop_box.get_children():
		c.queue_free()
	# список продаётся только из игровых товаров с ценой > 0 (то же правило, что на сервере)
	var ids: Array = GameData.ITEMS.keys()
	ids.sort()
	for id in ids:
		var it: Dictionary = GameData.ITEMS[id]
		var price := int(it.get("price", 0))
		if price <= 0:
			continue
		var b := Button.new()
		b.text = "%s — %d зол." % [it["name"], price]
		b.custom_minimum_size = Vector2(0, 40)
		b.pressed.connect(_on_buy.bind(String(id)))
		_shop_box.add_child(b)


func _on_buy(item_id: String) -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		_local.on_buy(1, item_id)
	else:
		Net.c_buy.rpc_id(1, item_id)


func _on_heal() -> void:
	if _stage != "play":
		return
	if Net.offline and _local:
		_local.on_heal(1)
	else:
		Net.c_heal.rpc_id(1)


func client_self(d: Dictionary) -> void:
	if _stage == "play":
		_show_self(d)


func client_snapshot(snap: Dictionary) -> void:
	if _stage == "play" and _view:
		_view.apply_snapshot(snap, _my_id)
	if _stage == "play":
		_info.text = _info.text.split("\n")[0] + "\nИгроков онлайн: %d, мобов: %d" % [snap["players"].size(), snap["mobs"].size()]


func client_notify(text: String) -> void:
	_set_status(text)


func client_store_result(ok: bool, msg: String) -> void:
	_set_status(msg)


func client_chat(from_name: String, text: String) -> void:
	_set_status("%s: %s" % [from_name, text])
