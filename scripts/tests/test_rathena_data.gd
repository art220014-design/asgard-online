extends SceneTree
## Проверка данных, перенесённых из rAthena: магазины и каталог предметов.

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
	var gd = root.get_node_or_null("/root/GameData")
	_check(gd != null, "GameData доступен")
	var shops: Array = gd.rathena_shops()
	_check(shops.size() == 280, "магазинов 280 (получили %d)" % shops.size())
	var total := 0
	var bad_price := 0
	var missing := 0
	for s in shops:
		_check(String(s["name"]) != "", "у магазина есть имя")
		_check(s["items"].size() > 0, "магазин %s не пуст" % s["name"])
		for it in s["items"]:
			total += 1
			if int(it["price"]) < 0:
				bad_price += 1
			if gd.rathena_item(int(it["id"])).is_empty():
				missing += 1
	_check(total == 2541, "позиций продажи 2541 (получили %d)" % total)
	_check(bad_price == 0, "все цены неотрицательные (ошибок %d)" % bad_price)
	_check(missing == 0, "все товары есть в каталоге (нет %d)" % missing)
	var potion: Dictionary = gd.rathena_item(501)
	_check(String(potion.get("name", "")) == "Red Potion", "каталог: 501 = Red Potion")
	_check(int(potion.get("buy", 0)) == 50, "каталог: Red Potion стоит 50 (получили %s)" % str(potion.get("buy")))
	print("проверок rAthena-данных: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
	return false
