extends Node

## --- Unit Tests: Temperament system ---
## Covers TemperamentLibrary, CombatantData.get_temperament_stat_bonus(),
## derived-stat wiring, ArchetypeLibrary.create() assignment, and CSV rule
## enforcement for backgrounds (+1 single stat) and classes (4 pts, max +2).
## Headless — no scene required.

const GODOT_EXE := "C:/Users/caleb/Documents/Video Game Developement/Godot/Godot_v4.5.1-stable_win64_console.exe"

func _ready() -> void:
	print("=== test_temperament.gd ===")
	test_library_loads_all_temperaments()
	test_neutral_exists()
	test_neutral_bonus_zero_for_all_stats()
	test_boosted_stat_returns_plus_one()
	test_hindered_stat_returns_minus_one()
	test_unaffected_stat_returns_zero()
	test_temperament_wires_into_attack()
	test_temperament_wires_into_hp_max()
	test_temperament_wires_into_energy_regen()
	test_temperament_wires_into_speed()
	test_archetype_create_assigns_temperament()
	test_all_temperaments_boosted_ne_hindered()
	test_all_backgrounds_single_plus_one()
	test_all_classes_four_points_max_two()
	print("=== All temperament tests passed ===")

## --- Helpers ---

func _bare_combatant() -> CombatantData:
	var d := CombatantData.new()
	d.kindred        = ""
	d.background     = ""
	d.unit_class     = ""
	d.feat_ids       = []
	d.strength  = 5; d.dexterity = 5; d.cognition = 5; d.willpower = 5; d.vitality = 5
	d.physical_armor = 0; d.magic_armor = 0
	d.temperament_id = "even"
	return d

## --- Library tests ---

func test_library_loads_all_temperaments() -> void:
	TemperamentLibrary.reload()
	assert(TemperamentLibrary.all_temperaments().size() == 21,
		"Expected 21 temperaments (20 non-neutral + 1 neutral), got %d" % TemperamentLibrary.all_temperaments().size())
	print("  PASS test_library_loads_all_temperaments")

func test_neutral_exists() -> void:
	var t: TemperamentData = TemperamentLibrary.get_temperament("even")
	assert(t.temperament_id == "even", "neutral temperament id should be 'even'")
	assert(t.boosted_stat   == "",     "neutral boosted_stat should be empty")
	assert(t.hindered_stat  == "",     "neutral hindered_stat should be empty")
	print("  PASS test_neutral_exists")

## --- Bonus getter tests ---

func test_neutral_bonus_zero_for_all_stats() -> void:
	var d := _bare_combatant()
	d.temperament_id = "even"
	for stat in ["strength", "dexterity", "cognition", "willpower", "vitality"]:
		assert(d.get_temperament_stat_bonus(stat) == 0,
			"neutral 'even' should return 0 for %s" % stat)
	print("  PASS test_neutral_bonus_zero_for_all_stats")

func test_boosted_stat_returns_plus_one() -> void:
	var d := _bare_combatant()
	d.temperament_id = "fierce"  # +strength / -vitality
	assert(d.get_temperament_stat_bonus("strength") == 1,
		"fierce should return +1 for strength, got %d" % d.get_temperament_stat_bonus("strength"))
	print("  PASS test_boosted_stat_returns_plus_one")

func test_hindered_stat_returns_minus_one() -> void:
	var d := _bare_combatant()
	d.temperament_id = "fierce"  # +strength / -vitality
	assert(d.get_temperament_stat_bonus("vitality") == -1,
		"fierce should return -1 for vitality, got %d" % d.get_temperament_stat_bonus("vitality"))
	print("  PASS test_hindered_stat_returns_minus_one")

func test_unaffected_stat_returns_zero() -> void:
	var d := _bare_combatant()
	d.temperament_id = "fierce"  # +strength / -vitality; cognition unaffected
	assert(d.get_temperament_stat_bonus("cognition") == 0,
		"fierce should return 0 for cognition, got %d" % d.get_temperament_stat_bonus("cognition"))
	print("  PASS test_unaffected_stat_returns_zero")

## --- Derived-stat wiring tests ---

func test_temperament_wires_into_attack() -> void:
	var d := _bare_combatant()
	d.temperament_id = "even"
	var base_attack: int = d.attack
	d.temperament_id = "brutish"  # +strength / -dexterity
	assert(d.attack == base_attack + 1,
		"brutish (+STR) should raise attack by 1, got %d (base %d)" % [d.attack, base_attack])
	d.temperament_id = "nimble"  # +dexterity / -strength
	assert(d.attack == base_attack - 1,
		"nimble (-STR) should lower attack by 1, got %d (base %d)" % [d.attack, base_attack])
	print("  PASS test_temperament_wires_into_attack")

