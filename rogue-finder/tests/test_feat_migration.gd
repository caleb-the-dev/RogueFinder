extends Node

## --- Unit Tests: Save migration from old feat format to feat_ids ---
## Verifies that saves with the old kindred_feat_id + feats split
## are deserialized correctly into the unified feat_ids array,
## and that old kindred-source feat IDs are stripped on load.

func _ready() -> void:
	print("=== test_feat_migration.gd ===")
	test_migrate_kindred_feat_id_stripped_on_load()
	test_migrate_feats_only()
	test_migrate_both_combined_strips_kindred()
	test_migrate_no_duplicates()
	test_new_format_feat_ids_strips_kindred()
	GameState.reset()
	print("=== All feat migration tests passed ===")

func _write_save(party_entry: Dictionary) -> void:
	var data := {
		"player_node_id": "badurga",
		"visited_nodes": ["badurga"],
		"map_seed": 1,
		"node_types": {},
		"cleared_nodes": [],
		"threat_level": 0.0,
		"used_event_ids": [],
		"party": [party_entry],
		"inventory": []
	}
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file = null

func _base_entry() -> Dictionary:
	return {
		"archetype_id": "generic",
		"character_name": "OldUnit",
		"is_player_unit": false,
		"unit_class": "",
		"kindred": "Human",
		"background": "",
		"strength": 2, "dexterity": 2, "cognition": 2,
		"willpower": 2, "vitality": 2,
		"armor_defense": 5, "qte_resolution": 0.3,
		"abilities": [], "ability_pool": [],
		"current_hp": 10, "current_energy": 5, "is_dead": false,
		"consumable": "", "weapon_id": "", "armor_id": "", "accessory_id": ""
	}

func test_migrate_kindred_feat_id_stripped_on_load() -> void:
	# Old saves had kindred_feat_id = "adaptive" (now a removed kindred feat).
	# Migration must strip it — stat bonuses are now structural via get_kindred_stat_bonus().
	var entry := _base_entry()
	entry["kindred_feat_id"] = "adaptive"
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(not m.feat_ids.has("adaptive"),
		"old kindred feat 'adaptive' must be stripped on load, got %s" % str(m.feat_ids))
	assert(m.feat_ids.size() == 0,
		"no feats expected after stripping kindred feat, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_kindred_feat_id_stripped_on_load")

func test_migrate_feats_only() -> void:
	# Non-kindred feats in the old "feats" list survive; kindred-source IDs are stripped.
	var entry := _base_entry()
	entry["kindred_feat_id"] = ""
	entry["feats"] = ["street_smart", "stubborn"]  # neither is a kindred feat
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.has("street_smart") and m.feat_ids.has("stubborn"),
		"both non-kindred feats should migrate into feat_ids")
	assert(m.feat_ids.size() == 2,
		"expect 2 feats migrated, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_feats_only")

func test_migrate_both_combined_strips_kindred() -> void:
	# kindred_feat_id gets stripped; non-kindred feats in the old list survive.
	var entry := _base_entry()
	entry["kindred_feat_id"] = "adaptive"   # kindred feat → stripped
	entry["feats"] = ["street_smart"]        # background feat → survives
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(not m.feat_ids.has("adaptive"),
		"kindred feat 'adaptive' must be stripped")
	assert(m.feat_ids.has("street_smart"),
		"non-kindred feat 'street_smart' must survive")
	assert(m.feat_ids.size() == 1,
		"expect 1 feat (stripped kindred + kept bg), got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_both_combined_strips_kindred")

func test_migrate_no_duplicates() -> void:
	var entry := _base_entry()
	entry["kindred_feat_id"] = "street_smart"
	entry["feats"] = ["street_smart"]  # same id — must not appear twice
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.size() == 1,
		"duplicate street_smart should be deduplicated, got %d" % m.feat_ids.size())
	assert(m.feat_ids.has("street_smart"),
		"deduplicated feat 'street_smart' should still be present")
	GameState.reset()
	print("  PASS test_migrate_no_duplicates")

func test_new_format_feat_ids_strips_kindred() -> void:
	# New feat_ids format takes priority; old kindred-source ids are still stripped.
	var entry := _base_entry()
	entry["feat_ids"] = ["street_smart", "relentless"]  # relentless is old kindred → stripped
	entry["kindred_feat_id"] = "adaptive"  # ignored because feat_ids key is present
	entry["feats"] = ["tinkerer"]           # ignored because feat_ids key is present
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.has("street_smart"),
		"non-kindred feat 'street_smart' must survive from feat_ids")
	assert(not m.feat_ids.has("relentless"),
		"old kindred feat 'relentless' must be stripped from feat_ids")
	assert(not m.feat_ids.has("adaptive"),
		"old kindred_feat_id should be ignored when feat_ids key is present")
	assert(m.feat_ids.size() == 1,
		"expect exactly 1 feat after stripping, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_new_format_feat_ids_strips_kindred")
