extends Control
## StatsMenu - lifetime statistics.

func _ready() -> void:
	_setup_ui()


func _setup_ui() -> void:
	UIBuilder.add_bg(self)
	UIBuilder.header(self, "statistics")

	var panel := PanelContainer.new()
	panel.position = Vector2(290, 110)
	panel.size = Vector2(700, 520)
	panel.add_theme_stylebox_override("panel", UIBuilder.panel())
	add_child(panel)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 14)
	grid.position = Vector2(48, 32)
	grid.size = Vector2(604, 450)
	panel.add_child(grid)

	var rows := [
		["stat.jumps", str(SaveManager.stat("jumps"))],
		["stat.deaths", str(SaveManager.stat("deaths"))],
		["stat.attempts", str(SaveManager.stat("attempts"))],
		["stat.time", UIBuilder.fmt_time(float(SaveManager.stat("time_played")))],
		["stat.levels", str(SaveManager.stat("levels_completed"))],
		["stat.coins", str(SaveManager.stat("coins_collected"))],
		["stat.secret_coins", str(SaveManager.stat("secret_coins_collected"))],
		["stat.endless", str(int(float(SaveManager.stat("endless_best")) * 10)) + "m"],
		["stat.daily", str(int(float(SaveManager.stat("daily_best")) * 10)) + "m"],
		["stat.achievements", str(SaveManager.stat("achievements_unlocked")) + " / " + str(AchievementManager.DEFS.size())],
	]
	for row in rows:
		grid.add_child(UIBuilder.label(Localization.t(row[0]), 20))
		grid.add_child(UIBuilder.label(str(row[1]), 20, ThemeManager.current["accent"]))
