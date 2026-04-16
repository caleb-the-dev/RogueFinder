class_name AbilityLibrary
extends RefCounted

## --- AbilityLibrary ---
## Static definitions for all abilities in the game.
## Each entry has full effect data. A future CSV import will replace ABILITIES
## without changing the get_ability() signature.
##
## Adding an ability: add one entry to ABILITIES; nothing else changes.

## --- Schema ---
## "name"         : String
## "attribute"    : AbilityData.Attribute
## "target"       : AbilityData.TargetShape
## "applicable_to": AbilityData.ApplicableTo
## "range"        : int  (-1 = whole map)
## "passthrough"  : bool (optional, default false)
## "cost"         : int
## "description"  : String
## "effects"      : Array[Dictionary]
##   Each effect dict keys:
##     "type"       : EffectData.EffectType  (required)
##     "base_value" : int                    (required)
##     "pool"       : EffectData.PoolType    (HARM / MEND only)
##     "stat"       : AbilityData.Attribute  (BUFF / DEBUFF only)
##     "move"       : EffectData.MoveType    (TRAVEL only)
##     "force"      : EffectData.ForceType   (FORCE only)

const ABILITIES: Dictionary = {
	"strike": {
		"name":          "Strike",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          2,
		"description":   "Step into range and put your weight behind the blow — deal damage to one adjacent enemy.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 5, "pool": EffectData.PoolType.HP },
		],
	},
	"heavy_strike": {
		"name":          "Heavy Strike",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          4,
		"description":   "Wind up and swing with everything you have — hit one adjacent enemy for serious damage.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 9, "pool": EffectData.PoolType.HP },
		],
	},
	"quick_shot": {
		"name":          "Quick Shot",
		"attribute":     AbilityData.Attribute.DEXTERITY,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         4,
		"cost":          2,
		"description":   "Draw and loose before the moment passes — deal damage to one enemy within 4 tiles.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 4, "pool": EffectData.PoolType.HP },
		],
	},
	"disengage": {
		"name":          "Disengage",
		"attribute":     AbilityData.Attribute.DEXTERITY,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         1,
		"cost":          2,
		"description":   "Step back with practiced care — reposition 1 tile without triggering opportunity attacks.",
		"effects": [
			{ "type": EffectData.EffectType.TRAVEL, "base_value": 1, "move": EffectData.MoveType.FREE },
		],
	},
	"acid_splash": {
		"name":          "Acid Splash",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         3,
		"cost":          3,
		"description":   "Hurl a flask of sizzling reagent — damages on contact and eats through the target's dexterity.",
		"effects": [
			{ "type": EffectData.EffectType.HARM,   "base_value": 3, "pool": EffectData.PoolType.HP },
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.DEXTERITY },
		],
	},
	"smoke_bomb": {
		"name":          "Smoke Bomb",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.RADIAL,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         2,
		"cost":          2,
		"description":   "Shatter a smoke-filled vial — all units in the blast radius lose footing and dexterity.",
		"effects": [
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.DEXTERITY },
		],
	},
	"healing_draught": {
		"name":          "Healing Draught",
		"attribute":     AbilityData.Attribute.VITALITY,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         0,
		"cost":          3,
		"description":   "Uncork a bitter medicinal brew and down it — restore a measure of your own health.",
		"effects": [
			{ "type": EffectData.EffectType.MEND, "base_value": 5, "pool": EffectData.PoolType.HP },
		],
	},
	"shield_bash": {
		"name":          "Shield Bash",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          3,
		"description":   "Lead with the rim of your shield — deal damage and disrupt the target's offensive strength.",
		"effects": [
			{ "type": EffectData.EffectType.HARM,   "base_value": 3, "pool": EffectData.PoolType.HP },
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.STRENGTH },
		],
	},
	"counter": {
		"name":          "Counter",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         0,
		"cost":          2,
		"description":   "Plant your feet and channel your resolve — temporarily sharpen your offensive strength.",
		"effects": [
			{ "type": EffectData.EffectType.BUFF, "base_value": 2, "stat": AbilityData.Attribute.STRENGTH },
		],
	},
	"taunt": {
		"name":          "Taunt",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         3,
		"cost":          1,
		"description":   "Bark choice insults at a nearby enemy — sap their resolve and force their attention onto you.",
		"effects": [
			{ "type": EffectData.EffectType.DEBUFF, "base_value": 1, "stat": AbilityData.Attribute.WILLPOWER },
		],
	},
	"inspire": {
		"name":          "Inspire",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ALLY,
		"range":         3,
		"cost":          3,
		"description":   "Shout a rallying cry — bolster one ally's strength for the fight ahead.",
		"effects": [
			{ "type": EffectData.EffectType.BUFF, "base_value": 1, "stat": AbilityData.Attribute.STRENGTH },
		],
	},
	"guard": {
		"name":          "Guard",
		"attribute":     AbilityData.Attribute.VITALITY,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         0,
		"cost":          2,
		"description":   "Adopt a defensive stance — bolster your vitality to weather incoming blows.",
		"effects": [
			{ "type": EffectData.EffectType.BUFF, "base_value": 2, "stat": AbilityData.Attribute.VITALITY },
		],
	},
	"sweep": {
		"name":          "Sweep",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.ARC,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          3,
		"description":   "Drag your weapon in a wide arc — hits every enemy in a 3-wide arc directly in front of you.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 4, "pool": EffectData.PoolType.HP },
		],
	},
	## --- Fireball: RADIAL + ANY + HARM (hurts allies and enemies; passthrough=false) ---
	"fireball": {
		"name":          "Fireball",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.RADIAL,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         4,
		"passthrough":   false,
		"cost":          5,
		"description":   "Hurl a sphere of roiling fire — scorches everything in the blast, allies included. Inner units shield those behind them.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 6, "pool": EffectData.PoolType.HP },
		],
	},
	## --- Heal Burst: RADIAL + ALLY + MEND ---
	"heal_burst": {
		"name":          "Heal Burst",
		"attribute":     AbilityData.Attribute.WILLPOWER,
		"target":        AbilityData.TargetShape.RADIAL,
		"applicable_to": AbilityData.ApplicableTo.ALLY,
		"range":         2,
		"passthrough":   true,
		"cost":          4,
		"description":   "Release a wave of restorative energy — heals all allies caught in the pulse.",
		"effects": [
			{ "type": EffectData.EffectType.MEND, "base_value": 5, "pool": EffectData.PoolType.HP },
		],
	},
	## --- Charge: SELF + TRAVEL/LINE (dash in a straight line) ---
	"charge": {
		"name":          "Charge",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SELF,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         3,
		"cost":          2,
		"description":   "Burst forward in a straight line — close the gap in one powerful rush.",
		"effects": [
			{ "type": EffectData.EffectType.TRAVEL, "base_value": 3, "move": EffectData.MoveType.LINE },
		],
	},
	## --- Gust: SINGLE + ANY + FORCE/PUSH ---
	"gust": {
		"name":          "Gust",
		"attribute":     AbilityData.Attribute.DEXTERITY,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         3,
		"cost":          2,
		"description":   "Blast a target with a focused burst of wind — knock them 2 tiles directly away.",
		"effects": [
			{ "type": EffectData.EffectType.FORCE, "base_value": 2, "force": EffectData.ForceType.PUSH },
		],
	},
	## --- Yank: SINGLE + ANY + FORCE/PULL ---
	"yank": {
		"name":          "Yank",
		"attribute":     AbilityData.Attribute.STRENGTH,
		"target":        AbilityData.TargetShape.SINGLE,
		"applicable_to": AbilityData.ApplicableTo.ANY,
		"range":         3,
		"cost":          2,
		"description":   "Grab and haul a target 2 tiles toward you — close range on a retreating foe.",
		"effects": [
			{ "type": EffectData.EffectType.FORCE, "base_value": 2, "force": EffectData.ForceType.PULL },
		],
	},
	## --- Windblast: RADIAL + ENEMY + FORCE/RADIAL (push all outward from center) ---
	"windblast": {
		"name":          "Windblast",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.RADIAL,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         3,
		"passthrough":   true,
		"cost":          3,
		"description":   "Unleash a radial burst of force — blasts every enemy outward from the point of impact.",
		"effects": [
			{ "type": EffectData.EffectType.FORCE, "base_value": 2, "force": EffectData.ForceType.RADIAL },
		],
	},
	"fire_breath": {
		"name":          "Fire Breath",
		"attribute":     AbilityData.Attribute.COGNITION,
		"target":        AbilityData.TargetShape.CONE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         1,
		"cost":          4,
		"description":   "Exhale a torrent of flame — scorches all enemies in an expanding triangle up to 3 tiles deep.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 5, "pool": EffectData.PoolType.HP },
		],
	},
	"piercing_shot": {
		"name":          "Piercing Shot",
		"attribute":     AbilityData.Attribute.DEXTERITY,
		"target":        AbilityData.TargetShape.LINE,
		"applicable_to": AbilityData.ApplicableTo.ENEMY,
		"range":         6,
		"passthrough":   true,
		"cost":          3,
		"description":   "Draw and loose with full force — the bolt punches through every enemy in a straight line.",
		"effects": [
			{ "type": EffectData.EffectType.HARM, "base_value": 4, "pool": EffectData.PoolType.HP },
		],
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
	a.ability_id    = ability_id
	a.ability_name  = def["name"]
	a.attribute     = def["attribute"]
	a.target_shape  = def["target"]
	a.applicable_to = def["applicable_to"]
	a.tile_range    = def["range"]
	a.passthrough   = def.get("passthrough", false)
	a.energy_cost   = def["cost"]
	a.description   = def["description"]
	a.ability_icon  = godot_icon

	## Build EffectData instances from nested dicts
	for effect_def: Dictionary in def["effects"]:
		var e := EffectData.new()
		e.effect_type = effect_def["type"]
		e.base_value  = effect_def.get("base_value", 0)
		if effect_def.has("pool"):
			e.target_pool = effect_def["pool"]
		if effect_def.has("stat"):
			e.target_stat = effect_def["stat"]
		if effect_def.has("move"):
			e.movement_type = effect_def["move"]
		if effect_def.has("force"):
			e.force_type = effect_def["force"]
		a.effects.append(e)

	return a
