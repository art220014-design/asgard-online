extends Node
## Статические данные игры: классы, навыки, мобы, предметы, карта.
## Один и тот же файл работает и на сервере, и на клиенте — карта детерминированная.

const TILE := 64
const MAP_W := 64
const MAP_H := 64
const WORLD_SIZE := Vector2(MAP_W * TILE, MAP_H * TILE)

# ---------- Тайлы ----------
const T_GRASS := 0
const T_GRASS2 := 1
const T_SAND := 2
const T_STONE := 3
const T_WATER := 4
const T_TREE := 5
const T_ROCK := 6

const TILE_TEX := {
	T_GRASS: "res://assets/tiles/grass.png",
	T_GRASS2: "res://assets/tiles/grass2.png",
	T_SAND: "res://assets/tiles/sand.png",
	T_STONE: "res://assets/tiles/stone.png",
	T_WATER: "res://assets/tiles/water.png",
	T_TREE: "res://assets/tiles/tree.png",
	T_ROCK: "res://assets/tiles/rock.png",
}

const BLOCKING := {
	T_WATER: true,
	T_TREE: true,
	T_ROCK: true,
}

# ---------- Классы ----------
const CLASSES := {
	"sword": {
		"name": "Мечник",
		"sprite": "res://assets/sprites_v3/heroes/swordsman_down.png",
		"hp": 160, "mp": 40, "atk": 16, "def": 8, "speed": 215,
		"skills": ["slash", "whirl", "bash"],
	},
	"mage": {
		"name": "Маг",
		"sprite": "res://assets/sprites_v3/heroes/mage_down.png",
		"hp": 105, "mp": 90, "atk": 22, "def": 4, "speed": 200,
		"skills": ["bolt", "frost", "heal"],
	},
	"archer": {
		"name": "Лучник",
		"sprite": "res://assets/sprites_v3/heroes/archer_down.png",
		"hp": 125, "mp": 55, "atk": 18, "def": 5, "speed": 230,
		"skills": ["arrow", "multi", "trap"],
	},
}

# ---------- Вторая ступень классов ----------
# Доступна у NPC-наставника при уровне >= PROMOTE_LEVEL и наличии PROMOTE_COST золота.
const PROMOTE_LEVEL := 5
const PROMOTE_COST := 300
const PROMOTE_POS := Vector2(30 * TILE, 37 * TILE)
const PROMOTE_RANGE := 170.0
const CLASSES_T2 := {
	"paladin": {
		"name": "Паладин", "base": "sword",
		"hp": 200, "mp": 60, "atk": 22, "def": 14, "speed": 205,
		"skills": ["slash", "whirl", "bash"],
		"sprite": "res://assets/sprites_v3/heroes/paladin_down.png",
	},
	"high_mage": {
		"name": "Архимаг", "base": "mage",
		"hp": 130, "mp": 130, "atk": 30, "def": 7, "speed": 205,
		"skills": ["bolt", "frost", "heal"],
		"sprite": "res://assets/sprites_v3/heroes/archmage_down.png",
	},
	"ranger": {
		"name": "Следопыт", "base": "archer",
		"hp": 160, "mp": 75, "atk": 26, "def": 9, "speed": 245,
		"skills": ["arrow", "multi", "trap"],
		"sprite": "res://assets/sprites_v3/heroes/scout_down.png",
	},
}
# Какой класс первой ступени можно повысить и во что.
const PROMOTE_TO := {"sword": "paladin", "mage": "high_mage", "archer": "ranger"}

# ---------- Навыки ----------
const SKILLS := {
	"slash": {
		"name": "Удар", "icon": "res://assets/icons/sword.png",
		"element": "Neutral", "element_level": 1,
		"mp": 0, "cd": 0.6, "range": 78, "kind": "melee", "power": 1.0,
	},
	"whirl": {
		"name": "Вихрь", "icon": "res://assets/icons/skill_b.png",
		"element": "Neutral", "element_level": 1,
		"mp": 12, "cd": 2.4, "range": 96, "kind": "aoe", "power": 1.35,
	},
	"bash": {
		"name": "Сокрушение", "icon": "res://assets/icons/skill_c.png",
		"element": "Neutral", "element_level": 1,
		"mp": 20, "cd": 4.0, "range": 92, "kind": "melee", "power": 2.2,
	},
	"bolt": {
		"name": "Молния", "icon": "res://assets/icons/skill_a.png",
		"element": "Wind", "element_level": 1,
		"mp": 8, "cd": 0.9, "range": 420, "kind": "projectile", "power": 1.15,
	},
	"frost": {
		"name": "Стужа", "icon": "res://assets/icons/skill_b.png",
		"element": "Water", "element_level": 1,
		"mp": 18, "cd": 3.0, "range": 360, "kind": "aoe", "power": 1.6,
	},
	"heal": {
		"name": "Исцеление", "icon": "res://assets/icons/potion.png",
		"element": "Holy", "element_level": 1,
		"mp": 16, "cd": 5.0, "range": 0, "kind": "heal", "power": 1.5,
	},
	"arrow": {
		"name": "Выстрел", "icon": "res://assets/icons/bow.png",
		"element": "Neutral", "element_level": 1,
		"mp": 0, "cd": 0.7, "range": 400, "kind": "projectile", "power": 1.0,
	},
	"multi": {
		"name": "Веер стрел", "icon": "res://assets/icons/skill_a.png",
		"element": "Neutral", "element_level": 1,
		"mp": 14, "cd": 2.6, "range": 360, "kind": "aoe", "power": 1.4,
	},
	"trap": {
		"name": "Капкан", "icon": "res://assets/icons/skill_c.png",
		"element": "Earth", "element_level": 1,
		"mp": 10, "cd": 6.0, "range": 120, "kind": "melee", "power": 1.8,
	},
}

# ---------- Стихии и таблица множителей урона ----------
# Источник: rAthena db/re/attr_fix.txt (4 уровня, строки — стихия атакующего,
# столбцы — стихия цели, значение в %). 100 = обычный урон.
const ELEMENTS: Array[String] = ["Neutral", "Water", "Earth", "Fire", "Wind", "Poison", "Holy", "Shadow", "Ghost", "Undead"]
const ATTR_FIX := {
	1: [
		[100, 100, 100, 100, 100, 100, 100, 100, 70, 100],
		[100, 25, 100, 150, 90, 100, 75, 100, 100, 100],
		[100, 100, 25, 90, 150, 100, 75, 100, 100, 100],
		[100, 90, 150, 25, 100, 100, 75, 100, 100, 125],
		[100, 175, 90, 100, 25, 100, 75, 100, 100, 100],
		[100, 100, 125, 125, 125, 0, 75, 50, 100, -25],
		[100, 100, 100, 100, 100, 100, 0, 125, 100, 150],
		[100, 100, 100, 100, 100, 50, 125, 0, 100, -25],
		[70, 100, 100, 100, 100, 100, 75, 75, 125, 100],
		[100, 100, 100, 100, 100, 50, 100, 0, 100, 0],
	],
	2: [
		[100, 100, 100, 100, 100, 100, 100, 100, 50, 100],
		[100, 0, 100, 175, 80, 100, 50, 75, 100, 100],
		[100, 100, 0, 80, 175, 100, 50, 75, 100, 100],
		[100, 80, 175, 0, 100, 100, 50, 75, 100, 150],
		[100, 175, 80, 100, 0, 100, 50, 75, 100, 100],
		[100, 75, 125, 125, 125, 0, 50, 25, 75, -50],
		[100, 100, 100, 100, 100, 100, -25, 150, 100, 175],
		[100, 100, 100, 100, 100, 25, 150, -25, 100, -50],
		[50, 75, 75, 75, 75, 75, 50, 50, 150, 125],
		[100, 75, 75, 75, 75, 25, 125, 0, 100, 0],
	],
	3: [
		[100, 100, 100, 100, 100, 100, 100, 100, 0, 100],
		[100, -25, 100, 200, 70, 100, 25, 50, 100, 125],
		[100, 100, -25, 70, 200, 100, 25, 50, 100, 100],
		[100, 70, 200, -25, 100, 100, 25, 50, 100, 175],
		[100, 200, 70, 100, -25, 100, 25, 50, 100, 100],
		[100, 50, 100, 100, 100, 0, 25, 0, 50, -75],
		[100, 100, 100, 100, 100, 125, -50, 175, 100, 200],
		[100, 100, 100, 100, 100, 0, 175, -50, 100, -75],
		[0, 50, 50, 50, 50, 50, 25, 25, 175, 150],
		[100, 50, 50, 50, 50, 0, 150, 0, 100, 0],
	],
	4: [
		[100, 100, 100, 100, 100, 100, 100, 100, 0, 100],
		[100, -50, 100, 200, 60, 75, 0, 25, 100, 150],
		[100, 100, -50, 60, 200, 75, 0, 25, 100, 50],
		[100, 60, 200, -50, 100, 75, 0, 25, 100, 200],
		[100, 200, 60, 100, -50, 75, 0, 25, 100, 100],
		[100, 25, 75, 75, 75, 0, 0, -25, 25, -100],
		[100, 75, 75, 75, 75, 125, -100, 200, 100, 200],
		[100, 75, 75, 75, 75, -25, 200, -100, 100, -100],
		[0, 25, 25, 25, 25, 25, 0, 0, 200, 175],
		[100, 25, 25, 25, 25, -25, 175, 0, 100, 0],
	],
}

