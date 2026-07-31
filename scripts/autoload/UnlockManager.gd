extends Node
## UnlockManager - cosmetic unlockables (icon colors, trails) earned through
## achievements and coins. Provides the catalog for the icon shop.

const COLORS := {
	"cyan": {"name": "Neon Cyan", "color": Color("00e5ff"), "cost": 0},
	"magenta": {"name": "Shock Magenta", "color": Color("ff2fd6"), "cost": 25},
	"lime": {"name": "Volt Lime", "color": Color("69f0ae"), "cost": 25},
	"orange": {"name": "Blaze Orange", "color": Color("ffa726"), "cost": 40},
	"purple": {"name": "Void Purple", "color": Color("7c4dff"), "cost": 40},
	"red": {"name": "Ember Red", "color": Color("ff5252"), "cost": 60},
	"gold": {"name": "Champion Gold", "color": Color("ffd740"), "cost": 100},
	"white": {"name": "Arctic White", "color": Color("f5f5ff"), "cost": 150},
}

const TRAILS := {
	"standard": {"name": "Standard", "cost": 0},
	"spark": {"name": "Spark", "cost": 25},
	"ghost": {"name": "Ghost", "cost": 40},
	"flame": {"name": "Flame", "cost": 60},
	"rainbow": {"name": "Prism", "cost": 120},
}


func is_color_owned(c: String) -> bool:
	return SaveManager.owned_colors().has(c)


func is_trail_owned(t: String) -> bool:
	return SaveManager.owned_trails().has(t)


func buy_color(c: String) -> bool:
	if is_color_owned(c):
		return true
	if int(SaveManager.data["coins"]) < int(COLORS[c]["cost"]):
		return false
	SaveManager.data["coins"] = int(SaveManager.data["coins"]) - int(COLORS[c]["cost"])
	SaveManager.unlock_color(c)
	SaveManager.data["selected_icon"]["color"] = c
	SaveManager.save_game()
	return true


func buy_trail(t: String) -> bool:
	if is_trail_owned(t):
		return true
	if int(SaveManager.data["coins"]) < int(TRAILS[t]["cost"]):
		return false
	SaveManager.data["coins"] = int(SaveManager.data["coins"]) - int(TRAILS[t]["cost"])
	SaveManager.unlock_trail(t)
	SaveManager.data["selected_icon"]["trail"] = t
	SaveManager.save_game()
	return true


func select_color(c: String) -> void:
	if not is_color_owned(c):
		return
	SaveManager.data["selected_icon"]["color"] = c
	SaveManager.save_game()


func select_trail(t: String) -> void:
	if not is_trail_owned(t):
		return
	SaveManager.data["selected_icon"]["trail"] = t
	SaveManager.save_game()


func selected_color() -> Color:
	var c: String = str(SaveManager.data["selected_icon"]["color"])
	if not COLORS.has(c):
		c = "cyan"
	return COLORS[c]["color"]


func selected_trail() -> String:
	var t: String = str(SaveManager.data["selected_icon"]["trail"])
	if not TRAILS.has(t):
		t = "standard"
	return t
