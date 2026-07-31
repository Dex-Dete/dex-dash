extends Control
## SettingsMenu - video, audio, gameplay, interface, controls and data tabs.

var _tabs: TabContainer
var _controls_box: VBoxContainer
var _capture_action := ""
var _capture_button: Button


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	UIBuilder.header(self, "menu.settings")
	_tabs = TabContainer.new()
	_tabs.position = Vector2(24, 84)
	_tabs.size = Vector2(1232, 610)
	add_child(_tabs)
	_build_video()
	_build_audio()
	_build_gameplay()
	_build_interface()
	_build_controls()
	_build_data()


func _build_video() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_tabs.add_child(v)
	v.name = Localization.t("quality")
	var full := UIBuilder.check_row(v, Localization.t("fullscreen"), "fullscreen", "video")
	full.toggled.connect(_on_window_mode)
	var vsync := UIBuilder.check_row(v, Localization.t("vsync"), "vsync", "video")
	vsync.toggled.connect(func(on: bool): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED))
	# fps limit
	var row := HBoxContainer.new()
	row.add_child(UIBuilder.label(Localization.t("fps_limit")))
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 500
	spin.value = int(SettingsManager.settings["video"]["fps_limit"])
	spin.custom_minimum_size = Vector2(120, 32)
	spin.value_changed.connect(func(val: float):
		SettingsManager.set_video("fps_limit", int(val)))
	row.add_child(spin)
	v.add_child(row)
	# quality
	var qrow := HBoxContainer.new()
	qrow.add_child(UIBuilder.label(Localization.t("quality")))
	var qopt := OptionButton.new()
	for i in 3:
		qopt.add_item(Localization.t("quality_" + ["low", "medium", "high"][i]))
	qopt.select(SettingsManager.quality())
	qopt.item_selected.connect(func(idx: int):
		SettingsManager.set_video("quality", idx))
	qopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qrow.add_child(qopt)
	v.add_child(qrow)
	UIBuilder.check_row(v, Localization.t("particles"), "particles", "video")
	UIBuilder.check_row(v, Localization.t("screen_shake"), "screen_shake", "video")
	UIBuilder.check_row(v, Localization.t("background_detail"), "background_detail", "video")
	# ui scale
	var urow := HBoxContainer.new()
	urow.add_child(UIBuilder.label(Localization.t("ui_scale")))
	var uslider := HSlider.new()
	uslider.min_value = 0.8
	uslider.max_value = 1.5
	uslider.step = 0.1
	uslider.value = float(SettingsManager.settings["ui"]["ui_scale"])
	uslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uslider.value_changed.connect(func(val: float):
		SettingsManager.set_ui("ui_scale", val))
	urow.add_child(uslider)
	v.add_child(urow)


func _on_window_mode(full: bool) -> void:
	SettingsManager.apply_all()


func _build_audio() -> void:
	var a := VBoxContainer.new()
	a.add_theme_constant_override("separation", 10)
	_tabs.add_child(a)
	a.name = Localization.t("master_volume")
	for bus in ["master", "music", "sfx"]:
		var row := HBoxContainer.new()
		row.add_child(UIBuilder.label(Localization.t(bus + "_volume")))
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(SettingsManager.settings["audio"][bus])
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.value_changed.connect(_on_volume.bind(bus))
		row.add_child(slider)
		a.add_child(row)


func _on_volume(val: float, bus: String) -> void:
	SettingsManager.set_audio(bus, val)
	AudioManager.get_bus_volumes()


func _build_gameplay() -> void:
	var g := VBoxContainer.new()
	g.add_theme_constant_override("separation", 10)
	_tabs.add_child(g)
	g.name = Localization.t("controls")
	UIBuilder.check_row(g, Localization.t("ghost_mode"), "ghost_mode", "gameplay")
	UIBuilder.check_row(g, Localization.t("auto_retry"), "auto_retry", "gameplay")
	UIBuilder.check_row(g, Localization.t("screen_shake"), "shake_on_land", "gameplay")


