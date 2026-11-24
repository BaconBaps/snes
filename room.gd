extends Node2D

const LocalRuntime := preload("res://local_runtime.gd")

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
const SECOND_CABLE_EXIT_X := 729.0
const DESK := Rect2(770, 252, 354, 308)
const CEILING_LIGHT := Rect2(970, 60, 126, 62)

const POSTER_RECTS := [Rect2(736, 58, 91, 112), Rect2(855, 29, 101, 62),
	Rect2(866, 110, 96, 86), Rect2(1046, 132, 67, 73)]
const POSTER_TILTS := [-9.0, 5.0, -4.0, 8.0]
const POSTER_ART := [
	preload("res://art/poster-starfighter.png"),
	preload("res://art/poster-racer.png"),
	preload("res://art/poster-quest.png"),
	preload("res://art/poster-platformer.png"),
]
const POSTER_DIRECTORY := "user://posters"
const TV_OFFSET := Vector2(0, -55)
const TV_GLASS := Rect2(153, 96, 480, 360)
const SCREEN := Rect2(TV_GLASS.position + TV_OFFSET, TV_GLASS.size)
const MD_SHELL := preload("res://art/mega-drive-shell.svg")
const MD_SLOT := Rect2(373.2, 480, 147.6, 14)
const MD_RESET := Rect2(302, 550, 34, 12)
const MD_POWER_LED := Vector2(447, 557)
const MD_CART_WIDTH_SCALE := 0.9
const MD_CART_SIZE := Vector2(160 * MD_CART_WIDTH_SCALE, 73)
const MD_LABEL := Rect2(24, 11, 112, 55)
const MD_SEATED_HEIGHT := 39.0
const MD_PORT_ONE := Rect2(422, 592, 33, 9)
const MD_PORT_TWO := Rect2(472, 592, 33, 9)
const MD_EXTENSIONS := ["md", "gen", "bin", "smd"]
const SNES_EXTENSIONS := ["sfc", "smc"]
const SNES_DEMOS := ["Star Hopper", "Midnight Rally", "Moon Orchard", "Wave Rider", "Snow Circuit", "Tiny Atlas"]
const MD_DEMOS := ["Neon Circuit", "Ocean Shift", "Steel Comet", "Night Speedway", "Cosmic Drift", "Skyline Runner"]

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

var poster_picker := FileDialog.new()
var poster_images: Array[Texture2D] = []
var editing_poster := -1
var manual := preload("res://manuals/manual_viewer.gd").new()
var manual_button := Button.new()
var manual_fade: Tween
var manual_opacity := 0.0:
	set(value):
		manual_opacity = value
		queue_redraw()
signal console_changed

var tv_input_buttons: Array[Button] = []
var library_navigation := HBoxContainer.new()
var console_transition: Tween
var left_slide := Vector2.ZERO
var right_slide := Vector2.ZERO
var prop_draw_offset := Vector2.ZERO
var notebook_button := Button.new()
var notes_button := Button.new()
var game_notes := preload("res://game_notes.gd").new()
var notebook := preload("res://cartridge_notebook.gd").new()
var shoebox_indices: Array[int] = []
var notebook_selection := -1
@export var megadrive_preview_scene := false
var megadrive := false
var snes_rom_folder := ""
var snes_art_folder := ""
var md_rom_folder := ""
var md_art_folder := ""
var manual_folders := PackedStringArray(["", ""])
var setup_complete := false
var first_run := preload("res://setup/first_run.gd").new()
var cart_grab_offset := Vector2.ZERO
var pull_origin := Vector2.ZERO
var titles := PackedStringArray(SNES_DEMOS)
var rom_paths := PackedStringArray()
const EmulatorBridge := preload("res://emulator/bridge.gd")
var console_emulators: Array[EmulatorBridge] = [EmulatorBridge.new(), EmulatorBridge.new()]
var cartridge_sessions: Array[Dictionary] = [{}, {}]
var emulator: EmulatorBridge = console_emulators[0]
var core_picker := OptionButton.new()
enum PortOne { AUTO, GAMEPAD, MOUSE }
var port_one_picker := OptionButton.new()
var port_one_overrides := {}
var mouse_captured := false
var mouse_buttons := 0
const MOUSE_CAPTURE_HINT := "Click the CRT to use the SNES Mouse."
const MOUSE_RELEASE_HINT := "SNES Mouse active · Esc to return to the room."
var rom_folder := ""
var art_folder := ""
var art_paths: Dictionary[String, String] = {}
var sidecar_paths: Dictionary[String, String] = {}
var label_textures: Dictionary[String, Texture2D] = {}
var title_tags := RegEx.create_from_string(r"\([^()\[\]]*\)|\[[^()\[\]]*\]")
var end_label_palettes: Dictionary[String, PackedColorArray] = {}
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
var crt_glass := ColorRect.new()
const INPUT_STATIC_SECONDS := 0.20
var crt_static := ColorRect.new()
var input_static_timer := Timer.new()
var input_hiss := AudioStreamPlayer.new()
var room_dimmer := ColorRect.new()
var room_overlay := Node2D.new()
var dragged_prop_layer := Node2D.new()
var prop_canvas: CanvasItem = self
var ceiling_light_on := true
var screen_spill := ColorRect.new()
var screen_light := Color.BLACK
var last_insert := -1
var last_eject := -1
var insert_sound := AudioStreamPlayer.new()
var eject_sound := AudioStreamPlayer.new()

func _ready() -> void:
	for player in [insert_sound, eject_sound]:
		player.volume_db = -7.0
		add_child(player)
	restore_preferences()
	room_dimmer.color = Color("#0a0816ca")
	room_dimmer.size = Vector2(1152, 648)
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
	crt.material = crt_material
	crt.position = SCREEN.position
	crt.size = SCREEN.size
	crt.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.hide()
	add_child(crt)
	setup_crt_static()
	var glass_material := ShaderMaterial.new()
	glass_material.shader = preload("res://emulator/crt_glass.gdshader")
	glass_material.set_shader_parameter("glass_size", SCREEN.size)
	crt_glass.material = glass_material
	crt_glass.position = SCREEN.position
	crt_glass.size = SCREEN.size
	crt_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crt_glass)
	dragged_prop_layer.draw.connect(draw_dragged_prop)
	add_child(dragged_prop_layer)
	room_overlay.draw.connect(draw_room_overlay)
	add_child(room_overlay)
	update_glass_sheen()
	emulator = console_emulators[int(megadrive)]
	for index in range(console_emulators.size()):
		var bridge = console_emulators[index]
		add_child(bridge)
		bridge.frame_changed.connect(func():
			if bridge == emulator:
				update_crt())
		bridge.failed.connect(func(error: String):
			if bridge == emulator:
				show_emulator_error(error)
			else:
				cartridge_sessions[index]["powered"] = false
				cartridge_sessions[index]["message"] = error)

	setup_tv_inputs()
	setup_settings()
	add_child(notebook)
	notebook.setup(self)
	setup_cartridge_navigation()
	setup_posters()
	notebook_button.name = "NotebookButton"
	notebook_button.flat = true
	notebook_button.focus_mode = Control.FOCUS_NONE
	notebook_button.tooltip_text = "Open Cart List"
	notebook_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	notebook_button.position = notebook_position()
	notebook_button.rotation = deg_to_rad(-9)
	notebook_button.size = Vector2(99, 48)
	notebook_button.mouse_entered.connect(queue_redraw)
	notebook_button.mouse_exited.connect(queue_redraw)
	notebook_button.pressed.connect(func():
		game_notes.close_for_room()
		notebook.open_notebook())
	add_child(notebook_button)
	setup_manual()
	setup_game_notes()
	for bridge in console_emulators:
		game_notes.editor.focus_entered.connect(func(): bridge.keyboard_enabled = false)
		game_notes.editor.focus_exited.connect(func(): bridge.keyboard_enabled = true)
	get_viewport().size_changed.connect(queue_redraw)
	get_window().mouse_exited.connect(func(): hovered = -1)
	get_window().focus_exited.connect(release_game_mouse)
	# Godot's built-in UI actions otherwise also react to SNES gameplay buttons.
	for action in InputMap.get_actions():
		if String(action).begins_with("ui_"):
			for binding in InputMap.action_get_events(action):
				if binding is InputEventJoypadButton or binding is InputEventJoypadMotion:
					InputMap.action_erase_event(action, binding)
	var cursor := Image.new()
	cursor.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="26" height="26" viewBox="0 0 26 26"><circle cx="13" cy="13" r="9" fill="#2b2037" fill-opacity=".6" stroke="#ffe6bf" stroke-width="2"/><circle cx="13" cy="13" r="2" fill="#ffe6bf"/></svg>')
	pointer_art = ImageTexture.create_from_image(cursor)

	load_console_library()
	first_run.setup(self)
	add_child(first_run)
	if not setup_complete:
		first_run.open.call_deferred()

