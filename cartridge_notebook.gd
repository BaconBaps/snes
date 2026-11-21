extends PopupPanel

const SAVE_PATH := "user://notebook.cfg"
const ALL_GAMES := "All cartridges"

var room
var favourites := PackedStringArray()
var recent := PackedStringArray()
var boxes := {}
var active_box := ""
var box_picker := OptionButton.new()
var search := LineEdit.new()
var filter := OptionButton.new()
var results := ItemList.new()
var favourite_button := Button.new()
var membership_button := Button.new()
var earlier := Button.new()
var later := Button.new()
var find_button := Button.new()
var new_box := LineEdit.new()

func setup(owner_room: Node2D) -> void:
	room = owner_room
	name = "CartridgeNotebook"
	theme = room.make_settings_theme()
	restore()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 17)
	room.add_settings_heading(content, "Cartridge notebook")

	search.placeholder_text = "Find a cartridge…"
	search.text_changed.connect(func(_value: String): refresh())
	content.add_child(search)
	for label in ["All games", "Favourites", "Recently played", "Current shoebox"]:
		filter.add_item(label)
	filter.item_selected.connect(func(_index: int): refresh())
	content.add_child(filter)

	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.custom_minimum_size.y = 130
	results.item_selected.connect(func(_index: int): update_actions())
	results.item_activated.connect(func(_index: int): reveal_selection())
	content.add_child(results)

	var actions := HBoxContainer.new()
	content.add_child(actions)
	favourite_button.pressed.connect(toggle_favourite)
	actions.add_child(favourite_button)
	find_button.text = "Find in shoebox"
	find_button.pressed.connect(reveal_selection)
	actions.add_child(find_button)

	var box_row := HBoxContainer.new()
	content.add_child(box_row)
	box_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_picker.item_selected.connect(select_box)
	box_row.add_child(box_picker)
	new_box.placeholder_text = "New shoebox name"
	new_box.max_length = 35
	new_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_box.text_submitted.connect(func(_value: String): create_box())
	box_row.add_child(new_box)
	var add_box := Button.new()
	add_box.text = "Create box"
	add_box.pressed.connect(create_box)
	box_row.add_child(add_box)

	var order_row := HBoxContainer.new()
	content.add_child(order_row)
	membership_button.pressed.connect(toggle_membership)
	order_row.add_child(membership_button)
	earlier.text = "Move earlier"
	earlier.pressed.connect(func(): move_selection(-1))
	order_row.add_child(earlier)
	later.text = "Move later"
	later.pressed.connect(func(): move_selection(1))
	order_row.add_child(later)

func restore() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	favourites = config.get_value("notebook", "favourites", PackedStringArray())
	recent = config.get_value("notebook", "recent", PackedStringArray())
	boxes = config.get_value("notebook", "boxes", {})
	active_box = config.get_value("notebook", "active_box", "")
	if not boxes.has(active_box):
		active_box = ""

func persist() -> void:
	var config := ConfigFile.new()
	config.set_value("notebook", "favourites", favourites)
	config.set_value("notebook", "recent", recent)
	config.set_value("notebook", "boxes", boxes)
	config.set_value("notebook", "active_box", active_box)
	if config.save(SAVE_PATH) != OK:
		push_warning("Could not save the cartridge notebook.")

func open_notebook() -> void:
	box_picker.clear()
	box_picker.add_item(ALL_GAMES)
	for box_name in boxes:
		box_picker.add_item(box_name)
		if box_name == active_box:
			box_picker.select(box_picker.item_count - 1)
	refresh()
	popup_centered(Vector2i(540, 486))
	search.grab_focus()

func record_played(path: String) -> void:
	if recent.has(path):
		recent.remove_at(recent.find(path))
	recent.insert(0, path)
	if recent.size() > 50:
		recent.resize(50)
	persist()
	if visible:
		refresh()

func select_box(index: int) -> void:
	active_box = "" if index == 0 else box_picker.get_item_text(index)
	persist()
	room.refresh_shoebox()
	refresh()

