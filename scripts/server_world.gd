extends Node
## Авторитетная симуляция. Работает ТОЛЬКО на сервере.
## Клиенту уходят лишь снимки состояния; урон, лут, опыт, цены считаются здесь.

const SAVE_DIR := "user://saves"
const QL := preload("res://scripts/quest_logic.gd")
const PF := preload("res://scripts/pathfind.gd")
const PL := preload("res://scripts/profession_logic.gd")
var _node_depleted := {}  # node_id -> unix-время, когда узел снова доступен
const TICK := 1.0 / 20.0
const SNAP_EVERY := 1.0 / 15.0
const AUTOSAVE_EVERY := 30.0
const RESPAWN_PLAYER := 4.0
const SHOP_RANGE := 170.0
const TALK_RANGE := 170.0
const ATTACK_RANGE_BASIC := 80.0

var players := {}        # peer_id -> Dictionary (состояние персонажа)
var mobs: Array = []     # Array[Dictionary]
var _next_mob_id := 100000
var _mapped := {}       # имя карты -> уже заспавнены мобы
var _cur := ""          # карта, с которой сейчас работаем (для событий)
var _acc := 0.0
var _snap_acc := 0.0
var _save_acc := 0.0
var _events: Array = []  # накопленные события (урон, смерть) за кадр снимка
var _rng := RandomNumberGenerator.new()
var authed := {}         # peer_id -> имя аккаунта (в нижнем регистре)
var auth_fails := {}     # ip -> число неверных паролей
var auth_locked := {}    # ip -> unix-время, до которого вход закрыт
const AUTH_MAX_FAILS := 5
const AUTH_LOCK_SEC := 300.0


func _ready() -> void:
	_rng.randomize()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_mapped[GameData.DEFAULT_MAP] = true
	for spawn in GameData.MOB_SPAWNS:
		_spawn_mob(spawn[0], Vector2(spawn[1], spawn[2]) * GameData.TILE + Vector2(32, 32), GameData.DEFAULT_MAP)
	multiplayer.peer_disconnected.connect(on_disconnect)


func _process(delta: float) -> void:
	if not Net.is_server:
		return
	_acc += delta
	_snap_acc += delta
	_save_acc += delta
	while _acc >= TICK:
		_acc -= TICK
		_simulate(TICK)
	if _snap_acc >= SNAP_EVERY:
		_snap_acc = 0.0
		_broadcast()
	if _save_acc >= AUTOSAVE_EVERY:
		_save_acc = 0.0
		for pid in players:
			_save(players[pid])


# ---------------- карты ----------------

func _pmap(p: Dictionary) -> String:
	return String(p.get("map", GameData.DEFAULT_MAP))


## Делает карту активной для коллизий и запоминает её для событий.
func _activate(mp: String) -> void:
	_cur = mp
	GameData.activate_map(mp)


## NPC есть только на стартовой карте.
func _near_npc(p: Dictionary, pos: Vector2, r: float) -> bool:
	return _pmap(p) == GameData.DEFAULT_MAP and p["pos"].distance_to(pos) <= r


## Восстанавливает карту и позицию игрока при входе.
func _resolve_map(p: Dictionary) -> void:
	var mp := String(p.get("map", GameData.DEFAULT_MAP))
	if not GameData.map_exists(mp):
		mp = GameData.DEFAULT_MAP
	p["map"] = mp
	var sp = p.get("pos")
	if typeof(sp) == TYPE_ARRAY and sp.size() == 2:
		p["pos"] = Vector2(float(sp[0]), float(sp[1]))
	elif typeof(sp) != TYPE_VECTOR2:
		p["pos"] = GameData.SPAWN_POINT if mp == GameData.DEFAULT_MAP else GameData.arrival_pos(mp, GameData.DEFAULT_MAP)
	p["target"] = p["pos"]
	_ensure_map(mp)


## Заспавнить мобов карты из реестра rAthena (один раз, при первом входе).
func _ensure_map(mp: String) -> void:
	if _mapped.has(mp) or not GameData.map_exists(mp):
		return
	_mapped[mp] = true
	var n := 0
	var k := 0
	for sp in GameData.spawns_for(mp):
		var cnt := mini(int(sp[1]), 3)
		var typ := GameData.mob_type_for_level(int(sp[2]))
		for i in cnt:
			if n >= GameData.MAX_MOBS_PER_MAP:
				return
			_spawn_mob(typ, GameData.random_walkable(mp, k), mp)
			k += 1
			n += 1


## Переход через портал: игрок оказывается на другой карте рядом с обратным порталом.
func _check_portal(p: Dictionary) -> void:
	var mp := _pmap(p)
	var pt: Dictionary = GameData.portal_at(mp, p["pos"])
	if pt.is_empty():
		return
	var dst := String(pt["dst"])
	_ensure_map(dst)
	p["map"] = dst
	p["pos"] = GameData.arrival_pos(dst, mp)
	p["target"] = p["pos"]
	p["path"] = []
	p["moving"] = false
	_notify(p["peer"], "Переход: %s" % dst)
	_save(p)
	_send_self(p)


