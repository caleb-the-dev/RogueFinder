extends Node

## --- Unit Tests: CombatantData.get_feat_stat_bonus() + derived stat formulas ---
## Headless — no scene required.

func _ready() -> void:
	print("=== test_feat_stat_bonus.gd ===")
	test_no_feats_returns_zero()
	test_single_feat_sums_correctly()
	test_multiple_feats_sum()
	test_wrong_stat_returns_zero()
	test_physical_defense_increases_with_armor_feat()
	test_unknown_feat_id_does_not_crash()
	print("=== All feat stat bonus tests passed ===")

func _bare_combatant() -> CombatantData:
	var d := CombatantData.new()
	d.kindred   = ""  # no kindred bonus
	d.strength  = 2
	d.dexterity = 2
	d.cognition = 2
	d.willpower = 2
	d.vitality  = 2
	d.physical_armor = 0
	d.magic_armor    = 0
	return d

func test_no_feats_returns_zero() -> void:
	var d := _bare_combatant()
	d.feat_ids = []
	assert(d.get_feat_stat_bonus("strength") == 0,
		"no feats: strength bonus should be 0, got %d" % d.get_feat_stat_bonus("strength"))
	assert(d.get_feat_stat_bonus("willpower") == 0,
		"no feats: willpower bonus should be 0")
	print("  PASS test_no_feats_returns_zero")

func test_single_feat_sums_correctly() -> void:
	var d := _bare_combatant()
	d.feat_ids = ["war_cry_discipline"]  # willpower:1
	assert(d.get_feat_stat_bonus("willpower") == 1,
		"war_cry_discipline feat: willpower bonus should be 1, got %d" % d.get_feat_stat_bonus("willpower"))
	assert(d.get_feat_stat_bonus("strength") == 0,
		"war_cry_discipline feat: strength bonus should be 0")
	print("  PASS test_single_feat_sums_correctly")

func test_multiple_feats_sum() -> void:
	var d := _bare_combatant()
	# combat_mastery = strength:1, battle_hardened = strength:2
	d.feat_ids = ["combat_mastery", "battle_hardened"]
	assert(d.get_feat_stat_bonus("strength") == 3,
		"combat_mastery+battle_hardened: strength bonus should be 3, got %d" % d.get_feat_stat_bonus("strength"))
	print("  PASS test_multiple_feats_sum")

func test_wrong_stat_returns_zero() -> void:
	var d := _bare_combatant()
	d.feat_ids = ["iron_guard"]  # physical_armor:2
	assert(d.get_feat_stat_bonus("strength") == 0,
		"iron_guard: strength bonus should be 0")
	assert(d.get_feat_stat_bonus("physical_armor") == 2,
		"iron_guard: physical_armor bonus should be 2, got %d" % d.get_feat_stat_bonus("physical_armor"))
	print("  PASS test_wrong_stat_returns_zero")

func test_physical_defense_increases_with_armor_feat() -> void:
	var d := _bare_combatant()
	var base_pdef: int = d.physical_defense
	d.feat_ids = ["iron_guard"]  # physical_armor:2
	assert(d.physical_defense == base_pdef + 2,
		"iron_guard should raise physical_defense by 2, got %d (base %d)" % [d.physical_defense, base_pdef])
	print("  PASS test_physical_defense_increases_with_armor_feat")

func test_unknown_feat_id_does_not_crash() -> void:
	var d := _bare_combatant()
	d.feat_ids = ["completely_fake_feat_id_xyz"]
	# Must not crash; stub has empty stat_bonuses
	var bonus: int = d.get_feat_stat_bonus("strength")
	assert(bonus == 0,
		"unknown feat id should produce 0 bonus, got %d" % bonus)
	print("  PASS test_unknown_feat_id_does_not_crash")
