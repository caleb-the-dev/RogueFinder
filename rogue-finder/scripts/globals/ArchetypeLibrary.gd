class_name ArchetypeLibrary
extends RefCounted

## --- ArchetypeLibrary ---
## Static archetype definitions and a factory that builds randomized CombatantData.
##
## Each archetype entry fixes: class, artwork paths, available backgrounds, ability pool.
## Numeric fields are given as [min, max] ranges — the factory rolls within them.
##
## Placeholder data only — a future CSV import will replace these constants.
## Adding a new archetype: add an entry to ARCHETYPES, nothing else needs to change.

## --- Archetype definition schema ---
## "class"          : String            — fixed class label
## "artwork_idle"   : String            — res:// path placeholder
## "artwork_attack" : String            — res:// path placeholder
## "backgrounds"    : Array[String]     — pool; one is chosen at random
## "abilities"      : Array             — fixed 4-slot list of ability IDs ("" = empty slot)
## "consumable"     : String            — item ID or display name ("" = none)
## "str_range"      : [min, max] int
## "dex_range"      : [min, max] int
## "cog_range"      : [min, max] int
## "wil_range"      : [min, max] int
## "vit_range"      : [min, max] int    — clamped to min 1 at creation
## "armor_range"    : [min, max] int    — placeholder until item system exists
## "qte_range"      : [min, max] float  — enemy-only auto-accuracy

const ARCHETYPES: Dictionary = {
	## RogueFinder — the player character. One per party; wide ranges for variety.
	"RogueFinder": {
		"class":          "Custom",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Noble", "Peasant", "Scholar", "Soldier", "Merchant"],
		"abilities":      ["strike", "guard", "fireball", "sweep"],
		"consumable":     "Smoke Vial",
		"str_range":      [1, 4],
		"dex_range":      [1, 4],
		"cog_range":      [1, 4],
		"wil_range":      [1, 4],
		"vit_range":      [2, 5],
		"armor_range":    [4, 8],
		"qte_range":      [0.0, 0.0],
	},
	## Quick, nimble brigand. High dex, low strength. Backgrounds limited to criminal/military.
	"archer_bandit": {
		"class":          "Rogue",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Crook", "Soldier"],
		"abilities":      ["quick_shot", "disengage", "piercing_shot", "gust"],
		"consumable":     "",
		"str_range":      [1, 2],
		"dex_range":      [3, 4],
		"cog_range":      [1, 2],
		"wil_range":      [0, 2],
		"vit_range":      [1, 3],
		"armor_range":    [3, 5],
		"qte_range":      [0.3, 0.5],
	},
	## Brawny melee fighter. High strength and vitality, low cognition.
	"grunt": {
		"class":          "Barbarian",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Crook", "Soldier"],
		"abilities":      ["heavy_strike", "charge", "", ""],
		"consumable":     "",
		"str_range":      [2, 4],
		"dex_range":      [1, 2],
		"cog_range":      [0, 1],
		"wil_range":      [0, 2],
		"vit_range":      [2, 4],
		"armor_range":    [4, 7],
		"qte_range":      [0.2, 0.5],
	},
	## Crafty support caster. High cognition, low strength. Broad background pool.
	"alchemist": {
		"class":          "Wizard",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Baker", "Scholar", "Merchant"],
		"abilities":      ["acid_splash", "smoke_bomb", "heal_burst", "fire_breath"],
		"consumable":     "Healing Potion",
		"str_range":      [0, 1],
		"dex_range":      [1, 3],
		"cog_range":      [3, 5],
		"wil_range":      [2, 4],
		"vit_range":      [1, 2],
		"armor_range":    [2, 4],
		"qte_range":      [0.5, 0.8],
	},
	## Heavily armored veteran. High strength, willpower, and vitality. Disciplined background only.
	"elite_guard": {
		"class":          "Warrior",
		"artwork_idle":   "",
		"artwork_attack": "",
		"backgrounds":    ["Soldier", "Noble"],
		"abilities":      ["shield_bash", "yank", "windblast", "sweep"],
		"consumable":     "",
		"str_range":      [3, 5],
		"dex_range":      [1, 3],
		"cog_range":      [1, 2],
		"wil_range":      [2, 4],
		"vit_range":      [3, 5],
		"armor_range":    [7, 10],
		"qte_range":      [0.6, 0.9],
	},
}

## --- Flavor name pools ---
## Used when is_player=true and no character_name is supplied (party allies auto-named).
## Enemies (is_player=false) are never auto-named — they show their archetype above their head.
const _NAME_POOLS: Dictionary = {
	"RogueFinder":  ["Hero"],
	"archer_bandit": ["Kale", "Sora", "Wren", "Dax", "Mira", "Fenn"],
	"grunt":         ["Brak", "Mord", "Thug", "Krak", "Uge", "Dorn"],
	"alchemist":     ["Finch", "Alda", "Quill", "Senna", "Pip", "Loris"],
	"elite_guard":   ["Sven", "Holt", "Cara", "Brix", "Edda", "Vale"],
}

## ======================================================
## Public API
## ======================================================

## Creates a fully randomized CombatantData for the given archetype.
##
## archetype_id  — must be a key in ARCHETYPES; falls back to "grunt" if unknown.
## character_name — optional override; if empty a flavor name is chosen from the pool.
## is_player     — sets is_player_unit on the result.
static func create(archetype_id: String, character_name: String = "",
		is_player: bool = false) -> CombatantData:
	var def: Dictionary = ARCHETYPES.get(archetype_id, ARCHETYPES["grunt"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var data := CombatantData.new()
	data.archetype_id   = archetype_id
	data.is_player_unit = is_player
	data.unit_class     = def["class"]
	data.artwork_idle   = def["artwork_idle"]
	data.artwork_attack = def["artwork_attack"]

	# Ability pool: copy so each instance is independent
	var ability_src: Array = def["abilities"]
	data.abilities.clear()
	for ab in ability_src:
		data.abilities.append(str(ab))
	# Pad to exactly 4 slots
	while data.abilities.size() < 4:
		data.abilities.append("")

	# Consumable item (empty string = none)
	data.consumable = def.get("consumable", "")

	# Random background from the archetype's allowed pool
	var bgs: Array = def["backgrounds"]
	data.background = bgs[rng.randi_range(0, bgs.size() - 1)]

	# Randomize core attributes within archetype ranges
	data.strength  = rng.randi_range(def["str_range"][0], def["str_range"][1])
	data.dexterity = rng.randi_range(def["dex_range"][0], def["dex_range"][1])
	data.cognition = rng.randi_range(def["cog_range"][0], def["cog_range"][1])
	data.willpower = rng.randi_range(def["wil_range"][0], def["wil_range"][1])
	data.vitality  = rng.randi_range(def["vit_range"][0], def["vit_range"][1])
	data.vitality  = maxi(1, data.vitality)  # guard: HP = 0 is invalid

	data.armor_defense  = rng.randi_range(def["armor_range"][0], def["armor_range"][1])
	data.qte_resolution = rng.randf_range(def["qte_range"][0], def["qte_range"][1])

	# Name: explicit override always wins.
	# Player units with no name get one from the flavor pool.
	# Enemy units with no name stay empty — Unit3D will show the archetype label instead.
	if character_name != "":
		data.character_name = character_name
	elif is_player:
		var pool: Array = _NAME_POOLS.get(archetype_id, ["Unit"])
		data.character_name = pool[rng.randi_range(0, pool.size() - 1)]
	else:
		data.character_name = ""

	return data
