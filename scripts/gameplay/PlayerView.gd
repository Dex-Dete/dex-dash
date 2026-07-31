class_name PlayerView
extends Node2D
## PlayerView - the cube's visual: rotation animation on land, squash/stretch,
## dash afterimages and a trailing glow. Purely visual; physics lives in Level.

const CELL := 48.0

var color := Color("00e5ff")
var trail_color := Color("00e5ff")
var ghost := false
var size := 1.0
var rot := 0.0
var _target_rot := 0.0
var _land_timer := 0.0
var _squash := 1.0
var _spin := 0.0
var _dash := false
var _time := 0.0
var alpha := 1.0
var _level: Node2D
var _texture_region := "player_idle"


func _ready() -> void:
	_texture_region = "player_ghost" if ghost else "player_idle"


func setup(parent: Node2D, is_ghost := false) -> void:
	_level = parent
	ghost = is_ghost
	_texture_region = "player_ghost" if is_ghost else "player_idle"
	modulate.a = 0.55 if is_ghost else 1.0
	z_index = 10 if is_ghost else 5


func _process(dt: float) -> void:
	_time += dt
	if _land_timer > 0.0:
		_land_timer -= dt
		if _land_timer <= 0.0:
			_squash = 1.0
	queue_redraw()


func set_pos_world(world_pos: Vector2) -> void:
	position = world_pos * CELL


func on_land() -> void:
	_target_rot += PI / 2.0
	_land_timer = 0.14
	_squash = 0.72


func on_jump() -> void:
	_squash = 1.25


func on_dash(on: bool) -> void:
	_dash = on


func on_death() -> void:
	_squash = 0.4
	alpha = 0.0


func _draw() -> void:
	var tex := Assets.game_texture()
	var g := Assets.game_rects
	var rect: Rect2 = g[_texture_region]
	var s := size * CELL / 96.0 * (1.0 + 0.06 * sin(_time * 10.0))
	var squashed_y := _squash
	var draw_size := Vector2(s * 96.0 * (2.0 - squashed_y) * 0.5 + 48.0, s * 96.0 * squashed_y)
	draw_set_transform(Vector2.ZERO, rot + _spin, Vector2(draw_size.x / 96.0, draw_size.y / 96.0))
	var c := Color(1, 1, 1, alpha)
	if not ghost:
		# colored cube: tint via separate overlay
		draw_texture_rect_region(tex, Rect2(-48, -48, 96, 96), rect, c)
		draw_texture_rect_region(tex, Rect2(-48, -48, 96, 96), rect, Color(color.r, color.g, color.b, 0.55))
	else:
		draw_texture_rect_region(tex, Rect2(-48, -48, 96, 96), rect, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
