class_name AbilityLibrary
extends RefCounted

## --- AbilityLibrary ---
## Static definitions for all abilities in the game.
## Mirrors ArchetypeLibrary's pattern: a Dictionary of dicts keyed by ability_id.
## A future CSV import will replace ABILITIES — get_ability() signature stays the same.
##
## Adding a new ability: add one entry to ABILITIES; nothing else changes.

## --- Schema ---
## "name"        : String
## "tags"        : Array[String]
## "cost"        : int
## "range"       : int
## "target"      : AbilityData.TargetType  (int)
## "description" : String

const ABILITIES: Dictionary = {
	"strike": {
		"name":        "Strike",
		"tags":        ["Melee"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Step into range and put your weight behind the blow — deal damage to one adjacent enemy.",
	},
	"heavy_strike": {
		"name":        "Heavy Strike",
		"tags":        ["Melee"],
		"cost":        4,
		"range":       1,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Wind up and swing with everything you have — hit one adjacent enemy for serious damage, but leave yourself wide open.",
	},
	"quick_shot": {
		"name":        "Quick Shot",
		"tags":        ["Ranged"],
		"cost":        2,
		"range":       4,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Draw and loose before the moment passes — deal damage to one enemy within 4 tiles.",
	},
	"disengage": {
		"name":        "Disengage",
		"tags":        ["Utility"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Step back with practiced care — reposition 1 tile without triggering opportunity attacks. (effect placeholder)",
	},
	"acid_splash": {
		"name":        "Acid Splash",
		"tags":        ["Magic", "Ranged"],
		"cost":        3,
		"range":       3,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Hurl a flask of sizzling reagent at one enemy within 3 tiles — their skin will remember it.",
	},
	"smoke_bomb": {
		"name":        "Smoke Bomb",
		"tags":        ["Utility"],
		"cost":        2,
		"range":       2,
		"target":      AbilityData.TargetType.AOE,
		"description": "Shatter a smoke-filled vial at a point within 2 tiles — obscure the area, granting concealment to all within. (effect placeholder)",
	},
	"healing_draught": {
		"name":        "Healing Draught",
		"tags":        ["Utility"],
		"cost":        3,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Uncork a bitter medicinal brew and down it — restore a measure of your own health. (effect placeholder)",
	},
	"shield_bash": {
		"name":        "Shield Bash",
		"tags":        ["Melee"],
		"cost":        3,
		"range":       1,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Lead with the rim of your shield — deal damage to one adjacent enemy and disrupt their footing.",
	},
	"counter": {
		"name":        "Counter",
		"tags":        ["Melee"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Plant your feet and watch for an opening — prepare a retaliatory strike against the next enemy that swings at you. (effect placeholder)",
	},
	"taunt": {
		"name":        "Taunt",
		"tags":        ["Utility"],
		"cost":        1,
		"range":       3,
		"target":      AbilityData.TargetType.SINGLE_ENEMY,
		"description": "Bark choice insults at a nearby enemy — force them to direct their next action at you, if able. (effect placeholder)",
	},
	"inspire": {
		"name":        "Inspire",
		"tags":        ["Utility"],
		"cost":        3,
		"range":       3,
		"target":      AbilityData.TargetType.SINGLE_ALLY,
		"description": "Shout a rallying cry — bolster one ally within 3 tiles, granting a bonus to their next attack. (effect placeholder)",
	},
	"guard": {
		"name":        "Guard",
		"tags":        ["Utility"],
		"cost":        2,
		"range":       1,
		"target":      AbilityData.TargetType.SELF,
		"description": "Adopt a defensive stance — reduce all incoming damage until the start of your next turn. (effect placeholder)",
	},
}

## Cached Godot icon — loaded once on first ability lookup.
static var _icon: Texture2D = null

static func _get_icon() -> Texture2D:
	if _icon == null:
		_icon = load("res://icon.svg")
	return _icon

## Returns a populated AbilityData for the given ID.
## Falls back to a blank stub if the ID is unknown — never returns null.
static func get_ability(ability_id: String) -> AbilityData:
	var godot_icon: Texture2D = _get_icon()
	if not ABILITIES.has(ability_id):
		var stub := AbilityData.new()
		stub.ability_id   = "unknown"
		stub.ability_name = "Unknown"
		stub.description  = "No ability data found for ID: " + ability_id
		stub.ability_icon = godot_icon
		return stub

	var def: Dictionary = ABILITIES[ability_id]
	var a := AbilityData.new()
	a.ability_id   = ability_id
	a.ability_name = def["name"]
	a.tags         = def["tags"].duplicate()
	a.energy_cost  = def["cost"]
	a.range        = def["range"]
	a.target_type  = def["target"]
	a.ability_icon = godot_icon
	a.description  = def["description"]
	return a
