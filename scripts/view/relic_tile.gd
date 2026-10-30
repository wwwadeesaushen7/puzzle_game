class_name RelicTile
extends Node3D
var tile_id := -1
var kind := -1
var body: StaticBody3D
var artifact: Node3D
var special_visual: Node3D
var halo: MeshInstance3D
var low := false
var signature := ""
static var cache: Dictionary = {}

static func model(asset: String, reduced := false) -> Node3D:
	var path := "res://assets/models/" + asset + ("_low" if reduced else "") + ".glb"
	if not cache.has(path): cache[path] = load(path)
	return cache[path].instantiate()

func setup(id: int, reduced: bool) -> void:
	tile_id = id
	low = reduced
	add_child(model("tile", reduced))
	body = StaticBody3D.new()
	body.set_meta("tile_id", id)
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(BoardState.WIDTH, 0.78, BoardState.DEPTH)
	shape.shape = box
	shape.position.y = 0.34
	body.add_child(shape)
	halo = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.675
	torus.rings = 48
	torus.ring_segments = 6
	halo.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("93e8dd")
	mat.emission_enabled = true
	mat.emission = Color("50a79e")
	mat.emission_energy_multiplier = 1.8
	halo.material_override = mat
	halo.position.y = 0.30
	halo.visible = false
	add_child(halo)

func update_appearance(tile: Dictionary, state: BoardState) -> void:
	var hidden := not state.secret_open(tile)
	var frozen: bool = tile.special == "frozen" and state.matches == 0
	var locked: bool = tile.special == "locked" and not state.key_found
	var mystery: bool = tile.special == "mystery" and not state.uncovered(tile.id) and tile.state == "board"
	var new_signature := str([tile.kind, hidden, frozen, locked, mystery, tile.special])
	if signature == new_signature: return
	signature = new_signature
	if is_instance_valid(artifact): artifact.queue_free()
	if is_instance_valid(special_visual):
		var old_shell := special_visual
		if old_shell.get_child_count() > 0:
			var opening := create_tween().set_parallel(true)
			opening.tween_property(old_shell,"position:y",0.7,0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			opening.tween_property(old_shell,"rotation:z",0.45,0.38)
			opening.tween_property(old_shell,"scale",Vector3.ONE*0.02,0.38)
			opening.chain().tween_callback(old_shell.queue_free)
		else: old_shell.queue_free()
	kind = tile.kind
	artifact = model("relic_%02d" % (9 if mystery or hidden else kind), low)
	add_child(artifact)
	artifact.visible = not hidden
	special_visual = Node3D.new()
	add_child(special_visual)
	if hidden or frozen:
		special_visual.add_child(model("frost_shell" if frozen else "compartment",low))
	if locked:
		special_visual.add_child(model("relic_seal",low))
	if tile.special == "golden":
		var light_ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.40
		torus.outer_radius = 0.425
		light_ring.mesh = torus
		light_ring.position.y = 0.29
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("efbd56")
		mat.emission_enabled = true
		mat.emission = Color("8e4c17")
		light_ring.material_override = mat
		special_visual.add_child(light_ring)

func selectable(enabled: bool) -> void:
	body.collision_layer = 1 if visible else 0
	# Keep covered tiles in the raycast so clicks cannot pass through them.
	if is_instance_valid(artifact): artifact.scale = Vector3.ONE * (1.0 if enabled else 0.92)

func highlight(enabled: bool) -> void:
	halo.visible = enabled
