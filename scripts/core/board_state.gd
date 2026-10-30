class_name BoardState
extends RefCounted
## Authoritative puzzle simulation. Coordinates and OBB overlap are also used by the 3D view.
const WIDTH := 1.16
const DEPTH := 1.28
const BRIDGE_HEIGHT := 1.25
const SHIFT_OFFSET := Vector3(1.45, -BRIDGE_HEIGHT, 0)
const CARRIAGE_HOME := Vector3(-2.48, BRIDGE_HEIGHT - 0.09, 0)
const NAMES := ["Golden Compass", "Crystal Sphere", "Ancient Key", "Mechanical Gear", "Silver Hourglass", "Magic Lantern", "Bronze Telescope", "Celestial Crown", "Golden Astrolabe", "Ancient Relic", "Emerald Crystal", "Astral Vessel"]
const ROTOR_CENTER := Vector3(2.35, 0, 0)
var tiles: Array = []
var tray: Array[int] = []
var capacity := 7
var matches := 0
var golden_matches := 0
var key_found := false
var status := "playing"
var angle := 0.0
var shifted := false
var history: Array = []
var solution: Array = []

func load_level(data: Dictionary) -> void:
	tiles = data.tiles.duplicate(true)
	solution = data.solution.duplicate()
	tray.clear()
	history.clear()
	capacity = 7
	matches = 0
	golden_matches = 0
	key_found = false
	status = "playing"
	angle = 0.0
	shifted = false

func position_of(tile: Dictionary) -> Vector3:
	var p: Vector3 = tile.pos
	if tile.section == 1:
		p = ROTOR_CENTER + (p - ROTOR_CENTER).rotated(Vector3.UP, angle)
	elif tile.section == 2 and shifted:
		p += SHIFT_OFFSET
	return p

func yaw_of(tile: Dictionary) -> float:
	return angle if tile.section == 1 else 0.0

static func footprints_overlap(a: Vector3, ay: float, b: Vector3, by: float) -> bool:
	# Separating Axis Theorem for two oriented rectangular footprints. Edge contact is not cover.
	var axes_a := [Vector2(cos(ay), -sin(ay)), Vector2(sin(ay), cos(ay))]
	var axes_b := [Vector2(cos(by), -sin(by)), Vector2(sin(by), cos(by))]
	var delta := Vector2(b.x - a.x, b.z - a.z)
	for axis in axes_a + axes_b:
		var ra: float = abs(axis.dot(axes_a[0])) * WIDTH * 0.5 + abs(axis.dot(axes_a[1])) * DEPTH * 0.5
		var rb: float = abs(axis.dot(axes_b[0])) * WIDTH * 0.5 + abs(axis.dot(axes_b[1])) * DEPTH * 0.5
		if abs(delta.dot(axis)) >= ra + rb - 0.035:
			return false
	return true

func uncovered(id: int) -> bool:
	var tile: Dictionary = tiles[id]
	if tile.state != "board": return false
	var p := position_of(tile)
	for other in tiles:
		if other.id == id or other.state != "board": continue
		var op := position_of(other)
		if op.y > p.y + 0.22 and footprints_overlap(p, yaw_of(tile), op, yaw_of(other)):
			return false
	return true

func secret_open(tile: Dictionary) -> bool:
	return tile.secret_parent < 0 or tiles[tile.secret_parent].state == "matched"

func blocked_reason(id: int) -> String:
	var t: Dictionary = tiles[id]
	if t.state != "board": return "This relic has already been collected."
	if not uncovered(id): return "Clear the relics resting above this tile."
	if not secret_open(t): return "A hidden chamber. Match its guardian to open it."
	if t.special == "frozen" and matches == 0: return "Make a match anywhere to melt the frost."
	if t.special == "locked" and not key_found: return "Match three Ancient Keys to release the seals."
	return ""

func available() -> Array[int]:
	var ids: Array[int] = []
	for t in tiles:
		if blocked_reason(t.id).is_empty(): ids.append(t.id)
	return ids

func snapshot() -> Dictionary:
	return {"tiles": tiles.duplicate(true), "tray": tray.duplicate(), "capacity": capacity, "matches": matches, "golden_matches": golden_matches, "key_found": key_found, "status": status, "angle": angle, "shifted": shifted}

func restore(s: Dictionary) -> void:
	tiles = s.tiles.duplicate(true)
	tray.assign(s.tray)
	capacity = s.capacity
	matches = s.matches
	golden_matches = s.golden_matches
	key_found = s.key_found
	status = s.status
	angle = s.angle
	shifted = s.shifted

