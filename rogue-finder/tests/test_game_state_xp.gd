extends Node

## --- Unit Tests: XP + Level-Up System ---
## Headless — no scene required. Covers GameState.grant_xp(), threshold math,
## level cap, pending_level_ups accumulation, and pool candidate helpers.

func _ready() -> void:
	print("=== test_game_state_xp.gd ===")
	test_xp_needed_thresholds()
	test_xp_needed_above_table()
	test_grant_xp_basic_level_up()
	test_grant_xp_multi_level()
	test_grant_xp_level_cap()
	test_grant_xp_pending_increments()
	test_grant_xp_skips_dead()
	test_sample_ability_candidates_excludes_owned()
	test_sample_ability_candidates_deduplicates()
	test_sample_feat_candidates_excludes_owned()
	test_sample_feat_candidates_count_cap()
	GameState.reset()
	print("=== All XP/Level-Up tests passed ===")

func _make_member(class_id: String = "prowler", kindred_id: String = "Human",
		bg_id: String = "street_thief") -> CombatantData:
	var m := CombatantData.new()
	m.character_name = "TestUnit"
	m.is_player_unit = true
	m.unit_class  = class_id
	m.kindred     = kindred_id
	m.background  = bg_id
	m.level       = 1
	m.xp          = 0
	m.pending_level_ups = 0
	m.vitality    = 4
	m.ability_pool = []
	m.feat_ids    = []
	m.current_hp  = m.hp_max
	return m

## xp_needed_for_next_level: first 4 entries use the table, beyond uses level*20
func test_xp_needed_thresholds() -> void:
	assert(GameState.xp_needed_for_next_level(1) == 20,
		"Level 1→2 threshold should be 20")
	assert(GameState.xp_needed_for_next_level(2) == 35,
		"Level 2→3 threshold should be 35")
	assert(GameState.xp_needed_for_next_level(3) == 55,
		"Level 3→4 threshold should be 55")
	assert(GameState.xp_needed_for_next_level(4) == 80,
		"Level 4→5 threshold should be 80")
	print("  PASS test_xp_needed_thresholds")

func test_xp_needed_above_table() -> void:
	assert(GameState.xp_needed_for_next_level(5) == 100,
		"Level 5 should use 5*20=100")
	assert(GameState.xp_needed_for_next_level(10) == 200,
		"Level 10 should use 10*20=200")
	print("  PASS test_xp_needed_above_table")

## Basic single level-up: exactly enough XP
func test_grant_xp_basic_level_up() -> void:
	var m := _make_member()
	GameState.party = [m]
	GameState.grant_xp(20)  # threshold for level 1→2 is 20
	assert(m.level == 2, "level should be 2, got %d" % m.level)
	assert(m.xp == 0, "xp should be 0 after exact threshold, got %d" % m.xp)
	assert(m.pending_level_ups == 1, "pending should be 1, got %d" % m.pending_level_ups)
	GameState.reset()
	print("  PASS test_grant_xp_basic_level_up")

## XP overflow triggers multiple level-ups in one grant
func test_grant_xp_multi_level() -> void:
	var m := _make_member()
	GameState.party = [m]
	# 20 (L1→2) + 35 (L2→3) = 55 total — grants exactly 2 levels
	GameState.grant_xp(55)
	assert(m.level == 3, "level should be 3, got %d" % m.level)
	assert(m.pending_level_ups == 2, "pending should be 2, got %d" % m.pending_level_ups)
	GameState.reset()
	print("  PASS test_grant_xp_multi_level")

## Level cap: level must not exceed 20
func test_grant_xp_level_cap() -> void:
	var m := _make_member()
	m.level = 20
	m.xp    = 0
	GameState.party = [m]
	GameState.grant_xp(999)
	assert(m.level == 20, "level should not exceed 20, got %d" % m.level)
	GameState.reset()
	print("  PASS test_grant_xp_level_cap")

## pending_level_ups accumulates, not reset, per grant call
func test_grant_xp_pending_increments() -> void:
	var m := _make_member()
	GameState.party = [m]
	GameState.grant_xp(20)  # level 1→2
	GameState.grant_xp(35)  # level 2→3
	assert(m.level == 3, "level should be 3, got %d" % m.level)
	assert(m.pending_level_ups == 2, "pending should be 2 from two grants, got %d" % m.pending_level_ups)
	GameState.reset()
	print("  PASS test_grant_xp_pending_increments")

## Dead party members do not receive XP
func test_grant_xp_skips_dead() -> void:
	var alive := _make_member()
	var dead := _make_member()
	dead.is_dead = true
	GameState.party = [alive, dead]
	GameState.grant_xp(20)
	assert(alive.level == 2, "alive member should level up, got %d" % alive.level)
	assert(dead.level  == 1, "dead member should stay at level 1, got %d" % dead.level)
	GameState.reset()
	print("  PASS test_grant_xp_skips_dead")

## sample_ability_candidates: owned abilities are excluded
func test_sample_ability_candidates_excludes_owned() -> void:
	var m := _make_member("prowler", "Human", "street_thief")
	# Pre-load a known ability into ability_pool (owned)
	var class_pool: Array[String] = ClassLibrary.get_class_data("prowler").ability_pool
	if class_pool.is_empty():
		print("  SKIP test_sample_ability_candidates_excludes_owned (empty pool)")
		return
	m.ability_pool = [class_pool[0]]
	var candidates: Array[String] = GameState.sample_ability_candidates(m, 3)
	assert(class_pool[0] not in candidates,
		"owned ability '%s' must not appear in candidates" % class_pool[0])
	print("  PASS test_sample_ability_candidates_excludes_owned")

## sample_ability_candidates: no duplicates even if same id appears in class + kindred pools
func test_sample_ability_candidates_deduplicates() -> void:
	var m := _make_member("prowler", "Human", "street_thief")
	m.ability_pool = []
	var candidates: Array[String] = GameState.sample_ability_candidates(m, 99)
	var seen: Dictionary = {}
	for id: String in candidates:
		assert(id not in seen, "duplicate id '%s' in candidates" % id)
		seen[id] = true
	print("  PASS test_sample_ability_candidates_deduplicates")

## sample_feat_candidates: owned feats are excluded
func test_sample_feat_candidates_excludes_owned() -> void:
	var m := _make_member("prowler", "Human", "street_thief")
	var class_pool: Array[String] = ClassLibrary.get_class_data("prowler").feat_pool
	if class_pool.is_empty():
		print("  SKIP test_sample_feat_candidates_excludes_owned (empty pool)")
		return
	m.feat_ids = [class_pool[0]]
	var candidates: Array[String] = GameState.sample_feat_candidates(m, 3)
	assert(class_pool[0] not in candidates,
		"owned feat '%s' must not appear in candidates" % class_pool[0])
	print("  PASS test_sample_feat_candidates_excludes_owned")

## sample_feat_candidates: respects count cap
func test_sample_feat_candidates_count_cap() -> void:
	var m := _make_member("prowler", "Human", "street_thief")
	m.feat_ids = []
	var candidates: Array[String] = GameState.sample_feat_candidates(m, 2)
	assert(candidates.size() <= 2, "should return at most 2 candidates, got %d" % candidates.size())
	print("  PASS test_sample_feat_candidates_count_cap")
