extends Node2D
## Игровой вид: карта, игроки и мобы. Рисуется процедурно, без внешних ассетов.
## Карта строится тем же GameData, что и на сервере (фиксированный seed), поэтому совпадает.
## Позиции сглаживаются между снимками сервера (интерполяция).

const SMOOTH := 12.0  # скорость сглаживания позиции
const DMG_LIFE := 0.9  # сек, сколько живёт всплывающая цифра
const FLASH_LIFE := 0.18
const PARTICLE_LIFE := 0.7
const PICK_RADIUS := 40.0  # радиус выбора моба нажатием
const ATTACK_RANGE := 76.0  # чуть меньше серверной дальности (80), чтобы не получать «цель далеко»
const ATTACK_EVERY := 0.7  # сек между запросами удара (сервер сам держит кулдаун)
const REPATH_EVERY := 0.5  # сек между пересчётами пути к цели
const GDATA := preload("res://scripts/game_data.gd")
const TILE_PX := 64  # размер тайла на карте в пикселях (как GDATA.TILE)
const ZOOM := 1.6  # масштаб мира: карта крупнее, мобы и персонажи читаемы
const CAMERA_AT := Vector2(960, 360)  # где на экране держим игрока (правее панели входа)

var _map_cache: Image
var _map_tex: ImageTexture = null
var _map_name := ""   # текущая карта (имя rAthena) из последнего снимка
var map: Node = null  # источник карты; по умолчанию autoload GameData
var _players := {}  # id -> {"pos": Vector2, "target": Vector2, "phase": float, "moving": bool, "flash": float, "scale_t": float, ...}
var _mobs := {}     # id -> {"pos": Vector2, "target": Vector2, "type": String, "hp": int, "mhp": int, "flash": float, "scale_t": float}
var _popups: Array = []    # {"pos": Vector2, "text": String, "color": Color, "t": float}
var _particles: Array = []  # {"pos": Vector2, "vel": Vector2, "t": float, "color": Color}
var _time := 0.0
var _my_id := 1
var _selected := -1
var _atk_t := 0.0
var _repath_t := 0.0
var _halted := false
var _touch_handled := false