func _exit_tree() -> void:
	game_notes.flush()
	release_game_mouse()
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
	var existing := config.load(SETTINGS_PATH) == OK
	setup_complete = bool(config.get_value("setup", "complete", existing))
	for index in range(2):
		manual_folders[index] = str(config.get_value("manuals", str(index), ""))
	megadrive = megadrive_preview_scene or bool(config.get_value("room", "megadrive", false))
	snes_rom_folder = str(config.get_value("library", "rom_folder", ""))
	snes_art_folder = str(config.get_value("library", "art_folder", ""))
	md_rom_folder = str(config.get_value("megadrive", "rom_folder", ""))
	md_art_folder = str(config.get_value("megadrive", "art_folder", ""))
	stacked = bool(config.get_value("library", "stacked", true))
	ceiling_light_on = bool(config.get_value("room", "ceiling_light", true))
	preferred_core = clampi(int(config.get_value("emulation", "core", 0)), 0, emulator.CORE_NAMES.size() - 1)
	var overrides: Variant = config.get_value("emulation", "port_one_overrides", {})
	if overrides is Dictionary:
		port_one_overrides = overrides

func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("setup", "complete", setup_complete)
	for index in range(2):
		config.set_value("manuals", str(index), manual_folders[index])
	config.set_value("library", "rom_folder", library_folder(false))
	config.set_value("library", "art_folder", library_folder(false, true))
	config.set_value("megadrive", "rom_folder", library_folder(true))
	config.set_value("megadrive", "art_folder", library_folder(true, true))
	config.set_value("room", "megadrive", megadrive)
	config.set_value("library", "stacked", stacked)
	config.set_value("room", "ceiling_light", ceiling_light_on)
	config.set_value("emulation", "core", preferred_core)
	config.set_value("emulation", "port_one_overrides", port_one_overrides)
	if config.save(SETTINGS_PATH) != OK:
		push_warning("Could not save Bedroom Gaming Emulator settings.")

func library_folder(for_megadrive: bool, artwork := false) -> String:
	if for_megadrive == megadrive:
		return art_folder if artwork else rom_folder
	if for_megadrive:
		return md_art_folder if artwork else md_rom_folder
	return snes_art_folder if artwork else snes_rom_folder

func load_console_library(keep_session := false) -> void:
	manual.extra_folder = manual_folders[int(megadrive)]
	rom_folder = md_rom_folder if megadrive else snes_rom_folder
	art_folder = md_art_folder if megadrive else snes_art_folder
	rom_paths.clear()
	titles = PackedStringArray(MD_DEMOS if megadrive else SNES_DEMOS)
	refresh_label_art()
	if not rom_folder.is_empty():
		load_folder(rom_folder, keep_session)
	else:
		refresh_shoebox()
		message = "Drag a cartridge into the console slot."

func switch_console(index: int) -> void:
	if megadrive == (index == 1):
		return
	if megadrive:
		md_rom_folder = rom_folder
		md_art_folder = art_folder
	else:
		snes_rom_folder = rom_folder
		snes_art_folder = art_folder
	release_game_mouse()
	emulator.set_paused(true)
	cartridge_sessions[int(megadrive)] = {
		"rom": rom_paths[inserted] if inserted >= 0 and inserted < rom_paths.size() else "",
		"inserted": inserted, "seated": seated, "powered": powered, "lift": lift,
		"page": page, "message": message, "preview_elapsed": Time.get_ticks_msec() - preview_started,
	}
	game_notes.close_for_room()
	manual.set_rom("")
	inserted = -1
	dragging = -1
	dragging_plug = false
	seated = false
	powered = false
	reset_lift()
	megadrive = index == 1
	emulator = console_emulators[index]
	load_console_library(true)
	var session := cartridge_sessions[index]
	if not session.is_empty():
		var rom: String = session.rom
		inserted = rom_paths.find(rom) if not rom.is_empty() else session.inserted
		if inserted >= 0 and inserted < titles.size():
			seated = session.seated
			powered = session.powered
			lift = session.lift
			message = session.message
			preview_started = Time.get_ticks_msec() - int(session.preview_elapsed)
			if seated and not rom.is_empty():
				manual.set_rom(rom)
		else:
			inserted = -1
			emulator.stop()
		page = mini(int(session.page), page_count() - 1)
		update_page_controls()
	screen_light = Color.BLACK
	update_crt()
	if not console_transition:
		emulator.set_paused(false)
	save_preferences()
	console_changed.emit()

func request_console_switch(index: int) -> void:
	if console_transition or megadrive == (index == 1):
		return
	dragging = -1
	dragging_plug = false
	clear_stack_hover()
	manual.hide()
	game_notes.close_for_room()
	console_transition = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	console_transition.tween_method(update_console_slide, 0.0, 1.0, 0.36)
	console_transition.tween_callback(func():
		input_static_timer.start()
		input_hiss.play()
		update_crt_static()
		switch_console(index))
	console_transition.tween_method(update_console_slide, 1.0, 0.0, 0.40)
	console_transition.finished.connect(func():
		console_transition = null
		emulator.set_paused(false))

func update_console_slide(progress: float) -> void:
	left_slide = Vector2(-760.0 * progress, 0)
	right_slide = Vector2(maxf(420.0, get_viewport_rect().end.x - 738.0) * progress, 0)
	notebook_button.position = notebook_position() + right_slide
	manual_button.position = manual_position() + right_slide
	notes_button.position = notes_position() + right_slide
	library_navigation.position = Vector2(783, 563) + right_slide
	queue_redraw()

func finish_setup(folders: Array[PackedStringArray], apply_folders: bool) -> void:
	setup_complete = true
	if apply_folders:
		var active := int(megadrive)
		var old_rom_folder := rom_folder
		var old_manual_folder := manual.extra_folder
		var inactive := 1 - active
		if folders[0][inactive] != library_folder(inactive == 1):
			console_emulators[inactive].stop()
			cartridge_sessions[inactive].clear()
		snes_rom_folder = folders[0][0]
		md_rom_folder = folders[0][1]
		snes_art_folder = folders[1][0]
		md_art_folder = folders[1][1]
		manual_folders = folders[2]
		if old_rom_folder != folders[0][active]:
			emulator.stop()
			inserted = -1
			seated = false
			powered = false
			game_notes.close_for_room()
			manual.set_rom("")
			load_console_library()
		else:
			art_folder = folders[1][active]
			refresh_label_art()
			manual.extra_folder = manual_folders[active]
			if old_manual_folder != manual.extra_folder and seated and inserted >= 0 and inserted < rom_paths.size():
				manual.set_rom(rom_paths[inserted])
		queue_redraw()
	save_preferences()

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
	var rule := StyleBoxLine.new()
	rule.color = Color("#796078")
	rule.thickness = 1
	divider.add_theme_stylebox_override("separator", rule)
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
	var console_picker := OptionButton.new()
	console_picker.name = "ConsolePicker"
	console_picker.add_item("Super Nintendo")
	console_picker.add_item("Mega Drive")
	console_picker.select(int(megadrive))
	menu.add_child(console_picker)

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
		refresh_port_one_picker()
		emulation_page.show()
		settings.popup_centered(Vector2i(344, 520)))
	menu.add_child(emulation_button)

	var back := Button.new()
	back.text = "‹  Back to settings"
	back.alignment = HORIZONTAL_ALIGNMENT_LEFT
	back.pressed.connect(func():
		emulation_page.hide()
		menu.show()
		settings.popup_centered(Vector2i(344, 406)))
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
	var scraper := preload("res://screenscraper/scraper_dialog.gd").new()
	add_child(scraper)
	scraper.setup(self)
	var scrape_button := Button.new()
	scrape_button.text = "Download art and manuals  ›"
	scrape_button.pressed.connect(func():
		settings.hide()
		scraper.open())
	menu.add_child(scrape_button)
	scrape_button.disabled = megadrive
	scrape_button.tooltip_text = "ScreenScraper downloads are available for SNES."
	core_picker.visible = not megadrive
	core_label.text = emulator.MEGA_DRIVE_CORE_NAME if megadrive else "SNES core"
	console_picker.item_selected.connect(func(index: int):
		console_picker.select(int(megadrive))
		settings.hide()
		request_console_switch(index))
	console_changed.connect(func():
		console_picker.select(int(megadrive))
		scrape_button.disabled = megadrive
		core_picker.visible = not megadrive
		core_label.text = emulator.MEGA_DRIVE_CORE_NAME if megadrive else "SNES core")
	menu.move_child(scrape_button, art_button.get_index() + 1)
	for button in [folder_button, art_button, scrape_button, emulation_button]:
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT

	var setup_button := Button.new()
	setup_button.text = "Setup wizard  ›"
	setup_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	setup_button.pressed.connect(func():
		settings.hide()
		first_run.open())
	menu.add_child(setup_button)
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
		settings.popup_centered(Vector2i(344, 406)))
	add_child(gear)

func add_emulation_controls(page_controls: VBoxContainer) -> void:
	var port_label := Label.new()
	port_label.text = "Controller port 1 · Current cartridge"
	page_controls.add_child(port_label)
	port_one_picker.name = "PortOneController"
	for option in ["Auto", "Gamepad", "SNES Mouse"]:
		port_one_picker.add_item(option)
	port_one_picker.item_selected.connect(set_port_one_override)
	page_controls.add_child(port_one_picker)
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
	for bridge in console_emulators:
		bridge.state_result.connect(func(result: String):
			if bridge == emulator:
				state_status.text = result)
	page_controls.add_child(state_status)

	var log_button := Button.new()
	log_button.text = "Open last emulator log"
	log_button.pressed.connect(func():
		var path: String = emulator.MEGA_DRIVE_LOG if megadrive else emulator.LAST_LOG
		if FileAccess.file_exists(path):
			if OS.shell_open(ProjectSettings.globalize_path(path)) != OK:
				state_status.text = "Could not open the emulator log."
		else:
			state_status.text = "No emulator log yet. Insert a ROM first.")
	page_controls.add_child(log_button)

