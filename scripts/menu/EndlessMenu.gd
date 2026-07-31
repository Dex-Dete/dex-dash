extends Control
## EndlessMenu - how far can you go? Generates a fresh endless circuit.

func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	UIBuilder.header(self, "endless")

	var panel := PanelContainer.new()
	panel.position = Vector2(340, 160)
	panel.size = Vector2(600, 380)
	panel.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.position = Vector2(32, 28)
	box.size = Vector2(536, 320)
	panel.add_child(box)

	var title := UIBuilder.label(Localization.t("endless"), 28, ThemeManager.current["accent"])
	box.add_child(title)
	var desc := UIBuilder.label(Localization.t("endless.desc"), 18)
	box.add_child(desc)

	var best := float(SaveManager.stat("endless_best"))
	var best_lbl := UIBuilder.label(
		Localization.t("best") + ": " + str(int(best * 10)) + "m", 18, Color("ffd740"))
	box.add_child(best_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	box.add_child(spacer)

	var play := UIBuilder.button(Localization.t("play"))
	play.custom_minimum_size = Vector2(240, 56)
	play.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		var level := LevelGenerator.build_endless()
		GameFlow.start_level("endless", level, GameFlow.Mode.ENDLESS))
	box.add_child(play)

	var hint := UIBuilder.label(Localization.t("controls_hint"), 15, UIBuilder.SUBTLE)
	box.add_child(hint)
