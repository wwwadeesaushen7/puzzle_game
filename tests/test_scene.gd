extends SceneTree
var app: Node3D
var failures := 0
var screenshot := false
var quick := false
var checks := 0

func _initialize() -> void:
	screenshot = "--capture" in OS.get_cmdline_user_args()
	quick = "--quick" in OS.get_cmdline_user_args()
	call_deferred("run")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: "+message)

func frames(count := 4) -> void:
	for i in range(count): await process_frame

func capture(name_: String) -> void:
	if not screenshot: return
	await RenderingServer.frame_post_draw
	var dir := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(dir)
	var result := root.get_texture().get_image().save_png(dir+"/"+name_+".png")
	expect(result == OK,"Screenshot " + name_)

func run() -> void:
	var progress: Node = root.get_node("Progress")
	var original: Dictionary = progress.data.duplicate(true)
	progress.data = progress.defaults()
	progress.data.tutorial = true
	progress.data.coins = 5000
	if "--ultra" in OS.get_cmdline_user_args(): progress.data.settings.quality = 3
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await frames(8)
	expect(app.camera != null and app.camera is Camera3D,"Real perspective camera exists")
	expect(app.tiles.size() == 18,"First expedition has 18 modeled relics")
	expect(app.ui.screen == "menu","Main menu loads")
	await capture("01-main-menu")
	app.on_action("continue")
	await frames(8)
	expect(app.playing,"Continue starts expedition")
	app.ui.close_panel()
	await capture("02-observatory")
	var id: int = app.state.solution[0]
	var screen_pos: Vector2 = app.camera.unproject_position(app.tiles[id].position+Vector3(0,.4,0))
	await physics_frame
	expect(app.pick(screen_pos) == id,"3D raycast selects the visible relic")
	var click := InputEventMouseButton.new()
	click.position = screen_pos
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await frames(2)
	while app.busy: await process_frame
	expect(app.state.tray.size() == 1,"Animated selection moves a relic into the tray")
	await capture("03-collection")
	app.on_action("undo")
	expect(app.state.tray.is_empty(),"Undo restores animated selection")
	if not quick:
		for move in app.state.solution.duplicate():
			app.collect(move)
			while app.busy: await process_frame
		expect(app.state.status == "won" and app.ui.panel_open,"Full animated level completes and shows victory")
		expect(progress.data.unlocked == 2,"Victory unlocks the next expedition")
		await capture("04-victory")
		for world in range(1,5):
			app.load_expedition(LevelCatalog.generate(world*6+1))
			app.ui.close_panel()
			await frames(5)
			expect(app.world.world_id == world,"World %d loads" % world)
			await capture("world-%d" % (world+1))
		app.load_expedition(LevelCatalog.generate(30))
		app.ui.close_panel()
		await frames(4)
		app.on_action("rotate")
		while app.busy: await process_frame
		expect(is_equal_approx(app.world.rotor.rotation.y,app.state.angle),"Rotor visual matches simulation")
		app.on_action("shift")
		while app.busy: await process_frame
		expect(app.state.shifted,"Carriage animation completes")
		for preset in range(4):
			app.on_action("quality:%d" % preset)
			await frames(3)
			expect(app.tiles[0].low == (preset < 2),"Quality changes mesh LOD")
		app.on_action("quality:2")
		app.on_action("hint")
		while app.busy: await process_frame
		app.on_action("shuffle")
		app.on_action("slot")
		expect(app.state.capacity == 8,"Extra slot expands real tray")
	app.ui.levels()
	await frames()
	await capture("05-expeditions")
	app.ui.settings()
	await frames()
	await capture("06-settings")
	app.ui.close_panel()
	root.size = Vector2i(600,1000)
	root.content_scale_size = Vector2i(600,1000)
	await frames(12)
	app.load_expedition(LevelCatalog.generate(7))
	app.ui.close_panel()
	await frames(8)
	expect(app.ui.mobile,"Portrait layout activates")
	await capture("07-portrait")
	# Two-finger gestures may never collect a relic.
	var before: int = app.state.remaining()
	for index in range(2):
		var e := InputEventScreenTouch.new()
		e.index = index; e.pressed = true; e.position = Vector2(200+index*100,400)
		app._unhandled_input(e)
	for index in range(2):
		var e := InputEventScreenTouch.new()
		e.index = index; e.pressed = false; e.position = Vector2(200+index*100,400)
		app._unhandled_input(e)
	expect(app.state.remaining() == before and app.state.tray.is_empty(),"Two-finger camera gesture does not select")
	app.on_action("menu")
	await frames(8)
	await capture("08-portrait-menu")
	progress.data = original
	progress.save()
	app.queue_free()
	await frames(3)
	print("SCENE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
