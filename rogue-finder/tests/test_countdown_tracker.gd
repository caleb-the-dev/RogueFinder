extends Node

func _ready() -> void:
	print("=== test_countdown_tracker.gd ===")
	test_countdown_max_from_spd()
	test_countdown_decrement_all()
	test_unit_acts_at_zero()
	test_cooldown_decrement_per_unit()
	test_cooldown_blocks_pick_until_zero()
	test_tiebreak_higher_spd_first()
	print("=== All CountdownTracker tests passed ===")

func test_countdown_max_from_spd() -> void:
	assert(CountdownTracker.compute_countdown_max(4) == 4, "spd 4 → cd 4")
	assert(CountdownTracker.compute_countdown_max(6) == 2, "spd 6 → cd 2")
	assert(CountdownTracker.compute_countdown_max(1) == 7, "spd 1 → cd 7")
	assert(CountdownTracker.compute_countdown_max(8) == 2, "spd 8 → clamps to 2")
	assert(CountdownTracker.compute_countdown_max(-5) == 12, "spd -5 → clamps to 12")
	print("  PASS test_countdown_max_from_spd")

func test_countdown_decrement_all() -> void:
	var u1 := CombatantData.new()
	u1.spd = 4
	u1.countdown_current = 4
	u1.countdown_max = 4
	var u2 := CombatantData.new()
	u2.spd = 6
	u2.countdown_current = 2
	u2.countdown_max = 2
	var units: Array[CombatantData] = [u1, u2]
	CountdownTracker.tick(units)
	assert(u1.countdown_current == 3, "u1 countdown should decrement to 3, got %d" % u1.countdown_current)
	assert(u2.countdown_current == 1, "u2 countdown should decrement to 1, got %d" % u2.countdown_current)
	print("  PASS test_countdown_decrement_all")

func test_unit_acts_at_zero() -> void:
	var u := CombatantData.new()
	u.spd = 6
	u.countdown_current = 1
	u.countdown_max = 2
	var units: Array[CombatantData] = [u]
	var ready := CountdownTracker.tick_and_collect_ready(units)
	assert(ready.size() == 1, "u should be ready after countdown reaches 0")
	assert(ready[0] == u, "ready unit should be u")
	print("  PASS test_unit_acts_at_zero")

func test_cooldown_decrement_per_unit() -> void:
	var cds: Array[int] = [0, 1, 3]
	CountdownTracker.tick_cooldowns(cds)
	assert(cds[0] == 0, "0 stays 0 (off cooldown)")
	assert(cds[1] == 0, "1 ticks to 0")
	assert(cds[2] == 2, "3 ticks to 2")
	print("  PASS test_cooldown_decrement_per_unit")

func test_cooldown_blocks_pick_until_zero() -> void:
	var cds: Array[int] = [0, 2, 5]
	var available := CountdownTracker.available_slot_indices(cds)
	assert(available.size() == 1, "only slot 0 is available")
	assert(available[0] == 0, "available index should be 0")
	print("  PASS test_cooldown_blocks_pick_until_zero")

func test_tiebreak_higher_spd_first() -> void:
	var slow := CombatantData.new()
	slow.spd = 4
	slow.countdown_current = 0
	slow.character_name = "Slow"
	var fast := CombatantData.new()
	fast.spd = 6
	fast.countdown_current = 0
	fast.character_name = "Fast"
	var both: Array[CombatantData] = [slow, fast]
	var ordered := CountdownTracker.tiebreak_ready(both)
	assert(ordered[0] == fast, "fast should act first (higher spd)")
	assert(ordered[1] == slow, "slow acts second")
	print("  PASS test_tiebreak_higher_spd_first")
