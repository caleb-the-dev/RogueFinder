extends Node

## --- Unit Tests: CombatantData + ArchetypeLibrary ---
## Run via Project > Run This Scene (F6) with this script attached to a Node.
## Tests cover derived stat formulas, alias fields, and archetype factory correctness.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_combatant_data.gd ===")
	test_derived_hp()
	test_derived_energy()
	test_derived_energy_regen()
	test_derived_speed()
	test_derived_attack()
	test_derived_defense_alias()
	test_unit_name_alias()
	test_vitality_min_guard()
	test_ability_pool_size()
	test_archetype_archer_bandit_ranges()
	test_archetype_alchemist_background_pool()
	test_archetype_grunt_class()
	test_archetype_elite_guard_armor_range()
	test_archetype_unknown_falls_back_to_grunt()
	test_archetype_name_override()
	test_archetype_enemy_name_empty()
	test_archetype_ally_auto_name_from_pool()
	test_ability_pool_superset_of_slots()
	test_fresh_hp_equals_hp_max()
	test_fresh_energy_equals_energy_max()
	test_is_dead_default_false()
	test_ability_pool_size_all_archetypes()
	test_kindred_speed_formula()
	test_kindred_hp_formula()
	test_kindred_feat_assignment()
	test_kindred_unknown_defaults_safe()
	test_kindred_name_pool_loaded()
	test_kindred_name_pool_unknown_safe()
	print("=== All CombatantData tests passed ===")

## --- Derived Stat Tests ---

func test_derived_hp() -> void:
	# No kindred set → bonus = 0. Formula: 10 + 0 + vitality*6.
	var d := CombatantData.new()
	d.vitality = 3
	assert(d.hp_max == 28, "hp_max should be 10+0+18=28 (no kindred, vit 3), got %d" % d.hp_max)
	d.vitality = 1
	assert(d.hp_max == 16, "hp_max should be 10+0+6=16 (no kindred, vit 1), got %d" % d.hp_max)
	print("  PASS test_derived_hp")

func test_derived_energy() -> void:
	var d := CombatantData.new()
	d.vitality = 4
	assert(d.energy_max == 9, "energy_max should be 5 + vitality (9), got %d" % d.energy_max)
	d.vitality = 1
	assert(d.energy_max == 6, "energy_max should be 6 for vitality 1, got %d" % d.energy_max)
	print("  PASS test_derived_energy")

func test_derived_energy_regen() -> void:
	var d := CombatantData.new()
	d.willpower = 3
	assert(d.energy_regen == 5, "energy_regen should be 2 + willpower (5), got %d" % d.energy_regen)
	d.willpower = 0
	assert(d.energy_regen == 2, "energy_regen should be 2 for willpower 0, got %d" % d.energy_regen)
	print("  PASS test_derived_energy_regen")

func test_derived_speed() -> void:
	# No kindred set → bonus = 0. Formula: 1 + 0 = 1 regardless of DEX.
	var d := CombatantData.new()
	d.dexterity = 4  # DEX no longer drives speed
	assert(d.speed == 1, "speed should be 1+0=1 (no kindred), got %d" % d.speed)
	d.kindred = "Human"
	assert(d.speed == 4, "Human speed should be 1+3=4, got %d" % d.speed)
	print("  PASS test_derived_speed")

func test_derived_attack() -> void:
	var d := CombatantData.new()
	d.strength = 5
	assert(d.attack == 10, "attack should be 5 + strength (10), got %d" % d.attack)
	d.strength = 0
	assert(d.attack == 5, "attack should be 5 for strength 0, got %d" % d.attack)
	print("  PASS test_derived_attack")

func test_derived_defense_alias() -> void:
	var d := CombatantData.new()
	d.armor_defense = 7
	assert(d.defense == 7, "defense should alias armor_defense (7), got %d" % d.defense)
	print("  PASS test_derived_defense_alias")

