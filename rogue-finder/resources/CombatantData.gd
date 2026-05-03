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
## Pokémon-style personality modifier. Randomly assigned at creation; never changes.
## Gives +1 to one attribute and -1 to another (or no effect for "even").
@export var temperament_id: String = ""

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
## --- Core Attributes (range 1–10) ---
## ======================================================

@export_range(1, 10) var strength:  int = 4  # Offensive power; scales STR-based abilities
@export_range(1, 10) var dexterity: int = 4  # Agility; drives move speed
@export_range(1, 10) var cognition: int = 4  # Intelligence; reserved for ability costs
@export_range(1, 10) var willpower: int = 4  # Resolve; drives energy recharge
@export_range(1, 10) var vitality:  int = 4  # Toughness; drives HP and energy pool
@export_range(1, 10) var spd:       int = 4  # Speed; drives countdown_max in autobattler

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

## Level-up progress. level/xp drive the XP threshold ladder; pending_level_ups accumulates
## while in combat and is consumed one at a time via the PartySheet select-3 overlay.
@export var level:             int = 1
@export var xp:                int = 0
@export var pending_level_ups: int = 0

## Live HP that persists between combats. Seeded to hp_max at creation.
@export var current_hp: int = 0

## Permanent death flag. Flipped by CombatManagerAuto; defaults false.
@export var is_dead: bool = false

## ======================================================
## --- Enemy-Only ---
## ======================================================

## Auto-resolve accuracy used to simulate the enemy's QTE (0.0 = always miss, 1.0 = perfect).
@export_range(0.0, 1.0) var qte_resolution: float = 0.3

## ======================================================
## --- Armor ---
## Both fields set by ArchetypeLibrary at creation time.
## physical_armor resists PHYSICAL HARM; magic_armor resists MAGIC HARM.
## ======================================================

@export var physical_armor: int = 3
@export var magic_armor:    int = 2

## --- Mid-combat armor mods (transient — not serialized) ---
## Set by BUFF/DEBUFF effects targeting PHYSICAL_ARMOR_MOD / MAGIC_ARMOR_MOD.
## Snapshotted by CombatManager3D._setup_units() and rolled back in _end_combat()
## via _attr_snapshots, so they always default to 0 outside of combat.
## NOT saved to disk — combat state is transient.
var physical_armor_mod: int = 0
var magic_armor_mod:    int = 0

## --- Transient autobattler state (NOT serialized) ---
## countdown_current ticks down each combat tick; when 0, the unit acts.
## countdown_max is computed from effective_stat("spd") at combat start.
## cooldowns tracks per-slot cooldown remaining (one entry per slot, 3 slots).
var countdown_current: int = 0
var countdown_max:     int = 0
var cooldowns:         Array[int] = [0, 0, 0]

## Ability IDs added since the party sheet was last opened — used for the glow badge.
## Cleared on hover in the party sheet. Not saved to disk.
var new_ability_ids: Array[String] = []

## ======================================================
## Derived Stats — computed from core attributes + equipped items + feats
## ======================================================

## Public wrapper — returns the total stat_bonuses contribution from all three equipment slots.
func get_equip_bonus(stat: String) -> int:
	return _equip_bonus(stat)

## Sums a stat bonus across all three equipment slots.
func _equip_bonus(stat: String) -> int:
	return (weapon.get_bonus(stat)    if weapon    else 0) \
		 + (armor.get_bonus(stat)     if armor     else 0) \
		 + (accessory.get_bonus(stat) if accessory else 0)

## Sums a stat bonus across all owned feats plus the equipped accessory's feat (if any).
## Deduplicates: if the accessory's feat_id already appears in feat_ids it counts once.
func get_feat_stat_bonus(stat: String) -> int:
	var seen: Dictionary = {}
	var total: int = 0
	for id in feat_ids:
		if not seen.has(id):
			seen[id] = true
			total += FeatLibrary.get_feat(id).stat_bonuses.get(stat, 0)
	if accessory != null and accessory.feat_id != "":
		if not seen.has(accessory.feat_id):
			total += FeatLibrary.get_feat(accessory.feat_id).stat_bonuses.get(stat, 0)
	return total

## Returns the flat stat bonus from the unit's class. Stubs to 0 for unknown class IDs.
func get_class_stat_bonus(stat: String) -> int:
	return ClassLibrary.get_class_data(unit_class).stat_bonuses.get(stat, 0)

