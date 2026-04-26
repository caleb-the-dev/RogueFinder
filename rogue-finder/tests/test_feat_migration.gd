extends Node

## --- Unit Tests: Save migration from old feat format to feat_ids ---
## Verifies that saves with the old kindred_feat_id + feats split
## are deserialized correctly into the unified feat_ids array.

func _ready() -> void:
	print("=== test_feat_migration.gd ===")
	test_migrate_kindred_feat_id_only()
	test_migrate_feats_only()
	test_migrate_both_combined()
	test_migrate_no_duplicates()
	test_new_format_feat_ids_takes_priority()
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

func test_migrate_kindred_feat_id_only() -> void:
	var entry := _base_entry()
	entry["kindred_feat_id"] = "adaptive"
	# No "feats" key — old format pre-Slice 4
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.has("adaptive"),
		"kindred_feat_id 'adaptive' should migrate into feat_ids")
	assert(m.feat_ids.size() == 1,
		"expect 1 feat migrated, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_kindred_feat_id_only")

func test_migrate_feats_only() -> void:
	var entry := _base_entry()
	entry["kindred_feat_id"] = ""
	entry["feats"] = ["relentless", "stubborn"]
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.has("relentless") and m.feat_ids.has("stubborn"),
		"both feats should migrate into feat_ids")
	assert(m.feat_ids.size() == 2,
		"expect 2 feats migrated, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_feats_only")

func test_migrate_both_combined() -> void:
	var entry := _base_entry()
	entry["kindred_feat_id"] = "adaptive"
	entry["feats"] = ["relentless"]
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.has("adaptive"), "kindred feat should migrate")
	assert(m.feat_ids.has("relentless"), "event feat should migrate")
	assert(m.feat_ids.size() == 2,
		"expect 2 feats total, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_both_combined")

func test_migrate_no_duplicates() -> void:
	var entry := _base_entry()
	entry["kindred_feat_id"] = "adaptive"
	entry["feats"] = ["adaptive"]  # same id — must not appear twice
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.size() == 1,
		"duplicate adaptive should be deduplicated, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_migrate_no_duplicates")

func test_new_format_feat_ids_takes_priority() -> void:
	var entry := _base_entry()
	entry["feat_ids"] = ["stonehide", "relentless"]
	# Even if old keys are present, feat_ids wins
	entry["kindred_feat_id"] = "adaptive"
	entry["feats"] = ["tinkerer"]
	_write_save(entry)
	GameState.reset()
	assert(GameState.load_save(), "load_save should succeed")
	var m: CombatantData = GameState.party[0]
	assert(m.feat_ids.has("stonehide") and m.feat_ids.has("relentless"),
		"feat_ids key should take priority over migration path")
	assert(not m.feat_ids.has("adaptive"),
		"old kindred_feat_id should be ignored when feat_ids is present")
	assert(m.feat_ids.size() == 2,
		"expect exactly 2 feats from feat_ids key, got %d" % m.feat_ids.size())
	GameState.reset()
	print("  PASS test_new_format_feat_ids_takes_priority")
