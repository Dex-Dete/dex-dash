extends Control
## Editor - cell-based level editor for custom levels.
## Paint objects on a grid, undo/redo, save to custom levels, playtest,
## export/import via clipboard.

const CELL := 48.0

const TOOLS := {
	"ground": {"name": "Ground", "hint": ""},
	"spike_up": {"name": "Spike Up", "hint": ""},
	"spike_down": {"name": "Spike Down", "hint": ""},
	"spike_left": {"name": "Spike Left", "hint": ""},
	"spike_right": {"name": "Spike Right", "hint": ""},
	"pad": {"name": "Bounce Pad", "hint": ""},
	"coin": {"name": "Coin", "hint": ""},
	"coin_secret": {"name": "Secret Coin", "hint": ""},
	"checkpoint": {"name": "Checkpoint", "hint": ""},
	"finish": {"name": "Finish", "hint": ""},
	"portal_grav_up": {"name": "Gravity Up", "hint": ""},
	"portal_grav_down": {"name": "Gravity Down", "hint": ""},
	"portal_speed": {"name": "Speed Portal", "hint": "speed"},
	"portal_size": {"name": "Size Portal", "hint": "size"},
	"portal_dash": {"name": "Dash Portal", "hint": ""},
	"portal_rotate_cw": {"name": "Rotate CW", "hint": ""},
	"portal_rotate_ccw": {"name": "Rotate CCW", "hint": ""},
	"portal_spin": {"name": "Spin Portal", "hint": ""},
	"portal_teleport": {"name": "Teleport Pair", "hint": ""},
	"start": {"name": "Start Point", "hint": ""},
	"erase": {"name": "Erase", "hint": ""},
}

const TOOL_COLORS := {
	"ground": Color("3a5ad9"), "spike_up": Color("ff5252"), "spike_down": Color("ff5252"),
	"spike_left": Color("ff5252"), "spike_right": Color("ff5252"), "pad": Color("69f0ae"),
	"coin": Color("ffd740"), "coin_secret": Color("ffab40"), "checkpoint": Color("9fd8ff"),
	"finish": Color("69f0ae"), "portal_grav_up": Color("7c4dff"), "portal_grav_down": Color("7c4dff"),
	"portal_speed": Color("ff2fd6"), "portal_size": Color("ff2fd6"), "portal_dash": Color("ff2fd6"),
	"portal_rotate_cw": Color("ffa726"), "portal_rotate_ccw": Color("ffa726"), "portal_spin": Color("ffa726"),
	"portal_teleport": Color("ffa726"), "start": Color("00e5ff"), "erase": Color("ff5252"),
}

const VIEW_ORIGIN := Vector2(232, 64)
const VIEW_SIZE := Vector2(1048, 656)

var _objects: Array = []
var _start: Dictionary = {"x": -3, "y": -1}
var _name := "Untitled Level"
var _music := "easy"
var _theme := "cyber"
var _difficulty := "easy"
var _level_id := ""

var _tool := "ground"
var _speed_val := 2
var _size_val := 0.5
var _tp_id := 0
var _palette_buttons: Dictionary = {}

var _grid: GridView
var _cam: Camera2D
var _undo: Array = []
var _redo: Array = []
var _painting := false
var _last_cell := Vector2i(-999, -999)
var _status: Label
var _tool_hint: Label

var _name_edit: LineEdit
var _music_opt: OptionButton
var _theme_opt: OptionButton
var _diff_opt: OptionButton


