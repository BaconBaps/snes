extends Node2D

const CONSOLE_FLOOR := 607.0
const CONSOLE_HEIGHT_SCALE := 1.75
const CONSOLE_TRANSFORM := Transform2D(Vector2.RIGHT, Vector2(0, CONSOLE_HEIGHT_SCALE),
	Vector2(0, CONSOLE_FLOOR * (1.0 - CONSOLE_HEIGHT_SCALE)))
const SLOT_ART := Rect2(336, 520, 159, 14)
const BUTTON_HEIGHT := 23.0 * 0.85
const RESET_ART := Rect2(470, 548, 39, BUTTON_HEIGHT)
const EJECT_ART := Rect2(376, 548, 77, BUTTON_HEIGHT)
const SLOT := CONSOLE_TRANSFORM * SLOT_ART
const RESET := CONSOLE_TRANSFORM * RESET_ART
const EJECT := CONSOLE_TRANSFORM * EJECT_ART
const PLAYER_ONE_SOCKET := CONSOLE_TRANSFORM * Rect2(355, 591, 35, 8)
const PLAYER_TWO_SOCKET := CONSOLE_TRANSFORM * Rect2(440, 591, 35, 8)
const PLUG_SIZE := Vector2(41, 22)
const LOOSE_PLUG := Vector2(611, 556)
const LOOSE_CABLE_END := Vector2(729, 601)
const DESK := Rect2(770, 252, 354, 308)
const CEILING_LIGHT := Rect2(970, 60, 126, 62)
enum Television { ORIGINAL, GRAPHITE, SILVER }

const TV_OFFSET := Vector2(0, -55)
const TV_GLASS := Rect2(153, 96, 480, 360)
const SCREEN := Rect2(TV_GLASS.position + TV_OFFSET, TV_GLASS.size)
const CART_SIZE := Vector2(160, 84 * 1.15)
const LABEL_SIZE := Vector2(CART_SIZE.x - 16, 39)
const LABEL_RADIUS := 3
const INSERT_SOUNDS := [
	preload("res://audio/cartridge/insert_01.wav"),
	preload("res://audio/cartridge/insert_02.wav"),
	preload("res://audio/cartridge/insert_03.wav"),
	preload("res://audio/cartridge/insert_04.wav"),
	preload("res://audio/cartridge/insert_05.wav"),
	preload("res://audio/cartridge/insert_06.wav"),
	preload("res://audio/cartridge/insert_07.wav"),
	preload("res://audio/cartridge/insert_08.wav"),
]
const EJECT_SOUNDS := [
	preload("res://audio/cartridge/eject_01.wav"),
	preload("res://audio/cartridge/eject_02.wav"),
	preload("res://audio/cartridge/eject_03.wav"),
	preload("res://audio/cartridge/eject_04.wav"),
	preload("res://audio/cartridge/eject_05.wav"),
	preload("res://audio/cartridge/eject_06.wav"),
	preload("res://audio/cartridge/eject_07.wav"),
	preload("res://audio/cartridge/eject_08.wav"),
]
const SETTINGS_PATH := "user://settings.cfg"
const SEATED_CART_HEIGHT := 52.0
const GRID_PAGE_SIZE := 6
const STACK_PAGE_SIZE := 12
const STACK_ROW_SPACING := 28
const POINTER_DEVICE := -100
const STICK_DEADZONE := 0.20
const TRIGGER_PRESS := 0.60
const TRIGGER_RELEASE := 0.35
const STACK_LIFT := -22.0
const LABEL_COLORS := ["#367d80", "#a05261", "#646095", "#8b693c"]

var titles := PackedStringArray(["Star Hopper", "Midnight Rally", "Moon Orchard", "Wave Rider", "Snow Circuit", "Tiny Atlas"])
var rom_paths := PackedStringArray()
var emulator := preload("res://emulator/bridge.gd").new()
var core_picker := OptionButton.new()
var rom_folder := ""
var art_folder := ""
var art_paths: Dictionary[String, String] = {}
var sidecar_paths: Dictionary[String, String] = {}
var label_textures: Dictionary[String, Texture2D] = {}
var shader_preset := 1
var preferred_core := 0
var preview_started := 0
var inserted := -1
var dragging := -1
var dragging_plug := false
var plug_grab_offset := Vector2.ZERO
var seated := false
var powered := false
var page := 0
var stacked := true
var stack_offsets: Dictionary[int, float] = {}
var stack_tweens: Dictionary[int, Tween] = {}
var hovered := -1:
	set(index):
		if hovered == index:
			return
		var previous := hovered
		hovered = index
		if previous >= 0:
			ease_stack_card(previous, 0.0)
		if index >= 0:
			ease_stack_card(index, STACK_LIFT)
var pointer := Vector2.ZERO
var virtual_position := Vector2.ZERO
var virtual_pointer_active := false
var pointer_art: ImageTexture
var left_trigger := false
var right_trigger := false
var previous_page_button := Button.new()
var next_page_button := Button.new()
var page_label := Label.new()
var alphabet_button := MenuButton.new()
var message := "Drag a cartridge into the console slot."
var eject_animation: Tween
var lift := 0.0:
	set(value):
		lift = value
		queue_redraw()

var crt := TextureRect.new()
var room_dimmer := ColorRect.new()
var ceiling_light_on := true
var television := Television.ORIGINAL
var scanlines_enabled := false
var screen_spill := ColorRect.new()
var screen_light := Color.BLACK
var last_insert := -1
var last_eject := -1
var insert_sound := AudioStreamPlayer.new()
var eject_sound := AudioStreamPlayer.new()
var diagnostics := Label.new()

func _ready() -> void:
	for player in [insert_sound, eject_sound]:
		player.volume_db = -7.0
		add_child(player)
	restore_preferences()
	room_dimmer.color = Color("#0a0816ca")
	room_dimmer.size = Vector2(1152, 607)
	room_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room_dimmer.visible = not ceiling_light_on
	add_child(room_dimmer)
	var spill_material := ShaderMaterial.new()
	spill_material.shader = preload("res://emulator/crt_spill.gdshader")
	screen_spill.material = spill_material
	screen_spill.size = Vector2(793, 607)
	screen_spill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_spill.hide()
	add_child(screen_spill)
	var crt_material := ShaderMaterial.new()
	crt_material.shader = preload("res://emulator/crt.gdshader")
	crt_material.set_shader_parameter("glass_size", SCREEN.size)
	crt_material.set_shader_parameter("scanlines", scanlines_enabled)
	crt_material.set_shader_parameter("preset", shader_preset)
	crt.material = crt_material
	crt.position = SCREEN.position
	crt.size = SCREEN.size
	crt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.hide()
	add_child(crt)
	add_child(emulator)
	emulator.frame_changed.connect(update_crt)
	emulator.failed.connect(show_emulator_error)

	setup_settings()
	setup_cartridge_navigation()
	get_window().mouse_exited.connect(func(): hovered = -1)
	# Godot's built-in UI actions otherwise also react to SNES gameplay buttons.
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			for binding in InputMap.action_get_events(action):
				if binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
					InputMap.action_erase_event(action, binding)
	var cursor := Image.new()
	cursor.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26"><circle cx="13" cy="13" r="9" fill="#2b2037" fill-opacity=".6" stroke="#ffe6bf" stroke-width="2"/><circle cx="13" cy="13" r="2" fill="#ffe6bf"/></svg>')
	pointer_art = ImageTexture.create_from_image(cursor)

	diagnostics.position = Vector2(163, 49)
	diagnostics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#171320ed")
	panel.content_margin_left = 8
	panel.content_margin_right = 8
	panel.content_margin_top = 5
	panel.content_margin_bottom = 5
	diagnostics.add_theme_stylebox_override("normal", panel)
	diagnostics.add_theme_font_size_override("font_size", 12)
	diagnostics.hide()
	add_child(diagnostics)
	if not rom_folder.is_empty():
		load_folder(rom_folder)

