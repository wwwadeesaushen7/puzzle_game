extends Node3D
## Owns scene presentation; BoardState remains the sole authority on puzzle rules.
var state := BoardState.new()
var level: Dictionary
var world: WorldBuilder
var camera: Camera3D
var ui: ForgeInterface
var tile_root: Node3D
var tray_root: Node3D
var tiles: Dictionary = {}
var busy := false
var playing := false
var yaw := 0.12
var target_yaw := 0.12
var zoom := 1.0
var target_zoom := 1.0
var hovered := -1
var touch_points: Dictionary = {}
var touch_origin := Vector2.ZERO
var multi_gesture := false
var touch_moved := false
var audio: Dictionary = {}
var music: AudioStreamPlayer
var pending_quality := false
var reward: Dictionary = {}
var sound_tick := 0
const CAMERA_VIEWS := ["Perspective", "Overhead", "Inspect"]
const VIEW_PITCH := [0.94, 1.42, 0.68]
var camera_view := 0
var pitch := 0.94
var target_pitch := 0.94
var touch_ui: Dictionary = {}
var touch_tile := -1
var board_bounds := AABB()
var fitting_distance := 18.0
var fit_dirty := true
var input_epoch := 0
var touch_epoch := 0

func _ready() -> void:
	if "--low" in OS.get_cmdline_user_args(): Progress.data.settings.quality = 0
	if OS.has_feature("mobile"):
		get_window().mode = Window.MODE_FULLSCREEN
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR)
		resize_mobile_view()
	build_audio()
	camera = Camera3D.new()
	camera.fov = 42
	camera.near = 0.1
	camera.far = 180
	add_child(camera)
	camera.current = true
	tile_root = Node3D.new()
	add_child(tile_root)
	tray_root = Node3D.new()
	add_child(tray_root)
	ui = ForgeInterface.new()
	add_child(ui)
	ui.action.connect(on_action)
	load_expedition(LevelCatalog.generate(1),false)
	apply_settings()
	get_window().size_changed.connect(on_resize)
	ui.menu()

func build_audio() -> void:
	for name_ in ["select","match","stone","victory"]:
		var player := AudioStreamPlayer.new()
		player.stream = load("res://assets/audio/"+name_+".wav")
		player.volume_db = -8
		add_child(player)
		audio[name_] = player
	music = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load("res://assets/audio/ambient.wav")
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	music.stream = stream
	music.volume_db = -9
	add_child(music)
	music.play()

func sound(name_: String) -> void:
	if Progress.data.settings.audio:
		audio[name_].pitch_scale = 1.0 + sin(float(sound_tick)) * 0.035
		sound_tick += 1
		audio[name_].play()

func _exit_tree() -> void:
	if is_instance_valid(music):
		music.stop()
		music.stream = null
	for player in audio.values():
		player.stop()
		player.stream = null

func load_expedition(data: Dictionary, active := true) -> void:
	cancel_touches()
	level = data
	state.load_level(level)
	Progress.session_abilities = 0
	reward.clear()
	playing = active
	busy = false
	zoom = 1.0
	target_zoom = 1.0
	target_yaw = 0.12
	camera_view = 0
	target_pitch = VIEW_PITCH[0]
	fit_dirty = true
	if is_instance_valid(world):
		remove_child(world)
		world.queue_free()
	world = WorldBuilder.new()
	add_child(world)
	world.build(level.world, Progress.data.settings.quality)
	world.rotor.visible = level.rotating
	world.carriage.visible = level.rotating
	rebuild_tiles()
	update_camera(1.0,true)
	if active:
		ui.gameplay(level,state)
		if not Progress.data.tutorial:
			ui.help()
			Progress.data.tutorial = true
			Progress.save()
		else:
			var lesson := {7:"Frozen relics thaw after your first match.",13:"The bronze platform turns. Press Rotate to reveal new angles.",19:"Match the Ancient Keys to release the locked relics.",21:"Shift the carriage to uncover the tiles above and below it.",23:"Hidden chambers open when their guardian is matched.",25:"Mystery relics reveal themselves when uncovered."}
			if lesson.has(level.number): ui.toast(lesson[level.number],7)
	layout_tray()

