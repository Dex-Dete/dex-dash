extends Node
## GameFlow - global flow controller: scene transitions, current level/mode
## state, and navigation between gameplay and menus.

signal level_loaded(level_id: String)
signal scene_changed(scene: String)

const FADE_TIME := 0.25

enum Mode { NORMAL, PRACTICE, ENDLESS, DAILY, CUSTOM, BOSS, EDITOR_TEST }

var current_mode := Mode.NORMAL
var current_level_id := ""
var current_level_data: Dictionary = {}
var next_level_after_win := ""
var last_result: Dictionary = {}
var _fade_layer: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ensure_fade() -> void:
	if _fade_layer == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		get_tree().root.add_child(layer)
		_fade_layer = ColorRect.new()
		_fade_layer.color = Color(0.01, 0.01, 0.04, 0.0)
		_fade_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_fade_layer)


func change_scene(path: String, fade := FADE_TIME) -> void:
	if _busy:
		return
	_busy = true
	_ensure_fade()
	var tween := create_tween()
	tween.tween_property(_fade_layer, "color:a", 1.0, fade)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
		scene_changed.emit(path)
	)
	tween.tween_callback(_fade_in.bind(fade))


func _fade_in(fade: float) -> void:
	var tween := create_tween()
	tween.tween_property(_fade_layer, "color:a", 0.0, fade)
	tween.tween_callback(func(): _busy = false)


func goto_main_menu() -> void:
	change_scene("res://scenes/menu/MainMenu.tscn")


func goto_level_select() -> void:
	change_scene("res://scenes/menu/LevelSelect.tscn")


func goto_story() -> void:
	change_scene("res://scenes/menu/StoryHub.tscn")


func goto_endless() -> void:
	change_scene("res://scenes/menu/EndlessMenu.tscn")


func goto_daily() -> void:
	change_scene("res://scenes/menu/DailyMenu.tscn")


func goto_custom() -> void:
	change_scene("res://scenes/menu/CustomLevels.tscn")


func goto_editor() -> void:
	change_scene("res://scenes/editor/Editor.tscn")


func start_level(level_id: String, data: Dictionary, mode := Mode.NORMAL, next_id := "") -> void:
	current_mode = mode
	current_level_id = level_id
	current_level_data = data
	next_level_after_win = next_id
	change_scene("res://scenes/levels/Level.tscn")


func start_custom_level(level_id: String, data: Dictionary) -> void:
	start_level(level_id, data, Mode.CUSTOM)


func mode_name() -> String:
	match current_mode:
		Mode.PRACTICE: return "practice"
		Mode.ENDLESS: return "endless"
		Mode.DAILY: return "daily"
		Mode.CUSTOM: return "custom"
		Mode.BOSS: return "boss"
	return "normal"
