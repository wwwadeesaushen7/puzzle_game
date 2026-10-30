class_name ForgeInterface
extends CanvasLayer
signal action(command: String)
const GOLD := Color("d4b27a")
const TEXT := Color("ede9dc")
const MUTED := Color("94a6b2")
const INK := Color("111e2b")
var root: Control
var modal: Control
var toast_label: Label
var counters: Label
var level_caption: Label
var hover_label: Label
var screen := "menu"
var panel_open := false
var mobile := false
var current_data: Dictionary = {}
var current_state: BoardState
var toast_time := 0.0
var last_reward: Dictionary = {}
var display_font: Font = preload("res://assets/fonts/Display.otf")
var body_font: Font = preload("res://assets/fonts/Body.ttf")

func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	get_viewport().size_changed.connect(func(): call_deferred("rebuild"))

func dimensions() -> Vector2:
	return get_viewport().get_visible_rect().size

func clean() -> void:
	for child in root.get_children(): child.queue_free()
	modal = null
	panel_open = false
	toast_label = null
	counters = null
	mobile = dimensions().x / dimensions().y < 0.9

func label_(text_: String, size_: int, color := TEXT, serif := false) -> Label:
	var label := Label.new()
	label.text = text_
	label.add_theme_font_override("font", display_font if serif else body_font)
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func place_label(text_: String, pos: Vector2, size_: int, color := TEXT, serif := false, parent: Control = root) -> Label:
	var label := label_(text_, size_, color, serif)
	label.position = pos
	parent.add_child(label)
	return label

func style(fill: Color, border: Color, radius := 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	return sb

func button_(title: String, command: String, primary := false) -> Button:
	var b := Button.new()
	b.text = title
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_override("font", body_font)
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color("16222a") if primary else TEXT)
	b.add_theme_color_override("font_hover_color", Color("16222a") if primary else Color.WHITE)
	b.add_theme_stylebox_override("normal", style(GOLD if primary else Color(0.055,0.10,0.15,0.91), GOLD if primary else Color("46515a")))
	b.add_theme_stylebox_override("hover", style(GOLD.lightened(0.13) if primary else Color("253646"), GOLD))
	b.add_theme_stylebox_override("pressed", style(Color("a78956") if primary else Color("101a23"), GOLD))
	b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), GOLD.lightened(0.2)))
	b.add_theme_stylebox_override("disabled", style(Color("131c25"), Color("28343e")))
	b.add_theme_color_override("font_disabled_color", Color("63717c"))
	b.pressed.connect(func(): action.emit(command))
	return b

func place_button(text_: String, command: String, pos: Vector2, size_: Vector2, primary := false, parent: Control = root) -> Button:
	var b := button_(text_, command, primary)
	b.position = pos
	b.size = size_
	parent.add_child(b)
	return b

