extends Node

## --- Global Game State ---
## Autoloaded singleton (name: GameState) — tracks run-wide data.
## Stage 1.5: map traversal + save/load. Will expand to party roster, reputation, etc.

const SAVE_PATH := "user://save.json"

## --- Map Progress ---

var player_node_id: String = "badurga"
var visited_nodes: Array[String] = ["badurga"]
# Owned here so load_save() can restore it before MapManager seeds its RNG.
var map_seed: int = 0  # 0 = not yet seeded
var node_types: Dictionary = {}    # id -> String; populated by MapManager on first run, saved to disk
var pending_node_type: String = "" # consumed by NodeStub on scene entry; NOT saved to disk
var current_combat_node_id: String = "" # transient handoff to EndCombatScreen; NOT saved to disk
var cleared_nodes: Array[String] = []  # nodes where player won and collected reward; saved to disk
var threat_level: float = 0.0          # 0.0–1.0; rises on travel + entry; resets to 0 on BOSS defeat

## --- Party ---

var party: Array[CombatantData] = []  # index 0 = PC; empty = not yet initialized
var run_summary: Dictionary = {}      # populated before run-end transition; cleared on reset()

## --- Inventory (party bag) ---
## Stores raw reward dicts: {id, name, description, item_type}.
## item_type is "equipment" or "consumable" — used for tab filtering in the bag UI (Stage 2).
## Player assigns items from the bag manually; nothing is auto-equipped on pickup.

var inventory: Array = []

func add_to_inventory(item: Dictionary) -> void:
	inventory.append(item)
	print("[Inventory] Added '%s' (%s) — bag size: %d" % [item.get("id", "?"), item.get("item_type", "?"), inventory.size()])

