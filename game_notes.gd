extends PanelContainer

var editor := TextEdit.new()
var heading := Label.new()
var status := Label.new()
var autosave := Timer.new()
var note_path := ""
var saved_text := ""
var drafts: Dictionary[String, String] = {}

func setup(room: Node2D) -> void:
	name = "GameNotes"
	position = Vector2(744, 185)
	size = Vector2(385, 410)
	theme = room.make_settings_theme()
	add_theme_stylebox_override("panel", room.settings_style("#432f43", "#b18b86", 8))
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 7)
	add_child(contents)
	room.add_settings_heading(contents, "Game Notes")
	heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	contents.add_child(heading)

	var paper: StyleBoxFlat = room.settings_style("#ead9b7", "#aa7e78", 3)
	paper.content_margin_left = 16
	editor.add_theme_stylebox_override("normal", paper)
	editor.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	editor.add_theme_color_override("font_color", Color("#3d293c"))
	editor.add_theme_color_override("font_selected_color", Color("#261f33"))
	editor.add_theme_color_override("font_placeholder_color", Color("#776879"))
	editor.add_theme_color_override("caret_color", Color("#3d293c"))
	editor.add_theme_color_override("selection_color", Color("#c5aabc"))
	editor.placeholder_text = "Write your notes here…"
	editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	editor.custom_minimum_size = Vector2(330, 270)
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.text_changed.connect(func():
		if not visible or note_path.is_empty() or (editor.text == saved_text and not drafts.has(note_path)):
			return
		drafts[note_path] = editor.text
		status.text = "Saving…"
		autosave.start())
	contents.add_child(editor)

	var toolbar := HBoxContainer.new()
	contents.add_child(toolbar)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.add_theme_font_size_override("font_size", 12)
	toolbar.add_child(status)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(func():
		if flush():
			hide())
	toolbar.add_child(close)
	autosave.one_shot = true
	autosave.wait_time = 0.55
	autosave.timeout.connect(flush)
	add_child(autosave)
	hide()

func open_rom(rom: String) -> void:
	var destination := preload("res://local_runtime.gd").notes_path(rom)
	if visible and note_path == destination:
		editor.grab_focus()
		return
	close_for_room()
	note_path = destination
	heading.text = rom.get_file().get_basename()
	heading.tooltip_text = note_path
	status.text = "Saves to restored notes" if FileAccess.file_exists(destination) and destination != rom.get_basename() + ".txt" else "Saves beside the ROM"
	editor.editable = true
	var body := ""
	if drafts.has(note_path):
		body = drafts[note_path]
	elif FileAccess.file_exists(note_path):
		var file := FileAccess.open(note_path, FileAccess.READ)
		if file == null:
			editor.editable = false
			status.text = "Could not read the notes file."
		else:
			body = file.get_as_text()
	saved_text = body
	editor.set_text(body)
	editor.clear_undo_history()
	show()
	editor.grab_focus()

func close_for_room() -> void:
	if not note_path.is_empty():
		flush()
	hide()
	note_path = ""

func flush() -> bool:
	autosave.stop()
	if visible and editor.editable and not note_path.is_empty() and editor.text != saved_text:
		drafts[note_path] = editor.text
	if not drafts.has(note_path):
		return true
	var temporary := "%s.%d.%d.tmp" % [note_path, OS.get_process_id(), Time.get_ticks_usec()]
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		status.text = "Could not save the notes."
		return false
	file.store_string(drafts[note_path])
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temporary, note_path) != OK:
		DirAccess.remove_absolute(temporary)
		status.text = "Could not save the notes."
		return false
	saved_text = drafts[note_path]
	drafts.erase(note_path)
	status.text = "Notes saved"
	return true