# Спрайты Kenney (CC0), растянутые до размера тайла. Пустой массив — процедурный резерв.
var _kenney_grass: Array[Image] = []
var _kenney_stone: Array[Image] = []
# Спрайты персонажей и слизней (Kenney CC0): ключ -> Texture2D, обрезанный по прозрачной области.
var _sprite_cache := {}
const SPRITE_FILES := {
	"hero_sword_0": "res://assets/sprites_v3/heroes/swordsman_down.png",
	"hero_sword_1": "res://assets/sprites_v3/heroes/swordsman_left.png",
	"hero_sword_2": "res://assets/sprites_v3/heroes/swordsman_down.png",
	"hero_sword_3": "res://assets/sprites_v3/heroes/swordsman_right.png",
	"hero_sword_attack": "res://assets/sprites_v3/heroes/swordsman_down.png",
	"hero_mage_0": "res://assets/sprites_v3/heroes/mage_down.png",
	"hero_mage_1": "res://assets/sprites_v3/heroes/mage_left.png",
	"hero_mage_2": "res://assets/sprites_v3/heroes/mage_down.png",
	"hero_mage_3": "res://assets/sprites_v3/heroes/mage_right.png",
	"hero_mage_attack": "res://assets/sprites_v3/heroes/mage_down.png",
	"hero_archer_0": "res://assets/sprites_v3/heroes/archer_down.png",
	"hero_archer_1": "res://assets/sprites_v3/heroes/archer_left.png",
	"hero_archer_2": "res://assets/sprites_v3/heroes/archer_down.png",
	"hero_archer_3": "res://assets/sprites_v3/heroes/archer_right.png",
	"hero_archer_attack": "res://assets/sprites_v3/heroes/archer_down.png",
	"hero_paladin_0": "res://assets/sprites_v3/heroes/paladin_down.png",
	"hero_paladin_1": "res://assets/sprites_v3/heroes/paladin_left.png",
	"hero_paladin_2": "res://assets/sprites_v3/heroes/paladin_down.png",
	"hero_paladin_3": "res://assets/sprites_v3/heroes/paladin_right.png",
	"hero_paladin_attack": "res://assets/sprites_v3/heroes/paladin_down.png",
	"hero_high_mage_0": "res://assets/sprites_v3/heroes/archmage_down.png",
	"hero_high_mage_1": "res://assets/sprites_v3/heroes/archmage_left.png",
	"hero_high_mage_2": "res://assets/sprites_v3/heroes/archmage_down.png",
	"hero_high_mage_3": "res://assets/sprites_v3/heroes/archmage_right.png",
	"hero_high_mage_attack": "res://assets/sprites_v3/heroes/archmage_down.png",
	"hero_ranger_0": "res://assets/sprites_v3/heroes/scout_down.png",
	"hero_ranger_1": "res://assets/sprites_v3/heroes/scout_left.png",
	"hero_ranger_2": "res://assets/sprites_v3/heroes/scout_down.png",
	"hero_ranger_3": "res://assets/sprites_v3/heroes/scout_right.png",
	"hero_ranger_attack": "res://assets/sprites_v3/heroes/scout_down.png",
	"mob_slime_0": "res://assets/sprites_v3/monsters/slime_red_idle1.png",
	"mob_slime_1": "res://assets/sprites_v3/monsters/slime_red_idle2.png",
	"mob_slime_2": "res://assets/sprites_v3/monsters/slime_red_attack.png",
	"mob_slime_3": "res://assets/sprites_v3/monsters/slime_red_idle1.png",
	"mob_wolf_0": "res://assets/sprites_v3/monsters/wolf_idle1.png",
	"mob_wolf_1": "res://assets/sprites_v3/monsters/wolf_idle2.png",
	"mob_wolf_2": "res://assets/sprites_v3/monsters/wolf_attack.png",
	"mob_wolf_3": "res://assets/sprites_v3/monsters/wolf_idle1.png",
	"mob_golem_0": "res://assets/sprites_v3/monsters/skeleton_idle1.png",
	"mob_golem_1": "res://assets/sprites_v3/monsters/skeleton_idle2.png",
	"mob_golem_2": "res://assets/sprites_v3/monsters/skeleton_attack.png",
	"mob_golem_3": "res://assets/sprites_v3/monsters/skeleton_idle1.png",
	"mob_boss_0": "res://assets/sprites_v3/monsters/dragon_idle1.png",
	"mob_boss_1": "res://assets/sprites_v3/monsters/dragon_idle2.png",
	"mob_boss_2": "res://assets/sprites_v3/monsters/dragon_attack.png",
	"mob_boss_3": "res://assets/sprites_v3/monsters/dragon_idle1.png",
	"mob_marin_0": "res://assets/sprites_v3/monsters/slime_blue_idle1.png",
	"mob_marin_1": "res://assets/sprites_v3/monsters/slime_blue_idle2.png",
	"mob_marin_2": "res://assets/sprites_v3/monsters/slime_blue_attack.png",
	"mob_marin_3": "res://assets/sprites_v3/monsters/slime_blue_idle1.png",
	"mob_poporing_0": "res://assets/sprites_v3/monsters/slime_green_idle1.png",
	"mob_poporing_1": "res://assets/sprites_v3/monsters/slime_green_idle2.png",
	"mob_poporing_2": "res://assets/sprites_v3/monsters/slime_green_attack.png",
	"mob_poporing_3": "res://assets/sprites_v3/monsters/slime_green_idle1.png",
	"mob_zombie_0": "res://assets/sprites_v3/monsters/skeleton_idle1.png",
	"mob_zombie_1": "res://assets/sprites_v3/monsters/skeleton_idle2.png",
	"mob_zombie_2": "res://assets/sprites_v3/monsters/skeleton_attack.png",
	"mob_zombie_3": "res://assets/sprites_v3/monsters/skeleton_idle1.png",
	"mob_orc_0": "res://assets/sprites_v3/monsters/orc_idle1.png",
	"mob_orc_1": "res://assets/sprites_v3/monsters/orc_idle2.png",
	"mob_orc_2": "res://assets/sprites_v3/monsters/orc_attack.png",
	"mob_orc_3": "res://assets/sprites_v3/monsters/orc_idle1.png",
}
const HERO_H := 58.0   # высота персонажа на экране (в мировых пикселях)
const SLIME_W := 44.0  # ширина слизня на экране

func _sprite(key: String) -> Texture2D:
	if _sprite_cache.has(key):
		return _sprite_cache[key]
	var tex: Texture2D = null
	var path: String = SPRITE_FILES.get(key, "")
	# PNG читаем байтами: не зависим от файлов импорта Godot и одинаково работает в APK.
	if path != "" and FileAccess.file_exists(path):
		var img := Image.new()
		if img.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			img.convert(Image.FORMAT_RGBA8)
			var bb := img.get_used_rect()
			if bb.size.x > 0 and bb.size.y > 0:
				tex = ImageTexture.create_from_image(img.get_region(bb))
	_sprite_cache[key] = tex
	return tex

signal move_requested(pos: Vector2)
signal attack_requested(mob_id: int)


func _ready() -> void:
	scale = Vector2(ZOOM, ZOOM)
	ensure_map()


func _process(delta: float) -> void:
	_time += delta
	for id in _players:
		var pl: Dictionary = _players[id]
		pl["pos"] = pl["pos"].lerp(pl["target"], minf(1.0, SMOOTH * delta))
		pl["moving"] = pl["pos"].distance_to(pl["target"]) > 1.5
		pl["flash"] = maxf(0.0, float(pl["flash"]) - delta)
		pl["scale_t"] = maxf(0.0, float(pl["scale_t"]) - delta)
	for id in _mobs:
		var mb: Dictionary = _mobs[id]
		mb["pos"] = mb["pos"].lerp(mb["target"], minf(1.0, SMOOTH * delta))
		mb["flash"] = maxf(0.0, float(mb["flash"]) - delta)
		mb["scale_t"] = maxf(0.0, float(mb["scale_t"]) - delta)
	for i in range(_popups.size() - 1, -1, -1):
		_popups[i]["t"] += delta
		if _popups[i]["t"] > DMG_LIFE:
			_popups.remove_at(i)
	for i in range(_particles.size() - 1, -1, -1):
		var pt: Dictionary = _particles[i]
		pt["t"] += delta
		pt["pos"] += pt["vel"] * delta
		pt["vel"] *= 0.92
		if pt["t"] > PARTICLE_LIFE:
			_particles.remove_at(i)
	_update_selection(delta)
	queue_redraw()


