extends Node
## ThemeManager - color themes that drive level backgrounds, UI accents and
## the global palette. Themes are data-driven for easy modding.

signal theme_changed(theme_name: String)

const THEMES := {
	"cyber": {
		"name": "Neon Core",
		"bg_top": Color("070a18"), "bg_bottom": Color("0d1230"),
		"accent": Color("00e5ff"), "accent2": Color("ff2fd6"),
		"ground": "block_cyan", "hazard": "block_red",
		"glow": Color("00e5ff"),
	},
	"sunset": {
		"name": "Sunset Grid",
		"bg_top": Color("1a0a24"), "bg_bottom": Color("3a1230"),
		"accent": Color("ffa726"), "accent2": Color("ff5252"),
		"ground": "block_orange", "hazard": "block_red",
		"glow": Color("ffa726"),
	},
	"forest": {
		"name": "Verdant Flow",
		"bg_top": Color("04120c"), "bg_bottom": Color("0a2418"),
		"accent": Color("69f0ae"), "accent2": Color("00e5ff"),
		"ground": "block_lime", "hazard": "block_red",
		"glow": Color("69f0ae"),
	},
	"void": {
		"name": "Deep Void",
		"bg_top": Color("05030f"), "bg_bottom": Color("12083a"),
		"accent": Color("7c4dff"), "accent2": Color("ff2fd6"),
		"ground": "block_purple", "hazard": "block_red",
		"glow": Color("7c4dff"),
	},
	"ember": {
		"name": "Ember Forge",
		"bg_top": Color("160505"), "bg_bottom": Color("381008"),
		"accent": Color("ff5252"), "accent2": Color("ffa726"),
		"ground": "block_red", "hazard": "block_red",
		"glow": Color("ff5252"),
	},
	"ice": {
		"name": "Cryo Lab",
		"bg_top": Color("031018"), "bg_bottom": Color("082838"),
		"accent": Color("9fd8ff"), "accent2": Color("00e5ff"),
		"ground": "block_white", "hazard": "block_red",
		"glow": Color("9fd8ff"),
	},
	"mono": {
		"name": "Monochrome",
		"bg_top": Color("0a0a0a"), "bg_bottom": Color("181818"),
		"accent": Color("e8e8f0"), "accent2": Color("9090a0"),
		"ground": "block_gray", "hazard": "block_gray",
		"glow": Color("e8e8f0"),
	},
}

var current: Dictionary = THEMES["cyber"]
var current_name := "cyber"


func set_theme(name: String) -> void:
	if not THEMES.has(name):
		name = "cyber"
	current = THEMES[name]
	current_name = name
	theme_changed.emit(name)


func accent_pulse(strength := 1.0) -> Color:
	var c: Color = current["accent"]
	return Color(c.r, c.g, c.b, 0.15 + 0.25 * strength)


func next_theme() -> String:
	var keys := THEMES.keys()
	var i := keys.find(current_name)
	return keys[(i + 1) % keys.size()]
