extends Node
## AchievementManager - defines and evaluates achievements.
## Toast notifications are shown by AchievementToast (UI).

signal achievement_unlocked(id: String)

const DEFS := {
	"first_jump": {"name": "Hop Begins", "desc": "Perform your first jump", "icon": "icon_star"},
	"first_death": {"name": "Resilient", "desc": "Die for the first time", "icon": "icon_bomb"},
	"first_coin": {"name": "Shiny", "desc": "Collect your first coin", "icon": "coin"},
	"first_win": {"name": "Runner", "desc": "Complete your first level", "icon": "icon_flag"},
	"coins_10": {"name": "Collector", "desc": "Collect 10 coins", "icon": "coin"},
	"coins_50": {"name": "Treasure Hunter", "desc": "Collect 50 coins", "icon": "coin"},
	"coins_100": {"name": "Coin Baron", "desc": "Collect 100 coins", "icon": "icon_trophy"},
	"deaths_50": {"name": "Persistence", "desc": "Die 50 times", "icon": "icon_bomb"},
	"jumps_1000": {"name": "Bouncy", "desc": "Jump 1000 times", "icon": "icon_star"},
	"hard_clear": {"name": "Getting Serious", "desc": "Beat any Hard level", "icon": "icon_trophy"},
	"insane_clear": {"name": "Unshakable", "desc": "Beat any Insane level", "icon": "icon_trophy"},
	"extreme_clear": {"name": "Legend", "desc": "Beat any Extreme level", "icon": "icon_crown"},
	"boss_clear": {"name": "Warden Breaker", "desc": "Defeat THE WARDEN", "icon": "icon_crown"},
	"flawless": {"name": "Flawless", "desc": "Complete a level without dying", "icon": "icon_star"},
	"no_jump": {"name": "Zen", "desc": "Complete a level without jumping", "icon": "icon_star"},
	"secret_1": {"name": "Hidden Path", "desc": "Find a secret coin", "icon": "coin_secret"},
	"secret_3": {"name": "Pathfinder", "desc": "Find 3 secret coins", "icon": "coin_secret"},
	"endless_1000": {"name": "Marathon", "desc": "Reach 1000m in Endless mode", "icon": "icon_gear"},
	"endless_3000": {"name": "Unstoppable", "desc": "Reach 3000m in Endless mode", "icon": "icon_gear"},
	"editor_first": {"name": "Architect", "desc": "Create your first custom level", "icon": "icon_plus"},
	"editor_publish": {"name": "Cartographer", "desc": "Create 5 custom levels", "icon": "icon_plus"},
	"daily_first": {"name": "Daily Grinder", "desc": "Complete a Daily Challenge", "icon": "icon_star"},
	"practice_clear": {"name": "Rehearsed", "desc": "Beat a level in Practice mode", "icon": "icon_flag"},
	"ghost_run": {"name": "Past Echoes", "desc": "Beat your ghost record", "icon": "icon_ghost"},
	"all_coins": {"name": "Perfectionist", "desc": "Collect every coin in a level", "icon": "coin"},
}


func check_all() -> void:
	_check("first_jump", StatsManager.lifetime_jumps() >= 1)
	_check("first_death", StatsManager.lifetime_deaths() >= 1)
	_check("first_coin", int(SaveManager.stat("coins_collected")) >= 1)
	_check("first_win", int(SaveManager.stat("levels_completed")) >= 1)
	_check("coins_10", int(SaveManager.stat("coins_collected")) >= 10)
	_check("coins_50", int(SaveManager.stat("coins_collected")) >= 50)
	_check("coins_100", int(SaveManager.stat("coins_collected")) >= 100)
	_check("deaths_50", StatsManager.lifetime_deaths() >= 50)
	_check("jumps_1000", StatsManager.lifetime_jumps() >= 1000)


func check_level_result(level_id: String, fields: Dictionary) -> void:
	# difficulty-tied achievements
	var difficulty: String = str(fields.get("difficulty", ""))
	match difficulty:
		"hard", "harder":
			_check("hard_clear", true)
		"insane":
			_check("hard_clear", true)
			_check("insane_clear", true)
		"extreme":
			_check("hard_clear", true)
			_check("insane_clear", true)
			_check("extreme_clear", true)
	if str(level_id).begins_with("boss"):
		_check("boss_clear", true)
	if int(fields.get("deaths", 0)) == 0 and bool(fields.get("completed", false)):
		_check("flawless", true)
	if bool(fields.get("no_jump", false)) and bool(fields.get("completed", false)):
		_check("no_jump", true)
	if int(fields.get("coins_found", 0)) > 0:
		_check("secret_1", true)
		if int(SaveManager.stat("secret_coins_collected")) >= 3:
			_check("secret_3", true)
	if bool(fields.get("all_coins", false)) and bool(fields.get("completed", false)):
		_check("all_coins", true)
	if bool(fields.get("practice", false)) and bool(fields.get("completed", false)):
		_check("practice_clear", true)
	if bool(fields.get("ghost_beaten", false)):
		_check("ghost_run", true)


func check_endless(distance: float) -> void:
	if distance >= 1000.0:
		_check("endless_1000", true)
	if distance >= 3000.0:
		_check("endless_3000", true)


func check_daily() -> void:
	_check("daily_first", true)


func check_editor(count: int) -> void:
	_check("editor_first", count >= 1)
	_check("editor_publish", count >= 5)


func _check(id: String, condition: bool) -> void:
	if not condition:
		return
	if SaveManager.has_achievement(id):
		return
	SaveManager.unlock_achievement(id)
	achievement_unlocked.emit(id)
	AudioManager.play_sfx("achievement", 0.9)
