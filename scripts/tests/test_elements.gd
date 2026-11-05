extends SceneTree
## Тесты стихий: таблица attr_fix из rAthena и её применение к урону.

const GD := preload("res://scripts/game_data.gd")

var _fails := 0
var _checks := 0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fails += 1
		print("FAIL: ", msg)


func _initialize() -> void:
	var gd = GD.new()
	root.add_child(gd)
	gd._ready()

	# --- структура таблицы
	_check(GD.ELEMENTS.size() == 10, "10 стихий")
	_check(GD.ATTR_FIX.has(1) and GD.ATTR_FIX.has(4), "уровни 1..4 присутствуют")
	for lv in [1, 2, 3, 4]:
		_check(GD.ATTR_FIX[lv].size() == 10, "уровень %d: 10 строк" % lv)
		for row in GD.ATTR_FIX[lv]:
			_check(row.size() == 10, "уровень %d: 10 столбцов" % lv)

	# --- нейтральная стихия по нейтральной цели = 100%
	_check(is_equal_approx(GD.element_multiplier("Neutral", 1, "Neutral"), 1.0),
		"нейтральный по нейтральному = 1.0")

	# --- известные клетки из attr_fix (проверено по файлу rAthena)
	# lv1: Fire по Water = 150, Water по Fire = 150? берём точные значения
	_check(is_equal_approx(GD.element_multiplier("Fire", 1, "Earth"), 1.5),
		"огонь по земле = 150%")
	_check(is_equal_approx(GD.element_multiplier("Water", 1, "Fire"), 1.5),
		"вода по огню = 150%")
	_check(is_equal_approx(GD.element_multiplier("Fire", 1, "Fire"), 0.25),
		"огонь по огню = 25%")
	_check(is_equal_approx(GD.element_multiplier("Water", 1, "Water"), 0.25),
		"вода по воде = 25%")
	_check(is_equal_approx(GD.element_multiplier("Neutral", 1, "Undead"), 1.0),
		"нейтральный по нежити = 100%")
	_check(is_equal_approx(GD.element_multiplier("Holy", 1, "Undead"), 1.5),
		"святой по нежити = 150%")
	_check(is_equal_approx(GD.element_multiplier("Ghost", 1, "Neutral"), 0.7),
		"призрак по нейтральному = 70%")

	# --- уровень стихии меняет множитель
	var lv1: float = GD.element_multiplier("Fire", 1, "Earth")
	var lv2: float = GD.element_multiplier("Fire", 2, "Earth")
	_check(lv1 != lv2 and lv2 >= lv1, "уровень стихии влияет: lv1=%.2f lv2=%.2f" % [lv1, lv2])

	# --- устойчивость к мусору
	_check(is_equal_approx(GD.element_multiplier("НетТакой", 1, "Neutral"), 1.0), "неизвестная стихия = 1.0")
	_check(is_equal_approx(GD.element_multiplier("Fire", 99, "Earth"), GD.element_multiplier("Fire", 4, "Earth")),
		"уровень выше 4 зажимается в 4")

	# --- у каждого моба есть стихия и уровень
	for key in GD.MOBS:
		var mb: Dictionary = GD.MOBS[key]
		_check(mb.has("element"), "%s: стихия задана" % key)
		_check(GD.ELEMENTS.has(String(mb.get("element", ""))), "%s: стихия корректна (%s)" % [key, mb.get("element", "")])
		_check(int(mb.get("element_level", 0)) >= 1 and int(mb.get("element_level", 0)) <= 4,
			"%s: уровень стихии 1..4" % key)

	# --- у каждого навыка есть стихия
	for sid in GD.SKILLS:
		var s: Dictionary = GD.SKILLS[sid]
		_check(GD.ELEMENTS.has(String(s.get("element", ""))), "навык %s: стихия (%s)" % [sid, s.get("element", "")])

	# --- стихии не ломают обычную атаку: нейтральный меч по земле = 100%
	_check(is_equal_approx(GD.element_multiplier(String(GD.SKILLS["slash"]["element"]), 1, "Earth"), 1.0),
		"обычный удар по волку = 100%")

	print("проверок стихий: %d, провалов: %d" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)