func test_unit_name_alias() -> void:
	var d := CombatantData.new()
	d.character_name = "Vael"
	assert(d.unit_name == "Vael", "unit_name alias should match character_name")
	print("  PASS test_unit_name_alias")

func test_vitality_min_guard() -> void:
	# ArchetypeLibrary guards vitality >= 1. Alchemist is Gnome (+2 hp_bonus), VIT min 1.
	# Minimum hp_max = 10 + 2 + 1*6 = 18.
	var d: CombatantData = ArchetypeLibrary.create("alchemist")
	assert(d.vitality >= 1, "vitality must be at least 1 after factory creation")
	assert(d.hp_max   >= 18, "hp_max must be >= 18 for Gnome at VIT 1, got %d" % d.hp_max)
	print("  PASS test_vitality_min_guard")

## --- Archetype Factory Tests ---

func test_ability_pool_size() -> void:
	var d: CombatantData = ArchetypeLibrary.create("archer_bandit")
	assert(d.abilities.size() == 4, "ability pool must have exactly 4 slots, got %d" % d.abilities.size())
	print("  PASS test_ability_pool_size")

func test_archetype_archer_bandit_ranges() -> void:
	# Run several times to catch out-of-range rolls statistically
	for i in range(20):
		var d: CombatantData = ArchetypeLibrary.create("archer_bandit")
		assert(d.dexterity >= 3 and d.dexterity <= 4,
			"archer_bandit dex out of range [3,4]: %d" % d.dexterity)
		assert(d.strength  >= 1 and d.strength  <= 2,
			"archer_bandit str out of range [1,2]: %d" % d.strength)
		assert(d.background in ["Crook", "Soldier"],
			"archer_bandit background not in pool: %s" % d.background)
	print("  PASS test_archetype_archer_bandit_ranges")

func test_archetype_alchemist_background_pool() -> void:
	var seen: Dictionary = {}
	# Draw enough times to hit all three backgrounds with high probability
	for i in range(60):
		var d: CombatantData = ArchetypeLibrary.create("alchemist")
		assert(d.background in ["Baker", "Scholar", "Merchant"],
			"alchemist background not in allowed pool: %s" % d.background)
		seen[d.background] = true
	# All three should appear in 60 draws (1/3 each → P(all seen) > 0.9999)
	assert(seen.has("Baker"),    "alchemist should occasionally roll Baker")
	assert(seen.has("Scholar"),  "alchemist should occasionally roll Scholar")
	assert(seen.has("Merchant"), "alchemist should occasionally roll Merchant")
	print("  PASS test_archetype_alchemist_background_pool")

func test_archetype_grunt_class() -> void:
	var d: CombatantData = ArchetypeLibrary.create("grunt")
	assert(d.unit_class == "Barbarian", "grunt class should be Barbarian, got %s" % d.unit_class)
	assert(d.archetype_id == "grunt",   "archetype_id should be 'grunt'")
	print("  PASS test_archetype_grunt_class")

func test_archetype_elite_guard_armor_range() -> void:
	for i in range(10):
		var d: CombatantData = ArchetypeLibrary.create("elite_guard")
		assert(d.armor_defense >= 7 and d.armor_defense <= 10,
			"elite_guard armor out of range [7,10]: %d" % d.armor_defense)
		assert(d.vitality >= 3 and d.vitality <= 5,
			"elite_guard vit out of range [3,5]: %d" % d.vitality)
	print("  PASS test_archetype_elite_guard_armor_range")

func test_archetype_unknown_falls_back_to_grunt() -> void:
	var d: CombatantData = ArchetypeLibrary.create("not_a_real_archetype")
	# Falls back to "grunt" definition, but keeps the passed archetype_id
	assert(d.unit_class == "Barbarian",
		"unknown archetype should fall back to grunt's class (Barbarian)")
	print("  PASS test_archetype_unknown_falls_back_to_grunt")

