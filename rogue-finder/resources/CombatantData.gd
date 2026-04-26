class_name CombatantData
extends Resource

## --- CombatantData ---
## Authoritative data record for every combatant (player or NPC).
## Stores identity, archetype link, core attributes, and slot data.
## All derived combat stats are computed properties — never stored directly.
##
## Analogy: archetype_id = the pokemon species (Pikachu), character_name = the nickname
## you gave it. Archetypes fix the class and artwork; everything else is randomized
## within per-archetype ranges by ArchetypeLibrary.create().

## ======================================================
## --- Identity ---
## ======================================================

@export var character_name: String  = "Unit"
## Key into ArchetypeLibrary. Determines allowed class, backgrounds,
## artwork, and attribute ranges. "RogueFinder" is reserved for the player character.
@export var archetype_id: String    = "generic"
@export var is_player_unit: bool    = false
## Species / ancestry (e.g. "Human", "Dwarf", "Gnome"). Fixed per archetype.
@export var kindred: String         = ""

## ======================================================
## --- Background & Class ---
## ======================================================

## Narrative origin. Chosen from the archetype's allowed pool at creation time.
@export var background: String  = ""
## Combat role. Fixed per archetype. e.g. "Rogue", "Barbarian", "Wizard".
@export var unit_class: String  = ""

## ======================================================
## --- Portrait (UI display — shown in StatPanel / UnitInfoBar) ---
## Falls back to the Godot icon if null. Replace with character art when available.
## ======================================================

@export var portrait: Texture2D = null

## ======================================================
## --- Artwork (placeholder paths — sprite sheets TBD) ---
## ======================================================

@export var artwork_idle: String   = ""
@export var artwork_attack: String = ""

## ======================================================
## --- Core Attributes (range 0–5) ---
## ======================================================

@export_range(0, 5) var strength:  int = 2  # Offensive power; drives attack
@export_range(0, 5) var dexterity: int = 2  # Agility; drives move speed
@export_range(0, 5) var cognition: int = 2  # Intelligence; reserved for ability costs
@export_range(0, 5) var willpower: int = 2  # Resolve; drives energy recharge
@export_range(0, 5) var vitality:  int = 2  # Toughness; drives HP and energy pool

## ======================================================
## --- Equipment Slots ---
## weapon / armor / accessory: null = unequipped.
## consumable: ID string into ConsumableLibrary; "" = none.
## ======================================================

@export var weapon:     EquipmentData = null
@export var armor:      EquipmentData = null
## consumable_id into ConsumableLibrary; "" = none
@export var consumable: String = ""
@export var accessory:  EquipmentData = null

## ======================================================
## --- Ability Slots ---
## Exactly 4 active ability IDs. Empty string = unfilled slot.
## This is the subset shown in the ActionMenu — not the full unlocked set.
## ======================================================

@export var abilities: Array[String] = ["", "", "", ""]

## ======================================================
## --- Persistent Run State ---
## These fields survive between combats. Fresh units are seeded by ArchetypeLibrary.create().
## Persisted to disk in Slice 2; types are JSON-friendly already.
## ======================================================

## Full unlocked ability set for this unit — superset of `abilities`.
@export var ability_pool: Array[String] = []

## All feats this unit has — kindred feat (index 0) plus any gained during the run.
## Replaces the old split of kindred_feat_id + feats. Populated by GameState.grant_feat().
@export var feat_ids: Array[String] = []

## Live HP that persists between combats. Seeded to hp_max at creation.
@export var current_hp: int = 0

## Live energy that persists between combats. Seeded to energy_max at creation.
@export var current_energy: int = 0

## Permanent death flag. Flipped by CombatManager3D; defaults false.
@export var is_dead: bool = false

## ======================================================
## --- Enemy-Only ---
## ======================================================

## Auto-resolve accuracy used to simulate the enemy's QTE (0.0 = always miss, 1.0 = perfect).
@export_range(0.0, 1.0) var qte_resolution: float = 0.3

## ======================================================
## --- Armor Defense ---
## Set by ArchetypeLibrary at creation time.
## ======================================================

@export var armor_defense: int = 5

## ======================================================
## Derived Stats — computed from core attributes + equipped items + feats
## ======================================================

## Sums a stat bonus across all three equipment slots.
func _equip_bonus(stat: String) -> int:
	return (weapon.get_bonus(stat)    if weapon    else 0) \
		 + (armor.get_bonus(stat)     if armor     else 0) \
		 + (accessory.get_bonus(stat) if accessory else 0)

## Sums a stat bonus across all owned feats. Never crashes — unknown feat returns {}.
func get_feat_stat_bonus(stat: String) -> int:
	var total: int = 0
	for feat_id in feat_ids:
		total += FeatLibrary.get_feat(feat_id).stat_bonuses.get(stat, 0)
	return total

## hp_max: flat 10 + kindred bonus + vitality*6. Feat/equip bonuses are flat additions.
var hp_max: int:
	get: return 10 + KindredLibrary.get_hp_bonus(kindred) + (vitality * 6) \
		+ _equip_bonus("vitality") + get_feat_stat_bonus("vitality")

## energy_max: 5 + vitality
var energy_max: int:
	get: return 5 + vitality + _equip_bonus("vitality") + get_feat_stat_bonus("vitality")

## energy_regen: energy restored at the start of each turn — 2 + willpower
var energy_regen: int:
	get: return 2 + willpower + _equip_bonus("willpower") + get_feat_stat_bonus("willpower")

## speed: movement range in grid cells — 1 + kindred bonus.
## DEX removed from base formula; reserved for dodge/evasion (future).
## Equipment/feat dexterity bonuses still flow through until a dedicated speed slot exists.
var speed: int:
	get: return 1 + KindredLibrary.get_speed_bonus(kindred) \
		+ _equip_bonus("dexterity") + get_feat_stat_bonus("dexterity")

## defense: armor_defense + any armor_defense bonuses from equipped items + feats.
var defense: int:
	get: return armor_defense + _equip_bonus("armor_defense") + get_feat_stat_bonus("armor_defense")

## attack: 5 + strength + any strength bonuses from equipped items + feats.
var attack: int:
	get: return 5 + strength + _equip_bonus("strength") + get_feat_stat_bonus("strength")

## unit_name: alias for character_name.
## Keeps HUD.gd and Unit3D.gd working without changes — they duck-type on this field.
var unit_name: String:
	get: return character_name