class GridView:
	extends Node2D
	var editor: Node

	func _draw() -> void:
		var objs: Array = editor._objects
		# grid lines
		var min_x := -20
		var max_x: int = int(editor._length_cells()) + 12
		for x in range(min_x, max_x):
			var col := Color(1, 1, 1, 0.04) if x != 0 else Color(1, 1, 1, 0.10)
			draw_line(Vector2(x * CELL, -14 * CELL), Vector2(x * CELL, 14 * CELL), col, 1.0)
		for y in range(-14, 14):
			var col := Color(1, 1, 1, 0.04) if y != 0 else Color(1, 1, 1, 0.10)
			draw_line(Vector2(-20 * CELL, y * CELL), Vector2(max_x * CELL, y * CELL), col, 1.0)
		# ground band
		draw_rect(Rect2(-20 * CELL, 0, (max_x + 20) * CELL, CELL), Color(0.2, 0.35, 0.9, 0.10))
		# start marker
		var s: Vector2 = Vector2(float(editor._start.get("x", -3)) + 0.5, float(editor._start.get("y", -1)) + 0.5)
		draw_circle(s * CELL, 18.0, Color("00e5ff"))
		draw_circle(s * CELL, 10.0, Color(0.03, 0.03, 0.09))
		# objects
		for obj in objs:
			var t: String = str(obj.get("t", ""))
			var x := int(obj.get("x", 0))
			var y := int(obj.get("y", 0))
			var c: Color = editor.TOOL_COLORS.get(t, Color("8a94b8"))
			if t == "ground":
				draw_rect(Rect2(x * CELL + 1, y * CELL + 1, CELL - 2, CELL - 2), c, true)
			elif t in ["spike_up", "spike_down", "spike_left", "spike_right"]:
				var pts: PackedVector2Array = []
				var cx := x * CELL + CELL / 2.0
				var cy := y * CELL + CELL / 2.0
				match t:
					"spike_up":
						pts = [Vector2(x * CELL + 4, y * CELL + CELL - 4), Vector2(cx, y * CELL + 4), Vector2(x * CELL + CELL - 4, y * CELL + CELL - 4)]
					"spike_down":
						pts = [Vector2(x * CELL + 4, y * CELL + 4), Vector2(cx, y * CELL + CELL - 4), Vector2(x * CELL + CELL - 4, y * CELL + 4)]
					"spike_left":
						pts = [Vector2(x * CELL + CELL - 4, y * CELL + 4), Vector2(x * CELL + 4, cy), Vector2(x * CELL + CELL - 4, y * CELL + CELL - 4)]
					"spike_right":
						pts = [Vector2(x * CELL + 4, y * CELL + 4), Vector2(x * CELL + CELL - 4, cy), Vector2(x * CELL + 4, y * CELL + CELL - 4)]
				draw_colored_polygon(pts, c)
			elif t == "pad":
				draw_rect(Rect2(x * CELL + 4, y * CELL + 4, CELL - 8, CELL * 0.4), c)
				draw_rect(Rect2(x * CELL + 6, y * CELL + 4 - 6, CELL - 12, 6), c)
			elif t in ["coin", "coin_secret"]:
				draw_circle(Vector2(x * CELL + CELL / 2.0, y * CELL + CELL / 2.0), 12.0, c)
			elif t == "checkpoint":
				draw_rect(Rect2(x * CELL + 8, y * CELL + 8, 6, CELL - 16), c)
				draw_rect(Rect2(x * CELL + 14, y * CELL + 8, CELL * 0.5, CELL * 0.4), c)
			elif t == "finish":
				draw_rect(Rect2(x * CELL + 8, y * CELL + 8, CELL - 16, CELL - 16), c, true)
			elif t.begins_with("portal"):
				draw_rect(Rect2(x * CELL + 4, y * CELL - CELL + 4, CELL - 8, CELL * 2 - 8), Color(c.r, c.g, c.b, 0.35))
				var label := "G" if t.ends_with("up") else ("V" if t.ends_with("down") else ("S" if t.contains("speed") else ("Z" if t.contains("size") else ("D" if t.contains("dash") else ("T" if t.contains("teleport") else "R")))))
				var f: Font = editor.get_font()
				draw_string(f, Vector2(x * CELL + 10, y * CELL + 6), label, HORIZONTAL_ALIGNMENT_LEFT, CELL - 20, 22, c)
				if t.contains("teleport"):
					draw_string(f, Vector2(x * CELL + 10, y * CELL + CELL - 10), str(obj.get("pair", 0)), HORIZONTAL_ALIGNMENT_LEFT, CELL - 20, 16, c)
			elif t == "boss":
				draw_rect(Rect2(x * CELL + 2, y * CELL - CELL + 2, CELL - 4, CELL * 2 - 4), Color("b388ff"), false, 3.0)
				draw_string(editor.get_font(), Vector2(x * CELL + 8, y * CELL + 8), "WARDEN", HORIZONTAL_ALIGNMENT_LEFT, CELL - 16, 12, Color("b388ff"))
			else:
				draw_rect(Rect2(x * CELL + 6, y * CELL + 6, CELL - 12, CELL - 12), c, false, 2.0)


