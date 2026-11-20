extends Node

signal failed(message: String)
signal frame_changed

var rgb565 := true

const CORE_NAMES := ["Snes9x", "bsnes Balanced"]
const CORE_FILES := ["snes9x_libretro", "bsnes_mercury_balanced_libretro"]
const AUDIO_PREROLL_SECONDS := 0.07
const HEADER_SIZE := 20
const MAX_READ_PER_TICK := 2 * 1024 * 1024
const READ_CHUNK := 256 * 1024
const KEYS := [KEY_Z, KEY_A, KEY_SHIFT, KEY_ENTER, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_X, KEY_S, KEY_Q, KEY_W]
const GAMEPAD := [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_BACK, JOY_BUTTON_START,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_B, JOY_BUTTON_Y, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]

var picture: ImageTexture
var screen_light := Color.BLACK
var light_sample_at := 0
var running := false

var server := TCPServer.new()
var peer: StreamPeerTCP
var nonce := PackedByteArray()
var incoming := PackedByteArray()
var authenticated := false
var deadline := 0
var process_id := -1
var sent_mask := -1
var sent_second_mask := -1
var player_two_connected := false
var audio := AudioStreamPlayer.new()
var playback: AudioStreamGeneratorPlayback
var audio_preroll := PackedVector2Array()
var received_frames := 0
var displayed_frames := 0
var stats := ""
var frame_stats_started := 0
var previous_audio_skips := 0
var core_stats := Vector4.ZERO

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
	sent_second_mask = -1
	received_frames = 0
	displayed_frames = 0
	previous_audio_skips = 0
	core_stats = Vector4.ZERO
	stats = ""
	frame_stats_started = Time.get_ticks_msec()
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
	screen_light = Color.BLACK
	light_sample_at = 0
	frame_changed.emit()
	audio.stop()
	playback = null
	audio_preroll.clear()
	running = false
	set_process(false)

func reset() -> void:
	if authenticated:
		send_command(82, 0)

func set_player_two(connected: bool) -> void:
	player_two_connected = connected
	sent_second_mask = -1
	if running and authenticated:
		send_command(80, int(connected))

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
	# A single availability snapshot can leave part of a frame behind until the next tick.
	var budget := MAX_READ_PER_TICK
	while budget > 0 and peer.get_available_bytes() > 0:
		var received := peer.get_partial_data(mini(READ_CHUNK, budget))
		var chunk: PackedByteArray = received[1]
		if received[0] != OK or chunk.is_empty():
			break
		incoming.append_array(chunk)
		budget -= chunk.size()
	if not authenticated and incoming.size() >= nonce.size():
		if incoming.slice(0, nonce.size()) != nonce:
			report_error("Could not verify the local emulator connection.")
			return
		authenticated = true
		incoming = incoming.slice(nonce.size())
		server.stop()
		send_command(80, int(player_two_connected))
	if not authenticated and Time.get_ticks_msec() >= deadline:
		report_error("The emulator core connection timed out.")
		return
	if authenticated:
		read_frames()
		if not running:
			return
		update_stats()
		send_inputs()
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
		if kind == 4:
			core_stats = Vector4(width, height, rate, payload_size) / 1000.0
			offset += HEADER_SIZE
			continue
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
		received_frames += 1
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
		var now := Time.get_ticks_msec()
		if now >= light_sample_at:
			sample_screen_light(latest_start, latest_width, latest_height, latest_rgb565)
			light_sample_at = now + 33
		var image := Image.create_from_data(latest_width, latest_height, false, Image.FORMAT_RG8,
			incoming.slice(latest_start, latest_end))
		if not picture or picture.get_width() != latest_width or picture.get_height() != latest_height:
			picture = ImageTexture.create_from_image(image)
		else:
			picture.update(image)
		displayed_frames += 1
		rgb565 = latest_rgb565
		frame_changed.emit()
	if offset > 0:
		incoming = incoming.slice(offset)

func sample_screen_light(start: int, width: int, height: int, is_rgb565: bool) -> void:
	# Read a sparse set of pixels from the received frame, without a GPU readback.
	var sum := Vector3.ZERO
	var green_bits := 6 if is_rgb565 else 5
	var green_mask := (1 << green_bits) - 1
	for row in range(1, 8):
		for column in range(1, 10):
			var offset := start + (floori(row * height / 8.0) * width + floori(column * width / 10.0)) * 2
			var pixel := incoming.decode_u16(offset)
			sum += Vector3(float((pixel >> (green_bits + 5)) & 31) / 31.0,
				float((pixel >> 5) & green_mask) / green_mask, float(pixel & 31) / 31.0)
	screen_light = Color(sum.x / 63.0, sum.y / 63.0, sum.z / 63.0)

func update_stats() -> void:
	var now := Time.get_ticks_msec()
	var elapsed := (now - frame_stats_started) / 1000.0
	if elapsed < 1.0:
		return
	var skips := playback.get_skips() if playback else 0
	stats = "Core %.1f / %.1f fps   |   Received %.1f   |   CRT %.1f   |   Godot %d fps\n" % [
		core_stats.y, core_stats.x, received_frames / elapsed, displayed_frames / elapsed, Engine.get_frames_per_second()]
	stats += "Core %.2f ms   |   Socket send %.2f ms   |   Audio underruns %d" % [
		core_stats.z, core_stats.w, skips - previous_audio_skips]
	received_frames = 0
	displayed_frames = 0
	previous_audio_skips = skips
	frame_stats_started = now

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

func send_inputs() -> void:
	var devices := Input.get_connected_joypads()
	var focused := get_window().has_focus()
	var first := read_input(devices[0] if not devices.is_empty() else -1, true) if focused else 0
	if first != sent_mask:
		send_command(73, first)
		sent_mask = first
	if player_two_connected:
		var second := read_input(devices[1], false) if focused and devices.size() > 1 else 0
		if second != sent_second_mask:
			send_command(74, second)
			sent_second_mask = second

func read_input(device: int, keyboard: bool) -> int:
	var mask := 0
	for index in range(KEYS.size()):
		if (keyboard and Input.is_physical_key_pressed(KEYS[index])) or (device >= 0 and Input.is_joy_button_pressed(device, GAMEPAD[index])):
			mask |= 1 << index
	return mask

func send_command(command: int, mask: int) -> void:
	peer.put_data(PackedByteArray([command, mask & 255, mask >> 8]))