func _exit_tree() -> void:
	insert_sound.stop()
	eject_sound.stop()

func play_cartridge_sound(player: AudioStreamPlayer, clips: Array, previous: int) -> int:
	var index := randi_range(0, clips.size() - 1)
	if index == previous:
		index = (index + randi_range(1, clips.size() - 1)) % clips.size()
	player.stream = clips[index]
	player.play()
	return index

func restore_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	rom_folder = str(config.get_value("library", "rom_folder", ""))
	art_folder = str(config.get_value("library", "art_folder", ""))
	stacked = bool(config.get_value("library", "stacked", true))
	ceiling_light_on = bool(config.get_value("room", "ceiling_light", true))
	television = clampi(int(config.get_value("room", "television", Television.ORIGINAL)), Television.ORIGINAL, Television.SILVER) as Television
	preferred_core = clampi(int(config.get_value("emulation", "core", 0)), 0, emulator.CORE_NAMES.size() - 1)
	shader_preset = clampi(int(config.get_value("emulation", "shader_preset", 1)), 0, 2)
	scanlines_enabled = bool(config.get_value("emulation", "scanlines", false))

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("library", "rom_folder", rom_folder)
	config.set_value("library", "art_folder", art_folder)
	config.set_value("library", "stacked", stacked)
	config.set_value("room", "ceiling_light", ceiling_light_on)
	config.set_value("room", "television", television)
	config.set_value("emulation", "core", preferred_core)
	config.set_value("emulation", "shader_preset", shader_preset)
	config.set_value("emulation", "scanlines", scanlines_enabled)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Could not save Bedroom Arcade settings.")

func settings_style(fill: String, edge: String, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style

func make_settings_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 15
	var panel := settings_style("#211a2c", "#796078", 12)
	panel.shadow_color = Color("#0a0714b9")
	panel.shadow_size = 8
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "PopupMenu", settings_style("#2b2035", "#796078", 6))
	theme.set_stylebox("hover", "PopupMenu", settings_style("#654358", "#90697e", 4))
	theme.set_color("font_color", "PopupMenu", Color("#f5e4db"))
	theme.set_color("font_color", "Label", Color("#d9bbc8"))
	var normal := settings_style("#36283e", "#685068", 6)
	var hover := settings_style("#4e354d", "#ac7c8b", 6)
	var pressed := settings_style("#654358", "#d4a591", 6)
	var focus := settings_style("#00000000", "#edb99a", 6)
	focus.draw_center = false
	for control_type in ["Button", "OptionButton", "CheckButton"]:
		theme.set_stylebox("normal", control_type, normal)
		theme.set_stylebox("hover", control_type, hover)
		theme.set_stylebox("pressed", control_type, pressed)
		theme.set_stylebox("hover_pressed", control_type, pressed)
		theme.set_stylebox("focus", control_type, focus)
		theme.set_color("font_color", control_type, Color("#f5e4db"))
		theme.set_color("font_hover_color", control_type, Color("#fff0db"))
		theme.set_color("font_pressed_color", control_type, Color("#fff0db"))
	return theme

func add_settings_heading(menu: VBoxContainer, title: String) -> void:
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 23)
	heading.add_theme_color_override("font_color", Color("#ffdbc0"))
	menu.add_child(heading)
	var divider := HSeparator.new()
	divider.add_theme_stylebox_override("separator", settings_style("#796078", "#796078", 0))
	menu.add_child(divider)