# ---------------- управление ----------------

func _unhandled_input(event: InputEvent) -> void:
	# Касание телефона: обрабатываем напрямую и помечаем, что касание уже учтено.
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_handled = true
			_on_tap(_screen_to_world(event.position))
			get_viewport().set_input_as_handled()
		return
	# Мышь. Эмулированный из касания клик пропускаем, чтобы одно касание не
	# срабатывало дважды.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _touch_handled:
			_touch_handled = false
			return
		_on_tap(get_local_mouse_position())
		get_viewport().set_input_as_handled()


func _screen_to_world(screen: Vector2) -> Vector2:
	return (screen - position) / ZOOM


func _on_tap(world: Vector2) -> void:
	if not _players.has(_my_id) or bool(_players[_my_id]["dead"]):
		return
	var mid := _mob_at(world)
	_halted = false
	if mid != -1:
		_selected = mid
		_atk_t = 0.0
		_repath_t = 0.0
		move_requested.emit(_mobs[mid]["target"])
	else:
		_selected = -1
		move_requested.emit(world)


func _mob_at(world: Vector2) -> int:
	var best := -1
	var best_d := PICK_RADIUS
	for id in _mobs:
		var d: float = _mobs[id]["target"].distance_to(world)
		if d <= best_d:
			best_d = d
			best = id
	return best


func _update_selection(delta: float) -> void:
	if _selected == -1:
		return
	if not _mobs.has(_selected) or not _players.has(_my_id) or bool(_players[_my_id]["dead"]):
		_selected = -1
		return
	var me: Vector2 = _players[_my_id]["pos"]
	var foe: Vector2 = _mobs[_selected]["target"]
	if me.distance_to(foe) <= ATTACK_RANGE:
		if not _halted:
			_halted = true
			move_requested.emit(me)
		_atk_t -= delta
		if _atk_t <= 0.0:
			_atk_t = ATTACK_EVERY
			attack_requested.emit(_selected)
	else:
		_halted = false
		_repath_t -= delta
		if _repath_t <= 0.0:
			_repath_t = REPATH_EVERY
			move_requested.emit(foe)


# ---------------- данные с сервера ----------------

## Принять снимок сервера: обновить цели позиций, добавить новых, убрать пропавших.
func apply_snapshot(snap: Dictionary, my_id: int) -> void:
	_my_id = my_id
	var mn := String(snap.get("map", ""))
	if mn != _map_name:
		_map_name = mn
		_map_cache = null
		_map_tex = null
		_mobs.clear()
	var seen := {}
	var camera_target := Vector2.ZERO
	var have_target := false
	for p in snap.get("players", []):
		var id: int = int(p["id"])
		seen[id] = true
		var target: Vector2 = p["p"]
		if not _players.has(id):
			_players[id] = {"pos": target, "target": target, "phase": randf() * TAU,
				"moving": false, "flash": 0.0, "scale_t": 0.0, "cls": p.get("c", "sword"),
				"name": p.get("n", ""), "hp": int(p.get("hp", 0)), "mhp": int(p.get("mhp", 1)),
				"dead": bool(p.get("d", false))}
		else:
			_players[id]["target"] = target
			_players[id]["hp"] = int(p.get("hp", 0))
			_players[id]["mhp"] = int(p.get("mhp", 1))
			_players[id]["dead"] = bool(p.get("d", false))
			_players[id]["cls"] = p.get("c", "sword")
			_players[id]["name"] = p.get("n", "")
	for id in _players.keys():
		if not seen.has(id):
			_players.erase(id)
	if _players.has(my_id):
		camera_target = _players[my_id]["target"]
		have_target = true
	if have_target:
		# камера: игрок в точке (CAMERA_AT), карта сдвигается
		position = CAMERA_AT - camera_target * ZOOM
	var mseen := {}
	for m in snap.get("mobs", []):
		var mid: int = int(m["id"])
		mseen[mid] = true
		var tgt: Vector2 = m["p"]
		if not _mobs.has(mid):
			_mobs[mid] = {"pos": tgt, "target": tgt, "type": String(m["t"]),
				"hp": int(m["hp"]), "mhp": int(m["mhp"]), "flash": 0.0, "scale_t": 0.0}
		else:
			_mobs[mid]["target"] = tgt
			_mobs[mid]["hp"] = int(m["hp"])
			_mobs[mid]["mhp"] = int(m["mhp"])
	for mid in _mobs.keys():
		if not mseen.has(mid):
			_mobs.erase(mid)
	for ev in snap.get("events", []):
		_on_event(ev, my_id)


func _on_event(ev: Dictionary, my_id: int) -> void:
	var k: String = String(ev.get("k", ""))
	var at: Vector2 = ev.get("p", Vector2.ZERO)
	var txt: String = String(ev.get("t", ""))
	match k:
		"dmg", "crit":
			var col := Color(1.0, 0.85, 0.2) if k == "crit" else Color(1, 1, 1)
			_popups.append({"pos": at, "text": txt, "color": col, "t": 0.0})
			_flash_mob(int(ev.get("id", -1)))
			_spawn_particles(at, Color(1, 0.6, 0.2), 4)
		"heal":
			_popups.append({"pos": at, "text": txt, "color": Color(0.4, 1.0, 0.5), "t": 0.0})
		"hurt", "pdeath":
			_popups.append({"pos": at, "text": txt if k == "hurt" else "погиб", "color": Color(1, 0.3, 0.3), "t": 0.0})
			_flash_player(int(ev.get("id", -1)))
		"death":
			_spawn_particles(at, Color(0.7, 0.9, 0.5), 14)
			_popups.append({"pos": at + Vector2(0, -24), "text": txt, "color": Color(0.8, 0.8, 0.8), "t": 0.0})


