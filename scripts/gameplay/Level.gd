extends Node2D
## Level - gameplay scene. Fixed 60Hz simulation, rendering orchestration,
## input, death/win flow, practice mode, replay ghosts, boss AI.
##
## Physics model (level-frame):
##   - Position in cell coordinates, forward along +X by default.
##   - Rotation portals rotate the gravity AND forward vectors by 90° and
##     spin the camera - the level data itself never moves. This makes
##     rotation sections (snake paths) coherent and deterministic.
##   - Velocity decomposes as forward*speed + gravity*vy.

const CELL := 48.0
const TICK := 1.0 / 60.0
const BASE_SPEED := 5.0
const SPEED_FACTORS := [1.0, 1.18, 1.42, 1.73]
const GRAVITY := 28.0
const JUMP_VEL := 9.6
const PAD_VEL := 13.5
const COYOTE_TICKS := 4
const BUFFER_TICKS := 6
const DASH_TIME := 0.75
const DASH_FACTOR := 1.9
const SHIP_THRUST := 42.0      # net upward accel while held: SHIP_THRUST - GRAVITY
const SHIP_MAX_RISE := 11.5
const WAVE_SPEED := 9.5
const UFO_VEL := 7.8
const ORB_VEL := 10.5

var _lv: LevelData
var _mode := GameFlow.Mode.NORMAL
var _level_id := ""
var _level_name := ""
var _difficulty := "easy"
var _music := "easy"
var _theme := "cyber"
var _story := ""

var _pos := Vector2.ZERO        # cells, center
var _vy := 0.0                  # scalar velocity along gravity axis
var _grav := Vector2.DOWN       # unit vector (1,0),(0,1),(-1,0),(0,-1)
var _fwd := Vector2.RIGHT       # unit vector, rotated by rotation portals
var _ctrl := "cube"             # control mode: cube, ship, wave, ufo, ball
var _size := 1.0
var _spd_tier := 1
var _grounded := false
var _coyote := 0
var _buffer := 0
var _dash := 0.0
var _alive := true
var _win := false
var _freeze := 0.0
var _dead_timer := 0.0
var _spawn_pos := Vector2.ZERO
var _spawn_size := 1.0
var _spawn_grav := Vector2.DOWN
var _checkpoint := Vector2.ZERO
var _has_checkpoint := false
var _checkpoint_grav := Vector2.DOWN
var _tick := 0
var _acc := 0.0
var _jumps := 0
var _deaths := 0
var _attempts := 0
var _coins := 0
var _coins_total := 0
var _secrets := 0
var _secrets_total := 0
var _start_time := 0.0
var _run_time := 0.0
var _practice := false
var _endless := false
var _distance := 0.0

var _ghost_enabled := false
var _ghost_playback: ReplayRecorder.Playback
var _ghost_alive := false
var _ghost_pos := Vector2.ZERO
var _ghost_vy := 0.0
var _ghost_grav := Vector2.DOWN
var _ghost_fwd := Vector2.RIGHT
var _ghost_ctrl := "cube"
var _ghost_size := 1.0
var _ghost_spd_tier := 1
var _ghost_grounded := false
var _ghost_dash := 0.0
var _ghost_complete_tick := -1
var _ghost_had_completion := false
var _my_complete_tick := -1
var _replay: ReplayRecorder.Recorder

var _boss_projectiles: Array = []
var _boss_timer := 0.0

var _renderer: LevelRenderer
var _bg: BackgroundFX
var _player_view: PlayerView
var _ghost_view: PlayerView
var _effects: EffectsFX
var _cam: CameraRig
var _boss_view: BossView
var _hud: Control
var _hud_bar: Control
var _hud_attempts: Label
var _hud_practice: Label
var _hud_distance: Label
var _toasts: Control
var _win_overlay: Control
var _pause_overlay: Control
var _death_overlay: Control
var _death_label: Label
var _shade: ColorRect
var _toast_queue: Array = []
var _toast_active := false
var time_scale_helper := 1.0:
	set(v):
		time_scale_helper = v
		Engine.time_scale = v


func _ready() -> void:
	_setup()
	_build_hud()
	_mode = GameFlow.current_mode
	_apply_mode()
	AudioManager.get_bus_volumes()
	AudioManager.play_music(_music)
	if not BeatManager.beat.is_connected(_on_beat):
		BeatManager.beat.connect(_on_beat)
	if not _story.is_empty():
		_show_story(_story)


func _setup() -> void:
	var data: Dictionary = GameFlow.current_level_data
	if data.is_empty():
		data = LevelCatalog.get_level("tutorial")
	_level_id = str(data.get("id", "level"))
	_level_name = str(data.get("name", "Level"))
	_difficulty = str(data.get("difficulty", "easy"))
	_music = str(data.get("music", "easy"))
	_theme = str(data.get("theme", "cyber"))
	_story = str(data.get("story", ""))
	_lv = LevelData.from_dict(data)
	var errors := _lv.validate()
	if not errors.is_empty():
		push_warning("Level validation: " + str(errors))
	_spawn_pos = Vector2(_lv.start.x + 0.5, _lv.start.y + 0.5)
	_checkpoint = _spawn_pos
	_pos = _spawn_pos
	_grav = Vector2.DOWN
	_fwd = Vector2.RIGHT
	_spd_tier = 1
	_coins_total = _lv.total_coins()
	_secrets_total = _lv.total_secret_coins()
	_bg = BackgroundFX.new()
	_bg.set_theme(_theme)
	add_child(_bg)
	_renderer = LevelRenderer.new()
	_renderer.set_level(_lv, _theme)
	add_child(_renderer)
	_boss_view = BossView.new()
	_boss_view.setup_from_level(_lv)
	add_child(_boss_view)
	_player_view = PlayerView.new()
	_player_view.setup(self, false)
	_player_view.color = UnlockManager.selected_color()
	_player_view.trail_color = UnlockManager.selected_color()
	add_child(_player_view)
	_ghost_view = PlayerView.new()
	_ghost_view.setup(self, true)
	add_child(_ghost_view)
	_effects = EffectsFX.new()
	add_child(_effects)
	_cam = CameraRig.new()
	add_child(_cam)
	_cam.make_current()


