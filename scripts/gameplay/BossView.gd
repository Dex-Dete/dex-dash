class_name BossView
extends Node2D
## BossView - draws boss objects (core / eye) and their projectiles.
## Bosses pulse on the beat and glow when active. Projectiles are
## animated hazard orbs spawned by the boss AI in Level.

const CELL := 48.0

var boss_objs: Array = []   # [{x, y, type, active}]
var projectiles: Array = [] # [{pos: Vector2(cells), type: "spike"/"orb"}]
var time := 0.0
var active := false
var defeated := false


func _process(dt: float) -> void:
	time += dt
	queue_redraw()


func setup_from_level(level: LevelData) -> void:
	boss_objs.clear()
	for o in level.objects:
		var t: String = str(o.get("t", ""))
		if t in LevelData.BOSS_TYPES:
			boss_objs.append({"x": int(o.x), "y": int(o.y), "type": t, "active": false})
	projectiles.clear()


func activate_all() -> void:
	for b in boss_objs:
		b["active"] = true


func _draw() -> void:
	var tex := Assets.game_texture()
	var g := Assets.game_rects
	for b in boss_objs:
		var rect: Rect2 = g["boss_core"] if b["type"] == "boss_core" else g["boss_eye"]
		var pulse := 1.0 + 0.06 * sin(time * 6.0)
		var alpha := 0.55 if not b["active"] else 0.95
		var c := Color(1, 1, 1, alpha)
		if b["active"]:
			var flash := 0.15 + 0.1 * sin(time * 8.0)
			c = Color(1.35, 1.2, 1.2, alpha)
			draw_circle(Vector2(b["x"] * CELL + 24, (b["y"]) * CELL), 34 * pulse, Color(1, 0.2, 0.2, flash))
		draw_texture_rect_region(tex, Rect2(b["x"] * CELL - 24, (b["y"] - 2) * CELL, 96 * pulse, 96 * pulse), rect, c)
	for p in projectiles:
		var c := Color(1, 1, 1, 0.95)
		var sz := 22.0
		if p["type"] == "orb":
			draw_circle(p["pos"] * CELL + Vector2(24, 24), sz, Color(1, 0.35, 0.35, 0.85))
			draw_circle(p["pos"] * CELL + Vector2(24, 24), sz * 0.55, Color(1, 0.85, 0.7, 0.9))
		else:
			draw_texture_rect_region(tex, Rect2(p["pos"].x * CELL + 12 - sz / 2, p["pos"].y * CELL + 12 - sz / 2, sz, sz), g["spike_up"], c)
