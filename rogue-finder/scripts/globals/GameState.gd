extends Node

## --- Global Game State ---
## Autoloaded singleton (name: GameState) — tracks run-wide data.
## Stage 1.5: map traversal + save/load. Will expand to party roster, reputation, etc.

const SAVE_PATH := "user://save.json"

const XP_THRESHOLDS: Array[int] = [20, 35, 55, 80]

## --- Map Progress ---

var player_node_id: String = "badurga"
var visited_nodes: Array[String] = ["badurga"]
# Owned here so load_save() can restore it before MapManager seeds its RNG.
var map_seed: int = 0  # 0 = not yet seeded
var node_types: Dictionary = {}    # id -> String; populated by MapManager on first run, saved to disk
var pending_node_type: String = "" # consumed by NodeStub on scene entry; NOT saved to disk
var current_combat_node_id: String = "" # transient handoff to EndCombatScreen; NOT saved to disk
var current_combat_ring: String = ""    # transient ring name ("inner"/"middle"/"outer"); NOT saved to disk
var cleared_nodes: Array[String] = []  # nodes where player won and collected reward; saved to disk
var threat_level: float = 0.0          # 0.0–1.0; rises on travel + entry; resets to 0 on BOSS defeat
var used_event_ids: Array[String] = [] # event ids drawn this run; used by EventSelector for no-repeat logic; saved to disk
var encountered_archetypes: Array[String] = [] # archetype ids seen in combat or recruited this run; drives the Archetypes Log
var recruited_archetypes:  Array[String] = [] # archetype ids ever added to the bench (persists across bench releases)

## --- Party ---

var party: Array[CombatantData] = []  # index 0 = PC; empty = not yet initialized
var run_summary: Dictionary = {}      # populated before run-end transition; cleared on reset()

## --- Economy ---

var gold: int = 0

## --- Vendor Stocks ---
## Pre-rolled per-vendor manifests. Keyed by instance_key:
##   CITY vendors → vendor_id (e.g. "vendor_weapon")
##   WORLD vendors → node_id  (e.g. "node_o3")
## Each value is Array of { vendor_id, item, price, sold }.
## Populated by MapManager._generate_vendor_stocks() on map-gen; never re-rolled mid-run.
var vendor_stocks: Dictionary = {}

## Regenerates ONLY WORLD vendor stocks (keyed by VENDOR node_ids in node_types).
## CITY stocks (keyed by vendor_id) are left untouched.
## Future map-reset cycle (every 3 boss wins) will call this — trigger not wired yet.
func regen_world_vendor_stocks() -> void:
	var world_vendors: Array[VendorData] = VendorLibrary.vendors_by_scope("WORLD")
	if world_vendors.is_empty():
		return
	for node_id: String in node_types.keys():
		if node_types[node_id] != "VENDOR":
			continue
		var vendor_idx: int = posmod(hash(str(map_seed) + node_id), world_vendors.size())
		var vendor: VendorData = world_vendors[vendor_idx]
		var seed_int: int = hash(str(map_seed) + "::" + node_id)
		vendor_stocks[node_id] = StockGenerator.roll_stock(vendor, seed_int)
	save()

## --- Followers / Bench ---
## Followers captured in combat. Saved to disk via save()/load_save().

const BENCH_CAP: int = 9

var bench: Array[CombatantData] = []

func add_to_bench(follower: CombatantData) -> bool:
	if bench.size() >= BENCH_CAP:
		return false
	bench.append(follower)
	record_recruited_archetype(follower.archetype_id)
	return true

## Swaps party[party_idx] with bench[bench_idx] in-place. Gear deequip is the
## caller's responsibility (BadurgaManager calls _deequip_to_bag first).
func swap_active_bench(party_idx: int, bench_idx: int) -> void:
	if party_idx < 0 or party_idx >= party.size():
		return
	if bench_idx < 0 or bench_idx >= bench.size():
		return
	var tmp: CombatantData = party[party_idx]
	party[party_idx]  = bench[bench_idx]
	bench[bench_idx]  = tmp

