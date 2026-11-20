extends SubViewport
## Fixed-camera models aligned to Bedroom Arcade's existing pointer coordinates.

const PIXELS_PER_UNIT := 100.0
const SIZE := Vector2i(1152, 607)

var stage := Node3D.new()
var ceiling := OmniLight3D.new()
var screen_light := OmniLight3D.new()
var glass := ShaderMaterial.new()
var cartridge_model := Node3D.new()
var cartridge_back: MeshInstance3D
var cartridge_art := Sprite3D.new()
var cartridge_title := Label3D.new()
var power_material := StandardMaterial3D.new()
var last_cartridge_height := 0.0
var last_screen_options: Array = []

func build(screen: Rect2, slot: Rect2, reset: Rect2, eject: Rect2) -> void:
	size = SIZE
	transparent_bg = true
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	own_world_3d = true
	add_child(stage)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size.y / PIXELS_PER_UNIT
	camera.position.z = 12.0
	stage.add_child(camera)
	camera.current = true

	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#c4b0df")
	environment.ambient_light_energy = 0.48
	var world := WorldEnvironment.new()
	world.environment = environment
	stage.add_child(world)

	ceiling.position = world_point(Vector2(860, 15), 4.6)
	ceiling.light_color = Color("#ffd0a6")
	ceiling.light_energy = 2.1
	ceiling.omni_range = 11.0
	stage.add_child(ceiling)
	screen_light.position = world_point(Vector2(410, 419), 2.7)
	screen_light.omni_range = 3.8
	stage.add_child(screen_light)

	# A tapered rear housing and a square face keep the CRT readable at this angle.
	box(Rect2(148, 12, 548, 411), -0.45, 1.45, "#3b334b")
	surface([Vector2(124, 28), Vector2(150, 12), Vector2(696, 12), Vector2(713, 28)],
		[0.52, -0.6, -0.6, 0.52], "#69617a")
	box(Rect2(123, 28, 590, 405), 0.39, 0.26, "#554b65")
	box(screen.grow(8), 0.54, 0.08, "#262333")
	var picture := QuadMesh.new()
	picture.size = screen.size / PIXELS_PER_UNIT
	var image := MeshInstance3D.new()
	image.mesh = picture
	image.position = world_point(screen.get_center(), 0.594)
	glass.shader = preload("res://prototype_3d/glass.gdshader")
	image.material_override = glass
	stage.add_child(image)
	for x in range(653, 696, 6):
		box(Rect2(x, 87, 2, 174), 0.54, 0.035, "#252031")
	box(Rect2(656, 325, 40, 31), 0.55, 0.06, "#372d45")
	box(Rect2(665, 333, 20, 14), 0.59, 0.05, "#8a7d93")

	for x in [164, 644]:
		box(Rect2(x, 430, 29, 10), 0.43, 0.37, "#242030")
	for x in [139, 679]:
		box(Rect2(x, 447, 24, 89), 0.33, 0.60, "#49313e")
	box(Rect2(159, 505, 524, 14), 0.33, 0.48, "#593949")
	surface([Vector2(116, 445), Vector2(145, 428), Vector2(699, 428), Vector2(723, 445)],
		[0.92, -0.5, -0.5, 0.92], "#754e60")
	box(Rect2(116, 441, 607, 15), 0.82, 0.22, "#81566a")

	# Actual 3D panels, with projected anchors matching the current hit regions.
	box(Rect2(274, 549, 283, 52), 1.56, 0.55, "#a69a99")
	surface([Vector2(274, 549), Vector2(310, 425), Vector2(521, 425), Vector2(557, 549)],
		[1.87, 0.86, 0.86, 1.87], "#bdb0ad")
	surface([Vector2(300, 541), Vector2(325, 438), Vector2(506, 438), Vector2(532, 541)],
		[1.90, 0.99, 0.99, 1.90], "#8d8798")
	box(slot.grow(3), 1.64, 0.12, "#56505e")
	box(slot, 1.72, 0.10, "#272330")
	button(Rect2(reset.position.x - 149, reset.position.y, reset.size.x, reset.size.y), "POWER", "#5c576a")
	button(eject, "EJECT", "#9b96a5")
	button(reset, "RESET", "#605a70")
	box(Rect2(344, 578, 139, 19), 1.87, 0.16, "#766b76")
	for x in [355, 440]:
		box(Rect2(x, 580, 35, 13), 1.97, 0.05, "#302a3b")
	var led := box(Rect2(492, 559, 16, 6), 1.86, 0.07, "#401e31")
	led.material_override = power_material

	stage.add_child(cartridge_model)
	cartridge_model.hide()
	cartridge_back = MeshInstance3D.new()
	cartridge_back.mesh = BoxMesh.new()
	var shell := StandardMaterial3D.new()
	shell.albedo_color = Color("#c7bec7")
	cartridge_back.material_override = shell
	cartridge_model.add_child(cartridge_back)
	cartridge_art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	cartridge_art.position = Vector3(0, 0, 0.093)
	cartridge_model.add_child(cartridge_art)
	cartridge_title.font_size = 24
	cartridge_title.pixel_size = 0.0042
	cartridge_title.outline_size = 4
	cartridge_title.modulate = Color("#fff0cc")
	cartridge_title.position = Vector3(0, -0.25, 0.10)
	cartridge_model.add_child(cartridge_title)

