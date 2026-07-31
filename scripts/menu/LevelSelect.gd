extends Control
## LevelSelect - campaign level list with sequential unlock, per-level
## play / practice buttons and completion badges.

const DIFF_COLORS := {
	"easy": Color("69f0ae"),
	"normal": Color("66bbf4"),
	"hard": Color("ffd54f"),
	"harder": Color("ff8a65"),
	"insane": Color("ff5c8a"),
	"extreme": Color("ff2e63"),
	"demon": Color("b388ff"),
}

var _list: VBoxContainer


func _ready() -> void:
	_setup_ui()
	_rebuild_list()


func _setup_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var header := HBoxContainer.new()
	header.position = Vector2(24, 16)
	header.size = Vector2(1232, 48)
	add_child(header)

	var back := Button.new()
	back.text = "< " + Localization.t("back")
	back.add_theme_font_override("font", Assets.font_body)
	back.add_theme_font_size_override("font_size", 18)
	back.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		GameFlow.goto_main_menu())
	header.add_child(back)

	var title := Label.new()
	title.text = Localization.t("menu.level_select")
	title.add_theme_font_override("font", Assets.font_pixel)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("69f0ae"))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 80)
	scroll.size = Vector2(1232, 620)
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func _rebuild_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var levels := LevelCatalog.catalog()
	var unlocked := true
	for entry in levels:
		_add_row(entry, unlocked)
		var progress: Dictionary = SaveManager.get_level_progress(str(entry["id"]))
		if not bool(progress.get("completed", false)):
			unlocked = false


func _add_row(entry: Dictionary, unlocked: bool) -> void:
	var id := str(entry["id"])
	var name := str(entry["name"])
	var diff := str(entry["difficulty"])
	var progress: Dictionary = SaveManager.get_level_progress(id)
	var completed := bool(progress.get("completed", false))
	var best := float(progress.get("best_time", 0.0))

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(1200, 64)
	row.add_theme_stylebox_override("panel", _make_panel(completed))
	_list.add_child(row)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)

	var badge := Label.new()
	badge.text = "DONE" if completed else ("LOCK" if not unlocked else str(entry["length"]) + "s")
	badge.custom_minimum_size = Vector2(80, 0)
	badge.add_theme_font_override("font", Assets.font_pixel)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", DIFF_COLORS[diff])
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(badge)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(info)

	var lbl_name := Label.new()
	lbl_name.text = name
	lbl_name.add_theme_font_override("font", Assets.font_body)
	lbl_name.add_theme_font_size_override("font_size", 20)
	info.add_child(lbl_name)

	var lbl_sub := Label.new()
	var sub := Localization.t(diff) + "  |  " + Localization.t("coins") + ": " + str(progress.get("coins", 0))
	if best > 0.0:
		sub += "  |  " + Localization.t("best_time") + ": %.1fs" % best
	lbl_sub.text = sub
	lbl_sub.add_theme_font_override("font", Assets.font_body)
	lbl_sub.add_theme_font_size_override("font_size", 14)
	lbl_sub.add_theme_color_override("font_color", Color("8a94b8"))
	info.add_child(lbl_sub)

	var btn_play := Button.new()
	btn_play.text = Localization.t("play")
	btn_play.disabled = not unlocked
	btn_play.pressed.connect(_play.bind(entry))
	h.add_child(btn_play)

	var btn_practice := Button.new()
	btn_practice.text = Localization.t("practice")
	btn_practice.disabled = not unlocked
	btn_practice.pressed.connect(_play.bind(entry, GameFlow.Mode.PRACTICE))
	h.add_child(btn_practice)


func _play(entry: Dictionary, mode := GameFlow.Mode.NORMAL) -> void:
	AudioManager.play_sfx("click", 0.8)
	var next := ""
	var levels := LevelCatalog.catalog()
	for i in levels.size():
		if str(levels[i]["id"]) == str(entry["id"]) and i + 1 < levels.size():
			next = str(levels[i + 1]["id"])
			break
	GameFlow.start_level(str(entry["id"]), entry, mode, next)


func _make_panel(completed: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.16, 0.9)
	sb.border_color = Color("69f0ae") if completed else Color(0.25, 0.3, 0.45)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	return sb