func test_archetype_name_override() -> void:
	var d: CombatantData = ArchetypeLibrary.create("grunt", "Claude")
	assert(d.character_name == "Claude",
		"character_name override should be 'Claude', got %s" % d.character_name)
	print("  PASS test_archetype_name_override")

func test_archetype_enemy_name_empty() -> void:
	# Enemies (is_player=false) with no explicit name should have an empty character_name.
	# Unit3D will display the archetype label above their head instead.
	for i in range(10):
		var d: CombatantData = ArchetypeLibrary.create("grunt")
		assert(d.character_name == "",
			"enemy grunt with no name should be empty, got '%s'" % d.character_name)
	print("  PASS test_archetype_enemy_name_empty")

func test_archetype_ally_auto_name_from_pool() -> void:
	# Player allies (is_player=true) with no explicit name draw from the flavor pool.
	var grunt_names: Array = ["Brak", "Mord", "Thug", "Krak", "Uge", "Dorn"]
	for i in range(20):
		var d: CombatantData = ArchetypeLibrary.create("grunt", "", true)
		assert(d.character_name in grunt_names,
			"ally grunt auto name '%s' is not in grunt name pool" % d.character_name)
	print("  PASS test_archetype_ally_auto_name_from_pool")

## --- Persistent Run State Tests (Slice 1) ---

func test_ability_pool_superset_of_slots() -> void:
	# Every non-empty active slot must appear in ability_pool.
	for archetype in ArchetypeLibrary.all_archetypes():
		var d: CombatantData = ArchetypeLibrary.create(archetype.archetype_id)
		for ab in d.abilities:
			if ab != "":
				assert(ab in d.ability_pool,
					"%s: active slot '%s' missing from ability_pool" % [archetype.archetype_id, ab])
	print("  PASS test_ability_pool_superset_of_slots")

func test_fresh_hp_equals_hp_max() -> void:
	for archetype in ArchetypeLibrary.all_archetypes():
		var d: CombatantData = ArchetypeLibrary.create(archetype.archetype_id)
		assert(d.current_hp == d.hp_max,
			"%s: current_hp %d != hp_max %d" % [archetype.archetype_id, d.current_hp, d.hp_max])
	print("  PASS test_fresh_hp_equals_hp_max")

func test_fresh_energy_equals_energy_max() -> void:
	for archetype in ArchetypeLibrary.all_archetypes():
		var d: CombatantData = ArchetypeLibrary.create(archetype.archetype_id)
		assert(d.current_energy == d.energy_max,
			"%s: current_energy %d != energy_max %d" % [archetype.archetype_id, d.current_energy, d.energy_max])
	print("  PASS test_fresh_energy_equals_energy_max")

func test_is_dead_default_false() -> void:
	for archetype in ArchetypeLibrary.all_archetypes():
		var d: CombatantData = ArchetypeLibrary.create(archetype.archetype_id)
		assert(d.is_dead == false,
			"%s: is_dead should default false" % archetype.archetype_id)
	print("  PASS test_is_dead_default_false")

## --- Kindred Stat Tests ---

func test_kindred_speed_formula() -> void:
	# 1 + kindred_speed_bonus; DEX is irrelevant
	var cases: Dictionary = { "Human": 4, "Half-Orc": 3, "Gnome": 5, "Dwarf": 2 }
	for kindred in cases.keys():
		var d: CombatantData = CombatantData.new()
		d.kindred   = kindred
		d.dexterity = 5  # should have zero effect on speed
		assert(d.speed == cases[kindred],
			"%s: expected speed %d, got %d" % [kindred, cases[kindred], d.speed])
	print("  PASS test_kindred_speed_formula")

