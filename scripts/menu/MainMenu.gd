extends Control
## MainMenu - title screen with mode navigation.
## Scenes not built yet appear as disabled "soon" entries.

const MENU_ITEMS := [
	["menu.play", "play"],
	["menu.story", "story"],
	["menu.endless", "endless"],
	["menu.daily", "daily"],
	["menu.custom", "custom"],
	["menu.editor", "editor"],
	["menu.settings", "settings"],
	["menu.stats", "stats"],
	["menu.achievements", "achievements"],
	["menu.icons", "icons"],
	["menu.quit", "quit"],
]

var _vbox: VBoxContainer


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var title := Label.new()
	title.text = Localization.t("app.title")
	title.add_theme_font_override("font", Assets.font_pixel)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("69f0ae"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var tagline := Label.new()
	tagline.text = Localization.t("app.tagline")
	tagline.add_theme_font_override("font", Assets.font_body)
	tagline.add_theme_font_size_override("font_size", 18)
	tagline.add_theme_color_override("font_color", Color("8a94b8"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(tagline)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	center.add_child(spacer)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	center.add_child(_vbox)

	for item in MENU_ITEMS:
		_add_button(Localization.t(item[0]), item[1])

	var version := Label.new()
	version.text = "v0.2.0"
	version.add_theme_font_override("font", Assets.font_body)
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.4, 0.42, 0.55))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.position = Vector2(0, 660)
	version.size = Vector2(1280, 24)
	add_child(version)


func _add_button(text: String, key: String) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 44)
	b.add_theme_font_override("font", Assets.font_body)
	b.add_theme_font_size_override("font_size", 20)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_on_pressed.bind(key))
	_vbox.add_child(b)


func _on_pressed(key: String) -> void:
	AudioManager.play_sfx("click", 0.8)
	match key:
		"play":
			GameFlow.goto_level_select()
		"story":
			GameFlow.goto_story()
		"endless":
			GameFlow.goto_endless()
		"daily":
			GameFlow.goto_daily()
		"custom":
			GameFlow.goto_custom()
		"editor":
			GameFlow.current_level_data = {}
			GameFlow.goto_editor()
		"settings":
			GameFlow.change_scene("res://scenes/menu/SettingsMenu.tscn")
		"stats":
			GameFlow.change_scene("res://scenes/menu/StatsMenu.tscn")
		"achievements":
			GameFlow.change_scene("res://scenes/menu/AchievementsMenu.tscn")
		"icons":
			GameFlow.change_scene("res://scenes/menu/IconsMenu.tscn")
		"quit":
			get_tree().quit()