func _flash_mob(id: int) -> void:
	if _mobs.has(id):
		_mobs[id]["flash"] = FLASH_LIFE
		_mobs[id]["scale_t"] = FLASH_LIFE


func _flash_player(id: int) -> void:
	if _players.has(id):
		_players[id]["flash"] = FLASH_LIFE
		_players[id]["scale_t"] = FLASH_LIFE


func _spawn_particles(at: Vector2, col: Color, n: int) -> void:
	for i in n:
		var ang := randf() * TAU
		var spd := 40.0 + randf() * 90.0
		_particles.append({"pos": at, "vel": Vector2(cos(ang), sin(ang)) * spd, "t": 0.0, "color": col})


# ---------------- карта ----------------

## Построить кэш карты один раз. Безопасно вызывать многократно.
func _load_kenney() -> void:
	if not _kenney_grass.is_empty():
		return
	for i in 4:
		var g := _load_tile_image("res://assets/kenney/grass_%d.png" % i)
		if g != null:
			_kenney_grass.append(g)
		var st := _load_tile_image("res://assets/kenney/stone_%d.png" % i)
		if st != null:
			_kenney_stone.append(st)


func _load_tile_image(path: String) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(TILE_PX, TILE_PX, Image.INTERPOLATE_NEAREST)
	return img


func ensure_map() -> void:
	if _map_cache != null:
		return
	_load_kenney()
	var m: Node = map if map != null else get_node_or_null("/root/GameData")
	if m != null and m == get_node_or_null("/root/GameData"):
		m.activate_map(_map_name if _map_name != "" else m.DEFAULT_MAP)
	if m == null:
		push_error("world_view: нет источника карты")
		return
	# карта строится в _ready источника; если он ещё не готов, строим явно
	if m.get("_tiles") != null and (m.get("_tiles") as PackedByteArray).size() == 0:
		m._build_map()
	var tile: int = int(m.TILE)
	var img := Image.create(int(m.MAP_W) * tile, int(m.MAP_H) * tile, false, Image.FORMAT_RGBA8)
	for y in int(m.MAP_H):
		for x in int(m.MAP_W):
			_paint_tile(img, x * tile, y * tile, int(m.tile_at(x, y)), x, y, m)
	_map_cache = img


func _paint_tile(img: Image, ox: int, oy: int, t: int, x: int, y: int, m: Node) -> void:
	var tile: int = int(m.TILE)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = x * 92821 + y * 68917 + 7
	var is_obj: bool = t == int(m.T_TREE) or t == int(m.T_ROCK)
	var ground_t: int = int(m.T_GRASS) if is_obj else t
	var base := _tile_color(ground_t, m)
	# Настоящие спрайты Kenney для травы и камня, если они загружены.
	if not is_obj and t == int(m.T_STONE) and not _kenney_stone.is_empty():
		img.blit_rect(_kenney_stone[rnd.randi() % _kenney_stone.size()], Rect2i(0, 0, tile, tile), Vector2i(ox, oy))
		return
	if (t == int(m.T_GRASS) or t == int(m.T_GRASS2) or is_obj) and not _kenney_grass.is_empty():
		img.blit_rect(_kenney_grass[rnd.randi() % _kenney_grass.size()], Rect2i(0, 0, tile, tile), Vector2i(ox, oy))
		if is_obj:
			_paint_object_over(img, ox, oy, tile, t, base, rnd, m)
		return
	var shade := rnd.randf_range(-0.02, 0.02)
	var col := Color(clampf(base.r + shade, 0.0, 1.0), clampf(base.g + shade, 0.0, 1.0), clampf(base.b + shade, 0.0, 1.0))
	img.fill_rect(Rect2i(ox, oy, tile, tile), col)
	if t == int(m.T_WATER):
		var wave := col.lightened(0.28)
		for i in 3:
			img.fill_rect(Rect2i(ox + rnd.randi_range(4, tile - 22), oy + rnd.randi_range(10, tile - 10), 14, 2), wave)
	elif t == int(m.T_TREE):
		_draw_tree(img, ox, oy, tile, col, rnd)
	elif t == int(m.T_ROCK):
		_draw_rock(img, ox, oy, tile, col, rnd)
	elif t == int(m.T_SAND) or t == int(m.T_STONE):
		for i in 10:
			img.set_pixel(ox + rnd.randi_range(0, tile - 1), oy + rnd.randi_range(0, tile - 1), col.darkened(0.14))
	else:
		_draw_grass(img, ox, oy, tile, col, rnd)


func _paint_object_over(img: Image, ox: int, oy: int, tile: int, t: int, base: Color, rnd: RandomNumberGenerator, m: Node) -> void:
	var col := base
	if t == int(m.T_TREE):
		_draw_tree(img, ox, oy, tile, col, rnd)
	elif t == int(m.T_ROCK):
		_draw_rock(img, ox, oy, tile, col, rnd)


