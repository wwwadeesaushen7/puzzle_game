extends Node
## Versioned offline save. A previous complete save is kept if an interrupted write occurs.
const SAVE := "user://progress.json"
var data: Dictionary = defaults()
var session_abilities := 0

func defaults() -> Dictionary:
	return {"version": 1, "unlocked": 1, "coins": 120, "stars": {}, "daily": {}, "matches": 0, "golden": 0, "wins": 0, "tutorial": false, "settings": {"quality": 1 if OS.has_feature("mobile") else 2, "scale": 0.85 if OS.has_feature("mobile") else 1.0, "fps": 30 if OS.has_feature("mobile") else 60, "audio": true, "fullscreen": false}}

func _ready() -> void:
	load_save()

func load_save() -> void:
	for path in [SAVE, SAVE + ".bak"]:
		if not FileAccess.file_exists(path): continue
		var decoder := JSON.new()
		if decoder.parse(FileAccess.get_file_as_string(path)) != OK: continue
		var parsed = decoder.data
		if not parsed is Dictionary or parsed.get("version", 0) != 1: continue
		if not parsed.get("stars", {}) is Dictionary or not parsed.get("daily", {}) is Dictionary: continue
		var fresh := defaults()
		fresh.unlocked = clampi(int(parsed.get("unlocked", 1)), 1, 30)
		fresh.coins = clampi(int(parsed.get("coins", 120)), 0, 999999)
		for field in ["matches", "golden", "wins"]: fresh[field] = maxi(0, int(parsed.get(field, 0)))
		for key in parsed.get("stars", {}):
			if int(key) >= 1 and int(key) <= 30: fresh.stars[str(key)] = clampi(int(parsed.stars[key]), 0, 3)
		for key in parsed.get("daily", {}): fresh.daily[str(key)] = clampi(int(parsed.daily[key]), 0, 3)
		fresh.tutorial = bool(parsed.get("tutorial", false))
		var s = parsed.get("settings", {})
		if s is Dictionary:
			fresh.settings.quality = clampi(int(s.get("quality", 2)), 0, 3)
			fresh.settings.scale = clampf(float(s.get("scale", 1.0)), 0.5, 1.0)
			fresh.settings.fps = 60 if int(s.get("fps", 60)) == 60 else 30
			fresh.settings.audio = bool(s.get("audio", true))
			fresh.settings.fullscreen = bool(s.get("fullscreen", false))
		data = fresh
		return

func save() -> bool:
	var file := FileAccess.open(SAVE + ".tmp", FileAccess.WRITE)
	if file == null:
		push_warning("Progress could not be saved: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	var directory := DirAccess.open("user://")
	if directory.file_exists("progress.json"):
		if directory.file_exists("progress.json.bak"): directory.remove("progress.json.bak")
		if directory.rename("progress.json", "progress.json.bak") != OK: return false
	return directory.rename("progress.json.tmp", "progress.json") == OK

func spend(amount: int) -> bool:
	if data.coins < amount: return false
	data.coins -= amount
	save()
	return true

func complete(level: int, matches_count: int, golden_count: int, daily_key := "") -> Dictionary:
	var stars := maxi(1, 3 - session_abilities / 2)
	var table: Dictionary = data.stars if daily_key.is_empty() else data.daily
	var key := str(level) if daily_key.is_empty() else daily_key
	var previous := int(table.get(key, 0))
	var reward := 0
	if stars > previous:
		reward = (stars - previous) * 15 + (10 + golden_count * 5 if previous == 0 else 0)
		table[key] = stars
	if previous == 0:
		data.matches += matches_count
		data.golden += golden_count
		data.wins += 1
	data.coins += reward
	if daily_key.is_empty(): data.unlocked = maxi(data.unlocked, mini(30, level + 1))
	save()
	return {"stars": stars, "reward": reward}

func total_stars() -> int:
	var total := 0
	for n in data.stars.values(): total += int(n)
	return total

func achievements() -> Array:
	return [
		["First light", "Complete your first expedition", data.wins >= 1],
		["Star cartographer", "Earn 30 expedition stars", total_stars() >= 30],
		["Master of the forge", "Complete all 30 expeditions", data.stars.size() >= 30],
		["Gold keeper", "Match a golden relic", data.golden >= 1],
		["A daily ritual", "Complete three daily alignments", data.daily.size() >= 3],
		["Astral perfection", "Earn all 90 expedition stars", total_stars() >= 90]]
