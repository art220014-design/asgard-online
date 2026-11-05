extends RefCounted
## Профессии (этап 3): обучение, уровни, добыча с узлов, крафт.
## Чистая логика без сети; функции возвращают текст ошибки или "" при успехе.
## Состояние игрока: {"learned": [id, ...], "xp": {id: int}}.

const MAX_LEARNED := 2
const MAX_LEVEL := 10
const GATHER_XP := 10
const CRAFT_XP := 15
const NODE_RESPAWN := 20.0
const GATHER_RANGE := 96.0
const TRAINER_RANGE := 170.0
const TRAINER_POS := Vector2(27 * 64, 31 * 64)

const PROFS := {
	"mining": {"name": "Горное дело", "kind": "gather"},
	"herbalism": {"name": "Травничество", "kind": "gather"},
	"woodcutting": {"name": "Лесорубство", "kind": "gather"},
	"alchemy": {"name": "Алхимия", "kind": "craft"},
	"smithing": {"name": "Кузнечное дело", "kind": "craft"},
}

# Узлы ресурсов: позиции на проходимой траве (проверены на сетке карты).
const NODES := [
	{"id": "ore_1", "prof": "mining", "item": "ore", "amount": 4, "min_level": 1,
	 "pos": Vector2(46 * 64 + 32, 46 * 64 + 32), "name": "Жила руды"},
	{"id": "ore_2", "prof": "mining", "item": "ore", "amount": 8, "min_level": 4,
	 "pos": Vector2(10 * 64 + 32, 36 * 64 + 32), "name": "Богатая жила"},
	{"id": "herb_1", "prof": "herbalism", "item": "herb", "amount": 1, "min_level": 1,
	 "pos": Vector2(24 * 64 + 32, 40 * 64 + 32), "name": "Куст трав"},
	{"id": "herb_2", "prof": "herbalism", "item": "herb", "amount": 1, "min_level": 1,
	 "pos": Vector2(42 * 64 + 32, 30 * 64 + 32), "name": "Поляна трав"},
	{"id": "wood_1", "prof": "woodcutting", "item": "wood", "amount": 1, "min_level": 1,
	 "pos": Vector2(14 * 64 + 32, 30 * 64 + 32), "name": "Старый дуб"},
	{"id": "wood_2", "prof": "woodcutting", "item": "wood", "amount": 1, "min_level": 1,
	 "pos": Vector2(50 * 64 + 32, 30 * 64 + 32), "name": "Ель"},
	{"id": "ore_3", "prof": "mining", "item": "ore", "amount": 4, "min_level": 1,
	 "pos": Vector2(38 * 64 + 32, 40 * 64 + 32), "name": "Жила у холма"},
	{"id": "ore_4", "prof": "mining", "item": "ore", "amount": 8, "min_level": 4,
	 "pos": Vector2(50 * 64 + 32, 42 * 64 + 32), "name": "Глубокая жила"},
	{"id": "herb_3", "prof": "herbalism", "item": "herb", "amount": 1, "min_level": 1,
	 "pos": Vector2(20 * 64 + 32, 24 * 64 + 32), "name": "Луговая трава"},
	{"id": "herb_4", "prof": "herbalism", "item": "herb", "amount": 1, "min_level": 1,
	 "pos": Vector2(40 * 64 + 32, 22 * 64 + 32), "name": "Лесной куст"},
	{"id": "wood_3", "prof": "woodcutting", "item": "wood", "amount": 1, "min_level": 1,
	 "pos": Vector2(10 * 64 + 32, 44 * 64 + 32), "name": "Бук"},
	{"id": "wood_4", "prof": "woodcutting", "item": "wood", "amount": 1, "min_level": 1,
	 "pos": Vector2(46 * 64 + 32, 36 * 64 + 32), "name": "Сосна"},
]