func test_temperament_wires_into_hp_max() -> void:
	var d := _bare_combatant()
	d.temperament_id = "even"
	var base_hp: int = d.hp_max
	d.temperament_id = "hardy"  # +vitality / -strength
	assert(d.hp_max == base_hp + 1,
		"hardy (+VIT) should raise hp_max by 1, got %d (base %d)" % [d.hp_max, base_hp])
	d.temperament_id = "fierce"  # +strength / -vitality
	assert(d.hp_max == base_hp - 1,
		"fierce (-VIT) should lower hp_max by 1, got %d (base %d)" % [d.hp_max, base_hp])
	print("  PASS test_temperament_wires_into_hp_max")

func test_temperament_wires_into_energy_regen() -> void:
	var d := _bare_combatant()
	d.temperament_id = "even"
	var base_regen: int = d.energy_regen
	d.temperament_id = "stoic"  # +willpower / -strength
	assert(d.energy_regen == base_regen + 1,
		"stoic (+WIL) should raise energy_regen by 1, got %d (base %d)" % [d.energy_regen, base_regen])
	d.temperament_id = "reckless"  # +strength / -willpower
	assert(d.energy_regen == base_regen - 1,
		"reckless (-WIL) should lower energy_regen by 1, got %d (base %d)" % [d.energy_regen, base_regen])
	print("  PASS test_temperament_wires_into_energy_regen")

func test_temperament_wires_into_speed() -> void:
	var d := _bare_combatant()
	d.temperament_id = "even"
	var base_speed: int = d.speed
	d.temperament_id = "nimble"  # +dexterity / -strength
	assert(d.speed == base_speed + 1,
		"nimble (+DEX) should raise speed by 1, got %d (base %d)" % [d.speed, base_speed])
	d.temperament_id = "brutish"  # +strength / -dexterity
	assert(d.speed == base_speed - 1,
		"brutish (-DEX) should lower speed by 1, got %d (base %d)" % [d.speed, base_speed])
	print("  PASS test_temperament_wires_into_speed")

## --- Creation tests ---

func test_archetype_create_assigns_temperament() -> void:
	for _i in range(5):
		var d: CombatantData = ArchetypeLibrary.create("grunt")
		assert(d.temperament_id != "",
			"ArchetypeLibrary.create() must assign a non-empty temperament_id")
		var t: TemperamentData = TemperamentLibrary.get_temperament(d.temperament_id)
		assert(t.temperament_id == d.temperament_id,
			"Assigned temperament_id '%s' must exist in TemperamentLibrary" % d.temperament_id)
	print("  PASS test_archetype_create_assigns_temperament")

## --- CSV rule enforcement ---

func test_all_temperaments_boosted_ne_hindered() -> void:
	for t in TemperamentLibrary.all_temperaments():
		if t.boosted_stat == "" and t.hindered_stat == "":
			continue  # neutral is fine
		assert(t.boosted_stat  != "", "non-neutral temperament '%s' must have boosted_stat" % t.temperament_id)
		assert(t.hindered_stat != "", "non-neutral temperament '%s' must have hindered_stat" % t.temperament_id)
		assert(t.boosted_stat  != t.hindered_stat,
			"temperament '%s': boosted and hindered must differ" % t.temperament_id)
	print("  PASS test_all_temperaments_boosted_ne_hindered")

func test_all_backgrounds_single_plus_one() -> void:
	for bg in BackgroundLibrary.all_backgrounds():
		var bonuses: Dictionary = bg.stat_bonuses
		var total: int = 0
		var max_val: int = 0
		for stat in bonuses.keys():
			var v: int = bonuses[stat]
			total += v
			max_val = maxi(max_val, v)
		assert(total == 1,
			"background '%s' must give exactly +1 total, got %d" % [bg.background_id, total])
		assert(max_val <= 1,
			"background '%s' must not exceed +1 on any stat, max was %d" % [bg.background_id, max_val])
		assert(bonuses.size() == 1,
			"background '%s' must affect exactly 1 stat, affects %d" % [bg.background_id, bonuses.size()])
	print("  PASS test_all_backgrounds_single_plus_one")

func test_all_classes_four_points_max_two() -> void:
	for c in ClassLibrary.all_classes():
		var bonuses: Dictionary = c.stat_bonuses
		var total: int = 0
		var max_val: int = 0
		var min_val: int = 0
		for stat in bonuses.keys():
			var v: int = bonuses[stat]
			total += v
			max_val = maxi(max_val, v)
			min_val = mini(min_val, v)
		assert(total == 4,
			"class '%s' must give exactly 4 total stat points, got %d" % [c.class_id, total])
		assert(max_val <= 2,
			"class '%s' must not exceed +2 on any stat, max was %d" % [c.class_id, max_val])
		assert(min_val >= 0,
			"class '%s' must have no negative stat bonuses, min was %d" % [c.class_id, min_val])
	print("  PASS test_all_classes_four_points_max_two")