func _ready() -> void:
	_undo = []
	_redo = []
	UIBuilder.add_bg(self)
	_build_topbar()
	_build_palette()
	_build_grid()
	_load_initial()
	_update_status()


func _build_topbar() -> void:
	var bar := PanelContainer.new()
	bar.position = Vector2(8, 8)
	bar.size = Vector2(1264, 48)
	bar.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(bar)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	bar.add_child(h)

	var back := UIBuilder.button("< " + Localization.t("back"))
	back.custom_minimum_size = Vector2(120, 36)
	back.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		GameFlow.goto_custom())
	h.add_child(back)

	_name_edit = LineEdit.new()
	_name_edit.text = _name
	_name_edit.custom_minimum_size = Vector2(220, 36)
	_name_edit.add_theme_font_override("font", Assets.font_body)
	_name_edit.add_theme_font_size_override("font_size", 16)
	_name_edit.text_changed.connect(func(t: String): _name = t)
	h.add_child(_name_edit)

	_music_opt = _opt(["tutorial", "easy", "normal", "hard", "harder", "insane", "extreme", "endless", "boss"])
	_music_opt.select(1)
	_music_opt.item_selected.connect(func(idx: int): _music = _music_opt.get_item_text(idx))
	h.add_child(_music_opt)

	_theme_opt = _opt(ThemeManager.THEMES.keys())
	_theme_opt.select(0)
	_theme_opt.item_selected.connect(func(idx: int): _theme = _theme_opt.get_item_text(idx))
	h.add_child(_theme_opt)

	_diff_opt = _opt(["easy", "normal", "hard", "harder", "insane", "extreme"])
	_diff_opt.select(0)
	_diff_opt.item_selected.connect(func(idx: int): _difficulty = _diff_opt.get_item_text(idx))
	h.add_child(_diff_opt)

	for spec in [["save", Localization.t("editor.save")], ["play", Localization.t("editor.playtest")],
			["export", Localization.t("editor.export")], ["import", Localization.t("editor.import")],
			["undo", Localization.t("editor.undo")], ["redo", Localization.t("editor.redo")],
			["clear", Localization.t("editor.clear")]]:
		var b := UIBuilder.button(spec[1])
		b.custom_minimum_size = Vector2(96, 36)
		b.pressed.connect(_on_action.bind(spec[0]))
		h.add_child(b)


func _opt(items: Array) -> OptionButton:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.custom_minimum_size = Vector2(130, 36)
	return o


func _build_palette() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(8, 64)
	panel.size = Vector2(216, 656)
	panel.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(12, 10)
	scroll.size = Vector2(192, 500)
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	for t in TOOLS.keys():
		var b := UIBuilder.button(str(TOOLS[t]["name"]))
		b.custom_minimum_size = Vector2(176, 32)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(_select_tool.bind(t))
		b.add_theme_color_override("font_color", TOOL_COLORS[t])
		box.add_child(b)
		_palette_buttons[t] = b
	_tool_hint = UIBuilder.label("", 13, UIBuilder.SUBTLE)
	_tool_hint.position = Vector2(12, 520)
	_tool_hint.size = Vector2(192, 120)
	_tool_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_tool_hint)
	var srow := HBoxContainer.new()
	srow.position = Vector2(12, 560)
	srow.size = Vector2(192, 90)
	panel.add_child(srow)
	var sbox := VBoxContainer.new()
	srow.add_child(sbox)
	sbox.add_child(UIBuilder.label("Speed v:", 13))
	var speed := SpinBox.new()
	speed.min_value = 1
	speed.max_value = 4
	speed.value = 2
	speed.custom_minimum_size = Vector2(70, 28)
	speed.value_changed.connect(func(val: float): _speed_val = int(val))
	sbox.add_child(speed)
	var zbox := VBoxContainer.new()
	srow.add_child(zbox)
	zbox.add_child(UIBuilder.label("Size s:", 13))
	var zsize := SpinBox.new()
	zsize.min_value = 0.5
	zsize.max_value = 2.0
	zsize.step = 0.5
	zsize.value = 0.5
	zsize.custom_minimum_size = Vector2(70, 28)
	zsize.value_changed.connect(func(val: float): _size_val = val)
	zbox.add_child(zsize)


