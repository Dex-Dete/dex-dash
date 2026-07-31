class_name BackgroundFX
extends Node2D
## BackgroundFX - parallax background with theme colors and beat pulse.
## Draws stars, mountains, planets, pillars from the bg atlas in 3 layers.

const CELL := 48.0

var theme := "cyber"
var time := 0.0
var scroll := 0.0
var pulse := 0.0
var detail := true
var stars := []  # [x01, y01, size, twinkle_phase]
var quality := SettingsManager.Quality.HIGH


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 90:
		stars.append([rng.randf(), rng.randf(), rng.randf_range(0.5, 1.8), rng.randf() * 6.28])
	detail = bool(SettingsManager.get_video("background_detail"))
	quality = SettingsManager.quality()


func set_theme(t: String) -> void:
	theme = t
	queue_redraw()


func _process(dt: float) -> void:
	time += dt
	pulse = lerpf(pulse, 0.0, dt * 6.0)
	queue_redraw()


func beat_pulse(strength: float) -> void:
	pulse = maxf(pulse, strength)
	queue_redraw()


func _draw() -> void:
	var t: Dictionary = ThemeManager.THEMES.get(theme, ThemeManager.THEMES["cyber"])
	var accent: Color = t["accent"]
	var size := get_viewport_rect().size
	var w := size.x
	var h := size.y
	# gradient sky
	var top: Color = t["bg_top"]
	var bottom: Color = t["bg_bottom"]
	var steps := 8
	for i in steps:
		var c := top.lerp(bottom, float(i + 1) / steps)
		draw_rect(Rect2(0, h * i / steps, w, h / steps + 1), c)
	# beat pulse aura
	if pulse > 0.02:
		draw_rect(Rect2(0, 0, w, h), Color(accent.r, accent.g, accent.b, 0.06 * pulse))
	# stars
	var star_col := Color(0.9, 0.92, 1.0, 0.8)
	var accent_dim := Color(accent.r, accent.g, accent.b, 0.5)
	for s in stars:
		var x: float = fmod(s[0] * w - scroll * 0.03 * CELL, w)
		if x < 0:
			x += w
		var y: float = s[1] * h * 0.75
		var tw: float = 0.4 + 0.6 * abs(sin(time * 1.5 + s[3]))
		var c := accent_dim if s[3] > 4.5 else star_col
		draw_circle(Vector2(x, y), s[2], Color(c.r, c.g, c.b, 0.7 * tw))
	if not detail:
		return
	# moon / planet (far)
	var mrect: Rect2 = Assets.bg_rects.get("bg_moon", Rect2())
	if theme in ["void", "ember"]:
		mrect = Assets.bg_rects.get("bg_planet", mrect)
	draw_texture_rect_region(Assets.bg_texture(),
		Rect2(w * 0.72 - scroll * 0.04 * CELL, h * 0.1, 96, 96),
		mrect, Color(1, 1, 1, 0.9))
	# far mountains
	_draw_tile_row("bg_mountain_far", w, h * 0.55, 256, 128, 0.08, 0.75)
	# clouds
	_draw_tile_row("bg_cloud", w, h * 0.3, 192, 96, 0.14, 0.4)
	# near mountains
	_draw_tile_row("bg_mountain_near", w, h * 0.72, 256, 128, 0.18, 0.95)
	# pillars
	_draw_tile_row("bg_pillar", w, h, 96, 192, 0.28, 1.0)


func _draw_tile_row(name: String, w: float, base_y: float, tw: float, th: float, factor: float, alpha: float) -> void:
	var rect: Rect2 = Assets.bg_rects.get(name, Rect2())
	var offset := fmod(scroll * factor * CELL, tw)
	var x := -offset
	while x < w + tw:
		draw_texture_rect_region(Assets.bg_texture(), Rect2(x, base_y, tw, th), rect, Color(1, 1, 1, alpha))
		x += tw