func test_kindred_hp_formula() -> void:
	# Formula: 10 + hp_bonus + vitality*6
	var cases: Dictionary = {
		"Human":    { "hp_bonus": 5,  "vit": 3, "expected": 10 + 5  + 18 },  # 33
		"Half-Orc": { "hp_bonus": 12, "vit": 3, "expected": 10 + 12 + 18 },  # 40
		"Gnome":    { "hp_bonus": 2,  "vit": 1, "expected": 10 + 2  + 6  },  # 18
		"Dwarf":    { "hp_bonus": 8,  "vit": 4, "expected": 10 + 8  + 24 },  # 42
	}
	for kindred in cases.keys():
		var c: Dictionary = cases[kindred]
		var d: CombatantData = CombatantData.new()
		d.kindred  = kindred
		d.vitality = c["vit"]
		assert(d.hp_max == c["expected"],
			"%s: expected hp_max %d, got %d" % [kindred, c["expected"], d.hp_max])
	print("  PASS test_kindred_hp_formula")

func test_kindred_feat_assignment() -> void:
	var expected_feats: Dictionary = {
		"RogueFinder":  "adaptive",
		"archer_bandit": "adaptive",   # also Human
		"grunt":         "relentless",
		"alchemist":     "tinkerer",
		"elite_guard":   "stonehide",
	}
	for archetype_id in expected_feats.keys():
		var d: CombatantData = ArchetypeLibrary.create(archetype_id)
		assert(d.kindred_feat_id == expected_feats[archetype_id],
			"%s: expected feat '%s', got '%s'" % [archetype_id, expected_feats[archetype_id], d.kindred_feat_id])
	print("  PASS test_kindred_feat_assignment")

func test_kindred_unknown_defaults_safe() -> void:
	var d: CombatantData = CombatantData.new()
	d.kindred = "Unknown"
	assert(d.speed  == 1, "Unknown kindred speed should be 1+0=1, got %d" % d.speed)
	assert(d.hp_max == 10 + (d.vitality * 6),
		"Unknown kindred hp_max should use 0 bonus, got %d" % d.hp_max)
	assert(KindredLibrary.get_feat_name("Unknown") == "",
		"Unknown kindred feat_name should be empty string")
	print("  PASS test_kindred_unknown_defaults_safe")

## Every known kindred must load a non-empty name pool with a known flavor name —
## proves the CSV `name_pool` column parses correctly and reaches get_name_pool().
func test_kindred_name_pool_loaded() -> void:
	var expected_member: Dictionary = {
		"Human":    "Kale",
		"Half-Orc": "Brak",
		"Gnome":    "Finch",
		"Dwarf":    "Sven",
	}
	for kindred in expected_member.keys():
		var pool: Array[String] = KindredLibrary.get_name_pool(kindred)
		assert(not pool.is_empty(),
			"%s: name_pool should not be empty" % kindred)
		assert(expected_member[kindred] in pool,
			"%s: expected '%s' in name_pool, got %s" % [kindred, expected_member[kindred], str(pool)])
	print("  PASS test_kindred_name_pool_loaded")

## Unknown kindred returns an empty pool — ArchetypeLibrary.create() falls back to "Unit".
func test_kindred_name_pool_unknown_safe() -> void:
	var pool: Array[String] = KindredLibrary.get_name_pool("NotAKindred")
	assert(pool.is_empty(),
		"Unknown kindred name_pool should be empty, got %s" % str(pool))
	print("  PASS test_kindred_name_pool_unknown_safe")

func test_ability_pool_size_all_archetypes() -> void:
	# RogueFinder / archer_bandit / grunt have 4 active + 4 pool_extras = 8.
	# alchemist / elite_guard have no pool_extras = 4.
	var expected: Dictionary = {
		"RogueFinder":  8,
		"archer_bandit": 8,
		"grunt":         8,
		"alchemist":     4,
		"elite_guard":   4,
	}
	for archetype_id in expected.keys():
		var d: CombatantData = ArchetypeLibrary.create(archetype_id)
		assert(d.ability_pool.size() == expected[archetype_id],
			"%s: expected pool size %d, got %d" % [archetype_id, expected[archetype_id], d.ability_pool.size()])
	print("  PASS test_ability_pool_size_all_archetypes")
