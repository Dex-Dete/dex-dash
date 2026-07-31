extends Node2D
## Boot - splash / loading scene. Fades in, starts menu music, then
## hands off to the main menu.

const BOOT_WAIT := 1.2

var _elapsed := 0.0


func _ready() -> void:
	AudioManager.play_music("menu", 1.5)


func _process(dt: float) -> void:
	_elapsed += dt
	if _elapsed >= BOOT_WAIT:
		GameFlow.goto_main_menu()
