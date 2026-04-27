extends Node

## --- Unit Tests: GameState.bench — data model, persistence, release, swap ---
## Run via test_bench.tscn headless runner.

func _ready() -> void:
	print("=== test_bench.gd ===")
	test_add_to_bench()
	test_add_to_full_bench_returns_false()
	test_release_deequips_gear_to_inventory()
	test_release_removes_from_bench()
	test_swap_active_bench()
	test_save_round_trip()
	print("=== All bench tests passed ===")

func _clean() -> void:
	GameState.delete_save()
	GameState.reset()

func _make_follower(follower_name: String) -> CombatantData:
	var d := CombatantData.new()
	d.character_name = follower_name
	d.archetype_id   = "generic"
	d.is_player_unit = false
	d.unit_class     = "vanguard"
	d.kindred        = "Human"
	d.background     = "soldier"
	d.temperament_id = "even"
	d.strength       = 3
	d.dexterity      = 2
	d.cognition      = 2
	d.willpower      = 2
	d.vitality       = 3
	d.physical_armor = 3
	d.magic_armor    = 2
	d.level          = 1
	d.xp             = 0
	d.current_hp     = 22
	d.current_energy = 5
	return d

func test_add_to_bench() -> void:
	_clean()
	var f := _make_follower("Brunt")
	var ok := GameState.add_to_bench(f)
	assert(ok, "add_to_bench should return true on empty bench")
	assert(GameState.bench.size() == 1, "bench should have 1 entry")
	assert(GameState.bench[0].character_name == "Brunt", "bench[0] name should be Brunt")
	_clean()
	print("  PASS test_add_to_bench")

func test_add_to_full_bench_returns_false() -> void:
	_clean()
	for i in range(GameState.BENCH_CAP):
		var added := GameState.add_to_bench(_make_follower("F%d" % i))
		assert(added, "slot %d should accept follower" % i)
	assert(GameState.bench.size() == GameState.BENCH_CAP, "bench should be at cap")
	var overflow := GameState.add_to_bench(_make_follower("Overflow"))
	assert(not overflow, "add_to_bench should return false when bench is full")
	assert(GameState.bench.size() == GameState.BENCH_CAP, "bench size must not change after rejection")
	_clean()
	print("  PASS test_add_to_full_bench_returns_false")

func test_release_deequips_gear_to_inventory() -> void:
	_clean()
	var f := _make_follower("Geared")
	f.weapon = EquipmentLibrary.get_equipment("short_sword")
	GameState.add_to_bench(f)
	GameState.release_from_bench(0)
	var found := false
	for item in GameState.inventory:
		if item.get("id", "") == "short_sword":
			found = true
			assert(item.get("seen") == false, "released gear should have seen=false")
	assert(found, "short_sword should be in inventory after release")
	_clean()
	print("  PASS test_release_deequips_gear_to_inventory")

func test_release_removes_from_bench() -> void:
	_clean()
	GameState.add_to_bench(_make_follower("Alpha"))
	GameState.add_to_bench(_make_follower("Beta"))
	GameState.release_from_bench(0)
	assert(GameState.bench.size() == 1, "bench should have 1 entry after release")
	assert(GameState.bench[0].character_name == "Beta",
		"bench[0] should be Beta after releasing index 0")
	_clean()
	print("  PASS test_release_removes_from_bench")

func test_swap_active_bench() -> void:
	_clean()
	var pc := _make_follower("PC")
	pc.is_player_unit = true
	var ally := _make_follower("Ally")
	var benched := _make_follower("Benched")
	GameState.party.append(pc)
	GameState.party.append(ally)
	GameState.add_to_bench(benched)
	GameState.swap_active_bench(1, 0)
	assert(GameState.party[1].character_name == "Benched",
		"party[1] should be Benched after swap")
	assert(GameState.bench[0].character_name == "Ally",
		"bench[0] should be Ally after swap")
	_clean()
	print("  PASS test_swap_active_bench")

func test_save_round_trip() -> void:
	_clean()
	var f := _make_follower("Persisted")
	f.strength = 7
	GameState.add_to_bench(f)
	GameState.save()
	GameState.reset()
	assert(GameState.bench.is_empty(), "bench should be empty after reset")
	GameState.load_save()
	assert(GameState.bench.size() == 1, "bench should have 1 entry after load")
	assert(GameState.bench[0].character_name == "Persisted",
		"character_name should survive round-trip")
	assert(GameState.bench[0].strength == 7, "strength should survive round-trip")
	_clean()
	print("  PASS test_save_round_trip")