# Рецепты: inputs и output — пары [id, количество].
const RECIPES := [
	{"id": "potion_alch", "prof": "alchemy", "level": 1, "name": "Зелье лечения",
	 "inputs": [["herb", 2]], "output": ["potion", 1]},
	{"id": "mana_alch", "prof": "alchemy", "level": 3, "name": "Эликсир маны",
	 "inputs": [["herb", 3]], "output": ["mana", 1]},
	{"id": "blade_smith", "prof": "smithing", "level": 1, "name": "Стальной клинок",
	 "inputs": [["ore", 2], ["wood", 1]], "output": ["blade", 1]},
	{"id": "war_axe_smith", "prof": "smithing", "level": 5, "name": "Боевой топор",
	 "inputs": [["ore", 4], ["wood", 2]], "output": ["war_axe", 1]},
	{"id": "rA_cutter", "prof": "smithing", "level": 1, "name": "Cutter (rAthena, id 1204)",
	 "inputs": [["ore", 25]], "output": ["cutter", 1]},
	{"id": "rA_main_gauche", "prof": "smithing", "level": 1, "name": "Main Gauche (rAthena, id 1207)",
	 "inputs": [["ore", 50]], "output": ["main_gauche", 1]},
	{"id": "rA_axe", "prof": "smithing", "level": 1, "name": "Axe (rAthena, id 1301)",
	 "inputs": [["ore", 10]], "output": ["axe", 1]},
	{"id": "rA_battle_axe", "prof": "smithing", "level": 1, "name": "Battle Axe (rAthena, id 1351)",
	 "inputs": [["ore", 110]], "output": ["battle_axe", 1]},
	{"id": "rA_club", "prof": "smithing", "level": 1, "name": "Club (rAthena, id 1501)",
	 "inputs": [["ore", 3]], "output": ["club", 1]},
	{"id": "rA_mace", "prof": "smithing", "level": 1, "name": "Mace (rAthena, id 1504)",
	 "inputs": [["ore", 30]], "output": ["mace", 1]},
	{"id": "rA_javelin", "prof": "smithing", "level": 1, "name": "Javelin (rAthena, id 1401)",
	 "inputs": [["ore", 3]], "output": ["javelin", 1]},
	{"id": "rA_spear", "prof": "smithing", "level": 1, "name": "Spear (rAthena, id 1404)",
	 "inputs": [["ore", 35]], "output": ["spear", 1]},
	{"id": "rA_pike", "prof": "smithing", "level": 1, "name": "Pike (rAthena, id 1407)",
	 "inputs": [["ore", 70]], "output": ["pike", 1]},
]


static func new_state() -> Dictionary:
	return {"learned": [], "xp": {}}


## Уровень из опыта: 1 + sqrt(xp/20), не выше MAX_LEVEL.
static func level_for_xp(xp: int) -> int:
	if xp <= 0:
		return 1
	return mini(MAX_LEVEL, 1 + int(sqrt(float(xp) / 20.0)))


static func level_of(st: Dictionary, prof: String) -> int:
	return level_for_xp(int(st["xp"].get(prof, 0)))


static func knows(st: Dictionary, prof: String) -> bool:
	return (st["learned"] as Array).has(prof)


static func node_by_id(node_id: String) -> Dictionary:
	for n in NODES:
		if n["id"] == node_id:
			return n
	return {}


static func recipe_by_id(recipe_id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == recipe_id:
			return r
	return {}


static func trainer_near(pos: Vector2) -> bool:
	return pos.distance_to(TRAINER_POS) <= TRAINER_RANGE


## Изучение профессии. Возвращает "" или текст ошибки.
static func learn(st: Dictionary, prof: String) -> String:
	if not PROFS.has(prof):
		return "Нет такой профессии"
	if knows(st, prof):
		return "Профессия уже изучена"
	if (st["learned"] as Array).size() >= MAX_LEARNED:
		return "Можно изучить не больше двух профессий"
	(st["learned"] as Array).append(prof)
	return ""


## Проверка добычи. depleted — узел сейчас восстанавливается.
static func gather_check(node: Dictionary, st: Dictionary, pos: Vector2, depleted: bool) -> String:
	if node.is_empty():
		return "Нет такого ресурса"
	var prof: String = node["prof"]
	if not knows(st, prof):
		return "Сначала изучите профессию"
	if level_of(st, prof) < int(node["min_level"]):
		return "Нужен уровень %d" % int(node["min_level"])
	if pos.distance_to(node["pos"]) > GATHER_RANGE:
		return "Подойдите к ресурсу"
	if depleted:
		return "Ресурс ещё восстанавливается"
	return ""


## Добыча: кладёт ресурс в инвентарь и начисляет опыт. Возвращает количество.
static func gather(node: Dictionary, st: Dictionary, inv: Dictionary) -> int:
	var amount := int(node["amount"])
	var item: String = node["item"]
	inv[item] = int(inv.get(item, 0)) + amount
	var prof: String = node["prof"]
	st["xp"][prof] = int(st["xp"].get(prof, 0)) + GATHER_XP
	return amount


static func craft_check(recipe: Dictionary, st: Dictionary, inv: Dictionary) -> String:
	if recipe.is_empty():
		return "Нет такого рецепта"
	var prof: String = recipe["prof"]
	if not knows(st, prof):
		return "Сначала изучите профессию"
	if level_of(st, prof) < int(recipe["level"]):
		return "Нужен уровень %d" % int(recipe["level"])
	for pair in recipe["inputs"]:
		if int(inv.get(pair[0], 0)) < int(pair[1]):
			return "Не хватает материалов"
	return ""


## Крафт: списывает материалы, выдаёт результат, начисляет опыт.
static func craft(recipe: Dictionary, st: Dictionary, inv: Dictionary) -> String:
	var err := craft_check(recipe, st, inv)
	if err != "":
		return err
	for pair in recipe["inputs"]:
		var left := int(inv[pair[0]]) - int(pair[1])
		if left > 0:
			inv[pair[0]] = left
		else:
			inv.erase(pair[0])
	var out: Array = recipe["output"]
	inv[out[0]] = int(inv.get(out[0], 0)) + int(out[1])
	var prof: String = recipe["prof"]
	st["xp"][prof] = int(st["xp"].get(prof, 0)) + CRAFT_XP
	return ""
