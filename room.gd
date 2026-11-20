extends Node2D

const CONSOLE_FLOOR := 607.0
const CONSOLE_HEIGHT_SCALE := 1.75
const CONSOLE_TRANSFORM := Transform2D(Vector2.RIGHT, Vector2(0, CONSOLE_HEIGHT_SCALE),
	Vector2(0, CONSOLE_FLOOR * (1.0 - CONSOLE_HEIGHT_SCALE)))
const SLOT_ART := Rect2(347, 525, 137, 14)
const BUTTON_HEIGHT := 23.0 * 0.85
const RESET_ART := Rect2(470, 548, 39, BUTTON_HEIGHT)
const EJECT_ART := Rect2(376, 548, 77, BUTTON_HEIGHT)
const SLOT := CONSOLE_TRANSFORM * SLOT_ART
const RESET := CONSOLE_TRANSFORM * RESET_ART
const EJECT := CONSOLE_TRANSFORM * EJECT_ART
const DESK := Rect2(770, 301, 354, 246)
const TV_OFFSET := Vector2(0, -55)
const TV_GLASS := Rect2(153, 96, 480, 360)
const SCREEN := Rect2(TV_GLASS.position + TV_OFFSET, TV_GLASS.size)
const CART_SIZE := Vector2(122, 70)
const SEATED_CART_HEIGHT := 49.0
const PAGE_SIZE := 6
const LABEL_COLORS := ["#367d80", "#a05261", "#646095", "#8b693c"]

var titles := PackedStringArray(["Star Hopper", "Midnight Rally", "Moon Orchard", "Wave Rider", "Snow Circuit", "Tiny Atlas"])
var rom_paths := PackedStringArray()
var emulator := preload("res://emulator/bridge.gd").new()
var core_picker := OptionButton.new()
var preview_started := 0
var inserted := -1
var dragging := -1
var seated := false
var powered := false
var page := 0
var pointer := Vector2.ZERO
var message := "Drag a cartridge into the console slot."
var eject_animation: Tween
var lift := 0.0:
	set(value):
		lift = value
		queue_redraw()

var crt := TextureRect.new()
var diagnostics := Label.new()

func _ready() -> void:
	var crt_material := ShaderMaterial.new()
	crt_material.shader = preload("res://emulator/crt.gdshader")
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

	var picker := FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.dir_selected.connect(load_folder)
	add_child(picker)

	var button := Button.new()
	button.text = "Choose ROM folder"
	button.position = Vector2(810, 256)
	button.custom_minimum_size = Vector2(165, 34)
	for state in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#594251") if state == "normal" else Color("#825b65")
		style.border_color = Color("#ac7980")
		style.set_border_width_all(1)
		style.set_corner_radius_all(5)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(func(): picker.popup_centered_ratio(0.8))
	add_child(button)

	core_picker.position = Vector2(980, 256)
	core_picker.custom_minimum_size = Vector2(143, 34)
	core_picker.tooltip_text = "Emulation core for the next cartridge"
	for name in emulator.CORE_NAMES:
		core_picker.add_item(name)
	add_child(core_picker)

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
	emulator.stop()
	titles.clear()
	rom_paths.clear()
	var files := folder.get_files()
	files.sort()
	for file in files:
		if file.get_extension().to_lower() in ["sfc", "smc"]:
			titles.append(file.get_basename())
			rom_paths.append(path.path_join(file))
	inserted = -1
	dragging = -1
	seated = false
	powered = false
	page = 0
	reset_lift()
	message = "No .sfc or .smc files in this folder." if titles.is_empty() else "Drag a cartridge into the console slot."
	queue_redraw()

func reset_lift() -> void:
	if eject_animation:
		eject_animation.kill()
	lift = 0.0

func desk_position(index: int) -> Vector2:
	var cell := index % PAGE_SIZE
	return Vector2(799 + (cell % 2) * 164, 320 + floori(cell / 2.0) * 73)

func console_position() -> Vector2:
	var slot_lip := CONSOLE_TRANSFORM * Vector2(SLOT_ART.get_center().x, 536)
	return slot_lip - Vector2(CART_SIZE.x / 2.0, SEATED_CART_HEIGHT + lift)

func console_cartridge_height() -> float:
	return minf(CART_SIZE.y, SEATED_CART_HEIGHT + lift)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var window := get_window()
			window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif event.keycode == KEY_F10:
			diagnostics.visible = not diagnostics.visible
	elif event is InputEventMouseMotion:
		pointer = get_local_mouse_position()
	elif event is InputEventMouseButton:
		pointer = get_local_mouse_position()
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				press_at(pointer)
			elif dragging >= 0:
				drop_at(pointer)
		elif event.pressed and DESK.has_point(pointer) and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
			page = clampi(page + direction, 0, maxi(0, ceili(titles.size() / float(PAGE_SIZE)) - 1))
	queue_redraw()