## Множитель урона: стихия и уровень атакующего против стихии цели.
## 1.0 = 100%. Неизвестная стихия — без изменений.
static func element_multiplier(atk_elem: String, atk_lv: int, def_elem: String) -> float:
	var ai := ELEMENTS.find(atk_elem)
	var di := ELEMENTS.find(def_elem)
	if ai < 0 or di < 0:
		return 1.0
	var table: Array = ATTR_FIX.get(clampi(atk_lv, 1, 4), ATTR_FIX[1])
	if ai >= table.size():
		return 1.0
	var row: Array = table[ai]
	if di >= row.size():
		return 1.0
	return float(row[di]) / 100.0

# ---------- Улучшение (refine) ----------
# Источник: rAthena db/re/refine_db.yml, уровни 1..20.
# chance 100 = безопасное улучшение. Дальше шанс падает и предмет может сломаться.
const REFINE_MAX := 20
const REFINE_COST := 2000
const REFINE_MATERIAL := "ore"
const REFINE_MATERIAL_COUNT := 1
const REFINE_POS := Vector2(33 * TILE, 34 * TILE)
const HEALER_POS := Vector2(33 * TILE, 30 * TILE)
const REFINE_RANGE := 170.0

const REFINE_RATES := {
	"WeaponLv1": [
		[8, 60],
		[9, 40],
		[10, 19],
		[11, 18],
		[12, 18],
		[13, 18],
		[14, 18],
		[15, 18],
		[16, 17],
		[17, 17],
		[18, 17],
		[19, 15],
		[20, 15],
	],
	"WeaponLv2": [
		[7, 60],
		[8, 40],
		[9, 20],
		[10, 19],
		[11, 18],
		[12, 18],
		[13, 18],
		[14, 18],
		[15, 18],
		[16, 17],
		[17, 17],
		[18, 17],
		[19, 15],
		[20, 15],
	],
	"WeaponLv3": [
		[6, 60],
		[7, 50],
		[8, 20],
		[9, 20],
		[10, 19],
		[11, 18],
		[12, 18],
		[13, 18],
		[14, 18],
		[15, 18],
		[16, 17],
		[17, 17],
		[18, 17],
		[19, 15],
		[20, 15],
	],
	"WeaponLv4": [
		[5, 60],
		[6, 40],
		[7, 40],
		[8, 20],
		[9, 20],
		[10, 9],
		[11, 8],
		[12, 8],
		[13, 8],
		[14, 8],
		[15, 7],
		[16, 7],
		[17, 7],
		[18, 7],
		[19, 5],
		[20, 5],
	],
	"Armor": [
		[1, 100],
		[2, 100],
		[3, 100],
		[4, 100],
		[5, 60],
		[6, 40],
		[7, 40],
		[8, 20],
		[9, 20],
		[10, 9],
		[11, 8],
		[12, 8],
		[13, 8],
		[14, 8],
		[15, 7],
		[16, 7],
		[17, 7],
		[18, 7],
		[19, 5],
		[20, 5],
	],
}

