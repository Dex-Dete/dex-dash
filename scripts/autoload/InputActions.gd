extends Node
## InputActions - rebindable input layer.
## Maps action names to a list of bind tokens; translates them to InputEvent
## objects at load time and on rebind. Defaults defined in project.godot.

const TOKENS := {
	"key_space": ["key", 32],
	"key_enter": ["key", 4194309],
	"key_escape": ["key", 4194305],
	"key_tab": ["key", 4194306],
	"key_w": ["key", 87],
	"key_a": ["key", 65],
	"key_s": ["key", 83],
	"key_d": ["key", 68],
	"key_up": ["key", 4194320],
	"key_down": ["key", 4194322],
	"key_left": ["key", 4194319],
	"key_right": ["key", 4194321],
	"key_z": ["key", 90],
	"key_x": ["key", 88],
	"key_c": ["key", 67],
	"key_v": ["key", 86],
	"key_b": ["key", 66],
	"key_g": ["key", 71],
	"key_p": ["key", 80],
	"key_r": ["key", 82],
	"key_1": ["key", 49],
	"key_2": ["key", 50],
	"key_3": ["key", 51],
	"key_4": ["key", 52],
	"key_5": ["key", 53],
	"key_6": ["key", 54],
	"gamepad_a": ["gamepad", 0],
	"gamepad_b": ["gamepad", 1],
	"gamepad_x": ["gamepad", 2],
	"gamepad_y": ["gamepad", 3],
	"gamepad_start": ["gamepad", 7],
	"gamepad_select": ["gamepad", 6],
	"gamepad_dpad_left": ["gamepad", 13],
	"gamepad_dpad_right": ["gamepad", 14],
	"gamepad_dpad_up": ["gamepad", 12],
	"gamepad_dpad_down": ["gamepad", 11],
	"gamepad_lb": ["gamepad", 9],
	"gamepad_rb": ["gamepad", 10],
	"mouse_left": ["mouse", 1],
	"mouse_right": ["mouse", 2],
}

const ACTIONS := ["jump", "pause", "ui_accept", "ui_cancel", "ui_left", "ui_right", "ui_up", "ui_down"]


func _ready() -> void:
	rebuild_all()


func token_to_event(token: String) -> InputEvent:
	if not TOKENS.has(token):
		return null
	var kind: String = TOKENS[token][0]
	var code: int = TOKENS[token][1]
	match kind:
		"key":
			var e := InputEventKey.new()
			e.physical_keycode = code
			return e
		"gamepad":
			var g := InputEventJoypadButton.new()
			g.button_index = code
			return g
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = code
			return m
	return null


func event_to_token(e: InputEvent) -> String:
	if e is InputEventKey:
		return "key_" + str(e.physical_keycode)
	if e is InputEventJoypadButton:
		return "gamepad_" + str(e.button_index)
	if e is InputEventMouseButton:
		return "mouse_" + str(e.button_index)
	return ""


func rebuild_all() -> void:
	for action in ACTIONS:
		rebuild(action)


func rebuild(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	var binds: Array = SettingsManager.get_control(action)
	for token in binds:
		var ev := token_to_event(str(token))
		if ev != null:
			InputMap.action_add_event(action, ev)


func rebind(action: String, tokens: Array) -> void:
	SettingsManager.set_controls(action, tokens)
	rebuild(action)


func reset_defaults() -> void:
	SettingsManager.settings["controls"] = {
		"jump": ["key_space", "key_w", "key_up", "gamepad_a"],
		"pause": ["key_escape", "gamepad_start"],
		"ui_accept": ["key_enter", "key_space", "gamepad_a"],
		"ui_cancel": ["key_escape", "gamepad_b"],
		"ui_left": ["key_left", "key_a", "gamepad_dpad_left"],
		"ui_right": ["key_right", "key_d", "gamepad_dpad_right"],
		"ui_up": ["key_up", "key_w", "gamepad_dpad_up"],
		"ui_down": ["key_down", "key_s", "gamepad_dpad_down"],
	}
	rebuild_all()


func pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func pressed_any(actions: Array) -> bool:
	for a in actions:
		if Input.is_action_pressed(a):
			return true
	return false


func just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


func just_pressed_any(actions: Array) -> bool:
	for a in actions:
		if Input.is_action_just_pressed(a):
			return true
	return false