# ---------------- вход и выход ----------------

func _peer_ip(peer: int) -> String:
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	var pp := enet.get_peer(peer) if enet else null
	return pp.get_remote_address() if pp else ""


func on_auth(peer: int, user: String, pw: String) -> void:
	var ip := _peer_ip(peer)
	var now := Time.get_unix_time_from_system()
	if float(auth_locked.get(ip, 0.0)) > now:
		Net.send_to(peer, "s_auth_result", [false, "Слишком много попыток, подождите"])
		return
	var u := user.strip_edges()
	if not _valid_name(u) or not Accounts.check(u, pw):
		var n := int(auth_fails.get(ip, 0)) + 1
		auth_fails[ip] = n
		if n >= AUTH_MAX_FAILS:
			auth_locked[ip] = now + AUTH_LOCK_SEC
			auth_fails.erase(ip)
		Net.send_to(peer, "s_auth_result", [false, "Неверный логин или пароль"])
		return
	auth_fails.erase(ip)
	auth_locked.erase(ip)
	authed[peer] = u.to_lower()
	Net.send_to(peer, "s_auth_result", [true, "ok"])
func start_local(char_name: String, class_id: String) -> void:
	authed[1] = char_name.strip_edges().to_lower()
	on_login(1, char_name, class_id)


func on_login(peer: int, char_name: String, class_id: String) -> void:
	if authed.get(peer, "") != char_name.strip_edges().to_lower():
		Net.send_to(peer, "s_login_result", [false, "Сначала войдите в аккаунт", {}])
		return
	var clean := char_name.strip_edges()
	if not _valid_name(clean):
		Net.send_to(peer, "s_login_result", [false, "Имя: 4-16 латинских букв или цифр", {}])
		return
	if not GameData.CLASSES.has(class_id):
		Net.send_to(peer, "s_login_result", [false, "Неизвестный класс", {}])
		return
	for pid in players:
		if players[pid]["name"].to_lower() == clean.to_lower():
			Net.send_to(peer, "s_login_result", [false, "Этот персонаж уже в игре", {}])
			return
	var p := _load_or_create(clean, class_id)
	p["peer"] = peer
	_resolve_map(p)
	p["moving"] = false
	p["cds"] = {}
	p["dead_until"] = 0.0
	p["processed_tokens"] = p.get("processed_tokens", [])
	p["path"] = []
	p["vip_until"] = float(p.get("vip_until", 0.0))
	players[peer] = p
	Net.send_to(peer, "s_login_result", [true, "ok", _self_data(p)])
	_notify(peer, "Добро пожаловать, %s!" % p["name"])


func on_disconnect(peer: int) -> void:
	authed.erase(peer)
	if players.has(peer):
		_save(players[peer])
		players.erase(peer)


## Логин аккаунта и имя персонажа: 4–16 латинских букв и цифр (как char_name_min_length в rAthena).
const NAME_MIN := 4
const NAME_MAX := 16


func _valid_name(n: String) -> bool:
	if n.length() < NAME_MIN or n.length() > NAME_MAX:
		return false
	var re := RegEx.new()
	re.compile("^[A-Za-z0-9]+$")
	return re.search(n) != null


func _load_or_create(char_name: String, class_id: String) -> Dictionary:
	var path := "%s/%s.json" % [SAVE_DIR, char_name.to_lower()]
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed = JSON.parse_string(f.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			return _hydrate(parsed)
	var base := GameData.class_stats(class_id)
	return _hydrate({
		"name": char_name, "cls": class_id, "lvl": 1, "xp": 0, "gold": 120,
		"hp": base["max_hp"], "mp": base["max_mp"],
		"inv": {"potion": 3, "mana": 1}, "quests": {}, "chains": {}, "prof": PL.new_state(),
		"eq_weapon": "", "eq_armor": "", "refine_weapon": 0, "refine_armor": 0,
	})


## Пересчёт боевых характеристик из уровня, класса и экипировки
func _hydrate(p: Dictionary) -> Dictionary:
	var base := GameData.class_stats(p["cls"])
	var lvl: int = int(p["lvl"])
	var cid: String = String(p["cls"])
	p["maxhp"] = base["max_hp"] + (lvl - 1) * GameData.hp_per_level(cid)
	p["maxmp"] = base["max_mp"] + (lvl - 1) * GameData.sp_per_level(cid)
	var eqb := GameData.equip_bonus(p)
	p["atk"] = base["atk"] + (lvl - 1) * 2 + int(eqb["atk"])
	p["def"] = base["def"] + (lvl - 1) * 1 + int(eqb["defense"])
	p["speed"] = base["speed"]
	p["skills"] = base["skills"]
	p["sprite"] = base["sprite"]
	if typeof(p.get("chains")) != TYPE_DICTIONARY:
		p["chains"] = {}
	if typeof(p.get("prof")) != TYPE_DICTIONARY:
		p["prof"] = PL.new_state()
	if typeof(p["prof"].get("learned")) != TYPE_ARRAY:
		p["prof"]["learned"] = []
	if typeof(p["prof"].get("xp")) != TYPE_DICTIONARY:
		p["prof"]["xp"] = {}
	p["hp"] = clampi(int(p.get("hp", p["maxhp"])), 1, p["maxhp"])
	p["mp"] = clampi(int(p.get("mp", p["maxmp"])), 0, p["maxmp"])
	return p


func _save(p: Dictionary) -> void:
	var out := {}
	for k in ["name", "cls", "lvl", "xp", "gold", "hp", "mp", "inv", "quests", "chains", "prof", "eq_weapon", "eq_armor", "refine_weapon", "refine_armor", "processed_tokens", "vip_until"]:
		out[k] = p[k]
	out["map"] = _pmap(p)
	if p.has("pos") and typeof(p["pos"]) == TYPE_VECTOR2:
		out["pos"] = [p["pos"].x, p["pos"].y]
	var f := FileAccess.open("%s/%s.json" % [SAVE_DIR, p["name"].to_lower()], FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out))