func _apply_mode() -> void:
	match _mode:
		GameFlow.Mode.PRACTICE:
			_practice = true
		GameFlow.Mode.ENDLESS:
			_endless = true
	if not _practice and not _endless and bool(SettingsManager.get_gameplay("ghost_mode")):
		var rep := SaveManager.get_replay(_level_id)
		if not rep.is_empty():
			_ghost_playback = ReplayRecorder.Playback.new()
			if _ghost_playback.load(rep):
				_ghost_enabled = true
				_ghost_pos = _spawn_pos
				_ghost_grav = Vector2.DOWN
				_ghost_fwd = Vector2.RIGHT
				_ghost_alive = true
	_replay = ReplayRecorder.Recorder.new()
	_replay.start()
	StatsManager.add_attempt()
	_attempts = 1
	_start_time = Time.get_ticks_msec() / 1000.0


func _process(dt: float) -> void:
	if Engine.time_scale <= 0.0:
		return
	_run_time += dt
	_acc += dt
	var steps := 0
	while _acc >= TICK and steps < 5:
		_sim_tick()
		_acc -= TICK
		steps += 1
		if _acc > TICK * 5:
			_acc = 0.0
	# visuals
	var cam_pos: Vector2 = _pos if _alive or _win else _cam.position / CELL
	_cam.set_target(cam_pos)
	_cam.set_lookahead(_fwd)
	_renderer.view_rect = Rect2(_cam.position.x - 900, _cam.position.y - 900, 1800, 1800)
	_player_view.set_pos_world(_pos)
	_player_view.size = _size
	_player_view.on_dash(_dash > 0.0)
	if _ghost_enabled and _ghost_alive:
		_ghost_view.set_pos_world(_ghost_pos)
		_ghost_view.size = _ghost_size
		_ghost_view.visible = true
	else:
		_ghost_view.visible = false
	if _endless:
		_distance = maxf(_distance, (_pos - _spawn_pos).length())
		if _hud_distance:
			_hud_distance.text = Localization.t("endless.score") + ": " + str(int(_distance * 10)) + "m"
	elif _hud_bar:
		_update_progress_bar()
	if _win or _death_overlay.visible or _pause_overlay.visible:
		pass
	elif InputActions.just_pressed_any(["pause", "ui_cancel"]):
		_toggle_pause()
	if InputActions.just_pressed("restart") and not _win and not _win_overlay:
		_restart()
	if not _alive and not _win:
		_dead_timer -= dt
		if bool(SettingsManager.get_gameplay("auto_retry")):
			if _dead_timer <= 0.0:
				_restart()
			elif _dead_timer < 0.55 and InputActions.just_pressed("jump"):
				_restart()
		elif InputActions.just_pressed_any(["jump", "ui_accept"]):
			_restart()
	if _dash > 0.0 and _alive:
		_dash -= dt
		if _dash <= 0.0:
			_dash = 0.0
	if _freeze > 0.0:
		_freeze -= dt
	if _lv.is_boss and _alive:
		_boss_update(dt)
	if _alive and not _win:
		if _dash > 0.0:
			_effects.trail(_player_view.position, _player_view.trail_color, 18.0)
		elif _tick % 12 == 0:
			_effects.trail(_player_view.position, _player_view.trail_color, 9.0)
	if not _toast_queue.is_empty() and not _toast_active:
		_show_next_toast()


func _sim_tick() -> void:
	if not _alive or _win or _freeze > 0.0:
		if _ghost_enabled and _ghost_alive and _freeze <= 0.0:
			_ghost_tick()
		_tick += 1
		return
	var jp := InputActions.just_pressed("jump")
	var jump_held := InputActions.pressed("jump")
	if jp:
		_buffer = BUFFER_TICKS
	_replay.record_tick(jump_held)
	if _buffer > 0:
		_buffer -= 1
	if _coyote > 0:
		_coyote -= 1
	var grounded_prev := _grounded
	var support := _support_cell()
	if grounded_prev and not _cell_solid(support):
		_grounded = false
		_coyote = COYOTE_TICKS
	if jp:
		if _ctrl == "ball":
			# ball mode: tap flips gravity (roll on any surface = death)
			_grav = -_grav
			_vy = -_vy
			_grounded = false
			AudioManager.play_sfx("gravity", 0.9, 1.1)
			_effects.ring(_player_view.position, Color("ffa726"), 70.0, 0.35)
			_player_view._spin += PI
		elif _ctrl == "ufo":
			# ufo mode: tap = short hop, works mid-air
			_vy = -UFO_VEL
			_grounded = false
			_jumps += 1
			StatsManager.add_jump()
			AudioManager.play_sfx("jump", 0.8, randf_range(1.05, 1.2))
			_player_view.on_jump()
			_effects.glow_burst(_player_view.position + _grav * 12.0, Color(0.8, 0.9, 1.0), 4, 110.0)
	if _ctrl == "cube" and _buffer > 0 and (_grounded or _coyote > 0):
		_do_jump()
	if _grounded and (_ctrl == "cube" or _ctrl == "ufo"):
		var pad_cell := support
		if _lv.pad_at(pad_cell.x, pad_cell.y):
			_vy = -JUMP_VEL * 1.4
			_grounded = false
			_jumps += 1
			StatsManager.add_jump()
			AudioManager.play_sfx("jump_big", 0.9, 1.0)
			_effects.ring(_player_view.position, ThemeManager.current["accent"], 60.0, 0.3)
	match _ctrl:
		"wave":
			_vy = -WAVE_SPEED if jump_held else WAVE_SPEED
		"ship":
			_vy += (GRAVITY - (SHIP_THRUST if jump_held else 0.0)) * TICK
			_vy = clampf(_vy, -SHIP_MAX_RISE, 20.0)
		_:
			var g_scale := 1.0
			if _ctrl == "cube" and jump_held and _vy < 0.0:
				g_scale = 0.72
			_vy += GRAVITY * g_scale * TICK
			_vy = minf(_vy, 18.0)
	var speed := _current_speed()
	_pos += _fwd * speed * TICK
	_pos += _grav * _vy * TICK
	_check_overlap_deaths()
	if not _alive:
		return
	if _ctrl == "wave" or _ctrl == "ball":
		# these forms die on any surface contact
		if _snap_to_ground():
			_die("crash")
			return
	else:
		if _snap_to_ground():
			_grounded = true
			_vy = 0.0
		else:
			_grounded = false
	_check_coin()
	_check_objects(jp)
	_tick += 1
	if _ghost_enabled and _ghost_alive:
		_ghost_tick()