func line_(pos: Vector2, width: float, parent: Control = root) -> void:
	var line := ColorRect.new()
	line.color = Color(0.8,0.67,0.44,0.38)
	line.position = pos
	line.size = Vector2(width, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

func shade(menu: bool) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; uniform bool menu; uniform bool portrait; void fragment(){float edge=pow(abs(UV.x-0.5)*2.0,2.0)*0.32;float top=pow(1.0-UV.y,7.0)*0.7;float bottom=pow(UV.y,7.0)*0.95;float left=menu?(portrait?0.15:pow(1.0-UV.x,2.8)*0.94):0.0;COLOR=vec4(0.018,0.034,0.052,clamp(max(left,top)+bottom+edge,0.0,0.97));}"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("menu", menu)
	mat.set_shader_parameter("portrait", mobile)
	rect.material = mat
	root.add_child(rect)

func menu() -> void:
	screen = "menu"
	clean()
	shade(true)
	var s := dimensions()
	var left := 46.0 if mobile else 74.0
	place_label("A N   A S T R A L   E X P E D I T I O N", Vector2(left, 38), 13, GOLD)
	place_button("Settings", "settings", Vector2(s.x-150,30), Vector2(112,48))
	var title_y := s.y * 0.12 if mobile else s.y * 0.24
	place_label("ASTRAL\nFORGE", Vector2(left, title_y), 68 if mobile else 98, TEXT, true)
	line_(Vector2(left, title_y + (174 if mobile else 240)), 72)
	place_label("THE HEAVENS LEFT SOMETHING BEHIND.", Vector2(left, title_y + (194 if mobile else 263)), 12, GOLD)
	var blurb := place_label("Unearth ancient relics. Restore lost constellations.\nDiscover the quiet art of finding what belongs together.", Vector2(left, title_y+300), 16, MUTED)
	blurb.visible = not mobile
	var buttons_y := s.y-278 if mobile else s.y*0.69
	var width := s.x - left * 2 if mobile else 350.0
	place_button("Continue expedition     →", "continue", Vector2(left,buttons_y), Vector2(width,60), true)
	place_button("The five worlds", "levels", Vector2(left,buttons_y+72), Vector2(width,52))
	place_button("Daily alignment", "daily", Vector2(left,buttons_y+134), Vector2(width*0.55-5,52))
	place_button("Collection", "achievements", Vector2(left+width*0.55+5,buttons_y+134), Vector2(width*0.45-5,52))
	place_label("30 EXPEDITIONS   /   5 WORLDS   /   ONE FORGOTTEN CIVILIZATION", Vector2(left,s.y-46), 11, MUTED).visible = not mobile
	if not mobile:
		place_label("I  /  ANCIENT OBSERVATORY", Vector2(s.x-400,s.y-115), 13, GOLD)
		place_label("Where the heavens were first measured.", Vector2(s.x-400,s.y-85), 18, TEXT, true)
		line_(Vector2(s.x-400,s.y-132), 330)
	make_toast()

func gameplay(data: Dictionary, state: BoardState) -> void:
	current_data = data
	current_state = state
	screen = "game"
	clean()
	shade(false)
	var s := dimensions()
	var left := 24.0 if mobile else 42.0
	place_label("A S T R A L   F O R G E", Vector2(left,28), 14, GOLD)
	place_button("Ⅱ" if mobile else "Pause   ·   Esc", "pause", Vector2(s.x-(90 if mobile else 180),22), Vector2(65 if mobile else 140,48))
	var world_name: String = LevelCatalog.WORLD_NAMES[data.world]
	place_label(world_name.to_upper(), Vector2(left,88), 12, MUTED)
	place_label(data.title, Vector2(left,111), 32 if mobile else 41, TEXT, true)
	level_caption = place_label("", Vector2(left,164), 13, GOLD)
	counters = place_label("", Vector2(s.x-320,92) if not mobile else Vector2(left,194), 14, TEXT)
	if not mobile: counters.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var actions := [["Undo · 10", "undo"], ["Reweave · 25", "shuffle"], ["Hint · 5", "hint"], ["+ Slot · 30", "slot"]]
	var cell_width := minf(142, (s.x-40)/4.0)
	for i in range(4):
		var b := place_button(actions[i][0], actions[i][1], Vector2(s.x/2+(i-2)*cell_width+5,s.y-82), Vector2(cell_width-10,52))
		b.add_theme_font_size_override("font_size", 13 if mobile else 15)
		b.tooltip_text = ["Restore the previous move, including a completed match. Keyboard: U", "Return held tiles, dissolve seals and rearrange remaining relics into a solvable pattern. Keyboard: R", "Reveal a move with a verified continuation. Keyboard: H", "Expand the tray to eight slots for this expedition. Keyboard: E"][i]
	place_label("THE COLLECTION", Vector2(s.x/2-73,s.y*0.78), 11, GOLD)
	if data.rotating:
		place_button("Rotate  ↻", "rotate", Vector2(left,s.y*0.66), Vector2(128,48)).tooltip_text = "Turn the bronze platform 45°. Space."
	if data.moving:
		place_button("Shift  ⇄", "shift", Vector2(s.x-left-128,s.y*0.66), Vector2(128,48)).tooltip_text = "Move the left carriage along its rails. F."
	hover_label = place_label("", Vector2(s.x/2-200,s.y*0.735), 14, TEXT)
	hover_label.size.x = 400
	hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not mobile: place_label("CLICK TO COLLECT    ·    SCROLL TO ZOOM    ·    RIGHT DRAG TO ORBIT", Vector2(left,s.y-28), 10, MUTED)
	make_toast()
	update_stats()

func update_stats() -> void:
	if not is_instance_valid(counters) or current_state == null: return
	counters.text = "%02d RELICS   /   %d OF %d HELD\n%d COINS" % [current_state.remaining(), current_state.tray.size(), current_state.capacity, Progress.data.coins]
	level_caption.text = "EXPEDITION %02d / 30     ·     MATCH THREE TO RESTORE THE LIGHT" % current_data.number if not current_data.has("daily") else "DAILY ALIGNMENT    ·    " + current_data.daily

func make_toast() -> void:
	toast_label = label_("", 16, TEXT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.position = Vector2(30,dimensions().y*0.27)
	toast_label.size = Vector2(dimensions().x-60,80)
	toast_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	toast_label.add_theme_constant_override("shadow_offset_x", 1)
	toast_label.add_theme_constant_override("shadow_offset_y", 2)
	root.add_child(toast_label)

func toast(text_: String, seconds := 4.0) -> void:
	if is_instance_valid(toast_label): toast_label.text = text_
	toast_time = seconds

func _process(delta: float) -> void:
	if toast_time > 0:
		toast_time -= delta
		if toast_time <= 0 and is_instance_valid(toast_label): toast_label.text = ""

func close_panel() -> void:
	if is_instance_valid(modal): modal.queue_free()
	modal = null
	panel_open = false

func panel(title: String, subtitle: String, wide := false) -> VBoxContainer:
	close_panel()
	panel_open = true
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0.01,0.02,0.035,0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(dim)
	var size_ := dimensions()
	var width := minf(size_.x-36, 960 if wide else 600)
	var height := minf(size_.y-60, 740 if wide else 650)
	var box := PanelContainer.new()
	box.position = Vector2((size_.x-width)/2,(size_.y-height)/2)
	box.size = Vector2(width,height)
	box.add_theme_stylebox_override("panel", style(Color("101e2b"), Color("766343"), 10))
	modal.add_child(box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",18)
	scroll.add_child(body)
	var eyebrow := label_("THE ASTRAL ARCHIVE",12,GOLD)
	body.add_child(eyebrow)
	body.add_child(label_(title,38,TEXT,true))
	var sub := label_(subtitle,15,MUTED)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub)
	return body

func paragraph(parent: Control, text_: String, color := MUTED) -> void:
	var l := label_(text_,16,color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)

func pause() -> void:
	var body := panel("A moment of stillness", "Your expedition will be here when you return.")
	body.add_child(button_("Return to the forge", "resume", true))
	body.add_child(button_("How to play", "help"))
	body.add_child(button_("Settings", "settings"))
	body.add_child(button_("Restart expedition", "restart"))
	body.add_child(button_("Return to the observatory", "menu"))

func help() -> void:
	var body := panel("Everything in its place", "Three relics. One constellation.")
	paragraph(body,"Select an uncovered relic to lift it into the collection. Three identical relics return their light to the forge. Clear the board to complete an expedition.",TEXT)
	paragraph(body,"The collection holds seven relics. If it fills without a match, the expedition ends. Complete a triple with the seventh relic and it clears safely.")
	paragraph(body,"Frost melts after any match. Three Ancient Keys release all seals. Mystery relics reveal their identity when uncovered. A compartment opens when its guardian is matched. Golden matches award extra coins.")
	paragraph(body,"Turn the bronze platform or shift the carriage to expose new paths. Reweave preserves completed matches, returns held relics and removes remaining seals. Undo restores the last move. Abilities use earned coins; every expedition has a solution without them.")
	paragraph(body,"Mouse: click, wheel to zoom, right drag to orbit. Touch: tap to collect; pinch and turn with two fingers. Keyboard: H hint, U undo, R reweave, E extra slot, Space rotate, F shift, Esc pause, F11 fullscreen.")
	body.add_child(button_("Begin the expedition", "resume", true))

func levels() -> void:
	var body := panel("The five worlds", "%d / 90 stars collected. Each world holds six expeditions." % Progress.total_stars(),true)
	for world in range(5):
		body.add_child(label_("%s  /  %s" % [["I","II","III","IV","V"][world],LevelCatalog.WORLD_NAMES[world]],24,GOLD,true))
		paragraph(body,LevelCatalog.WORLD_SUBTITLES[world])
		var grid := GridContainer.new()
		grid.columns = 3 if mobile else 6
		grid.add_theme_constant_override("h_separation",8)
		grid.add_theme_constant_override("v_separation",8)
		body.add_child(grid)
		for i in range(6):
			var n := world*6+i+1
			var unlocked: bool = n <= Progress.data.unlocked
			var stars := int(Progress.data.stars.get(str(n),0))
			var text_ := "%02d\n%s" % [n,"★".repeat(stars)+"·".repeat(3-stars)] if unlocked else "%02d\nSealed" % n
			var b := button_(text_,"level:%d" % n)
			b.custom_minimum_size = Vector2(128 if not mobile else 140,82)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = not unlocked
			b.tooltip_text = LevelCatalog.TITLES[n-1]
			grid.add_child(b)
	body.add_child(button_("Return", "close"))

func collection() -> void:
	var body := panel("A legacy in starlight", "%d coins  ·  %d stars  ·  %d expeditions completed" % [Progress.data.coins,Progress.total_stars(),Progress.data.wins],true)
	for item in Progress.achievements():
		body.add_child(label_(("✦  " if item[2] else "◇  ")+item[0],23,GOLD if item[2] else MUTED,true))
		paragraph(body,item[1] + ("  ·  Discovered" if item[2] else "  ·  Undiscovered"))
	body.add_child(button_("Return", "close"))

func settings() -> void:
	var body := panel("Shape your experience", "Settings apply immediately and are saved on this device.")
	body.add_child(label_("GRAPHICS QUALITY",12,GOLD))
	var quality := OptionButton.new()
	for title in ["Low · minimal effects / mobile meshes", "Medium · balanced", "High · detailed materials and shadows", "Ultra · highest supported effects"]: quality.add_item(title)
	quality.selected = Progress.data.settings.quality
	quality.custom_minimum_size.y = 46
	quality.add_theme_font_size_override("font_size",16)
	quality.item_selected.connect(func(i: int): action.emit("quality:%d" % i))
	body.add_child(quality)
	paragraph(body,"Renderer: " + RenderingServer.get_current_rendering_method() + ". Advanced reflections, occlusion and depth of field require Forward+. Renderer selection is available in the launch scripts.")
	body.add_child(label_("3D RESOLUTION SCALE",12,GOLD))
	var scale_ := HSlider.new()
	scale_.min_value = 0.5
	scale_.max_value = 1.0
	scale_.step = 0.05
	scale_.value = Progress.data.settings.scale
	scale_.custom_minimum_size.y = 36
	scale_.value_changed.connect(func(v: float): action.emit("scale:%f" % v))
	body.add_child(scale_)
	var fps := button_("Frame limit: %d FPS   ·   switch" % Progress.data.settings.fps, "fps")
	body.add_child(fps)
	body.add_child(button_("Sound: %s" % ("on" if Progress.data.settings.audio else "off"), "audio"))
	body.add_child(button_("Credits and licenses", "licenses:engine"))
	if not OS.has_feature("mobile"):
		body.add_child(button_("Fullscreen: %s" % ("on" if Progress.data.settings.fullscreen else "off"), "fullscreen"))
		var sizes := HBoxContainer.new()
		for text_ in ["1280×800", "1440×900", "1920×1080"]:
			var b := button_(text_,"resolution:"+text_)
			b.add_theme_font_size_override("font_size",13)
			sizes.add_child(b)
		body.add_child(sizes)
	body.add_child(button_("Done", "close",true))

func licenses(which := "engine") -> void:
	var body := panel("Made beneath the stars", "Original procedural art and audio. Built with Godot. Typography: P052 Roman and Open Sans.")
	var row := HBoxContainer.new()
	row.add_child(button_("Godot and components","licenses:engine"))
	row.add_child(button_("Fonts","licenses:fonts"))
	body.add_child(row)
	var paths: Array = ["res://assets/licenses/Godot-LICENSE.txt","res://assets/licenses/Godot-COPYRIGHT.txt"] if which == "engine" else ["res://assets/fonts/LICENSE-URW.txt","res://assets/fonts/LICENSE-OpenSans.txt"]
	var notice := TextEdit.new()
	notice.editable = false
	notice.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	notice.custom_minimum_size = Vector2(0,300)
	notice.add_theme_font_size_override("font_size",13)
	for path in paths: notice.text += FileAccess.get_file_as_string(path) + "\n\n"
	body.add_child(notice)
	body.add_child(button_("Back to settings","settings",true))

func result(won: bool, rewards := {}) -> void:
	if won: last_reward = rewards.duplicate()
	var body := panel("A constellation restored" if won else "The collection is full", "The light remembers your work." if won else "A different path is waiting to be found.")
	if won:
		body.add_child(label_("★".repeat(rewards.stars)+"☆".repeat(3-rewards.stars),48,GOLD))
		paragraph(body,"+%d coins  ·  %d matches restored\nStars: 3 with 0–1 abilities, 2 with 2–3, 1 with 4 or more. Improved star records earn additional coins." % [rewards.reward,current_state.matches],TEXT)
		body.add_child(button_("Continue the journey", "next",true))
	else:
		paragraph(body,"You can undo the last choice, expand the tray, reweave the remaining relics, or restart freely.",TEXT)
		body.add_child(button_("Undo last choice · 10 coins", "undo",true))
		body.add_child(button_("Reweave · 25 coins", "shuffle"))
		body.add_child(button_("Extra slot · 30 coins", "slot"))
	body.add_child(button_("Restart expedition", "restart"))
	body.add_child(button_("Return to the observatory", "menu"))

func rebuild() -> void:
	# Resize closes a nonessential panel, retaining the exact puzzle state.
	if screen == "menu": menu()
	elif current_state != null:
		gameplay(current_data,current_state)
		if current_state.status != "playing": result(current_state.status == "won",last_reward)
