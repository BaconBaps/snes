extends PanelContainer

const LocalRuntime := preload("res://local_runtime.gd")

signal cover_changed

const CACHE := "user://manual-cache"

var document_path := ""
var extra_folder := ""
var cover: Texture2D
var page_index := 0
var page_count := 0
var last_page_on_spread := 0
var process_id := -1
var output_prefix := ""
var render_deadline := 0
var status := Label.new()
var previous := Button.new()
var next := Button.new()
var zoom := CheckButton.new()
var paper := TextureRect.new()
var booklet_material := ShaderMaterial.new()
var page_turn: Tween
var previous_page_index := 0
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
	booklet_material.shader = preload("res://manuals/booklet.gdshader")
	paper.material = booklet_material
	paper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	paper.mouse_filter = Control.MOUSE_FILTER_PASS
	paper.gui_input.connect(turn_at_page)
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
	previous.pressed.connect(func(): request_page(previous_spread()))
	controls.add_child(previous)
	next.text = "Next ›"
	next.pressed.connect(func(): request_page(last_page_on_spread + 1))
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

func turn_at_page(event: InputEvent) -> void:
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	accept_event()
	if not paper.texture or process_id > 0 or page_turn:
		return
	var image_size := paper.texture.get_size()
	var fit := minf(paper.size.x / image_size.x, paper.size.y / image_size.y)
	var displayed_size := image_size * fit
	var spread := Rect2((paper.size - displayed_size) * 0.5, displayed_size)
	if not spread.has_point(event.position):
		return
	if event.position.x < spread.get_center().x:
		if not previous.disabled:
			request_page(previous_spread())
	elif not next.disabled:
		request_page(last_page_on_spread + 1)

func set_rom(rom: String) -> void:
	stop_render()
	finish_turn()
	hide()
	document_path = find_manual(rom) if not rom.is_empty() else ""
	cover = null
	paper.texture = null
	page_index = 0
	page_count = 0
	last_page_on_spread = 0
	zoom.set_pressed_no_signal(false)
	update_zoom(false)
	cover_changed.emit()
	if not document_path.is_empty():
		request_page(0)

func find_manual(rom: String) -> String:
	var stem := rom.get_file().get_basename().to_lower()
	var folder := rom.get_base_dir()
	for location in [extra_folder, folder.path_join("manuals"), folder]:
		if location.is_empty() or not DirAccess.dir_exists_absolute(location):
			continue
		for file in DirAccess.get_files_at(location):
			if file.get_extension().to_lower() == "pdf" and file.get_basename().to_lower() == stem:
				return location.path_join(file)
	var cached := LocalRuntime.media_directory(rom).path_join("manual.pdf")
	return cached if FileAccess.file_exists(cached) else ""

func open_manual() -> void:
	if not document_path.is_empty():
		show()

func previous_spread() -> int:
	if page_index == page_count - 1 and page_index > 0 and page_index % 2 == 0:
		return page_index - 1
	return maxi(0, page_index - 2)

func request_page(index: int) -> void:
	if page_turn or document_path.is_empty() or index < 0 or (page_count > 0 and index >= page_count):
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
	previous_page_index = page_index
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
	last_page_on_spread = int(data.get("last_index", page_index))
	var old_spread := paper.texture
	paper.texture = ImageTexture.create_from_image(image)
	booklet_material.set_shader_parameter("bound_spread", last_page_on_spread != page_index)
	if visible and old_spread and previous_page_index != page_index:
		animate_turn(old_spread, page_index > previous_page_index)
	if page_index == 0 and cover == null:
		var cover_size := Vector2i(int(data.get("first_width", 0)), int(data.get("first_height", 0)))
		var cover_origin := Vector2i(int(data.get("first_x", 0)), 0)
		if cover_size.x > 0 and cover_size.y > 0:
			cover = ImageTexture.create_from_image(image.get_region(Rect2i(cover_origin, cover_size)))
			cover_changed.emit()
	update_zoom(zoom.button_pressed)
	page_scroll.scroll_horizontal = 0
	page_scroll.scroll_vertical = 0
	var first := page_index + 1
	var last := last_page_on_spread + 1
	var spread := "%d–%d" % [first, last] if first != last else str(first)
	show_status("%s / %d" % [spread, page_count])

func animate_turn(old_spread: Texture2D, forward: bool) -> void:
	booklet_material.set_shader_parameter("previous_spread", old_spread)
	booklet_material.set_shader_parameter("turn_forward", forward)
	booklet_material.set_shader_parameter("turn_progress", 0.0)
	page_turn = create_tween()
	page_turn.tween_method(func(amount: float):
		booklet_material.set_shader_parameter("turn_progress", amount), 0.0, 1.0, 0.38
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	page_turn.finished.connect(func():
		finish_turn()
		show_status(status.text))

func finish_turn() -> void:
	if page_turn and page_turn.is_running():
		page_turn.kill()
	page_turn = null
	booklet_material.set_shader_parameter("turn_progress", 1.0)
	booklet_material.set_shader_parameter("previous_spread", null)

func show_status(value: String) -> void:
	status.text = value
	var busy := process_id > 0 or page_turn != null
	previous.disabled = busy or page_index <= 0
	next.disabled = busy or last_page_on_spread + 1 >= page_count
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
