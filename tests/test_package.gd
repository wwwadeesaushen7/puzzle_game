extends SceneTree
## Run against the Windows embedded pack or the APK's extracted assets with a
## matching Linux Godot engine. This validates payloads, not native execution.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: "+message)

func run() -> void:
	expect(ProjectSettings.get_setting("application/config/version") == "1.1.0","Packed version")
	expect(ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),"Packed GUI touch emulation")
	expect(ProjectSettings.get_setting("display/window/handheld/orientation") == 6,"Packed sensor orientation")
	var progress: Node = root.get_node("Progress")
	progress.data = progress.defaults()
	progress.data.tutorial = true
	var app: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	for i in range(8): await process_frame
	expect(app.ui.screen == "menu","Packed menu loads")
	expect(app.tiles.size() == 18,"Packed models and first level load")
	expect(app.CAMERA_VIEWS.size() == 3,"Packed camera controls")
	app.on_action("continue")
	for i in range(8): await process_frame
	var id: int = app.state.solution[0]
	var point: Vector2 = app.camera.unproject_position(app.tiles[id].position+Vector3(0,0.4,0))
	for pressed in [true,false]:
		var e := InputEventScreenTouch.new()
		e.index = 0
		e.position = point
		e.pressed = pressed
		root.push_input(e,true)
	while app.busy: await process_frame
	expect(app.state.tray.size() == 1,"Packed touch selects exactly once")
	var catalog: GDScript = load("res://scripts/core/level_catalog.gd")
	var data: Dictionary = catalog.generate(30)
	expect(data.tiles.size() == 66 and data.difficulty == 4,"Packed final difficulty")
	app.ui.licenses()
	expect(app.ui.panel_page == "licenses","Packed licenses UI")
	expect(FileAccess.get_file_as_string("res://assets/licenses/Godot-LICENSE.txt").contains("MIT"),"Packed engine notice")
	app.queue_free()
	for i in range(4): await process_frame
	print("PACKAGE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
