extends Node

## --- Unit Tests: EventManager — recruit_follower effect + bench_not_full condition ---
## Headless tests — call static methods directly. No scene instantiation required.

func _ready() -> void:
	print("=== test_event_follower.gd ===")

	test_recruit_follower_adds_to_bench()
	test_recruit_follower_bench_full_no_crash()
	test_recruit_follower_bench_full_with_release_idx()
	test_recruit_follower_explicit_name()
	test_recruit_follower_no_name_uses_pool()
	test_bench_not_full_condition()

	print("All tests passed.")
	get_tree().quit()

## --- Helpers ---

func _reset_state() -> void:
	GameState.reset()
	var pc := ArchetypeLibrary.create("grunt", "Tester", true)
	GameState.party.append(pc)

## --- Tests ---

func test_recruit_follower_adds_to_bench() -> void:
	_reset_state()
	assert(GameState.bench.size() == 0)

	var effect := {"type": "recruit_follower", "archetype_id": "rat_scrapper", "name": "Fang"}
	EventManager.dispatch_effect(effect, GameState.party)

	assert(GameState.bench.size() == 1, "bench should have 1 follower after recruit")
	assert(GameState.bench[0].character_name == "Fang", "follower name should be Fang")
	print("  PASS: recruit_follower adds to bench")

func test_recruit_follower_bench_full_no_crash() -> void:
	_reset_state()
	# Fill the bench to capacity
	for i in GameState.BENCH_CAP:
		var f := ArchetypeLibrary.create("grunt", "Filler%d" % i, true)
		GameState.bench.append(f)
	assert(GameState.bench.size() == GameState.BENCH_CAP)

	var effect := {"type": "recruit_follower", "archetype_id": "rat_scrapper", "name": "Overflow"}
	EventManager.dispatch_effect(effect, GameState.party)

	assert(GameState.bench.size() == GameState.BENCH_CAP, "bench size should stay at cap")
	print("  PASS: recruit_follower with full bench does not crash or add")

func test_recruit_follower_bench_full_with_release_idx() -> void:
	_reset_state()
	for i in GameState.BENCH_CAP:
		var f := ArchetypeLibrary.create("grunt", "Filler%d" % i, true)
		GameState.bench.append(f)
	assert(GameState.bench.size() == GameState.BENCH_CAP)

	var effect := {"type": "recruit_follower", "archetype_id": "rat_scrapper", "name": "Fang"}
	EventManager.dispatch_effect(effect, GameState.party, null, 0)

	assert(GameState.bench.size() == GameState.BENCH_CAP, "bench should stay at cap after release+recruit")
	var names: Array[String] = []
	for m: CombatantData in GameState.bench:
		names.append(m.character_name)
	assert("Fang" in names, "Fang should be in bench after recruit")
	assert(not ("Filler0" in names), "Filler0 should have been released")
	print("  PASS: recruit_follower with bench_release_idx releases slot and adds follower")

func test_recruit_follower_explicit_name() -> void:
	_reset_state()
	var effect := {"type": "recruit_follower", "archetype_id": "skeleton_warrior", "name": "Rattle"}
	EventManager.dispatch_effect(effect, GameState.party)

	assert(GameState.bench.size() == 1)
	assert(GameState.bench[0].character_name == "Rattle", "explicit name should be used exactly")
	print("  PASS: recruit_follower uses explicit name")

func test_recruit_follower_no_name_uses_pool() -> void:
	_reset_state()
	# No name field — should draw from kindred pool
	var effect := {"type": "recruit_follower", "archetype_id": "archer_bandit"}
	EventManager.dispatch_effect(effect, GameState.party)

	assert(GameState.bench.size() == 1)
	assert(GameState.bench[0].character_name != "", "follower should have a non-empty name from pool")
	print("  PASS: recruit_follower picks name from kindred pool when none provided")

func test_bench_not_full_condition() -> void:
	_reset_state()
	assert(GameState.bench.size() == 0)

	var has_space := EventManager.evaluate_condition("bench_not_full", GameState.party)
	assert(has_space == true, "bench_not_full should be true when bench is empty")

	# Fill to capacity
	for i in GameState.BENCH_CAP:
		var f := ArchetypeLibrary.create("grunt", "Pad%d" % i, true)
		GameState.bench.append(f)

	var is_full := EventManager.evaluate_condition("bench_not_full", GameState.party)
	assert(is_full == false, "bench_not_full should be false when bench is at cap")
	print("  PASS: bench_not_full condition reflects bench state correctly")