func _draw_grass(img: Image, ox: int, oy: int, tile: int, col: Color, rnd: RandomNumberGenerator) -> void:
	var dark := col.darkened(0.14)
	var light := col.lightened(0.16)
	for i in 7:
		var gx := ox + rnd.randi_range(2, tile - 4)
		var gy := oy + rnd.randi_range(6, tile - 2)
		img.fill_rect(Rect2i(gx, gy, 2, 4), dark)
		img.fill_rect(Rect2i(gx + 2, gy - 2, 1, 3), light)
	if rnd.randf() < 0.2:
		var flowers := [Color(1.0, 0.95, 0.6), Color(1.0, 0.7, 0.8), Color(0.95, 0.95, 1.0)]
		_fill_circle(img, ox + rnd.randi_range(8, tile - 8), oy + rnd.randi_range(8, tile - 8), 2, flowers[rnd.randi() % flowers.size()])


# ---- спрайты окружения (env) вместо процедурной отрисовки ----
var _env_cache := {}

func _load_env_sprite(name: String, h: int) -> Image:
	var key := "%s_%d" % [name, h]
	if _env_cache.has(key):
		return _env_cache[key]
	var out: Image = null
	var path := "res://assets/sprites_v3/env/%s.png" % name
	if FileAccess.file_exists(path):
		var src := Image.new()
		if src.load_png_from_buffer(FileAccess.get_file_as_bytes(path)) == OK:
			src.convert(Image.FORMAT_RGBA8)
			var w := maxi(1, int(round(float(src.get_width()) * h / float(src.get_height()))))
			src.resize(w, h, Image.INTERPOLATE_NEAREST)
			out = src
	_env_cache[key] = out
	return out

func _blit_env(img: Image, name: String, ox: int, oy: int, tile: int, factor: float) -> bool:
	if img.get_format() != Image.FORMAT_RGBA8:
		return false
	var h := int(round(tile * factor))
	var spr := _load_env_sprite(name, h)
	if spr == null:
		return false
	var cx := ox + (tile - spr.get_width()) / 2
	var cy := oy + tile - h
	img.blend_rect(spr, Rect2i(0, 0, spr.get_width(), spr.get_height()), Vector2i(cx, cy))
	return true

func _draw_tree(img: Image, ox: int, oy: int, tile: int, col: Color, rnd: RandomNumberGenerator) -> void:
	if _blit_env(img, "tree", ox, oy, tile, 1.5):
		return
	var cx := ox + tile / 2
	_fill_circle(img, cx + 4, oy + 52, 15, col.darkened(0.28))
	img.fill_rect(Rect2i(cx - 3, oy + 36, 7, 18), Color(0.36, 0.24, 0.13))
	var leaf := Color(0.16, 0.46, 0.2) if rnd.randf() < 0.5 else Color(0.2, 0.52, 0.22)
	_fill_circle(img, cx, oy + 26, 21, leaf.darkened(0.25))
	_fill_circle(img, cx - 2, oy + 23, 17, leaf)
	_fill_circle(img, cx - 7, oy + 17, 5, leaf.lightened(0.3))


func _draw_rock(img: Image, ox: int, oy: int, tile: int, col: Color, rnd: RandomNumberGenerator) -> void:
	if _blit_env(img, "stone", ox, oy, tile, 0.9):
		return
	var cx := ox + tile / 2
	_fill_circle(img, cx + 3, oy + 46, 17, col.darkened(0.3))
	_fill_circle(img, cx, oy + 38, 17, Color(0.5, 0.5, 0.54))
	_fill_circle(img, cx - 5, oy + 33, 6, Color(0.66, 0.66, 0.7))


func _tile_color(t: int, m: Node) -> Color:
	if t == int(m.T_GRASS):
		return Color(0.36, 0.62, 0.30)
	if t == int(m.T_GRASS2):
		return Color(0.33, 0.58, 0.28)
	if t == int(m.T_SAND):
		return Color(0.82, 0.75, 0.52)
	if t == int(m.T_STONE):
		return Color(0.55, 0.53, 0.50)
	if t == int(m.T_WATER):
		return Color(0.18, 0.42, 0.72)
	if t == int(m.T_TREE):
		return Color(0.30, 0.55, 0.26)
	if t == int(m.T_ROCK):
		return Color(0.42, 0.42, 0.45)
	return Color(0.3, 0.3, 0.3)