func rebuild_tiles() -> void:
	for child in tile_root.get_children():
		tile_root.remove_child(child)
		child.queue_free()
	tiles.clear()
	for data in state.tiles:
		var tile := RelicTile.new()
		tile_root.add_child(tile)
		tile.setup(data.id,Progress.data.settings.quality < 2)
		tiles[data.id] = tile
	sync_tiles()
	update_bounds()

func sync_tiles() -> void:
	for data in state.tiles:
		var tile: RelicTile = tiles[data.id]
		tile.visible = data.state != "matched"
		tile.scale = Vector3.ONE
		tile.rotation = Vector3(0,state.yaw_of(data),0)
		tile.position = state.position_of(data)
		tile.highlight(false)
		tile.update_appearance(data,state)
		tile.selectable(state.blocked_reason(data.id).is_empty())
		if data.state == "tray":
			tile.position = tray_position(state.tray.find(data.id))
			tile.scale = Vector3.ONE * tray_scale()
			tile.rotation = tray_rotation()
			tile.body.collision_layer = 0
	world.rotor.rotation.y = state.angle
	world.carriage.position = BoardState.CARRIAGE_HOME + (BoardState.SHIFT_OFFSET if state.shifted else Vector3.ZERO)
	ui.update_stats()

func tray_spacing() -> float:
	return minf(87.0,(ui.dimensions().x-38.0)/state.capacity)

func tray_position(index: int) -> Vector3:
	var center := ui.tray_center()
	return camera.project_position(center + Vector2((index-(state.capacity-1)*0.5)*tray_spacing(),0),8.0)

func tray_scale() -> float:
	var center := ui.tray_center()
	return camera.project_position(center+Vector2(tray_spacing()*0.42,0),8).distance_to(camera.project_position(center-Vector2(tray_spacing()*0.42,0),8))/BoardState.WIDTH

func tray_rotation() -> Vector3:
	return Vector3(0,camera.rotation.y,0)

func layout_tray() -> void:
	fit_dirty = true
	if not is_instance_valid(camera) or not is_instance_valid(tray_root): return
	for child in tray_root.get_children():
		tray_root.remove_child(child)
		child.queue_free()
	tray_root.visible = playing
	for i in range(state.capacity):
		var socket := RelicTile.model("tile",true)
		tray_root.add_child(socket)
		socket.position = tray_position(i) - camera.global_basis.y*0.12
		socket.scale = Vector3.ONE*tray_scale()*Vector3(1.07,0.6,1.07)
		socket.rotation = tray_rotation()
	update_tray_positions()

func update_tray_positions() -> void:
	if not playing: return
	for i in range(tray_root.get_child_count()):
		var socket: Node3D = tray_root.get_child(i)
		socket.position = tray_position(i) - camera.global_basis.y*0.12
		socket.rotation = tray_rotation()
		socket.scale = Vector3.ONE*tray_scale()*Vector3(1.07,0.6,1.07)
	if busy: return
	for i in range(state.tray.size()):
		var tile: RelicTile = tiles[state.tray[i]]
		tile.position = tray_position(i)
		tile.scale = Vector3.ONE*tray_scale()
		tile.rotation = tray_rotation()

func resize_mobile_view() -> void:
	if not OS.has_feature("mobile"): return
	var physical := Vector2(get_window().size)
	if physical.x <= 0 or physical.y <= 0: return
	var logical := Vector2i((physical * (600.0 / minf(physical.x,physical.y))).round())
	if get_window().content_scale_size != logical: get_window().content_scale_size = logical

func on_resize() -> void:
	cancel_touches()
	resize_mobile_view()
	fit_dirty = true
	call_deferred("layout_tray")

func cancel_touches() -> void:
	touch_points.clear()
	touch_ui.clear()
	multi_gesture = false
	touch_moved = false
	touch_tile = -1
	input_epoch += 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		cancel_touches()
		if is_instance_valid(ui) and playing and not ui.panel_open: ui.pause()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(ui):
		if ui.panel_open: on_action("close")
		elif playing: on_action("pause")

