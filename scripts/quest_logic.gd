extends RefCounted
## Чистая логика квестов-цепочек: без сети и без узлов сцены, покрыта тестами.
## Состояние одной цепочки: {"step": int, "count": int, "claimed": bool}.


static func new_state() -> Dictionary:
	return {"step": 0, "count": 0, "claimed": false}


static func current_step(chain: Dictionary, st: Dictionary) -> Dictionary:
	var steps: Array = chain["steps"]
	var i := int(st.get("step", 0))
	if i < 0 or i >= steps.size():
		return {}
	return steps[i]


static func is_complete(chain: Dictionary, st: Dictionary) -> bool:
	return int(st.get("step", 0)) >= (chain["steps"] as Array).size()


## Убийство моба. Возвращает true, если прогресс изменился.
static func on_kill(chain: Dictionary, st: Dictionary, mob_type: String) -> bool:
	if bool(st.get("claimed", false)):
		return false
	var step := current_step(chain, st)
	if step.is_empty() or step["type"] != "kill" or step["target"] != mob_type:
		return false
	st["count"] = int(st.get("count", 0)) + 1
	if int(st["count"]) >= int(step["count"]):
		st["step"] = int(st.get("step", 0)) + 1
		st["count"] = 0
	return true


## Разговор с NPC. Шаг talk продвигает цепочку; collect сдаёт предмет из inv, collect_any — первый подходящий из items.
static func on_talk(chain: Dictionary, st: Dictionary, npc: String, level: int, inv: Dictionary = {}) -> bool:
	if bool(st.get("claimed", false)):
		return false
	if int(st.get("step", 0)) == 0 and level < int(chain.get("min_level", 1)):
		return false
	var step := current_step(chain, st)
	if step.is_empty() or step.get("npc", "") != npc:
		return false
	if step["type"] == "talk":
		pass
	elif step["type"] == "collect":
		if not has_items(step, inv):
			return false
		take_items(step, inv)
	elif step["type"] == "collect_any":
		var key := pick_any(step, inv)
		if key == "":
			return false
		take_items({"item": key, "count": step["count"]}, inv)
	else:
		return false
	st["step"] = int(st.get("step", 0)) + 1
	st["count"] = 0
	return true


static func has_items(step: Dictionary, inv: Dictionary) -> bool:
	return int(inv.get(String(step["item"]), 0)) >= int(step["count"])


static func pick_any(step: Dictionary, inv: Dictionary) -> String:
	for item in step["items"]:
		if int(inv.get(String(item), 0)) >= int(step["count"]):
			return String(item)
	return ""


static func take_items(step: Dictionary, inv: Dictionary) -> void:
	var item := String(step["item"])
	var left := int(inv.get(item, 0)) - int(step["count"])
	if left > 0:
		inv[item] = left
	else:
		inv.erase(item)


static func can_claim(chain: Dictionary, st: Dictionary, level: int) -> bool:
	if bool(st.get("claimed", false)):
		return false
	if not is_complete(chain, st):
		return false
	return level >= int(chain.get("min_level", 1))


## Сдача цепочки: помечает награду как полученную. Выдачу наград делает сервер.
static func claim(chain: Dictionary, st: Dictionary, level: int) -> bool:
	if not can_claim(chain, st, level):
		return false
	st["claimed"] = true
	return true
