class_name UIBuilder
## UIBuilder - shared helpers for building the neon UI in code.

const BG := Color(0.03, 0.03, 0.09)
const BG_2 := Color(0.07, 0.09, 0.16, 0.9)
const TEXT := Color(0.85, 0.9, 1.0)
const SUBTLE := Color(0.55, 0.6, 0.75)
const BORDER := Color(0.25, 0.3, 0.45)


static func add_bg(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	return bg


static func header(parent: Control, title_key: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	h.position = Vector2(24, 16)
	h.size = Vector2(1232, 48)
	parent.add_child(h)
	var back := Button.new()
	back.text = "< " + Localization.t("back")
	back.add_theme_font_override("font", Assets.font_body)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		GameFlow.goto_main_menu())
	h.add_child(back)
	var title := Label.new()
	title.text = Localization.t(title_key)
	title.add_theme_font_override("font", Assets.font_pixel)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", ThemeManager.current["accent"])
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(title)
	return h


static func panel() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG_2
	sb.border_color = BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Assets.font_body)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 40)
	b.add_theme_font_override("font", Assets.font_body)
	b.add_theme_font_size_override("font_size", 18)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func check_row(parent: VBoxContainer, label_text: String, key: String, section: String) -> CheckButton:
	var row := HBoxContainer.new()
	var l := label(label_text)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var cb := CheckButton.new()
	cb.button_pressed = bool(SettingsManager.settings[section][key])
	cb.toggled.connect(func(on: bool):
		SettingsManager.settings[section][key] = on
		SettingsManager.save_settings())
	row.add_child(cb)
	parent.add_child(row)
	return cb


static func fmt_time(sec: float) -> String:
	var s := int(floor(sec))
	var h := s / 3600
	var m := (s % 3600) / 60
	var ss := s % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, ss]
	return "%d:%02d" % [m, ss]


static func token_name(token: String) -> String:
	if token.begins_with("key_"):
		var code := int(InputActions.TOKENS[token][1])
		return OS.get_keycode_string(code)
	if token.begins_with("gamepad_"):
		var idx := int(InputActions.TOKENS[token][1])
		var names := ["A", "B", "X", "Y", "", "", "Select", "Start", "", "LB", "RB", "Down", "Up", "Left", "Right"]
		return "Pad " + (names[idx] if idx < names.size() and names[idx] != "" else str(idx))
	if token.begins_with("mouse_"):
		return "LMB" if int(InputActions.TOKENS[token][1]) == 1 else "RMB"
	return token
