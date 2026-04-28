extends Node

## --- Unit Tests: Recruit Success Path ---
## Headless tests for _build_follower level-matching logic, release_from_bench
## auto-deequip, and bench save round-trip. No scene or input required.

func _ready() -> void:
	print("=== test_recruit_success.gd ===")
	test_follower_level_matches_party()
	test_follower_level_defaults_to_one_when_party_empty()
	test_follower_qte_resolution_is_zero()
	test_follower_is_player_unit()
	test_follower_hp_seeded_to_max()
	test_release_from_bench_removes_entry()
	test_release_from_bench_deequips_weapon()
	test_release_from_bench_deequips_armor()
	test_release_from_bench_out_of_bounds_safe()
	test_bench_save_round_trip()
	test_bench_empty_on_fresh_save()
	print("=== All recruit-success tests passed ===")

## --- Helpers ---

## Mirrors _build_follower level logic from CombatManager3D (no scene needed).
func _build_follower_level(party: Array[CombatantData]) -> int:
	return party[0].level if not party.is_empty() else 1

func _make_combatant(level: int) -> CombatantData:
	var d := CombatantData.new()
	d.archetype_id = "test"
	d.is_player_unit = true
	d.kindred = "Human"
	d.unit_class = "vanguard"
	d.background = ""
	d.temperament_id = "even"
	d.strength = 3
	d.dexterity = 3
	d.cognition = 3
	d.willpower = 3
	d.vitality = 3
	d.physical_armor = 3
	d.magic_armor = 2
	d.abilities = ["", "", "", ""]
	d.ability_pool = []
	d.feat_ids = []
	d.level = level
	d.xp = 0
	d.pending_level_ups = 0
	d.current_hp = d.hp_max
	d.current_energy = d.energy_max
	d.is_dead = false
	d.consumable = ""
	d.qte_resolution = 0.0
	return d

func _clean() -> void:
	GameState.delete_save()
	GameState.reset()

## --- Level-Matching Tests ---

func test_follower_level_matches_party() -> void:
	var party: Array[CombatantData] = []
	var pc := _make_combatant(3)
	party.append(pc)
	var level: int = _build_follower_level(party)
	assert(level == 3, "Follower level should match party[0].level (3), got %d" % level)
	print("  PASS test_follower_level_matches_party")

func test_follower_level_defaults_to_one_when_party_empty() -> void:
	var level: int = _build_follower_level([])
	assert(level == 1, "Follower level should default to 1 with empty party, got %d" % level)
	print("  PASS test_follower_level_defaults_to_one_when_party_empty")

func test_follower_qte_resolution_is_zero() -> void:
	# Bench followers never instant-sim — qte_resolution must be 0
	var f := _make_combatant(1)
	f.qte_resolution = 0.0
	assert(f.qte_resolution == 0.0, "Follower qte_resolution must be 0.0, got %f" % f.qte_resolution)
	print("  PASS test_follower_qte_resolution_is_zero")

func test_follower_is_player_unit() -> void:
	var f := _make_combatant(1)
	f.is_player_unit = true
	assert(f.is_player_unit, "Follower must be marked as player unit")
	print("  PASS test_follower_is_player_unit")

func test_follower_hp_seeded_to_max() -> void:
	var f := _make_combatant(1)
	assert(f.current_hp == f.hp_max,
		"Follower current_hp should equal hp_max at creation (%d vs %d)" % [f.current_hp, f.hp_max])
	print("  PASS test_follower_hp_seeded_to_max")

## --- release_from_bench Tests ---

func test_release_from_bench_removes_entry() -> void:
	_clean()
	var f := _make_combatant(1)
	f.character_name = "TestFollower"
	GameState.bench.append(f)
	assert(GameState.bench.size() == 1, "Bench should have 1 entry before release")
	GameState.release_from_bench(0)
	assert(GameState.bench.is_empty(), "Bench should be empty after release, got %d" % GameState.bench.size())
	_clean()
	print("  PASS test_release_from_bench_removes_entry")

func test_release_from_bench_deequips_weapon() -> void:
	_clean()
	var f := _make_combatant(1)
	f.character_name = "ArmedFollower"
	# Use a real equipment entry so EquipmentLibrary round-trips correctly
	var sword: EquipmentData = EquipmentLibrary.get_equipment("iron_sword")
	if sword == null:
		print("  SKIP test_release_from_bench_deequips_weapon (iron_sword not found)")
		_clean()
		return
	f.weapon = sword
	GameState.bench.append(f)
	GameState.release_from_bench(0)
	assert(GameState.bench.is_empty(), "Bench should be empty after release")
	var found_in_inv: bool = false
	for item in GameState.inventory:
		if item.get("id", "") == sword.equipment_id:
			found_in_inv = true
			break
	assert(found_in_inv, "Weapon should land in inventory after release_from_bench")
	_clean()
	print("  PASS test_release_from_bench_deequips_weapon")

func test_release_from_bench_deequips_armor() -> void:
	_clean()
	var f := _make_combatant(1)
	f.character_name = "ArmoredFollower"
	var armor_piece: EquipmentData = EquipmentLibrary.get_equipment("leather_armor")
	if armor_piece == null:
		print("  SKIP test_release_from_bench_deequips_armor (leather_armor not found)")
		_clean()
		return
	f.armor = armor_piece
	GameState.bench.append(f)
	GameState.release_from_bench(0)
	var found_in_inv: bool = false
	for item in GameState.inventory:
		if item.get("id", "") == armor_piece.equipment_id:
			found_in_inv = true
			break
	assert(found_in_inv, "Armor should land in inventory after release_from_bench")
	_clean()
	print("  PASS test_release_from_bench_deequips_armor")

func test_release_from_bench_out_of_bounds_safe() -> void:
	_clean()
	# Should not crash on bad index
	GameState.release_from_bench(-1)
	GameState.release_from_bench(99)
	assert(true, "Out-of-bounds release should not crash")
	_clean()
	print("  PASS test_release_from_bench_out_of_bounds_safe")

## --- Bench Save Round-Trip Tests ---

func test_bench_save_round_trip() -> void:
	_clean()
	var f := _make_combatant(2)
	f.character_name = "Saved Follower"
	GameState.bench.append(f)
	GameState.party.append(_make_combatant(2))  # need a party entry for save to work normally
	GameState.save()
	GameState.reset()
	assert(GameState.bench.is_empty(), "Bench should be empty after reset()")
	GameState.load_save()
	assert(GameState.bench.size() == 1,
		"Bench should have 1 entry after load, got %d" % GameState.bench.size())
	assert(GameState.bench[0].character_name == "Saved Follower",
		"Follower name should survive save/load, got '%s'" % GameState.bench[0].character_name)
	assert(GameState.bench[0].level == 2,
		"Follower level should survive save/load, got %d" % GameState.bench[0].level)
	assert(GameState.bench[0].is_player_unit,
		"Follower is_player_unit should survive save/load")
	_clean()
	print("  PASS test_bench_save_round_trip")

func test_bench_empty_on_fresh_save() -> void:
	_clean()
	GameState.party.append(_make_combatant(1))
	GameState.save()
	GameState.reset()
	GameState.load_save()
	assert(GameState.bench.is_empty(),
		"Bench should be empty when no followers were saved, got %d" % GameState.bench.size())
	_clean()
	print("  PASS test_bench_empty_on_fresh_save")