func port_one_rom() -> String:
	return rom_paths[inserted] if not megadrive and seated and inserted >= 0 and inserted < rom_paths.size() else ""

func use_snes_mouse(rom: String) -> bool:
	var choice := int(port_one_overrides.get(rom.sha256_text(), PortOne.AUTO))
	if choice != PortOne.AUTO:
		return choice == PortOne.MOUSE
	return is_mario_paint(rom)

func is_mario_paint(rom: String) -> bool:
	var stem := rom.get_file().get_basename().to_lower().replace("_", " ").replace("-", " ").strip_edges()
	return stem == "mario paint" or stem.begins_with("mario paint ")

func refresh_port_one_picker() -> void:
	var rom := port_one_rom()
	port_one_picker.disabled = rom.is_empty()
	port_one_picker.select(clampi(int(port_one_overrides.get(rom.sha256_text(), PortOne.AUTO)), PortOne.AUTO, PortOne.MOUSE))
	port_one_picker.tooltip_text = "Insert an SNES ROM to choose its controller." if rom.is_empty() else "Auto selects %s for this cartridge." % ("SNES Mouse" if is_mario_paint(rom) else "Gamepad")

func set_port_one_override(index: int) -> void:
	var rom := port_one_rom()
	if rom.is_empty():
		return
	var key := rom.sha256_text()
	if index == PortOne.AUTO:
		port_one_overrides.erase(key)
	else:
		port_one_overrides[key] = index
	save_preferences()
	if emulator.running:
		release_game_mouse()
		var enabled := use_snes_mouse(rom)
		emulator.set_mouse_device(enabled)
		message = MOUSE_CAPTURE_HINT if enabled else ""
		queue_redraw()

func capture_game_mouse() -> void:
	hide_virtual_pointer()
	hovered = -1
	mouse_captured = true
	mouse_buttons = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	message = MOUSE_RELEASE_HINT
	queue_redraw()

func release_game_mouse() -> void:
	if not mouse_captured:
		return
	mouse_captured = false
	mouse_buttons = 0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	emulator.clear_mouse()
	if message == MOUSE_RELEASE_HINT:
		message = MOUSE_CAPTURE_HINT if emulator.mouse_enabled else ""
	queue_redraw()

func setup_crt_static() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://emulator/crt_static.gdshader")
	material.set_shader_parameter("glass_size", SCREEN.size)
	crt_static.material = material
	crt_static.position = SCREEN.position
	crt_static.size = SCREEN.size
	crt_static.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crt_static)

	input_static_timer.one_shot = true
	input_static_timer.wait_time = INPUT_STATIC_SECONDS
	input_static_timer.timeout.connect(update_crt_static)
	add_child(input_static_timer)
	input_hiss.stream = create_input_hiss()
	input_hiss.volume_db = -12.0
	add_child(input_hiss)
	update_crt_static()