# ---------------- действия игроков ----------------

func on_move(peer: int, target: Vector2) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	var goal := Vector2(clampf(target.x, 0, GameData.WORLD_SIZE.x), clampf(target.y, 0, GameData.WORLD_SIZE.y))
	p["path"] = _route(p["pos"], goal, _pmap(p))
	p["target"] = goal
	p["moving"] = not p["path"].is_empty()


func on_attack(peer: int, target_id: int) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	var basic: String = p["skills"][0]
	var m = _find_mob(target_id)
	if m == null or m["dead"] or String(m.get("map", "")) != _pmap(p):
		return
	_activate(_pmap(p))
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(p["cds"].get(basic, 0.0)):
		return
	if p["pos"].distance_to(m["pos"]) > ATTACK_RANGE_BASIC:
		_notify(peer, "Цель далеко")
		return
	# Базовая атака идёт по ASPD класса и уровня оружия (db/re/job_stats.yml), а не по фиксированному КД.
	var wlvl: int = int(GameData.ITEMS.get(String(p.get("eq_weapon", "")), {}).get("weapon_level", 1))
	p["cds"][basic] = now + GameData.attack_interval(String(p["cls"]), wlvl)
	_cast_damage(p, basic, m)


func on_skill(peer: int, skill_id: String, target_id: int, target_pos: Vector2) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	if not p["skills"].has(skill_id):
		return
	var s: Dictionary = GameData.SKILLS[skill_id]
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(p["cds"].get(skill_id, 0.0)):
		return
	if int(p["mp"]) < int(s["mp"]):
		_notify(peer, "Недостаточно MP")
		return
	p["mp"] -= int(s["mp"])
	p["cds"][skill_id] = now + float(s["cd"])
	match s["kind"]:
		"heal":
			var amount := int(p["atk"] * float(s["power"]) * 3.0)
			p["hp"] = mini(p["maxhp"], p["hp"] + amount)
			_events.append({"m": _cur, "k": "heal", "p": p["pos"], "t": "+%d" % amount, "id": p["peer"]})
		"aoe":
			var center: Vector2 = target_pos
			if center == Vector2.ZERO:
				center = p["pos"]
			_activate(_pmap(p))
			for m in mobs:
				if not m["dead"] and String(m.get("map", "")) == _pmap(p) and m["pos"].distance_to(center) <= float(s["range"]):
					_cast_damage(p, skill_id, m)
		"projectile", "melee":
			var m = _find_mob(target_id)
			_activate(_pmap(p))
			if m != null and not m["dead"] and String(m.get("map", "")) == _pmap(p) and p["pos"].distance_to(m["pos"]) <= float(s["range"]) + 24.0:
				_cast_damage(p, skill_id, m)
			elif skill_id == "bolt" or skill_id == "arrow":
				_notify(peer, "Цель вне досягаемости")


func on_buy(peer: int, item_id: String) -> void:
	var p = players.get(peer)
	if p == null or not GameData.ITEMS.has(item_id) or int(GameData.ITEMS[item_id]["price"]) <= 0:
		return
	if not _near_npc(p, GameData.NPC_SHOP_POS, SHOP_RANGE):
		_notify(peer, "Подойдите к торговцу")
		return
	var price: int = GameData.ITEMS[item_id]["price"]
	if p["gold"] < price:
		_notify(peer, "Недостаточно золота")
		return
	p["gold"] -= price
	p["inv"][item_id] = int(p["inv"].get(item_id, 0)) + 1
	_notify(peer, "Куплено: %s" % GameData.ITEMS[item_id]["name"])
	_send_self(p)


