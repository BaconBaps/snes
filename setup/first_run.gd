extends Window

const TITLES := ["Welcome", "Gamepad controls", "ROM folders", "Cartridge art folders", "Manual folders"]
const DESCRIPTIONS := [
	"Set up your SNES and Mega Drive libraries. You can add either console now and come back to Settings → Setup wizard later.",
	"L2 picks up and drops items. R2 clicks room controls or puts back an item you’re holding. You can also use your mouse.",
	"Leave a console’s folder blank to play its included homebrew. SNES folders accept .sfc and .smc. Mega Drive folders accept .md, .gen, .bin and .smd.",
	"Name each PNG or JPG exactly like its ROM, including any region tags. For example, Sonic (USA).md matches Sonic (USA).png. You can also keep art beside the ROM.",
	"Match PDF and ROM filenames too. For example, Sonic (USA).pdf matches Sonic (USA).md. PDFs can also sit beside the ROM or in its manuals subfolder.",
]

var room: Node2D
var page := 0
var folders: Array[PackedStringArray] = []
var content := VBoxContainer.new()
var heading := Label.new()
var description := Label.new()
var back := Button.new()
var next := Button.new()
var picker := FileDialog.new()
var folder_paths: Array[Label] = []
var chosen_console := 0

func setup(parent_room: Node2D) -> void:
	room = parent_room
	name = "FirstRunWizard"
	title = "Bedroom Gaming Emulator"
	visible = false
	transient = true
	exclusive = true
	unresizable = true
	close_requested.connect(hide)
	theme = room.make_settings_theme()
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", room.settings_style("#251d30", "#6e5469", 0))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 13)
	panel.add_child(layout)

	heading.add_theme_font_size_override("font_size", 27)
	layout.add_child(heading)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(description)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	layout.add_child(content)

	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 8)
	layout.add_child(navigation)
	var skip := Button.new()
	skip.text = "Skip setup"
	skip.pressed.connect(func(): complete(false))
	navigation.add_child(skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(spacer)
	back.text = "Back"
	back.pressed.connect(func():
		page -= 1
		render_page())
	navigation.add_child(back)
	next.pressed.connect(func():
		if page == TITLES.size() - 1:
			complete(true)
		else:
			page += 1
			render_page())
	navigation.add_child(next)

	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.transient = true
	picker.exclusive = true
	picker.dir_selected.connect(func(path: String):
		var kind := page - 2
		folders[kind][chosen_console] = path
		update_folder_paths())
	add_child(picker)

func open() -> void:
	folders = [
		PackedStringArray([room.library_folder(false), room.library_folder(true)]),
		PackedStringArray([room.library_folder(false, true), room.library_folder(true, true)]),
		room.manual_folders.duplicate(),
	]
	page = 0
	render_page()
	popup_centered(Vector2i(744, 488))

func complete(apply_folders: bool) -> void:
	room.finish_setup(folders, apply_folders)
	hide()

func render_page() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	folder_paths.clear()
	heading.text = TITLES[page]
	description.text = DESCRIPTIONS[page]
	back.disabled = page == 0
	next.text = "Finish" if page == TITLES.size() - 1 else "Next  ›"
	match page:
		0:
			var sample := Label.new()
			sample.text = "Choose a TV input to switch consoles. Drag a cartridge into the slot to start a game. Press F11 to enter or leave fullscreen."
			sample.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			content.add_child(sample)
		1:
			show_controls()
		_:
			for index in range(2):
				add_folder_row(index)
			update_folder_paths()

func show_controls() -> void:
	var diagram := TextureRect.new()
	diagram.texture = preload("res://setup/gamepad.svg")
	diagram.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	diagram.custom_minimum_size = Vector2(680, 224)
	diagram.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	diagram.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(diagram)
	for entry in [
		[Vector2(9, 16), "L2  Pick up / drop\nL1  SNES L / MD X"],
		[Vector2(9, 88), "D-pad\nMove in game"],
		[Vector2(9, 153), "Either stick\nMove room pointer"],
		[Vector2(551, 16), "R2  Click / cancel\nR1  SNES R / MD Z"],
		[Vector2(551, 88), "Face buttons\nGame actions"],
		[Vector2(551, 153), "Start / Select\nStart / Mode on MD"],
	]:
		var callout := Label.new()
		callout.position = entry[0]
		callout.text = entry[1]
		callout.add_theme_font_size_override("font_size", 13)
		diagram.add_child(callout)
	var mapping := Label.new()
	mapping.text = "Face buttons  □  ×  ○  △\nSNES  Y  B  A  X     ·     Mega Drive  A  B  C  Y"
	mapping.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(mapping)

func add_folder_row(index: int) -> void:
	var console_name := "SNES" if index == 0 else "Mega Drive"
	var title_label := Label.new()
	title_label.text = console_name
	content.add_child(title_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var path := Label.new()
	path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(path)
	folder_paths.append(path)
	var choose := Button.new()
	choose.text = "Choose folder…"
	choose.pressed.connect(func():
		chosen_console = index
		picker.title = "%s · %s" % [console_name, TITLES[page]]
		var current := folders[page - 2][index]
		if not current.is_empty():
			picker.current_dir = current
		picker.popup_centered(Vector2i(620, 350)))
	row.add_child(choose)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(func():
		folders[page - 2][index] = ""
		update_folder_paths())
	row.add_child(clear)

func update_folder_paths() -> void:
	for index in range(2):
		var path := folders[page - 2][index]
		folder_paths[index].text = "No folder selected" if path.is_empty() else path
		folder_paths[index].tooltip_text = path
