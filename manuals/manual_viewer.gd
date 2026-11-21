extends PanelContainer

const LocalRuntime := preload("res://local_runtime.gd")

signal cover_changed

const CACHE := "user://manual-cache"

var document_path := ""
var cover: Texture2D
var page_index := 0
var page_count := 0
var process_id := -1
var output_prefix := ""
var render_deadline := 0
var status := Label.new()
var previous := Button.new()
var next := Button.new()
var zoom := CheckButton.new()
var paper := TextureRect.new()
var page_scroll := ScrollContainer.new()

func setup(room: Node2D) -> void:
	name = "ManualViewer"
	position = Vector2(736, 193)
	size = Vector2(400, 410)
	theme = room.make_settings_theme()
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 5)
	add_child(contents)

	page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_scroll.custom_minimum_size.y = 240
	contents.add_child(page_scroll)
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_scroll.add_child(paper)

	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_color_override("font_outline_color", Color("#211a2c"))
	status.add_theme_constant_override("outline_size", 4)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 310
	contents.add_child(status)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 5)
	contents.add_child(controls)
	previous.text = "‹ Previous"
	previous.pressed.connect(func(): request_page(page_index - 2))
	controls.add_child(previous)
	next.text = "Next ›"
	next.pressed.connect(func(): request_page(page_index + 2))
	controls.add_child(next)
	zoom.text = "2×"
	zoom.tooltip_text = "Zoom in to read small print"
	zoom.toggled.connect(update_zoom)
	controls.add_child(zoom)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	controls.add_child(close)
	hide()
	set_process(false)

func set_rom(rom: String) -> void:
	stop_render()
	hide()
	document_path = find_manual(rom) if not rom.is_empty() else ""
	cover = null
	paper.texture = null
	page_index = 0
	page_count = 0
	zoom.set_pressed_no_signal(false)
	update_zoom(false)
	cover_changed.emit()
	if not document_path.is_empty():
		request_page(0)

func find_manual(rom: String) -> String:
	var stem := rom.get_file().get_basename().to_lower()
	var folder := rom.get_base_dir()
	for location in [folder.path_join("manuals"), folder]:
		if not DirAccess.dir_exists_absolute(location):
			continue
		for file in DirAccess.get_files_at(location):
			if file.get_extension().to_lower() == "pdf" and file.get_basename().to_lower() == stem:
				return location.path_join(file)
	return ""

func open_manual() -> void:
	if not document_path.is_empty():
		show()

func request_page(index: int) -> void:
	if document_path.is_empty() or index < 0 or (page_count > 0 and index >= page_count):
		return
	stop_render()
	if DirAccess.make_dir_recursive_absolute(CACHE) != OK:
		show_status("Could not create the manual cache.")
		return
	output_prefix = ProjectSettings.globalize_path(CACHE).path_join("page-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()])
	var python := LocalRuntime.python_executable()
	var script := LocalRuntime.app_path("manuals/render_page.py")
	process_id = OS.create_process(python, [script, document_path, str(index), output_prefix])
	if process_id <= 0:
		stop_render()
		show_status("Could not start Python for the manual viewer.")
		return
	page_index = index
	render_deadline = Time.get_ticks_msec() + 15000
	show_status("Opening spread…")
	set_process(true)

func _process(_delta: float) -> void:
	if OS.is_process_running(process_id):
		if Time.get_ticks_msec() >= render_deadline:
			stop_render()
			show_status("The manual took too long to open.")
		return
	var metadata_path := output_prefix + ".json"
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path)) if FileAccess.file_exists(metadata_path) else null
	var image := Image.new()
	var loaded := FileAccess.file_exists(output_prefix + ".png") and image.load(output_prefix + ".png") == OK
	stop_render()
	if not data is Dictionary or not loaded:
		show_status(str(data.get("error", "Could not open the manual.")) if data is Dictionary else "Could not open the manual.")
		return
	page_count = int(data.get("pages", 0))
	paper.texture = ImageTexture.create_from_image(image)
	if page_index == 0:
		var left_size := Vector2i(int(data.get("left_width", 0)), int(data.get("left_height", 0)))
		if left_size.x > 0 and left_size.y > 0:
			cover = ImageTexture.create_from_image(image.get_region(Rect2i(Vector2i.ZERO, left_size)))
			cover_changed.emit()
	update_zoom(zoom.button_pressed)
	page_scroll.scroll_horizontal = 0
	page_scroll.scroll_vertical = 0
	var first := page_index + 1
	var last := mini(first + 1, page_count)
	var spread := "%d–%d" % [first, last] if first != last else str(first)
	show_status("%s / %d" % [spread, page_count])

func show_status(value: String) -> void:
	status.text = value
	var busy := process_id > 0
	previous.disabled = busy or page_index <= 0
	next.disabled = busy or page_index + 2 >= page_count
	zoom.disabled = paper.texture == null

func update_zoom(enabled: bool) -> void:
	paper.custom_minimum_size = Vector2.ZERO
	if enabled and paper.texture:
		var dimensions := paper.texture.get_size()
		var viewport := page_scroll.size
		var fit := minf(viewport.x / dimensions.x, viewport.y / dimensions.y)
		paper.custom_minimum_size = dimensions * fit * 2.0

func stop_render() -> void:
	set_process(false)
	if process_id > 0 and OS.is_process_running(process_id):
		OS.kill(process_id)
	process_id = -1
	if not output_prefix.is_empty():
		for extension in [".png", ".json"]:
			var path: String = output_prefix + extension
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
	output_prefix = ""

func _exit_tree() -> void:
	stop_render()