func press_at(point: Vector2) -> void:
	if RESET.has_point(point) and seated:
		if emulator.running:
			emulator.reset()
		elif not powered:
			start_cartridge()
		else:
			preview_started = Time.get_ticks_msec()
			message = "CRT preview reset."
	elif EJECT.has_point(point) and seated:
		emulator.stop()
		powered = false
		seated = false
		eject_animation = create_tween()
		eject_animation.tween_property(self, "lift", 24.0, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		message = "Drag the ejected cartridge back to the desk."
	elif inserted >= 0 and not seated and Rect2(console_position(), Vector2(CART_SIZE.x, console_cartridge_height())).has_point(point):
		dragging = inserted
	elif inserted < 0:
		for index in range(page * PAGE_SIZE, mini(titles.size(), (page + 1) * PAGE_SIZE)):
			if Rect2(desk_position(index), CART_SIZE).has_point(point):
				dragging = index
				break

func drop_at(point: Vector2) -> void:
	if SLOT.grow(20).has_point(point):
		inserted = dragging
		seated = true
		reset_lift()
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
	message = "Reset restarts the game. Eject returns the cartridge."

func show_emulator_error(error: String) -> void:
	powered = false
	message = error
	queue_redraw()

func _process(_delta: float) -> void:
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
	var shell := Vector2(CART_SIZE.x, visible_height)
	if visible_height == CART_SIZE.y:
		rounded(Rect2(at + Vector2(3, 5), shell), 5, "#221926a8")
	rounded(Rect2(at, shell), 5, "#9d9aa4", "#c5bcc1")
	gradient(Rect2(at + Vector2(5, 4), Vector2(CART_SIZE.x - 10, 43)), "#ccc6ca", "#a099a4")
	var label := Rect2(at + Vector2(8, 8), Vector2(CART_SIZE.x - 16, 37))
	rounded(label, 3, LABEL_COLORS[index % LABEL_COLORS.size()])
	draw_circle(at + Vector2(CART_SIZE.x - 23, 18), 8, Color("#ffcf913c"), true, -1, true)
	line(at + Vector2(13, 17), at + Vector2(53, 17), "#f8c992", 2)
	words(titles[index], at.x + 13, at.y + 39, 11, int(CART_SIZE.x) - 26)
	if visible_height > 57.0:
		box(at.x + 8, at.y + 56, CART_SIZE.x - 16, minf(7.0, visible_height - 56.0), "#77717d")
		line(at + Vector2(12, 57), at + Vector2(CART_SIZE.x - 12, 57), "#bbb0b6")

func draw_bedroom() -> void:
	gradient(Rect2(0, 0, 1152, 405), "#292d49", "#796178")
	for x in range(18, 1152, 31):
		box(x, 0, 1, 405, "#d3a7b011")
		box(x + 5, 0, 1, 405, "#291d381a")
	glow(Vector2(923, 180), Vector2(320, 253), Color("#ec9c6c38"))
	box(0, 400, 1152, 17, "#4b354d")
	line(Vector2(0, 400), Vector2(1152, 400), "#a17881", 2)
	gradient(Rect2(0, 417, 1152, 231), "#735052", "#392936")
	for y in [437, 461, 491, 529, 576, 638]:
		line(Vector2(0, y), Vector2(1152, y), "#281e2f89", 2)
	for x in range(-250, 1500, 115):
		line(Vector2(530 + (x - 530) * 0.54, 417), Vector2(x, 648), "#261b2e56")

	# Moonlit window and curtains behind the television.
	rounded(Rect2(18, 36, 186, 264), 5, "#322840")
	gradient(Rect2(30, 47, 162, 239), "#1a2349", "#8c6788")
	glow(Vector2(83, 103), Vector2(34, 35), Color("#dfd4ff77"))
	draw_circle(Vector2(83, 103), 18, Color("#f5dfcf"), true, -1, true)
	for star in [Vector2(55, 79), Vector2(104, 66), Vector2(123, 127), Vector2(56, 150), Vector2(156, 84)]:
		draw_circle(star, 1.45, Color("#fbdfd3"), true, -1, true)
	box(109, 47, 6, 239, "#6a526f")
	box(30, 161, 162, 6, "#71556f")
	shape([Vector2(13, 42), Vector2(55, 42), Vector2(44, 173), Vector2(58, 292),
		Vector2(13, 302)], "#53405f")
	line(Vector2(32, 47), Vector2(27, 290), "#8a6482", 2)
	box(10, 288, 195, 7, "#795970")

	# Bedspread at the edge of the room.
	rounded(Rect2(-47, 340, 133, 88), 19, "#756482")
	shape([Vector2(-12, 387), Vector2(66, 388), Vector2(109, 450), Vector2(87, 532),
		Vector2(-12, 545)], "#666078")
	shape([Vector2(-12, 387), Vector2(66, 388), Vector2(109, 450), Vector2(-12, 461)], "#93839b")
	for x in range(0, 87, 13):
		line(Vector2(x, 400 + x * 0.55), Vector2(x - 8, 525), "#bda3b132")

	# Woven rug under the console.
	shape([Vector2(188, 483), Vector2(630, 483), Vector2(754, 600), Vector2(84, 600)], "#261c2b7f")
	shape([Vector2(192, 481), Vector2(626, 481), Vector2(733, 594), Vector2(96, 594)], "#684958")
	shape([Vector2(205, 488), Vector2(615, 488), Vector2(706, 581), Vector2(123, 581)], "#8c5d6a")
	for y in range(491, 581, 4):
		var side := (y - 491) * 0.85
		line(Vector2(204 - side, y), Vector2(616 + side, y), "#d4928f24")
	glow(Vector2(414, 492), Vector2(305, 115), Color("#161323a5"))

func draw_desk() -> void:
	# A warm desk lamp lights the cartridge tray.
	box(1032, 162, 8, 133, "#4c3246")
	line(Vector2(1036, 165), Vector2(1036, 284), "#e2a780", 2)
	rounded(Rect2(1000, 282, 67, 10), 5, "#614354", "#b78570")
	shape([Vector2(1004, 125), Vector2(1069, 125), Vector2(1090, 169), Vector2(981, 169)], "#8c575c")
	shape([Vector2(1010, 126), Vector2(1063, 126), Vector2(1078, 166), Vector2(992, 166)], "#bc7f6f")
	glow(Vector2(1035, 171), Vector2(95, 49), Color("#ffd3a576"))
	line(Vector2(984, 169), Vector2(1087, 169), "#fac297", 3)

	rounded(Rect2(777, 482, 336, 100), 5, "#30212e")
	gradient(Rect2(783, 514, 319, 64), "#8c5957", "#523545")
	box(789, 562, 22, 41, "#593a46")
	box(1079, 559, 20, 44, "#563741")
	shape([Vector2(810, 292), Vector2(1099, 292), Vector2(1130, 539), Vector2(752, 539)], "#a77163")
	shape([Vector2(819, 301), Vector2(1091, 301), Vector2(1115, 535), Vector2(769, 535)], "#74545b")
	gradient(Rect2(785, 322, 311, 213), "#8b625f", "#6a4956")
	for y in [316, 391, 464, 538]:
		line(Vector2(784, y), Vector2(1105, y), "#442f42", 2)
	box(752, 539, 378, 15, "#704754")
	line(Vector2(754, 539), Vector2(1128, 539), "#d49379", 2)
	words("Cartridge collection", 810, 240, 25)
	if titles.size() > PAGE_SIZE:
		words("Scroll for more cartridges", 788, 572, 14)

func draw_television() -> void:
	draw_set_transform(TV_OFFSET)
	# The front stays square to the viewer. The top recedes symmetrically.
	shape([Vector2(130, 85), Vector2(151, 62), Vector2(686, 62), Vector2(707, 85)], "#80727e")
	line(Vector2(155, 64), Vector2(682, 64), "#a49197", 2)
	for x in range(536, 653, 7):
		line(Vector2(x, 67), Vector2(x + 4, 73), "#514757")
	rounded(Rect2(125, 75, 587, 414), 22, "#514859", "#a18a91")
	rounded(Rect2(139, 84, 508, 387), 18, "#272432", "#6c5b6d")
	rounded(Rect2(146, 90, 494, 374), 12, "#141623", "#181925")
	draw_rect(TV_GLASS, Color("#171d2d"))
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
	for y in range(98, 456, 4):
		line(Vector2(153, y), Vector2(633, y), "#090b1524")
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
	rounded(Rect2(277, 574, 277, 33), 14, "#958579", "#b4a297")
	rounded(Rect2(282, 579, 267, 21), 9, "#aea195")
	shape([Vector2(277, 581), Vector2(281, 571), Vector2(308, 508), Vector2(316, 501),
		Vector2(514, 501), Vector2(523, 508), Vector2(552, 572), Vector2(554, 581),
		Vector2(545, 588), Vector2(287, 588)], "#d9cbb8")
	shape([Vector2(288, 579), Vector2(313, 508), Vector2(518, 508), Vector2(543, 579),
		Vector2(536, 584), Vector2(294, 584)], "#e8ddcc")
	line(Vector2(294, 586), Vector2(538, 586), "#f7e4cf", 2)
	line(Vector2(281, 592), Vector2(550, 592), "#7c7069")
	shape([Vector2(320, 511), Vector2(510, 511), Vector2(530, 568), Vector2(524, 574),
		Vector2(305, 574), Vector2(301, 569)], "#918b94")
	shape([Vector2(323, 511), Vector2(508, 511), Vector2(525, 567), Vector2(520, 571),
		Vector2(310, 571), Vector2(306, 567)], "#aaa5af")
	for x in range(330, 507, 7):
		line(Vector2(x, 502), Vector2(x, 507), "#887d78", 2)

	draw_circle(Vector2(503, 519), 5.5, Color("#817d89"), true, -1, true)
	draw_circle(Vector2(502, 517), 1.55, Color("#72a9d3"), true, -1, true)
	draw_circle(Vector2(506, 519), 1.55, Color("#df7773"), true, -1, true)
	draw_circle(Vector2(500, 520), 1.55, Color("#83c49d"), true, -1, true)
	draw_circle(Vector2(503, 522), 1.55, Color("#edc479"), true, -1, true)

	# The top hatch sits behind the three controls, with its lip in front of the cartridge.
	rounded(SLOT_ART.grow(4), 8, "#928c96")
	rounded(SLOT_ART, 6, "#292634")
	if inserted < 0 or dragging == inserted:
		rounded(SLOT_ART.grow(-2), 5, "#696473", "#a5a0aa")
		words("P A L   V E R S I O N", 379, 535, 7)
	if dragging >= 0 and SLOT.grow(20).has_point(pointer):
		rounded(SLOT_ART.grow(3), 7, "#eab58975", "#ffdfad")
	if inserted >= 0 and inserted != dragging:
		draw_set_transform(Vector2.ZERO)
		# At rest the slot hides the shell immediately below the label.
		cartridge(inserted, console_position(), console_cartridge_height())
		draw_set_transform_matrix(CONSOLE_TRANSFORM)
		if seated:
			line(Vector2(352, 536), Vector2(479, 536), "#3e3547", 2)

	draw_console_button(Rect2(321, 548, 39, BUTTON_HEIGHT), "POWER", "#575465")
	var switch_y := 553 if powered else 558
	line(Vector2(328, switch_y), Vector2(353, switch_y), "#b0a5ae", 2)
	draw_console_button(EJECT_ART, "EJECT", "#bcb9bf" if EJECT.has_point(pointer) else "#a6a1aa")
	draw_console_button(RESET_ART, "RESET", "#817d90" if RESET.has_point(pointer) else "#626070")

	draw_string(ThemeDB.fallback_font, Vector2(315, 583), "SUPER NINTENDO",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#494654"))
	rounded(Rect2(490, 577, 18, 5), 3, "#786567", "#c4b2ae")
	if powered:
		glow(Vector2(499, 579), Vector2(24, 12), Color("#ff4d557f"))
		rounded(Rect2(491, 577, 16, 5), 2, "#ff3d5c")

	rounded(Rect2(335, 589, 157, 13), 7, "#b6a597", "#867a73")
	for x in [355, 440]:
		rounded(Rect2(x, 591, 35, 8), 3, "#34313c")
		for pin in range(7):
			draw_circle(Vector2(x + 4 + pin * 4.5, 595), 1.0, Color("#aa9892"))
	rounded(Rect2(348, 591, 41, 13), 4, "#676271", "#8e8590")
	line(Vector2(369, 603), Vector2(371, 608), "#37323e", 4)
	line(Vector2(371, 608), Vector2(379, 611), "#37323e", 4)
	draw_set_transform(Vector2.ZERO)

func draw_console_button(rect: Rect2, label: String, color: String) -> void:
	rounded(rect.grow(2), 5, "#d8cec6", "#8a828d")
	rounded(rect, 4, color, "#716a78")
	var center := rect.get_center()
	draw_string(ThemeDB.fallback_font, Vector2(rect.position.x, center.y + 7), label,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 8, Color("#f9f1eb"))

func _draw() -> void:
	draw_bedroom()
	draw_desk()
	draw_television()
	draw_console()
	for index in range(page * PAGE_SIZE, mini(titles.size(), (page + 1) * PAGE_SIZE)):
		if index != inserted and index != dragging:
			cartridge(index, desk_position(index))
	if dragging >= 0:
		cartridge(dragging, pointer - CART_SIZE / 2.0)
	gradient(Rect2(0, 607, 1152, 41), "#271d2cca", "#1d1726")
	words(message, 32, 633, 16, 920)
	words("F11  Fullscreen", 994, 633, 15)