func _build_grid() -> void:
	_grid = GridView.new()
	_grid.editor = self
	_grid.position = VIEW_ORIGIN
	add_child(_grid)
	_cam = Camera2D.new()
	_cam.position = Vector2(12 * CELL, 0)
	_cam.zoom = Vector2(1.0, 1.0)
	_grid.add_child(_cam)
	_cam.make_current()
	_status = UIBuilder.label("", 15, UIBuilder.SUBTLE)
	_status.position = Vector2(240, 688)
	_status.size = Vector2(1000, 30)
	add_child(_status)


func _load_initial() -> void:
	var data: Dictionary = GameFlow.current_level_data
	if data.is_empty():
		return
	_name = str(data.get("name", _name))
	_music = str(data.get("music", "easy"))
	_theme = str(data.get("theme", "cyber"))
	_difficulty = str(data.get("difficulty", "easy"))
	_level_id = str(data.get("id", ""))
	_start = (data.get("start", _start) as Dictionary).duplicate(true)
	_objects = (data.get("objects", []) as Array).duplicate(true)
	_name_edit.text = _name
	_music_opt.select(maxi(_music_opt.find_text(_music), 0))
	_theme_opt.select(maxi(_theme_opt.find_text(_theme), 0))
	_diff_opt.select(maxi(_diff_opt.find_text(_difficulty), 0))


func _select_tool(t: String) -> void:
	_tool = t
	for k in _palette_buttons.keys():
		var b: Button = _palette_buttons[k]
		b.add_theme_color_override("font_color", Color("ffd740") if k == t else TOOL_COLORS[k])
	var hint: String = str(TOOLS[t]["hint"])
	_tool_hint.text = "Speed portal: v value\nSize portal: s value\nTeleport: places pair 0, then 1\nLMB: place | RMB: erase\nMMB drag: pan | wheel: zoom" if t == "portal_teleport" else ("Uses the v value below" if hint == "speed" else ("Uses the s value below" if hint == "size" else ""))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var zoom_change := 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
			var world := _screen_to_world(event.position)
			var new_zoom := clampf(_cam.zoom.x * zoom_change, 0.35, 3.0)
			var factor := new_zoom / _cam.zoom.x
			_cam.zoom = Vector2(new_zoom, new_zoom)
			_cam.position = world - (world - _cam.position) / factor
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_painting = true
			_last_cell = _world_to_cell(_screen_to_world(event.position))
			_apply_at(_last_cell)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_painting = false
	elif event is InputEventMouseMotion:
		if _painting:
			var cell := _world_to_cell(_screen_to_world(event.position))
			if cell != _last_cell:
				_apply_at(cell)
				_last_cell = cell
	elif event is InputEventKey and event.pressed and not event.echo:
		var ctrl: bool = (event as InputEventKey).ctrl_pressed
		if ctrl and event.keycode == KEY_Z:
			_undo_act()
			get_viewport().set_input_as_handled()
		elif ctrl and event.keycode == KEY_Y:
			_redo_act()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_LEFT or event.keycode == KEY_A:
			_cam.position.x -= 48.0 / _cam.zoom.x
		elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
			_cam.position.x += 48.0 / _cam.zoom.x
		elif event.keycode == KEY_UP or event.keycode == KEY_W:
			_cam.position.y -= 48.0 / _cam.zoom.x
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			_cam.position.y += 48.0 / _cam.zoom.x
	_update_status()


func _process(_dt: float) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		var mv := Input.get_last_mouse_velocity()
		_cam.position -= mv * 0.016 / _cam.zoom.x
	_update_status()


func _screen_to_world(pos: Vector2) -> Vector2:
	return _cam.position + (pos - VIEW_ORIGIN - VIEW_SIZE / 2.0) / _cam.zoom.x


func _world_to_cell(world: Vector2) -> Vector2i:
	return Vector2i(floori(world.x / CELL), floori(world.y / CELL))


