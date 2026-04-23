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
## Key into ArchetypeLibrary.ARCHETYPES. Determines allowed class, backgrounds,
## artwork, and attribute ranges. "RogueFinder" is reserved for the player character.
@export var archetype_id: String    = "generic"
@export var is_player_unit: bool    = false
## Species / ancestry (e.g. "Human", "Dwarf", "Gnome"). Fixed per archetype.
@export var kindred: String         = ""

## ======================================================
## --- Background & Class (placeholder — CSV values TBD) ---
## ======================================================

## Narrative origin. Chosen from the archetype's allowed pool at creation time.
## e.g. "Crook" or "Soldier" for an Archer Bandit; "Baker" for an Alchemist.
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
## Grows as the unit unlocks new abilities (leveling is a future slice).
## Kept separate from `abilities` so the 4-slot active list is undisturbed when the pool grows.
@export var ability_pool: Array[String] = []

## Live HP that persists between combats. Seeded to hp_max at creation.
@export var current_hp: int = 0

## Live energy that persists between combats. Seeded to energy_max at creation.
@export var current_energy: int = 0

## Permanent death flag. Flipped by CombatManager3D in a later slice; defaults false.
@export var is_dead: bool = false

## ======================================================
## --- Enemy-Only ---
## ======================================================

## Auto-resolve accuracy used to simulate the enemy's QTE (0.0 = always miss, 1.0 = perfect).
@export_range(0.0, 1.0) var qte_resolution: float = 0.3

## ======================================================
## --- Armor Defense ---
## Set by ArchetypeLibrary at creation time; will be driven by the armor item in the future.
## ======================================================

@export var armor_defense: int = 5

## ======================================================
## Derived Stats — computed from core attributes + all equipped items
## ======================================================

## Sums a stat bonus across all three equipment slots.
func _equip_bonus(stat: String) -> int:
	return (weapon.get_bonus(stat)    if weapon    else 0) \
		 + (armor.get_bonus(stat)     if armor     else 0) \
		 + (accessory.get_bonus(stat) if accessory else 0)

## hp_max: 10 × vitality (vitality bonuses add linearly, not multiplicatively)
var hp_max: int:
	get: return 10 * vitality + _equip_bonus("vitality")

## energy_max: 5 + vitality
var energy_max: int:
	get: return 5 + vitality + _equip_bonus("vitality")

## energy_regen: energy restored at the start of each turn — 2 + willpower
var energy_regen: int:
	get: return 2 + willpower + _equip_bonus("willpower")

## speed: movement range in grid cells (Manhattan distance) — 2 + dexterity
## Named "speed" to stay compatible with Grid3D / CombatManager3D references.
var speed: int:
	get: return 2 + dexterity + _equip_bonus("dexterity")

## defense: armor_defense + any armor_defense bonuses from equipped items.
var defense: int:
	get: return armor_defense + _equip_bonus("armor_defense")

## attack: 5 + strength + any strength bonuses from equipped items.
var attack: int:
	get: return 5 + strength + _equip_bonus("strength")

## unit_name: alias for character_name.
## Keeps HUD.gd and Unit3D.gd working without changes — they duck-type on this field.
var unit_name: String:
	get: return character_name