func world_point(pixel: Vector2, depth: float) -> Vector3:
	return Vector3(pixel.x - SIZE.x / 2.0, SIZE.y / 2.0 - pixel.y, depth * PIXELS_PER_UNIT) / PIXELS_PER_UNIT

func box(rect: Rect2, depth: float, thickness: float, color: String) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(rect.size.x / PIXELS_PER_UNIT, rect.size.y / PIXELS_PER_UNIT, thickness)
	piece.mesh = mesh
	piece.position = world_point(rect.get_center(), depth)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = 0.84
	piece.material_override = material
	stage.add_child(piece)
	return piece

func surface(points: Array[Vector2], depths: Array[float], color: String) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in [0, 1, 2, 0, 2, 3]:
		mesh.add_vertex(world_point(points[i], depths[i]))
	mesh.generate_normals()
	var piece := MeshInstance3D.new()
	piece.mesh = mesh.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.material_override = material
	stage.add_child(piece)

func button(rect: Rect2, title: String, color: String) -> void:
	box(rect.grow(2), 1.96, 0.08, "#807788")
	box(rect, 2.01, 0.08, color)
	var text := Label3D.new()
	text.text = title
	text.font_size = 18
	text.pixel_size = 0.005
	text.outline_size = 0
	text.position = world_point(rect.get_center(), 2.06)
	stage.add_child(text)

func set_active(active: bool) -> void:
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED

func update_screen(texture: Texture2D, rgb565: bool, scanlines: bool, preset: int, preview: bool) -> void:
	var options := [texture, rgb565, scanlines, preset, preview]
	if options == last_screen_options:
		return
	last_screen_options = options
	glass.set_shader_parameter("preview", preview)
	glass.set_shader_parameter("playing", texture != null)
	glass.set_shader_parameter("game_picture", texture)
	glass.set_shader_parameter("rgb565", rgb565)
	glass.set_shader_parameter("scanlines", scanlines)
	glass.set_shader_parameter("preset", preset)

func update_lighting(lit: bool, light_color: Color, powered: bool) -> void:
	ceiling.visible = lit
	glass.set_shader_parameter("room_lit", lit)
	screen_light.light_color = light_color.lerp(Color.WHITE, 0.16)
	screen_light.light_energy = light_color.get_luminance() * 2.1
	power_material.albedo_color = Color("#ff3858") if powered else Color("#502333")
	power_material.emission_enabled = powered
	power_material.emission = Color("#fb234d")

func update_cartridge(visible: bool, position: Vector2, width: float, height: float,
		title: String, art: Texture2D, label_size: Vector2) -> void:
	cartridge_model.visible = visible
	if not visible:
		return
	cartridge_model.position = world_point(position + Vector2(width * 0.5, height * 0.5), 1.84)
	if height != last_cartridge_height:
		cartridge_back.mesh.size = Vector3(width, height, 18) / PIXELS_PER_UNIT
		last_cartridge_height = height
	cartridge_art.visible = art != null
	if art:
		cartridge_art.texture = art
		cartridge_art.pixel_size = label_size.x / PIXELS_PER_UNIT / art.get_width()
		cartridge_art.position.y = (height * 0.5 - 8.0 - label_size.y * 0.5) / PIXELS_PER_UNIT
	cartridge_title.visible = art == null
	cartridge_title.text = title.left(21)
	cartridge_title.position.y = (height * 0.5 - 30.0) / PIXELS_PER_UNIT
