extends Node

## --- Unit Tests: GameState party field — Persistent Party Slice 2 ---
## Run via the headless .tscn runner. Tests cover save/load round-trips,
## typed-array preservation, equipment resolution, and the fresh-run guard.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_game_state_party.gd ===")
	test_round_trip_identity()
	test_scalar_preservation()
	test_typed_arrays_preserved()
	test_equipment_round_trip()
	test_dead_flag_persistence()
	test_fresh_run_guard()
	print("=== All GameState party tests passed ===")

func _clean() -> void:
	GameState.delete_save()
	GameState.reset()

## --- Tests ---

func test_round_trip_identity() -> void:
	_clean()
	GameState.init_party()
	var pc_name: String       = GameState.party[0].character_name
	var arch0: String         = GameState.party[0].archetype_id
	var arch1: String         = GameState.party[1].archetype_id
	var arch2: String         = GameState.party[2].archetype_id
	GameState.save()
	GameState.reset()
	assert(GameState.party.is_empty(), "party should be empty after reset")
	GameState.load_save()
	assert(GameState.party.size() == 3,
		"party should have 3 members after load, got %d" % GameState.party.size())
	assert(GameState.party[0].character_name == pc_name,
		"PC name mismatch: expected '%s', got '%s'" % [pc_name, GameState.party[0].character_name])
	assert(GameState.party[0].archetype_id == arch0, "PC archetype_id mismatch after round-trip")
	assert(GameState.party[1].archetype_id == arch1, "ally 1 archetype_id mismatch after round-trip")
	assert(GameState.party[2].archetype_id == arch2, "ally 2 archetype_id mismatch after round-trip")
	assert(GameState.party[0].is_player_unit == true, "PC should be is_player_unit=true")
	assert(GameState.party[1].is_player_unit == true, "ally 1 should be is_player_unit=true")
	print("  PASS test_round_trip_identity")

func test_scalar_preservation() -> void:
	_clean()
	GameState.init_party()
	GameState.party[0].current_hp     = 7
	GameState.party[0].current_energy = 3
	GameState.party[1].is_dead        = true
	GameState.save()
	GameState.reset()
	GameState.load_save()
	assert(GameState.party[0].current_hp == 7,
		"current_hp not preserved: expected 7, got %d" % GameState.party[0].current_hp)
	assert(GameState.party[0].current_energy == 3,
		"current_energy not preserved: expected 3, got %d" % GameState.party[0].current_energy)
	assert(GameState.party[1].is_dead == true, "is_dead not preserved for party[1]")
	print("  PASS test_scalar_preservation")

func test_typed_arrays_preserved() -> void:
	_clean()
	GameState.init_party()
	var orig_abilities: Array[String] = GameState.party[0].abilities.duplicate()
	var orig_pool: Array[String]      = GameState.party[0].ability_pool.duplicate()
	GameState.save()
	GameState.reset()
	GameState.load_save()
	assert(GameState.party[0].abilities.size() == orig_abilities.size(),
		"abilities size mismatch after round-trip")
	for i in range(orig_abilities.size()):
		assert(GameState.party[0].abilities[i] == orig_abilities[i],
			"abilities[%d] mismatch: expected '%s', got '%s'" %
			[i, orig_abilities[i], GameState.party[0].abilities[i]])
	assert(GameState.party[0].ability_pool.size() == orig_pool.size(),
		"ability_pool size mismatch after round-trip")
	for i in range(orig_pool.size()):
		assert(GameState.party[0].ability_pool[i] == orig_pool[i],
			"ability_pool[%d] mismatch" % i)
	print("  PASS test_typed_arrays_preserved")

func test_equipment_round_trip() -> void:
	_clean()
	GameState.init_party()
	GameState.party[0].weapon = EquipmentLibrary.get_equipment("short_sword")
	GameState.save()
	GameState.reset()
	GameState.load_save()
	assert(GameState.party[0].weapon != null, "weapon should not be null after load")
	assert(GameState.party[0].weapon.equipment_id == "short_sword",
		"weapon id mismatch: expected 'short_sword', got '%s'" % GameState.party[0].weapon.equipment_id)
	print("  PASS test_equipment_round_trip")

func test_dead_flag_persistence() -> void:
	_clean()
	GameState.init_party()
	GameState.party[1].is_dead = true
	GameState.save()
	GameState.reset()
	GameState.load_save()
	assert(GameState.party[1].is_dead == true,
		"is_dead on party[1] should survive round-trip")
	print("  PASS test_dead_flag_persistence")

func test_fresh_run_guard() -> void:
	_clean()
	GameState.init_party()
	assert(GameState.party.size() == 3,
		"party should have 3 after first init_party(), got %d" % GameState.party.size())
	GameState.init_party()
	assert(GameState.party.size() == 3,
		"calling init_party() twice must not add members, got %d" % GameState.party.size())
	print("  PASS test_fresh_run_guard")
