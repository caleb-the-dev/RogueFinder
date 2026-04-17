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
## --- Equipment Slots (placeholder strings — item system TBD) ---
## ======================================================

@export var weapon:     String = ""
@export var armor:      String = ""
## consumable_id into ConsumableLibrary; "" = none
@export var consumable: String = ""
@export var accessory:  String = ""

## ======================================================
## --- Ability Pool ---
## Exactly 4 slotted ability names. Empty string = unfilled slot.
## Ability system is TBD; strings are placeholders until then.
## ======================================================

@export var abilities: Array[String] = ["", "", "", ""]

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
## Derived Stats — computed from core attributes
## ======================================================

## hp_max: 10 × vitality
var hp_max: int:
	get: return 10 * vitality

## energy_max: 5 + vitality
var energy_max: int:
	get: return 5 + vitality

## energy_regen: energy restored at the start of each turn — 2 + willpower
var energy_regen: int:
	get: return 2 + willpower

## speed: movement range in grid cells (Manhattan distance) — 2 + dexterity
## Named "speed" to stay compatible with Grid3D / CombatManager3D references.
var speed: int:
	get: return 2 + dexterity

## defense: shorthand alias to armor_defense for CombatManager compatibility.
var defense: int:
	get: return armor_defense

## attack: base offensive power — 5 + strength.
## Will be refined by the equipped weapon in a future update.
var attack: int:
	get: return 5 + strength

## unit_name: alias for character_name.
## Keeps HUD.gd and Unit3D.gd working without changes — they duck-type on this field.
var unit_name: String:
	get: return character_name
