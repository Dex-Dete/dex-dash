extends Control
## AchievementsMenu - all achievements with unlock state.

var _list: VBoxContainer


func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	var header := UIBuilder.header(self, "achievements")
	var unlocked := 0
	for id in AchievementManager.DEFS.keys():
		if SaveManager.has_achievement(id):
			unlocked += 1
	var count := UIBuilder.label(
		Localization.trf("achievements_progress", [str(unlocked), str(AchievementManager.DEFS.size())]), 18, Color("ffd740"))
	header.add_child(count)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 80)
	scroll.size = Vector2(1232, 620)
	add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	for id in AchievementManager.DEFS.keys():
		_add_row(id)


func _add_row(id: String) -> void:
	var def: Dictionary = AchievementManager.DEFS[id]
	var unlocked := SaveManager.has_achievement(id)
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(1200, 48)
	var sb := UIBuilder.panel()
	sb.border_color = Color("ffd740") if unlocked else UIBuilder.BORDER
	row.add_theme_stylebox_override("panel", sb)
	_list.add_child(row)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	row.add_child(h)
	var mark := UIBuilder.label("DONE" if unlocked else "LOCK", 14)
	mark.custom_minimum_size = Vector2(70, 0)
	mark.add_theme_font_override("font", Assets.font_pixel)
	mark.add_theme_font_size_override("font_size", 13)
	mark.add_theme_color_override("font_color", Color("69f0ae") if unlocked else UIBuilder.SUBTLE)
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(mark)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(box)
	var name_lbl := UIBuilder.label(str(def["name"]), 18)
	name_lbl.add_theme_color_override("font_color", UIBuilder.TEXT if unlocked else UIBuilder.SUBTLE)
	box.add_child(name_lbl)
	var desc := UIBuilder.label(str(def["desc"]), 14, UIBuilder.SUBTLE)
	box.add_child(desc)
