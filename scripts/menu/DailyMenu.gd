extends Control
## DailyMenu - the daily challenge. Same level for everyone, resets at midnight.

func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	UIBuilder.header(self, "daily")

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

	var title := UIBuilder.label(Localization.t("daily"), 28, ThemeManager.current["accent"])
	box.add_child(title)
	var desc := UIBuilder.label(Localization.t("daily.desc"), 18)
	box.add_child(desc)

	var date := UIBuilder.label(Time.get_date_string_from_system(), 18, Color("9fd8ff"))
	box.add_child(date)

	var done := DailyManager.has_completed_today()
	var status := UIBuilder.label(
		Localization.t("daily.done") if done else Localization.t("daily"), 18,
		Color("69f0ae") if done else UIBuilder.SUBTLE)
	box.add_child(status)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	box.add_child(spacer)

	var play := UIBuilder.button(Localization.t("play"))
	play.custom_minimum_size = Vector2(240, 56)
	play.disabled = done
	play.pressed.connect(func():
		AudioManager.play_sfx("click", 0.8)
		var level := DailyManager.build_daily_level()
		GameFlow.start_level(level["id"], level, GameFlow.Mode.DAILY))
	box.add_child(play)