## Returns the flat stat bonus from the unit's kindred. Stubs to 0 for unknown kindred/stat.
func get_kindred_stat_bonus(stat: String) -> int:
	return KindredLibrary.get_stat_bonus(kindred, stat)

## Returns the flat stat bonus from the unit's background. Stubs to 0 for unknown bg/stat.
func get_background_stat_bonus(stat: String) -> int:
	return BackgroundLibrary.get_background(background).stat_bonuses.get(stat, 0)

## Returns +1 if stat is the temperament's boosted_stat, -1 if it's the hindered_stat, else 0.
func get_temperament_stat_bonus(stat: String) -> int:
	var t: TemperamentData = TemperamentLibrary.get_temperament(temperament_id)
	if t.boosted_stat  == stat and stat != "": return  1
	if t.hindered_stat == stat and stat != "": return -1
	return 0

## hp_max: flat 10 + kindred bonus + vitality*4. Feat/equip/class/kindred/bg bonuses are flat additions.
## Multiplier is 4 (not 6) to keep HP in the 14–50 range with the 1–10 attribute scale.
var hp_max: int:
	get: return 10 + KindredLibrary.get_hp_bonus(kindred) + (vitality * 4) \
		+ _equip_bonus("vitality") + get_feat_stat_bonus("vitality") \
		+ get_class_stat_bonus("vitality") + get_kindred_stat_bonus("vitality") \
		+ get_background_stat_bonus("vitality") + get_temperament_stat_bonus("vitality")

## physical_defense: resists PHYSICAL HARM — base + transient mod + 5 pillar bonuses keyed "physical_armor".
var physical_defense: int:
	get: return physical_armor + physical_armor_mod \
		+ _equip_bonus("physical_armor") + get_feat_stat_bonus("physical_armor") \
		+ get_class_stat_bonus("physical_armor") + get_kindred_stat_bonus("physical_armor") \
		+ get_background_stat_bonus("physical_armor")

## magic_defense: resists MAGIC HARM — base + transient mod + 5 pillar bonuses keyed "magic_armor".
var magic_defense: int:
	get: return magic_armor + magic_armor_mod \
		+ _equip_bonus("magic_armor") + get_feat_stat_bonus("magic_armor") \
		+ get_class_stat_bonus("magic_armor") + get_kindred_stat_bonus("magic_armor") \
		+ get_background_stat_bonus("magic_armor")

## effective_stat: returns raw attribute + all bonus sources (equip/feat/class/kindred/bg/temp).
## Used by the HARM formula so ability scaling uses the same stat total the player sees on the sheet.
func effective_stat(stat: String) -> int:
	var raw: int
	match stat:
		"strength":  raw = strength
		"dexterity": raw = dexterity
		"cognition": raw = cognition
		"vitality":  raw = vitality
		"willpower": raw = willpower
		"spd":       raw = spd
		_: return 0
	return raw + _equip_bonus(stat) + get_feat_stat_bonus(stat) + get_class_stat_bonus(stat) \
		+ get_kindred_stat_bonus(stat) + get_background_stat_bonus(stat) + get_temperament_stat_bonus(stat)

## unit_name: alias for character_name.
## Keeps HUD.gd and Unit3D.gd working without changes — they duck-type on this field.
var unit_name: String:
	get: return character_name

## ======================================================
## --- Equipment Pool Lifecycle ---
## Call on_equip before setting the slot; call on_unequip before clearing it.
## These manage granted_ability_ids in ability_pool without touching active ability slots.
## ======================================================

## Adds each id in eq.granted_ability_ids to ability_pool (deduped). Safe to call on items
## with empty granted_ability_ids (armor, accessories) — no-op in that case.
func on_equip(eq: EquipmentData) -> void:
	for aid: String in eq.granted_ability_ids:
		if aid != "" and not ability_pool.has(aid):
			ability_pool.append(aid)

## Removes each id in eq.granted_ability_ids from ability_pool AND clears any active slot
## that holds the ability. The player does not keep granted abilities after unequipping.
func on_unequip(eq: EquipmentData) -> void:
	for aid: String in eq.granted_ability_ids:
		if aid == "":
			continue
		for i in abilities.size():
			if abilities[i] == aid:
				abilities[i] = ""
		ability_pool.erase(aid)
