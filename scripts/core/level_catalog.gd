class_name LevelCatalog
extends RefCounted
const WORLD_NAMES := ["Ancient Observatory", "Crystal Temple", "Golden Palace", "Forgotten Ruins", "Celestial Sanctuary"]
const WORLD_SUBTITLES := ["Where the heavens were first measured.", "Listen to the light beneath the stone.", "An empire, preserved in gold.", "What time takes, the forest returns.", "The last forge above the clouds."]
const TITLES := ["First Light", "Three of a Kind", "Buried Starlight", "The Watchmaker", "Celestial Steps", "The First Alignment", "Prismatic Echo", "Veins of Light", "The Frozen Choir", "Winter's Heart", "Beneath the Glass", "The Crystal Vault", "Gilded Horizon", "Turning the Heavens", "The Sun Dial", "A Golden Age", "The Royal Mechanism", "Heart of the Palace", "Keys to the Past", "The Silent Garden", "Lifting the Veil", "The Lost Causeway", "What Lies Beneath", "Keeper of Secrets", "Above the Clouds", "The Unknown Star", "Fragments of Eternity", "The Last Constellation", "Heaven's Machinery", "Astral Forge"]

static func generate(number: int, seed_override := -1) -> Dictionary:
	var level := clampi(number, 1, 30)
	var rng := RandomNumberGenerator.new()
	rng.seed = 91027 + level * 7919 if seed_override < 0 else seed_override
	var tiles: Array = []
	# Real horizontal layers: 18 / 30 / 42 / 54 tiles, every count divisible by three.
	var layers := 1 + int(level >= 3) + int(level >= 11) + int(level >= 23)
	for layer in range(layers):
		var rows := 3 if layer == 0 else 2
		for row in range(rows):
			for col in range(6):
				var p := Vector3((col - 2.5) * 1.24, layer * 0.83, (row - (rows - 1) * 0.5) * 1.37)
				if layer % 2 == 1: p += Vector3(0.27, 0, 0.27)
				var section := 0
				if level >= 13 and layer == 0 and col >= 4: section = 1
				if level >= 21 and layer == 0 and col <= 1: section = 2
				# Raised bridge above the rotor; moving sections pass underneath,
				# so rotation never interpenetrates relics on the same physical plane.
				if level >= 13 and section != 1: p.y += BoardState.BRIDGE_HEIGHT
				tiles.append({"id": tiles.size(), "kind": 0, "pos": p, "section": section, "state": "board", "special": "plain", "secret_parent": -1})
	var sim := BoardState.new()
	sim.tiles = tiles
	var order: Array[int] = []
	# Construct a geometric removal certificate before distributing matching triples.
	while order.size() < tiles.size():
		var choices := sim.available()
		assert(not choices.is_empty(), "Layout has a geometric cycle")
		var id: int = choices[rng.randi_range(0, choices.size() - 1)]
		order.append(id)
		tiles[id].state = "matched"
	var type_count := mini(12, 3 + int(level / 3))
	for i in range(order.size()):
		var t: Dictionary = tiles[order[i]]
		t.state = "board"
		var group := int(i / 3)
		t.kind = 2 if group == 0 else (group + level) % type_count
		if i >= 3 and level >= 7 and i % 8 == 4: t.special = "frozen"
		if i >= 6 and level >= 19 and i % 9 == 7: t.special = "locked"
		if i >= 6 and level >= 25 and i % 7 == 3: t.special = "mystery"
		if level >= 15 and i % 11 == 5: t.special = "golden"
		if i >= 6 and level >= 23 and i % 13 == 8: t.secret_parent = order[0]
	return {"number": level, "world": int((level - 1) / 6), "title": TITLES[level - 1], "tiles": tiles, "solution": order, "rotating": level >= 13, "moving": level >= 21, "seed": rng.seed}

static func daily(date_string: String) -> Dictionary:
	var result := generate(30, int(date_string.replace("-", "")) + 431)
	result["title"] = "Daily Alignment"
	result["daily"] = date_string
	return result
