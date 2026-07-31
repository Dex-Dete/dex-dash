class_name CameraRig
extends Camera2D
## CameraRig - smooth follow with lookahead, beat pulse zoom, screen shake
## and rotation spin animations for rotate portals.

var shake_strength := 0.0
var _shake_time := 0.0
var _base_zoom := Vector2.ONE
var _pulse := 0.0
var _spin_angle := 0.0
var _spin_target := 0.0
var _spin_time := 0.0
var _target := Vector2.ZERO
var _look := Vector2.ZERO
var _smooth := 8.0
var follow_y := true
var shake_enabled := true
var _lock_x := 0.0
var lock_x := false


func _ready() -> void:
	shake_enabled = bool(SettingsManager.get_video("screen_shake"))


func set_target(t: Vector2) -> void:
	_target = t + _look * 3.0


func set_lookahead(dir: Vector2) -> void:
	_look = dir


func beat_pulse(strength: float) -> void:
	_pulse = maxf(_pulse, strength)


func shake(strength: float) -> void:
	shake_strength = maxf(shake_strength, strength)


func spin_to(angle: float, duration := 0.3) -> void:
	_spin_target = angle
	_spin_time = duration


func _process(dt: float) -> void:
	var t := _target
	if lock_x:
		t.x = _lock_x
	var target_pos: Vector2 = t * 48.0 + Vector2(160, 20)
	if not follow_y:
		target_pos.y = 360.0
	position = position.lerp(target_pos, 1.0 - exp(-_smooth * dt))
	# shake
	if shake_strength > 0.01 and shake_enabled:
		_shake_time += dt
		offset = Vector2(
			sin(_shake_time * 47.0) * shake_strength,
			cos(_shake_time * 41.0) * shake_strength * 0.8)
		shake_strength = lerpf(shake_strength, 0.0, dt * 8.0)
	else:
		offset = Vector2.ZERO
	# beat zoom pulse
	_pulse = lerpf(_pulse, 0.0, dt * 8.0)
	zoom = _base_zoom * (1.0 + _pulse * 0.012)
	# spin
	if _spin_time > 0.0:
		var k := dt / 0.3
		_spin_time -= dt
		rotation = lerp_angle(rotation, _spin_target, k)
		if _spin_time <= 0.0:
			rotation = _spin_target