func _apply_at(cell: Vector2i) -> void:
	if _tool == "erase":
		_snapshot()
		for i in range(_objects.size() - 1, -1, -1):
			var o: Dictionary = _objects[i]
			if int(o.get("x", -999)) == cell.x and int(o.get("y", -999)) == cell.y:
				_objects.remove_at(i)
		_grid.queue_redraw()
		_update_status()
		return
	if _tool == "start":
		_snapshot()
		_start = {"x": cell.x, "y": cell.y}
		_grid.queue_redraw()
		_update_status()
		return
	var obj: Dictionary = {"t": _tool, "x": cell.x, "y": cell.y}
	if _tool == "portal_speed":
		obj["v"] = _speed_val
	elif _tool == "portal_size":
		obj["v"] = _size_val
	elif _tool == "portal_teleport":
		obj["pair"] = _tp_id
		_tp_id = 1 - _tp_id
	if _tool != "ground" and _tool != "finish" and _tool != "checkpoint":
		for i in range(_objects.size() - 1, -1, -1):
			var o: Dictionary = _objects[i]
			if int(o.get("x", -999)) == cell.x and int(o.get("y", -999)) == cell.y and str(o.get("t", "")) == _tool:
				_objects.remove_at(i)
	_snapshot()
	_objects.append(obj)
	_grid.queue_redraw()
	_update_status()


func _snapshot() -> void:
	_undo.append({"objects": _objects.duplicate(true), "start": _start.duplicate(true)})
	if _undo.size() > 200:
		_undo.pop_front()
	_redo.clear()


func _undo_act() -> void:
	if _undo.is_empty():
		return
	var snap: Dictionary = _undo.pop_back()
	_redo.append({"objects": _objects.duplicate(true), "start": _start.duplicate(true)})
	_objects = (snap["objects"] as Array).duplicate(true)
	_start = (snap["start"] as Dictionary).duplicate(true)
	_grid.queue_redraw()
	_update_status()


func _redo_act() -> void:
	if _redo.is_empty():
		return
	var snap: Dictionary = _redo.pop_back()
	_undo.append({"objects": _objects.duplicate(true), "start": _start.duplicate(true)})
	_objects = (snap["objects"] as Array).duplicate(true)
	_start = (snap["start"] as Dictionary).duplicate(true)
	_grid.queue_redraw()
	_update_status()


func _on_action(what: String) -> void:
	match what:
		"save":
			_save()
		"play":
			AudioManager.play_sfx("click", 0.8)
			var lv := _to_dict()
			GameFlow.start_level("custom_" + str(Time.get_unix_time_from_system()), lv, GameFlow.Mode.EDITOR_TEST)
		"export":
			DisplayServer.clipboard_set(JSON.stringify(_to_dict(), "\t"))
			_show_toast(Localization.t("editor.exported"))
		"import":
			_import_clipboard()
		"undo":
			_undo_act()
		"redo":
			_redo_act()
		"clear":
			_snapshot()
			_objects = []
			_grid.queue_redraw()
			_update_status()


func _to_dict() -> Dictionary:
	return {
		"id": "custom_" + str(Time.get_unix_time_from_system()),
		"name": _name if not _name.is_empty() else "Untitled Level",
		"difficulty": _difficulty, "music": _music, "theme": _theme,
		"bpm": 120, "length": _length_cells(), "start": _start,
		"objects": _objects.duplicate(true),
	}


func _length_cells() -> int:
	var m := 20
	for o in _objects:
		m = max(m, int(o.get("x", 0)) + 8)
	return m


func _save() -> void:
	AudioManager.play_sfx("click", 0.8)
	var json := JSON.stringify(_to_dict(), "\t")
	_level_id = "custom_" + str(Time.get_unix_time_from_system())
	SaveManager.save_custom_level(_level_id, json)
	AchievementManager.check_editor(SaveManager.get_custom_levels().size())
	_show_toast(Localization.t("editor.saved"))


func _import_clipboard() -> void:
	var text := DisplayServer.clipboard_get()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("objects"):
		var lv := LevelData.from_dict(parsed)
		if lv != null and lv.validate().is_empty():
			_objects = (parsed["objects"] as Array).duplicate(true)
			_start = (parsed.get("start", _start) as Dictionary).duplicate(true)
			_grid.queue_redraw()
			_show_toast(Localization.t("editor.imported"))
			_update_status()
			return
	_show_toast("Invalid level data", Color("ff5252"))


func _update_status() -> void:
	var mouse := _screen_to_world(get_global_mouse_position())
	var cell := _world_to_cell(mouse)
	_status.text = "cell: %d,%d   |   objects: %d   |   length: %d cells" % [cell.x, cell.y, _objects.size(), _length_cells()]


func _show_toast(msg: String, color := Color("69f0ae")) -> void:
	var toast := UIBuilder.label(msg, 18, color)
	toast.position = Vector2(440, 680)
	toast.size = Vector2(400, 40)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast.queue_free)


func get_font() -> Font:
	return Assets.font_body