func on_use_item(peer: int, item_id: String) -> void:
	var p = players.get(peer)
	if p == null or int(p["inv"].get(item_id, 0)) <= 0 or not GameData.ITEMS.has(item_id):
		return
	var it: Dictionary = GameData.ITEMS[item_id]
	if it["kind"] == "weapon" or it["kind"] == "armor":
		if GameData.equip(p, item_id):
			_hydrate(p)
			_notify(peer, "Надето: %s" % it["name"])
			_send_self(p)
		return
	match it["kind"]:
		"heal":
			p["hp"] = mini(p["maxhp"], p["hp"] + int(it["amount"]))
		"mana":
			p["mp"] = mini(p["maxmp"], p["mp"] + int(it["amount"]))
		_:
			return
	p["inv"][item_id] -= 1
	if p["inv"][item_id] <= 0:
		p["inv"].erase(item_id)
	_send_self(p)


## Изучить профессию у мастера.
func on_learn(peer: int, prof: String) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	if not PL.trainer_near(p["pos"]):
		_notify(peer, "Подойдите к мастеру профессий")
		return
	var err := PL.learn(p["prof"], prof)
	if err != "":
		_notify(peer, err)
		return
	_notify(peer, "Изучено: %s" % PL.PROFS[prof]["name"])
	_send_self(p)


## Добыча с узла. Узел восстанавливается через NODE_RESPAWN секунд.
func on_gather(peer: int, node_id: String) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	var node := PL.node_by_id(node_id)
	var now := Time.get_unix_time_from_system()
	var depleted := float(_node_depleted.get(node_id, 0.0)) > now
	var err := PL.gather_check(node, p["prof"], p["pos"], depleted)
	if err != "":
		_notify(peer, err)
		return
	var got := PL.gather(node, p["prof"], p["inv"])
	_node_depleted[node_id] = now + PL.NODE_RESPAWN
	_notify(peer, "Добыто: %s x%d" % [GameData.ITEMS[node["item"]]["name"], got])
	_send_self(p)


## Крафт по рецепту. Мастерская не нужна: рецепты доступны из любого места.
func on_craft(peer: int, recipe_id: String) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	var recipe := PL.recipe_by_id(recipe_id)
	var err := PL.craft(recipe, p["prof"], p["inv"])
	if err != "":
		_notify(peer, err)
		return
	_notify(peer, "Создано: %s" % GameData.ITEMS[recipe["output"][0]]["name"])
	_send_self(p)


## Снять экипировку (оружие или броню) в инвентарь.
func on_unequip(peer: int, slot: String) -> void:
	var p = players.get(peer)
	if p == null:
		return
	if GameData.unequip(p, slot):
		_hydrate(p)
		_notify(peer, "Снято")
		_send_self(p)


## Разговор с NPC квестов: продвигает все цепочки, ожидающие разговора с ним.
## Повышение класса у наставника: проверки, списание золота, смена класса, сохранение.
func on_promote(peer: int) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	if not _near_npc(p, GameData.PROMOTE_POS, GameData.PROMOTE_RANGE):
		_notify(peer, "Подойдите к Наставнику")
		return
	var cls := String(p["cls"])
	if not GameData.PROMOTE_TO.has(cls):
		_notify(peer, "Ваш класс уже повышен или не может быть повышен")
		return
	if int(p["lvl"]) < GameData.PROMOTE_LEVEL:
		_notify(peer, "Повышение доступно с уровня %d" % GameData.PROMOTE_LEVEL)
		return
	if int(p["gold"]) < GameData.PROMOTE_COST:
		_notify(peer, "Нужно золота: %d" % GameData.PROMOTE_COST)
		return
	p["gold"] = int(p["gold"]) - GameData.PROMOTE_COST
	p["cls"] = GameData.PROMOTE_TO[cls]
	_hydrate(p)
	p["hp"] = mini(int(p["hp"]), int(p["maxhp"]))
	_save(p)
	_notify(peer, "Вы стали: %s" % GameData.CLASSES_T2[p["cls"]]["name"])
	_send_self(p)


# ---------------- улучшение (refine) ----------------

## Улучшение надетого оружия или брони.
## Шанс берётся из rAthena refine_db.yml; при неудаче уровень сбрасывается на 0.
func on_refine(peer: int, slot: String) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	if not _near_npc(p, GameData.REFINE_POS, GameData.REFINE_RANGE):
		_notify(peer, "Подойдите к кузнецу")
		return
	if slot != "eq_weapon" and slot != "eq_armor":
		return
	var item_id := String(p.get(slot, ""))
	if item_id == "":
		_notify(peer, "Нечего улучшать")
		return
	var lvl_key := "refine_weapon" if slot == "eq_weapon" else "refine_armor"
	var cur := int(p.get(lvl_key, 0))
	if cur >= GameData.REFINE_MAX:
		_notify(peer, "Достигнут максимум улучшения")
		return
	var chance := GameData.refine_chance(item_id, cur)
	if chance <= 0:
		_notify(peer, "Этот предмет нельзя улучшить")
		return
	if int(p["gold"]) < GameData.REFINE_COST:
		_notify(peer, "Нужно золота: %d" % GameData.REFINE_COST)
		return
	if int(p["inv"].get(GameData.REFINE_MATERIAL, 0)) < GameData.REFINE_MATERIAL_COUNT:
		_notify(peer, "Нужен материал: %s" % GameData.ITEMS[GameData.REFINE_MATERIAL]["name"])
		return

	p["gold"] = int(p["gold"]) - GameData.REFINE_COST
	p["inv"][GameData.REFINE_MATERIAL] = int(p["inv"][GameData.REFINE_MATERIAL]) - GameData.REFINE_MATERIAL_COUNT
	if int(p["inv"][GameData.REFINE_MATERIAL]) <= 0:
		p["inv"].erase(GameData.REFINE_MATERIAL)

	var roll := _rng.randi_range(1, 100)
	if roll <= chance:
		p[lvl_key] = cur + 1
		_hydrate(p)
		p["hp"] = mini(int(p["hp"]), int(p["maxhp"]))
		_notify(peer, "Улучшение удалось! +%d (шанс был %d%%)" % [int(p[lvl_key]), chance])
		_events.append({"m": _cur, "k": "refine_ok", "p": p["pos"], "t": "+%d" % int(p[lvl_key]), "id": p["peer"]})
	else:
		var was := cur
		p[lvl_key] = 0
		_hydrate(p)
		p["hp"] = mini(int(p["hp"]), int(p["maxhp"]))
		_notify(peer, "Улучшение провалилось. Уровень сброшен с +%d (шанс был %d%%)" % [was, chance])
		_events.append({"m": _cur, "k": "refine_fail", "p": p["pos"], "t": "сброс", "id": p["peer"]})
	_save(p)
	_send_self(p)


