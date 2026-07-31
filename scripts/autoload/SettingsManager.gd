extends Node
## SettingsManager - loads/saves user settings (graphics, audio, controls, themes).
## Settings are persisted to user://settings.json.

signal settings_changed
signal quality_preset_changed(preset: int)

const SETTINGS_PATH := "user://settings.json"

enum Quality { LOW, MEDIUM, HIGH }

var settings: Dictionary = {
	"video": {
		"fullscreen": false,
		"vsync": true,
		"fps_limit": 240,
		"quality": Quality.HIGH,
		"particles": true,
		"screen_shake": true,
		"background_detail": true,
		"window_width": 1280,
		"window_height": 720,
	},
	"audio": {
		"master": 0.8,
		"music": 0.7,
		"sfx": 0.9,
	},
	"gameplay": {
		"ghost_mode": true,
		"auto_retry": true,
		"shake_on_land": true,
	},
	"ui": {
		"theme": "cyber",
		"language": "en",
		"show_fps": false,
		"ui_scale": 1.0,
		"reduced_motion": false,
		"colorblind_mode": "none",
		"high_contrast": false,
	},
	"controls": {
		"jump": ["key_space", "key_w", "key_up", "gamepad_a"],
		"pause": ["key_escape", "gamepad_start"],
		"restart": ["key_r"],
		"ui_accept": ["key_enter", "key_space", "gamepad_a"],
		"ui_cancel": ["key_escape", "gamepad_b"],
		"ui_left": ["key_left", "key_a", "gamepad_dpad_left"],
		"ui_right": ["key_right", "key_d", "gamepad_dpad_right"],
		"ui_up": ["key_up", "key_w", "gamepad_dpad_up"],
		"ui_down": ["key_down", "key_s", "gamepad_dpad_down"],
	},
}


func _ready() -> void:
	load_settings()
	apply_all()


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_merge(settings, data)
	sanitize()


func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write settings file")
		return
	f.store_string(JSON.stringify(settings, "\t"))
	apply_all()
	settings_changed.emit()


func _merge(base: Dictionary, patch: Dictionary) -> void:
	for k in patch.keys():
		if base.has(k) and base[k] is Dictionary and patch[k] is Dictionary:
			_merge(base[k], patch[k])
		else:
			base[k] = patch[k]


func sanitize() -> void:
	var v: Dictionary = settings["video"]
	v["quality"] = clampi(v["quality"], Quality.LOW, Quality.HIGH)
	var a: Dictionary = settings["audio"]
	a["master"] = clampf(a["master"], 0.0, 1.0)
	a["music"] = clampf(a["music"], 0.0, 1.0)
	a["sfx"] = clampf(a["sfx"], 0.0, 1.0)


func apply_all() -> void:
	var v: Dictionary = settings["video"]
	if v["fullscreen"]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(v["window_width"], v["window_height"]))
	var win := get_window()
	if win != null:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if v["vsync"] else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = int(v["fps_limit"]) if v["fps_limit"] > 0 else 0
	if get_tree().root != null:
		get_tree().root.content_scale_factor = 1.0 / float(settings["ui"]["ui_scale"])


func get_video(key: String) -> Variant:
	return settings["video"].get(key)


func set_video(key: String, value: Variant) -> void:
	settings["video"][key] = value
	save_settings()


func get_audio(key: String) -> Variant:
	return settings["audio"].get(key)


func set_audio(key: String, value: Variant) -> void:
	settings["audio"][key] = value
	save_settings()


func get_ui(key: String) -> Variant:
	return settings["ui"].get(key)


func set_ui(key: String, value: Variant) -> void:
	settings["ui"][key] = value
	save_settings()


func get_gameplay(key: String) -> Variant:
	return settings["gameplay"].get(key)


func set_gameplay(key: String, value: Variant) -> void:
	settings["gameplay"][key] = value
	save_settings()


func get_control(action: String) -> Array:
	return settings["controls"].get(action, [])


func set_controls(action: String, binds: Array) -> void:
	settings["controls"][action] = binds
	save_settings()


func quality() -> int:
	return int(settings["video"]["quality"])
