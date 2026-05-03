extends Node

## --- Unit Tests: CombatantData + ArchetypeLibrary ---
## Run via Project > Run This Scene (F6) with this script attached to a Node.
## Tests cover derived stat formulas, alias fields, and archetype factory correctness.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_combatant_data.gd ===")
	test_derived_hp()
	test_derived_defense()
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
	test_is_dead_default_false()
	test_ability_pool_size_all_archetypes()
	test_kindred_hp_formula()
	test_kindred_stat_bonus_structural()
	test_kindred_name_pool_loaded()
	test_kindred_name_pool_unknown_safe()
	print("=== All CombatantData tests passed ===")

## --- Derived Stat Tests ---

func test_derived_hp() -> void:
	# No kindred set → bonus = 0. Formula: 10 + 0 + vitality*4.
	var d := CombatantData.new()
	d.vitality = 3
	assert(d.hp_max == 22, "hp_max should be 10+0+12=22 (no kindred, vit 3), got %d" % d.hp_max)
	d.vitality = 1
	assert(d.hp_max == 14, "hp_max should be 10+0+4=14 (no kindred, vit 1), got %d" % d.hp_max)
	print("  PASS test_derived_hp")

func test_derived_defense() -> void:
	var d := CombatantData.new()
	d.physical_armor = 7
	d.magic_armor    = 4
	assert(d.physical_defense == 7, "physical_defense should equal physical_armor (7), got %d" % d.physical_defense)
	assert(d.magic_defense    == 4, "magic_defense should equal magic_armor (4), got %d" % d.magic_defense)
	print("  PASS test_derived_defense")

func test_unit_name_alias() -> void:
	var d := CombatantData.new()
	d.character_name = "Vael"
	assert(d.unit_name == "Vael", "unit_name alias should match character_name")
	print("  PASS test_unit_name_alias")

func test_vitality_min_guard() -> void:
	# ArchetypeLibrary guards vitality >= 1. Alchemist is Gnome (+2 hp_bonus), VIT min 1.
	# Base min: 10 + 2 + 1*4 = 16. Temperament can shift by -1, so floor is 15.
	var d: CombatantData = ArchetypeLibrary.create("alchemist")
	assert(d.vitality >= 1, "vitality must be at least 1 after factory creation")
	assert(d.hp_max   >= 15, "hp_max must be >= 15 for Gnome at VIT 1 (±1 temperament), got %d" % d.hp_max)
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
		assert(d.dexterity >= 6 and d.dexterity <= 9,
			"archer_bandit dex out of range [6,9]: %d" % d.dexterity)
		assert(d.strength  >= 2 and d.strength  <= 5,
			"archer_bandit str out of range [2,5]: %d" % d.strength)
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
	assert(d.unit_class == "vanguard", "grunt class should be vanguard, got %s" % d.unit_class)
	assert(d.archetype_id == "grunt",  "archetype_id should be 'grunt'")
	print("  PASS test_archetype_grunt_class")

func test_archetype_elite_guard_armor_range() -> void:
	for i in range(10):
		var d: CombatantData = ArchetypeLibrary.create("elite_guard")
		assert(d.physical_armor >= 6 and d.physical_armor <= 9,
			"elite_guard physical_armor out of range [6,9]: %d" % d.physical_armor)
		assert(d.magic_armor >= 2 and d.magic_armor <= 4,
			"elite_guard magic_armor out of range [2,4]: %d" % d.magic_armor)
		assert(d.vitality >= 4 and d.vitality <= 8,
			"elite_guard vit out of range [4,8]: %d" % d.vitality)
	print("  PASS test_archetype_elite_guard_armor_range")

func test_archetype_unknown_falls_back_to_grunt() -> void:
	var d: CombatantData = ArchetypeLibrary.create("not_a_real_archetype")
	# Falls back to "grunt" definition, but keeps the passed archetype_id
	assert(d.unit_class == "vanguard",
		"unknown archetype should fall back to grunt's class (vanguard), got %s" % d.unit_class)
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

func test_is_dead_default_false() -> void:
	for archetype in ArchetypeLibrary.all_archetypes():
		var d: CombatantData = ArchetypeLibrary.create(archetype.archetype_id)
		assert(d.is_dead == false,
			"%s: is_dead should default false" % archetype.archetype_id)
	print("  PASS test_is_dead_default_false")

## --- Kindred Stat Tests ---

func test_kindred_hp_formula() -> void:
	# Formula: 10 + hp_bonus + vitality*4
	var cases: Dictionary = {
		"Human":    { "hp_bonus": 5,  "vit": 3, "expected": 10 + 5  + 12 },  # 27
		"Half-Orc": { "hp_bonus": 12, "vit": 3, "expected": 10 + 12 + 12 },  # 34
		"Gnome":    { "hp_bonus": 2,  "vit": 1, "expected": 10 + 2  + 4  },  # 16
		"Dwarf":    { "hp_bonus": 8,  "vit": 4, "expected": 10 + 8  + 16 },  # 34
	}
	for kindred in cases.keys():
		var c: Dictionary = cases[kindred]
		var d: CombatantData = CombatantData.new()
		d.kindred  = kindred
		d.vitality = c["vit"]
		assert(d.hp_max == c["expected"],
			"%s: expected hp_max %d, got %d" % [kindred, c["expected"], d.hp_max])
	print("  PASS test_kindred_hp_formula")

func test_kindred_stat_bonus_structural() -> void:
	# Kindred stat bonuses are structural (always-on in derived formulas) — no feat entry needed.
	# Enemies start with empty feat_ids; their kindred bonuses still flow through get_kindred_stat_bonus().
	for archetype_id in ["archer_bandit", "grunt", "alchemist", "elite_guard"]:
		var d: CombatantData = ArchetypeLibrary.create(archetype_id)
		var old_kindred_feats: Array[String] = ["adaptive", "relentless", "tinkerer", "stonehide"]
		for f_id in d.feat_ids:
			assert(f_id not in old_kindred_feats,
				"%s: old kindred feat '%s' should not be in feat_ids after migration" % [archetype_id, f_id])
	# Verify the bonus still applies structurally for a Dwarf (physical_armor:2)
	var guard: CombatantData = ArchetypeLibrary.create("elite_guard")  # Dwarf
	assert(guard.get_kindred_stat_bonus("physical_armor") == 2,
		"elite_guard (Dwarf) kindred physical_armor bonus should be 2, got %d" % guard.get_kindred_stat_bonus("physical_armor"))
	print("  PASS test_kindred_stat_bonus_structural")

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
