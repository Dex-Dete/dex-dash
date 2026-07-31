extends Node
## SaveManager - persists all player data (progress, coins, stats, achievements,
## unlocks, replays, custom levels) to user://save.json.

signal save_loaded
signal save_written

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var data: Dictionary = {
	"version": SAVE_VERSION,
	"player_name": "Runner",
	"progress": {},
	"coins": 0,
	"secret_coins": 0,
	"stats": {
		"jumps": 0,
		"deaths": 0,
		"attempts": 0,
		"time_played": 0.0,
		"levels_completed": 0,
		"coins_collected": 0,
		"secret_coins_collected": 0,
		"endless_best": 0.0,
		"daily_best": 0.0,
		"custom_levels_created": 0,
		"replays_saved": 0,
		"achievements_unlocked": 0,
	},
	"achievements": [],
	"unlocks": {
		"colors": ["cyan"],
		"trails": ["standard"],
	},
	"selected_icon": {"color": "cyan", "trail": "standard"},
	"replays": {},
	"custom_levels": {},
	"daily": {"last_date": "", "score": 0, "completed": false},
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_loaded.emit()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("Failed to read save file")
		save_loaded.emit()
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)
	data["version"] = SAVE_VERSION
	save_loaded.emit()


func save_game() -> void:
	# dedupe replays/custom data stays as-is
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Failed to write save file")
		return
	f.store_string(JSON.stringify(data))
	save_written.emit()


func _merge(base: Dictionary, patch: Dictionary) -> void:
	for k in patch.keys():
		if base.has(k) and base[k] is Dictionary and patch[k] is Dictionary:
			_merge(base[k], patch[k])
		else:
			base[k] = patch[k]


func reset_all() -> void:
	data = {
		"version": SAVE_VERSION,
		"player_name": "Runner",
		"progress": {}, "coins": 0, "secret_coins": 0,
		"stats": data["stats"],  # keep cumulative stats? No - full reset
		"achievements": [], "unlocks": {"colors": ["cyan"], "trails": ["standard"]},
		"selected_icon": {"color": "cyan", "trail": "standard"},
		"replays": {}, "custom_levels": {},
		"daily": {"last_date": "", "score": 0, "completed": false},
	}
	data["stats"] = {
		"jumps": 0, "deaths": 0, "attempts": 0, "time_played": 0.0,
		"levels_completed": 0, "coins_collected": 0, "secret_coins_collected": 0,
		"endless_best": 0.0, "daily_best": 0.0, "custom_levels_created": 0,
		"replays_saved": 0, "achievements_unlocked": 0,
	}
	save_game()


func progress() -> Dictionary:
	return data["progress"]


func get_level_progress(level_id: String) -> Dictionary:
	var p: Dictionary = progress()
	return p.get(level_id, {})


func set_level_progress(level_id: String, fields: Dictionary) -> void:
	var p: Dictionary = progress()
	var cur: Dictionary = p.get(level_id, {})
	for k in fields.keys():
		cur[k] = fields[k]
	p[level_id] = cur
	save_game()


func add_coins(n: int, secret := false) -> void:
	if secret:
		data["secret_coins"] = int(data["secret_coins"]) + n
		data["stats"]["secret_coins_collected"] = int(data["stats"]["secret_coins_collected"]) + n
	else:
		data["coins"] = int(data["coins"]) + n
		data["stats"]["coins_collected"] = int(data["stats"]["coins_collected"]) + n
	save_game()


func get_stats() -> Dictionary:
	return data["stats"]


func stat(key: String) -> Variant:
	return data["stats"].get(key, 0)


func bump_stat(key: String, by := 1) -> void:
	data["stats"][key] = stat(key) + by
	save_game()


func set_stat(key: String, value: Variant) -> void:
	data["stats"][key] = value
	save_game()


func has_achievement(id: String) -> bool:
	return id in data["achievements"]


func unlock_achievement(id: String) -> void:
	if id in data["achievements"]:
		return
	data["achievements"].append(id)
	data["stats"]["achievements_unlocked"] = data["achievements"].size()
	save_game()


func unlock_color(color: String) -> void:
	if not color in data["unlocks"]["colors"]:
		data["unlocks"]["colors"].append(color)
		save_game()


func unlock_trail(trail: String) -> void:
	if not trail in data["unlocks"]["trails"]:
		data["unlocks"]["trails"].append(trail)
		save_game()


func owned_colors() -> Array:
	return data["unlocks"]["colors"]


func owned_trails() -> Array:
	return data["unlocks"]["trails"]


func save_replay(level_id: String, replay_data: String) -> void:
	data["replays"][level_id] = replay_data
	bump_stat("replays_saved")
	save_game()


func get_replay(level_id: String) -> String:
	return str(data["replays"].get(level_id, ""))


func save_custom_level(level_id: String, level_json: String) -> void:
	data["custom_levels"][level_id] = level_json
	bump_stat("custom_levels_created", 0)
	save_game()


func get_custom_levels() -> Dictionary:
	return data["custom_levels"]


func delete_custom_level(level_id: String) -> void:
	data["custom_levels"].erase(level_id)
	save_game()