func _current_speed() -> float:
	var f: float = SPEED_FACTORS[clampi(_spd_tier - 1, 0, 3)]
	var s: float = BASE_SPEED * f
	if _dash > 0.0:
		s *= DASH_FACTOR
	return s


func _do_jump() -> void:
	_vy = -JUMP_VEL
	_grounded = false
	_coyote = 0
	_buffer = 0
	_jumps += 1
	StatsManager.add_jump()
	AudioManager.play_sfx("jump", 0.8, randf_range(0.95, 1.05))
	_player_view.on_jump()
	_effects.glow_burst(_player_view.position + _grav * 12.0, Color(0.8, 0.9, 1.0), 5, 120.0)


func _support_cell() -> Vector2i:
	# cell just past the body edge in the gravity direction
	var edge := _pos + _grav * (_size / 2.0 + 0.02)
	return _cell_of(edge)


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.y))


func _cell_solid(c: Vector2i) -> bool:
	return _lv.solid_at(c.x, c.y)


func _snap_to_ground() -> bool:
	var support := _support_cell()
	if not _cell_solid(support):
		return false
	if _vy > -0.001:
		# rest ON TOP of the support cell: align only the gravity axis so the
		# body edge sits on the cell's gravity-facing boundary; the
		# perpendicular coordinate is left free (no snapping to column centers).
		if _grav.y < 0.0:
			_pos.y = support.y + 1.0 + _size / 2.0
		elif _grav.y > 0.0:
			_pos.y = support.y - _size / 2.0
		elif _grav.x > 0.0:
			_pos.x = support.x - _size / 2.0
		else:
			_pos.x = support.x + 1.0 + _size / 2.0
		_vy = 0.0
		_player_view.on_land()
		_effects.spark(_player_view.position - _grav * 12.0, _grav * 40.0, Color(1, 1, 1, 0.7), 0.25, 3.0)
		return true
	return false


func _hitbox() -> Rect2:
	var half := _size / 2.0
	return Rect2(_pos.x - half, _pos.y - half, half * 2, half * 2)


func _check_overlap_deaths() -> void:
	var hb := _hitbox()
	var x0 := floori(hb.position.x)
	var x1 := floori(hb.end.x - 0.001)
	var y0 := floori(hb.position.y)
	var y1 := floori(hb.end.y - 0.001)
	var support := _support_cell()
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			# the surface the body rests on / approaches is contact (the snap
			# handles it), never a crush; hazards still apply there.
			var is_support := cy == support.y if _grav.y != 0.0 else cx == support.x
			if not is_support and _lv.solid_at(cx, cy):
				_die("crash")
				return
			var hz := _lv.hazard_at(cx, cy)
			if hz != "" and _spike_overlap(hz, cx, cy, hb):
				_die("spike")
				return
			var boss := _lv.boss_at(cx, cy)
			if not boss.is_empty() and hb.intersects(Rect2(cx + 0.1, cy + 0.1, 0.8, 0.8)):
				_die("boss")
				return
	for p in _boss_projectiles:
		var r := Rect2(p.x + 0.05, p.y + 0.05, 0.9, 0.9)
		if hb.intersects(r):
			_die("boss")
			return
	if _pos.length() > 60.0:
		_die("void")


func _spike_overlap(hz: String, cx: int, cy: int, hb: Rect2) -> bool:
	var zone := Rect2(cx + 0.15, cy + 0.15, 0.7, 0.7)
	match hz:
		"spike_up":
			zone = Rect2(cx + 0.15, cy + 0.5, 0.7, 0.5)
		"spike_down":
			zone = Rect2(cx + 0.15, cy, 0.7, 0.5)
		"spike_left":
			zone = Rect2(cx + 0.5, cy + 0.15, 0.5, 0.7)
		"spike_right":
			zone = Rect2(cx, cy + 0.15, 0.5, 0.7)
	return hb.intersects(zone)