## Лекарь: полностью восстанавливает HP и MP. Бесплатно, как в rAthena npc/custom/healer.txt.
func on_heal(peer: int) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	if not _near_npc(p, GameData.HEALER_POS, GameData.REFINE_RANGE):
		_notify(peer, "Подойдите к лекарю")
		return
	if int(p["hp"]) >= int(p["maxhp"]) and int(p["mp"]) >= int(p["maxmp"]):
		_notify(peer, "Вы и так здоровы")
		return
	p["hp"] = int(p["maxhp"])
	p["mp"] = int(p["maxmp"])
	_notify(peer, "Лекарь восстановил HP и MP")
	_events.append({"m": _cur, "k": "heal", "p": p["pos"], "t": "+%d" % int(p["maxhp"]), "id": p["peer"]})
	_send_self(p)


func on_talk_npc(peer: int, npc: String) -> void:
	var p = players.get(peer)
	if p == null or _is_dead(p):
		return
	if npc != "quest":
		return
	if not _near_npc(p, GameData.NPC_QUEST_POS, TALK_RANGE):
		_notify(peer, "Подойдите к Старейшине")
		return
	var moved := false
	var need := ""
	for ch in GameData.CHAINS:
		var st := _chain_state(p, ch["id"])
		if QL.on_talk(ch, st, npc, int(p["lvl"]), p["inv"]):
			moved = true
			if QL.is_complete(ch, st):
				_notify(peer, "Цепочка готова к сдаче: %s" % ch["title"])
		elif need == "" and not bool(st.get("claimed", false)):
			var step := QL.current_step(ch, st)
			if not step.is_empty() and step.get("npc", "") == npc and step["type"] == "collect":
				var nm := String(GameData.ITEMS.get(String(step["item"]), {}).get("name", step["item"]))
				need = "Принесите: %s x%d" % [nm, int(step["count"])]
			elif not step.is_empty() and step.get("npc", "") == npc and step["type"] == "collect_any":
				var names := PackedStringArray()
				for it in step["items"]:
					names.append(String(GameData.ITEMS.get(String(it), {}).get("name", it)))
				need = "Принесите один из предметов: %s" % ", ".join(names)
	if not moved:
		_notify(peer, need if need != "" else "Сейчас с Старейшиной не о чем говорить")
		return
	_send_self(p)


## Сдача завершённой цепочки: награда выдаётся один раз.
func on_chain_claim(peer: int, chain_id: String) -> void:
	var p = players.get(peer)
	if p == null:
		return
	var ch := _chain_def(chain_id)
	if ch.is_empty():
		return
	if not _near_npc(p, GameData.NPC_QUEST_POS, TALK_RANGE):
		_notify(peer, "Подойдите к Старейшине")
		return
	var st := _chain_state(p, chain_id)
	if not QL.claim(ch, st, int(p["lvl"])):
		_notify(peer, "Цепочка не готова к сдаче")
		return
	var rw: Dictionary = ch["reward"]
	p["gold"] += int(rw.get("gold", 0))
	for pair in rw.get("items", []):
		p["inv"][pair[0]] = int(p["inv"].get(pair[0], 0)) + int(pair[1])
	_gain_xp(p, int(rw.get("xp", 0)))
	_notify(peer, "Награда получена: %s" % ch["title"])
	_send_self(p)


func _chain_def(chain_id: String) -> Dictionary:
	for ch in GameData.CHAINS:
		if ch["id"] == chain_id:
			return ch
	return {}