func update_bounds() -> void:
	var first := true
	for tile in state.tiles:
		# Include mechanisms' current position; collecting never reframes the board.
		var p := state.position_of(tile)
		var box := AABB(p-Vector3(0.65,0.15,0.7),Vector3(1.3,1.5,1.4))
		board_bounds = box if first else board_bounds.merge(box)
		first = false
	fit_dirty = true

func pose_camera(distance: float, angle: float, elevation: float) -> void:
	var target := board_bounds.get_center()
	var direction := Vector3(sin(angle)*cos(elevation),sin(elevation),cos(angle)*cos(elevation))
	camera.position = target + direction*distance
	camera.look_at(target,Vector3.UP)
	if is_instance_valid(ui) and playing:
		var center := get_viewport().get_visible_rect().size * 0.5
		var desired := ui.board_rect().get_center()
		# Translate the camera plane to frame the board above the tray and below HUD.
		camera.position += camera.project_position(center,distance)-camera.project_position(desired,distance)

func fit_camera() -> void:
	fitting_distance = 10.0
	var area := ui.board_rect().grow(-8)
	for attempt in range(24):
		pose_camera(fitting_distance,target_yaw,target_pitch)
		var fits := true
		for i in range(8):
			if not area.has_point(camera.unproject_position(board_bounds.get_endpoint(i))): fits = false
		if fits: break
		fitting_distance *= 1.10
	fit_dirty = false

func update_camera(delta: float, immediate := false) -> void:
	if not is_instance_valid(ui): return
	if fit_dirty: fit_camera()
	var blend := 1.0 if immediate else 1.0-exp(-delta*9)
	yaw = lerp_angle(yaw,target_yaw,blend)
	pitch = lerpf(pitch,target_pitch,blend)
	zoom = lerpf(zoom,target_zoom,blend)
	pose_camera(fitting_distance * zoom,yaw,pitch)
	if is_instance_valid(ui.camera_label): ui.camera_label.text = CAMERA_VIEWS[camera_view] + " · %d%%" % int(100/target_zoom)

func camera_action(command: String) -> void:
	match command:
		"camera_view":
			camera_view = (camera_view+1)%CAMERA_VIEWS.size()
			target_pitch = VIEW_PITCH[camera_view]
			target_zoom = 1.0
			ui.toast(CAMERA_VIEWS[camera_view] + " view",1.5)
		"camera_reset":
			camera_view = 0
			target_pitch = VIEW_PITCH[0]
			target_yaw = 0.12
			target_zoom = 1.0
		"zoom_in": target_zoom = clampf(target_zoom-0.12,0.65,1.55)
		"zoom_out": target_zoom = clampf(target_zoom+0.12,0.65,1.55)
	fit_dirty = true

func _input(event: InputEvent) -> void:
	# Track raw touch lifetimes before GUI dispatch so releases/cancellation over
	# controls cannot leave a stuck gesture. Emulated mouse belongs to the GUI only.
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			touch_ui[event.index] = ui.blocks_point(event.position) or busy or not playing
			if touch_points.size() == 1:
				touch_origin = event.position
				touch_moved = false
				touch_epoch = input_epoch
				touch_tile = -1 if touch_ui[event.index] else pick(event.position)
			else: multi_gesture = true
		else:
			var owned: bool = touch_points.has(event.index) and not touch_ui.get(event.index,true)
			var tap: bool = owned and not event.canceled and not multi_gesture and not touch_moved and touch_epoch == input_epoch
			tap = tap and not busy and playing and not ui.blocks_point(event.position) and event.position.distance_to(touch_origin) < 16
			var id := pick(event.position) if tap else -1
			touch_points.erase(event.index)
			touch_ui.erase(event.index)
			if tap and id >= 0 and id == touch_tile: collect(id)
			if touch_points.is_empty(): cancel_touches()
	elif event is InputEventScreenDrag and touch_points.has(event.index):
		var old: Vector2 = touch_points[event.index]
		if event.position.distance_to(touch_origin) >= 16: touch_moved = true
		var board_gesture: bool = not ui.panel_open and playing and not busy
		for on_ui in touch_ui.values(): board_gesture = board_gesture and not on_ui
		if board_gesture and touch_points.size() == 2:
			var ids := touch_points.keys()
			var old_delta: Vector2 = touch_points[ids[1]]-touch_points[ids[0]]
			touch_points[event.index] = event.position
			var new_delta: Vector2 = touch_points[ids[1]]-touch_points[ids[0]]
			if new_delta.length() > 20 and old_delta.length() > 20:
				target_zoom = clampf(target_zoom*old_delta.length()/new_delta.length(),0.65,1.55)
				target_yaw -= old_delta.angle_to(new_delta)
				fit_dirty = true
		elif board_gesture and touch_moved and not multi_gesture:
			target_yaw -= (event.position.x-old.x)*0.006
			target_pitch = clampf(target_pitch+(event.position.y-old.y)*0.004,0.55,1.48)
			fit_dirty = true
		touch_points[event.index] = event.position