func _check_coin() -> void:
	var cx := floori(_pos.x)
	var cy := floori(_pos.y)
	var got := _lv.take_coin(cx, cy)
	if got == "":
		return
	AudioManager.play_sfx("secret" if got == "coin_secret" else "coin", 0.85)
	var c: Color = ThemeManager.current["accent2"] if got == "coin_secret" else Color(1, 0.8, 0.2)
	_effects.burst(_player_view.position, c, 6, 160.0)
	if got == "coin_secret":
		_secrets += 1
		StatsManager.add_coin(true)
		_show_toast(Localization.t("secret_found"), c)
	else:
		_coins += 1
		StatsManager.add_coin()
		_show_toast("+1", Color(1, 0.8, 0.2), 0.8)


func _check_objects(jp: bool) -> void:
	var cx := floori(_pos.x)
	var cy := floori(_pos.y)
	# trigger checks span the body height (cells cy-1..cy+1) so objects placed
	# one cell above/below the player's center (e.g. portals at GND-1) fire
	# while running on the ground, like GD overlap-triggers.
	for dy in range(-1, 2):
		var yy := cy + dy
		if _lv.orb_at(cx, yy) and jp:
			_vy = -ORB_VEL
			_grounded = false
			_coyote = 0
			_jumps += 1
			StatsManager.add_jump()
			AudioManager.play_sfx("jump", 0.8, 1.15)
			_player_view.on_jump()
			_effects.glow_burst(_player_view.position + _grav * 12.0, Color(1, 0.9, 0.4), 5, 120.0)
			return
	for dy in range(-1, 2):
		var yy := cy + dy
		if not _lv.checkpoint_at(cx, yy).is_empty() and not _has_checkpoint:
			_has_checkpoint = true
			_checkpoint = Vector2(cx + 0.5, yy + 0.5)
			_checkpoint_grav = _grav
			AudioManager.play_sfx("checkpoint", 0.9)
			_effects.ring(_player_view.position, Color(0.6, 0.9, 1.0), 70.0, 0.4)
			_show_toast(Localization.t("checkpoint_reached"), Color(0.6, 0.9, 1.0), 1.2)
			break
	var fp: Vector2i = _lv.finish_pos()
	if floori(fp.x) == cx and cy >= fp.y - 1 and cy <= fp.y + 1:
		_win_level()
		return
	for dy in range(-1, 2):
		var yy := cy + dy
		var portal: Dictionary = _lv.portal_at(cx, yy)
		if not portal.is_empty():
			_apply_portal(portal)
			return


func _apply_portal(portal: Dictionary) -> void:
	var t: String = str(portal.t)
	match t:
		"portal_grav_up", "portal_grav_down":
			var new_grav := -_grav
			if str(portal.t) == "portal_grav_up":
				new_grav = -_grav
			elif str(portal.t) == "portal_grav_down":
				new_grav = _grav
			# flips are relative to the current gravity axis
			new_grav = -_grav
			_grav = new_grav
			_vy *= 0.15
			AudioManager.play_sfx("gravity", 0.9)
			_effects.ring(_player_view.position, Color("ff2fd6"), 80.0, 0.4)
			_effects.glow_burst(_player_view.position, Color("ff2fd6"), 10, 220.0)
			_player_view._spin += PI
		"portal_speed":
			_spd_tier = clampi(int(portal.get("v", 2)), 1, 4)
			AudioManager.play_sfx("portal_speed", 0.9)
			_effects.ring(_player_view.position, Color("ffa726"), 70.0, 0.35)
		"portal_size":
			var new_size := float(portal.get("v", 0.5))
			if new_size != _size:
				var contact := _pos + _grav * (_size / 2.0)
				_size = new_size
				_pos = contact - _grav * (_size / 2.0)
				AudioManager.play_sfx("portal", 0.9)
				_effects.ring(_player_view.position, Color("7c4dff"), 70.0, 0.35)
		"portal_dash":
			_dash = DASH_TIME
			AudioManager.play_sfx("dash", 1.0)
			_effects.ring(_player_view.position, Color("00e5ff"), 90.0, 0.4)
			_cam.shake(6.0)
		"portal_teleport":
			var pair := str(portal.get("pair", ""))
			var target := _lv.teleport_target(pair, Vector2(int(portal.x), int(portal.y)))
			if target != Vector2.ZERO:
				_pos = target + Vector2(0.5, 0.5)
				_vy *= 0.2
				AudioManager.play_sfx("teleport", 0.9)
				_effects.ring(_player_view.position, Color("ff5252"), 90.0, 0.4)
				_effects.glow_burst(_player_view.position, Color("ff2fd6"), 12, 260.0)
				_cam.shake(4.0)
		"portal_rotate_cw", "portal_rotate_ccw":
			var dir := -1 if t == "portal_rotate_cw" else 1
			_rotate_world(dir)
		"portal_spin":
			_player_view._spin += PI * 2.0
		"portal_cube", "portal_ship", "portal_wave", "portal_ufo", "portal_ball":
			_set_ctrl(t.trim_prefix("portal_"))


func _set_ctrl(c: String) -> void:
	_ctrl = c
	_player_view.mode = c
	AudioManager.play_sfx("portal", 0.9, 1.05)
	_effects.ring(_player_view.position, Color("69f0ae"), 70.0, 0.35)
	_effects.glow_burst(_player_view.position, Color("69f0ae"), 8, 200.0)


func _rotate_world(dir: int) -> void:
	# Rotate the player's gravity and forward axes 90°; the camera spins.
	# explicit 2D rotation (cw: (x,y)->(y,-x), ccw: (x,y)->(-y,x))
	if dir < 0:
		_grav = Vector2(_grav.y, -_grav.x)
		_fwd = Vector2(_fwd.y, -_fwd.x)
	else:
		_grav = Vector2(-_grav.y, _grav.x)
		_fwd = Vector2(-_fwd.y, _fwd.x)
	AudioManager.play_sfx("rotate", 1.0)
	_effects.ring(_player_view.position, Color("69f0ae"), 110.0, 0.5)
	_effects.glow_burst(_player_view.position, Color("69f0ae"), 14, 240.0)
	_cam.shake(8.0)
	_cam.spin_to(_cam.rotation + PI / 2.0 * dir, 0.35)
	_freeze = 0.35


