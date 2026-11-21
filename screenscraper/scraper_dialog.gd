extends PopupPanel

const LocalRuntime := preload("res://local_runtime.gd")
const FIELDS := {
	"ssid": "ScreenScraper username",
	"sspassword": "ScreenScraper password",
	"devid": "Developer ID",
	"devpassword": "Developer password",
}

var room: Node2D
var entries: Dictionary[String, LineEdit] = {}
var status := Label.new()
var start_button := Button.new()
var cancel_button := Button.new()
var pipe: Dictionary
var status_path := ""
var process_id := -1
var poll_elapsed := 0.0

func setup(parent_room: Node2D) -> void:
	room = parent_room
	name = "ScreenScraper"
	theme = room.make_settings_theme()
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 7)
	add_child(contents)
	contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 17)
	room.add_settings_heading(contents, "ScreenScraper")
	var info := Label.new()
	info.text = "Fill in missing cartridge art and PDF manuals for your ROM folder. Credentials are kept for this session only."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(info)
	for field in FIELDS:
		var entry := LineEdit.new()
		entry.placeholder_text = FIELDS[field]
		entry.secret = field.ends_with("password")
		entries[field] = entry
		contents.add_child(entry)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	contents.add_child(status)
	var buttons := HBoxContainer.new()
	contents.add_child(buttons)
	start_button.text = "Download missing media"
	start_button.pressed.connect(start)
	buttons.add_child(start_button)
	cancel_button.text = "Cancel download"
	cancel_button.disabled = true
	cancel_button.pressed.connect(func(): finish("Download cancelled. Saved media is ready to use."))
	buttons.add_child(cancel_button)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	buttons.add_child(close)
	set_process(false)

func open() -> void:
	if process_id < 0 and status.text.is_empty():
		status.text = "%d games in the selected ROM folder." % room.rom_paths.size()
	start_button.disabled = process_id > 0 or room.rom_paths.is_empty()
	popup_centered(Vector2i(422, 339))

func start() -> void:
	var credentials := {}
	for field in entries:
		var value := entries[field].text
		if value.strip_edges().is_empty():
			status.text = "Enter your account and developer credentials."
			return
		credentials[field] = value
	var jobs: Array[Dictionary] = []
	for index in room.rom_paths.size():
		var rom: String = room.rom_paths[index]
		var title: String = room.titles[index].to_lower()
		var get_label: bool = not (room.art_paths.has(title) or room.sidecar_paths.has(title)) and LocalRuntime.scraped_label(rom).is_empty()
		var get_manual: bool = room.manual.find_manual(rom).is_empty()
		if get_label or get_manual:
			jobs.append({"rom": rom, "directory": LocalRuntime.media_directory(rom), "label": get_label, "manual": get_manual})
	if jobs.is_empty():
		status.text = "All games already have cartridge art and a manual."
		return
	var cache := ProjectSettings.globalize_path("user://screenscraper")
	if DirAccess.make_dir_recursive_absolute(cache) != OK:
		status.text = "Could not create the ScreenScraper cache."
		return
	status_path = cache.path_join("progress-%d-%d.json" % [OS.get_process_id(), Time.get_ticks_usec()])
	var manifest := FileAccess.open(status_path + ".jobs", FileAccess.WRITE)
	if manifest == null:
		finish("Could not prepare the ROM list.")
		return
	manifest.store_string(JSON.stringify(jobs))
	var error := manifest.get_error()
	manifest.close()
	if error != OK:
		finish("Could not prepare the ROM list.")
		return
	pipe = OS.execute_with_pipe(LocalRuntime.python_executable(),
		["-u", LocalRuntime.app_path("screenscraper/fetch_media.py"), status_path], false)
	if pipe.is_empty():
		finish("Could not start the ScreenScraper downloader.")
		return
	process_id = int(pipe["pid"])
	var stdio: FileAccess = pipe["stdio"]
	stdio.store_line(JSON.stringify(credentials))
	if stdio.get_error() != OK:
		finish("Could not send the ROM list to the downloader.")
		return
	status.text = "Connecting to ScreenScraper…"
	start_button.disabled = true
	cancel_button.disabled = false
	set_process(true)

func _process(delta: float) -> void:
	poll_elapsed += delta
	if poll_elapsed < 0.2:
		return
	poll_elapsed = 0.0
	var running := OS.is_process_running(process_id)
	if FileAccess.file_exists(status_path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(status_path))
		if data is Dictionary:
			status.text = data.get("message", "")
			if data.get("done", false):
				finish(status.text)
				return
	if not running:
		finish("The ScreenScraper downloader closed unexpectedly.")

func finish(message: String) -> void:
	stop_worker()
	status.text = message
	start_button.disabled = room.rom_paths.is_empty()
	cancel_button.disabled = true
	room.refresh_label_art()
	if room.inserted >= 0 and room.inserted < room.rom_paths.size() and room.manual.document_path.is_empty():
		var rom: String = room.rom_paths[room.inserted]
		if not room.manual.find_manual(rom).is_empty():
			room.manual.set_rom(rom)
	room.queue_redraw()

func stop_worker() -> void:
	var old_process := process_id
	if old_process > 0 and OS.is_process_running(old_process):
		OS.kill(old_process)
	process_id = -1
	pipe.clear()
	set_process(false)
	if not status_path.is_empty():
		DirAccess.remove_absolute(status_path)
		DirAccess.remove_absolute("%s.%d.tmp" % [status_path, old_process])
		DirAccess.remove_absolute(status_path + ".jobs")
		status_path = ""

func _exit_tree() -> void:
	stop_worker()
