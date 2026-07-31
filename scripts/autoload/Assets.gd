extends Node
## Assets - centralized lazy access to texture atlases, fonts and audio.
## Atlases are loaded once and shared; rect lookup via generated JSON.

const GAME_ATLAS := "res://assets/textures/atlas_game.png"
const UI_ATLAS := "res://assets/textures/atlas_ui.png"
const BG_ATLAS := "res://assets/textures/atlas_bg.png"

var game_atlas: Texture2D
var ui_atlas: Texture2D
var bg_atlas: Texture2D
var game_rects: Dictionary = {}
var ui_rects: Dictionary = {}
var bg_rects: Dictionary = {}

var font_pixel: Font
var font_body: Font

var _loading := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	game_atlas = load(GAME_ATLAS)
	ui_atlas = load(UI_ATLAS)
	bg_atlas = load(BG_ATLAS)
	game_rects = _load_rects("res://assets/textures/atlas_game.json")
	ui_rects = _load_rects("res://assets/textures/atlas_ui.json")
	bg_rects = _load_rects("res://assets/textures/atlas_bg.json")
	font_pixel = load("res://assets/fonts/PressStart2P-Regular.ttf")
	font_body = load("res://assets/fonts/Rubik-Variable.ttf")


func _load_rects(path: String) -> Dictionary:
	var out := {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		for k in parsed.keys():
			var r: Dictionary = parsed[k]
			out[k] = Rect2(int(r["x"]), int(r["y"]), int(r["w"]), int(r["h"]))
	return out


func game_rect(name: String) -> Rect2:
	return game_rects.get(name, Rect2())


func ui_rect(name: String) -> Rect2:
	return ui_rects.get(name, Rect2())


func bg_rect(name: String) -> Rect2:
	return bg_rects.get(name, Rect2())


func game_texture() -> Texture2D:
	return game_atlas


func ui_texture() -> Texture2D:
	return ui_atlas


func bg_texture() -> Texture2D:
	return bg_atlas
