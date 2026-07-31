extends Control
## StoryHub - story mode entry: progress summary, continue, level select.

func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	UIBuilder.header(self, "story")

	var panel := PanelContainer.new()
	panel.position = Vector2(200, 140)
	panel.size = Vector2(880, 420)
	panel.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.position = Vector2(32, 24)
	box.size = Vector2(816, 360)
	panel.add_child(box)

	var title := UIBuilder.label(Localization.t("story.desc"), 22, ThemeManager.current["accent"])
	box.add_child(title)

	var levels := LevelCatalog.catalog()
	var completed := 0
	var next := ""
	for entry in levels:
		var pr: Dictionary = SaveManager.get_level_progress(str(entry["id"]))
		if bool(pr.get("completed", false)):
			completed += 1
		elif next == "":
			next = str(entry["id"])
	var prog := UIBuilder.label(
		Localization.t("progress") + ": " + str(completed) + " / " + str(levels.size()), 18)
	box.add_child(prog)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	var cont := UIBuilder.button(Localization.t("menu.continue"))
	cont.disabled = next == ""
	cont.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		var d := LevelCatalog.get_level(next)
		GameFlow.start_level(next, d, GameFlow.Mode.NORMAL, LevelCatalog.unlock_next(next)))
	box.add_child(cont)

	var sel := UIBuilder.button(Localization.t("menu.level_select"))
	sel.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		GameFlow.goto_level_select())
	box.add_child(sel)

	var hint := UIBuilder.label(Localization.t("how_to_play"), 15, UIBuilder.SUBTLE)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(0, 60)
	box.add_child(hint)
