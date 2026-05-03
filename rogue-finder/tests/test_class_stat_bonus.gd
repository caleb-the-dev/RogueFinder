extends Node

## --- Unit Tests: CombatantData stat bonus methods + derived stat formulas ---
## Covers class, kindred, and background bonus getters and how they wire into
## hp_max, attack, defense, speed, energy_max, energy_regen.
## Headless — no scene required.

func _ready() -> void:
	print("=== test_class_stat_bonus.gd ===")
	test_get_class_stat_bonus_known_class()
	test_get_class_stat_bonus_unknown_stat_returns_zero()
	test_get_class_stat_bonus_unknown_class_returns_zero()
	test_hp_max_includes_class_vit_bonus()
	test_attribute_range_min_boundary()
	test_attribute_range_max_boundary()
	test_hp_formula_with_max_vit()
	# Kindred stat bonus
	test_get_kindred_stat_bonus_known()
	test_get_kindred_stat_bonus_unknown_returns_zero()
	test_physical_defense_includes_kindred_armor_bonus()
	test_attack_includes_kindred_str_bonus()
	# Background stat bonus
	test_get_background_stat_bonus_known()
	test_get_background_stat_bonus_unknown_returns_zero()
	test_attack_includes_background_str_bonus()
	test_hp_max_includes_background_vit_bonus()
	print("=== All stat bonus tests passed ===")

func _bare_combatant() -> CombatantData:
	var d := CombatantData.new()
	d.kindred       = ""
	d.background    = ""
	d.strength      = 5
	d.dexterity     = 5
	d.cognition     = 5
	d.willpower     = 5
	d.vitality      = 5
	d.physical_armor = 0
	d.magic_armor    = 0
	d.feat_ids      = []
	d.unit_class    = ""
	return d

## --- Class bonus tests ---

func test_get_class_stat_bonus_known_class() -> void:
	var d := _bare_combatant()
	d.unit_class = "vanguard"  # strength:2|vitality:2
	assert(d.get_class_stat_bonus("strength") == 2,
		"vanguard strength bonus should be 2, got %d" % d.get_class_stat_bonus("strength"))
	assert(d.get_class_stat_bonus("vitality") == 2,
		"vanguard vitality bonus should be 2, got %d" % d.get_class_stat_bonus("vitality"))
	print("  PASS test_get_class_stat_bonus_known_class")

func test_get_class_stat_bonus_unknown_stat_returns_zero() -> void:
	var d := _bare_combatant()
	d.unit_class = "vanguard"
	assert(d.get_class_stat_bonus("cognition") == 0,
		"vanguard has no cognition bonus — should return 0")
	print("  PASS test_get_class_stat_bonus_unknown_stat_returns_zero")

func test_get_class_stat_bonus_unknown_class_returns_zero() -> void:
	var d := _bare_combatant()
	d.unit_class = "completely_fake_class_id"
	assert(d.get_class_stat_bonus("str") == 0,
		"unknown class should return 0 for any stat bonus")
	print("  PASS test_get_class_stat_bonus_unknown_class_returns_zero")

func test_hp_max_includes_class_vit_bonus() -> void:
	var d := _bare_combatant()
	var base_hp: int = d.hp_max  # unit_class = ""
	d.unit_class = "vanguard"  # vit:2
	assert(d.hp_max == base_hp + 2,
		"vanguard vit:2 should raise hp_max by 2, got %d (base %d)" % [d.hp_max, base_hp])
	print("  PASS test_hp_max_includes_class_vit_bonus")

func test_attribute_range_min_boundary() -> void:
	var d := _bare_combatant()
	d.vitality = 1
	assert(d.hp_max == 14, "min vit=1: hp_max should be 14, got %d" % d.hp_max)
	print("  PASS test_attribute_range_min_boundary")

func test_attribute_range_max_boundary() -> void:
	var d := _bare_combatant()
	d.vitality = 10
	assert(d.hp_max == 50, "max vit=10: hp_max should be 50, got %d" % d.hp_max)
	print("  PASS test_attribute_range_max_boundary")

func test_hp_formula_with_max_vit() -> void:
	var d := _bare_combatant()
	d.vitality   = 10
	d.unit_class = "vanguard"  # vit:2
	# hp = 10 + 0 + 10*4 + 2 = 52
	assert(d.hp_max == 52,
		"vit=10 + vanguard vit:2 should give hp_max=52, got %d" % d.hp_max)
	print("  PASS test_hp_formula_with_max_vit")

