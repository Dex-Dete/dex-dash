extends Node
## DailyManager - daily challenge levels generated from a date seed.
## Same seed = same level for everyone on that day (architecture supports
## server-verified leaderboards later).

signal daily_ready(level_id: String)

const LEVELS_PER_DIFFICULTY := 6


func today_seed() -> int:
	var d := Time.get_date_string_from_system()
	var seed := 0
	for ch in d.to_utf8_buffer():
		seed = (seed * 31 + ch) & 0x7fffffff
	return seed


func daily_level_id() -> String:
	return "daily_" + Time.get_date_string_from_system()


func has_completed_today() -> bool:
	var d: Dictionary = SaveManager.data["daily"]
	return str(d.get("last_date", "")) == Time.get_date_string_from_system() and bool(d.get("completed", false))


func mark_completed() -> void:
	SaveManager.data["daily"] = {
		"last_date": Time.get_date_string_from_system(),
		"score": 1,
		"completed": true,
	}
	SaveManager.save_game()
	AchievementManager.check_daily()


func build_daily_level() -> Dictionary:
	# Stitch together random chunks from the built-in generator using the
	# date seed so every player gets the same layout.
	var seed := today_seed()
	var chunks: Array = []
	var difficulty := "normal"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var chunk_count := 10 + rng.randi_range(0, 6)
	for i in chunk_count:
		var types := ["flat", "gap", "spikes", "steps", "stair", "portal_grav", "portal_speed", "coin_row"]
		var t: String = types[rng.randi_range(0, types.size() - 1)]
		chunks.append(LevelGenerator.make_chunk(t, difficulty, rng))
	var objs: Array = []
	var x := -2
	for chunk in chunks:
		for o in chunk:
			var copy: Dictionary = o.duplicate()
			copy["x"] = int(copy["x"]) + x
			objs.append(copy)
		x += LevelGenerator.chunk_width(chunk)
	var level := {
		"id": daily_level_id(),
		"name": "Daily " + Time.get_date_string_from_system(),
		"difficulty": difficulty,
		"music": "endless",
		"theme": "sunset",
		"bpm": 130,
		"objects": objs,
		"start": {"x": -2, "y": 0},
		"coins": [],
	}
	return level
