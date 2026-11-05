extends RefCounted
## Поиск пути по сетке тайлов (A*, 4 направления). Чистая логика, без узлов сцены.


static func find(w: int, h: int, blocked: Callable, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if start == goal:
		return out
	if not _inside(w, h, goal) or blocked.call(goal):
		return out
	var came := {}
	var g := {start: 0}
	var open: Array = [[_h(start, goal), start]]
	while not open.is_empty():
		var best := 0
		for i in range(1, open.size()):
			if open[i][0] < open[best][0]:
				best = i
		var cur: Vector2i = open[best][1]
		open.remove_at(best)
		if cur == goal:
			return _rebuild(came, cur, start)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + d
			if not _inside(w, h, nb):
				continue
			if nb != goal and blocked.call(nb):
				continue
			var ng: int = int(g[cur]) + 1
			if not g.has(nb) or ng < int(g[nb]):
				g[nb] = ng
				came[nb] = cur
				open.append([ng + _h(nb, goal), nb])
	return out


static func _inside(w: int, h: int, p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < w and p.y < h


static func _h(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func _rebuild(came: Dictionary, cur: Vector2i, start: Vector2i) -> Array[Vector2i]:
	var rev: Array[Vector2i] = [cur]
	while came.has(cur):
		cur = came[cur]
		if cur == start:
			break
		rev.append(cur)
	rev.reverse()
	return rev
