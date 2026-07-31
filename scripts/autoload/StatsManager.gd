extends Node
## StatsManager - tracks session and lifetime statistics. Wraps SaveManager.stats.

var session: Dictionary = {
	"jumps": 0, "deaths": 0, "coins": 0, "secret_coins": 0,
	"start_time": 0,
}


func _ready() -> void:
	session["start_time"] = Time.get_unix_time_from_system()


func add_jump() -> void:
	session["jumps"] += 1
	SaveManager.bump_stat("jumps")


func add_death() -> void:
	session["deaths"] += 1
	SaveManager.bump_stat("deaths")


func add_attempt() -> void:
	SaveManager.bump_stat("attempts")


func add_coin(secret := false) -> void:
	if secret:
		session["secret_coins"] += 1
		SaveManager.add_coins(1, true)
	else:
		session["coins"] += 1
		SaveManager.add_coins(1)


func level_completed() -> void:
	SaveManager.bump_stat("levels_completed")


func tick(dt: float) -> void:
	SaveManager.data["stats"]["time_played"] = float(SaveManager.stat("time_played")) + dt


func lifetime_jumps() -> int:
	return int(SaveManager.stat("jumps"))


func lifetime_deaths() -> int:
	return int(SaveManager.stat("deaths"))