## Removes the bench entry at index. Auto-deequips gear back to inventory. Saves.
func release_from_bench(index: int) -> void:
	if index < 0 or index >= bench.size():
		return
	var follower: CombatantData = bench[index]
	if follower.weapon:
		follower.on_unequip(follower.weapon)
		add_to_inventory({"id": follower.weapon.equipment_id,
			"name": follower.weapon.equipment_name,
			"description": follower.weapon.description,
			"item_type": "equipment", "rarity": follower.weapon.rarity})
		follower.weapon = null
	if follower.armor:
		follower.on_unequip(follower.armor)
		add_to_inventory({"id": follower.armor.equipment_id,
			"name": follower.armor.equipment_name,
			"description": follower.armor.description,
			"item_type": "equipment", "rarity": follower.armor.rarity})
		follower.armor = null
	if follower.accessory:
		follower.on_unequip(follower.accessory)
		add_to_inventory({"id": follower.accessory.equipment_id,
			"name": follower.accessory.equipment_name,
			"description": follower.accessory.description,
			"item_type": "equipment", "rarity": follower.accessory.rarity})
		follower.accessory = null
	bench.remove_at(index)
	save()

## Transient — never saved. Set true before entering the test combat room from the dev menu.
## CombatManager3D reads it to spawn hardcoded test units instead of GameState.party.
var test_room_mode: bool = false

## Which test room scenario to spawn — read by CombatManager3D when test_room_mode is true.
## Valid values: "armor_showcase" (dual-armor: phys/magic damage vs phys/magic-armored enemies),
## "armor_mod" (BUFF/DEBUFF showcase featuring stone_guard + divine_ward).
## Reset to default in CombatManager3D._end_combat() so the next normal combat is unaffected.
var test_room_kind: String = "armor_showcase"

## --- Inventory (party bag) ---
## Stores raw reward dicts: {id, name, description, item_type}.
## item_type is "equipment" or "consumable" — used for tab filtering in the bag UI (Stage 2).
## Player assigns items from the bag manually; nothing is auto-equipped on pickup.

var inventory: Array = []

func add_to_inventory(item: Dictionary) -> void:
	item["seen"] = false
	inventory.append(item)
	print("[Inventory] Added '%s' (%s) — bag size: %d" % [item.get("id", "?"), item.get("item_type", "?"), inventory.size()])

## Removes the first entry whose id matches. Returns true if found and removed.
func remove_from_inventory(item_id: String) -> bool:
	for i in range(inventory.size()):
		if inventory[i].get("id", "") == item_id:
			inventory.remove_at(i)
			return true
	return false

