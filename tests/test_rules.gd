extends SceneTree
var checks := 0
var failures := 0

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)

func _init() -> void:
	call_deferred("run")

func fresh(number: int) -> BoardState:
	var s := BoardState.new()
	s.load_level(LevelCatalog.generate(number))
	return s

func replay(s: BoardState, certificate: Array) -> void:
	for id in certificate:
		var r := s.select_tile(id)
		expect(r.ok, "Certificate move %d is legal" % id)
		expect(s.status != "lost", "Certificate never fills the tray")
	expect(s.status == "won" and s.tray.is_empty(), "Certificate clears all relics")

func run() -> void:
	for n in range(1,31):
		var data := LevelCatalog.generate(n)
		var s := BoardState.new()
		s.load_level(data)
		expect(s.tiles.size()%3 == 0,"Level %d has a multiple of three relics" % n)
		expect(s.available().size() >= 3,"Level %d has legal starting moves" % n)
		replay(s,data.solution)
		print("PASS expedition %02d — %d relics, no abilities" % [n,s.tiles.size()])
	for date in ["2026-10-29","2026-10-30","2026-11-01","2027-01-01"]:
		var data := LevelCatalog.daily(date)
		var s := BoardState.new()
		s.load_level(data)
		replay(s,data.solution)
		expect(data.tiles == LevelCatalog.daily(date).tiles,"Daily seed is deterministic")
	# Difficulty must increase in depth and required tray planning, while all
	# generated certificates remain legal for varied deterministic seeds.
	var peaks: Array[int] = []
	for n in [1,8,17,28]:
		var puzzle := fresh(n)
		var peak := 0
		for id in puzzle.solution:
			puzzle.select_tile(id)
			peak = maxi(peak,puzzle.tray.size())
		peaks.append(peak)
	expect(peaks[0] < peaks[1] and peaks[1] < peaks[2] and peaks[3] >= peaks[2],"Later tiers require progressively more tray planning")
	expect(LevelCatalog.generate(30).tiles.size() > LevelCatalog.generate(20).tiles.size(),"Final world adds another physical layer")
	for n in [7,13,19,23,27,30]:
		for seed_value in range(6):
			var data := LevelCatalog.generate(n,seed_value*977+42)
			var puzzle := BoardState.new()
			puzzle.load_level(data)
			replay(puzzle,data.solution)
	var opening := fresh(1)
	for i in range(3):
		var result := opening.select_tile(opening.solution[i])
		expect(result.matched.size() == (3 if i == 2 else 0),"Only completed triples emit match effects")
	var state := fresh(30)
	var original := state.snapshot()
	var covered := -1
	for tile in state.tiles:
		if not state.uncovered(tile.id): covered=tile.id; break
	expect(covered >= 0,"Multilayer level contains covered tiles")
	expect(not state.select_tile(covered).ok,"Covered tile selection is rejected")
	expect(state.snapshot() == original,"Invalid picks leave state untouched")
	var first: int = state.solution[0]
	state.select_tile(first)
	expect(state.undo(),"Undo is available")
	expect(state.snapshot() == original,"Undo exactly restores the board")
	for id in state.solution.slice(0,3): state.select_tile(id)
	expect(state.matches == 1 and state.key_found,"Key triple releases seals")
	for t in state.tiles:
		if t.special == "frozen" and state.uncovered(t.id): expect(state.blocked_reason(t.id).is_empty(),"First match thaws frost")
	var count_before := state.remaining()
	state.select_tile(state.available()[0])
	expect(state.shuffle_board(128),"Reweave succeeds with occupied tray")
	expect(state.remaining() == count_before and state.tray.is_empty(),"Reweave preserves unmatched relic count and returns tray")
	replay(state,state.solution)
	state=fresh(30)
	state.rotate_section()
	expect(is_equal_approx(state.angle,PI/4),"Rotor turns 45 degrees")
	state.move_section()
	expect(state.shifted,"Carriage shifts")
	state.undo()
	expect(not state.shifted,"Undo restores a moving mechanism")
	state.undo()
	expect(is_zero_approx(state.angle),"Undo restores the rotor")
	expect(BoardState.footprints_overlap(Vector3.ZERO,0,Vector3(.4,1,0),.6),"Oriented rectangles overlap")
	expect(not BoardState.footprints_overlap(Vector3.ZERO,0,Vector3(3,1,0),.6),"Separated rectangles do not overlap")
	expect(not BoardState.footprints_overlap(Vector3.ZERO,0,Vector3(BoardState.WIDTH,1,0),0),"Touching edges are not coverage")
	# Seven unrelated relics trigger loss; a triple at the seventh slot resolves first.
	var sample := {"tiles":[],"solution":[]}
	for i in range(12): sample.tiles.append({"id":i,"kind":i,"pos":Vector3(i*2,0,0),"section":0,"state":"board","special":"plain","secret_parent":-1})
	state.load_level(sample)
	for i in range(7): state.select_tile(i)
	expect(state.status == "lost","Seven unmatched relics lose")
	expect(state.add_slot() and state.status == "playing","Eighth slot recovers a full seven-slot tray")
	expect(not state.add_slot(),"Only one extra slot is allowed")
	state.load_level(sample)
	state.tiles[0].kind=11;state.tiles[1].kind=11;state.tiles[6].kind=11
	for i in range(7): state.select_tile(i)
	expect(state.status == "playing" and state.tray.size() == 4 and state.matches == 1,"Seventh-slot triple clears before failure")
	state=fresh(19)
	var before_hint := state.snapshot()
	var hint := state.hint()
	expect(hint >= 0 and hint == state.solution[0],"Hint returns a proven move")
	expect(state.snapshot() == before_hint,"Hint search is nonmutating")
	state=fresh(30)
	for t in state.tiles:
		if t.secret_parent >= 0:
			expect(not state.secret_open(t),"Secret chamber starts closed")
			for id in state.solution.slice(0,3): state.select_tile(id)
			expect(state.secret_open(t),"Matching guardian opens chamber")
			break
	print("RULES: %d assertions, %d failures" % [checks,failures])
	quit(1 if failures else 0)
