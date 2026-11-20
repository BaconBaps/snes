extends Node

signal failed(message: String)
signal frame_changed

var rgb565 := true

const CORE_NAMES := ["Snes9x", "bsnes Balanced"]
const CORE_FILES := ["snes9x_libretro", "bsnes_mercury_balanced_libretro"]
const AUDIO_PREROLL_SECONDS := 0.07
const HEADER_SIZE := 20
const KEYS := [KEY_Z, KEY_A, KEY_SHIFT, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_X, KEY_S, KEY_Q, KEY_W]
const GAMEPAD := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_BACK, JOY_BUTTON_START,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]

var picture: ImageTexture
var running := false

var server := TCPServer.new()
var peer: StreamPeerTCP
var nonce := PackedByteArray()
var incoming := PackedByteArray()
var authenticated := false
var deadline := 0
var process_id := -1
var sent_mask := -1
var audio := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var audio_preroll := PackedVector2Array()

func _ready() -> void:
	add_child(audio)
	set_process(false)

func start(rom: String, core_index := 0) -> String:
	if process_id > 0 and OS.is_process_running(process_id):
		return "The previous game is still closing. Try Reset in a moment."
	var directory := ProjectSettings.globalize_path("res://emulator")
	var extension := ".dll" if OS.get_name() == "Windows" else ".so"
	var core := directory.path_join(CORE_FILES[core_index] + extension)
	if not FileAccess.file_exists(core):
		return "Add %s to the emulator folder. See README." % core.get_file()
	var save_dir := ProjectSettings.globalize_path("user://saves")
	if DirAccess.make_dir_recursive_absolute(save_dir) != OK:
		return "Could not create the battery save folder."
	var save := save_dir.path_join(rom.sha256_text() + ".srm")
	if server.listen(0, "127.0.0.1") != OK:
		return "Could not open a local connection to the emulator core."
	nonce = Crypto.new().generate_random_bytes(16).hex_encode().to_ascii_buffer()
	var python := OS.get_environment("BEDROOM_ARCADE_PYTHON")
	if python.is_empty():
		python = "python" if OS.get_name() == "Windows" else "python3"
	process_id = OS.create_process(python, [directory.path_join("host.py"),
		str(server.get_local_port()), nonce.get_string_from_ascii(), core, rom, save])
	if process_id <= 0:
		server.stop()
		return "Could not start Python. See README for setup."
	running = true
	authenticated = false
	sent_mask = -1
	deadline = Time.get_ticks_msec() + 8000
	set_process(true)
	return ""

func stop() -> void:
	if peer:
		if authenticated:
			send_command(81, 0)
		peer.disconnect_from_host()
		peer = null
	server.stop()
	incoming.clear()
	picture = null
	frame_changed.emit()
	audio.stop()
	playback = null
	audio_preroll.clear()
	running = false
	set_process(false)

func reset() -> void:
	if authenticated:
		send_command(82, sent_mask if sent_mask >= 0 else 0)

func _exit_tree() -> void:
	stop()

func report_error(message: String) -> void:
	stop()
	failed.emit(message)

func _process(_delta: float) -> void:
	if not peer and server.is_connection_available():
		peer = server.take_connection()
		peer.set_no_delay(true)
	if not peer:
		if Time.get_ticks_msec() >= deadline or not OS.is_process_running(process_id):
			report_error("The emulator core did not start. Check the Python setup in README.")
		return
	peer.poll()
	var available := peer.get_available_bytes()
	if available > 0:
		var received := peer.get_data(available)
		if received[0] == OK:
			incoming.append_array(received[1])
	if not authenticated and incoming.size() >= nonce.size():
		if incoming.slice(0, nonce.size()) != nonce:
			report_error("Could not verify the local emulator connection.")
			return
		authenticated = true
		incoming = incoming.slice(nonce.size())
		server.stop()
	if not authenticated and Time.get_ticks_msec() >= deadline:
		report_error("The emulator core connection timed out.")
		return
	if authenticated:
		read_frames()
		if not running:
			return
		var mask := read_input()
		if mask != sent_mask:
			send_command(73, mask)
			sent_mask = mask
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		report_error("The emulator process stopped.")

func read_frames() -> void:
	var offset := 0
	var latest_start := -1
	var latest_end := 0
	var latest_width := 0
	var latest_height := 0
	var latest_rgb565 := true
	while incoming.size() - offset >= HEADER_SIZE:
		var kind := incoming.decode_u32(offset)
		var width := incoming.decode_u32(offset + 4)
		var height := incoming.decode_u32(offset + 8)
		var rate := incoming.decode_u32(offset + 12)
		var payload_size := incoming.decode_u32(offset + 16)
		if kind < 1 or kind > 3 or width > 1024 or height > 1024 or payload_size > 32768:
			report_error("Invalid data from the emulator core.")
			return
		var start := offset + HEADER_SIZE
		var video_end := start + width * height * 2
		var end := video_end + payload_size
		if incoming.size() < end:
			break
		if kind == 1:
			report_error(incoming.slice(start, end).get_string_from_utf8())
			return
		if width > 0 and height > 0:
			latest_start = start
			latest_end = video_end
			latest_width = width
			latest_height = height
			latest_rgb565 = kind == 2
		if rate > 0 and payload_size > 0:
			play_audio(rate, video_end, end)
		offset = end
	# Keep all audio, but upload only the newest complete video frame.
	if latest_start >= 0:
		var image := Image.create_from_data(latest_width, latest_height, false, Image.FORMAT_RG8,
			incoming.slice(latest_start, latest_end))
		if not picture or picture.get_width() != latest_width or picture.get_height() != latest_height:
			picture = ImageTexture.create_from_image(image)
		else:
			picture.update(image)
		rgb565 = latest_rgb565
		frame_changed.emit()
	if offset > 0:
		incoming = incoming.slice(offset)

func play_audio(rate: int, start: int, end: int) -> void:
	var frame_count := (end - start) >> 2
	if playback:
		frame_count = mini(frame_count, playback.get_frames_available())
	var frames := PackedVector2Array()
	frames.resize(frame_count)
	for frame in range(frame_count):
		var offset := start + frame * 4
		frames[frame] = Vector2(incoming.decode_s16(offset), incoming.decode_s16(offset + 2)) / 32768.0
	if playback:
		playback.push_buffer(frames)
		return

	# Let a few core frames arrive before the audio thread starts consuming them.
	audio_preroll.append_array(frames)
	if audio_preroll.size() < rate * AUDIO_PREROLL_SECONDS:
		return
	var generator := AudioStreamGenerator.new()
	generator.mix_rate_mode = AudioStreamGenerator.MIX_RATE_CUSTOM
	generator.mix_rate = rate
	generator.buffer_length = 0.2
	audio.stream = generator
	audio.play()
	playback = audio.get_stream_playback()
	playback.push_buffer(audio_preroll)
	audio_preroll.clear()

func read_input() -> int:
	if not get_window().has_focus():
		return 0
	var mask := 0
	var devices := Input.get_connected_joypads()
	for index in range(KEYS.size()):
		if Input.is_physical_key_pressed(KEYS[index]) or (not devices.is_empty() and Input.is_joy_button_pressed(devices[0], GAMEPAD[index])):
			mask |= 1 << index
	return mask

func send_command(command: int, mask: int) -> void:
	peer.put_data(PackedByteArray([command, mask & 255, mask >> 8]))