func create_box() -> void:
	var box_name := new_box.text.strip_edges()
	if box_name.is_empty() or box_name.nocasecmp_to(ALL_GAMES) == 0:
		return
	for existing_name in boxes:
		if box_name.nocasecmp_to(existing_name) == 0:
			return
	boxes[box_name] = PackedStringArray()
	box_picker.add_item(box_name)
	box_picker.select(box_picker.item_count - 1)
	new_box.clear()
	select_box(box_picker.selected)
	filter.select(0)
	refresh()

func current_paths() -> PackedStringArray:
	return boxes.get(active_box, PackedStringArray())

func selection() -> int:
	var picked := results.get_selected_items()
	return -1 if picked.is_empty() else int(results.get_item_metadata(picked[0]))

func refresh(keep := -1) -> void:
	results.clear()
	var query := search.text.strip_edges().to_lower()
	var indices := range(room.titles.size())
	if filter.selected == 2 and not recent.is_empty():
		indices = []
		for path in recent:
			var index: int = room.rom_paths.find(path)
			if index >= 0:
				indices.append(index)
	elif filter.selected == 3 and not active_box.is_empty():
		indices = []
		for path in current_paths():
			var index: int = room.rom_paths.find(path)
			if index >= 0:
				indices.append(index)
	for index in indices:
		var title: String = room.titles[index]
		var path: String = room.rom_paths[index] if index < room.rom_paths.size() else ""
		if not query.is_empty() and not title.to_lower().contains(query):
			continue
		if (filter.selected == 1 and not favourites.has(path)) or (filter.selected == 2 and not recent.has(path)):
			continue
		results.add_item(("★  " if favourites.has(path) else "") + title)
		results.set_item_metadata(results.item_count - 1, index)
		if index == keep:
			results.select(results.item_count - 1)
	update_actions()

func update_actions() -> void:
	var index := selection()
	var path: String = room.rom_paths[index] if index >= 0 and index < room.rom_paths.size() else ""
	var paths := current_paths()
	var position := paths.find(path)
	favourite_button.text = "Remove favourite" if favourites.has(path) else "Add favourite"
	favourite_button.disabled = path.is_empty()
	find_button.disabled = index < 0
	membership_button.text = "Remove from box" if position >= 0 else "Add to box"
	membership_button.disabled = active_box.is_empty() or path.is_empty()
	earlier.disabled = position <= 0
	later.disabled = position < 0 or position >= paths.size() - 1

func toggle_favourite() -> void:
	var index := selection()
	if index < 0 or index >= room.rom_paths.size():
		return
	var path: String = room.rom_paths[index]
	if favourites.has(path):
		favourites.remove_at(favourites.find(path))
	else:
		favourites.append(path)
	persist()
	refresh(index)

func toggle_membership() -> void:
	var index := selection()
	if active_box.is_empty() or index < 0 or index >= room.rom_paths.size():
		return
	var paths := current_paths()
	var path: String = room.rom_paths[index]
	if paths.has(path):
		paths.remove_at(paths.find(path))
	else:
		paths.append(path)
	boxes[active_box] = paths
	persist()
	room.refresh_shoebox(true)
	refresh(index)

func move_selection(direction: int) -> void:
	var index := selection()
	if index >= 0 and index < room.rom_paths.size() and room.shoebox_position(index) >= 0:
		move_in_box(index, current_paths().find(room.rom_paths[index]) + direction)

func move_to_cartridge(index: int, target: int) -> void:
	move_in_box(index, current_paths().find(room.rom_paths[target]))

func move_in_box(index: int, destination: int) -> void:
	if active_box.is_empty() or index < 0 or index >= room.rom_paths.size():
		return
	var paths := current_paths()
	var path: String = room.rom_paths[index]
	var position := paths.find(path)
	if position < 0 or destination < 0 or destination >= paths.size() or destination == position:
		return
	paths.remove_at(position)
	paths.insert(destination, path)
	boxes[active_box] = paths
	persist()
	room.refresh_shoebox(true)
	refresh(index)

func reveal_selection() -> void:
	var index := selection()
	if index < 0:
		return
	if room.shoebox_position(index) < 0:
		select_box(0)
	hide()
	room.jump_to_title(index)
	room.notebook_selection = index
	room.hovered = index if room.stacked and room.inserted != index else -1
	room.queue_redraw()
