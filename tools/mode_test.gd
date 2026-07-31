extends Node
## Headless regression harness for the control forms, mode portals, jump orbs
## and collision. Run: godot --headless res://tools/mode_test.tscn

var _lv: Node
var _fails := 0


func _ready() -> void:
	var objects: Array = []
	for x in range(-4, 60):
		objects.append({"t": "ground", "x": x, "y": 0})
		objects.append({"t": "ground", "x": x, "y": -16})
	objects.append({"t": "portal_ship", "x": 10, "y": -1})
	objects.append({"t": "portal_cube", "x": 16, "y": -1})
	objects.append({"t": "orb", "x": 20, "y": -1})
	objects.append({"t": "finish", "x": 54, "y": 0})
	GameFlow.current_level_data = {
		"id": "mode_test", "name": "mode_test", "difficulty": "easy",
		"music": "easy", "theme": "cyber", "bpm": 120, "length": 60,
		"start": {"x": -3, "y": -1}, "objects": objects,
	}
	_lv = load("res://scenes/levels/Level.tscn").instantiate()
	add_child(_lv)
	await get_tree().process_frame
	_lv.set_process(false)
	_lv._restart()
	await _run_tests()
	print("MODE TEST RESULT: " + ("PASS" if _fails == 0 else str(_fails) + " FAILURES"))
	get_tree().quit(0 if _fails == 0 else 1)


func _check(cond: bool, name: String) -> void:
	if cond:
		print("  ok: " + name)
	else:
		_fails += 1
		print("  FAIL: " + name)


func _tick_n(n: int) -> void:
	for i in n:
		_lv._sim_tick()
		await get_tree().process_frame


func _press_hold() -> void:
	Input.action_press("jump")


func _release() -> void:
	Input.action_release("jump")


func _tap() -> void:
	Input.action_press("jump")
	_lv._sim_tick()
	Input.action_release("jump")


func _run_tests() -> void:
	# cube survives landing and keeps running (regression for snap bug)
	_lv._pos = Vector2(5, -2)
	_lv._vy = 0.0
	_lv._ctrl = "cube"
	_lv._grav = Vector2.DOWN
	_lv._alive = true
	await _tick_n(60)
	_check(_lv._alive and _lv._grounded and _lv._pos.x > 5.0, "cube survives landing and runs")
	# ship rises while held
	_lv._pos = Vector2(5, -2)
	_lv._vy = 0.0
	_lv._ctrl = "ship"
	_lv._grav = Vector2.DOWN
	_lv._alive = true
	await _press_hold()
	await _tick_n(60)
	await _release()
	_check(_lv._vy < 0.0 and _lv._pos.y < -2.0, "ship rises while held")
	# ship falls when released (checked while still airborne)
	for i in 30:
		_lv._sim_tick()
		if i % 6 == 0:
			print("    DBG ship rel t%d vy=%.2f y=%.3f alive=%s held=%s" % [
				i, _lv._vy, _lv._pos.y, _lv._alive, Input.is_action_pressed("jump")])
		await get_tree().process_frame
	_check(_lv._vy > 0.0, "ship falls when released")
	# ship rests on ground
	await _tick_n(180)
	_check(_lv._grounded and absf(_lv._vy) < 0.01, "ship lands and rests")
	# wave holds toward -grav
	_lv._ctrl = "wave"
	_lv._pos = Vector2(5, -2)
	_lv._vy = 0.0
	_lv._alive = true
	await _press_hold()
	await _tick_n(30)
	await _release()
	_check(_lv._vy < 0.0, "wave holds up")
	await _tick_n(30)
	_check(_lv._vy > 0.0, "wave falls on release")
	# ball flips gravity on tap
	_lv._ctrl = "ball"
	_lv._grav = Vector2.DOWN
	_lv._vy = 2.0
	_lv._pos = Vector2(5, -2)
	_lv._alive = true
	await _tap()
	_check(_lv._grav == Vector2.UP, "ball flips gravity on tap")
	# ball dies on surface contact
	_lv._ctrl = "ball"
	_lv._grav = Vector2.DOWN
	_lv._vy = 2.0
	_lv._pos = Vector2(5, -0.35)
	_lv._alive = true
	await _tick_n(3)
	_check(not _lv._alive, "ball dies on surface contact")
	_lv._restart()
	# wave dies on surface contact
	_lv._ctrl = "wave"
	_lv._vy = 2.0
	_lv._pos = Vector2(5, -0.3)
	_lv._alive = true
	await _tick_n(3)
	_check(not _lv._alive, "wave dies on surface contact")
	_lv._restart()
	# ufo tap hops mid-air
	_lv._ctrl = "ufo"
	_lv._pos = Vector2(5, -2)
	_lv._vy = 0.0
	_lv._alive = true
	await _tap()
	_check(_lv._vy < 0.0, "ufo tap hops mid-air")
	# ship portal switches mode, cube portal restores
	_lv._pos = Vector2(7, -2)
	_lv._vy = 0.0
	_lv._ctrl = "cube"
	_lv._alive = true
	_lv._grav = Vector2.DOWN
	_lv._fwd = Vector2.RIGHT
	await _tick_n(40)
	_check(_lv._ctrl == "ship", "ship portal switches mode")
	await _tick_n(80)
	_check(_lv._ctrl == "cube", "cube portal restores mode")
	# orb bounce
	_lv._pos = Vector2(20.1, -0.5)
	_lv._vy = 0.0
	_lv._ctrl = "cube"
	_lv._alive = true
	_lv._grounded = true
	await _tap()
	_check(_lv._vy < 0.0, "orb bounces")
	# restart resets control mode
	_lv._ctrl = "ship"
	_lv._pos = Vector2(5, -2)
	_lv._alive = true
	_lv._restart()
	_check(_lv._ctrl == "cube", "restart resets control mode")
	_lv._restart()
	print("  done")
