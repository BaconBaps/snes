extends Node2D

const SLOT := Rect2(329, 505, 184, 23)
const POWER := Rect2(276, 536, 88, 43)
const EJECT := Rect2(473, 536, 88, 43)
const DESK := Rect2(765, 306, 372, 253)
const SCREEN := Rect2(241, 179, 328, 246)
const CART_SIZE := Vector2(92, 54)
const PAGE_SIZE := 9
const LABEL_COLORS := ["#367d80", "#a05261", "#646095", "#8b693c"]

var titles := PackedStringArray(["Star Hopper", "Midnight Rally", "Moon Orchard", "Wave Rider", "Snow Circuit", "Tiny Atlas"])
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

func _ready() -> void:
	var picker := FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.dir_selected.connect(load_folder)
	add_child(picker)

	var button := Button.new()
	button.text = "Choose ROM folder"
	button.position = Vector2(771, 244)
	button.pressed.connect(func(): picker.popup_centered_ratio(0.8))
	add_child(button)

func load_folder(path: String) -> void:
	var folder := DirAccess.open(path)
	if folder == null:
		message = "That folder could not be opened."
		queue_redraw()
		return
	titles.clear()
	for file in folder.get_files():
		if file.get_extension().to_lower() in ["sfc", "smc"]:
			titles.append(file.get_basename())
	titles.sort()
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
	return Vector2(788 + (cell % 3) * 111, 333 + floori(cell / 3.0) * 68)

func console_position() -> Vector2:
	return Vector2(375, 470 - lift)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var window := get_window()
		window.mode = Window.MODE_WINDOWED if window.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
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
	if POWER.has_point(point):
		powered = seated and not powered
		if powered:
			message = "CRT preview running. Click Eject to release the cartridge."
		elif seated:
			message = "Power off. The cartridge is still in the slot."
		else:
			message = "Insert a cartridge before switching on the console."
	elif EJECT.has_point(point) and seated:
		powered = false
		seated = false
		eject_animation = create_tween()
		eject_animation.tween_property(self, "lift", 29.0, 0.17).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		message = "Drag the ejected cartridge back to the desk."
	elif inserted >= 0 and not seated and Rect2(console_position(), CART_SIZE).has_point(point):
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
		message = "Cartridge inserted. Click Power."
	elif dragging == inserted and DESK.has_point(point):
		page = floori(inserted / float(PAGE_SIZE))
		inserted = -1
		reset_lift()
		message = "Drag a cartridge into the console slot."
	dragging = -1

func box(x: float, y: float, width: float, height: float, color: String) -> void:
	draw_rect(Rect2(x, y, width, height), Color(color))

func words(value: String, x: float, y: float, size: int, width := -1) -> void:
	draw_string(ThemeDB.fallback_font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, width, size, Color("#f9e4c5"))

func cartridge(index: int, at: Vector2) -> void:
	draw_rect(Rect2(at + Vector2(4, 5), CART_SIZE), Color("#261d2c"))
	draw_rect(Rect2(at, CART_SIZE), Color("#aaa5af"))
	box(at.x + 4, at.y + 3, 84, 4, "#d1c8c6")
	box(at.x + 8, at.y + 9, 76, 29, LABEL_COLORS[index % LABEL_COLORS.size()])
	box(at.x + 11, at.y + 13, 21, 3, "#ffd18e")
	words(titles[index], at.x + 11, at.y + 32, 10, 68)
	box(at.x + 12, at.y + 46, 68, 5, "#82798b")

func _draw() -> void:
	# Wallpaper, moonlit window, poster, and floorboards.
	box(0, 0, 1152, 454, "#29304b")
	for x in range(0, 1152, 38):
		box(x, 0, 3, 454, "#333953")
	box(0, 451, 1152, 13, "#514353")
	box(0, 464, 1152, 184, "#51394a")
	for y in [484, 512, 550, 601]:
		box(0, y, 1152, 3, "#382b40")
	box(52, 105, 156, 201, "#75617a")
	box(60, 113, 140, 185, "#162743")
	draw_circle(Vector2(150, 155), 18, Color("#e1ceaf"))
	for star in [Vector2(73, 135), Vector2(92, 171), Vector2(174, 172), Vector2(181, 238)]:
		draw_circle(star, 2, Color("#b4c7df"))
	box(126, 113, 6, 185, "#665971")
	box(60, 201, 140, 6, "#665971")
	box(43, 298, 174, 10, "#8a6875")
	box(642, 89, 79, 124, "#5a4871")
	box(649, 96, 65, 110, "#346075")
	draw_circle(Vector2(681, 141), 20, Color("#f0a275"))
	box(650, 166, 63, 4, "#96a5ae")
	box(770, 322, 351, 227, "#82564f")
	box(757, 314, 378, 14, "#c0896a")
	box(757, 543, 378, 15, "#b18164")
	box(775, 558, 22, 53, "#64414a")
	box(1095, 558, 22, 53, "#64414a")
	words("Cartridge collection", 771, 223, 25)

	# TV cabinet, glass, and scanlines.
	box(229, 425, 398, 34, "#171829")
	box(216, 151, 420, 293, "#77717f")
	box(223, 158, 404, 277, "#494958")
	box(231, 169, 349, 266, "#252635")
	draw_rect(SCREEN, Color("#151c28"))
	if powered:
		draw_rect(SCREEN, Color("#253951"))
		draw_circle(Vector2(484, 258), 42, Color("#f4aa79"))
		box(241, 327, 328, 98, "#2a5861")
		box(241, 357, 328, 68, "#234550")
		words("CRT PREVIEW", 260, 211, 13)
		words(titles[inserted], 260, 318, 23, 292)
	else:
		box(254, 189, 297, 5, "#283241")
	for y in range(180, 425, 4):
		draw_line(Vector2(241, y), Vector2(568, y), Color(0, 0, 0, 0.19))
	for y in range(211, 336, 8):
		box(588, y, 26, 3, "#303140")
	draw_circle(Vector2(600, 403), 4, Color("#8bd6ae") if powered else Color("#272934"))

	# The slot lip covers the cartridge base when seated.
	box(243, 502, 355, 91, "#30263c")
	box(248, 494, 345, 81, "#b4aabb")
	box(248, 574, 345, 11, "#847b98")
	draw_rect(SLOT, Color("#363248"))
	if dragging >= 0 and SLOT.grow(20).has_point(pointer):
		draw_rect(SLOT, Color("#f9d39d"), false, 2)
	if inserted >= 0 and inserted != dragging:
		cartridge(inserted, console_position())
	if seated:
		box(330, 516, 182, 12, "#9690a3")
	draw_rect(POWER, Color("#8272a1") if POWER.has_point(pointer) else Color("#665883"))
	draw_rect(EJECT, Color("#8272a1") if EJECT.has_point(pointer) else Color("#665883"))
	words("POWER", 287, 562, 14)
	words("EJECT", 485, 562, 14)
	draw_circle(Vector2(374, 548), 4, Color("#fa795f") if powered else Color("#52445d"))

	for index in range(page * PAGE_SIZE, mini(titles.size(), (page + 1) * PAGE_SIZE)):
		if index != inserted and index != dragging:
			cartridge(index, desk_position(index))
	if titles.size() > PAGE_SIZE:
		words("Scroll for more cartridges", 783, 580, 14)
	if dragging >= 0:
		cartridge(dragging, pointer - CART_SIZE / 2.0)
	words(message, 39, 620, 18)
	words("F11  Fullscreen", 989, 620, 16)