func on_quest_claim(peer: int, quest_id: String) -> void:
	var p = players.get(peer)
	if p == null:
		return
	var q := _quest_def(quest_id)
	if q.is_empty():
		return
	if not _near_npc(p, GameData.NPC_QUEST_POS, TALK_RANGE):
		_notify(peer, "Подойдите к Старейшине")
		return
	var st: Dictionary = p["quests"].get(quest_id, {"count": 0, "done": false})
	if st["done"] or int(st["count"]) < int(q["count"]):
		_notify(peer, "Задание ещё не выполнено")
		return
	st["done"] = true
	p["quests"][quest_id] = st
	p["gold"] += int(q["gold"])
	_gain_xp(p, int(q["xp"]))
	_notify(peer, "Задание выполнено: %s" % q["title"])
	_send_self(p)


func on_chat(peer: int, text: String) -> void:
	var p = players.get(peer)
	if p == null:
		return
	var msg := text.strip_edges().left(120)
	if msg.is_empty():
		return
	for pid in players:
		Net.send_to(pid, "s_chat", [p["name"], msg])
# ---------------- бой ----------------

func _cast_damage(attacker: Dictionary, skill_id: String, m: Dictionary) -> void:
	var s: Dictionary = GameData.SKILLS[skill_id]
	var roll := _rng.randf_range(0.9, 1.12)
	var raw := float(attacker["atk"]) * float(s["power"]) * roll
	var crit := _rng.randf() < 0.08
	if crit:
		raw *= 1.7
	var dmg := maxi(1, int(raw) - int(GameData.MOBS[m["type"]]["level"]))
	m["hp"] -= dmg
	m["aggro_peer"] = attacker["peer"]
	_events.append({"m": _cur, "k": "crit" if crit else "dmg", "p": m["pos"], "t": str(dmg), "id": m["id"]})
	if m["hp"] <= 0:
		_kill_mob(m, attacker)


func _kill_mob(m: Dictionary, killer: Dictionary) -> void:
	m["dead"] = true
	m["hp"] = 0
	m["respawn_at"] = Time.get_ticks_msec() / 1000.0 + float(GameData.MOBS[m["type"]]["respawn"])
	var def: Dictionary = GameData.MOBS[m["type"]]
	killer["gold"] += int(def["gold"])
	_gain_xp(killer, int(def["xp"]))
	var drop := GameData.pick_loot(m["type"], _rng.randf())
	if drop != "":
		killer["inv"][drop] = int(killer["inv"].get(drop, 0)) + 1
		_notify(killer["peer"], "Найдено: %s" % GameData.ITEMS[drop]["name"])
	_progress_quests(killer, m["type"])
	_events.append({"m": _cur, "k": "death", "p": m["pos"], "t": def["name"], "id": m["id"]})
	_send_self(killer)


func _chain_state(p: Dictionary, chain_id: String) -> Dictionary:
	if typeof(p["chains"].get(chain_id)) != TYPE_DICTIONARY:
		p["chains"][chain_id] = QL.new_state()
	return p["chains"][chain_id]


func _progress_chains_kill(p: Dictionary, mob_type: String) -> void:
	for ch in GameData.CHAINS:
		var st := _chain_state(p, ch["id"])
		if QL.on_kill(ch, st, mob_type) and QL.is_complete(ch, st):
			_notify(p["peer"], "Цепочка готова к сдаче: %s" % ch["title"])


func _progress_quests(p: Dictionary, mob_type: String) -> void:
	_progress_chains_kill(p, mob_type)
	for q in GameData.QUESTS:
		if q["type"] != "kill" or q["target"] != mob_type:
			continue
		var st: Dictionary = p["quests"].get(q["id"], {"count": 0, "done": false})
		if st["done"]:
			continue
		st["count"] = mini(int(q["count"]), int(st["count"]) + 1)
		p["quests"][q["id"]] = st
		if st["count"] == q["count"]:
			_notify(p["peer"], "Задание готово: %s" % q["title"])


func _gain_xp(p: Dictionary, amount: int) -> void:
	p["xp"] += amount
	while p["xp"] >= GameData.xp_for_level(int(p["lvl"])):
		p["xp"] -= GameData.xp_for_level(int(p["lvl"]))
		p["lvl"] += 1
		var hp_before: int = p["maxhp"]
		_hydrate(p)
		p["hp"] += p["maxhp"] - hp_before
		_notify(p["peer"], "Уровень %d!" % p["lvl"])


func _quest_def(id: String) -> Dictionary:
	for q in GameData.QUESTS:
		if q["id"] == id:
			return q
	return {}


# ---------------- симуляция ----------------