func _die(cause: String) -> void:
	if not _alive or _win:
		return
	_alive = false
	_deaths += 1
	StatsManager.add_death()
	AudioManager.play_sfx("death", 1.0)
	_cam.shake(18.0)
	_effects.burst(_player_view.position, UnlockManager.selected_color(), 14, 300.0)
	_effects.burst(_player_view.position, Color(1, 1, 1), 6, 220.0)
	_player_view.on_death()
	_ghost_view.visible = false
	var auto_retry := bool(SettingsManager.get_gameplay("auto_retry"))
	_dead_timer = 0.8 if auto_retry else 1.1
	if _death_label:
		_death_label.text = "" if auto_retry else Localization.t("tap_to_restart")
	if not _practice:
		Engine.time_scale = 0.25
		var tw := create_tween()
		tw.tween_interval(0.09)
		tw.tween_property(self, "time_scale_helper", 1.0, 0.35)
	_death_overlay.visible = true
	_death_overlay.modulate.a = 0.0
	var dtw := create_tween()
	dtw.tween_property(_death_overlay, "modulate:a", 1.0, 0.25)
	if _replay:
		_replay.stop()
	AchievementManager.check_all()


func _restart() -> void:
	Engine.time_scale = 1.0
	if _has_checkpoint and _practice:
		_pos = _checkpoint
		_grav = _checkpoint_grav
	else:
		_pos = _spawn_pos
		_grav = Vector2.DOWN
	_fwd = Vector2.RIGHT
	_ctrl = "cube"
	_ghost_ctrl = "cube"
	_player_view.mode = "cube"
	_size = 1.0
	_spd_tier = 1
	_vy = 0.0
	_alive = true
	_grounded = false
	_coyote = 0
	_buffer = 0
	_dash = 0.0
	_freeze = 0.0
	_dead_timer = 0.0
	_attempts += 1
	StatsManager.add_attempt()
	_death_overlay.visible = false
	_player_view.alpha = 1.0
	_player_view.rot = 0.0
	_player_view._spin = 0.0
	_effects.clear_all()
	_effects.ring(_player_view.position, UnlockManager.selected_color(), 60.0, 0.3)
	_cam.rotation = 0.0
	if _ghost_enabled:
		_ghost_playback = ReplayRecorder.Playback.new()
		var rep := SaveManager.get_replay(_level_id)
		_ghost_enabled = _ghost_playback.load(rep)
		_ghost_alive = _ghost_enabled
		_ghost_pos = _spawn_pos
		_ghost_grav = Vector2.DOWN
		_ghost_fwd = Vector2.RIGHT
		_ghost_size = 1.0
		_ghost_spd_tier = 1
		_ghost_dash = 0.0
	if _replay:
		_replay.start()
	if _hud_attempts:
		_hud_attempts.text = Localization.t("attempts") + ": " + str(_attempts)


func _win_level() -> void:
	if _win:
		return
	_win = true
	_alive = true
	AudioManager.play_sfx("win", 1.0)
	_effects.burst(_player_view.position, ThemeManager.current["accent"], 20, 320.0)
	_effects.burst(_player_view.position, Color(1, 1, 1), 12, 260.0)
	_effects.ring(_player_view.position, ThemeManager.current["accent2"], 140.0, 0.7)
	_cam.shake(6.0)
	_my_complete_tick = _tick
	var replay_data := _replay.stop() if _replay else ""
	var ghost_beaten := false
	if _ghost_enabled and not _practice:
		if _ghost_had_completion:
			ghost_beaten = _my_complete_tick < _ghost_complete_tick
		else:
			ghost_beaten = true
	var prev := SaveManager.get_level_progress(_level_id)
	var best_time := float(prev.get("best_time", 1e9))
	var new_best := _run_time < best_time
	var completed := bool(prev.get("completed", false))
	var prev_coins := int(prev.get("coins", 0))
	SaveManager.set_level_progress(_level_id, {
		"completed": true,
		"coins": max(prev_coins, _coins),
		"coins_max": _coins_total,
		"secret_coins": _secrets,
		"best_time": minf(best_time, _run_time),
		"attempts": _attempts,
		"deaths": _deaths,
	})
	if not completed:
		StatsManager.level_completed()
	if not _practice:
		var old := SaveManager.get_replay(_level_id)
		if old.is_empty() or new_best or not completed:
			SaveManager.save_replay(_level_id, replay_data)
	AchievementManager.check_level_result(_level_id, {
		"difficulty": _difficulty, "completed": true, "deaths": _deaths,
		"coins_found": _secrets,
		"all_coins": _coins_total > 0 and _coins >= _coins_total,
		"practice": _practice, "ghost_beaten": ghost_beaten,
		"no_jump": _jumps == 0,
	})
	if _endless:
		SaveManager.set_stat("endless_best", maxf(float(SaveManager.stat("endless_best")), _distance))
		AchievementManager.check_endless(_distance)
	if _mode == GameFlow.Mode.DAILY:
		DailyManager.mark_completed()
		SaveManager.set_stat("daily_best", maxf(float(SaveManager.stat("daily_best")), _run_time))
	AudioManager.stop_music(0.8)
	if _lv.is_boss:
		for b in _boss_view.boss_objs:
			_effects.burst(Vector2(b["x"], b["y"] - 1) * CELL, Color(1, 0.4, 0.3), 16, 340.0)
			AudioManager.play_sfx("boss_hit", 0.9)
	_show_win_overlay(new_best, ghost_beaten)