## Ключ таблицы улучшения по типу предмета.
static func refine_key(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return ""
	var it: Dictionary = ITEMS[item_id]
	if String(it.get("kind", "")) == "armor":
		return "Armor"
	if String(it.get("kind", "")) != "weapon":
		return ""
	return "WeaponLv%d" % clampi(int(it.get("weapon_level", 1)), 1, 4)

## Шанс успеха следующего улучшения (в процентах). 0 = дальше нельзя.
static func refine_chance(item_id: String, cur_level: int) -> int:
	var key := refine_key(item_id)
	if key == "" or cur_level >= REFINE_MAX:
		return 0
	var table: Array = REFINE_RATES.get(key, [])
	if table.is_empty():
		return 0
	# уровни ниже первого в таблице — безопасные (100%), как в rAthena
	var first: int = int(table[0][0])
	if cur_level + 1 < first:
		return 100
	for row in table:
		if int(row[0]) == cur_level + 1:
			return int(row[1])
	return 0

## Прибавка к атаке/защите за уровень улучшения.
## WeaponLv1-2: +1, WeaponLv3-4: +2, броня: +1 за уровень.
static func refine_bonus(item_id: String, level: int) -> int:
	if level <= 0:
		return 0
	var key := refine_key(item_id)
	if key == "":
		return 0
	var per := 2 if (key == "WeaponLv3" or key == "WeaponLv4") else 1
	return clampi(level, 0, REFINE_MAX) * per


# ---------- Магазины и каталог из rAthena (npc/merchants, db/re/item_db) ----------
# Данные в res://data/*.json, загружаются один раз при первом обращении.
var _rathena_shops_cache: Array = []
var _rathena_items_cache: Dictionary = {}


func _load_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_ARRAY else []


## Все магазины: [{map, name, items: [{id, name, price}]}].
func rathena_shops() -> Array:
	if _rathena_shops_cache.is_empty():
		_rathena_shops_cache = _load_json_array("res://data/rathena_shops.json")
	return _rathena_shops_cache


## Описание предмета из каталога rAthena по id (или {}).
func rathena_item(item_id: int) -> Dictionary:
	if _rathena_items_cache.is_empty():
		for it in _load_json_array("res://data/rathena_items.json"):
			_rathena_items_cache[int(it["id"])] = it
	return _rathena_items_cache.get(item_id, {})

# ---------- Мобы ----------
const MOBS := {
	"slime": {
		"element": "Water", "element_level": 1,
		"name": "Слайм", "sprite": "res://assets/sprites/mob_slime.png",
		"hp": 60, "atk": 8, "xp": 18, "gold": 12, "speed": 62,
		"aggro": 220, "attack_range": 56, "cooldown": 1.4, "respawn": 8.0,
		"level": 1,
	},
	"wolf": {
		"element": "Earth", "element_level": 1,
		"name": "Волк", "sprite": "res://assets/sprites/mob_wolf.png",
		"hp": 110, "atk": 15, "xp": 38, "gold": 26, "speed": 108,
		"aggro": 300, "attack_range": 62, "cooldown": 1.2, "respawn": 11.0,
		"level": 3,
	},
	"golem": {
		"element": "Undead", "element_level": 1,
		"name": "Голем", "sprite": "res://assets/sprites/mob_golem.png",
		"hp": 260, "atk": 26, "xp": 95, "gold": 70, "speed": 74,
		"aggro": 260, "attack_range": 70, "cooldown": 1.8, "respawn": 16.0,
		"level": 7,
	},
	"marin": {
		"element": "Water", "element_level": 2,
		"name": "Марин (Marin, id 1242)", "sprite": "res://assets/sprites_v3/monsters/slime_blue_idle1.png",
		"hp": 987, "atk": 69, "xp": 282, "gold": 120, "speed": 70,
		"aggro": 300, "attack_range": 60, "cooldown": 1.5, "respawn": 14.0,
		"level": 37,
	},
	"poporing": {
		"element": "Poison", "element_level": 1,
		"name": "Попоринг (Poporing, id 1031)", "sprite": "res://assets/sprites_v3/monsters/slime_green_idle1.png",
		"hp": 524, "atk": 74, "xp": 198, "gold": 95, "speed": 68,
		"aggro": 290, "attack_range": 60, "cooldown": 1.4, "respawn": 12.0,
		"level": 30,
	},
	"zombie": {
		"element": "Undead", "element_level": 1,
		"name": "Зомби (Zombie, id 1015)", "sprite": "res://assets/sprites_v3/monsters/skeleton_idle1.png",
		"hp": 234, "atk": 38, "xp": 117, "gold": 55, "speed": 66,
		"aggro": 280, "attack_range": 62, "cooldown": 1.6, "respawn": 11.0,
		"level": 17,
	},
	"orc": {
		"element": "Earth", "element_level": 2,
		"name": "Орк (Orc Lady, id 1273)", "sprite": "res://assets/sprites_v3/monsters/orc_idle1.png",
		"hp": 1520, "atk": 77, "xp": 380, "gold": 190, "speed": 84,
		"aggro": 340, "attack_range": 68, "cooldown": 1.7, "respawn": 18.0,
		"level": 45,
	},
	"boss": {
		"element": "Undead", "element_level": 1,
		"name": "Тролль-вожак", "sprite": "res://assets/sprites/mob_boss.png",
		"hp": 900, "atk": 42, "xp": 420, "gold": 380, "speed": 88,
		"aggro": 420, "attack_range": 84, "cooldown": 2.0, "respawn": 45.0,
		"level": 12,
	},
}

# ---------- Предметы ----------
const ITEMS := {
	# Зелья: названия по базе rAthena (501 Red Potion, 503 Blue Potion)
	"potion": {"name": "Красное зелье (Red Potion, id 501)", "id": 501, "price": 60, "kind": "heal", "amount": 60,
			   "icon": "res://assets/sprites_v3/items/potion_red.png", "desc": "Восстанавливает 60 HP"},
	"mana": {"name": "Синее зелье (Blue Potion, id 505)", "id": 505, "price": 80, "kind": "mana", "amount": 45,
			 "icon": "res://assets/sprites_v3/items/potion_blue.png", "desc": "Восстанавливает 45 MP"},
	# Оружие: id 1101 Sword, 1104 Falchion, 1601 Rod, 1701 Bow
	"blade": {"name": "Меч (Sword, id 1101, ATK 25)", "id": 1101, "price": 450, "kind": "weapon", "atk": 8, "weapon_level": 1,
			  "icon": "res://assets/sprites_v3/items/sword.png", "desc": "+8 к атаке"},
	"armor": {"name": "Кожаный жилет (Jacket, id 2303, DEF 15)", "id": 2303, "price": 380, "kind": "armor", "def": 6,
			  "icon": "res://assets/sprites_v3/items/bag.png", "desc": "+6 к защите"},
	"war_axe": {"name": "Фальшион (Falchion, id 1104, ATK 39)", "id": 1104, "price": 0, "kind": "weapon", "atk": 13, "weapon_level": 1, "rarity": "rare",
			  "icon": "res://assets/sprites_v3/items/sword2.png", "desc": "+13 к атаке"},
	"plate": {"name": "Кираса (Coat, id 2309, DEF 42)", "id": 2309, "price": 0, "kind": "armor", "def": 11, "rarity": "rare",
			  "icon": "res://assets/sprites_v3/items/shield.png", "desc": "+11 к защите"},
	"troll_club": {"name": "Дробитель тролля (Slayer, id 1151, ATK 90)", "id": 1151, "price": 0, "kind": "weapon", "atk": 22, "weapon_level": 2, "rarity": "epic",
			  "icon": "res://assets/sprites_v3/items/staff.png", "desc": "+22 к атаке"},
	# Материалы
	"ore": {"name": "Железо (Iron, id 998)", "id": 998, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/coin.png", "desc": "Материал для кузни"},
	"herb": {"name": "Красная трава (Red Herb, id 507)", "id": 507, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/scroll.png", "desc": "Лечебная трава"},
	"wood": {"name": "Древесина (Wooden Block, id 1019)", "id": 1019, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Древесина"},
	"cutter": {"name": "Cutter (Cutter, id 1204, ATK 30)", "id": 1204, "price": 0, "kind": "weapon", "atk": 10, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+10 к атаке"},
	"main_gauche": {"name": "Main Gauche (Main_Gauche, id 1207, ATK 43)", "id": 1207, "price": 0, "kind": "weapon", "atk": 14, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+14 к атаке"},
	"axe": {"name": "Axe (Axe, id 1301, ATK 38)", "id": 1301, "price": 0, "kind": "weapon", "atk": 12, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+12 к атаке"},
	"battle_axe": {"name": "Battle Axe (Battle_Axe, id 1351, ATK 80)", "id": 1351, "price": 0, "kind": "weapon", "atk": 26, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+26 к атаке"},
	"club": {"name": "Club (Club, id 1501, ATK 23)", "id": 1501, "price": 0, "kind": "weapon", "atk": 7, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+7 к атаке"},
	"mace": {"name": "Mace (Mace, id 1504, ATK 37)", "id": 1504, "price": 0, "kind": "weapon", "atk": 12, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+12 к атаке"},
	"javelin": {"name": "Javelin (Javelin, id 1401, ATK 28)", "id": 1401, "price": 0, "kind": "weapon", "atk": 9, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+9 к атаке"},
	"spear": {"name": "Spear (Spear, id 1404, ATK 44)", "id": 1404, "price": 0, "kind": "weapon", "atk": 14, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+14 к атаке"},
	"pike": {"name": "Pike (Pike, id 1407, ATK 60)", "id": 1407, "price": 0, "kind": "weapon", "atk": 20, "weapon_level": 1,
			"icon": "res://assets/sprites_v3/items/sword.png", "desc": "+20 к атаке"},
	"jellopy": {"name": "Желейка (Jellopy, id 909)", "id": 909, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/scroll2.png", "desc": "Слизь слайма, материал для квестов"},
	"feather": {"name": "Перо (Feather, id 949)", "id": 949, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Перо волка, материал для квестов"},
	"fluff": {"name": "Пух (Fluff, id 914)", "id": 914, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag.png", "desc": "Пушистый материал для квестов"},
	"clover": {"name": "Клевер (Clover, id 705)", "id": 705, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag.png", "desc": "Четырёхлистный клевер, материал для квестов"},
	"steel": {"name": "Сталь (Steel, id 999)", "id": 999, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/shield.png", "desc": "Сталь, материал для оружия и квестов"},
	"emperium": {"name": "Эмпериум (Emperium, id 714)", "id": 714, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/scroll.png", "desc": "Редкий материал, выпадает у боссов"},
	"poring_doll": {"name": "Кукла Порин (Poring Doll, id 741)", "id": 741, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла, которую любит Элин"},
	"chonchon_doll": {"name": "Кукла Чончон (Chonchon Doll, id 742)", "id": 742, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла Чончон, для квеста Элин"},
	"stuffed_doll": {"name": "Плюшевая кукла (Stuffed Doll, id 740)", "id": 740, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Мягкая кукла, для квеста Элин"},
	"grasshopper_doll": {"name": "Кукла Кузнечик (Grasshopper Doll, id 752)", "id": 752, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла кузнечика, для квеста Элин"},
	"spore_doll": {"name": "Кукла Спора (Spore Doll, id 743)", "id": 743, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла гриба, для квеста Элин"},
	"osiris_doll": {"name": "Кукла Осирис (Osiris Doll, id 751)", "id": 751, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла Осириса, для квеста Элин"},
	"baphomet_doll": {"name": "Кукла Бафомет (Baphomet Doll, id 750)", "id": 750, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла Бафомета, для квеста Элин"},
	"raccoon_doll": {"name": "Кукла енота (Raccoondog Doll, id 754)", "id": 754, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла енота, для квеста Элин"},
	"monkey_doll": {"name": "Кукла-йо-йо (Monkey Doll, id 753)", "id": 753, "price": 0, "kind": "material",
			"icon": "res://assets/sprites_v3/items/bag2.png", "desc": "Кукла-йо-йо, для квеста Элин"},
}

# ---------- Таблицы дропа ----------
# [предмет, вес]; пустая строка = ничего. Один бросок на убийство, сумма весов = 100.
const LOOT := {
	"slime": [["potion", 22], ["jellopy", 14], ["stuffed_doll", 4], ["", 60]],
	"wolf": [["potion", 20], ["armor", 3], ["feather", 12], ["fluff", 8], ["grasshopper_doll", 4], ["", 53]],
	"golem": [["potion", 20], ["war_axe", 4], ["plate", 3], ["steel", 8], ["", 65]],
	"marin": [["potion", 22], ["herb", 8], ["spore_doll", 4], ["", 66]],
	"poporing": [["potion", 20], ["herb", 10], ["clover", 20], ["poring_doll", 5], ["", 45]],
	"zombie": [["potion", 18], ["wood", 6], ["chonchon_doll", 4], ["", 72]],
	"orc": [["potion", 24], ["war_axe", 5], ["plate", 4], ["", 67]],
	"boss": [["potion", 30], ["war_axe", 15], ["plate", 15], ["troll_club", 10], ["emperium", 3], ["", 27]],
}

# ---------- Магазин за реальные деньги ----------
# Только удобство и косметика; боевой баланс за деньги не продаётся.
# id совпадает с product ID в Google Play Console.
const STORE := [
	{"id": "gold_small", "title": "Мешок золота", "desc": "+500 золота", "price_label": "99 руб.",
	 "grant": {"gold": 500}},
	{"id": "gold_large", "title": "Сундук золота", "desc": "+2500 золота", "price_label": "399 руб.",
	 "grant": {"gold": 2500}},
	{"id": "potion_pack", "title": "Набор зелий", "desc": "10 зелий лечения", "price_label": "149 руб.",
	 "grant": {"item": "potion", "count": 10}},
	{"id": "vip_week", "title": "Вип-неделя", "desc": "7 дней VIP", "price_label": "249 руб.",
	 "grant": {"vip_days": 7}},
]

# ---------- Квесты ----------
const QUESTS := [
	{"id": "q_slime", "title": "Чистка лугов", "desc": "Убей 10 слаймов",
	 "type": "kill", "target": "slime", "count": 10, "xp": 120, "gold": 150},
	{"id": "q_wolf", "title": "Волчья тропа", "desc": "Убей 8 волков",
	 "type": "kill", "target": "wolf", "count": 8, "xp": 260, "gold": 320},
	{"id": "q_boss", "title": "Вожак", "desc": "Убей тролля-вожака",
	 "type": "kill", "target": "boss", "count": 1, "xp": 800, "gold": 900},
]

# ---------- Цепочки квестов (этап 2) ----------
# steps: kill {target, count} или talk {npc}. Первый шаг обычно разговор с NPC.
# reward: gold, xp, items [[id, count]]. Старые QUESTS выше не трогаем, чтобы не сломать сохранения.
const CHAINS := [
	{"id": "ch_village", "title": "Тихая деревня", "min_level": 1,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Поговори со Старейшиной"},
		{"type": "kill", "target": "slime", "count": 5, "text": "Убей 5 слаймов у деревни"},
		{"type": "talk", "npc": "quest", "text": "Вернись к Старейшине"},
	],
	 "reward": {"gold": 200, "xp": 150, "items": [["potion", 2]]}},
	{"id": "ch_trail", "title": "Волчий след", "min_level": 3,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Узнай о волках у Старейшины"},
		{"type": "kill", "target": "wolf", "count": 6, "text": "Убей 6 волков"},
		{"type": "kill", "target": "golem", "count": 1, "text": "Победи голема"},
		{"type": "talk", "npc": "quest", "text": "Доложи Старейшине"},
	],
	 "reward": {"gold": 500, "xp": 420, "items": [["war_axe", 1], ["potion", 3]]}},
	{"id": "ch_chief", "title": "Логово вожака", "min_level": 10,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Выслушай предупреждение Старейшины"},
		{"type": "kill", "target": "boss", "count": 1, "text": "Победи тролля-вожака"},
		{"type": "talk", "npc": "quest", "text": "Сообщи о победе"},
	],
	 "reward": {"gold": 1200, "xp": 900, "items": [["troll_club", 1], ["plate", 1]]}},
	{"id": "ch_sword_trial", "title": "Испытание мечника", "min_level": 5,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Поговори со Старейшиной об испытании"},
		{"type": "kill", "target": "wolf", "count": 8, "text": "Убей 8 волков на тропе"},
		{"type": "kill", "target": "slime", "count": 6, "text": "Убей 6 слаймов у дороги"},
		{"type": "talk", "npc": "quest", "text": "Вернись к Старейшине с отчётом"},
	 ],
	 "reward": {"gold": 350, "xp": 240, "items": [["blade", 1]]}},
	{"id": "ch_archer_trial", "title": "Охота стрелка", "min_level": 8,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Узнай о каменных стражах у Старейшины"},
		{"type": "kill", "target": "golem", "count": 3, "text": "Победи 3 голема"},
		{"type": "kill", "target": "wolf", "count": 6, "text": "Убей 6 волков"},
		{"type": "talk", "npc": "quest", "text": "Доложи Старейшине о победе"},
	 ],
	 "reward": {"gold": 500, "xp": 380, "items": [["potion", 5]]}},
	{"id": "ch_marsh", "title": "Болотный дозор", "min_level": 12,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Выслушай Старейшину о сырости у болот"},
		{"type": "kill", "target": "poporing", "count": 4, "text": "Убей 4 попорингов"},
		{"type": "kill", "target": "marin", "count": 2, "text": "Одолей 2 марина"},
		{"type": "talk", "npc": "quest", "text": "Доложи о дозоре Старейшине"},
	 ],
	 "reward": {"gold": 600, "xp": 550, "items": [["potion", 4]]}},
	{"id": "ch_undead", "title": "Нежить у развалин", "min_level": 15,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Узнай у Старейшины о мертвецах в развалинах"},
		{"type": "kill", "target": "zombie", "count": 5, "text": "Упокой 5 зомби"},
		{"type": "kill", "target": "golem", "count": 2, "text": "Разбей 2 голема"},
		{"type": "talk", "npc": "quest", "text": "Сообщи Старейшине, что развалины очищены"},
	 ],
	 "reward": {"gold": 900, "xp": 800, "items": [["mana", 5]]}},
	{"id": "ch_orc_camp", "title": "Орочий лагерь", "min_level": 20,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Получи от Старейшины приказ о лагере орков"},
		{"type": "kill", "target": "orc", "count": 6, "text": "Побей 6 орков"},
		{"type": "kill", "target": "boss", "count": 1, "text": "Победи троллья-вожака"},
		{"type": "talk", "npc": "quest", "text": "Отчитайся перед Старейшиной о лагере"},
	 ],
	 "reward": {"gold": 1500, "xp": 1300, "items": [["blade", 1], ["potion", 5]]}},
	{"id": "ch_herbs", "title": "Сбор для лекаря", "min_level": 2,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Попроси Старейшину о травах для лекаря"},
		{"type": "collect", "npc": "quest", "item": "herb", "count": 4, "text": "Принеси Старейшине 4 красные травы"},
		{"type": "kill", "target": "slime", "count": 3, "text": "Убей 3 слайма на дороге"},
		{"type": "talk", "npc": "quest", "text": "Доложи Старейшине о выполненном"},
	 ],
	 "reward": {"gold": 250, "xp": 200, "items": [["potion", 3]]}},
	{"id": "ch_pelts", "title": "Пушистые трофеи", "min_level": 3,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Попроси Старейшину о трофеях для ремесленников"},
		{"type": "collect", "npc": "quest", "item": "jellopy", "count": 5, "text": "Принеси Старейшине 5 желеек"},
		{"type": "talk", "npc": "quest", "text": "Доложи о желейках Старейшине"},
		{"type": "collect", "npc": "quest", "item": "feather", "count": 3, "text": "Принеси Старейшине 3 пера"},
		{"type": "talk", "npc": "quest", "text": "Сдай перья Старейшине"},
	 ],
	 "reward": {"gold": 300, "xp": 260, "items": [["potion", 2]]}},
	{"id": "ch_smile", "title": "Улыбка господина Смайла", "min_level": 5,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Попроси Старейшину о диковинке мистера Смайла"},
		{"type": "collect", "npc": "quest", "item": "jellopy", "count": 10, "text": "Принеси Старейшине 10 желеек"},
		{"type": "talk", "npc": "quest", "text": "Передай желейки Старейшине"},
		{"type": "collect", "npc": "quest", "item": "fluff", "count": 10, "text": "Принеси Старейшине 10 пуха"},
		{"type": "talk", "npc": "quest", "text": "Передай пух Старейшине"},
		{"type": "collect", "npc": "quest", "item": "clover", "count": 10, "text": "Принеси Старейшине 10 клеверов"},
		{"type": "talk", "npc": "quest", "text": "Сдай клевер Старейшине"},
	 ],
	 "reward": {"gold": 400, "xp": 320, "items": [["potion", 3]]}},
	{"id": "ch_elin", "title": "Кукла для Элин", "min_level": 2,
	 "steps": [
		{"type": "talk", "npc": "quest", "text": "Поговори со Старейшиной о капризной девочке Элин"},
		{"type": "collect_any", "npc": "quest", "items": ["poring_doll", "chonchon_doll", "stuffed_doll", "grasshopper_doll", "spore_doll", "osiris_doll", "baphomet_doll", "raccoon_doll", "monkey_doll"], "count": 1, "text": "Принеси Старейшине любую куклу для Элин"},
		{"type": "talk", "npc": "quest", "text": "Отдай куклу Элин через Старейшину"},
	 ],
	 "reward": {"gold": 120, "xp": 90, "items": [["potion", 2]]}},
]

# ---------- Точки ----------
const SPAWN_POINT := Vector2(32 * TILE, 36 * TILE)
const NPC_SHOP_POS := Vector2(30 * TILE, 33 * TILE)
const NPC_QUEST_POS := Vector2(35 * TILE, 33 * TILE)

## Список спавнов мобов: [тип, x, y]
const MOB_SPAWNS := [
	["slime", 20, 28], ["slime", 24, 31], ["slime", 17, 34], ["slime", 26, 26],
	["slime", 22, 38], ["slime", 28, 34], ["slime", 15, 30], ["slime", 30, 29],
	["slime", 19, 42], ["slime", 27, 41],
	["wolf", 12, 20], ["wolf", 15, 17], ["wolf", 9, 24], ["wolf", 18, 14],
	["wolf", 44, 22], ["wolf", 47, 26], ["wolf", 41, 18], ["wolf", 50, 20],
	["golem", 8, 48], ["golem", 12, 52], ["golem", 6, 44],
	["zombie", 10, 12], ["zombie", 14, 9], ["zombie", 7, 16],
	["poporing", 33, 20], ["poporing", 36, 24], ["poporing", 30, 17],
	["marin", 40, 40], ["marin", 44, 44], ["marin", 37, 45],
	["orc", 46, 12], ["orc", 50, 16], ["orc", 43, 9],
	["boss", 52, 52],
]

var _tiles: PackedByteArray = PackedByteArray()
var _rng_seed := 1337


func _ready() -> void:
	_build_map()


func _hash_s(x: int, y: int, seed_v: int) -> int:
	var h: int = x * 374761393 + y * 668265263 + seed_v
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _hash(x: int, y: int) -> int:
	return _hash_s(x, y, _rng_seed)


## Тайл одной клетки карты. Геометрия зависит от категории карты (rAthena-название).
func _gen_tile(x: int, y: int, seed_v: int, cat: String) -> int:
	var n := _hash_s(x, y, seed_v) % 1000
	if cat == "dungeon" or cat == "indoor" or cat == "pvp":
		# подземелье / помещение: каменный пол, стены по краям, редкие камни
		var t := T_STONE
		if x < 2 or y < 2 or x > MAP_W - 3 or y > MAP_H - 3:
			t = T_ROCK
		elif n < 60 and n % 2 == 0:
			t = T_ROCK
		return t
	var t2 := T_GRASS
	if n < 190:
		t2 = T_GRASS2
	var road := absi(x - 32) <= 2 or absi(y - 34) <= 1
	if road:
		t2 = T_STONE
	if cat == "city":
		var dl := Vector2(x - 8, y - 8).length()
		var dr := Vector2(x - 56, y - 14).length()
		if dl < 6.5 or dr < 5.5:
			t2 = T_WATER
		elif (dl < 8.0 or dr < 7.0) and n % 3 != 0:
			t2 = T_SAND
	else:
		# поле: небольшой пруд по seed
		var pc := Vector2(float(seed_v % 48) + 8.0, float((seed_v / 48) % 48) + 8.0)
		if Vector2(x, y).distance_to(pc) < 4.0 and not road:
			t2 = T_WATER
	if x < 16 and y > 40 and n % 4 != 0:
		t2 = T_STONE
	if not road and (n > 880 or (x < 5 or x > MAP_W - 6 or y < 5 or y > MAP_H - 6)):
		if t2 == T_GRASS or t2 == T_GRASS2:
			t2 = T_TREE
	if n in [137, 244, 351] and t2 != T_WATER and not road:
		t2 = T_ROCK
	return t2


func _gen_tiles(seed_v: int, cat: String) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(MAP_W * MAP_H)
	for y in MAP_H:
		for x in MAP_W:
			out[y * MAP_W + x] = _gen_tile(x, y, seed_v, cat)
	return out


func _build_map() -> void:
	_load_registry()
	_active = ""
	activate_map(DEFAULT_MAP)


func pos_to_index(x: int, y: int) -> int:
	return y * MAP_W + x


func tile_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= MAP_W or y >= MAP_H:
		return T_TREE
	return _tiles[pos_to_index(x, y)]


func tile_at_world(world_pos: Vector2) -> int:
	return tile_at(int(world_pos.x / TILE), int(world_pos.y / TILE))


func is_walkable(world_pos: Vector2) -> bool:
	if world_pos.x < 0 or world_pos.y < 0 or world_pos.x >= WORLD_SIZE.x or world_pos.y >= WORLD_SIZE.y:
		return false
	var t := tile_at_world(world_pos)
	return not BLOCKING.get(t, false)


## Двигает позицию с проверкой коллизий по осям (скольжение вдоль стен)
func move_with_collision(from: Vector2, delta: Vector2) -> Vector2:
	var res := from
	var nx := res + Vector2(delta.x, 0)
	if is_walkable(nx + Vector2(0, 18)):
		res.x = nx.x
	var ny := res + Vector2(0, delta.y)
	if is_walkable(ny + Vector2(0, 18)):
		res.y = ny.y
	return res


## Начальные характеристики класса
## Таблицы HP/SP по уровням из rAthena db/re/job_basepoints.yml (BaseHp/BaseSp).
## Классы: Swordman/Mage/Archer/Crusader/Wizard/Hunter. Значения уровня 1 совпадают с балансом игры,
## рост за уровень повторяет форму реальных таблиц rAthena.
# rAthena db/re/job_basepoints.yml (BaseHp), 99 уровней, масштаб подобран по уровню 50
const HP_TABLE := {
	"sword": [
	160, 184, 212, 244, 280, 316, 356, 400, 444, 492,
	544, 596, 652, 712, 776, 840, 908, 980, 1052, 1128,
	1208, 1288, 1372, 1460, 1552, 1644, 1740, 1840, 1940, 2044,
	2152, 2260, 2372, 2488, 2608, 2728, 2852, 2980, 3108, 3240,
	3376, 3512, 3652, 3796, 3944, 4092, 4244, 4400, 4556, 4716,
	4880, 5044, 5212, 5384, 5560, 5736, 5916, 6100, 6284, 6472,
	6664, 6856, 7052, 7252, 7456, 7660, 7868, 8080, 8292, 8508,
	8728, 8948, 9172, 9400, 9632, 9864, 10100, 10340, 10580, 10824,
	11072, 11320, 11572, 11828, 12088, 12348, 12612, 12880, 13148, 13420,
	13696, 13972, 14252, 14536, 14824, 15112, 15404, 15700, 15996,
	],
	"mage": [
	105, 121, 136, 152, 171, 189, 207, 226, 247, 268,
	289, 312, 336, 360, 386, 412, 438, 465, 494, 522,
	551, 583, 614, 646, 680, 714, 748, 782, 819, 856,
	892, 932, 971, 1011, 1053, 1095, 1137, 1179, 1223, 1268,
	1312, 1360, 1407, 1454, 1504, 1554, 1604, 1654, 1706, 1759,
	1812, 1867, 1922, 1977, 2035, 2092, 2150, 2208, 2268, 2329,
	2389, 2452, 2515, 2578, 2644, 2709, 2775, 2841, 2909, 2977,
	3045, 3116, 3187, 3258, 3332, 3405, 3479, 3552, 3628, 3704,
	3781, 3859, 3938, 4017, 4098, 4180, 4261, 4342, 4426, 4510,
	4594, 4681, 4768, 4854, 4944, 5033, 5122, 5211, 5303,
	],
	"archer": [
	125, 144, 166, 188, 212, 238, 266, 294, 325, 356,
	391, 425, 462, 500, 541, 581, 625, 669, 716, 762,
	812, 862, 916, 969, 1025, 1081, 1141, 1200, 1262, 1325,
	1391, 1456, 1525, 1594, 1666, 1738, 1812, 1888, 1966, 2044,
	2125, 2206, 2291, 2375, 2462, 2550, 2641, 2731, 2825, 2919,
	3016, 3113, 3213, 3313, 3416, 3519, 3625, 3732, 3841, 3950,
	4063, 4175, 4291, 4407, 4525, 4644, 4766, 4888, 5013, 5138,
	5266, 5394, 5525, 5657, 5791, 5926, 6063, 6201, 6341, 6482,
	6626, 6769, 6916, 7063, 7213, 7363, 7516, 7669, 7826, 7982,
	8141, 8301, 8463, 8626, 8791, 8957, 9126, 9295, 9466,
	],
	"paladin": [
	200, 235, 280, 310, 405, 470, 540, 640, 735, 825,
	920, 1020, 1125, 1235, 1355, 1480, 1610, 1745, 1885, 2030,
	2180, 2335, 2495, 2660, 2835, 3015, 3200, 3390, 3585, 3785,
	3990, 4200, 4415, 4635, 4865, 5100, 5340, 5585, 5835, 6090,
	6350, 6615, 6885, 7160, 7445, 7735, 8030, 8330, 8635, 8945,
	9260, 9580, 9905, 10235, 10575, 10920, 11270, 11625, 11985, 12350,
	12720, 13095, 13475, 13860, 14255, 14655, 15060, 15470, 15885, 16305,
	16730, 17160, 17595, 18035, 18485, 18940, 19400, 19865, 20335, 20810,
	21290, 21775, 22265, 22760, 23265, 23775, 24290, 24810, 25335, 25865,
	26400, 26940, 27485, 28035, 28595, 29160, 29730, 30305, 30885,
	],
	"high_mage": [
	130, 150, 172, 195, 221, 247, 276, 306, 338, 374,
	410, 448, 488, 530, 572, 618, 663, 712, 760, 812,
	868, 923, 982, 1040, 1102, 1164, 1228, 1294, 1362, 1433,
	1505, 1580, 1654, 1732, 1810, 1892, 1973, 2057, 2142, 2230,
	2320, 2412, 2506, 2600, 2698, 2795, 2896, 2996, 3100, 3208,
	3315, 3426, 3536, 3650, 3764, 3881, 3998, 4118, 4238, 4362,
	4489, 4615, 4745, 4875, 5009, 5142, 5278, 5415, 5555, 5698,
	5841, 5987, 6133, 6283, 6432, 6585, 6738, 6894, 7050, 7209,
	7372, 7534, 7700, 7866, 8035, 8204, 8376, 8548, 8724, 8902,
	9081, 9263, 9445, 9631, 9816, 10004, 10193, 10385, 10576,
	],
	"ranger": [
	160, 188, 220, 252, 288, 328, 372, 420, 472, 528,
	584, 644, 708, 776, 848, 924, 1000, 1080, 1164, 1252,
	1344, 1440, 1540, 1640, 1744, 1852, 1964, 2080, 2200, 2324,
	2448, 2576, 2708, 2844, 2984, 3128, 3272, 3420, 3572, 3728,
	3888, 4052, 4220, 4388, 4560, 4736, 4916, 5100, 5288, 5480,
	5672, 5868, 6068, 6272, 6480, 6692, 6904, 7120, 7340, 7564,
	7792, 8024, 8260, 8496, 8736, 8980, 9228, 9480, 9736, 9996,
	10256, 10520, 10788, 11060, 11336, 11616, 11896, 12180, 12468, 12760,
	13056, 13356, 13660, 13964, 14272, 14584, 14900, 15220, 15544, 15872,
	16200, 16532, 16868, 17208, 17552, 17900, 18248, 18600, 18956,
	],
}

# rAthena db/re/job_basepoints.yml (BaseSp), 99 уровней, масштаб подобран по уровню 50
const SP_TABLE := {
	"sword": [
	40, 47, 53, 60, 67, 73, 80, 87, 93, 100,
	107, 113, 120, 127, 133, 140, 147, 153, 160, 167,
	173, 180, 187, 193, 200, 207, 213, 220, 227, 233,
	240, 247, 253, 260, 267, 273, 280, 287, 293, 300,
	307, 313, 320, 327, 333, 340, 347, 353, 360, 367,
	374, 380, 387, 394, 400, 407, 414, 420, 427, 434,
	440, 447, 454, 460, 467, 474, 480, 487, 494, 500,
	507, 514, 520, 527, 534, 541, 547, 554, 561, 567,
	574, 581, 587, 594, 601, 607, 614, 621, 627, 634,
	641, 647, 654, 661, 667, 674, 681, 687, 694,
	],
	"mage": [
	90, 124, 158, 191, 225, 259, 292, 326, 360, 394,
	428, 461, 495, 529, 562, 596, 630, 664, 698, 731,
	765, 799, 832, 866, 900, 934, 968, 1001, 1035, 1069,
	1102, 1136, 1170, 1204, 1238, 1271, 1305, 1339, 1372, 1406,
	1440, 1474, 1508, 1541, 1575, 1609, 1642, 1676, 1710, 1744,
	1778, 1812, 1845, 1879, 1913, 1947, 1980, 2014, 2048, 2082,
	2115, 2149, 2183, 2217, 2250, 2284, 2318, 2352, 2385, 2419,
	2453, 2487, 2520, 2554, 2588, 2622, 2655, 2689, 2723, 2757,
	2790, 2824, 2858, 2892, 2925, 2959, 2993, 3027, 3060, 3094,
	3128, 3162, 3195, 3229, 3263, 3297, 3330, 3364, 3398,
	],
	"archer": [
	55, 64, 73, 82, 92, 101, 110, 119, 128, 138,
	147, 156, 165, 174, 183, 192, 202, 211, 220, 229,
	238, 248, 257, 266, 275, 284, 293, 302, 312, 321,
	330, 339, 348, 358, 367, 376, 385, 394, 403, 412,
	422, 431, 440, 449, 458, 468, 477, 486, 495, 504,
	513, 522, 531, 541, 550, 559, 568, 577, 586, 596,
	605, 614, 623, 632, 641, 651, 660, 669, 678, 687,
	696, 706, 715, 724, 733, 742, 751, 761, 770, 779,
	788, 797, 806, 816, 825, 834, 843, 852, 861, 871,
	880, 889, 898, 907, 916, 926, 935, 944, 953,
	],
	"paladin": [
	60, 81, 103, 120, 141, 163, 180, 201, 223, 244,
	261, 283, 304, 321, 343, 364, 381, 403, 424, 446,
	463, 484, 506, 523, 544, 566, 583, 604, 626, 647,
	664, 686, 707, 724, 746, 767, 784, 806, 827, 849,
	866, 887, 909, 926, 947, 969, 986, 1007, 1029, 1050,
	1067, 1089, 1110, 1127, 1149, 1170, 1187, 1209, 1230, 1251,
	1269, 1290, 1311, 1329, 1350, 1371, 1389, 1410, 1431, 1453,
	1470, 1491, 1513, 1530, 1551, 1573, 1590, 1611, 1633, 1654,
	1671, 1693, 1714, 1731, 1753, 1774, 1791, 1813, 1834, 1856,
	1873, 1894, 1916, 1933, 1954, 1976, 1993, 2014, 2036,
	],
	"high_mage": [
	130, 192, 253, 315, 376, 438, 499, 561, 623, 684,
	746, 807, 869, 931, 992, 1054, 1115, 1177, 1238, 1300,
	1362, 1423, 1485, 1546, 1608, 1669, 1731, 1793, 1854, 1916,
	1977, 2039, 2101, 2162, 2224, 2285, 2347, 2408, 2470, 2532,
	2593, 2655, 2716, 2778, 2839, 2901, 2963, 3024, 3086, 3147,
	3209, 3270, 3332, 3393, 3455, 3516, 3578, 3640, 3701, 3763,
	3824, 3886, 3947, 4009, 4071, 4132, 4194, 4255, 4317, 4378,
	4440, 4502, 4563, 4625, 4686, 4748, 4809, 4871, 4933, 4994,
	5056, 5117, 5179, 5240, 5302, 5364, 5425, 5487, 5548, 5610,
	5671, 5733, 5795, 5856, 5918, 5979, 6041, 6102, 6164,
	],
	"ranger": [
	75, 96, 118, 139, 161, 182, 204, 225, 246, 268,
	289, 311, 332, 354, 375, 396, 418, 439, 461, 482,
	504, 525, 546, 568, 589, 611, 632, 654, 675, 696,
	718, 739, 761, 782, 804, 825, 846, 868, 889, 911,
	932, 954, 975, 996, 1018, 1039, 1061, 1082, 1104, 1125,
	1146, 1168, 1189, 1211, 1232, 1254, 1275, 1296, 1318, 1339,
	1361, 1382, 1404, 1425, 1446, 1468, 1489, 1511, 1532, 1554,
	1575, 1596, 1618, 1639, 1661, 1682, 1704, 1725, 1746, 1768,
	1789, 1811, 1832, 1854, 1875, 1896, 1918, 1939, 1961, 1982,
	2004, 2025, 2046, 2068, 2089, 2111, 2132, 2154, 2175,
	],
}

# Кривая опыта: rAthena db/re/job_exp.yml (BaseExp), масштаб подобран так, чтобы уровень 1 = 155 XP, как было в игре.
const XP_CURVE_NEW: Array[int] = [
	155, 253, 420, 615, 892, 1056, 1163, 1256, 1376, 1510,
	1642, 1664, 1727, 1817, 1987, 2156, 2257, 2358, 2458, 2584,
	2735, 2912, 3115, 3421, 3673, 3924, 4173, 4420, 4666, 4911,
	5154, 5395, 5635, 5925, 6111, 6600, 6960, 7318, 7547, 7900,
	8252, 8477, 8948, 9293, 9389, 9853, 10315, 10896, 11474, 11926,
	12375, 12822, 13266, 13707, 14146, 14701, 15014, 15445, 15872, 16297,
	16483, 17138, 18023, 18669, 19543, 20413, 21045, 21905, 25287, 29337,
	31991, 35312, 37023, 38498, 40640, 42319, 43763, 44750, 49628, 55037,
	61036, 67688, 75066, 83248, 92322, 102385, 113545, 125921, 139646, 154868,
	171748, 190469, 211229, 234253, 259787, 288103, 319506, 354332, 2828412,
]

# ---------- ASPD (скорость атаки) из db/re/job_stats.yml ----------
# Значения BaseASPD в rAthena: меньше = быстрее. Переводим в секунды между ударами
# той же формулой, что использует rAthena для отображения ASPD.
const ASPD_BASE := {
	"sword": 47,      # Swordman / 1hSword
	"mage": 55,       # Mage / Staff
	"archer": 50,     # Archer / Bow
	"paladin": 43,    # Crusader / 1hSword
	"high_mage": 53,  # Wizard / Staff
	"ranger": 48,     # Hunter / Bow
}

# Штраф за уровень оружия: чем тяжелее оружие, тем медленнее.
const ASPD_WEAPON_PENALTY := {0: 0.0, 1: 0.0, 2: 0.15, 3: 0.35, 4: 0.6}


## Секунды между автоатаками. weapon_level 0..4 (0 = без оружия).
## rAthena: ASPD 200 = 0 сек между ударами, ASPD 0 = ~4 сек.
## В игре базовый удар был 0.6 с — берём тот же масштаб, но с разбросом по классу.
static func attack_interval(class_id: String, weapon_level: int = 1) -> float:
	var base: int = int(ASPD_BASE.get(class_id, 50))
	var penalty: float = float(ASPD_WEAPON_PENALTY.get(clampi(weapon_level, 0, 4), 0.0))
	# В rAthena больше ASPD = медленнее удар. Мечник (47) бьёт чаще мага (55).
	var interval: float = 0.35 + (float(base) - 40.0) * 0.025
	return clampf(interval + penalty, 0.35, 1.4)

func class_stats(class_id: String) -> Dictionary:
	var c: Dictionary = CLASSES_T2.get(class_id, CLASSES.get(class_id, CLASSES["sword"]))
	return {
		"max_hp": int(c["hp"]),
		"max_mp": int(c["mp"]),
		"atk": int(c["atk"]),
		"def": int(c["def"]),
		"speed": float(c["speed"]),
		"skills": c["skills"].duplicate(),
		"sprite": c["sprite"],
		"name": c["name"],
	}


## Максимум HP/SP на уровне по таблице rAthena (BaseHp/BaseSp).
## Уровень 1 = базовое значение класса из CLASSES/CLASSES_T2, дальше идём по таблице.
static func hp_at_level(class_id: String, level: int) -> int:
	var t: Array = HP_TABLE.get(class_id, HP_TABLE["sword"])
	var i := clampi(level - 1, 0, t.size() - 1)
	var base: int = int(class_stats_for(class_id).get("max_hp", 100))
	var t0: int = int(t[0])
	return base + (int(t[i]) - t0)


static func sp_at_level(class_id: String, level: int) -> int:
	var t: Array = SP_TABLE.get(class_id, SP_TABLE["sword"])
	var i := clampi(level - 1, 0, t.size() - 1)
	var base: int = int(class_stats_for(class_id).get("max_mp", 40))
	var t0: int = int(t[0])
	return base + (int(t[i]) - t0)


## Статы класса без учёта уровня (для расчёта таблиц).
static func class_stats_for(class_id: String) -> Dictionary:
	var c: Dictionary = CLASSES_T2.get(class_id, CLASSES.get(class_id, CLASSES["sword"]))
	return {"max_hp": int(c["hp"]), "max_mp": int(c["mp"])}


func xp_for_level(level: int) -> int:
	var i := clampi(level - 1, 0, XP_CURVE_NEW.size() - 1)
	if level > XP_CURVE_NEW.size():
		# за пределами таблицы продолжаем кривой с последним шагом
		var last := XP_CURVE_NEW[XP_CURVE_NEW.size() - 1]
		return last + (level - XP_CURVE_NEW.size()) * 600
	return XP_CURVE_NEW[i]


## Рост HP и SP за уровень: доля от роста мечника, взятая из таблиц rAthena
## Прирост HP за уровень из таблицы rAthena (BaseHp): разница между уровнями.
static func hp_per_level(class_id: String) -> int:
	var t: Array = HP_TABLE.get(class_id, HP_TABLE["sword"])
	if t.size() < 2:
		return 14
	return int(t[1]) - int(t[0])


## Прирост SP за уровень из таблицы rAthena (BaseSp): разница между уровнями.
static func sp_per_level(class_id: String) -> int:
	var t: Array = SP_TABLE.get(class_id, SP_TABLE["sword"])
	if t.size() < 2:
		return 6
	return int(t[1]) - int(t[0])


# ---------- Логика лута и экипировки (чистые функции, покрыты тестами) ----------

## Выбор предмета из таблицы моба. roll в [0, 1). Возвращает "" если ничего не выпало.
static func pick_loot(mob_type: String, roll: float) -> String:
	var table: Array = LOOT.get(mob_type, [])
	var total := 0
	for e in table:
		total += int(e[1])
	if total <= 0:
		return ""
	var r := clampf(roll, 0.0, 0.999999) * total
	var acc := 0.0
	for e in table:
		acc += float(e[1])
		if r < acc:
			return String(e[0])
	return ""


## Надеть оружие или броню из инвентаря. Старый предмет возвращается в инвентарь.
## Возвращает false, если предмета нет, он не экипируемый, или его нет в инвентаре.
static func equip(p: Dictionary, item_id: String) -> bool:
	var inv: Dictionary = p["inv"]
	if int(inv.get(item_id, 0)) <= 0 or not ITEMS.has(item_id):
		return false
	var kind: String = String(ITEMS[item_id].get("kind", ""))
	var slot := ""
	if kind == "weapon":
		slot = "eq_weapon"
	elif kind == "armor":
		slot = "eq_armor"
	else:
		return false
	inv[item_id] = int(inv[item_id]) - 1
	if int(inv[item_id]) <= 0:
		inv.erase(item_id)
	var old: String = String(p.get(slot, ""))
	if old != "":
		inv[old] = int(inv.get(old, 0)) + 1
	p[slot] = item_id
	return true


## Снять экипировку из слота ("eq_weapon" или "eq_armor") в инвентарь.
## Возвращает false, если слот неизвестен или пуст.
static func unequip(p: Dictionary, slot: String) -> bool:
	if slot != "eq_weapon" and slot != "eq_armor":
		return false
	var item_id: String = String(p.get(slot, ""))
	if item_id == "":
		return false
	var inv: Dictionary = p["inv"]
	inv[item_id] = int(inv.get(item_id, 0)) + 1
	p[slot] = ""
	return true


## Суммарные бонусы от надетой экипировки.
static func equip_bonus(p: Dictionary) -> Dictionary:
	var atk := 0
	var defense := 0
	var w: String = String(p.get("eq_weapon", ""))
	if w != "" and ITEMS.has(w):
		atk = int(ITEMS[w].get("atk", 0))
		# уровень улучшения оружия добавляет атаку
		atk += refine_bonus(w, int(p.get("refine_weapon", 0)))
	var a: String = String(p.get("eq_armor", ""))
	if a != "" and ITEMS.has(a):
		defense = int(ITEMS[a].get("def", 0))
		defense += refine_bonus(a, int(p.get("refine_armor", 0)))
	return {"atk": atk, "defense": defense}


# ---------- Мир: карты rAthena (1265), варпы, спавны ----------
# Данные: res://data/world_registry.json (собрано из npc/ и conf/maps_athena.conf).
# Каждая карта генерируется по своему имени (seed) и своей категории.
# Варп = портал на нашей карте; координаты rAthena пересчитываются в клетки 64x64.
const DEFAULT_MAP := "prontera"
const WORLD_JSON := "res://data/world_registry.json"
const MAX_MOBS_PER_MAP := 14
const PORTAL_RADIUS := 30.0
const MOB_LEVELS := {"slime": 1, "wolf": 3, "golem": 7, "boss": 12, "zombie": 17, "poporing": 30, "marin": 37, "orc": 45}

var _registry_ok := false
var _map_cat := {}       # имя -> категория
var _warps := {}         # имя карты -> Array[[x, y, dst, dx, dy]]
var _spawns := {}        # имя карты -> Array[[mob_id, count, level]]
var _tile_cache := {}    # имя -> PackedByteArray (с порталами)
var _portal_cache := {}  # имя -> Array[{tile, dst, src}]
var _active := ""


func _load_registry() -> void:
	if _registry_ok:
		return
	_registry_ok = true
	if not FileAccess.file_exists(WORLD_JSON):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(WORLD_JSON))
	if typeof(d) != TYPE_DICTIONARY:
		return
	for m in d.get("maps", []):
		_map_cat[String(m["name"])] = String(m["cat"])
	for w in d.get("warps", []):
		var src := String(w[0])
		if not _warps.has(src):
			_warps[src] = []
		_warps[src].append([int(w[1]), int(w[2]), String(w[3]), int(w[4]), int(w[5])])
	for sp in d.get("spawns", []):
		var mp := String(sp[0])
		if not _spawns.has(mp):
			_spawns[mp] = []
		_spawns[mp].append([int(sp[1]), int(sp[2]), int(sp[3])])


func map_exists(name: String) -> bool:
	_load_registry()
	return _map_cat.has(name)


func map_names() -> Array:
	_load_registry()
	return _map_cat.keys()


func map_category(name: String) -> String:
	_load_registry()
	return String(_map_cat.get(name, ""))


func spawns_for(name: String) -> Array:
	_load_registry()
	return _spawns.get(name, [])


## Стабильный seed карты по её имени (FNV-1a).
func map_seed(name: String) -> int:
	var h := 2166136261
	for c in name.to_utf8_buffer():
		h = ((h ^ int(c)) * 16777619) & 0x7fffffff
	return h


func tile_center(t: Vector2i) -> Vector2:
	return Vector2(t.x * TILE + TILE / 2, t.y * TILE + TILE / 2)


func _rescale(x: int, y: int) -> Vector2i:
	# координаты rAthena (примерно 0..400) -> клетки нашей карты
	return Vector2i(clampi(2 + x * (MAP_W - 5) / 400, 2, MAP_W - 3),
		clampi(2 + y * (MAP_H - 5) / 400, 2, MAP_H - 3))


## Порталы карты: [{tile: Vector2i, dst: String}]. Одна клетка — один портал.
func portals_for(name: String) -> Array:
	_load_registry()
	if _portal_cache.has(name):
		return _portal_cache[name]
	var out: Array = []
	var used := {}
	var seen := {}
	for w in _warps.get(name, []):
		var dst: String = w[2]
		if dst == name:
			continue
		var key := "%s|%d|%d" % [dst, w[0], w[1]]
		if seen.has(key):
			continue
		seen[key] = true
		var t := _rescale(int(w[0]), int(w[1]))
		while used.has(t):
			t.x = (t.x + 1) if t.x < MAP_W - 3 else 2
		used[t] = true
		out.append({"tile": t, "dst": dst})
	_portal_cache[name] = out
	return out


## Клетка портала, в которую попадает игрок при переходе из карты `from` в карту `name`.
## Ставится рядом с обратным порталом (если он есть), иначе в центр карты.
func arrival_pos(name: String, from: String) -> Vector2:
	var center := Vector2i(MAP_W / 2, MAP_H / 2)
	var target := center
	for pt in portals_for(name):
		if String(pt["dst"]) == from:
			var v: Vector2i = pt["tile"]
			target = Vector2i(clampi(v.x + (1 if v.x < MAP_W / 2 else -1) * 2, 1, MAP_W - 2),
				clampi(v.y + (1 if v.y < MAP_H / 2 else -1) * 2, 1, MAP_H - 2))
			break
	return tile_center(_nearest_walkable(name, target))


func _nearest_walkable(name: String, t: Vector2i) -> Vector2i:
	var tiles := map_tiles(name)
	for r in range(0, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := t.x + dx
				var y := t.y + dy
				if x < 1 or y < 1 or x >= MAP_W - 1 or y >= MAP_H - 1:
					continue
				if not BLOCKING.get(tiles[y * MAP_W + x], false):
					return Vector2i(x, y)
	return t


## Тайлы карты с расчищенными площадками порталов.
func map_tiles(name: String) -> PackedByteArray:
	if _tile_cache.has(name):
		return _tile_cache[name]
	var cat := map_category(name)
	if cat == "":
		cat = "city"
	var t := _gen_tiles(map_seed(name), cat)
	for pt in portals_for(name):
		var v: Vector2i = pt["tile"]
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var x := v.x + dx
				var y := v.y + dy
				if x >= 0 and y >= 0 and x < MAP_W and y < MAP_H:
					t[y * MAP_W + x] = T_STONE
	_tile_cache[name] = t
	return t


## Делает карту активной для коллизий и маршрутов (tile_at/is_walkable работают с ней).
func activate_map(name: String) -> void:
	if name == _active:
		return
	if not map_exists(name):
		name = DEFAULT_MAP
		if name == _active:
			return
	_active = name
	_tiles = map_tiles(name)


func active_map() -> String:
	return _active


## Портал, на котором стоит позиция (или {}).
func portal_at(name: String, pos: Vector2) -> Dictionary:
	var t := Vector2i(int(pos.x) / TILE, int(pos.y) / TILE)
	for pt in portals_for(name):
		if pt["tile"] == t:
			return pt
	return {}


## Случайная проходимая клетка карты (детерминированно по k).
func random_walkable(name: String, k: int) -> Vector2:
	var tiles := map_tiles(name)
	var s := (map_seed(name) + k * 7919) & 0x7fffffff
	for i in 400:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var x := 2 + s % (MAP_W - 4)
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var y := 2 + s % (MAP_H - 4)
		if not BLOCKING.get(tiles[y * MAP_W + x], false):
			return tile_center(Vector2i(x, y))
	return tile_center(Vector2i(MAP_W / 2, MAP_H / 2))


## Наш тип моба, ближайший по уровню к монстру rAthena.
func mob_type_for_level(lv: int) -> String:
	var best := "slime"
	var bd := 1000000
	for k in MOB_LEVELS:
		var d := absi(int(MOB_LEVELS[k]) - lv)
		if d < bd:
			bd = d
			best = k
	return best
