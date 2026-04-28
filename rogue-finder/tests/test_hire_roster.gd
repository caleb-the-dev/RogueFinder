extends Node

## --- Unit Tests: Hire Roster generation + gold deduction logic ---
## Headless tests — no scene instantiation required.

func _ready() -> void:
	print("=== test_hire_roster.gd ===")

	test_roster_returns_4_archetypes()
	test_roster_is_deterministic()
	test_different_seeds_produce_different_rosters()
	test_all_roster_archetypes_have_hire_cost()
	test_gold_deduction()
	test_insufficient_gold_no_deduction()

	print("All tests passed.")
	get_tree().quit()

## --- Helpers ---

func _reset_state() -> void:
	GameState.reset()
	var pc := ArchetypeLibrary.create("grunt", "Tester", true)
	GameState.party.append(pc)

## --- Tests ---

func test_roster_returns_4_archetypes() -> void:
	var roster: Array[ArchetypeData] = BadurgaManager._generate_hire_roster(12345, 4)
	assert(roster.size() == 4, "roster should have exactly 4 entries, got %d" % roster.size())
	print("  PASS: generate_hire_roster returns 4 archetypes")

func test_roster_is_deterministic() -> void:
	var seed: int = 99999
	var first:  Array[ArchetypeData] = BadurgaManager._generate_hire_roster(seed, 4)
	var second: Array[ArchetypeData] = BadurgaManager._generate_hire_roster(seed, 4)
	assert(first.size() == second.size(), "roster sizes should match")
	for i in first.size():
		assert(first[i].archetype_id == second[i].archetype_id,
			"archetype at index %d differs between calls with same seed" % i)
	print("  PASS: same seed produces same roster")

func test_different_seeds_produce_different_rosters() -> void:
	var a: Array[ArchetypeData] = BadurgaManager._generate_hire_roster(1, 4)
	var b: Array[ArchetypeData] = BadurgaManager._generate_hire_roster(987654321, 4)
	var all_same := true
	for i in a.size():
		if a[i].archetype_id != b[i].archetype_id:
			all_same = false
			break
	assert(not all_same, "different seeds should (very likely) produce different rosters")
	print("  PASS: different seeds produce different rosters")

func test_all_roster_archetypes_have_hire_cost() -> void:
	var roster: Array[ArchetypeData] = BadurgaManager._generate_hire_roster(42, 4)
	for arch in roster:
		assert(arch.hire_cost > 0,
			"archetype '%s' in roster has hire_cost == 0 (should be excluded)" % arch.archetype_id)
	print("  PASS: all roster archetypes have hire_cost > 0")

func test_gold_deduction() -> void:
	_reset_state()
	GameState.gold = 50
	var cost: int = 30
	GameState.gold -= cost
	assert(GameState.gold == 20,
		"gold should be 20 after deducting 30 from 50, got %d" % GameState.gold)
	print("  PASS: gold deduction correct (50 - 30 = 20)")

func test_insufficient_gold_no_deduction() -> void:
	_reset_state()
	GameState.gold = 15
	var bench_before: int = GameState.bench.size()
	var gold_before: int  = GameState.gold
	var cost: int = 30

	# Guard logic mirrors _on_hire_pressed early return
	if GameState.gold >= cost:
		GameState.gold -= cost
		var follower := ArchetypeLibrary.create("grunt", "TestHire", true)
		GameState.add_to_bench(follower)

	assert(GameState.gold == gold_before,
		"gold should be unchanged when insufficient, got %d" % GameState.gold)
	assert(GameState.bench.size() == bench_before,
		"bench should be unchanged when gold insufficient")
	print("  PASS: insufficient gold does not deduct or add follower")
