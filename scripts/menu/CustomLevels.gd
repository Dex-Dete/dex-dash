extends Control
## CustomLevels - manage user-made levels: create, play, edit, export, import.

var _list: VBoxContainer


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	var header := UIBuilder.header(self, "custom_levels")
	var create := UIBuilder.button(Localization.t("create_level"))
	create.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		GameFlow.current_level_data = {}
		GameFlow.goto_editor())
	header.add_child(create)
	var imp := UIBuilder.button(Localization.t("editor.import"))
	imp.pressed.connect(_import_from_clipboard)
	header.add_child(imp)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 80)
	scroll.size = Vector2(1232, 620)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_rebuild_list()


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var custom: Dictionary = SaveManager.get_custom_levels()
	if custom.is_empty():
		_list.add_child(UIBuilder.label(Localization.t("editor.untitled"), 18, UIBuilder.SUBTLE))
		return
	for id in custom.keys():
		var json: String = str(custom[id])
		var parsed: Variant = JSON.parse_string(json)
		var name := str(id)
		var diff := "easy"
		if parsed is Dictionary:
			name = str(parsed.get("name", name))
			diff = str(parsed.get("difficulty", "easy"))
		_add_row(str(id), name, diff, parsed)


func _add_row(id: String, name: String, diff: String, data: Variant) -> void:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(1200, 64)
	row.add_theme_stylebox_override("panel", UIBuilder.panel())
	_list.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var name_lbl := UIBuilder.label(name + "   [" + Localization.t(diff) + "]", 20)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(name_lbl)
	var play := UIBuilder.button(Localization.t("play_custom"))
	play.pressed.connect(func():
		if data is Dictionary:
			AudioManager.play_sfx("click", 0.8)
			GameFlow.start_level(id, data, GameFlow.Mode.CUSTOM))
	h.add_child(play)
	var edit := UIBuilder.button(Localization.t("edit"))
	edit.pressed.connect(func():
		if data is Dictionary:
			AudioManager.play_sfx("click", 0.8)
			GameFlow.current_level_data = data
			GameFlow.goto_editor())
	h.add_child(edit)
	var exp := UIBuilder.button(Localization.t("editor.export"))
	exp.pressed.connect(func():
		DisplayServer.clipboard_set(JSON.stringify(data, "\t"))
		_show_toast(Localization.t("editor.exported")))
	h.add_child(exp)
	var del := UIBuilder.button(Localization.t("delete"))
	del.add_theme_color_override("font_color", Color("ff5252"))
	del.pressed.connect(func():
		SaveManager.delete_custom_level(id)
		_rebuild_list())
	h.add_child(del)


func _import_from_clipboard() -> void:
	var text := DisplayServer.clipboard_get()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary and parsed.has("objects"):
		var lv := LevelData.from_dict(parsed)
		if lv == null or not lv.validate().is_empty():
			_show_toast(Localization.t("editor.imported"))
			return
		var id: String = str(parsed.get("id", "custom_" + str(Time.get_unix_time_from_system())))
		SaveManager.save_custom_level(id, text)
		_rebuild_list()
		_show_toast(Localization.t("editor.imported"))
	else:
		_show_toast("Invalid level data", Color("ff5252"))


func _show_toast(msg: String, color := Color("69f0ae")) -> void:
	var toast := UIBuilder.label(msg, 18, color)
	toast.position = Vector2(440, 640)
	toast.size = Vector2(400, 40)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(toast)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast.queue_free)