func _fill_circle(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	for y in range(cy - r, cy + r + 1):
		for x in range(cx - r, cx + r + 1):
			if (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r and x >= 0 and y >= 0 \
					and x < img.get_width() and y < img.get_height():
				img.set_pixel(x, y, col)


# ---------------- отрисовка ----------------

func _draw() -> void:
	ensure_map()
	if _map_cache:
		if _map_tex == null:
			_map_tex = ImageTexture.create_from_image(_map_cache)
		draw_texture(_map_tex, Vector2.ZERO)
	if _selected != -1 and _mobs.has(_selected):
		var sel: Vector2 = _mobs[_selected]["pos"]
		var pulse := 1.0 + 0.08 * sin(_time * 6.0)
		draw_arc(sel, 30.0 * pulse, 0.0, TAU, 32, Color(1.0, 0.85, 0.2), 3.0)
	_draw_npcs()
	_draw_portals()
	for id in _mobs:
		_draw_mob(_mobs[id])
	for id in _players:
		_draw_player(_players[id])
	for pt in _particles:
		var a := 1.0 - float(pt["t"]) / PARTICLE_LIFE
		draw_circle(pt["pos"], 3.0, Color(pt["color"].r, pt["color"].g, pt["color"].b, a))
	for pu in _popups:
		var a2 := 1.0 - float(pu["t"]) / DMG_LIFE
		var lift := -30.0 * float(pu["t"]) / DMG_LIFE
		draw_string(ThemeDB.fallback_font, pu["pos"] + Vector2(-10, lift - 36),
			String(pu["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(pu["color"].r, pu["color"].g, pu["color"].b, a2))


## NPC на карте: торговец, старейшина, наставник, кузнец, лекарь.
## Раньше они существовали только как координаты и были невидимы.
## Порталы текущей карты с подписью назначения.
func _draw_portals() -> void:
	var mn := _map_name if _map_name != "" else GDATA.DEFAULT_MAP
	for pt in _gd().portals_for(mn):
		var c: Vector2 = _gd().tile_center(pt["tile"])
		draw_circle(c, 18.0, Color(0.5, 0.3, 0.9, 0.45))
		draw_arc(c, 22.0, 0.0, TAU, 24, Color(0.8, 0.6, 1.0), 2.0)
		draw_string(ThemeDB.fallback_font, c + Vector2(-50, -28), String(pt["dst"]),
			HORIZONTAL_ALIGNMENT_CENTER, 100, 10, Color(1, 1, 1, 0.9))


func _draw_npcs() -> void:
	if _map_name != "" and _map_name != GDATA.DEFAULT_MAP:
		return
	var list := [
		[GDATA.NPC_SHOP_POS, Color(0.95, 0.8, 0.3), "Торговец"],
		[GDATA.NPC_QUEST_POS, Color(0.55, 0.75, 0.95), "Старейшина"],
		[GDATA.PROMOTE_POS, Color(0.8, 0.6, 0.95), "Наставник"],
		[GDATA.REFINE_POS, Color(0.9, 0.55, 0.35), "Кузнец"],
		[GDATA.HEALER_POS, Color(0.5, 0.9, 0.6), "Лекарь"],
	]
	for e in list:
		var pos: Vector2 = e[0]
		var col: Color = e[1]
		var nm: String = e[2]
		draw_circle(pos + Vector2(0, 14), 11.0, Color(0, 0, 0, 0.28))
		draw_rect(Rect2(pos + Vector2(-10, -14), Vector2(20, 28)), col.darkened(0.25))
		draw_circle(pos + Vector2(0, -18), 9.0, Color(0.96, 0.84, 0.7))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-32, -34), nm,
			HORIZONTAL_ALIGNMENT_CENTER, 64, 10, Color(1, 1, 1, 0.92))


func _draw_mob(mb: Dictionary) -> void:
	var sc := 1.0 + (0.25 * float(mb["scale_t"]) / FLASH_LIFE)
	var t := String(mb["type"])
	var hit := float(mb["flash"]) > 0.0
	var pos: Vector2 = mb["pos"]
	draw_circle(pos + Vector2(0, 20 * sc), 15.0 * sc, Color(0, 0, 0, 0.3))
	match t:
		"slime":
			var stex := _sprite("mob_slime_%d" % (int(_time * 6.0) % 4))
			if stex != null:
				_draw_sprite_at(stex, pos, SLIME_W * sc, hit)
			else:
				_draw_slime(pos, sc, hit)
		"wolf":
			var wtex := _sprite("mob_wolf_%d" % (int(_time * 8.0) % 4))
			if wtex != null:
				_draw_sprite_at(wtex, pos, 52.0 * sc, hit)
			else:
				_draw_wolf(pos, sc, hit)
		"golem":
			var gtex := _sprite("mob_golem_%d" % (int(_time * 4.0) % 4))
			if gtex != null:
				_draw_sprite_at(gtex, pos, 60.0 * sc, hit)
			else:
				_draw_golem(pos, sc, hit)
		"boss":
			var btex := _sprite("mob_boss_%d" % (int(_time * 4.0) % 4))
			if btex != null:
				_draw_sprite_at(btex, pos, 84.0 * sc, hit)
			else:
				_draw_boss(pos, sc, hit)
		_:
			# любой новый тип моба из SPRITE_FILES: кадры задаются ключом mob_<type>_<n>
			var atex := _sprite("mob_%s_%d" % [t, int(_time * 5.0) % 4])
			if atex != null:
				_draw_sprite_at(atex, pos, 56.0 * sc, hit)
			else:
				draw_circle(pos, 20.0 * sc, Color(0.8, 0.8, 0.8))
	_draw_hp(pos + Vector2(0, -34 * sc), int(mb["hp"]), int(mb["mhp"]))


func _tint(col: Color, hit: bool) -> Color:
	return Color(1.0, 0.35, 0.35) if hit else col


func _draw_slime(c: Vector2, sc: float, hit: bool) -> void:
	var base := _tint(Color(0.35, 0.82, 0.42), hit)
	var squash := 1.0 + 0.06 * sin(_time * 6.0)
	draw_circle(c + Vector2(0, 2 * sc), 20.0 * sc * squash, base.darkened(0.25))
	draw_circle(c + Vector2(0, -2 * sc), 17.0 * sc * squash, base)
	draw_circle(c + Vector2(-7 * sc, -9 * sc), 5.0 * sc, base.lightened(0.5))
	draw_circle(c + Vector2(-6 * sc, 0), 2.6 * sc, Color(0.08, 0.1, 0.08))
	draw_circle(c + Vector2(6 * sc, 0), 2.6 * sc, Color(0.08, 0.1, 0.08))


func _draw_wolf(c: Vector2, sc: float, hit: bool) -> void:
	var fur := _tint(Color(0.55, 0.5, 0.45), hit)
	var dark := fur.darkened(0.3)
	var step := sin(_time * 10.0) * 3.0 * sc
	draw_rect(Rect2(c + Vector2(-12 * sc, 8 * sc + step), Vector2(5 * sc, 10 * sc)), dark)
	draw_rect(Rect2(c + Vector2(6 * sc, 8 * sc - step), Vector2(5 * sc, 10 * sc)), dark)
	draw_line(c + Vector2(-14 * sc, 0), c + Vector2(-24 * sc, -10 * sc), dark, 4 * sc)
	draw_circle(c + Vector2(-2 * sc, 2 * sc), 14 * sc, fur)
	draw_circle(c + Vector2(12 * sc, -6 * sc), 10 * sc, fur)
	draw_colored_polygon(PackedVector2Array([c + Vector2(6 * sc, -14 * sc), c + Vector2(9 * sc, -24 * sc), c + Vector2(15 * sc, -14 * sc)]), dark)
	draw_colored_polygon(PackedVector2Array([c + Vector2(13 * sc, -15 * sc), c + Vector2(17 * sc, -24 * sc), c + Vector2(21 * sc, -14 * sc)]), dark)
	draw_circle(c + Vector2(19 * sc, -4 * sc), 3.5 * sc, dark)
	draw_circle(c + Vector2(14 * sc, -9 * sc), 2.4 * sc, Color(0.95, 0.85, 0.2))
	draw_circle(c + Vector2(14 * sc, -9 * sc), 1.1 * sc, Color(0.05, 0.05, 0.05))


func _draw_golem(c: Vector2, sc: float, hit: bool) -> void:
	var stone := _tint(Color(0.6, 0.6, 0.65), hit)
	var r := Rect2(c + Vector2(-17 * sc, -20 * sc), Vector2(34 * sc, 40 * sc))
	draw_rect(r, stone.darkened(0.2))
	draw_rect(Rect2(r.position + Vector2(3 * sc, 3 * sc), r.size - Vector2(6 * sc, 6 * sc)), stone)
	draw_line(c + Vector2(-6 * sc, -8 * sc), c + Vector2(0, 2 * sc), stone.darkened(0.45), 2 * sc)
	draw_line(c + Vector2(4 * sc, 4 * sc), c + Vector2(8 * sc, 14 * sc), stone.darkened(0.45), 2 * sc)
	var glow := 0.6 + 0.4 * sin(_time * 3.0)
	draw_circle(c + Vector2(-6 * sc, -8 * sc), 2.8 * sc, Color(0.4, 0.9, 1.0, glow))
	draw_circle(c + Vector2(6 * sc, -8 * sc), 2.8 * sc, Color(0.4, 0.9, 1.0, glow))


func _draw_boss(c: Vector2, sc: float, hit: bool) -> void:
	var skin := _tint(Color(0.62, 0.3, 0.32), hit)
	var horn := Color(0.9, 0.85, 0.7)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-14 * sc, -14 * sc), c + Vector2(-22 * sc, -32 * sc), c + Vector2(-6 * sc, -20 * sc)]), horn)
	draw_colored_polygon(PackedVector2Array([c + Vector2(14 * sc, -14 * sc), c + Vector2(22 * sc, -32 * sc), c + Vector2(6 * sc, -20 * sc)]), horn)
	draw_circle(c, 24 * sc, skin.darkened(0.25))
	draw_circle(c + Vector2(0, -2 * sc), 21 * sc, skin)
	draw_circle(c + Vector2(-8 * sc, -4 * sc), 4 * sc, Color(1, 0.2, 0.1))
	draw_circle(c + Vector2(8 * sc, -4 * sc), 4 * sc, Color(1, 0.2, 0.1))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6 * sc, 8 * sc), c + Vector2(-3 * sc, 15 * sc), c + Vector2(-1 * sc, 8 * sc)]), Color(1, 1, 0.95))
	draw_colored_polygon(PackedVector2Array([c + Vector2(6 * sc, 8 * sc), c + Vector2(3 * sc, 15 * sc), c + Vector2(1 * sc, 8 * sc)]), Color(1, 1, 0.95))