func _ghost_tick() -> void:
	if not _ghost_playback or not _ghost_alive:
		return
	var alive := _ghost_playback.advance()
	if not alive:
		_ghost_alive = false
		_ghost_view.visible = false
		return
	var held := _ghost_playback.held_now()
	var jp := _ghost_playback.pressed_this_tick()
	if jp:
		var gcx := floori(_ghost_pos.x)
		var gcy := floori(_ghost_pos.y)
		var orb_near := false
		for dy in range(-1, 2):
			if _lv.orb_at(gcx, gcy + dy):
				orb_near = true
				break
		if orb_near:
			_ghost_vy = -ORB_VEL
			_ghost_grounded = false
		elif _ghost_ctrl == "ball":
			_ghost_grav = -_ghost_grav
			_ghost_vy = -_ghost_vy
			_ghost_grounded = false
		elif _ghost_ctrl == "ufo":
			_ghost_vy = -UFO_VEL
			_ghost_grounded = false
		elif _ghost_ctrl == "cube" and _ghost_grounded:
			_ghost_vy = -JUMP_VEL
			_ghost_grounded = false
	match _ghost_ctrl:
		"wave":
			_ghost_vy = -WAVE_SPEED if held else WAVE_SPEED
		"ship":
			_ghost_vy += (GRAVITY - (SHIP_THRUST if held else 0.0)) * TICK
			_ghost_vy = clampf(_ghost_vy, -SHIP_MAX_RISE, 20.0)
		_:
			_ghost_vy += GRAVITY * TICK
			_ghost_vy = minf(_ghost_vy, 18.0)
	var f: float = SPEED_FACTORS[clampi(_ghost_spd_tier - 1, 0, 3)]
	_ghost_pos += _ghost_fwd * BASE_SPEED * f * (DASH_FACTOR if _ghost_dash > 0.0 else 1.0) * TICK
	_ghost_pos += _ghost_grav * _ghost_vy * TICK
	var edge := _ghost_pos + _ghost_grav * (_ghost_size / 2.0 + 0.02)
	var support := Vector2i(floori(edge.x), floori(edge.y))
	if _ghost_ctrl == "wave" or _ghost_ctrl == "ball":
		if _lv.solid_at(support.x, support.y) and _ghost_vy > -0.001:
			_ghost_alive = false
			_ghost_view.visible = false
			return
	elif _lv.solid_at(support.x, support.y) and _ghost_vy > -0.001:
		var cell_center := Vector2(support) + Vector2(0.5, 0.5)
		_ghost_pos = cell_center - _ghost_grav * (_ghost_size / 2.0)
		_ghost_vy = 0.0
		_ghost_grounded = true
	else:
		_ghost_grounded = false
	var cx := floori(_ghost_pos.x)
	var cy := floori(_ghost_pos.y)
	var portal: Dictionary = _lv.portal_at(cx, cy)
	if not portal.is_empty():
		match str(portal.t):
			"portal_grav_up", "portal_grav_down":
				_ghost_grav = -_ghost_grav
			"portal_speed":
				_ghost_spd_tier = clampi(int(portal.get("v", 2)), 1, 4)
			"portal_size":
				var contact := _ghost_pos + _ghost_grav * (_ghost_size / 2.0)
				_ghost_size = float(portal.get("v", 0.5))
				_ghost_pos = contact - _ghost_grav * (_ghost_size / 2.0)
			"portal_dash":
				_ghost_dash = DASH_TIME
			"portal_teleport":
				var target := _lv.teleport_target(str(portal.get("pair", "")), Vector2(int(portal.x), int(portal.y)))
				if target != Vector2.ZERO:
					_ghost_pos = target + Vector2(0.5, 0.5)
			"portal_rotate_cw":
				_ghost_grav = Vector2(_ghost_grav.y, -_ghost_grav.x)
				_ghost_fwd = Vector2(_ghost_fwd.y, -_ghost_fwd.x)
			"portal_rotate_ccw":
				_ghost_grav = Vector2(-_ghost_grav.y, _ghost_grav.x)
				_ghost_fwd = Vector2(-_ghost_fwd.y, _ghost_fwd.x)
			"portal_cube", "portal_ship", "portal_wave", "portal_ufo", "portal_ball":
				_ghost_ctrl = str(portal.t).trim_prefix("portal_")
	if _ghost_dash > 0.0:
		_ghost_dash -= TICK
	if floori(_lv.finish_pos().x) == cx and floori(_lv.finish_pos().y) == cy:
		_ghost_alive = false
		_ghost_had_completion = true
		_ghost_complete_tick = _ghost_playback._idx


# ---------------- boss AI ----------------

func _boss_update(dt: float) -> void:
	_boss_timer -= dt
	for b in _boss_view.boss_objs:
		if _pos.x > float(b["x"]) - 14.0:
			b["active"] = true
	if _boss_timer <= 0.0:
		_boss_timer = 1.5
		_boss_spawn_projectile()
	for p in _boss_projectiles:
		p.x -= p.vx * dt
		p.y += p.vy * dt
	_boss_projectiles = _boss_projectiles.filter(func(p):
		return p.x > _pos.x - 20.0 and p.y < 20.0 and p.y > -10.0)
	_boss_view.projectiles = _boss_projectiles