## Populates party with a default PC. Guard ensures it is idempotent — safe to
## call from MapManager._ready() after load_save() regardless of save state.
## After character creation is live this path fires only as a safety fallback.
func init_party() -> void:
	if not party.is_empty():
		return
	party.append(ArchetypeLibrary.create("RogueFinder", "Hero", true))

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
		"used_event_ids": used_event_ids,
		"encountered_archetypes": encountered_archetypes,
		"recruited_archetypes":  recruited_archetypes,
		"party": party_data,
		"bench": bench.map(func(f: CombatantData) -> Dictionary: return _serialize_combatant(f)),
		"inventory":      inventory,
		"gold":           gold,
		"vendor_stocks":  vendor_stocks,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func _serialize_combatant(d: CombatantData) -> Dictionary:
	return {
		"archetype_id":   d.archetype_id,
		"character_name": d.character_name,
		"is_player_unit": d.is_player_unit,
		"unit_class":     d.unit_class,
		"kindred":        d.kindred,
		"background":     d.background,
		"temperament_id": d.temperament_id,
		"strength":       d.strength,
		"dexterity":      d.dexterity,
		"cognition":      d.cognition,
		"willpower":      d.willpower,
		"vitality":       d.vitality,
		"spd":            d.spd,
		"physical_armor": d.physical_armor,
		"magic_armor":    d.magic_armor,
		"qte_resolution": d.qte_resolution,
		"abilities":      d.abilities,
		"ability_pool":   d.ability_pool,
		"feat_ids":       Array(d.feat_ids),
		"level":          d.level,
		"xp":             d.xp,
		"pending_level_ups": d.pending_level_ups,
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
	var raw_event_ids: Array = parsed.get("used_event_ids", [])
	used_event_ids = Array(raw_event_ids, TYPE_STRING, "", null)
	var raw_archetypes: Array = parsed.get("encountered_archetypes", [])
	encountered_archetypes = Array(raw_archetypes, TYPE_STRING, "", null)
	var raw_recruited: Array = parsed.get("recruited_archetypes", [])
	recruited_archetypes = Array(raw_recruited, TYPE_STRING, "", null)
	party.clear()
	var raw_party: Array = parsed.get("party", [])
	for dict in raw_party:
		if dict is Dictionary:
			party.append(_deserialize_combatant(dict))
	bench.clear()
	var raw_bench: Array = parsed.get("bench", [])
	for dict in raw_bench:
		if dict is Dictionary:
			bench.append(_deserialize_combatant(dict))
	inventory.clear()
	var raw_inv: Array = parsed.get("inventory", [])
	for entry in raw_inv:
		if entry is Dictionary:
			inventory.append(entry)
	gold = int(parsed.get("gold", 0))
	vendor_stocks = {}
	var raw_stocks = parsed.get("vendor_stocks", {})
	if raw_stocks is Dictionary:
		for key: String in raw_stocks.keys():
			var raw_arr = raw_stocks[key]
			if raw_arr is Array:
				var arr: Array = []
				for entry in raw_arr:
					if entry is Dictionary:
						arr.append(entry)
				vendor_stocks[key] = arr
	return true

func _deserialize_combatant(dict: Dictionary) -> CombatantData:
	var d := CombatantData.new()
	d.archetype_id   = dict.get("archetype_id", "generic")
	d.character_name = dict.get("character_name", "Unit")
	d.is_player_unit = dict.get("is_player_unit", false)
	d.unit_class     = dict.get("unit_class", "")
	d.kindred        = dict.get("kindred", "Unknown")
	d.background     = dict.get("background", "")
	d.temperament_id = dict.get("temperament_id", "even")
	d.strength       = dict.get("strength", 2)
	d.dexterity      = dict.get("dexterity", 2)
	d.cognition      = dict.get("cognition", 2)
	d.willpower      = dict.get("willpower", 2)
	d.vitality       = dict.get("vitality", 2)
	d.spd            = dict.get("spd", 4)  # default 4 for old saves missing the field
	# Migrate old saves that stored a single armor_defense value — apply to both lanes.
	if dict.has("physical_armor"):
		d.physical_armor = dict.get("physical_armor", 3)
		d.magic_armor    = dict.get("magic_armor", 2)
	else:
		var legacy: int  = dict.get("armor_defense", 5)
		d.physical_armor = legacy
		d.magic_armor    = legacy
	d.qte_resolution = float(dict.get("qte_resolution", 0.3))
	var raw_abilities: Array = dict.get("abilities", [])
	d.abilities    = Array(raw_abilities, TYPE_STRING, "", null)
	var raw_pool: Array = dict.get("ability_pool", [])
	d.ability_pool = Array(raw_pool, TYPE_STRING, "", null)
	# Migrate from old split format (kindred_feat_id + feats) to unified feat_ids;
	# then strip kindred-source feat ids — their stat bumps are now structural.
	const _KINDRED_FEAT_IDS: Array[String] = ["adaptive", "relentless", "tinkerer", "stonehide"]
	if dict.has("feat_ids"):
		var raw_feat_ids: Array = dict.get("feat_ids", [])
		var loaded: Array[String] = Array(raw_feat_ids, TYPE_STRING, "", null)
		d.feat_ids = loaded.filter(func(id: String) -> bool: return id not in _KINDRED_FEAT_IDS)
	else:
		var migrated: Array[String] = []
		var kid_feat: String = dict.get("kindred_feat_id", "")
		if kid_feat != "" and kid_feat not in _KINDRED_FEAT_IDS:
			migrated.append(kid_feat)
		for f in dict.get("feats", []):
			var fs: String = str(f)
			if not migrated.has(fs) and fs not in _KINDRED_FEAT_IDS:
				migrated.append(fs)
		d.feat_ids = migrated
	d.level             = dict.get("level", 1)
	d.xp                = dict.get("xp", 0)
	d.pending_level_ups = dict.get("pending_level_ups", 0)
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

## Records an archetype as encountered this run. Deduplicates; saves immediately.
## Called by CombatManager3D at combat setup for each enemy.
func record_archetype(id: String) -> void:
	if id == "" or id in encountered_archetypes:
		return
	encountered_archetypes.append(id)
	save()

## Records an archetype as ever recruited. Called automatically by add_to_bench().
## Persists across bench releases — "once a follower, always logged."
func record_recruited_archetype(id: String) -> void:
	if id == "" or id in recruited_archetypes:
		return
	recruited_archetypes.append(id)
	save()

## Grants a feat to the party member at pc_index. Deduplicates; saves immediately.
func grant_feat(pc_index: int, feat_id: String) -> void:
	if pc_index < 0 or pc_index >= party.size():
		push_error("GameState.grant_feat: invalid index %d" % pc_index)
		return
	var pc: CombatantData = party[pc_index]
	if feat_id in pc.feat_ids:
		return
	pc.feat_ids.append(feat_id)
	save()

## Returns XP needed to advance from current_level to current_level+1.
func xp_needed_for_next_level(current_level: int) -> int:
	if current_level - 1 < XP_THRESHOLDS.size():
		return XP_THRESHOLDS[current_level - 1]
	return current_level * 20

## Awards `amount` XP to all living party members. Advances level and queues
## pending_level_ups when a threshold is crossed. Saves after all members are processed.
func grant_xp(amount: int) -> void:
	for pc: CombatantData in party:
		if pc.is_dead:
			continue
		pc.xp += amount
		while pc.level < 20 and pc.xp >= xp_needed_for_next_level(pc.level):
			pc.xp -= xp_needed_for_next_level(pc.level)
			pc.level += 1
			pc.pending_level_ups += 1
	save()

## Returns up to `count` ability IDs the character can learn (not already owned).
## Draws from class.ability_pool + kindred.ability_pool, deduplicates, shuffles.
static func sample_ability_candidates(pc: CombatantData, count: int) -> Array[String]:
	var class_pool: Array[String] = ClassLibrary.get_class_data(pc.unit_class).ability_pool
	var kindred_pool: Array[String] = KindredLibrary.get_kindred(pc.kindred).ability_pool
	var owned: Array[String] = pc.ability_pool
	var candidates: Array[String] = []
	for ab_id: String in class_pool + kindred_pool:
		if ab_id not in owned and ab_id not in candidates:
			candidates.append(ab_id)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))

## Returns up to `count` feat IDs the character can learn (not already owned).
## Draws from class.feat_pool + background.feat_pool, deduplicates, shuffles.
static func sample_feat_candidates(pc: CombatantData, count: int) -> Array[String]:
	var class_pool: Array[String] = ClassLibrary.get_class_data(pc.unit_class).feat_pool
	var bg_pool: Array[String] = BackgroundLibrary.get_background(pc.background).feat_pool
	var owned: Array[String] = pc.feat_ids
	var candidates: Array[String] = []
	for feat_id: String in class_pool + bg_pool:
		if feat_id not in owned and feat_id not in candidates:
			candidates.append(feat_id)
	candidates.shuffle()
	return candidates.slice(0, mini(count, candidates.size()))

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
	current_combat_ring = ""
	cleared_nodes = []
	threat_level = 0.0
	used_event_ids = []
	encountered_archetypes = []
	recruited_archetypes   = []
	party = []
	bench = []
	run_summary = {}
	inventory = []
	gold = 0
	vendor_stocks = {}