func _draw_sprite_at(tex: Texture2D, center: Vector2, width: float, hit: bool) -> void:
	var sz := tex.get_size()
	var k := width / sz.x
	var h := sz.y * k
	var r := Rect2(center + Vector2(-width / 2.0, -h + width * 0.25), Vector2(width, h))
	var mod := Color(1.0, 0.45, 0.45) if hit else Color(1, 1, 1)
	draw_texture_rect(tex, r, false, mod)


func _draw_player(pl: Dictionary) -> void:
	var cls_key := String(pl["cls"])
	var is_hit := float(pl["flash"]) > 0.0
	var frame_key := "hero_%s_attack" % cls_key if is_hit else "hero_%s_%d" % [cls_key, (int(_time * 8.0) % 4) if bool(pl["moving"]) else 0]
	var hero_tex := _sprite(frame_key)
	if hero_tex != null and not bool(pl["dead"]):
		var hp_pos: Vector2 = pl["pos"]
		var bob2 := -absf(sin(_time * 14.0 + float(pl["phase"]))) * 2.0 if bool(pl["moving"]) else 0.0
		var hit2 := float(pl["flash"]) > 0.0
		draw_circle(hp_pos + Vector2(0, 18), 13.0, Color(0, 0, 0, 0.3))
		_draw_sprite_at(hero_tex, hp_pos + Vector2(0, bob2), HERO_H * 0.7, hit2)
		draw_string(ThemeDB.fallback_font, hp_pos + Vector2(-30, -HERO_H * 0.9), String(pl["name"]),
			HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(1, 1, 1))
		_draw_hp(hp_pos + Vector2(0, -HERO_H * 0.75), int(pl["hp"]), int(pl["mhp"]))
		return
	var pos: Vector2 = pl["pos"]
	var walking := bool(pl["moving"])
	var swing := sin(_time * 14.0 + float(pl["phase"])) if walking else 0.0
	var bob := -absf(swing) * 2.0
	var c := pos + Vector2(0, bob)
	var sc := 1.0 + (0.18 * float(pl["scale_t"]) / FLASH_LIFE)
	var cls := String(pl["cls"])
	var tunic := Color(0.9, 0.7, 0.3)
	if cls == "mage":
		tunic = Color(0.35, 0.5, 1.0)
	elif cls == "archer":
		tunic = Color(0.45, 0.8, 0.35)
	if bool(pl["dead"]):
		tunic = Color(0.4, 0.4, 0.4)
	if float(pl["flash"]) > 0.0:
		tunic = Color(1.0, 0.3, 0.3)
	var skin := Color(0.96, 0.82, 0.68)
	var hair := Color(0.35, 0.22, 0.12)
	var pants := Color(0.25, 0.22, 0.3)
	draw_circle(pos + Vector2(0, 18 * sc), 13 * sc, Color(0, 0, 0, 0.3))
	draw_rect(Rect2(c + Vector2(-7 * sc + swing * 2 * sc, 6 * sc), Vector2(5 * sc, 11 * sc)), pants)
	draw_rect(Rect2(c + Vector2(2 * sc - swing * 2 * sc, 6 * sc), Vector2(5 * sc, 11 * sc)), pants)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11 * sc, -4 * sc), c + Vector2(11 * sc, -4 * sc), c + Vector2(13 * sc, 12 * sc), c + Vector2(-13 * sc, 12 * sc)]), tunic)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-11 * sc, -4 * sc), c + Vector2(11 * sc, -4 * sc), c + Vector2(9 * sc, -2 * sc), c + Vector2(-9 * sc, -2 * sc)]), tunic.lightened(0.25))
	draw_circle(c + Vector2(0, -13 * sc), 9.5 * sc, hair)
	draw_circle(c + Vector2(0, -12 * sc), 8.0 * sc, skin)
	draw_circle(c + Vector2(-3 * sc, -12 * sc), 1.6 * sc, Color(0.1, 0.08, 0.08))
	draw_circle(c + Vector2(3 * sc, -12 * sc), 1.6 * sc, Color(0.1, 0.08, 0.08))
	if cls == "mage":
		draw_line(c + Vector2(14 * sc, 12 * sc), c + Vector2(14 * sc, -20 * sc), Color(0.5, 0.35, 0.2), 2.5 * sc)
		draw_circle(c + Vector2(14 * sc, -22 * sc), 4 * sc, Color(0.5, 0.8, 1.0, 0.9))
	elif cls == "archer":
		draw_arc(c + Vector2(-14 * sc, -2 * sc), 13 * sc, -1.2, 1.2, 12, Color(0.45, 0.3, 0.15), 2.5 * sc)
	else:
		draw_line(c + Vector2(13 * sc, 10 * sc), c + Vector2(20 * sc, -18 * sc), Color(0.8, 0.85, 0.9), 3 * sc)
	draw_string(ThemeDB.fallback_font, c + Vector2(-30, -34 * sc), String(pl["name"]),
		HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(1, 1, 1))
	_draw_hp(c + Vector2(0, -28 * sc), int(pl["hp"]), int(pl["mhp"]))


func _draw_hp(at: Vector2, hp: int, mhp: int) -> void:
	var w := 40.0
	var frac := clampf(float(hp) / float(maxi(1, mhp)), 0.0, 1.0)
	draw_rect(Rect2(at + Vector2(-w / 2, -4), Vector2(w, 6)), Color(0.15, 0.05, 0.05))
	draw_rect(Rect2(at + Vector2(-w / 2, -4), Vector2(w * frac, 6)), Color(0.3, 0.85, 0.3))


## Автолоад GameData по пути (имя автолоада не видно из этого скрипта при загрузке через preload).
func _gd() -> Node:
	return get_node_or_null("/root/GameData")