## Removes the first entry whose id matches. Returns true if found and removed.
func remove_from_inventory(item_id: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			inventory.remove_at(i)
			return true
	return false

## Populates party with the PC + 2 allies. Guard ensures it is idempotent — safe to
## call from MapManager._ready() after load_save() regardless of save state.
func init_party() -> void:
	if not party.is_empty():
		return
	party.append(ArchetypeLibrary.create("RogueFinder", "Hero", true))
	party.append(ArchetypeLibrary.create("archer_bandit", "", true))
	party.append(ArchetypeLibrary.create("grunt", "", true))

# threat_level feeds into boss difficulty scaling — see Feature 8
func get_threat_level() -> float:
	return threat_level

func move_player(node_id: String) -> void:
	player_node_id = node_id
	if node_id not in visited_nodes:
		visited_nodes.append(node_id)

func is_visited(node_id: String) -> bool:
	return node_id in visited_nodes

# adjacency is passed in from MapManager to keep GameState decoupled from map-building data
func is_adjacent_to_player(node_id: String, adjacency: Dictionary) -> bool:
	var neighbors: Array = adjacency.get(player_node_id, [])
	return node_id in neighbors

## --- Save / Load ---

func save() -> void:
	var party_data: Array = []
	for member in party:
		party_data.append(_serialize_combatant(member))
	var data := {
		"player_node_id": player_node_id,
		"visited_nodes": visited_nodes,
		"map_seed": map_seed,
		"node_types": node_types,
		"cleared_nodes": cleared_nodes,
		"threat_level": threat_level,
		"party": party_data,
		"inventory": inventory,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func _serialize_combatant(d: CombatantData) -> Dictionary:
	return {
		"archetype_id":   d.archetype_id,
		"character_name": d.character_name,
		"is_player_unit": d.is_player_unit,
		"unit_class":     d.unit_class,
		"kindred":         d.kindred,
		"kindred_feat_id": d.kindred_feat_id,
		"background":     d.background,
		"strength":       d.strength,
		"dexterity":      d.dexterity,
		"cognition":      d.cognition,
		"willpower":      d.willpower,
		"vitality":       d.vitality,
		"armor_defense":  d.armor_defense,
		"qte_resolution": d.qte_resolution,
		"abilities":      d.abilities,
		"ability_pool":   d.ability_pool,
		"current_hp":     d.current_hp,
		"current_energy": d.current_energy,
		"is_dead":        d.is_dead,
		"consumable":     d.consumable,
		"weapon_id":      d.weapon.equipment_id if d.weapon else "",
		"armor_id":       d.armor.equipment_id if d.armor else "",
		"accessory_id":   d.accessory.equipment_id if d.accessory else "",
	}

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	player_node_id = parsed.get("player_node_id", "badurga")
	var raw_visited: Array = parsed.get("visited_nodes", ["badurga"])
	# JSON returns untyped Array; convert back to the typed form
	visited_nodes = Array(raw_visited, TYPE_STRING, "", null)
	map_seed = parsed.get("map_seed", 0)
	# Dictionary values are already strings from JSON; no typed conversion needed
	node_types = parsed.get("node_types", {})
	var raw_cleared: Array = parsed.get("cleared_nodes", [])
	cleared_nodes = Array(raw_cleared, TYPE_STRING, "", null)
	threat_level = float(parsed.get("threat_level", 0.0))
	party.clear()
	var raw_party: Array = parsed.get("party", [])
	for dict in raw_party:
		if dict is Dictionary:
			party.append(_deserialize_combatant(dict))
	inventory.clear()
	var raw_inv: Array = parsed.get("inventory", [])
	for entry in raw_inv:
		if entry is Dictionary:
			inventory.append(entry)
	return true

func _deserialize_combatant(dict: Dictionary) -> CombatantData:
	var d := CombatantData.new()
	d.archetype_id   = dict.get("archetype_id", "generic")
	d.character_name = dict.get("character_name", "Unit")
	d.is_player_unit = dict.get("is_player_unit", false)
	d.unit_class     = dict.get("unit_class", "")
	d.kindred         = dict.get("kindred", "Unknown")
	d.kindred_feat_id = dict.get("kindred_feat_id", "")
	d.background     = dict.get("background", "")
	d.strength       = dict.get("strength", 2)
	d.dexterity      = dict.get("dexterity", 2)
	d.cognition      = dict.get("cognition", 2)
	d.willpower      = dict.get("willpower", 2)
	d.vitality       = dict.get("vitality", 2)
	d.armor_defense  = dict.get("armor_defense", 5)
	d.qte_resolution = float(dict.get("qte_resolution", 0.3))
	var raw_abilities: Array = dict.get("abilities", [])
	d.abilities      = Array(raw_abilities, TYPE_STRING, "", null)
	var raw_pool: Array = dict.get("ability_pool", [])
	d.ability_pool   = Array(raw_pool, TYPE_STRING, "", null)
	d.current_hp     = dict.get("current_hp", 0)
	d.current_energy = dict.get("current_energy", 0)
	d.is_dead        = dict.get("is_dead", false)
	d.consumable     = dict.get("consumable", "")
	var weapon_id: String    = dict.get("weapon_id", "")
	d.weapon    = null if weapon_id    == "" else EquipmentLibrary.get_equipment(weapon_id)
	var armor_id: String     = dict.get("armor_id", "")
	d.armor     = null if armor_id     == "" else EquipmentLibrary.get_equipment(armor_id)
	var accessory_id: String = dict.get("accessory_id", "")
	d.accessory = null if accessory_id == "" else EquipmentLibrary.get_equipment(accessory_id)
	return d

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# Resets all in-memory fields to fresh-run defaults. Call before reload_current_scene()
# when wiping a save mid-session — load_save() does NOT reset fields on a missing file.
func reset() -> void:
	player_node_id = "badurga"
	visited_nodes = ["badurga"]
	map_seed = 0
	node_types = {}
	pending_node_type = ""
	current_combat_node_id = ""
	cleared_nodes = []
	threat_level = 0.0
	party = []
	run_summary = {}
	inventory = []