func _boss_spawn_projectile() -> void:
	var nearest: Dictionary = {}
	var best := 1e9
	for b in _boss_view.boss_objs:
		if not b["active"]:
			continue
		var d: float = float(b["x"]) - _pos.x
		if d > 0.0 and d < best:
			best = d
			nearest = b
	if nearest.is_empty():
		return
	var speed := 4.5 if nearest["type"] == "boss_eye" else 3.2
	_boss_projectiles.append({
		"x": float(nearest["x"]), "y": float(nearest["y"]) - 1.0,
		"vx": speed, "vy": 0.0, "type": "orb",
	})
	AudioManager.play_sfx("boss_hit", 0.4, 1.3)


# ---------------- UI ----------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_hud)
	_hud_attempts = Label.new()
	_hud_attempts.position = Vector2(16, 12)
	_hud_attempts.add_theme_font_override("font", Assets.font_body)
	_hud_attempts.add_theme_font_size_override("font_size", 18)
	_hud_attempts.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	_hud_attempts.text = Localization.t("attempts") + ": " + str(_attempts)
	_hud.add_child(_hud_attempts)
	_hud_practice = Label.new()
	_hud_practice.position = Vector2(16, 40)
	_hud_practice.add_theme_font_override("font", Assets.font_pixel)
	_hud_practice.add_theme_font_size_override("font_size", 12)
	_hud_practice.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
	_hud_practice.text = Localization.t("practice_mode")
	_hud_practice.visible = _practice
	_hud.add_child(_hud_practice)
	_hud_distance = Label.new()
	_hud_distance.position = Vector2(16, 40)
	_hud_distance.add_theme_font_override("font", Assets.font_body)
	_hud_distance.add_theme_font_size_override("font_size", 20)
	_hud_distance.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
	_hud_distance.visible = _endless
	_hud.add_child(_hud_distance)
	_hud_bar = _make_progress_bar()
	_hud.add_child(_hud_bar)
	var pause_btn := Button.new()
	pause_btn.position = Vector2(get_viewport_rect().size.x - 56, 12)
	pause_btn.custom_minimum_size = Vector2(44, 44)
	pause_btn.text = "II"
	pause_btn.add_theme_font_override("font", Assets.font_body)
	pause_btn.pressed.connect(_toggle_pause)
	_hud.add_child(pause_btn)
	_toasts = Control.new()
	_toasts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_toasts)
	_shade = ColorRect.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.01, 0.01, 0.05, 0.55)
	_shade.visible = false
	_hud.add_child(_shade)
	_death_overlay = Control.new()
	_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_overlay.visible = false
	_hud.add_child(_death_overlay)
	var death_label := Label.new()
	death_label.text = ""
	death_label.set_anchors_preset(Control.PRESET_CENTER)
	death_label.position.y += 60
	death_label.add_theme_font_override("font", Assets.font_body)
	death_label.add_theme_font_size_override("font_size", 22)
	death_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.85))
	_death_overlay.add_child(death_label)
	_death_label = death_label
	_pause_overlay = Control.new()
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.visible = false
	_hud.add_child(_pause_overlay)
	_build_pause_menu()
	if bool(SettingsManager.get_ui("show_fps")):
		var fps := Label.new()
		fps.position = Vector2(16, get_viewport_rect().size.y - 34)
		fps.add_theme_font_override("font", Assets.font_body)
		fps.add_theme_font_size_override("font_size", 14)
		fps.add_theme_color_override("font_color", Color(0.5, 0.6, 0.8))
		fps.text = "FPS"
		_hud.add_child(fps)
		var t := Timer.new()
		t.wait_time = 0.5
		t.autostart = true
		t.timeout.connect(func(): fps.text = "FPS " + str(Engine.get_frames_per_second()))
		add_child(t)


func _make_progress_bar() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_TOP_WIDE)
	c.custom_minimum_size = Vector2(0, 10)
	var rect := ColorRect.new()
	rect.color = Color(0.1, 0.12, 0.25, 0.8)
	rect.set_anchors_preset(Control.PRESET_TOP_WIDE)
	rect.custom_minimum_size = Vector2(0, 6)
	c.add_child(rect)
	c.set_meta("bar", rect)
	return c


func _update_progress_bar() -> void:
	var bar: ColorRect = _hud_bar.get_meta("bar")
	var p := clampf((_pos.x - _spawn_pos.x) / maxf(1.0, float(_lv.length) - _spawn_pos.x), 0.0, 1.0)
	var w := get_viewport_rect().size.x * p
	if not is_equal_approx(bar.offset_right, w):
		bar.offset_right = w
		var c: Color = ThemeManager.current["accent"]
		bar.color = Color(c.r, c.g, c.b, 0.9)


func _toggle_pause() -> void:
	if _win:
		return
	var show := not _pause_overlay.visible
	_pause_overlay.visible = show
	_shade.visible = show or _death_overlay.visible
	get_tree().paused = show
	if show:
		AudioManager.play_sfx("pause", 0.7)
	else:
		AudioManager.play_sfx("unpause", 0.7)


func _build_pause_menu() -> void:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(420, 420)
	panel.position = Vector2(get_viewport_rect().size.x / 2 - 210, 80)
	_pause_overlay.add_child(panel)
	_style_panel(panel)
	var title := Label.new()
	title.text = Localization.t("paused")
	title.position = Vector2(0, 24)
	title.size = Vector2(420, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Assets.font_pixel)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	panel.add_child(title)
	var opts := [
		[Localization.t("resume"), func(): _toggle_pause()],
		[Localization.t("restart"), func():
			_toggle_pause()
			_restart()],
		[Localization.t("quit_to_menu"), func():
			get_tree().paused = false
			GameFlow.goto_main_menu()],
	]
	for i in opts.size():
		var b := Button.new()
		b.text = opts[i][0]
		b.position = Vector2(60, 90 + i * 90)
		b.size = Vector2(300, 64)
		b.pressed.connect(opts[i][1])
		_style_button(b)
		panel.add_child(b)