func select_tile(id: int, record := true) -> Dictionary:
	if status != "playing" or id < 0 or id >= tiles.size(): return {"ok": false}
	var reason := blocked_reason(id)
	if not reason.is_empty(): return {"ok": false, "reason": reason}
	if record:
		history.append(snapshot())
		if history.size() > 40: history.pop_front()
	tiles[id].state = "tray"
	tray.append(id)
	# Keep like relics adjacent, stable inside each group.
	tray.sort_custom(func(a: int, b: int) -> bool: return tiles[a].kind < tiles[b].kind)
	var triple: Array[int] = []
	for tid in tray:
		if tiles[tid].kind == tiles[id].kind: triple.append(tid)
	if triple.size() == 3:
		for tid in triple:
			tray.erase(tid)
			tiles[tid].state = "matched"
		matches += 1
		if tiles[id].kind == 2: key_found = true
		for tid in triple:
			if tiles[tid].special == "golden":
				golden_matches += 1
				break
	# Resolve matches BEFORE evaluating the seven-slot loss condition.
	if remaining() == 0 and tray.is_empty(): status = "won"
	elif tray.size() >= capacity: status = "lost"
	return {"ok": true, "matched": triple, "status": status}

func undo() -> bool:
	if history.is_empty(): return false
	restore(history.pop_back())
	return true

func remaining() -> int:
	var n := 0
	for t in tiles:
		if t.state != "matched": n += 1
	return n

func rotate_section() -> void:
	if status != "playing": return
	history.append(snapshot())
	angle = fmod(angle + PI / 4.0, TAU)

func move_section() -> void:
	if status != "playing": return
	history.append(snapshot())
	shifted = not shifted

func add_slot() -> bool:
	if capacity >= 8: return false
	history.append(snapshot())
	capacity = 8
	if status == "lost": status = "playing"
	return true

func shuffle_board(seed_value: int) -> bool:
	# Reweave returns held tiles, preserves completed matches and the remaining multiset.
	# Moving structures return home; forge heat removes remaining seals and opens chambers.
	if status == "won": return false
	history.append(snapshot())
	for id in tray: tiles[id].state = "board"
	tray.clear()
	angle = 0.0
	shifted = false
	status = "playing"
	var counts: Dictionary = {}
	for t in tiles:
		if t.state == "board":
			counts[t.kind] = counts.get(t.kind, 0) + 1
			t.special = "plain"
			t.secret_parent = -1
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var order: Array[int] = []
	while true:
		var choices := available()
		if choices.is_empty(): break
		var id: int = choices[rng.randi_range(0, choices.size() - 1)]
		order.append(id)
		tiles[id].state = "matched"
	var kinds: Array = []
	for kind in counts:
		assert(counts[kind] % 3 == 0)
		for i in range(counts[kind] / 3): kinds.append(kind)
	for i in range(kinds.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = kinds[i]
		kinds[i] = kinds[j]
		kinds[j] = tmp
	for i in range(order.size()):
		tiles[order[i]].kind = kinds[i / 3]
		tiles[order[i]].state = "board"
	solution = order
	return true

func hint(node_budget := 18000) -> int:
	# A bounded search returns only a move with a complete proven continuation.
	# Fast path: replay the level's construction certificate from the current state.
	var initial := snapshot()
	var first := -1
	var valid := true
	for id in solution:
		if tiles[id].state != "board": continue
		if first == -1: first = id
		var result := select_tile(id, false)
		if not result.ok or status == "lost":
			valid = false
			break
	var wins := valid and status == "won"
	restore(initial)
	if wins: return first
	var context := {"left": node_budget, "seen": {}}
	var path: Array[int] = []
	if _search(context, path):
		restore(initial)
		return path[0] if not path.is_empty() else -1
	restore(initial)
	return -1

func _search(context: Dictionary, path: Array[int]) -> bool:
	if status == "won": return true
	if status == "lost" or context.left <= 0: return false
	context.left -= 1
	var key := ""
	for t in tiles: key += t.state.left(1)
	if context.seen.has(key): return false
	context.seen[key] = true
	var options := available()
	var counts: Dictionary = {}
	for id in tray: counts[tiles[id].kind] = counts.get(tiles[id].kind, 0) + 1
	options.sort_custom(func(a: int, b: int) -> bool: return counts.get(tiles[a].kind, 0) > counts.get(tiles[b].kind, 0))
	var before := snapshot()
	for id in options:
		select_tile(id, false)
		path.append(id)
		if _search(context, path): return true
		path.pop_back()
		restore(before)
	return false
