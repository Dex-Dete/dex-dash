extends Control
## IconsMenu - icon shop: colors and trails bought with coins.

var _coins_lbl: Label
var _color_grid: GridContainer
var _trail_list: VBoxContainer


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	var header := UIBuilder.header(self, "icon_shop")
	_coins_lbl = UIBuilder.label("", 20, Color("ffd740"))
	header.add_child(_coins_lbl)

	var panel := PanelContainer.new()
	panel.position = Vector2(24, 84)
	panel.size = Vector2(600, 610)
	panel.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(panel)
	var cbox := VBoxContainer.new()
	cbox.position = Vector2(20, 16)
	cbox.size = Vector2(560, 570)
	panel.add_child(cbox)
	cbox.add_child(UIBuilder.label(Localization.t("icon_color"), 20, ThemeManager.current["accent"]))
	_color_grid = GridContainer.new()
	_color_grid.columns = 2
	_color_grid.add_theme_constant_override("h_separation", 12)
	_color_grid.add_theme_constant_override("v_separation", 10)
	_color_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cbox.add_child(_color_grid)

	var panel2 := PanelContainer.new()
	panel2.position = Vector2(656, 84)
	panel2.size = Vector2(600, 610)
	panel2.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(panel2)
	var tbox := VBoxContainer.new()
	tbox.position = Vector2(20, 16)
	tbox.size = Vector2(560, 570)
	panel2.add_child(tbox)
	tbox.add_child(UIBuilder.label(Localization.t("icon_trail"), 20, ThemeManager.current["accent"]))
	_trail_list = VBoxContainer.new()
	_trail_list.add_theme_constant_override("separation", 10)
	_trail_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbox.add_child(_trail_list)

	_refresh()


func _refresh() -> void:
	_coins_lbl.text = Localization.t("coins") + ": " + str(SaveManager.data["coins"])
	_refresh_colors()
	_refresh_trails()


func _refresh_colors() -> void:
	for c in _color_grid.get_children():
		c.queue_free()
	var selected: String = str(SaveManager.data["selected_icon"]["color"])
	for key in UnlockManager.COLORS.keys():
		var def: Dictionary = UnlockManager.COLORS[key]
		var owned: bool = UnlockManager.is_color_owned(key)
		var equipped: bool = key == selected
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(268, 64)
		var sb := UIBuilder.panel()
		if equipped:
			sb.border_color = Color("ffd740")
			sb.set_border_width_all(2)
		row.add_theme_stylebox_override("panel", sb)
		_color_grid.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var swatch := ColorRect.new()
		swatch.color = def["color"]
		swatch.custom_minimum_size = Vector2(36, 36)
		h.add_child(swatch)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UIBuilder.label(str(def["name"]), 16))
		info.add_child(UIBuilder.label(
			Localization.t("equip") if equipped else (Localization.t("owned") if owned else str(def["cost"]) + " coins"),
			13, UIBuilder.SUBTLE))
		var btn := UIBuilder.button(Localization.t("equip") if equipped and owned else (Localization.t("buy") if not owned else Localization.t("equip")))
		btn.custom_minimum_size = Vector2(88, 34)
		btn.disabled = equipped
		btn.pressed.connect(func():
			if not owned:
				if not UnlockManager.buy_color(key):
					_show_toast(Localization.t("not_enough_coins"), Color("ff5252"))
					return
			else:
				UnlockManager.select_color(key)
			AudioManager.play_sfx("coin", 0.8)
			_refresh())
		h.add_child(btn)


func _refresh_trails() -> void:
	for c in _trail_list.get_children():
		c.queue_free()
	var selected: String = str(SaveManager.data["selected_icon"]["trail"])
	for key in UnlockManager.TRAILS.keys():
		var def: Dictionary = UnlockManager.TRAILS[key]
		var owned: bool = UnlockManager.is_trail_owned(key)
		var equipped: bool = key == selected
		var row := PanelContainer.new()
		row.custom_minimum_size = Vector2(540, 56)
		var sb := UIBuilder.panel()
		if equipped:
			sb.border_color = Color("ffd740")
			sb.set_border_width_all(2)
		row.add_theme_stylebox_override("panel", sb)
		_trail_list.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 12)
		row.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_child(info)
		info.add_child(UIBuilder.label(str(def["name"]), 16))
		var btn := UIBuilder.button(Localization.t("equip") if equipped else (Localization.t("buy") if not owned else Localization.t("equip")))
		btn.custom_minimum_size = Vector2(88, 34)
		btn.disabled = equipped
		btn.pressed.connect(func():
			if not owned:
				if not UnlockManager.buy_trail(key):
					_show_toast(Localization.t("not_enough_coins"), Color("ff5252"))
					return
			else:
				UnlockManager.select_trail(key)
			AudioManager.play_sfx("coin", 0.8)
			_refresh())
		h.add_child(btn)


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