## --- Kindred stat bonus tests ---

func test_get_kindred_stat_bonus_known() -> void:
	var d := _bare_combatant()
	d.kindred = "Half-Orc"  # strength:1
	assert(d.get_kindred_stat_bonus("strength") == 1,
		"Half-Orc kindred strength bonus should be 1, got %d" % d.get_kindred_stat_bonus("strength"))
	d.kindred = "Dwarf"  # physical_armor:2
	assert(d.get_kindred_stat_bonus("physical_armor") == 2,
		"Dwarf kindred physical_armor bonus should be 2, got %d" % d.get_kindred_stat_bonus("physical_armor"))
	d.kindred = "Gnome"  # cognition:1
	assert(d.get_kindred_stat_bonus("cognition") == 1,
		"Gnome kindred cognition bonus should be 1, got %d" % d.get_kindred_stat_bonus("cognition"))
	d.kindred = "Human"  # willpower:1
	assert(d.get_kindred_stat_bonus("willpower") == 1,
		"Human kindred willpower bonus should be 1, got %d" % d.get_kindred_stat_bonus("willpower"))
	print("  PASS test_get_kindred_stat_bonus_known")

func test_get_kindred_stat_bonus_unknown_returns_zero() -> void:
	var d := _bare_combatant()
	d.kindred = ""
	assert(d.get_kindred_stat_bonus("strength") == 0,
		"unknown kindred should return 0 for any stat bonus")
	print("  PASS test_get_kindred_stat_bonus_unknown_returns_zero")

func test_physical_defense_includes_kindred_armor_bonus() -> void:
	var d := _bare_combatant()
	d.kindred = ""
	var base_pdef: int = d.physical_defense
	d.kindred = "Dwarf"  # physical_armor:2
	assert(d.physical_defense == base_pdef + 2,
		"Dwarf physical_armor:2 should raise physical_defense by 2, got %d (base %d)" % [d.physical_defense, base_pdef])
	print("  PASS test_physical_defense_includes_kindred_armor_bonus")

func test_attack_includes_kindred_str_bonus() -> void:
	var d := _bare_combatant()
	d.kindred = ""
	var base_attack: int = d.attack
	d.kindred = "Half-Orc"  # strength:1
	assert(d.attack == base_attack + 1,
		"Half-Orc str:1 should raise attack by 1, got %d (base %d)" % [d.attack, base_attack])
	print("  PASS test_attack_includes_kindred_str_bonus")

## --- Background stat bonus tests ---

func test_get_background_stat_bonus_known() -> void:
	var d := _bare_combatant()
	d.background = "soldier"  # strength:1 only
	assert(d.get_background_stat_bonus("strength") == 1,
		"soldier background strength bonus should be 1, got %d" % d.get_background_stat_bonus("strength"))
	assert(d.get_background_stat_bonus("vitality") == 0,
		"soldier background vitality bonus should be 0 (dropped), got %d" % d.get_background_stat_bonus("vitality"))
	d.background = "scholar"  # cognition:1
	assert(d.get_background_stat_bonus("cognition") == 1,
		"scholar background cognition bonus should be 1, got %d" % d.get_background_stat_bonus("cognition"))
	print("  PASS test_get_background_stat_bonus_known")

func test_get_background_stat_bonus_unknown_returns_zero() -> void:
	var d := _bare_combatant()
	d.background = ""
	assert(d.get_background_stat_bonus("strength") == 0,
		"unknown background should return 0 for any stat bonus")
	print("  PASS test_get_background_stat_bonus_unknown_returns_zero")

func test_attack_includes_background_str_bonus() -> void:
	var d := _bare_combatant()
	d.background = ""
	var base_attack: int = d.attack
	d.background = "soldier"  # strength:1
	assert(d.attack == base_attack + 1,
		"soldier str:1 should raise attack by 1, got %d (base %d)" % [d.attack, base_attack])
	print("  PASS test_attack_includes_background_str_bonus")

func test_hp_max_includes_background_vit_bonus() -> void:
	var d := _bare_combatant()
	d.background = ""
	var base_hp: int = d.hp_max
	d.background = "baker"  # vitality:1
	assert(d.hp_max == base_hp + 1,
		"baker vit:1 should raise hp_max by 1, got %d (base %d)" % [d.hp_max, base_hp])
	print("  PASS test_hp_max_includes_background_vit_bonus")
