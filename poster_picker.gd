extends FileDialog

const PREVIEW_SIZE := 104
const IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]
const PREVIEW_FILE_LIMIT := 24 * 1024 * 1024

var queue: Dictionary[String, ImageTexture] = {}
var previews: Dictionary[String, ImageTexture] = {}
var job: Dictionary = {}
var preview_directory := ""
var task_id := -1
var placeholder: Image

func _ready() -> void:
	access = FileDialog.ACCESS_FILESYSTEM
	file_mode = FileDialog.FILE_MODE_OPEN_FILE
	title = "Choose poster artwork"
	filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Images"])
	use_native_dialog = false
	display_mode = FileDialog.DISPLAY_THUMBNAILS
	var gallery_theme := Theme.new()
	gallery_theme.set_constant("thumbnail_size", "FileDialog", PREVIEW_SIZE)
	theme = gallery_theme
	placeholder = Image.create_empty(48, 64, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color("#58485d"))
	visibility_changed.connect(func():
		if not visible:
			FileDialog.set_get_thumbnail_callback(Callable())
			queue.clear()
			previews.clear()
			preview_directory = "")
	set_process(false)

func open_for_poster() -> void:
	FileDialog.set_get_thumbnail_callback(request_thumbnail)
	popup_centered_ratio(0.78)
	invalidate()

func request_thumbnail(path: String) -> Texture2D:
	if path.get_extension().to_lower() not in IMAGE_EXTENSIONS:
		return null
	var directory := path.get_base_dir().simplify_path()
	if directory != preview_directory:
		queue.clear()
		previews.clear()
		preview_directory = directory
	if previews.has(path):
		if queue.has(path):
			set_process(true)
		return previews[path]
	var texture := ImageTexture.create_from_image(placeholder)
	previews[path] = texture
	queue[path] = texture
	set_process(true)
	return texture

func _process(_delta: float) -> void:
	if task_id >= 0:
		if not WorkerThreadPool.is_task_completed(task_id):
			return
		WorkerThreadPool.wait_for_task_completion(task_id)
		task_id = -1
		var path: String = job.path
		if job.image and previews.get(path) == job.texture:
			var texture: ImageTexture = job.texture
			texture.set_image(job.image)
		job.clear()
	if not visible or display_mode != DISPLAY_THUMBNAILS:
		set_process(false)
		return
	while not queue.is_empty():
		var path: String = queue.keys()[0]
		var texture: ImageTexture = queue[path]
		queue.erase(path)
		if path.get_base_dir().simplify_path() != current_dir.simplify_path():
			previews.erase(path)
			continue
		job = {"path": path, "texture": texture, "image": null}
		task_id = WorkerThreadPool.add_task(load_thumbnail.bind(path, job))
		return
	set_process(false)

static func load_thumbnail(path: String, result: Dictionary) -> void:
	var length := FileAccess.get_size(path)
	if length <= 0 or length > PREVIEW_FILE_LIMIT:
		return
	var image := Image.new()
	if image.load(path) != OK or image.is_empty():
		return
	var scale := minf(1.0, float(PREVIEW_SIZE) / maxi(image.get_width(), image.get_height()))
	image.resize(maxi(1, roundi(image.get_width() * scale)),
		maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
	result.image = image

func _exit_tree() -> void:
	if visible:
		FileDialog.set_get_thumbnail_callback(Callable())
	if task_id >= 0:
		WorkerThreadPool.wait_for_task_completion(task_id)