func create_input_hiss() -> AudioStreamWAV:
	const SAMPLE_RATE := 22050
	var count := int(SAMPLE_RATE * INPUT_STATIC_SECONDS)
	var data := PackedByteArray()
	data.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 117
	var filtered := 0.0
	for index in range(count):
		var progress := float(index) / count
		filtered = lerpf(filtered, random.randf_range(-1.0, 1.0), 0.64)
		var envelope := smoothstep(0.0, 0.02, progress) * (1.0 - smoothstep(0.22, 1.0, progress))
		data.encode_s16(index * 2, roundi(filtered * envelope * 16000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream

func update_crt_static() -> void:
	var switching := not input_static_timer.is_stopped()
	crt_static.visible = switching or (not crt.visible and not (powered and rom_paths.is_empty()))
	crt_static.material.set_shader_parameter("switching_input", switching)

func update_crt() -> void:
	if not emulator.mouse_enabled:
		release_game_mouse()
	if crt.texture != emulator.picture:
		if crt.texture == null and emulator.picture and inserted >= 0 and inserted < rom_paths.size():
			notebook.record_played(rom_paths[inserted])
		crt.texture = emulator.picture
		crt.visible = crt.texture != null
		update_glass_sheen()
	if crt.material.get_shader_parameter("rgb565") != emulator.rgb565:
		crt.material.set_shader_parameter("rgb565", emulator.rgb565)

func update_glass_sheen() -> void:
	var dim_tint := Color.WHITE.lerp(room_dimmer.color, room_dimmer.color.a)
	dragged_prop_layer.self_modulate = Color.WHITE if ceiling_light_on else Color(dim_tint, 1.0)
	crt_static.material.set_shader_parameter("brightness", 1.0 if ceiling_light_on else 0.54)
	var strength := 0.43 if crt.visible else 1.0
	if not ceiling_light_on and not crt.visible:
		strength *= 0.22
	crt_glass.material.set_shader_parameter("sheen_strength", strength)

func load_folder(path: String, keep_session := false) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		message = "That folder could not be opened."
		queue_redraw()
		return
	if path != rom_folder:
		rom_folder = path
		save_preferences()
	if not keep_session:
		emulator.stop()
	game_notes.close_for_room()
	manual.set_rom("")
	titles.clear()
	rom_paths.clear()
	var files := Array(folder.get_files())
	files.sort_custom(func(left: String, right: String): return left.naturalnocasecmp_to(right) < 0)
	for file in files:
		if file.get_extension().to_lower() in (MD_EXTENSIONS if megadrive else SNES_EXTENSIONS):
			titles.append(file.get_basename())
			rom_paths.append(path.path_join(file))
	refresh_label_art()
	inserted = -1
	dragging = -1
	seated = false
	powered = false
	refresh_shoebox()
	reset_lift()
	message = "Drag a cartridge into the console slot."
	if titles.is_empty():
		message = "No Mega Drive ROMs in this folder." if megadrive else "No .sfc or .smc files in this folder."
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
	end_label_palettes.clear()

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
		for path in [art_paths.get(title, ""), sidecar_paths.get(title, ""), LocalRuntime.scraped_label(rom_paths[index])]:
			if path.is_empty():
				continue
			if image.load(path) == OK and not image.is_empty():
				if megadrive:
					end_label_palettes[title] = sample_end_label_palette(image)
				prepare_label_image(image)
				texture = ImageTexture.create_from_image(image)
				break
		label_textures[title] = texture
	return label_textures[title]

func sample_end_label_palette(image: Image) -> PackedColorArray:
	var colors: Dictionary[Color, int] = {}
	var dimensions := Vector2(image.get_size())
	for y in range(12):
		for x in range(24):
			var point := Vector2i((Vector2(x, y) + Vector2(0.5, 0.5)) * dimensions / Vector2(24, 12))
			var pixel := image.get_pixelv(point)
			if pixel.a < 0.75:
				continue
			var color := Color(snappedf(pixel.r, 0.125), snappedf(pixel.g, 0.125), snappedf(pixel.b, 0.125))
			colors[color] = colors.get(color, 0) + 1
	var ranked := colors.keys()
	if ranked.is_empty():
		return PackedColorArray()
	ranked.sort_custom(func(a: Color, b: Color): return colors[a] > colors[b])
	var background: Color = ranked[0]
	var luminance := background.srgb_to_linear().get_luminance()
	for candidate: Color in ranked:
		var foreground := candidate.srgb_to_linear().get_luminance()
		if (maxf(luminance, foreground) + 0.05) / (minf(luminance, foreground) + 0.05) >= 4.5:
			return PackedColorArray([background, candidate])
	var ink := Color.BLACK if luminance >= 0.179 else Color.WHITE
	return PackedColorArray([background, ink])

func prepare_label_image(image: Image) -> void:
	# Cache the stretched, antialiased label at twice its on-screen size.
	var size := Vector2i((MD_LABEL.size if megadrive else LABEL_SIZE) * 2.0)
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

func refresh_shoebox(keep_page := false) -> void:
	shoebox_indices.clear()
	for path in notebook.current_paths():
		var index := rom_paths.find(path)
		if index >= 0:
			shoebox_indices.append(index)
	page = mini(page, page_count() - 1) if keep_page else 0
	notebook_selection = -1
	clear_stack_hover()
	refresh_alphabet()
	update_page_controls()
	queue_redraw()

func shoebox_position(index: int) -> int:
	return index if notebook.active_box.is_empty() else shoebox_indices.find(index)

func shoebox_count() -> int:
	return titles.size() if notebook.active_box.is_empty() else shoebox_indices.size()

func visible_cartridges() -> Array:
	var size := page_size()
	var start := page * size
	var finish := mini(shoebox_count(), start + size)
	return range(start, finish) if notebook.active_box.is_empty() else shoebox_indices.slice(start, finish)

func change_layout(index: int) -> void:
	var first_visible := page * page_size()
	stacked = index == 1
	notebook_button.position = notebook_position()
	manual_button.position = manual_position()
	notes_button.position = notes_position()
	save_preferences()
	page = floori(first_visible / float(page_size()))
	update_page_controls()
	clear_stack_hover()
	queue_redraw()

func desk_position(index: int) -> Vector2:
	var cell := shoebox_position(index) % page_size()
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
	notebook_selection = -1
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
		if index != inserted and index != dragging and Rect2(displayed_desk_position(index), cartridge_size()).has_point(point):
			return index
	# Keep the lift stable if the pointer was on the bottom edge when it moved.
	if hovered >= 0 and Rect2(desk_position(hovered), cartridge_size()).has_point(point):
		return hovered
	return -1

func cartridge_size() -> Vector2:
	return MD_CART_SIZE if megadrive else CART_SIZE

func console_position() -> Vector2:
	var slot := MD_SLOT if megadrive else SLOT
	return Vector2(slot.get_center().x - cartridge_size().x / 2.0, slot.end.y - console_cartridge_height())

func console_cartridge_height() -> float:
	var seated_height := MD_SEATED_HEIGHT if megadrive else SEATED_CART_HEIGHT
	return minf(cartridge_size().y, seated_height + lift)

func setup_cartridge_navigation() -> void:
	var controls := library_navigation
	controls.position = Vector2(783, 563)
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
	return maxi(1, ceili(shoebox_count() / float(page_size())))

func turn_page(direction: int) -> void:
	var next_page := clampi(page + direction, 0, page_count() - 1)
	if next_page == page:
		return
	page = next_page
	clear_stack_hover()
	update_page_controls()
	queue_redraw()

func jump_to_title(index: int) -> void:
	var position := shoebox_position(index)
	if position < 0:
		return
	page = floori(position / float(page_size()))
	clear_stack_hover()
	update_page_controls()
	queue_redraw()

func update_page_controls() -> void:
	var count := "%d / %d" % [page + 1, page_count()]
	page_label.text = count if notebook.active_box.is_empty() else "%s  ·  %s" % [notebook.active_box.left(16), count]
	page_label.tooltip_text = notebook.ALL_GAMES if notebook.active_box.is_empty() else notebook.active_box
	previous_page_button.disabled = page == 0
	next_page_button.disabled = page >= page_count() - 1

func refresh_alphabet() -> void:
	var menu := alphabet_button.get_popup()
	menu.clear()
	var seen := {}
	var indices := range(titles.size()) if notebook.active_box.is_empty() else shoebox_indices.duplicate()
	indices.sort_custom(func(left: int, right: int): return titles[left].naturalnocasecmp_to(titles[right]) < 0)
	for index in indices:
		var letter := titles[index].left(1).to_upper()
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZ".contains(letter) or letter.is_empty():
			letter = "#"
		if not seen.has(letter):
			menu.add_item(letter, index)
			seen[letter] = true
	alphabet_button.disabled = menu.item_count == 0

func _input(event: InputEvent) -> void:
	if console_transition and event is InputEventMouse:
		get_viewport().set_input_as_handled()
		return
	if mouse_captured:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			release_game_mouse()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouse:
			if event.device != POINTER_DEVICE:
				if event is InputEventMouseMotion:
					emulator.mouse_motion += event.screen_relative
				elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
					var bit := 1 if event.button_index == MOUSE_BUTTON_LEFT else 2
					var next_buttons := mouse_buttons | bit if event.pressed else mouse_buttons & ~bit
					if next_buttons != mouse_buttons:
						mouse_buttons = next_buttons
						emulator.set_mouse_buttons(mouse_buttons)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseMotion:
		if virtual_pointer_active and event.device != POINTER_DEVICE and event.position.distance_to(virtual_position) > 3.0:
			hide_virtual_pointer()
		if dragging_plug or dragging >= 0:
			pointer = event.position
			pull_cartridge_if_moved(pointer)
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
	elif event is InputEventMouseMotion:
		pointer = event.position
		var target := desk_cartridge_at(pointer) if stacked and dragging < 0 and not dragging_plug else -1
		if target >= 0:
			notebook_selection = -1
		hovered = notebook_selection if notebook_selection >= 0 else target
	elif event is InputEventMouseButton:
		pointer = event.position
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.device != POINTER_DEVICE and emulator.mouse_enabled and crt.visible and SCREEN.has_point(pointer) and dragging < 0 and not dragging_plug:
				capture_game_mouse()
			else:
				press_at(pointer)
		elif event.pressed and DESK.has_point(pointer) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			turn_page(1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
	queue_redraw()

func hide_virtual_pointer() -> void:
	if virtual_pointer_active:
		virtual_pointer_active = false
		Input.set_custom_mouse_cursor(null)

func update_gamepad_pointer(delta: float) -> void:
	if mouse_captured:
		return
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
		update_glass_sheen()
		save_preferences()
		queue_redraw()
		return
	if dragging < 0 and Rect2(plug, PLUG_SIZE).has_point(point):
		dragging_plug = true
		plug_grab_offset = point - plug
		pointer = point
		hovered = -1
		queue_redraw()
	elif (MD_RESET if megadrive else RESET).has_point(point) and seated:
		if emulator.running:
			emulator.reset()
		elif not powered:
			start_cartridge()
		else:
			preview_started = Time.get_ticks_msec()
			message = "CRT preview reset."
	elif megadrive and seated and inserted >= 0 and Rect2(console_position(), Vector2(MD_CART_SIZE.x, MD_SEATED_HEIGHT)).has_point(point):
		dragging = inserted
		pull_origin = point
		cart_grab_offset = point - console_position()
	elif not megadrive and EJECT.has_point(point) and seated:
		last_eject = play_cartridge_sound(eject_sound, EJECT_SOUNDS, last_eject)
		emulator.stop()
		game_notes.close_for_room()
		manual.set_rom("")
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
			cart_grab_offset = point - displayed_desk_position(dragging)
			notebook_selection = -1
			hovered = -1

func seated_plug_position(socket: Rect2) -> Vector2:
	return Vector2(socket.get_center().x - PLUG_SIZE.x / 2.0, socket.position.y - 1.0)

func player_two_plug_position() -> Vector2:
	if dragging_plug:
		return pointer - plug_grab_offset
	return seated_plug_position(player_two_socket()) if emulator.player_two_connected else LOOSE_PLUG

func player_two_socket() -> Rect2:
	return MD_PORT_TWO if megadrive else PLAYER_TWO_SOCKET

func plug_over_socket(point: Vector2) -> bool:
	var plug_center := point - plug_grab_offset + PLUG_SIZE / 2.0
	return player_two_socket().grow(14).has_point(plug_center)

func drop_plug(point: Vector2) -> void:
	var connected := plug_over_socket(point)
	if connected != emulator.player_two_connected:
		emulator.set_player_two(connected)
		message = "Player 2 controller connected." if connected else "Player 2 controller disconnected."
	dragging_plug = false
	queue_redraw()

func dragged_cartridge_position(point: Vector2) -> Vector2:
	return point - (cart_grab_offset if megadrive else CART_SIZE / 2.0)

func cartridge_edge_meets_slot(point: Vector2) -> bool:
	var slot := MD_SLOT if megadrive else SLOT
	var cart := Rect2(dragged_cartridge_position(point), cartridge_size())
	var overlap := minf(cart.end.x, slot.end.x) - maxf(cart.position.x, slot.position.x)
	var edge_near_slot := cart.end.y >= slot.position.y - 10.0 and cart.end.y <= slot.end.y + 10.0
	return edge_near_slot and overlap >= cart.size.x * 0.6

func pull_cartridge_if_moved(point: Vector2) -> void:
	if not megadrive or not seated or dragging != inserted or dragging < 0:
		return
	if point.distance_squared_to(pull_origin) < 144.0:
		return
	emulator.stop()
	inserted = -1
	seated = false
	powered = false
	game_notes.close_for_room()
	manual.set_rom("")
	message = "Cartridge removed. Drop it back in the slot to play again."

func drop_at(point: Vector2) -> void:
	if dragging < 0:
		return
	pull_cartridge_if_moved(point)
	if megadrive and seated and dragging == inserted:
		dragging = -1
		return
	if cartridge_edge_meets_slot(point):
		inserted = dragging
		seated = true
		reset_lift()
		last_insert = play_cartridge_sound(insert_sound, INSERT_SOUNDS, last_insert)
		if inserted < rom_paths.size():
			manual.set_rom(rom_paths[inserted])
		start_cartridge()
	elif dragging == inserted and DESK.has_point(point):
		inserted = -1
		reset_lift()
		message = "Drag a cartridge into the console slot."
	elif not notebook.active_box.is_empty() and DESK.has_point(point):
		var target := desk_cartridge_at(point)
		if target >= 0 and target != dragging:
			notebook.move_to_cartridge(dragging, target)
	dragging = -1
	if megadrive and not seated:
		message = "Drag a cartridge into the console slot."

func start_cartridge() -> void:
	if rom_paths.is_empty():
		powered = true
		preview_started = Time.get_ticks_msec()
		message = "CRT preview running. Choose a ROM folder to play."
		return
	var rom := rom_paths[inserted]
	var enable_mouse := not megadrive and use_snes_mouse(rom)
	var error: String = emulator.start(rom, core_picker.selected, enable_mouse, megadrive)
	if not error.is_empty():
		show_emulator_error(error)
		return
	powered = true
	message = MOUSE_CAPTURE_HINT if enable_mouse else ""

func show_emulator_error(error: String) -> void:
	powered = false
	message = error
	queue_redraw()

func _process(delta: float) -> void:
	update_gamepad_pointer(delta)
	var has_signal := crt.visible or (powered and rom_paths.is_empty())
	if input_static_timer.is_stopped() and crt_static.visible == has_signal:
		update_crt_static()
	var target := emulator.screen_light
	if powered and rom_paths.is_empty():
		target = Color("#496185")
	screen_light = screen_light.lerp(target, 1.0 - exp(-delta * 11.0))
	screen_spill.visible = screen_light.get_luminance() > 0.005
	if screen_spill.visible:
		screen_spill.material.set_shader_parameter("light_color", Vector3(screen_light.r, screen_light.g, screen_light.b))
	if powered and rom_paths.is_empty():
		queue_redraw()

func box(x: float, y: float, width: float, height: float, color: String) -> void:
	prop_canvas.draw_rect(Rect2(x, y, width, height), Color(color))

func words(value: String, x: float, y: float, size: int, width := -1) -> void:
	prop_canvas.draw_string(ThemeDB.fallback_font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, width, size, Color("#f9e4c5"))

func gradient(rect: Rect2, top: String, bottom: String) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
		rect.end, Vector2(rect.position.x, rect.end.y)])
	prop_canvas.draw_polygon(points, PackedColorArray([Color(top), Color(top), Color(bottom), Color(bottom)]))

func shape(points: PackedVector2Array, color: String) -> void:
	prop_canvas.draw_colored_polygon(points, Color(color))

func rounded(rect: Rect2, radius: int, fill: String, border: String = "", canvas: CanvasItem = null) -> void:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(radius)
	style.bg_color = Color(fill)
	if not border.is_empty():
		style.border_color = Color(border)
		style.set_border_width_all(1)
	(canvas if canvas else prop_canvas).draw_style_box(style, rect)

func glow(center: Vector2, size: Vector2, tint: Color, canvas: CanvasItem = self) -> void:
	var points := PackedVector2Array([center])
	var colors := PackedColorArray([tint])
	var edge := Color(tint, 0.0)
	for step in range(65):
		var angle := step * TAU / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
		colors.append(edge)
	# Draw a triangle fan so the light fades smoothly to its perimeter.
	for step in range(1, 65):
		canvas.draw_polygon(PackedVector2Array([points[0], points[step], points[step + 1]]),
			PackedColorArray([colors[0], colors[step], colors[step + 1]]))

func line(from: Vector2, to: Vector2, color: String, width: float = 1.0) -> void:
	prop_canvas.draw_line(from, to, Color(color), width, true)

func uses_black_shell(title: String) -> bool:
	return title.to_lower().replace("_", " ").strip_edges().begins_with("killer instinct")

func cartridge(index: int, at: Vector2, visible_height := -1.0) -> void:
	if visible_height < 0.0:
		visible_height = cartridge_size().y
	if megadrive:
		draw_megadrive_cartridge(index, at, visible_height)
		return
	var width := CART_SIZE.x
	var black_shell := uses_black_shell(titles[index])
	set_prop_transform(at)
	if visible_height == CART_SIZE.y:
		rounded(Rect2(Vector2(3, 5), CART_SIZE), 6, "#18142596")

	# The light catches the shallow top plane before rolling over the front edge.
	shape([Vector2(0, 7), Vector2(2, 3), Vector2(8, 1), Vector2(width - 8, 1),
		Vector2(width - 2, 3), Vector2(width, 7)], "#2d2c33" if black_shell else "#ded8d4")
	line(Vector2(8, 1.8), Vector2(width - 8, 1.8), "#56545c" if black_shell else "#f5ece0")
	for x in [22.0, width - 22.0]:
		var tilt := 1.0 if x < width / 2.0 else -1.0
		line(Vector2(x + tilt, 1.5), Vector2(x, 7), "#18171d" if black_shell else "#938a91")
		line(Vector2(x + tilt + 1, 2), Vector2(x + 1, 7), "#424149" if black_shell else "#eee5de")

	var body := PackedVector2Array([Vector2(0, 7), Vector2(width, 7),
		Vector2(width - 2, visible_height - 4), Vector2(width - 6, visible_height),
		Vector2(6, visible_height), Vector2(2, visible_height - 4)])
	var top := Color("#24232a" if black_shell else "#c6c0c3")
	var bottom := Color("#15141a" if black_shell else "#9e98a2")
	prop_canvas.draw_polygon(body, PackedColorArray([top, top, bottom, bottom, bottom, bottom]))
	line(Vector2(1, 7), Vector2(width - 1, 7), "#4e4b54" if black_shell else "#f2e9e0")
	line(Vector2(2, 10), Vector2(4, visible_height - 5), "#3c3941" if black_shell else "#ddd5d4")
	line(Vector2(width - 2, 10), Vector2(width - 4, visible_height - 5), "#111015" if black_shell else "#807985")
	for y in range(14, 31, 4):
		line(Vector2(2, y), Vector2(5, y + 1), "#45424a" if black_shell else "#8f8994")
		line(Vector2(width - 5, y + 1), Vector2(width - 2, y), "#45424a" if black_shell else "#8f8994")

	var label := Rect2(Vector2(8, 8), LABEL_SIZE)
	rounded(label.grow(0.75), LABEL_RADIUS + 1, "#343239" if black_shell else "#e5ddda", "#1c1b21" if black_shell else "#a29aa1")
	var art := cartridge_label_texture(index)
	if art:
		rounded(label, LABEL_RADIUS, "#36313b")
		prop_canvas.draw_texture_rect(art, label, false)
	else:
		rounded(label, LABEL_RADIUS, LABEL_COLORS[index % LABEL_COLORS.size()])
		prop_canvas.draw_circle(Vector2(width - 23, 18), 8, Color("#ffcf913c"), true, -1, true)
		line(Vector2(13, 17), Vector2(53, 17), "#f8c992", 2)
		words(titles[index], 13, 39, 11, int(width) - 26)

	for x in [22.0, width - 22.0]:
		line(Vector2(x, label.end.y + 1), Vector2(x, visible_height - 1), "#101015" if black_shell else "#817983")
		line(Vector2(x + 1, label.end.y + 1), Vector2(x + 1, visible_height - 1), "#28262e" if black_shell else "#c4bbc0")
	if visible_height > 57.0:
		var grip_height := minf(8.0, visible_height - 56.0)
		rounded(Rect2(31, 56, width - 62, grip_height), 3, "#111016" if black_shell else "#756e7b", "#36333c" if black_shell else "#d6cdd0")
		for y in range(58, mini(62, floori(56 + grip_height))):
			line(Vector2(35, y), Vector2(width - 35, y), "#25232a" if black_shell else "#9b929c")
	var screw_y := CART_SIZE.y - 13.0
	if visible_height >= screw_y + 3.0:
		for x in [11.0, width - 11.0]:
			prop_canvas.draw_circle(Vector2(x, screw_y), 2.5, Color("#101014" if black_shell else "#665e6a"), true, -1, true)
			line(Vector2(x - 1, screw_y), Vector2(x + 1, screw_y), "#37343d" if black_shell else "#b5a9b2")
	set_prop_transform(Vector2.ZERO)

func cartridge_display_title(title: String) -> String:
	var cleaned := title_tags.sub(title, "", true)
	while cleaned != title:
		title = cleaned
		cleaned = title_tags.sub(title, "", true)
	return " ".join(cleaned.split(" ", false))

func draw_megadrive_cartridge(index: int, at: Vector2, height: float) -> void:
	set_prop_transform(at, 0.0, Vector2(MD_CART_WIDTH_SCALE, 1))
	if height == MD_CART_SIZE.y:
		rounded(Rect2(Vector2(3, 5), Vector2(160, height)), 11, "#15111e99")
	var shell := PackedVector2Array([Vector2(0, 11), Vector2(6, 8), Vector2(154, 8), Vector2(160, 11)])
	var corner_y := MD_CART_SIZE.y - 7.0
	if height < corner_y:
		var inset := 6.0 * (height - 11.0) / (corner_y - 11.0)
		shell.append_array(PackedVector2Array([Vector2(160 - inset, height), Vector2(inset, height)]))
	else:
		shell.append_array(PackedVector2Array([Vector2(154, corner_y), Vector2(147, height),
			Vector2(13, height), Vector2(6, corner_y)]))
	var top := Color("#383440")
	var bottom := Color("#1b1823")
	var shell_colors := PackedColorArray([top, top, top, top])
	for vertex in range(4, shell.size()):
		shell_colors.append(bottom)
	prop_canvas.draw_polygon(shell, shell_colors)
	shape([Vector2(0, 11), Vector2(3, 5), Vector2(10, 1), Vector2(150, 1),
		Vector2(157, 5), Vector2(160, 11)], "#3e3948")
	line(Vector2(11, 2), Vector2(149, 2), "#77707f")
	line(Vector2(1, 11), Vector2(159, 11), "#18151d")
	line(Vector2(5, 16), Vector2(10, height - 9), "#504956")
	line(Vector2(154, 16), Vector2(149, height - 9), "#111019")
	var art := cartridge_label_texture(index)
	var accent: String = LABEL_COLORS[index % LABEL_COLORS.size()]
	var end_label := Rect2(25, 3, 110, 8)
	var title := titles[index]
	var palette: PackedColorArray = end_label_palettes.get(title.to_lower(), PackedColorArray())
	var background := Color(accent) if palette.is_empty() else palette[0]
	var ink := Color("#f9e4c5") if palette.is_empty() else palette[1]
	rounded(end_label, 2, background.to_html())
	var shell_scale := Vector2(MD_CART_WIDTH_SCALE, 1)
	var text_baseline := Vector2(29, 8.25) * shell_scale
	set_prop_transform(at + text_baseline, 0.0, shell_scale * 0.5)
	prop_canvas.draw_string(ThemeDB.fallback_font, Vector2.ZERO, cartridge_display_title(title),
		HORIZONTAL_ALIGNMENT_CENTER, 204, 7, ink)
	set_prop_transform(at, 0.0, shell_scale)
	var visible_face := Rect2(0, 0, 160, height)
	var label := MD_LABEL.intersection(visible_face)
	rounded(MD_LABEL.grow(0.8).intersection(visible_face), 4, "#14121b", "#5e5260")
	if art:
		var source_size := art.get_size() * label.size / MD_LABEL.size
		prop_canvas.draw_texture_rect_region(art, label, Rect2(Vector2.ZERO, source_size))
	else:
		rounded(label, 3, accent)
		line(Vector2(30, 22), Vector2(75, 22), "#e6b995", 2)
		words(title, 31, minf(45.0, height - 5.0), 11, 98)
		if height >= 63.0:
			words("MEGA DRIVE", 31, 61, 7, 96)
	set_prop_transform(Vector2.ZERO)

func setup_posters() -> void:
	poster_picker.access = FileDialog.ACCESS_FILESYSTEM
	poster_picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	poster_picker.title = "Choose poster artwork"
	poster_picker.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	poster_picker.file_selected.connect(import_poster)
	poster_picker.add_button("Restore original", true, "restore")
	poster_picker.custom_action.connect(func(_action: String): restore_poster())
	add_child(poster_picker)

	for index in range(POSTER_RECTS.size()):
		var custom := Image.new()
		var path := poster_path(index)
		if FileAccess.file_exists(path) and custom.load(path) == OK and not custom.is_empty():
			poster_images.append(ImageTexture.create_from_image(custom))
		else:
			poster_images.append(POSTER_ART[index])
		var frame: Rect2 = POSTER_RECTS[index]
		var hotspot := Button.new()
		hotspot.name = "Poster%d" % (index + 1)
		hotspot.flat = true
		hotspot.focus_mode = Control.FOCUS_NONE
		hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hotspot.tooltip_text = "Change poster artwork"
		hotspot.position = frame.position
		hotspot.size = frame.size
		hotspot.rotation = deg_to_rad(POSTER_TILTS[index])
		hotspot.pressed.connect(func():
			editing_poster = index
			poster_picker.popup_centered_ratio(0.72))
		add_child(hotspot)

func poster_path(index: int) -> String:
	return POSTER_DIRECTORY.path_join("poster-%d.png" % (index + 1))

func import_poster(path: String) -> void:
	if editing_poster < 0 or editing_poster >= poster_images.size():
		return
	var image := Image.new()
	if image.load(path) != OK or image.is_empty():
		message = "That poster image could not be opened."
		queue_redraw()
		return
	var frame: Rect2 = POSTER_RECTS[editing_poster]
	image.resize(roundi(frame.size.x * 4.0), roundi(frame.size.y * 4.0), Image.INTERPOLATE_LANCZOS)
	if DirAccess.make_dir_recursive_absolute(POSTER_DIRECTORY) != OK or image.save_png(poster_path(editing_poster)) != OK:
		message = "Could not save the poster artwork."
		queue_redraw()
		return
	poster_images[editing_poster] = ImageTexture.create_from_image(image)
	queue_redraw()

func restore_poster() -> void:
	if editing_poster < 0 or editing_poster >= poster_images.size():
		return
	var path := poster_path(editing_poster)
	if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
		message = "Could not restore the original poster."
	else:
		poster_images[editing_poster] = POSTER_ART[editing_poster]
	poster_picker.hide()
	queue_redraw()

func draw_posters() -> void:
	for index in range(poster_images.size()):
		var frame: Rect2 = POSTER_RECTS[index]
		set_prop_transform(frame.position, deg_to_rad(POSTER_TILTS[index]))
		draw_rect(Rect2(Vector2(3, 5), frame.size), Color("#160e2080"))
		draw_rect(Rect2(Vector2.ZERO, frame.size), Color("#baa29c"))
		draw_texture_rect(poster_images[index], Rect2(Vector2.ZERO, frame.size).grow(-2.0), false, Color("#d6bdcc"))
		var tape_x := 10.0 if index % 2 == 0 else frame.size.x - 27.0
		box(tape_x, -2, 17, 5, "#e1bc995a")
		set_prop_transform(Vector2.ZERO)

func draw_bedroom() -> void:
	var room_bounds := Rect2(0, 0, 1152, 648)
	draw_texture_rect(preload("res://art/walls-floor.png"), room_bounds, false)
	draw_texture_rect(preload("res://art/closed-curtains.png"), room_bounds, false)
	draw_texture_rect(preload("res://art/room-details.png"), room_bounds, false)
	draw_posters()
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

func notebook_position() -> Vector2:
	return Vector2(784, 246 if stacked else 202)

func draw_notebook() -> void:
	# The front cartridge covers the lower part of the pad.
	set_prop_transform(notebook_position(), notebook_button.rotation)
	rounded(Rect2(4, 6, 101, 93), 4, "#24182875")
	rounded(Rect2(-2, 1, 103, 94), 4, "#6f4b50", "#956a63")
	rounded(Rect2(1, 3, 98, 91), 3, "#ad8c7a", "#e0b998")
	rounded(Rect2(2, 1, 95, 89), 3, "#ddc5a6", "#f2d9bb")
	gradient(Rect2(5, 8, 89, 74), "#ecd6b7" if notebook_button.is_hovered() else "#dfc8a8", "#c4a78f")
	for y in range(24, 81, 8):
		line(Vector2(7, y), Vector2(92, y), "#7d769352")
	line(Vector2(17, 9), Vector2(17, 81), "#bb7b7666")
	for x in range(9, 96, 9):
		draw_circle(Vector2(x, 5), 1.6, Color("#584653"), true, -1, true)
		draw_arc(Vector2(x, 2), 3.0, PI * 0.2, PI * 1.8, 12, Color("#795d59"), 1.4, true)
	draw_string(ThemeDB.fallback_font, Vector2(22, 21), "Cart List",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#55415e"))
	var notes := PackedVector2Array([Vector2(23, 29), Vector2(32, 28), Vector2(37, 30),
		Vector2(47, 28), Vector2(55, 29), Vector2(70, 27)])
	draw_polyline(notes, Color("#675173aa"), 1.1, true)
	line(Vector2(23, 38), Vector2(76, 36), "#67517379")
	line(Vector2(23, 45), Vector2(64, 44), "#67517369")
	set_prop_transform(Vector2.ZERO)

func notes_position() -> Vector2:
	return Vector2(882, 251 if stacked else 203)

func setup_game_notes() -> void:
	notes_button.name = "GameNotesBook"
	notes_button.flat = true
	notes_button.focus_mode = Control.FOCUS_NONE
	notes_button.tooltip_text = "Open Game Notes for the inserted cartridge"
	notes_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	notes_button.position = notes_position()
	notes_button.rotation = deg_to_rad(-3)
	notes_button.size = Vector2(74, 46)
	notes_button.mouse_entered.connect(queue_redraw)
	notes_button.mouse_exited.connect(queue_redraw)
	notes_button.pressed.connect(func():
		if not seated or inserted < 0 or inserted >= rom_paths.size():
			message = "Insert a game to open its notes."
			queue_redraw()
			return
		manual.hide()
		game_notes.open_rom(rom_paths[inserted]))
	add_child(notes_button)
	add_child(game_notes)
	game_notes.setup(self)

func draw_game_notes_book() -> void:
	set_prop_transform(notes_position(), notes_button.rotation)
	rounded(Rect2(3, 5, 74, 88), 4, "#21172490")
	rounded(Rect2(1, 3, 72, 88), 3, "#d4b493", "#946f69")
	rounded(Rect2(0, 0, 70, 85), 4, "#60505f" if notes_button.is_hovered() else "#524454", "#a48283")
	rounded(Rect2(0, 1, 9, 83), 3, "#392b40")
	rounded(Rect2(14, 12, 49, 24), 3, "#dfc5a7", "#9a7977")
	draw_string(ThemeDB.fallback_font, Vector2(14, 27), "Game Notes",
		HORIZONTAL_ALIGNMENT_CENTER, 49, 8, Color("#49394a"))
	set_prop_transform(Vector2.ZERO)

func setup_manual() -> void:
	manual_button.name = "InstructionManual"
	manual_button.flat = true
	manual_button.focus_mode = Control.FOCUS_NONE
	manual_button.tooltip_text = "Open instruction manual"
	manual_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	manual_button.position = manual_position()
	manual_button.rotation = deg_to_rad(7)
	manual_button.size = Vector2(84, 45)
	manual_button.pressed.connect(func():
		game_notes.close_for_room()
		manual.open_manual())
	manual_button.mouse_entered.connect(queue_redraw)
	manual_button.mouse_exited.connect(queue_redraw)
	manual_button.hide()
	add_child(manual_button)
	add_child(manual)
	manual.setup(self)
	manual.cover_changed.connect(refresh_manual_cover)

func refresh_manual_cover() -> void:
	manual_button.visible = not manual.document_path.is_empty()
	if manual_fade:
		manual_fade.kill()
	manual_opacity = 0.0
	if manual.cover:
		manual_fade = create_tween()
		manual_fade.tween_property(self, "manual_opacity", 1.0, 0.38).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func manual_position() -> Vector2:
	return Vector2(967, 238 if stacked else 192)

func draw_manual() -> void:
	set_prop_transform(manual_position(), manual_button.rotation)
	rounded(Rect2(4, 4, 86, 103), 3, "#21172798")
	rounded(Rect2(2, 2, 85, 102), 2, "#bb9d8a", "#846b74")
	rounded(Rect2(0, 0, 84, 99), 2, "#dacebd" if manual_button.is_hovered() else "#bba99e", "#d7bfaa")
	rounded(Rect2(3, 3, 78, 93), 2, "#675975")
	box(3, 12, 78, 22, "#a28ca3")
	for y in [43, 51, 59]:
		line(Vector2(16, y), Vector2(67, y), "#cdb2b767")
	if manual.cover:
		draw_texture_rect(manual.cover, Rect2(3, 3, 78, 93), false, Color(1, 1, 1, manual_opacity))
	for x in [81, 83, 85]:
		line(Vector2(x, 4), Vector2(x, 99), "#b6a090", 1)
	rounded(Rect2(0, 2, 5, 97), 2, "#49374f")
	line(Vector2(4, 4), Vector2(4, 96), "#ac8991")
	for y in [14, 38, 62, 86]:
		line(Vector2(1, y), Vector2(4, y), "#dfc2b1", 1)
	set_prop_transform(Vector2.ZERO)

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
	rounded(Rect2(775, 559, 340, 34), 5, "#4d354044", "#b2827256")

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
	for x in [170, 646]:
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
	rounded(Rect2(664, 434, 28, 9), 4, "#171720", "#645c6e")
	line(Vector2(669, 435), Vector2(686, 435), "#878093")
	draw_circle(Vector2(695, 452), 2.5, Color("#9fd0bc") if powered else Color("#57444e"))
	rounded(Rect2(147, 484, 547, 9), 3, "#211d29")

func tv_input_rect(index: int) -> Rect2:
	return Rect2(660, 351 + index * 40, 38, 16)

func setup_tv_inputs() -> void:
	for index in range(2):
		var button := Button.new()
		button.name = "SnesInput" if index == 0 else "MegaDriveInput"
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Switch TV input to Super Nintendo" if index == 0 else "Switch TV input to Mega Drive"
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.mouse_entered.connect(queue_redraw)
		button.mouse_exited.connect(queue_redraw)
		button.button_down.connect(queue_redraw)
		button.button_up.connect(queue_redraw)
		button.pressed.connect(request_console_switch.bind(index))
		add_child(button)
		tv_input_buttons.append(button)
	position_tv_inputs()

func position_tv_inputs() -> void:
	for index in range(tv_input_buttons.size()):
		var rect := tv_input_rect(index).grow(3)
		tv_input_buttons[index].position = rect.position + TV_OFFSET
		tv_input_buttons[index].size = rect.size

func draw_tv_inputs() -> void:
	for index in range(tv_input_buttons.size()):
		var rect := tv_input_rect(index)
		var button := tv_input_buttons[index]
		var active := index == int(megadrive)
		rounded(rect, 4, "#191820", "#655b6c")
		var cap := rect.grow(-2.0)
		if button.is_pressed():
			cap.position.y += 1.0
		rounded(cap, 3, "#504a5a" if button.is_hovered() else "#3d3947", "#292630")
		line(cap.position + Vector2(4, 1), Vector2(cap.end.x - 4, cap.position.y + 1), "#777080")
		line(Vector2(cap.position.x + 4, cap.end.y - 2), cap.end - Vector2(4, 2), "#24212d")
		var indicator := Vector2(cap.end.x - 6, cap.get_center().y)
		draw_circle(indicator, 2.5, Color("#28232c"), true, -1, true)
		draw_circle(indicator, 1.5, Color("#c9d6a3" if active else "#554653"), true, -1, true)

		var tape_width := 25.0 if index == 0 else 43.0
		var tape_origin := Vector2(664 if index == 0 else 657, rect.end.y + 4)
		var tilt := deg_to_rad(-6.0 if index == 0 else 4.0)
		set_prop_transform(TV_OFFSET + tape_origin, tilt)
		rounded(Rect2(0, 1, tape_width, 9), 1, "#1a1320")
		rounded(Rect2(0, 0, tape_width, 9), 1, "#4e2b3b" if index == 0 else "#2b3548", "#7f6878")
		var label := "SNES" if index == 0 else "MEGA DRIVE"
		var font := ThemeDB.fallback_font
		draw_string(font, Vector2(0.4, 7.7), label, HORIZONTAL_ALIGNMENT_CENTER, int(tape_width), 7, Color("#221722"))
		draw_string(font, Vector2(0, 7), label, HORIZONTAL_ALIGNMENT_CENTER, int(tape_width), 7, Color("#f3d9d4"))
		set_prop_transform(TV_OFFSET)

func draw_television() -> void:
	set_prop_transform(TV_OFFSET)
	draw_graphite_cabinet()
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
	draw_tv_inputs()
	set_prop_transform(Vector2.ZERO)

func draw_console() -> void:
	if megadrive:
		draw_megadrive_console()
		return
	# The wide front and foreshortened top follow the angled PAL reference.
	glow(Vector2(414, 587), Vector2(171, 27), Color("#201927b0"))
	set_prop_matrix(CONSOLE_TRANSFORM)
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
	if dragging >= 0 and cartridge_edge_meets_slot(pointer):
		rounded(SLOT_ART.grow(3), 7, "#eab58975", "#ffdfad")
	if inserted >= 0 and inserted != dragging:
		set_prop_transform(Vector2.ZERO)
		# At rest the slot hides the shell immediately below the label.
		cartridge(inserted, console_position(), console_cartridge_height())
		set_prop_matrix(CONSOLE_TRANSFORM)
	draw_texture_rect(preload("res://art/pal-console-slot-lip.png"), Rect2(SLOT_ART.position.x - 7.0, SLOT_ART.end.y - 3.0, SLOT_ART.size.x + 14.0, 7.0), false)

	draw_console_button(Rect2(321, 548, 39, BUTTON_HEIGHT), "POWER", "#575465")
	var switch_y := 553 if powered else 558
	line(Vector2(328, switch_y), Vector2(353, switch_y), "#b0a5ae", 2)
	draw_console_button(EJECT_ART, "EJECT", "#bcb9bf" if EJECT.has_point(pointer) else "#a6a1aa")
	draw_console_button(RESET_ART, "RESET", "#817d90" if RESET.has_point(pointer) else "#626070")

	draw_console_wordmark()
	set_prop_transform(Vector2.ZERO)

func draw_megadrive_console() -> void:
	glow(Vector2(412, 594), Vector2(171, 20), Color("#16121fbf"))
	draw_texture_rect(MD_SHELL, Rect2(239.35, 446, 347.3, 159), false)
	rounded(MD_SLOT.grow(2), 7, "#282531", "#61596a")
	rounded(MD_SLOT, 6, "#100f19", "#171620")
	if not seated:
		var flap := Rect2(MD_SLOT.position + Vector2(8, 3), MD_SLOT.size - Vector2(16, 7))
		rounded(flap, 3, "#1c1b28", "#383443")
		line(flap.position + Vector2(5, 1), Vector2(flap.end.x - 5, flap.position.y + 1), "#625a6b")
		line(Vector2(flap.position.x + 7, flap.end.y - 1), flap.end - Vector2(7, 1), "#100e17")
	if dragging >= 0 and not seated and cartridge_edge_meets_slot(pointer):
		rounded(MD_SLOT.grow(2), 7, "#40353d", "#e9bb87")
	if inserted >= 0:
		cartridge(inserted, console_position(), MD_SEATED_HEIGHT)
		line(MD_SLOT.position + Vector2(5, 14), MD_SLOT.end - Vector2(5, 0), "#292531", 2)

	var slider := Rect2(304, 524, 32, 12)
	rounded(slider.grow(1), 3, "#2b2433", "#6e6373")
	rounded(slider, 2, "#14131d", "#16141f")
	var switch_x := 308.0 if powered else 322.0
	var toggle := Rect2(switch_x, 525, 10, 10)
	rounded(toggle, 2, "#3e3545", "#635a69")
	gradient(toggle.grow(-1.5), "#7a6e7d", "#252330")
	line(toggle.position + Vector2(4, 1), toggle.position + Vector2(4, 8), "#bc6867")
	words("ON", 305, 541, 4)
	words("OFF", 327, 541, 4)
	words("POWER", 307, 547, 6)
	words("VOL", 278, 569, 5)
	rounded(MD_RESET.grow(1), 3, "#201c29", "#726774")
	var reset_cap := MD_RESET.grow(-1.5)
	rounded(reset_cap, 2, "#fff0dc" if MD_RESET.has_point(pointer) and seated else "#c6bdb6")
	gradient(reset_cap.grow(-1.0), "#fff4e5" if MD_RESET.has_point(pointer) and seated else "#f3e6d5", "#b0a29d")
	for x in range(308, 332, 4):
		for y in [554.0, 557.0]:
			draw_circle(Vector2(x, y), 0.6, Color("#81747c"), true, -1, true)
	words("RESET", 308, 571, 6)

	var font := ThemeDB.fallback_font
	var badge_position := Vector2(413, 535)
	draw_string(font, badge_position + Vector2(0, 1), "16-BIT", HORIZONTAL_ALIGNMENT_CENTER, 68, 17, Color("#715741"))
	draw_string(font, badge_position, "16-BIT", HORIZONTAL_ALIGNMENT_CENTER, 68, 17, Color("#f0d292"))
	draw_string(font, Vector2(425, 558), "POWER", HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color("#524451"))
	draw_string(font, Vector2(457, 558), "ON", HORIZONTAL_ALIGNMENT_LEFT, -1, 4, Color("#524451"))
	draw_circle(MD_POWER_LED, 3.25, Color("#66565c"), true, -1, true)
	draw_circle(MD_POWER_LED, 2.45, Color("#30232e"), true, -1, true)
	set_prop_transform(Vector2(500, 575), 0.0, Vector2(0.75, 0.75))
	draw_string(font, Vector2.ZERO, "MEGA DRIVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#d5c5d4"))
	draw_string(font, Vector2(57, 0), "SEGA", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#e6d7e2"))
	set_prop_transform(Vector2.ZERO)
	for port in [MD_PORT_ONE, MD_PORT_TWO]:
		rounded(port.grow(1), 3, "#181620", "#635767")
		shape([port.position + Vector2(2, 1), port.position + Vector2(31, 1),
			port.position + Vector2(27, 8), port.position + Vector2(6, 8)], "#0e0d16")
		line(port.position + Vector2(4, 2), port.position + Vector2(29, 2), "#706573")
		for column in range(5):
			draw_circle(port.position + Vector2(7 + 4.7 * column, 3.4), 0.65, Color("#a79ba5"), true, -1, true)
		for column in range(4):
			draw_circle(port.position + Vector2(9.5 + 4.7 * column, 6.1), 0.55, Color("#827784"), true, -1, true)

func draw_console_wordmark() -> void:
	var font := ThemeDB.fallback_font
	var title := "SUPER NINTENDO"
	var subtitle := "ENTERTAINMENT SYSTEM"
	var title_width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	set_prop_matrix(CONSOLE_TRANSFORM * Transform2D(0.0, Vector2(1, 0.43), 0.0, Vector2(321, 578.7)))
	draw_string(font, Vector2.ZERO, title, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#494654"))

	var glyph_widths := PackedFloat32Array()
	var subtitle_width := 0.0
	for index in range(subtitle.length()):
		var glyph_width := font.get_string_size(subtitle.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
		glyph_widths.append(glyph_width)
		subtitle_width += glyph_width
	var tracking := (title_width - subtitle_width) / (subtitle.length() - 1)
	set_prop_matrix(CONSOLE_TRANSFORM * Transform2D(0.0, Vector2(1, 0.48), 0.0, Vector2(321, 581.9)))
	var x := 0.0
	for index in range(subtitle.length()):
		draw_string(font, Vector2(x, 0), subtitle.substr(index, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 5, Color("#68616c"))
		x += glyph_widths[index] + tracking
	set_prop_matrix(CONSOLE_TRANSFORM)

func draw_controller_plugs() -> void:
	var first := seated_plug_position(MD_PORT_ONE if megadrive else PLAYER_ONE_SOCKET)
	var second := player_two_plug_position()
	if dragging_plug and plug_over_socket(pointer):
		rounded(player_two_socket().grow(4), 5, "#a47b62", "#ffd7aa")
	var cable_exit_y := get_viewport_rect().end.y + 6.0
	draw_controller_plug(first, Vector2(438 if megadrive else 379, cable_exit_y))
	if not dragging_plug:
		draw_controller_plug(second, Vector2(SECOND_CABLE_EXIT_X, cable_exit_y))

func draw_controller_plug(at: Vector2, cable_end: Vector2) -> void:
	var start := at + Vector2(PLUG_SIZE.x / 2.0, PLUG_SIZE.y - 1.0)
	var exit_bend := cable_end - Vector2(0, 16)
	var bend_height := maxf(0.0, exit_bend.y - start.y)
	var points := PackedVector2Array()
	for index in range(33):
		points.append(start.bezier_interpolate(start + Vector2(0, bend_height * 0.55),
			exit_bend - Vector2(0, bend_height * 0.3), exit_bend, index / 32.0))
	points.append(cable_end)
	prop_canvas.draw_polyline(points, Color("#292633"), 5.0, true)
	prop_canvas.draw_polyline(points, Color("#746e7a"), 2.0, true)
	rounded(Rect2(at + Vector2(2, 3), PLUG_SIZE), 4, "#29263388")
	rounded(Rect2(at, PLUG_SIZE), 4, "#302b38" if megadrive else "#676271", "#696070" if megadrive else "#a49ba5")
	line(at + Vector2(7, 5), at + Vector2(34, 5), "#625869" if megadrive else "#a198a6")
	rounded(Rect2(at + Vector2(8, 9), Vector2(25, 4)), 2, "#211e29" if megadrive else "#524e5e")
	rounded(Rect2(start - Vector2(4, 3), Vector2(8, 7)), 2, "#282532" if megadrive else "#5d5967")

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
	var caption_transform := Transform2D(0.0, Vector2(1, 0.51), 0.0, baseline)
	set_prop_matrix(CONSOLE_TRANSFORM * caption_transform)
	draw_string(ThemeDB.fallback_font, Vector2.ZERO, label, HORIZONTAL_ALIGNMENT_CENTER, width, size, Color(ink))
	set_prop_matrix(CONSOLE_TRANSFORM)

func set_prop_transform(origin: Vector2, rotation := 0.0, scale := Vector2.ONE) -> void:
	prop_canvas.draw_set_transform(origin + prop_draw_offset, rotation, scale)

func set_prop_matrix(matrix: Transform2D) -> void:
	draw_set_transform_matrix(matrix.translated(prop_draw_offset))

func _draw() -> void:
	draw_bedroom()
	draw_ceiling_light()
	prop_draw_offset = right_slide
	set_prop_transform(Vector2.ZERO)
	draw_shoebox()
	draw_notebook()
	draw_game_notes_book()
	draw_manual()
	prop_draw_offset = Vector2.ZERO
	set_prop_transform(Vector2.ZERO)
	draw_tv_stand()
	draw_television()
	prop_draw_offset = left_slide
	set_prop_transform(Vector2.ZERO)
	draw_console()
	draw_controller_plugs()
	prop_draw_offset = right_slide
	set_prop_transform(Vector2.ZERO)
	for index in visible_cartridges():
		if index != inserted and index != dragging:
			var position := displayed_desk_position(index)
			if index == notebook_selection:
				rounded(Rect2(position - Vector2(3, 3), cartridge_size() + Vector2(6, 6)), 6, "#f7ca9188")
			cartridge(index, position)
	draw_shoebox_front()
	prop_draw_offset = Vector2.ZERO
	set_prop_transform(Vector2.ZERO)
	dragged_prop_layer.queue_redraw()
	room_overlay.queue_redraw()

func draw_dragged_prop() -> void:
	prop_canvas = dragged_prop_layer
	if dragging_plug:
		var cable_end := Vector2(SECOND_CABLE_EXIT_X, get_viewport_rect().end.y + 6.0)
		draw_controller_plug(player_two_plug_position(), cable_end)
	if dragging >= 0 and not (megadrive and seated and dragging == inserted):
		cartridge(dragging, dragged_cartridge_position(pointer))
	prop_canvas = self

func draw_room_overlay() -> void:
	var font := ThemeDB.fallback_font
	var ink := Color("#f9e4c5")
	room_overlay.draw_string(font, Vector2(32, 633), message, HORIZONTAL_ALIGNMENT_LEFT, 920, 16, ink)
	room_overlay.draw_string(font, Vector2(994, 633), "F11  Fullscreen", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
	if not powered:
		return
	if megadrive:
		var led := MD_POWER_LED + left_slide
		glow(led, Vector2(13, 9), Color("#fb435475"), room_overlay)
		room_overlay.draw_circle(led, 2.3, Color("#fc4258"), true, -1, true)
	else:
		room_overlay.draw_set_transform_matrix(CONSOLE_TRANSFORM.translated(left_slide))
		glow(Vector2(499, 579), Vector2(20, 8), Color("#ff4d5568"), room_overlay)
		rounded(Rect2(492, 577.8, 14, 3), 2, "#ff3d5c", "", room_overlay)
		room_overlay.draw_line(Vector2(495, 578.3), Vector2(503, 578.3), Color("#ffacaf"), 1.0, true)
		room_overlay.draw_set_transform(Vector2.ZERO)