func _process(delta: float) -> void:
	if level == null: return
	update_camera(delta)
	update_tray_positions()
	if is_instance_valid(world): world.set_process(not ui.panel_open)

func pick(screen_pos: Vector2) -> int:
	var from := camera.project_ray_origin(screen_pos)
	var query := PhysicsRayQueryParameters3D.create(from,from+camera.project_ray_normal(screen_pos)*120,1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return int(hit.collider.get_meta("tile_id",-1)) if not hit.is_empty() else -1

func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouse and ui.blocks_point(event.position): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11: on_action("fullscreen")
		if event.keycode == KEY_ESCAPE:
			if ui.panel_open: on_action("resume")
			elif playing: on_action("pause")
		if playing and not ui.panel_open:
			var keys := {KEY_U:"undo",KEY_R:"shuffle",KEY_H:"hint",KEY_E:"slot",KEY_SPACE:"rotate",KEY_F:"shift",KEY_V:"camera_view",KEY_C:"camera_reset",KEY_EQUAL:"zoom_in",KEY_MINUS:"zoom_out"}
			if keys.has(event.keycode): on_action(keys[event.keycode])
	if not playing or ui.panel_open or busy or state.status != "playing": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var id := pick(event.position)
			if id >= 0: collect(id)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: camera_action("zoom_in")
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: camera_action("zoom_out")
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			target_yaw -= event.relative.x*0.004
			target_pitch = clampf(target_pitch+event.relative.y*0.003,0.55,1.48)
			fit_dirty = true
		var id := pick(event.position)
		if id != hovered:
			if tiles.has(hovered): tiles[hovered].highlight(false)
			hovered = id
			if id >= 0 and state.blocked_reason(id).is_empty(): tiles[id].highlight(true)
			if is_instance_valid(ui.hover_label):
				ui.hover_label.text = "" if id < 0 else (BoardState.NAMES[state.tiles[id].kind] if state.uncovered(id) else "Covered relic")

func collect(id: int) -> void:
	if busy or not playing: return
	var before := state.tray.duplicate()
	var result := state.select_tile(id)
	if not result.ok:
		ui.toast(result.get("reason","This relic cannot be selected."))
		return
	busy = true
	sound("select")
	var temporary := before.duplicate()
	temporary.append(id)
	temporary.sort_custom(func(a: int,b: int) -> bool: return state.tiles[a].kind < state.tiles[b].kind)
	var tween := create_tween().set_parallel(true)
	for i in range(temporary.size()):
		var tile: RelicTile = tiles[temporary[i]]
		tile.body.collision_layer = 0
		tile.highlight(false)
		var start := tile.position
		var target := tray_position(i)
		if temporary[i] == id:
			tween.tween_method(func(t: float): tile.position = start.lerp(target,t) + Vector3.UP * sin(t*PI)*1.6,0.0,1.0,0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		else:
			tween.tween_property(tile,"position",target,0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(tile,"scale",Vector3.ONE*tray_scale(),0.42)
		tween.tween_property(tile,"rotation",tray_rotation(),0.42)
	await tween.finished
	if not result.matched.is_empty():
		sound("match")
		ui.match_feedback(state.matches)
		var disappear := create_tween().set_parallel(true)
		for tid in result.matched:
			burst(tiles[tid].position)
			disappear.tween_property(tiles[tid],"scale",Vector3.ONE*0.01,0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		await disappear.finished
		sound("stone")
	busy = false
	sync_tiles()
	if state.status == "won":
		reward = Progress.complete(level.number,state.matches,state.golden_matches,level.get("daily",""))
		sound("victory")
		for i in range(6): burst(Vector3((i-2.5)*1.2,2.4,0))
		ui.result(true,reward)
	elif state.status == "lost": ui.result(false)

func burst(pos: Vector3) -> void:
	# Expanding light ring also renders on the mobile Compatibility backend.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.32
	torus.outer_radius = 0.36
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = pos
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color("9deddf")
	ring.material_override = glow
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var ripple := create_tween().set_parallel(true)
	ripple.tween_property(ring,"scale",Vector3.ONE*3.5,0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	ripple.tween_property(glow,"albedo_color:a",0.0,0.55)
	ripple.chain().tween_callback(ring.queue_free)
	var p := GPUParticles3D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 10 if Progress.data.settings.quality < 2 else 28
	p.lifetime = 0.85
	p.explosiveness = 1.0
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 150
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.6
	m.gravity = Vector3(0,-1.3,0)
	m.scale_min = 0.015
	m.scale_max = 0.05
	m.color = Color("edc880")
	p.process_material = m
	var mesh := SphereMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("e6b96b")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	p.draw_pass_1 = mesh
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

func on_action(command: String) -> void:
	if command in ["camera_view","camera_reset","zoom_in","zoom_out"]:
		camera_action(command)
		return
	if busy and command not in ["pause","resume","close"]: return
	cancel_touches()
	sound("select")
	if command.begins_with("licenses:"):
		ui.licenses(command.split(":")[1])
		return
	if command.begins_with("level:"):
		var number := int(command.split(":")[1])
		if number <= Progress.data.unlocked: load_expedition(LevelCatalog.generate(number))
		return
	if command.begins_with("quality:"):
		Progress.data.settings.quality = int(command.split(":")[1])
		var old_world := world
		remove_child(old_world)
		old_world.queue_free()
		world = WorldBuilder.new()
		add_child(world)
		world.build(level.world,Progress.data.settings.quality)
		world.rotor.visible = level.rotating
		world.carriage.visible = level.rotating
		rebuild_tiles()
		apply_settings()
		return
	if command.begins_with("scale:"):
		Progress.data.settings.scale = float(command.split(":")[1])
		apply_settings()
		return
	if command.begins_with("resolution:"):
		var parts := command.split(":")[1].split("×")
		DisplayServer.window_set_size(Vector2i(int(parts[0]),int(parts[1])))
		return
	match command:
		"continue": load_expedition(LevelCatalog.generate(Progress.data.unlocked))
		"menu":
			playing = false
			tray_root.visible = false
			ui.menu()
		"levels": ui.levels()
		"settings": ui.settings()
		"achievements": ui.collection()
		"pause":
			if playing: ui.pause()
		"resume", "close":
			ui.close_panel()
			if playing and state.status != "playing": ui.result(state.status == "won",reward)
		"help": ui.help()
		"restart": load_expedition(LevelCatalog.daily(level.daily) if level.has("daily") else LevelCatalog.generate(level.number))
		"next":
			if level.has("daily") or level.number == 30: on_action("menu")
			else: load_expedition(LevelCatalog.generate(level.number+1))
		"daily": load_expedition(LevelCatalog.daily(Time.get_date_string_from_system(true)))
		"audio":
			Progress.data.settings.audio = not Progress.data.settings.audio
			apply_settings()
			ui.settings()
		"fps":
			Progress.data.settings.fps = 30 if Progress.data.settings.fps == 60 else 60
			apply_settings()
			ui.settings()
		"fullscreen":
			Progress.data.settings.fullscreen = not Progress.data.settings.fullscreen
			apply_settings()
			if ui.panel_open: ui.settings()
		"undo":
			if state.history.is_empty(): ui.toast("There is no earlier move to restore.")
			elif pay(10):
				state.undo()
				ui.close_panel()
				layout_tray()
				sync_tiles()
		"shuffle":
			if state.status != "won" and pay(25):
				state.shuffle_board(Time.get_ticks_msec())
				ui.close_panel()
				sync_tiles()
				ui.toast("The forge has rewoven the remaining relics.")
		"slot":
			if state.capacity >= 8: ui.toast("The collection already has its eighth slot.")
			elif pay(30):
				state.add_slot()
				ui.close_panel()
				layout_tray()
				sync_tiles()
		"hint": show_hint()
		"rotate":
			if level.rotating and state.status == "playing":
				state.rotate_section()
				animate_mechanisms()
		"shift":
			if level.moving and state.status == "playing":
				state.move_section()
				animate_mechanisms()

func pay(price: int) -> bool:
	if not playing: return false
	if not Progress.spend(price):
		ui.toast("You need %d coins. Expeditions award coins; restarting is always free." % price,5)
		return false
	Progress.session_abilities += 1
	ui.update_stats()
	return true

func show_hint() -> void:
	if not playing or state.status != "playing": return
	if Progress.data.coins < 5:
		ui.toast("A hint costs 5 coins. Restarting is always free.")
		return
	busy = true
	ui.toast("Reading the constellation…",20)
	var sim := BoardState.new()
	sim.restore(state.snapshot())
	sim.solution = state.solution.duplicate()
	var worker := Thread.new()
	worker.start(func(): return sim.hint(3500))
	while worker.is_alive(): await get_tree().process_frame
	var id: int = worker.wait_to_finish()
	busy = false
	if id < 0:
		ui.toast("No verified continuation found. Try Undo, a mechanism, or Reweave. No coins spent.",7)
	elif pay(5):
		for tile in tiles.values(): tile.highlight(false)
		tiles[id].highlight(true)
		ui.toast("Follow the light: " + BoardState.NAMES[state.tiles[id].kind])

func animate_mechanisms() -> void:
	busy = true
	sound("stone")
	var tw := create_tween().set_parallel(true)
	for data in state.tiles:
		if data.state == "board":
			if data.section == 1:
				var node: RelicTile = tiles[data.id]
				var from_angle := node.rotation.y
				var to_angle := from_angle + angle_difference(from_angle,state.angle)
				tw.tween_method(func(a: float):
					node.position = BoardState.ROTOR_CENTER+(data.pos-BoardState.ROTOR_CENTER).rotated(Vector3.UP,a)
					node.rotation.y = a,from_angle,to_angle,0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			elif data.section == 2:
				rail_motion(tiles[data.id],state.position_of(data),tw)
			else:
				tw.tween_property(tiles[data.id],"position",state.position_of(data),0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(world.rotor,"rotation:y",world.rotor.rotation.y+angle_difference(world.rotor.rotation.y,state.angle),0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rail_motion(world.carriage,BoardState.CARRIAGE_HOME+(BoardState.SHIFT_OFFSET if state.shifted else Vector3.ZERO),tw)
	await tw.finished
	busy = false
	sync_tiles()
	update_bounds()

func rail_motion(node: Node3D, target: Vector3, tween: Tween) -> void:
	# Lower before sliding underneath the bridge; slide home before raising.
	var start := node.position
	var corner := Vector3(start.x,target.y,start.z) if state.shifted else Vector3(target.x,start.y,target.z)
	tween.tween_method(func(t: float):
		if t < 0.5: node.position = start.lerp(corner,smoothstep(0.0,0.5,t))
		else: node.position = corner.lerp(target,smoothstep(0.5,1.0,t)),0.0,1.0,0.9)

func apply_settings() -> void:
	var settings: Dictionary = Progress.data.settings
	Engine.max_fps = settings.fps
	get_viewport().scaling_3d_scale = settings.scale
	AudioServer.set_bus_mute(0,not settings.audio)
	if not OS.has_feature("mobile"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if is_instance_valid(world): world.apply_quality(settings.quality)
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		var attributes := CameraAttributesPractical.new()
		attributes.dof_blur_far_enabled = settings.quality == 3
		attributes.dof_blur_far_distance = 30
		attributes.dof_blur_far_transition = 20
		attributes.dof_blur_amount = 0.12
		camera.attributes = attributes
	Progress.save()
