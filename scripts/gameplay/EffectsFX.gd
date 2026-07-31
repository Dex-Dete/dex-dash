class_name EffectsFX
extends Node2D
## EffectsFX - pooled particle system drawn in a single canvas item.
## Supports sparks, shards, rings, soft glows, trails and shockwaves.

const MAX_PARTICLES := 512

var _parts: Array = []     # dicts: pos, vel, life, max_life, size, color, kind, grav, rot, vrot
var _rings: Array = []     # dicts: pos, life, max_life, max_radius, color
var _time := 0.0
var enabled := true


func _ready() -> void:
	enabled = bool(SettingsManager.get_video("particles"))


func _process(dt: float) -> void:
	_time += dt
	if enabled:
		for p in _parts:
			p.life -= dt
			p.vel += Vector2(0, p.grav * dt)
			p.pos += p.vel * dt
			p.rot += p.vrot * dt
		_parts = _parts.filter(func(p): return p.life > 0)
		for r in _rings:
			r.life -= dt
		_rings = _rings.filter(func(r): return r.life > 0)
	queue_redraw()


func clear_all() -> void:
	_parts.clear()
	_rings.clear()
	queue_redraw()


func spark(pos: Vector2, vel: Vector2, color: Color, life := 0.4, size := 3.0) -> void:
	if not enabled:
		return
	if _parts.size() >= MAX_PARTICLES:
		_parts.pop_front()
	_parts.append({
		"pos": pos, "vel": vel, "life": life, "max_life": life,
		"size": size, "color": color, "kind": "spark", "grav": 300.0, "rot": 0.0, "vrot": 0.0,
	})


func shard(pos: Vector2, vel: Vector2, color: Color, life := 0.6, size := 8.0) -> void:
	if not enabled:
		return
	if _parts.size() >= MAX_PARTICLES:
		_parts.pop_front()
	_parts.append({
		"pos": pos, "vel": vel, "life": life, "max_life": life,
		"size": size, "color": color, "kind": "shard", "grav": 500.0,
		"rot": randf() * 6.28, "vrot": randf_range(-8.0, 8.0),
	})


func glow_burst(pos: Vector2, color: Color, count := 8, speed := 200.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.4, speed)
		spark(pos, v, color, randf_range(0.25, 0.5), randf_range(2.0, 5.0))


func ring(pos: Vector2, color: Color, max_radius := 80.0, life := 0.45) -> void:
	_rings.append({"pos": pos, "life": life, "max_life": life, "max_radius": max_radius, "color": color})


func burst(pos: Vector2, color: Color, shards := 10, speed := 260.0) -> void:
	ring(pos, color, 90.0, 0.5)
	for i in shards:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(speed * 0.3, speed)
		shard(pos, v, color, randf_range(0.4, 0.8), randf_range(5.0, 11.0))
	for i in 6:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a)) * randf_range(40.0, 120.0)
		spark(pos, v, Color(1, 1, 1, 0.9), 0.3, 4.0)


func trail(pos: Vector2, color: Color, size := 12.0) -> void:
	if not enabled:
		return
	if _parts.size() >= MAX_PARTICLES:
		_parts.pop_front()
	_parts.append({
		"pos": pos, "vel": Vector2(-randf_range(20, 60), randf_range(-10, 10)),
		"life": 0.28, "max_life": 0.28, "size": size, "color": color,
		"kind": "glow", "grav": 0.0, "rot": 0.0, "vrot": 0.0,
	})


func _draw() -> void:
	if not enabled:
		return
	var tex := Assets.game_texture()
	var g := Assets.game_rects
	for p in _parts:
		var t: float = 1.0 - float(p.life) / float(p.max_life)
		var fade: float = 1.0 - t
		var c := Color(p.color.r, p.color.g, p.color.b, p.color.a * fade)
		match p.kind:
			"spark":
				draw_texture_rect_region(tex, Rect2(p.pos.x - p.size, p.pos.y - p.size, p.size * 2, p.size * 2), g["part_spark"], c)
			"shard":
				var s: float = float(p.size) * (0.6 + 0.4 * fade)
				draw_set_transform(p.pos, p.rot, Vector2(s / 12.0, s / 12.0))
				draw_texture_rect_region(tex, Rect2(-12, -12, 24, 24), g["part_shard"], c)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"glow":
				draw_texture_rect_region(tex, Rect2(p.pos.x - p.size, p.pos.y - p.size, p.size * 2, p.size * 2), g["part_soft"], c)
	for r in _rings:
		var t: float = 1.0 - float(r.life) / float(r.max_life)
		var rad: float = float(r.max_radius) * (0.2 + 0.8 * t)
		var fade: float = 1.0 - t
		var c := Color(r.color.r, r.color.g, r.color.b, 0.6 * fade)
		var s: float = rad / 64.0
		draw_set_transform(r.pos, 0.0, Vector2(s, s))
		draw_texture_rect_region(tex, Rect2(-64, -64, 128, 128), g["part_ring"], c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
