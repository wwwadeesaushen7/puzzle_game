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

func _ready() -> void:
	if "--low" in OS.get_cmdline_user_args(): Progress.data.settings.quality = 0
	if OS.has_feature("mobile"):
		get_window().content_scale_size = Vector2i(600,1000)
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
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
	get_viewport().size_changed.connect(func(): call_deferred("layout_tray"))
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
	level = data
	state.load_level(level)
	Progress.session_abilities = 0
	reward.clear()
	playing = active
	busy = false
	zoom = 1.0
	target_zoom = 1.0
	target_yaw = 0.12
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
	return minf(87.0,(get_viewport().get_visible_rect().size.x-38.0)/state.capacity)

func tray_position(index: int) -> Vector3:
	var s := get_viewport().get_visible_rect().size
	return camera.project_position(Vector2(s.x*0.5+(index-(state.capacity-1)*0.5)*tray_spacing(),s.y*0.854),8.0)

func tray_scale() -> float:
	var s := get_viewport().get_visible_rect().size
	return camera.project_position(Vector2(s.x/2+tray_spacing()*0.42,s.y*0.854),8).distance_to(camera.project_position(Vector2(s.x/2-tray_spacing()*0.42,s.y*0.854),8))/BoardState.WIDTH

func tray_rotation() -> Vector3:
	return Vector3(0,camera.rotation.y,0)

func layout_tray() -> void:
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

func update_camera(delta: float, immediate := false) -> void:
	var s := get_viewport().get_visible_rect().size
	var portrait := s.x/s.y < 0.9
	var blend := 1.0 if immediate else 1.0-exp(-delta*7)
	yaw = lerpf(yaw,target_yaw,blend)
	zoom = lerpf(zoom,target_zoom,blend)
	var distance := (22.5 if portrait else 17.2) * zoom + 0.18 * float(level.tiles.size()/12)
	var target := Vector3(0,0.45,0) if playing or portrait else Vector3(-3.5,0.45,0)
	if playing: target.z += 0.70
	var direction := Vector3(sin(yaw)*0.52,0.80,cos(yaw)*0.59).normalized() if playing else Vector3(sin(yaw)*0.52,0.64,cos(yaw)*0.77).normalized()
	camera.position = camera.position.lerp(target+direction*distance,blend)
	camera.look_at(target,Vector3.UP)

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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11: on_action("fullscreen")
		if event.keycode == KEY_ESCAPE:
			if ui.panel_open: on_action("resume")
			elif playing: on_action("pause")
		if playing and not ui.panel_open:
			var keys := {KEY_U:"undo",KEY_R:"shuffle",KEY_H:"hint",KEY_E:"slot",KEY_SPACE:"rotate",KEY_F:"shift"}
			if keys.has(event.keycode): on_action(keys[event.keycode])
	if not playing or ui.panel_open or busy or state.status != "playing": return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var id := pick(event.position)
			if id >= 0: collect(id)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: target_zoom = maxf(0.82,target_zoom-0.04)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: target_zoom = minf(1.18,target_zoom+0.04)
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT: target_yaw = clampf(target_yaw-event.relative.x*0.004,-0.37,0.45)
		var id := pick(event.position)
		if id != hovered:
			if tiles.has(hovered): tiles[hovered].highlight(false)
			hovered = id
			if id >= 0 and state.blocked_reason(id).is_empty(): tiles[id].highlight(true)
			if is_instance_valid(ui.hover_label):
				ui.hover_label.text = "" if id < 0 else (BoardState.NAMES[state.tiles[id].kind] if state.uncovered(id) else "Covered relic")
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() == 1:
				touch_origin = event.position
				touch_moved = false
			if touch_points.size() > 1: multi_gesture = true
		else:
			if touch_points.has(event.index) and not multi_gesture and not touch_moved and event.position.distance_to(touch_origin) < 12:
				var id := pick(event.position)
				if id >= 0: collect(id)
			touch_points.erase(event.index)
			if touch_points.is_empty(): multi_gesture = false
	if event is InputEventScreenDrag and touch_points.has(event.index):
		if event.position.distance_to(touch_origin) > 12: touch_moved = true
		if touch_points.size() == 2:
			var ids := touch_points.keys()
			var old_delta: Vector2 = touch_points[ids[1]]-touch_points[ids[0]]
			touch_points[event.index] = event.position
			var new_delta: Vector2 = touch_points[ids[1]]-touch_points[ids[0]]
			if new_delta.length() > 12 and old_delta.length() > 12:
				target_zoom = clampf(target_zoom*old_delta.length()/new_delta.length(),0.82,1.18)
				target_yaw = clampf(target_yaw-old_delta.angle_to(new_delta),-0.37,0.45)
		else: touch_points[event.index] = event.position

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
	if busy: return
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