func _build_interface() -> void:
	var i := VBoxContainer.new()
	i.add_theme_constant_override("separation", 10)
	_tabs.add_child(i)
	i.name = Localization.t("language")
	# language
	var lrow := HBoxContainer.new()
	lrow.add_child(UIBuilder.label(Localization.t("language")))
	var lopt := OptionButton.new()
	for code in Localization.LANGS:
		lopt.add_item(code.to_upper())
	lopt.select(Localization.LANGS.find(Localization.lang))
	lopt.item_selected.connect(func(idx: int):
		Localization.set_language(Localization.LANGS[idx])
		_rebuild())
	lopt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(lopt)
	i.add_child(lrow)
	# theme
	var trow := HBoxContainer.new()
	trow.add_child(UIBuilder.label(Localization.t("theme")))
	var topt := OptionButton.new()
	for name in ThemeManager.THEMES.keys():
		topt.add_item(str(ThemeManager.THEMES[name]["name"]))
	topt.select(ThemeManager.THEMES.keys().find(ThemeManager.current_name))
	topt.item_selected.connect(func(idx: int):
		ThemeManager.set_theme(ThemeManager.THEMES.keys()[idx]))
	topt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	trow.add_child(topt)
	i.add_child(trow)
	UIBuilder.check_row(i, Localization.t("show_fps"), "show_fps", "ui")
	UIBuilder.check_row(i, Localization.t("reduced_motion"), "reduced_motion", "ui")
	UIBuilder.check_row(i, Localization.t("high_contrast"), "high_contrast", "ui")
	# colorblind
	var crow := HBoxContainer.new()
	crow.add_child(UIBuilder.label(Localization.t("colorblind")))
	var copt := OptionButton.new()
	for mode in ["none", "protanopia", "deuteranopia", "tritanopia"]:
		copt.add_item(mode.capitalize())
	var cur: String = str(SettingsManager.settings["ui"]["colorblind_mode"])
	copt.select(["none", "protanopia", "deuteranopia", "tritanopia"].find(cur))
	copt.item_selected.connect(func(idx: int):
		SettingsManager.set_ui("colorblind_mode", ["none", "protanopia", "deuteranopia", "tritanopia"][idx]))
	copt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crow.add_child(copt)
	i.add_child(crow)


func _build_controls() -> void:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", 8)
	_tabs.add_child(c)
	c.name = Localization.t("controls")
	_controls_box = c
	_refresh_controls()
	var reset := UIBuilder.button(Localization.t("reset_controls"))
	reset.pressed.connect(func():
		InputActions.reset_defaults()
		_refresh_controls())
	c.add_child(reset)


func _refresh_controls() -> void:
	for child in _controls_box.get_children():
		child.queue_free()
	for action in InputActions.ACTIONS:
		var row := HBoxContainer.new()
		var l := UIBuilder.label(action)
		l.custom_minimum_size = Vector2(200, 0)
		row.add_child(l)
		var btn := UIBuilder.button("")
		btn.custom_minimum_size = Vector2(360, 36)
		_refresh_token_text(btn, action)
		btn.pressed.connect(_start_capture.bind(action, btn))
		row.add_child(btn)
		_controls_box.add_child(row)


func _refresh_token_text(btn: Button, action: String) -> void:
	var binds: Array = SettingsManager.get_control(action)
	var parts: Array = []
	for tok in binds:
		parts.append(UIBuilder.token_name(str(tok)))
	btn.text = " + ".join(parts) if parts.size() > 0 else "---"


func _start_capture(action: String, btn: Button) -> void:
	if _capture_button != null:
		_capture_button.text = _capture_button.text
	_capture_action = action
	_capture_button = btn
	btn.text = "..."
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if _capture_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_apply_bind(event)
	elif event is InputEventJoypadButton and event.pressed:
		_apply_bind(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_apply_bind(event)


func _apply_bind(event: InputEvent) -> void:
	var action := _capture_action
	var tok := InputActions.event_to_token(event)
	if tok == "":
		return
	var binds: Array = SettingsManager.get_control(action)
	if not binds.has(tok):
		binds.append(tok)
	InputActions.rebind(action, binds)
	_capture_action = ""
	_capture_button = null
	get_viewport().set_input_as_handled()
	_refresh_controls()


func _build_data() -> void:
	var d := VBoxContainer.new()
	d.add_theme_constant_override("separation", 12)
	_tabs.add_child(d)
	d.name = Localization.t("delete_save")
	d.add_child(UIBuilder.label(Localization.t("delete_save_confirm"), 16, UIBuilder.SUBTLE))
	var reset_btn := UIBuilder.button(Localization.t("reset"))
	reset_btn.add_theme_color_override("font_color", Color("ff5252"))
	reset_btn.pressed.connect(func():
		SaveManager.reset_all()
		AchievementManager.check_all())
	d.add_child(reset_btn)


func _rebuild() -> void:
	var idx := _tabs.current_tab
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	_build_video()
	_build_audio()
	_build_gameplay()
	_build_interface()
	_build_controls()
	_build_data()
	_tabs.current_tab = mini(idx, _tabs.get_tab_count() - 1)