func _style_button(b: Button) -> void:
	b.add_theme_font_override("font", Assets.font_body)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(0.6, 0.7, 1.0))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_stylebox_override("normal", _btn_style(Color(0.12, 0.16, 0.34, 0.9)))
	b.add_theme_stylebox_override("hover", _btn_style(Color(0.16, 0.22, 0.46, 0.95)))
	b.add_theme_stylebox_override("pressed", _btn_style(Color(0.08, 0.11, 0.26, 0.95)))
	b.add_theme_stylebox_override("focus", _btn_style(Color(0.16, 0.22, 0.46, 0.95)))


func _btn_style(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.border_color = Color(0.2, 0.35, 0.6, 0.8)
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(8)
	return s


func _style_panel(p: Panel) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.08, 0.18, 0.92)
	s.border_color = Color(0.2, 0.3, 0.6, 0.6)
	s.set_border_width_all(1)
	s.set_corner_radius_all(18)
	p.add_theme_stylebox_override("panel", s)


func _show_win_overlay(new_best: bool, ghost_beaten: bool) -> void:
	_shade.visible = true
	_win_overlay = Control.new()
	_win_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud.add_child(_win_overlay)
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(520, 460)
	panel.position = Vector2(get_viewport_rect().size.x / 2 - 260, 60)
	_win_overlay.add_child(panel)
	_style_panel(panel)
	var title := Label.new()
	title.text = Localization.t("level_complete") if not _endless else Localization.t("new_record")
	title.position = Vector2(0, 26)
	title.size = Vector2(520, 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", Assets.font_pixel)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
	_win_overlay.add_child(title)
	var stats := Label.new()
	var txt := ""
	if not _endless:
		txt += Localization.t("level") + ": " + _level_name + "\n"
	txt += Localization.t("time") + ": %.1fs" % _run_time + "\n"
	txt += Localization.t("attempts") + ": " + str(_attempts) + "\n"
	txt += Localization.t("coins") + ": " + str(_coins) + "/" + str(_coins_total) + "\n"
	if new_best:
		txt += Localization.t("new_best") + "\n"
	if ghost_beaten:
		txt += Localization.t("ghost_beaten") + "\n"
	stats.text = txt
	stats.position = Vector2(60, 96)
	stats.size = Vector2(400, 160)
	stats.add_theme_font_override("font", Assets.font_body)
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	_win_overlay.add_child(stats)
	var btn_retry := Button.new()
	btn_retry.text = Localization.t("retry")
	btn_retry.position = Vector2(60, 280)
	btn_retry.size = Vector2(180, 56)
	btn_retry.pressed.connect(func():
		if _endless:
			GameFlow.start_level(_level_id, GameFlow.current_level_data, GameFlow.Mode.ENDLESS)
		else:
			_restart()
		_win_overlay.queue_free())
	_style_button(btn_retry)
	_win_overlay.add_child(btn_retry)
	var btn_menu := Button.new()
	btn_menu.text = Localization.t("menu.main_menu")
	btn_menu.position = Vector2(280, 280)
	btn_menu.size = Vector2(180, 56)
	btn_menu.pressed.connect(func():
		GameFlow.goto_main_menu())
	_style_button(btn_menu)
	_win_overlay.add_child(btn_menu)
	var nxt := LevelCatalog.unlock_next(_level_id)
	var btn_next := Button.new()
	btn_next.text = Localization.t("next")
	btn_next.position = Vector2(160, 360)
	btn_next.size = Vector2(200, 56)
	btn_next.pressed.connect(func():
		var d := LevelCatalog.get_level(nxt)
		GameFlow.start_level(nxt, d))
	_style_button(btn_next)
	_win_overlay.add_child(btn_next)
	btn_next.visible = not _endless and nxt != ""
	panel.modulate.a = 0.0
	panel.position.y += 30
	var tw := create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(panel, "position:y", panel.position.y - 30, 0.35)


func _show_story(text_key: String) -> void:
	var label := Label.new()
	label.text = Localization.t(text_key)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.y -= 160
	label.add_theme_font_override("font", Assets.font_body)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 0.0))
	_hud.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "modulate", Color(1, 1, 1, 0.9), 0.6)
	tw.tween_interval(2.0)
	tw.tween_property(label, "modulate", Color(1, 1, 1, 0.0), 0.8)
	tw.tween_callback(label.queue_free)


func _show_toast(text: String, color: Color, duration := 1.0) -> void:
	_toast_queue.append([text, color, duration])
	if not _toast_active:
		_show_next_toast()


func _show_next_toast() -> void:
	if _toast_queue.is_empty():
		_toast_active = false
		return
	_toast_active = true
	var item: Array = _toast_queue.pop_front()
	var label := Label.new()
	label.text = item[0]
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.position.y -= 60
	label.add_theme_font_override("font", Assets.font_pixel)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", item[1])
	label.modulate.a = 0.0
	_toasts.add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "modulate:a", 1.0, 0.18)
	tw.tween_interval(item[2])
	tw.tween_property(label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		label.queue_free()
		_show_next_toast())


func _on_beat(bar: int) -> void:
	_bg.beat_pulse(1.0)
	_cam.beat_pulse(1.0)
	if bar == 0 and _lv.is_boss:
		_cam.shake(2.0)


func _exit_tree() -> void:
	if Engine.time_scale < 1.0:
		Engine.time_scale = 1.0
	get_tree().paused = false
	if BeatManager.beat.is_connected(_on_beat):
		BeatManager.beat.disconnect(_on_beat)