func _simulate(dt: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for pid in players:
		var p: Dictionary = players[pid]
		if _is_dead(p):
			if now >= float(p["dead_until"]):
				_respawn(p)
			continue
		if p["moving"]:
			_walk(p, dt)
		_check_portal(p)
		_regen(p, dt, now)
	for m in mobs:
		_tick_mob(m, dt, now)


## Восстановление HP и MP вне боя. В бою (недавно получен удар) не восстанавливается.
const COMBAT_CALM := 5.0     # сек без урона, после которых начинается восстановление
const REGEN_HP_PER_SEC := 6.0
const REGEN_MP_PER_SEC := 4.0

func _regen(p: Dictionary, dt: float, now: float) -> void:
	if float(p.get("last_hit", -100.0)) + COMBAT_CALM > now:
		return
	if int(p["hp"]) < int(p["maxhp"]):
		p["regen_hp"] = float(p.get("regen_hp", 0.0)) + REGEN_HP_PER_SEC * dt
		var whole := int(p["regen_hp"])
		if whole > 0:
			p["regen_hp"] -= whole
			p["hp"] = mini(int(p["maxhp"]), int(p["hp"]) + whole)
	if int(p["mp"]) < int(p["maxmp"]):
		p["regen_mp"] = float(p.get("regen_mp", 0.0)) + REGEN_MP_PER_SEC * dt
		var mwhole := int(p["regen_mp"])
		if mwhole > 0:
			p["regen_mp"] -= mwhole
			p["mp"] = mini(int(p["maxmp"]), int(p["mp"]) + mwhole)


func _route(from: Vector2, goal: Vector2, mp: String = "") -> Array:
	_activate(mp if mp != "" else _cur)
	var a := Vector2i(int(from.x) / GameData.TILE, int(from.y) / GameData.TILE)
	var b := Vector2i(int(goal.x) / GameData.TILE, int(goal.y) / GameData.TILE)
	if a == b:
		return [goal]
	var blocked := func(t: Vector2i) -> bool:
		return GameData.BLOCKING.get(GameData.tile_at(t.x, t.y), false)
	var tiles: Array = PF.find(GameData.MAP_W, GameData.MAP_H, blocked, a, b)
	if tiles.is_empty():
		return []
	var pts: Array = []
	for t in tiles:
		pts.append(Vector2(t.x * GameData.TILE + GameData.TILE / 2, t.y * GameData.TILE + GameData.TILE / 2))
	pts[pts.size() - 1] = goal
	return pts


func _walk(p: Dictionary, dt: float) -> void:
	_activate(_pmap(p))
	var path: Array = p["path"]
	if path.is_empty():
		p["moving"] = false
		return
	var wp: Vector2 = path[0]
	var to: Vector2 = wp - p["pos"]
	var step := float(p["speed"]) * dt
	if to.length() <= step:
		p["pos"] = wp
		path.pop_front()
		if path.is_empty():
			p["moving"] = false
		return
	var before: Vector2 = p["pos"]
	p["pos"] = GameData.move_with_collision(before, to.normalized() * step)
	if p["pos"].distance_to(before) < 0.01:
		p["path"] = []
		p["moving"] = false


func _tick_mob(m: Dictionary, dt: float, now: float) -> void:
	_activate(String(m.get("map", GameData.DEFAULT_MAP)))
	var def: Dictionary = GameData.MOBS[m["type"]]
	if m["dead"]:
		if now >= float(m["respawn_at"]):
			m["dead"] = false
			m["hp"] = m["maxhp"]
			m["pos"] = m["home"]
		return
	m["cd"] = maxf(0.0, float(m["cd"]) - dt)
	var target: Dictionary = {}
	var best := float(def["aggro"])
	for pid in players:
		var p: Dictionary = players[pid]
		if _is_dead(p) or _pmap(p) != String(m.get("map", GameData.DEFAULT_MAP)):
			continue
		var d: float = p["pos"].distance_to(m["pos"])
		if d < best:
			best = d
			target = p
	if target.is_empty():
		if m["pos"].distance_to(m["home"]) > 12.0:
			var back: Vector2 = (m["home"] - m["pos"]).normalized() * float(def["speed"]) * dt
			m["pos"] = GameData.move_with_collision(m["pos"], back)
		return
	var dist: float = target["pos"].distance_to(m["pos"])
	if dist > float(def["attack_range"]):
		var step: Vector2 = (target["pos"] - m["pos"]).normalized() * float(def["speed"]) * dt
		m["pos"] = GameData.move_with_collision(m["pos"], step)
	elif float(m["cd"]) <= 0.0:
		m["cd"] = float(def["cooldown"])
		var dmg := maxi(1, int(def["atk"]) - int(target["def"]) / 2)
		target["hp"] -= dmg
		target["last_hit"] = now
		_events.append({"m": _cur, "k": "hurt", "p": target["pos"], "t": str(dmg), "id": target["peer"]})
		if target["hp"] <= 0:
			target["hp"] = 0
			target["dead_until"] = now + RESPAWN_PLAYER
			target["moving"] = false
			target["path"] = []
			_events.append({"m": _cur, "k": "pdeath", "p": target["pos"], "t": target["name"], "id": target["peer"]})
			_notify(target["peer"], "Вы погибли. Возрождение через %d с" % int(RESPAWN_PLAYER))
			target["deaths"] = int(target.get("deaths", 0)) + 1


func _respawn(p: Dictionary) -> void:
	p["hp"] = maxi(1, p["maxhp"] / 2)
	p["mp"] = p["maxmp"] / 2
	p["map"] = GameData.DEFAULT_MAP
	p["pos"] = GameData.SPAWN_POINT
	p["target"] = GameData.SPAWN_POINT
	p["path"] = []
	p["moving"] = false
	p["dead_until"] = 0.0
	_notify(p["peer"], "Вы возродились")


func _is_dead(p: Dictionary) -> bool:
	return float(p.get("dead_until", 0.0)) > 0.0 and Time.get_ticks_msec() / 1000.0 < float(p["dead_until"])


func _find_mob(id: int):
	for m in mobs:
		if m["id"] == id:
			return m
	return null


func _spawn_mob(type: String, pos: Vector2, mp: String = "") -> void:
	var def: Dictionary = GameData.MOBS[type]
	mobs.append({
		"id": _next_mob_id, "type": type, "pos": pos, "home": pos, "map": mp if mp != "" else GameData.DEFAULT_MAP,
		"hp": int(def["hp"]), "maxhp": int(def["hp"]),
		"dead": false, "cd": 0.0, "respawn_at": 0.0, "aggro_peer": 0,
	})
	_next_mob_id += 1


# ---------------- вещание ----------------

## Покупка за деньги. Выдача возможна ТОЛЬКО после проверки чека на стороне сервера
## через Google Play Developer API (purchases.products.get). Без проверки ничего не выдаётся:
## клиенту доверять нельзя, токен можно подделать.
func on_purchase(peer: int, product_id: String, purchase_token: String) -> void:
	var p = players.get(peer)
	if p == null:
		return
	var product := _store_product(product_id)
	if product.is_empty() or purchase_token.is_empty():
		Net.send_to(peer, "s_store_result", [false, "Товар не найден"])
		return
	if p["processed_tokens"].has(purchase_token):
		Net.send_to(peer, "s_store_result", [false, "Покупка уже получена"])
		return
	if not PlayVerifier.verify(product_id, purchase_token):
		Net.send_to(peer, "s_store_result", [false, "Покупка не подтверждена Google Play"])
		return
	p["processed_tokens"].append(purchase_token)
	_grant(p, product["grant"])
	_save(p)
	Net.send_to(peer, "s_store_result", [true, "Получено: %s" % product["title"]])
	_send_self(p)


func _store_product(product_id: String) -> Dictionary:
	for prod in GameData.STORE:
		if prod["id"] == product_id:
			return prod
	return {}


func _grant(p: Dictionary, grant: Dictionary) -> void:
	if grant.has("gold"):
		p["gold"] += int(grant["gold"])
	if grant.has("item"):
		var item_id: String = grant["item"]
		p["inv"][item_id] = int(p["inv"].get(item_id, 0)) + int(grant.get("count", 1))
	if grant.has("vip_days"):
		var now := Time.get_unix_time_from_system()
		var until := maxf(float(p.get("vip_until", 0.0)), now) + float(grant["vip_days"]) * 86400.0
		p["vip_until"] = until


func _self_data(p: Dictionary) -> Dictionary:
	return {
		"id": p["peer"], "name": p["name"], "cls": p["cls"], "lvl": p["lvl"],
		"xp": p["xp"], "need": GameData.xp_for_level(int(p["lvl"])),
		"gold": p["gold"], "hp": p["hp"], "maxhp": p["maxhp"],
		"mp": p["mp"], "maxmp": p["maxmp"], "atk": p["atk"], "def": p["def"],
		"inv": p["inv"], "quests": p["quests"], "skills": p["skills"],
		"eq_weapon": p.get("eq_weapon", ""), "eq_armor": p.get("eq_armor", ""),
		"chains": p["chains"], "prof": p["prof"], "map": _pmap(p),
	}


func _send_self(p: Dictionary) -> void:
	Net.send_to(p["peer"], "s_self", [_self_data(p)])
func _notify(peer: int, text: String) -> void:
	Net.send_to(peer, "s_notify", [text])
func _broadcast() -> void:
	var by_map := {}
	for pid in players:
		var mp := _pmap(players[pid])
		if not by_map.has(mp):
			by_map[mp] = {"players": [], "mobs": [], "events": [], "map": mp}
		var p: Dictionary = players[pid]
		by_map[mp]["players"].append({
			"id": p["peer"], "n": p["name"], "c": p["cls"], "l": p["lvl"],
			"p": p["pos"], "hp": p["hp"], "mhp": p["maxhp"], "d": _is_dead(p),
		})
	for m in mobs:
		if m["dead"]:
			continue
		var mm := String(m.get("map", GameData.DEFAULT_MAP))
		if by_map.has(mm):
			by_map[mm]["mobs"].append({"id": m["id"], "t": m["type"], "p": m["pos"], "hp": m["hp"], "mhp": m["maxhp"]})
	for ev in _events:
		var me := String(ev.get("m", ""))
		if by_map.has(me):
			by_map[me]["events"].append(ev)
	_events = []
	for pid in players:
		var mp2 := _pmap(players[pid])
		Net.send_to(pid, "s_snapshot", [by_map[mp2]])
		_send_self_hp(players[pid])


func _send_self_hp(p: Dictionary) -> void:
	pass