func setup_settings() -> void:
	var picker := FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.dir_selected.connect(func(path: String):
		if picker.title == "Choose cartridge art folder":
			load_art_folder(path)
		else:
			load_folder(path))
	add_child(picker)

	var settings := PopupPanel.new()
	settings.name = "Settings"
	settings.theme = make_settings_theme()
	add_child(settings)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 9)
	settings.add_child(menu)
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 17)

	add_settings_heading(menu, "Settings")

	var folder_button := Button.new()
	folder_button.text = "Choose ROM folder"
	folder_button.pressed.connect(func():
		settings.hide()
		picker.title = "Choose ROM folder"
		if DirAccess.dir_exists_absolute(rom_folder):
			picker.current_dir = rom_folder
		picker.popup_centered_ratio(0.8))
	menu.add_child(folder_button)

	var emulation_page := VBoxContainer.new()
	emulation_page.add_theme_constant_override("separation", 9)
	settings.add_child(emulation_page)
	emulation_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 17)
	emulation_page.hide()

	var emulation_button := Button.new()
	emulation_button.text = "Emulation  ›"
	emulation_button.pressed.connect(func():
		menu.hide()
		emulation_page.show()
		settings.popup_centered(Vector2i(344, 412)))
	menu.add_child(emulation_button)

	var back := Button.new()
	back.text = "‹  Back to settings"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(func():
		emulation_page.hide()
		menu.show()
		settings.popup_centered(Vector2i(344, 358)))
	emulation_page.add_child(back)
	add_settings_heading(emulation_page, "Emulation")

	var core_label := Label.new()
	core_label.text = "SNES core"
	emulation_page.add_child(core_label)
	core_picker.tooltip_text = "Emulation core for the next cartridge"
	for name in emulator.CORE_NAMES:
		core_picker.add_item(name)
	core_picker.select(preferred_core)
	core_picker.item_selected.connect(func(index: int):
		preferred_core = index
		save_preferences())
	emulation_page.add_child(core_picker)
	add_emulation_controls(emulation_page)

	var layout_label := Label.new()
	layout_label.text = "Cartridge view"
	menu.add_child(layout_label)
	var layout_picker := OptionButton.new()
	layout_picker.add_item("Grid")
	layout_picker.add_item("Stack")
	layout_picker.select(1 if stacked else 0)
	layout_picker.item_selected.connect(change_layout)
	menu.add_child(layout_picker)

	var art_button := Button.new()
	art_button.text = "Choose cartridge art folder"
	art_button.pressed.connect(func():
		settings.hide()
		picker.title = "Choose cartridge art folder"
		var start_dir := art_folder if DirAccess.dir_exists_absolute(art_folder) else rom_folder
		if DirAccess.dir_exists_absolute(start_dir):
			picker.current_dir = start_dir
		picker.popup_centered_ratio(0.8))
	menu.add_child(art_button)
	menu.move_child(art_button, folder_button.get_index() + 1)
	for button in [folder_button, art_button, emulation_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var tv_label := Label.new()
	tv_label.text = "CRT television"
	menu.add_child(tv_label)
	var tv_picker := OptionButton.new()
	tv_picker.name = "TelevisionPicker"
	tv_picker.add_item("Original", Television.ORIGINAL)
	tv_picker.add_item("Graphite", Television.GRAPHITE)
	tv_picker.add_item("Silver", Television.SILVER)
	tv_picker.select(int(television))
	tv_picker.item_selected.connect(func(index: int):
		television = tv_picker.get_item_id(index) as Television
		save_preferences()
		queue_redraw())
	menu.add_child(tv_picker)
	menu.move_child(emulation_button, menu.get_child_count() - 1)

	var gear := Button.new()
	gear.name = "SettingsButton"
	gear.text = "⚙"
	gear.tooltip_text = "Settings"
	gear.position = Vector2(1084, 214)
	gear.custom_minimum_size = Vector2(34, 32)
	gear.flat = true
	gear.add_theme_font_size_override("font_size", 21)
	gear.pressed.connect(func():
		hovered = -1
		queue_redraw()
		emulation_page.hide()
		menu.show()
		settings.popup_centered(Vector2i(344, 358)))
	add_child(gear)

func add_emulation_controls(page_controls: VBoxContainer) -> void:
	var state_buttons := HBoxContainer.new()
	state_buttons.add_theme_constant_override("separation", 8)
	for action in ["Save state", "Load state"]:
		var button := Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var save: bool = action == "Save state"
		button.pressed.connect(func(): emulator.request_state(save))
		state_buttons.add_child(button)
	page_controls.add_child(state_buttons)

	var state_status := Label.new()
	state_status.text = "One state per game and core"
	state_status.add_theme_font_size_override("font_size", 13)
	emulator.state_result.connect(func(result: String): state_status.text = result)
	page_controls.add_child(state_status)

	var scanlines := CheckButton.new()
	scanlines.text = "Scanlines"
	scanlines.button_pressed = scanlines_enabled
	scanlines.toggled.connect(func(enabled: bool):
		scanlines_enabled = enabled
		crt.material.set_shader_parameter("scanlines", enabled)
		save_preferences()
		queue_redraw())
	page_controls.add_child(scanlines)

	var shader_label := Label.new()
	shader_label.text = "Shader preset"
	page_controls.add_child(shader_label)
	var shader_picker := OptionButton.new()
	for preset in ["Standard", "Soft CRT", "RGB Mask"]:
		shader_picker.add_item(preset)
	shader_picker.select(shader_preset)
	shader_picker.item_selected.connect(func(index: int):
		shader_preset = index
		crt.material.set_shader_parameter("preset", index)
		save_preferences())
	page_controls.add_child(shader_picker)

func update_crt() -> void:
	if crt.texture != emulator.picture:
		crt.texture = emulator.picture
		crt.visible = crt.texture != null
	if crt.material.get_shader_parameter("rgb565") != emulator.rgb565:
		crt.material.set_shader_parameter("rgb565", emulator.rgb565)

func load_folder(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		message = "That folder could not be opened."
		queue_redraw()
		return
	if path != rom_folder:
		rom_folder = path
		save_preferences()
	emulator.stop()
	titles.clear()
	rom_paths.clear()
	var files := Array(folder.get_files())
	files.sort_custom(func(left: String, right: String): return left.naturalnocasecmp_to(right) < 0)
	for file in files:
		if file.get_extension().to_lower() in ["sfc", "smc"]:
			titles.append(file.get_basename())
			rom_paths.append(path.path_join(file))
	refresh_label_art()
	inserted = -1
	dragging = -1
	seated = false
	powered = false
	page = 0
	refresh_alphabet()
	update_page_controls()
	clear_stack_hover()
	reset_lift()
	message = "No .sfc or .smc files in this folder." if titles.is_empty() else "Drag a cartridge into the console slot."
	queue_redraw()

func load_art_folder(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		message = "That artwork folder could not be opened."
		queue_redraw()
		return
	art_folder = path
	save_preferences()
	refresh_label_art()
	queue_redraw()

func refresh_label_art() -> void:
	art_paths = index_label_images(art_folder)
	sidecar_paths = index_label_images(rom_folder)
	label_textures.clear()

func index_label_images(path: String) -> Dictionary[String, String]:
	var images: Dictionary[String, String] = {}
	if path.is_empty():
		return images
	var files := DirAccess.get_files_at(path)
	files.sort()
	for file in files:
		if file.get_extension().to_lower() in ["png", "jpg", "jpeg"]:
			var title := file.get_basename().to_lower()
			if not images.has(title):
				images[title] = path.path_join(file)
	return images

func cartridge_label_texture(index: int) -> Texture2D:
	if index >= rom_paths.size():
		return null
	var title := titles[index].to_lower()
	if not label_textures.has(title):
		var image := Image.new()
		var texture: Texture2D
		for path in [art_paths.get(title, ""), sidecar_paths.get(title, "")]:
			if path.is_empty():
				continue
			if image.load(path) == OK and not image.is_empty():
				prepare_label_image(image)
				texture = ImageTexture.create_from_image(image)
				break
		label_textures[title] = texture
	return label_textures[title]

func prepare_label_image(image: Image) -> void:
	# Cache the stretched, antialiased label at twice its on-screen size.
	var size := Vector2i(LABEL_SIZE * 2.0)
	var radius := LABEL_RADIUS * 2
	image.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	for x in range(radius):
		for y in range(radius):
			var distance := Vector2(radius - x - 0.5, radius - y - 0.5).length()
			var coverage := clampf(radius + 0.5 - distance, 0.0, 1.0)
			for corner_x in [x, size.x - 1 - x]:
				for corner_y in [y, size.y - 1 - y]:
					var pixel := image.get_pixel(corner_x, corner_y)
					pixel.a *= coverage
					image.set_pixel(corner_x, corner_y, pixel)

func reset_lift() -> void:
	if eject_animation:
		eject_animation.kill()
	lift = 0.0

func page_size() -> int:
	return STACK_PAGE_SIZE if stacked else GRID_PAGE_SIZE

func visible_cartridges() -> Array:
	var size := page_size()
	return range(page * size, mini(titles.size(), (page + 1) * size))

func change_layout(index: int) -> void:
	var first_visible := page * page_size()
	stacked = index == 1
	save_preferences()
	page = floori(first_visible / float(page_size()))
	update_page_controls()
	clear_stack_hover()
	queue_redraw()

func desk_position(index: int) -> Vector2:
	var cell := index % page_size()
	var row_spacing := STACK_ROW_SPACING if stacked else 98
	return Vector2(785 + (cell % 2) * 168, (315 if stacked else 258) + floori(cell / 2.0) * row_spacing)

func displayed_desk_position(index: int) -> Vector2:
	return desk_position(index) + Vector2(0, stack_offsets.get(index, 0.0))

func ease_stack_card(index: int, target: float) -> void:
	if stack_tweens.has(index):
		stack_tweens[index].kill()
	var start: float = stack_offsets.get(index, 0.0)
	if is_equal_approx(start, target):
		stack_tweens.erase(index)
		return
	var tween := create_tween()
	stack_tweens[index] = tween
	tween.tween_method(func(offset: float):
		stack_offsets[index] = offset
		queue_redraw(), start, target, 0.17 if target < 0.0 else 0.21
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.finished.connect(func():
		stack_tweens.erase(index)
		if is_zero_approx(target):
			stack_offsets.erase(index))

func clear_stack_hover() -> void:
	hovered = -1
	for tween in stack_tweens.values():
		tween.kill()
	stack_tweens.clear()
	stack_offsets.clear()

func desk_cartridge_at(point: Vector2) -> int:
	var visible := visible_cartridges()
	# Hit-test from front to back, just like the stack is drawn.
	for offset in range(visible.size() - 1, -1, -1):
		var index: int = visible[offset]
		if index != inserted and Rect2(displayed_desk_position(index), CART_SIZE).has_point(point):
			return index
	# Keep the lift stable if the pointer was on the bottom edge when it moved.
	if hovered >= 0 and Rect2(desk_position(hovered), CART_SIZE).has_point(point):
		return hovered
	return -1

func console_position() -> Vector2:
	var slot_lip := CONSOLE_TRANSFORM * Vector2(SLOT_ART.get_center().x, SLOT_ART.end.y)
	return slot_lip - Vector2(CART_SIZE.x / 2.0, SEATED_CART_HEIGHT + lift)

func console_cartridge_height() -> float:
	return minf(CART_SIZE.y, SEATED_CART_HEIGHT + lift)

func setup_cartridge_navigation() -> void:
	var controls := HBoxContainer.new()
	controls.position = Vector2(783, 575)
	controls.size = Vector2(331, 26)
	controls.add_theme_constant_override("separation", 8)
	previous_page_button.text = "‹"
	previous_page_button.tooltip_text = "Previous page"
	previous_page_button.pressed.connect(func(): turn_page(-1))
	next_page_button.text = "›"
	next_page_button.tooltip_text = "Next page"
	next_page_button.pressed.connect(func(): turn_page(1))
	for button in [previous_page_button, next_page_button]:
		button.custom_minimum_size = Vector2(34, 26)
		button.focus_mode = Control.FOCUS_NONE
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alphabet_button.text = "A–Z"
	alphabet_button.tooltip_text = "Jump to a title by its first letter"
	alphabet_button.focus_mode = Control.FOCUS_NONE
	alphabet_button.get_popup().id_pressed.connect(jump_to_title)
	for control in [previous_page_button, page_label, next_page_button, alphabet_button]:
		controls.add_child(control)
	add_child(controls)
	refresh_alphabet()
	update_page_controls()

func page_count() -> int:
	return maxi(1, ceili(titles.size() / float(page_size())))

func turn_page(direction: int) -> void:
	var next_page := clampi(page + direction, 0, page_count() - 1)
	if next_page == page:
		return
	page = next_page
	clear_stack_hover()
	update_page_controls()
	queue_redraw()

func jump_to_title(index: int) -> void:
	page = floori(index / float(page_size()))
	clear_stack_hover()
	update_page_controls()
	queue_redraw()

func update_page_controls() -> void:
	page_label.text = "%d / %d" % [page + 1, page_count()]
	previous_page_button.disabled = page == 0
	next_page_button.disabled = page >= page_count() - 1

func refresh_alphabet() -> void:
	var menu := alphabet_button.get_popup()
	menu.clear()
	var seen := {}
	for index in range(titles.size()):
		var letter := titles[index].left(1).to_upper()
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(letter) or letter.is_empty():
			letter = "#"
		if not seen.has(letter):
			menu.add_item(letter, index)
			seen[letter] = true
	alphabet_button.disabled = menu.item_count == 0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if virtual_pointer_active and event.device != POINTER_DEVICE and event.position.distance_to(virtual_position) > 3.0:
			hide_virtual_pointer()
		if dragging_plug or dragging >= 0:
			pointer = event.position
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if event.device != POINTER_DEVICE:
			hide_virtual_pointer()
		if dragging_plug:
			drop_plug(event.position)
			get_viewport().set_input_as_handled()
		elif dragging >= 0:
			drop_at(event.position)
			queue_redraw()
			get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif event.keycode == KEY_F10:
			diagnostics.visible = not diagnostics.visible
	elif event is InputEventMouseMotion:
		pointer = event.position
		hovered = desk_cartridge_at(pointer) if stacked and dragging < 0 and not dragging_plug else -1
	elif event is InputEventMouseButton:
		pointer = event.position
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press_at(pointer)
		elif event.pressed and DESK.has_point(pointer) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			turn_page(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
	queue_redraw()

func hide_virtual_pointer() -> void:
	if virtual_pointer_active:
		virtual_pointer_active = false
		Input.set_custom_mouse_cursor(null)

func update_gamepad_pointer(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		if virtual_pointer_active:
			dragging = -1
			dragging_plug = false
			queue_redraw()
		hide_virtual_pointer()
		left_trigger = false
		right_trigger = false
		return
	var pad := pads[0]
	var left := Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
	var right := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
	var stick := left if left.length_squared() >= right.length_squared() else right
	var strength := clampf((stick.length() - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 0.0, 1.0)
	var focused := get_window().has_focus()
	for window in get_viewport().get_embedded_subwindows():
		focused = focused or window.has_focus()
	if strength > 0.0 and focused:
		move_virtual_pointer(stick.normalized() * strength * delta * 780.0)
	var l2 := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_LEFT)
	var r2 := Input.get_joy_axis(pad, JOY_AXIS_TRIGGER_RIGHT)
	var l2_pressed := l2 >= (TRIGGER_RELEASE if left_trigger else TRIGGER_PRESS)
	var r2_pressed := r2 >= (TRIGGER_RELEASE if right_trigger else TRIGGER_PRESS)
	if focused and virtual_pointer_active:
		if l2_pressed and not left_trigger:
			virtual_interact(true)
		elif r2_pressed and not right_trigger:
			virtual_interact(false)
	left_trigger = l2_pressed
	right_trigger = r2_pressed

func move_virtual_pointer(motion: Vector2) -> void:
	var bounds := get_viewport_rect()
	if not virtual_pointer_active:
		virtual_position = get_viewport().get_mouse_position()
		virtual_pointer_active = true
		Input.set_custom_mouse_cursor(pointer_art, Input.CURSOR_ARROW, Vector2(13, 13))
	virtual_position = (virtual_position + motion).clamp(bounds.position, bounds.end - Vector2.ONE)
	get_viewport().warp_mouse(virtual_position)
	var event := InputEventMouseMotion.new()
	event.device = POINTER_DEVICE
	event.position = virtual_position
	event.global_position = virtual_position
	get_viewport().push_input(event, true)

func virtual_interact(grab: bool) -> void:
	var carrying := dragging >= 0 or dragging_plug
	if carrying:
		if grab and dragging_plug:
			drop_plug(virtual_position)
		elif grab:
			drop_at(virtual_position)
		else:
			dragging = -1
			dragging_plug = false
		queue_redraw()
		return

	# R2 activates room controls and menus. L2 can also pick up physical objects.
	for pressed in [true, false]:
		if not pressed and grab and (dragging >= 0 or dragging_plug):
			break
		var event := InputEventMouseButton.new()
		event.device = POINTER_DEVICE
		event.position = virtual_position
		event.global_position = virtual_position
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.pressed = pressed
		get_viewport().push_input(event, true)

func press_at(point: Vector2) -> void:
	var plug := player_two_plug_position()
	if CEILING_LIGHT.has_point(point) and dragging < 0:
		ceiling_light_on = not ceiling_light_on
		room_dimmer.visible = not ceiling_light_on
		save_preferences()
		queue_redraw()
		return
	if dragging < 0 and Rect2(plug, PLUG_SIZE).has_point(point):
		dragging_plug = true
		plug_grab_offset = point - plug
		pointer = point
		hovered = -1
		queue_redraw()
	elif RESET.has_point(point) and seated:
		if emulator.running:
			emulator.reset()
		elif not powered:
			start_cartridge()
		else:
			preview_started = Time.get_ticks_msec()
			message = "CRT preview reset."
	elif EJECT.has_point(point) and seated:
		last_eject = play_cartridge_sound(eject_sound, EJECT_SOUNDS, last_eject)
		emulator.stop()
		powered = false
		seated = false
		eject_animation = create_tween()
		eject_animation.tween_property(self, "lift", minf(CART_SIZE.y - SEATED_CART_HEIGHT + 2.0, console_position().y - SCREEN.end.y - 5.0), 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		message = "Drag the ejected cartridge back to the shoebox."
	elif inserted >= 0 and not seated and Rect2(console_position(), Vector2(CART_SIZE.x, console_cartridge_height())).has_point(point):
		dragging = inserted
	elif inserted < 0:
		dragging = desk_cartridge_at(point)
		if dragging >= 0:
			hovered = -1

func seated_plug_position(socket: Rect2) -> Vector2:
	return Vector2(socket.get_center().x - PLUG_SIZE.x / 2.0, socket.position.y - 1.0)

func player_two_plug_position() -> Vector2:
	if dragging_plug:
		return pointer - plug_grab_offset
	return seated_plug_position(PLAYER_TWO_SOCKET) if emulator.player_two_connected else LOOSE_PLUG

func plug_over_socket(point: Vector2) -> bool:
	var plug_center := point - plug_grab_offset + PLUG_SIZE / 2.0
	return PLAYER_TWO_SOCKET.grow(14).has_point(plug_center)

func drop_plug(point: Vector2) -> void:
	var connected := plug_over_socket(point)
	if connected != emulator.player_two_connected:
		emulator.set_player_two(connected)
		message = "Player 2 controller connected." if connected else "Player 2 controller disconnected."
	dragging_plug = false
	queue_redraw()

func drop_at(point: Vector2) -> void:
	if dragging < 0:
		return
	if SLOT.grow(20).has_point(point):
		inserted = dragging
		seated = true
		reset_lift()
		last_insert = play_cartridge_sound(insert_sound, INSERT_SOUNDS, last_insert)
		start_cartridge()
	elif dragging == inserted and DESK.has_point(point):
		inserted = -1
		reset_lift()
		message = "Drag a cartridge into the console slot."
	dragging = -1

func start_cartridge() -> void:
	if rom_paths.is_empty():
		powered = true
		preview_started = Time.get_ticks_msec()
		message = "CRT preview running. Choose a ROM folder to play."
		return
	var error: String = emulator.start(rom_paths[inserted], core_picker.selected)
	if not error.is_empty():
		show_emulator_error(error)
		return
	powered = true
	message = ""

func show_emulator_error(error: String) -> void:
	powered = false
	message = error
	queue_redraw()

func _process(delta: float) -> void:
	update_gamepad_pointer(delta)
	var target := emulator.screen_light
	if powered and rom_paths.is_empty():
		target = Color("#496185")
	screen_light = screen_light.lerp(target, 1.0 - exp(-delta * 11.0))
	screen_spill.visible = screen_light.get_luminance() > 0.005
	if screen_spill.visible:
		screen_spill.material.set_shader_parameter("light_color", Vector3(screen_light.r, screen_light.g, screen_light.b))
	if diagnostics.visible:
		var status: String = emulator.stats if emulator.running and not emulator.stats.is_empty() else "Insert a ROM to measure playback…"
		if diagnostics.text != status:
			diagnostics.text = status
	if powered and rom_paths.is_empty():
		queue_redraw()

func box(x: float, y: float, width: float, height: float, color: String) -> void:
	draw_rect(Rect2(x, y, width, height), Color(color))

func words(value: String, x: float, y: float, size: int, width := -1) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, width, size, Color("#f9e4c5"))

func gradient(rect: Rect2, top: String, bottom: String) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(points, PackedColorArray([Color(top), Color(top), Color(bottom), Color(bottom)]))

func shape(points: PackedVector2Array, color: String) -> void:
	draw_colored_polygon(points, Color(color))

func rounded(rect: Rect2, radius: int, fill: String, border: String = "") -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(radius)
	style.bg_color = Color(fill)
	if not border.is_empty():
		style.border_color = Color(border)
		style.set_border_width_all(1)
	draw_style_box(style, rect)

func glow(center: Vector2, size: Vector2, tint: Color) -> void:
	var points := PackedVector2Array([center])
	var colors := PackedColorArray([tint])
	var edge := Color(tint, 0.0)
	for step in range(65):
		var angle := step * TAU / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
		colors.append(edge)
	# Draw a triangle fan so the light fades smoothly to its perimeter.
	for step in range(1, 65):
		draw_polygon(PackedVector2Array([points[0], points[step], points[step + 1]]),
			PackedColorArray([colors[0], colors[step], colors[step + 1]]))

func line(from: Vector2, to: Vector2, color: String, width: float = 1.0) -> void:
	draw_line(from, to, Color(color), width, true)

func cartridge(index: int, at: Vector2, visible_height := CART_SIZE.y) -> void:
	var width := CART_SIZE.x
	draw_set_transform(at)
	if visible_height == CART_SIZE.y:
		rounded(Rect2(Vector2(3, 5), CART_SIZE), 6, "#18142596")

	# The light catches the shallow top plane before rolling over the front edge.
	shape([Vector2(0, 7), Vector2(2, 3), Vector2(8, 1), Vector2(width - 8, 1),
		Vector2(width - 2, 3), Vector2(width, 7)], "#ded8d4")
	line(Vector2(8, 1.8), Vector2(width - 8, 1.8), "#f5ece0")
	for x in [22.0, width - 22.0]:
		var tilt := 1.0 if x < width / 2.0 else -1.0
		line(Vector2(x + tilt, 1.5), Vector2(x, 7), "#938a91")
		line(Vector2(x + tilt + 1, 2), Vector2(x + 1, 7), "#eee5de")

	var body := PackedVector2Array([Vector2(0, 7), Vector2(width, 7),
		Vector2(width - 2, visible_height - 4), Vector2(width - 6, visible_height),
		Vector2(6, visible_height), Vector2(2, visible_height - 4)])
	var top := Color("#c6c0c3")
	var bottom := Color("#9e98a2")
	draw_polygon(body, PackedColorArray([top, top, bottom, bottom, bottom, bottom]))
	line(Vector2(1, 7), Vector2(width - 1, 7), "#f2e9e0")
	line(Vector2(2, 10), Vector2(4, visible_height - 5), "#ddd5d4")
	line(Vector2(width - 2, 10), Vector2(width - 4, visible_height - 5), "#807985")
	for y in range(14, 31, 4):
		line(Vector2(2, y), Vector2(5, y + 1), "#8f8994")
		line(Vector2(width - 5, y + 1), Vector2(width - 2, y), "#8f8994")

	var label := Rect2(Vector2(8, 8), LABEL_SIZE)
	rounded(label.grow(0.75), LABEL_RADIUS + 1, "#e5ddda", "#a29aa1")
	var art := cartridge_label_texture(index)
	if art:
		rounded(label, LABEL_RADIUS, "#36313b")
		draw_texture_rect(art, label, false)
	else:
		rounded(label, LABEL_RADIUS, LABEL_COLORS[index % LABEL_COLORS.size()])
		draw_circle(Vector2(width - 23, 18), 8, Color("#ffcf913c"), true, -1, true)
		line(Vector2(13, 17), Vector2(53, 17), "#f8c992", 2)
		words(titles[index], 13, 39, 11, int(width) - 26)

	for x in [22.0, width - 22.0]:
		line(Vector2(x, label.end.y + 1), Vector2(x, visible_height - 1), "#817983")
		line(Vector2(x + 1, label.end.y + 1), Vector2(x + 1, visible_height - 1), "#c4bbc0")
	if visible_height > 57.0:
		var grip_height := minf(8.0, visible_height - 56.0)
		rounded(Rect2(31, 56, width - 62, grip_height), 3, "#756e7b", "#d6cdd0")
		for y in range(58, mini(62, floori(56 + grip_height))):
			line(Vector2(35, y), Vector2(width - 35, y), "#9b929c")
	var screw_y := CART_SIZE.y - 13.0
	if visible_height >= screw_y + 3.0:
		for x in [11.0, width - 11.0]:
			draw_circle(Vector2(x, screw_y), 2.5, Color("#665e6a"), true, -1, true)
			line(Vector2(x - 1, screw_y), Vector2(x + 1, screw_y), "#b5a9b2")
	draw_set_transform(Vector2.ZERO)

func draw_bedroom() -> void:
	draw_texture_rect(preload("res://art/bedroom.jpg"), Rect2(0, 0, 1152, 648), false)
	if ceiling_light_on:
		glow(Vector2(1035, 132), Vector2(255, 219), Color("#ec91a349"))

	# Woven rug under the console.
	shape([Vector2(188, 483), Vector2(630, 483), Vector2(754, 600), Vector2(84, 600)], "#261c2b7f")
	shape([Vector2(192, 481), Vector2(626, 481), Vector2(733, 594), Vector2(96, 594)], "#443044")
	shape([Vector2(205, 488), Vector2(615, 488), Vector2(706, 581), Vector2(123, 581)], "#614454")
	for y in range(491, 581, 4):
		var side := (y - 491) * 0.85
		line(Vector2(204 - side, y), Vector2(616 + side, y), "#bd87902b")
	glow(Vector2(414, 492), Vector2(305, 115), Color("#161323a5"))

func draw_ceiling_light() -> void:
	line(Vector2(1033, 0), Vector2(1033, 71), "#564150", 3)
	if ceiling_light_on:
		glow(Vector2(1033, 110), Vector2(113, 71), Color("#ffd2aa75"))
	shape([Vector2(1003, 71), Vector2(1063, 71), Vector2(1091, 108),
		Vector2(975, 108)], "#a66d67" if ceiling_light_on else "#493847")
	shape([Vector2(1011, 73), Vector2(1055, 73), Vector2(1075, 106),
		Vector2(988, 106)], "#c48c77" if ceiling_light_on else "#5a4451")
	rounded(Rect2(975, 105, 116, 10), 5, "#f5bc92" if ceiling_light_on else "#43333e")
	if CEILING_LIGHT.has_point(pointer):
		line(Vector2(992, 108), Vector2(1075, 108), "#fff0d8" if ceiling_light_on else "#9d7b8b", 2)

func draw_shoebox() -> void:
	# The lid rests against the back of the box.
	glow(Vector2(945, 585), Vector2(200, 27), Color("#140b16a0"))
	shape([Vector2(785, 311), Vector2(810, 244), Vector2(1091, 250),
		Vector2(1114, 316)], "#45313b")
	shape([Vector2(796, 306), Vector2(818, 251), Vector2(1084, 257),
		Vector2(1102, 310)], "#896459")
	line(Vector2(819, 252), Vector2(1083, 258), "#c3967c", 2)
	line(Vector2(809, 276), Vector2(1091, 282), "#a57969", 2)
	rounded(Rect2(915, 262, 70, 14), 2, "#cfab8c35")

	# The back and side walls frame the darker cardboard interior.
	var rear_lift := 0.0 if stacked else 44.0
	shape([Vector2(777, 293 - rear_lift), Vector2(1120, 293 - rear_lift), Vector2(1131, 556),
		Vector2(751, 556)], "#a27c6e")
	shape([Vector2(781, 299 - rear_lift), Vector2(1115, 299 - rear_lift), Vector2(1115, 324 - rear_lift),
		Vector2(781, 324 - rear_lift)], "#63454a")
	shape([Vector2(781, 319 - rear_lift), Vector2(1115, 319 - rear_lift), Vector2(1119, 553),
		Vector2(764, 553)], "#5c4148")
	shape([Vector2(777, 301 - rear_lift), Vector2(781, 319 - rear_lift), Vector2(774, 548),
		Vector2(759, 553)], "#79574f")
	shape([Vector2(1120, 302 - rear_lift), Vector2(1123, 553), Vector2(1109, 548),
		Vector2(1115, 319 - rear_lift)], "#3d2b37")
	line(Vector2(779, 293 - rear_lift), Vector2(1118, 293 - rear_lift), "#ca9a7d", 2)
	line(Vector2(777, 294 - rear_lift), Vector2(752, 555), "#c3947c", 2)
	line(Vector2(1120, 294 - rear_lift), Vector2(1130, 555), "#b38671", 2)
	for index in range(12):
		var y := 330 + index * 18
		line(Vector2(778 + (index * 13) % 79, y),
			Vector2(1100 - (index * 17) % 75, y + 1), "#c0987e17")

func draw_shoebox_front() -> void:
	# Draw the front lip after the contents so it occludes their shadows.
	shape([Vector2(753, 553), Vector2(1130, 553), Vector2(1122, 596),
		Vector2(761, 596)], "#7f5955")
	gradient(Rect2(762, 560, 359, 35), "#8e665c", "#5c3d47")
	line(Vector2(754, 554), Vector2(1128, 554), "#cea084", 3)
	line(Vector2(760, 562), Vector2(1125, 562), "#b28472")
	line(Vector2(762, 595), Vector2(1121, 595), "#3a2935", 2)
	for x in [770, 1112]:
		line(Vector2(x, 562), Vector2(x, 592), "#68474b")
	rounded(Rect2(919, 564, 48, 7), 4, "#50343e", "#a77565")

func draw_tv_stand() -> void:
	# The console sits in front of the stand, with the TV's feet on its top.
	glow(Vector2(419, 535), Vector2(315, 30), Color("#120d1990"))
	# The shelf passes behind the front legs, hiding both ends at the joints.
	shape([Vector2(161, 517), Vector2(185, 493), Vector2(654, 493),
		Vector2(679, 517)], "#473443")
	gradient(Rect2(161, 517, 518, 10), "#795464", "#392737")
	line(Vector2(161, 517), Vector2(679, 517), "#a275804f")
	for x in [150, 668]:
		gradient(Rect2(x, 454, 21, 83), "#5d414a", "#2d202e")
		line(Vector2(x + 3, 456), Vector2(x + 3, 532), "#9a697253")
	shape([Vector2(121, 443), Vector2(149, 427), Vector2(692, 427),
		Vector2(718, 443)], "#5f4556")
	gradient(Rect2(121, 443, 597, 12), "#836274", "#463242")
	line(Vector2(125, 443), Vector2(714, 443), "#ab80915c")
	var right_foot := 606 if television == Television.SILVER else 646
	for x in [170, right_foot]:
		rounded(Rect2(x, 434, 25, 7), 2, "#24202c")

func draw_graphite_cabinet() -> void:
	shape([Vector2(125, 89), Vector2(150, 64), Vector2(681, 64), Vector2(711, 89)], "#3c3a4b")
	line(Vector2(154, 66), Vector2(677, 66), "#726e83", 2)
	rounded(Rect2(121, 80, 594, 409), 12, "#292833", "#676273")
	gradient(Rect2(131, 89, 574, 387), "#393844", "#24232e")
	line(Vector2(135, 88), Vector2(700, 88), "#888191")
	rounded(Rect2(136, 85, 513, 386), 16, "#15151d", "#5b5665")
	rounded(TV_GLASS.grow(7), 18, "#10121b", "#373643")

	# The graphite cabinet has horizontal speaker slats running up its right side.
	rounded(Rect2(655, 103, 48, 236), 3, "#17171f", "#5b5667")
	for y in range(108, 335, 6):
		line(Vector2(658, y), Vector2(700, y), "#60606f")
		line(Vector2(658, y + 1), Vector2(700, y + 1), "#24232c", 2)
	rounded(Rect2(655, 341, 48, 131), 4, "#2e2b39", "#4f485b")
	for y in [354, 376, 398, 434]:
		rounded(Rect2(664, y, 28, 9), 4, "#171720", "#645c6e")
		line(Vector2(669, y + 1), Vector2(686, y + 1), "#878093")
	draw_circle(Vector2(695, 452), 2.5, Color("#9fd0bc") if powered else Color("#57444e"))
	rounded(Rect2(147, 484, 547, 9), 3, "#211d29")

func draw_silver_cabinet() -> void:
	shape([Vector2(133, 88), Vector2(155, 62), Vector2(632, 62), Vector2(654, 88)], "#827f91")
	line(Vector2(158, 64), Vector2(629, 64), "#c0b8cc", 2)
	rounded(Rect2(126, 78, 535, 412), 19, "#888392", "#beb5c5")
	gradient(Rect2(136, 85, 515, 396), "#a5a0ac", "#706777")
	rounded(Rect2(139, 84, 508, 385), 17, "#514d5b", "#cfbec9")
	rounded(TV_GLASS.grow(7), 17, "#181a23", "#807682")

	# A full-width speaker bank sits below the tube with inset controls in the centre.
	rounded(Rect2(138, 467, 511, 19), 4, "#4b4355", "#a79aad")
	for y in range(470, 485, 3):
		line(Vector2(144, y), Vector2(644, y), "#262433")
		line(Vector2(144, y + 1), Vector2(644, y + 1), "#8d8191")
	rounded(Rect2(319, 468, 148, 17), 3, "#6f6378", "#9f8da3")
	for x in range(337, 450, 23):
		rounded(Rect2(x, 472, 15, 7), 3, "#8d8195", "#484250")
	draw_circle(Vector2(460, 481), 2.0, Color("#9fd0bc") if powered else Color("#634d62"))
	rounded(Rect2(154, 486, 478, 7), 3, "#3c3445")

func draw_television() -> void:
	draw_set_transform(TV_OFFSET)
	match television:
		Television.GRAPHITE:
			draw_graphite_cabinet()
		Television.SILVER:
			draw_silver_cabinet()
		_:
			# The front stays square to the viewer. The top recedes symmetrically.
			shape([Vector2(130, 85), Vector2(151, 62), Vector2(686, 62), Vector2(707, 85)], "#574e64")
			line(Vector2(155, 64), Vector2(682, 64), "#85748e", 2)
			for x in range(536, 653, 7):
				line(Vector2(x, 67), Vector2(x + 4, 73), "#514757")
			rounded(Rect2(125, 75, 587, 414), 22, "#3d374b", "#776683")
			gradient(Rect2(643, 106, 57, 351), "#54475d", "#30283a")
			line(Vector2(700, 110), Vector2(700, 454), "#67546d")
			rounded(Rect2(139, 84, 508, 387), 18, "#272432", "#6c5b6d")
			rounded(Rect2(146, 90, 494, 374), 12, "#141623", "#181925")
	rounded(TV_GLASS, 16, "#171d2d")
	if powered and rom_paths.is_empty():
		gradient(TV_GLASS, "#25344e", "#5b4466")
		var moon := Vector2(508, 209 + sin((Time.get_ticks_msec() - preview_started) / 480.0) * 8)
		glow(moon, Vector2(125, 115), Color("#f8ad8355"))
		draw_circle(moon, 47, Color("#ecae89"), true, -1, true)
		shape([Vector2(153, 380), Vector2(270, 298), Vector2(408, 382), Vector2(540, 261),
			Vector2(633, 359), Vector2(633, 456), Vector2(153, 456)], "#334659")
		shape([Vector2(153, 412), Vector2(337, 358), Vector2(454, 403), Vector2(633, 337),
			Vector2(633, 456), Vector2(153, 456)], "#24313f")
		words("CRT PREVIEW", 174, 126, 14)
		words(titles[inserted], 174, 425, 27, 425)
	else:
		shape([Vector2(154, 97), Vector2(375, 97), Vector2(207, 286), Vector2(154, 299)], "#70a0c116")
		line(Vector2(169, 109), Vector2(605, 109), "#b1aec331", 2)
	if scanlines_enabled:
		for y in range(98, 456, 4):
			line(Vector2(153, y), Vector2(633, y), "#090b1524")
	if television == Television.ORIGINAL:
		for x in range(660, 696, 5):
			rounded(Rect2(x, 137, 2, 163), 1, "#30293a")
		rounded(Rect2(660, 382, 34, 29), 6, "#3e3446", "#78677b")
		draw_circle(Vector2(677, 396), 7, Color("#827280"), true, -1, true)
		draw_circle(Vector2(674, 442), 3, Color("#88cab5") if powered else Color("#322b39"))
		box(153, 488, 530, 7, "#241b2a")
	draw_set_transform(Vector2.ZERO)

func draw_console() -> void:
	# The wide front and foreshortened top follow the angled PAL reference.
	glow(Vector2(414, 587), Vector2(171, 27), Color("#201927b0"))
	draw_set_transform_matrix(CONSOLE_TRANSFORM)
	draw_texture_rect(preload("res://art/pal-console-shell.png"), Rect2(272, 494, 289, 114), false)

	# The top hatch sits behind the three controls, with its lip in front of the cartridge.
	rounded(SLOT_ART.grow(4), 8, "#928c96")
	rounded(SLOT_ART, 6, "#a8a3ac" if seated else "#292634")
	if inserted < 0 or dragging == inserted:
		rounded(SLOT_ART.grow(-2), 5, "#666373", "#a5a0aa")
		for x in [SLOT_ART.position.x + 10, SLOT_ART.end.x - 10]:
			line(Vector2(x, SLOT_ART.position.y + 3.5), Vector2(x, SLOT_ART.end.y - 3.5), "#494653")
		draw_console_caption("P A L   V E R S I O N",
			Vector2(SLOT_ART.get_center().x - 49.5, SLOT_ART.position.y + 8.4), 99, 6, "#e4dce2")
		var arrow := Vector2(SLOT_ART.get_center().x, SLOT_ART.end.y - 4.0)
		shape([arrow + Vector2(-3.5, 0), arrow + Vector2(3.5, 0), arrow + Vector2(0, 2)], "#a7a0ad")
	if dragging >= 0 and SLOT.grow(20).has_point(pointer):
		rounded(SLOT_ART.grow(3), 7, "#eab58975", "#ffdfad")
	if inserted >= 0 and inserted != dragging:
		draw_set_transform(Vector2.ZERO)
		# At rest the slot hides the shell immediately below the label.
		cartridge(inserted, console_position(), console_cartridge_height())
		draw_set_transform_matrix(CONSOLE_TRANSFORM)
	draw_texture_rect(preload("res://art/pal-console-slot-lip.png"), Rect2(SLOT_ART.position.x - 7.0, SLOT_ART.end.y - 3.0, SLOT_ART.size.x + 14.0, 7.0), false)

	draw_console_button(Rect2(321, 548, 39, BUTTON_HEIGHT), "POWER", "#575465")
	var switch_y := 553 if powered else 558
	line(Vector2(328, switch_y), Vector2(353, switch_y), "#b0a5ae", 2)
	draw_console_button(EJECT_ART, "EJECT", "#bcb9bf" if EJECT.has_point(pointer) else "#a6a1aa")
	draw_console_button(RESET_ART, "RESET", "#817d90" if RESET.has_point(pointer) else "#626070")

	draw_console_wordmark()
	if powered:
		glow(Vector2(499, 579), Vector2(20, 8), Color("#ff4d5568"))
		rounded(Rect2(492, 577.8, 14, 3), 2, "#ff3d5c")
		line(Vector2(495, 578.3), Vector2(503, 578.3), "#ffacaf")
	draw_set_transform(Vector2.ZERO)

func draw_console_wordmark() -> void:
	var font := ThemeDB.fallback_font
	var title := "SUPER NINTENDO"
	var subtitle := "ENTERTAINMENT SYSTEM"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	draw_set_transform_matrix(CONSOLE_TRANSFORM * Transform2D(0.0, Vector2(1, 0.43), 0.0, Vector2(321, 578.7)))
	draw_string(font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#494654"))

	var glyph_widths := PackedFloat32Array()
	var subtitle_width := 0.0
	for index in range(subtitle.length()):
		var glyph_width := font.get_string_size(subtitle.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
		glyph_widths.append(glyph_width)
		subtitle_width += glyph_width
	var tracking := (title_width - subtitle_width) / (subtitle.length() - 1)
	draw_set_transform_matrix(CONSOLE_TRANSFORM * Transform2D(0.0, Vector2(1, 0.48), 0.0, Vector2(321, 581.9)))
	var x := 0.0
	for index in range(subtitle.length()):
		draw_string(font, Vector2(x, 0), subtitle.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("#68616c"))
		x += glyph_widths[index] + tracking
	draw_set_transform_matrix(CONSOLE_TRANSFORM)

func draw_controller_plugs() -> void:
	var first := seated_plug_position(PLAYER_ONE_SOCKET)
	var second := player_two_plug_position()
	if dragging_plug and plug_over_socket(pointer):
		rounded(PLAYER_TWO_SOCKET.grow(4), 5, "#a47b62", "#ffd7aa")
	draw_controller_plug(first, Vector2(379, 608))
	draw_controller_plug(second, LOOSE_CABLE_END)

func draw_controller_plug(at: Vector2, cable_end: Vector2) -> void:
	var start := at + Vector2(PLUG_SIZE.x / 2.0, PLUG_SIZE.y - 1.0)
	var points := PackedVector2Array()
	for index in range(17):
		points.append(start.bezier_interpolate(start + Vector2(0, 31),
			cable_end - Vector2(35, 9), cable_end, index / 16.0))
	draw_polyline(points, Color("#292633"), 5.0, true)
	draw_polyline(points, Color("#746e7a"), 2.0, true)
	rounded(Rect2(at + Vector2(2, 3), PLUG_SIZE), 4, "#29263388")
	rounded(Rect2(at, PLUG_SIZE), 4, "#676271", "#a49ba5")
	line(at + Vector2(7, 5), at + Vector2(34, 5), "#a198a6")
	rounded(Rect2(at + Vector2(8, 9), Vector2(25, 4)), 2, "#524e5e")
	rounded(Rect2(start - Vector2(4, 3), Vector2(8, 7)), 2, "#5d5967")

func draw_console_button(rect: Rect2, label: String, color: String) -> void:
	rounded(rect.grow(2), 5, "#dad3cd", "#9b909a")
	rounded(rect.grow(0.5), 4, "#4f4c5b")
	rounded(rect, 4, color, "#817985")
	var cap := rect.grow(-2.0)
	gradient(Rect2(cap.position, Vector2(cap.size.x, 5.0)),
		Color(color).lightened(0.24).to_html(), color)
	line(Vector2(rect.position.x + 4, rect.end.y - 1.8),
		Vector2(rect.end.x - 4, rect.end.y - 1.8), Color(color).darkened(0.22).to_html())
	var center := rect.get_center()
	draw_console_caption(label, Vector2(rect.position.x, center.y + 6.5), rect.size.x, 8, "#f9f1eb")

func draw_console_caption(label: String, baseline: Vector2, width: float, size: int, ink: String) -> void:
	var caption_transform := Transform2D(0.0, Vector2(1, 0.68), 0.0, baseline)
	draw_set_transform_matrix(CONSOLE_TRANSFORM * caption_transform)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(ink))
	draw_set_transform_matrix(CONSOLE_TRANSFORM)

func _draw() -> void:
	draw_bedroom()
	draw_ceiling_light()
	draw_shoebox()
	draw_tv_stand()
	draw_television()
	draw_console()
	draw_controller_plugs()
	for index in visible_cartridges():
		if index != inserted and index != dragging:
			cartridge(index, displayed_desk_position(index))
	draw_shoebox_front()
	if dragging >= 0:
		cartridge(dragging, pointer - CART_SIZE / 2.0)
	gradient(Rect2(0, 607, 1152, 41), "#271d2cca", "#1d1726")
	words(message, 32, 633, 16, 920)
	words("F11  Fullscreen", 994, 633, 15)
