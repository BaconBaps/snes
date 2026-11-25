extends PopupPanel

const LocalRuntime := preload("res://local_runtime.gd")
const ManualViewer := preload("res://manuals/manual_viewer.gd")

var room: Node2D
var picker := FileDialog.new()
var confirm := ConfirmationDialog.new()
var result := AcceptDialog.new()
var status := Label.new()
var worker := Thread.new()
var restore_path := ""
var busy := false

func setup(owner_room: Node2D) -> void:
	room = owner_room
	name = "BackupDialog"
	theme = room.make_settings_theme()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 17)
	room.add_settings_heading(layout, "Backup and restore")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "Save settings, cartridge lists, saved games, notes, artwork and manuals to a ZIP. Keep your ROMs separately. Eject running cartridges first to include their latest battery saves."
	layout.add_child(status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	layout.add_child(buttons)
	for action in ["Create backup…", "Restore backup…"]:
		var button := Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(open_picker.bind(action == "Restore backup…"))
		buttons.add_child(button)

	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.filters = PackedStringArray(["*.zip ; Backup ZIP"])
	picker.file_selected.connect(choose_archive)
	room.add_child(picker)
	confirm.title = "Restore backup"
	confirm.ok_button_text = "Restore"
	confirm.dialog_text = "Replace the app’s current settings, saves and backed-up media? Open games will close. ROM files and folders stay in place."
	confirm.confirmed.connect(func(): run_operation("restore", restore_path))
	room.add_child(confirm)
	result.title = "Backup and restore"
	result.transient = true
	result.exclusive = true
	result.close_requested.connect(func():
		if busy:
			result.popup_centered.call_deferred(Vector2i(465, 140)))
	room.add_child(result)

func open_picker(restoring: bool) -> void:
	hide()
	picker.title = "Restore backup" if restoring else "Create backup"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE if restoring else FileDialog.FILE_MODE_SAVE_FILE
	picker.current_file = "" if restoring else "Bedroom-Gaming-Emulator-backup.zip"
	picker.popup_centered_ratio(0.8)

func choose_archive(path: String) -> void:
	if picker.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		restore_path = path
		confirm.popup_centered()
	else:
		run_operation("backup", path)

func run_operation(operation: String, path: String) -> void:
	if busy:
		return
	if not room.game_notes.flush():
		show_result("The current game notes could not be saved.")
		return
	busy = true
	var restoring := operation == "restore"
	var arguments := [LocalRuntime.app_path("setup/backup_state.py"), operation,
		ProjectSettings.globalize_path("user://"), path]
	var manifest := ""
	if restoring:
		room.game_notes.close_for_room()
		room.reset_lift()
		for bridge in room.console_emulators:
			bridge.stop()
		room.powered = false
		var deadline := Time.get_ticks_msec() + 4000
		for bridge in room.console_emulators:
			while bridge.process_id > 0 and OS.is_process_running(bridge.process_id):
				if Time.get_ticks_msec() >= deadline:
					busy = false
					show_result("An emulator is still closing. Try restoring again in a moment.")
					return
				await get_tree().process_frame
	else:
		room.save_preferences()
		manifest = ProjectSettings.globalize_path("user://backup-index-%d.json" % OS.get_process_id())
		var file := FileAccess.open(manifest, FileAccess.WRITE)
		if file == null or not file.store_string(JSON.stringify(collect_library())):
			busy = false
			show_result("Could not prepare the backup.")
			return
		file.close()
		arguments.append(manifest)
	show_result("Restoring backup…" if restoring else "Creating backup…")
	result.get_ok_button().disabled = true
	result.dialog_close_on_escape = false
	var error := worker.start(execute.bind(LocalRuntime.python_executable(), arguments))
	if error != OK:
		result.get_ok_button().disabled = false
		show_result("Could not start the backup operation.")
	else:
		while worker.is_alive():
			await get_tree().process_frame
		var output: Array = worker.wait_to_finish()
		result.get_ok_button().disabled = false
		if not output[0]:
			show_result("Backup restored. Select OK to close the app, then reopen it." if restoring else "Backup saved.")
			if restoring:
				result.confirmed.connect(get_tree().quit, CONNECT_ONE_SHOT)
				result.close_requested.connect(get_tree().quit, CONNECT_ONE_SHOT)
		else:
			var detail := str(output[1][0]).strip_edges() if not output[1].is_empty() else "Check that Python is available and the ZIP location is accessible."
			show_result(detail)
	if not manifest.is_empty():
		DirAccess.remove_absolute(manifest)
	busy = false
	result.dialog_close_on_escape = true

func _exit_tree() -> void:
	if worker.is_started():
		worker.wait_to_finish()

static func execute(python: String, arguments: PackedStringArray) -> Array:
	var output := []
	var code := OS.execute(python, arguments, output, true)
	return [code, output]

func show_result(message: String) -> void:
	result.dialog_text = message
	result.popup_centered(Vector2i(465, 140))

func collect_library() -> Dictionary:
	var media := {}
	var roms := {}
	for index in range(2):
		var mega := index == 1
		var folder: String = room.library_folder(mega)
		var is_starter := folder.is_empty()
		var files: PackedStringArray
		if is_starter:
			files = PackedStringArray(room.STARTER_ROMS[index])
			folder = ProjectSettings.globalize_path("user://starter/" + ("megadrive" if mega else "snes"))
		elif DirAccess.dir_exists_absolute(folder):
			files = DirAccess.get_files_at(folder)
		var labels: Dictionary = room.index_label_images(room.library_folder(mega, true))
		var sidecars: Dictionary = room.index_label_images(folder)
		var extensions: Array = room.MD_EXTENSIONS if mega else room.SNES_EXTENSIONS
		var paths := PackedStringArray()
		for file in files:
			var extension := file.get_extension().to_lower()
			if extension != "zip" and extension not in extensions:
				continue
			var rom := folder.path_join(file)
			paths.append(rom)
			var key := "restored-media/" + rom.sha256_text() + "/"
			var title := file.get_basename().to_lower()
			var label: String = labels.get(title, sidecars.get(title, ""))
			if not label.is_empty():
				media[key + "label." + label.get_extension().to_lower()] = label
			var pdf := ManualViewer.manual_path(rom, room.manual_folders[index])
			if not pdf.is_empty():
				media[key + "manual.pdf"] = pdf
			var note := LocalRuntime.notes_path(rom)
			if FileAccess.file_exists(note):
				media[key + "notes.txt"] = note
		roms["megadrive" if mega else "snes"] = paths
	return {"roms": roms, "media": media}
