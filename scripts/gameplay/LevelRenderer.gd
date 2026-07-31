class_name LevelRenderer
extends Node2D
## LevelRenderer - draws all level objects in a few batched canvas items.
## Culling: only objects within the visible rect + margin are drawn.
## This keeps draw calls at a handful regardless of level size.

const CELL := 48.0

var level: LevelData
var view_rect := Rect2(-100, -100, 1400, 1000)
var theme_override := ""
var time := 0.0
var coin_bob := 0.0
var hidden_secret := {}   # "x,y" -> true (secret coins not drawn until... keep drawn but subtle)
var portal_glow := 1.0

var _game_atlas: Texture2D
var _g: Dictionary
var _block_texture := "block_cyan"
var _visible_cache: Array = []


func _ready() -> void:
	_game_atlas = Assets.game_texture()
	_g = Assets.game_rects


func set_level(lv: LevelData, theme_name: String) -> void:
	level = lv
	apply_theme(theme_name)


func apply_theme(theme_name: String) -> void:
	var themes := ThemeManager.THEMES
	if themes.has(theme_name):
		_block_texture = themes[theme_name]["ground"]
	else:
		_block_texture = "block_cyan"
	queue_redraw()


func _process(dt: float) -> void:
	time += dt
	coin_bob = fmod(coin_bob + dt, 1.0)
	if Engine.time_scale > 0.95 and not is_equal_approx(time, time):
		pass
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var tex := _game_atlas
	# ground blocks
	for obj in level.objects:
		var t: String = str(obj.t)
		var x: int = int(obj.x)
		var y: int = int(obj.y)
		var px := x * CELL
		var py := y * CELL
		if px > view_rect.end.x or px + CELL < view_rect.position.x:
			continue
		if py > view_rect.end.y or py + CELL < view_rect.position.y:
			continue
		match t:
			"ground":
				draw_texture_rect_region(tex, Rect2(px, py, CELL, CELL), _g[_block_texture])
			"pad":
				draw_texture_rect_region(tex, Rect2(px, py, CELL, CELL), _g["pad"])
			"spike_up", "spike_down", "spike_left", "spike_right":
				draw_texture_rect_region(tex, Rect2(px, py, CELL, CELL), _g[t])
			"coin", "coin_secret":
				# spinning coin: scale x with sin
				var spin: float = abs(sin(time * 4.0 + x * 0.5 + y))
				var w: float = CELL * (0.25 + 0.75 * spin)
				var r: Rect2 = _g[t]
				var ox: float = px + CELL / 2.0 - w / 2.0
				var bob := sin(time * 2.0 + x) * 4.0
				draw_texture_rect_region(tex, Rect2(ox, py + bob, w, CELL), r)
			"checkpoint":
				draw_texture_rect_region(tex, Rect2(px, py - CELL * 0.5, CELL, CELL * 1.5), _g["finish"], Color(0.6, 0.9, 1.0, 0.9))
			"finish":
				var pulse := 1.0 + 0.08 * sin(time * 5.0)
				draw_texture_rect_region(tex, Rect2(px - CELL * 0.15, py - CELL * 1.5 - 8 * pulse, CELL * 1.3, CELL * 2.2), _g["finish"])
			_:
				if t in _g:
					draw_texture_rect_region(tex, Rect2(px, py - CELL, CELL, CELL * 2), _g[t])
	# portals drawn after (on top), with energy animation
	for key in level._portals.keys():
		var obj: Dictionary = level._portals[key]
		var x := int(obj.x)
		var y := int(obj.y)
		var px := x * CELL
		var py := y * CELL
		if px > view_rect.end.x or px + CELL < view_rect.position.x:
			continue
		var r: Rect2 = _g[str(obj.t)]
		var pulse := 1.0 + 0.12 * sin(time * 6.0)
		draw_texture_rect_region(tex, Rect2(px - 2, py - CELL, CELL + 4, CELL * 2.0 * pulse * 0.5 + CELL), r, Color(1, 1, 1, 0.95))
		# energy band scrolling
		var band := Rect2(px, py - CELL + fmod(time * 60.0, CELL * 1.8), CELL, CELL * 0.4)
		draw_texture_rect_region(tex, band, Rect2(r.position.x, r.position.y, r.size.x, r.size.y), Color(1, 1, 1, 0.28))
	# deco
	for key in level._deco.keys():
		var t: String = level._deco[key]
		var parts: PackedStringArray = String(key).split(",")
		var x := int(parts[0])
		var y := int(parts[1])
		var px := x * CELL
		var py := y * CELL
		if px > view_rect.end.x or px + CELL < view_rect.position.x:
			continue
		draw_texture_rect_region(tex, Rect2(px, py, CELL, CELL), _g[t], Color(1, 1, 1, 0.85))
