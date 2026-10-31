extends SceneTree
var app: Node3D
var checks := 0
var failures := 0
var captured := false

func _initialize() -> void:
	captured = "--capture" in OS.get_cmdline_user_args()
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func frames(n := 3) -> void:
	for i in range(n): await process_frame

func button(command: String, parent: Node = null) -> Button:
	if parent == null: parent = app.ui.root
	for child in parent.get_children():
		if child is Button and child.get_meta("command", "") == command: return child
		var found := button(command,child)
		if found != null: return found
	return null

func touch(index: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event,true)

func drag(index: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = point
	root.push_input(event,true)

func tap_button(command: String) -> void:
	var b := button(command)
	expect(b != null,"Button exists: "+command)
	if b == null: return
	var scroll: ScrollContainer = app.ui.panel_scroll
	if is_instance_valid(scroll) and scroll.is_ancestor_of(b):
		scroll.ensure_control_visible(b)
		await frames()
	var point := b.get_global_rect().get_center()
	# Real raw touch goes through Input so the engine also produces the GUI's
	# synthetic mouse event. Convert logical viewport coordinates to window pixels.
	var window_point := root.get_final_transform() * point
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = window_point
		event.pressed = pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await frames(2)
	await frames()

func native_touch(point: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = root.get_final_transform() * point
	e.pressed = pressed
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func native_drag(from: Vector2, to: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = root.get_final_transform() * to
	e.relative = root.get_final_transform().basis_xform(to-from)
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func capture(name_: String) -> void:
	if not captured: return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	expect(root.get_texture().get_image().save_png("res://artifacts/"+name_+".png") == OK,"Capture "+name_)

func run() -> void:
	# Desktop/headless DisplayServer uses this flag to advertise a touchscreen.
	# Enable it only in this test so ScrollContainer takes its native touch path.
	Input.emulate_touch_from_mouse = true
	var progress: Node = root.get_node("Progress")
	progress.data = progress.defaults()
	progress.data.tutorial = true
	progress.data.coins = 5000
	progress.data.unlocked = 30
	progress.data.settings.quality = 0
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(8)
	await tap_button("settings")
	expect(app.ui.panel_page == "settings","Touch opens settings")
	var old_audio: bool = progress.data.settings.audio
	await tap_button("audio")
	expect(progress.data.settings.audio != old_audio,"Touch toggles sound in scrolled settings")
	var slider: HSlider
	for child in app.ui.panel_scroll.get_child(0).get_children():
		if child is HSlider: slider = child
	app.ui.panel_scroll.ensure_control_visible(slider)
	await frames()
	var slider_rect := slider.get_global_rect()
	var slider_start := slider_rect.position+Vector2(slider_rect.size.x*0.2,slider_rect.size.y*0.5)
	var slider_end := slider_rect.position+Vector2(slider_rect.size.x*0.8,slider_rect.size.y*0.5)
	native_touch(slider_start,true)
	native_drag(slider_start,slider_end)
	native_touch(slider_end,false)
	await frames()
	expect(progress.data.settings.scale > 0.8 and progress.data.settings.scale < 1.0,"Touch drags graphics slider")
	await tap_button("close")
	await tap_button("levels")
	expect(app.ui.panel_page == "levels","Touch opens level selection")
	var scroll: ScrollContainer = app.ui.panel_scroll
	var scroll_from: Vector2 = scroll.get_global_rect().end-Vector2(24,50)
	native_touch(scroll_from,true)
	for i in range(1,6):
		native_drag(scroll_from-Vector2(0,(i-1)*45),scroll_from-Vector2(0,i*45))
		await frames()
	native_touch(scroll_from-Vector2(0,225),false)
	await frames()
	expect(scroll.scroll_vertical > 0 and app.ui.panel_page == "levels","Touch drag scrolls level selection without launching a level (offset=%s, page=%s)" % [scroll.scroll_vertical,app.ui.panel_page])
	await tap_button("level:30")
	expect(app.level.number == 30 and app.playing,"Touch launches a late level from scrolled selector")
	app.ui.close_panel()
	await frames()
	await tap_button("pause")
	expect(app.ui.panel_page == "pause","Touch pauses gameplay")
	await tap_button("resume")
	expect(not app.ui.panel_open,"Touch resumes gameplay")
	app.load_expedition(LevelCatalog.generate(1))
	app.ui.close_panel()
	await frames(12)
	var first: int = app.state.solution[0]
	var point: Vector2 = app.camera.unproject_position(app.tiles[first].position+Vector3(0,0.4,0))
	touch(0,point,true)
	touch(0,point,false)
	while app.busy: await process_frame
	expect(app.state.tray.size() == 1,"One finger tap collects exactly one relic")
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	mouse.position = app.camera.unproject_position(app.tiles[app.state.solution[1]].position)
	root.push_input(mouse,true)
	expect(app.state.tray.size() == 1,"Synthetic mouse cannot collect a second relic")
	app.on_action("undo")
	await frames()
	point = app.camera.unproject_position(app.tiles[first].position+Vector3(0,0.4,0))
	touch(0,point,true)
	touch(0,point,false,true)
	expect(app.state.tray.is_empty() and app.touch_points.is_empty(),"Canceled Android touch clears state without selecting")
	touch(0,point,true)
	drag(0,point+Vector2(60,0))
	touch(0,point+Vector2(60,0),false)
	expect(app.state.tray.is_empty() and not is_equal_approx(app.target_yaw,0.12),"One finger drag orbits without collecting")
	app.on_action("camera_reset")
	var before_zoom: float = app.target_zoom
	touch(0,point,true)
	touch(1,point+Vector2(80,0),true)
	drag(1,point+Vector2(160,0))
	touch(1,point+Vector2(160,0),false)
	touch(0,point,false)
	expect(app.target_zoom < before_zoom and app.state.tray.is_empty(),"Pinch zoom and final finger release cannot collect")
	touch(0,point,true)
	app.on_action("pause")
	touch(0,point,false)
	expect(app.touch_points.is_empty() and app.state.tray.is_empty(),"Opening a modal cancels pending collection")
	app.on_action("resume")
	touch(0,point,true)
	app._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(0,point,false)
	expect(app.touch_points.is_empty() and app.state.tray.is_empty() and app.ui.panel_open,"Backgrounding cancels touches and pauses")
	app.on_action("resume")
	await tap_button("camera_view")
	expect(app.camera_view == 1,"Touch cycles camera view")
	await tap_button("zoom_in")
	expect(app.target_zoom < 1.0,"Touch zoom button works")
	await tap_button("camera_reset")
	expect(app.camera_view == 0 and is_equal_approx(app.target_zoom,1.0),"Reset restores view and zoom")
	for size_ in [Vector2i(600,1000),Vector2i(1300,600),Vector2i(600,1300),Vector2i(1000,600),Vector2i(800,1280),Vector2i(1280,800)]:
		var board_before: Dictionary = app.state.snapshot()
		root.size = size_
		root.content_scale_size = size_
		app.on_resize()
		await frames(8)
		expect(app.state.snapshot() == board_before,"Rotation preserves the puzzle: "+str(size_))
		app.ui.settings()
		app.ui.rebuild()
		expect(app.ui.panel_page == "settings","Rotation preserves settings panel: "+str(size_))
		app.ui.close_panel()
		app.load_expedition(LevelCatalog.generate(30))
		app.ui.close_panel()
		await frames(10)
		for view in range(3):
			app.camera_view = view
			app.target_pitch = app.VIEW_PITCH[view]
			app.target_zoom = 1.0
			app.fit_dirty = true
			app.update_camera(1.0,true)
			var fit := true
			for i in range(8): fit = fit and app.ui.board_rect().has_point(app.camera.unproject_position(app.board_bounds.get_endpoint(i)))
			expect(fit,"Camera fits final level: %s view %d" % [size_,view])
		for command in ["pause","camera_view","zoom_in","zoom_out","camera_reset","undo","shuffle","hint","slot","rotate","shift"]:
			var b := button(command)
			expect(b != null and app.ui.safe_area.encloses(b.get_global_rect()),"Safe touch target %s in %s" % [command,size_])
		await tap_button("pause")
		expect(app.ui.panel_page == "pause", "Touch pause after rotation: "+str(size_))
		await tap_button("resume")
		app.on_action("camera_reset")
		await frames(16)
		await physics_frame
		var id: int = app.state.solution[0]
		var pick_point: Vector2 = app.camera.unproject_position(app.tiles[id].position+Vector3(0,0.4,0))
		expect(app.pick(pick_point) == id,"Final-level tile is pickable after rotation: "+str(size_))
		touch(0,pick_point,true)
		touch(0,pick_point,false)
		while app.busy: await process_frame
		expect(app.state.tray.size() == 1,"Touch selects final-level tile after rotation: "+str(size_))
		app.on_action("undo")
		await frames()
		await capture("touch-%dx%d" % [size_.x,size_.y])
	app.load_expedition(LevelCatalog.generate(1))
	app.ui.close_panel()
	for id in app.state.solution: app.state.select_tile(id)
	app.sync_tiles()
	app.reward = progress.complete(1,app.state.matches,0)
	app.ui.result(true,app.reward)
	await frames()
	await tap_button("next")
	expect(app.level.number == 2 and app.state.status == "playing","Touch continues from victory")
	app.ui.help()
	await frames()
	await tap_button("resume")
	expect(not app.ui.panel_open,"Touch closes scrolled tutorial")
	app.on_action("menu")
	await frames()
	await tap_button("achievements")
	expect(app.ui.panel_page == "collection","Touch opens collection")
	await tap_button("close")
	expect(not app.ui.panel_open,"Touch returns from collection")
	app.queue_free()
	await frames(4)
	Input.emulate_touch_from_mouse = false
	print("TOUCH: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
