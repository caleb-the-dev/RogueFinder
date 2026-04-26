extends Node

## --- Unit Tests: ClassLibrary + ClassData ---
## Run via Project > Run This Scene (F6).
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_class_library.gd ===")
	test_load_succeeds()
	test_expected_row_count()
	test_get_known_id()
	test_get_unknown_id_is_stub_not_null()
	test_all_classes_full_roster()
	test_reload_reparses()
	test_known_ability_ids_are_valid()
	test_unlocked_by_default_all_true()
	test_tags_parsed()
	test_stat_bonuses_parsed()
	test_ability_pool_parsed()
	test_stat_bonuses_empty_stub()
	print("=== All ClassLibrary tests passed ===")

func test_load_succeeds() -> void:
	ClassLibrary.reload()
	assert(ClassLibrary.all_classes().size() > 0, "ClassLibrary should load at least one class")
	print("  PASS test_load_succeeds")

func test_expected_row_count() -> void:
	assert(ClassLibrary.all_classes().size() == 4,
		"Expected 4 classes, got %d" % ClassLibrary.all_classes().size())
	print("  PASS test_expected_row_count")

func test_get_known_id() -> void:
	var c: ClassData = ClassLibrary.get_class_data("vanguard")
	assert(c != null,                         "get_class_data('vanguard') must not be null")
	assert(c.class_id == "vanguard",          "class_id should be 'vanguard'")
	assert(c.display_name == "Vanguard",      "display_name should be 'Vanguard'")
	assert(c.starting_ability_id != "",       "starting_ability_id must not be empty")
	assert(c.description != "",               "description must not be empty")
	print("  PASS test_get_known_id")

func test_get_unknown_id_is_stub_not_null() -> void:
	var c: ClassData = ClassLibrary.get_class_data("not_a_real_class")
	assert(c != null,                          "get_class_data unknown id must never return null")
	assert(c.display_name == "Unknown",        "stub display_name should be 'Unknown'")
	assert(c.starting_ability_id == "",        "stub starting_ability_id should be empty")
	assert(c.stat_bonuses.is_empty(),          "stub stat_bonuses should be empty dict")
	print("  PASS test_get_unknown_id_is_stub_not_null")

func test_all_classes_full_roster() -> void:
	var ids: Array[String] = []
	for c in ClassLibrary.all_classes():
		ids.append(c.class_id)
	assert("vanguard"  in ids, "roster missing 'vanguard'")
	assert("arcanist"  in ids, "roster missing 'arcanist'")
	assert("prowler"   in ids, "roster missing 'prowler'")
	assert("warden"    in ids, "roster missing 'warden'")
	print("  PASS test_all_classes_full_roster")

func test_reload_reparses() -> void:
	ClassLibrary.reload()
	assert(ClassLibrary.all_classes().size() == 4,
		"reload() should restore full roster of 4, got %d" % ClassLibrary.all_classes().size())
	print("  PASS test_reload_reparses")

func test_known_ability_ids_are_valid() -> void:
	for c in ClassLibrary.all_classes():
		assert(AbilityLibrary.get_ability(c.starting_ability_id).ability_id != "unknown",
			"%s: starting_ability_id '%s' not found in AbilityLibrary" % [c.class_id, c.starting_ability_id])
	print("  PASS test_known_ability_ids_are_valid")

func test_unlocked_by_default_all_true() -> void:
	for c in ClassLibrary.all_classes():
		assert(c.unlocked_by_default == true,
			"%s: unlocked_by_default should be true at v1" % c.class_id)
	print("  PASS test_unlocked_by_default_all_true")

func test_tags_parsed() -> void:
	var prowler: ClassData = ClassLibrary.get_class_data("prowler")
	assert(prowler.tags.size() > 0, "prowler should have at least one tag")
	assert("agile" in prowler.tags, "prowler tags should include 'agile'")
	print("  PASS test_tags_parsed")

func test_stat_bonuses_parsed() -> void:
	var vanguard: ClassData = ClassLibrary.get_class_data("vanguard")
	assert(vanguard.stat_bonuses.has("strength"),  "vanguard stat_bonuses must have 'strength'")
	assert(vanguard.stat_bonuses.has("vitality"),  "vanguard stat_bonuses must have 'vitality'")
	assert(vanguard.stat_bonuses["strength"] == 1, "vanguard strength bonus should be 1, got %d" % vanguard.stat_bonuses.get("strength", -1))
	assert(vanguard.stat_bonuses["vitality"] == 2, "vanguard vitality bonus should be 2, got %d" % vanguard.stat_bonuses.get("vitality", -1))

	var arcanist: ClassData = ClassLibrary.get_class_data("arcanist")
	assert(arcanist.stat_bonuses.get("cognition", 0) == 2, "arcanist cognition bonus should be 2")
	assert(arcanist.stat_bonuses.get("willpower", 0) == 1, "arcanist willpower bonus should be 1")

	var prowler: ClassData = ClassLibrary.get_class_data("prowler")
	assert(prowler.stat_bonuses.get("dexterity", 0) == 2, "prowler dexterity bonus should be 2")
	assert(prowler.stat_bonuses.get("willpower", 0) == 1, "prowler willpower bonus should be 1")

	var warden: ClassData = ClassLibrary.get_class_data("warden")
	assert(warden.stat_bonuses.get("cognition", 0) == 1, "warden cognition bonus should be 1")
	assert(warden.stat_bonuses.get("vitality", 0) == 1, "warden vitality bonus should be 1")
	assert(warden.stat_bonuses.get("willpower", 0) == 1, "warden willpower bonus should be 1")
	print("  PASS test_stat_bonuses_parsed")

func test_ability_pool_parsed() -> void:
	for c in ClassLibrary.all_classes():
		assert(c.ability_pool.size() >= 3,
			"%s: ability_pool should have at least 3 entries, got %d" % [c.class_id, c.ability_pool.size()])
	var vanguard: ClassData = ClassLibrary.get_class_data("vanguard")
	assert("shield_bash" in vanguard.ability_pool, "vanguard ability_pool should include shield_bash")
	print("  PASS test_ability_pool_parsed")

func test_stat_bonuses_empty_stub() -> void:
	var stub: ClassData = ClassLibrary.get_class_data("completely_fake_id")
	assert(stub.stat_bonuses.get("str", 0) == 0, "stub should return 0 for any stat bonus")
	print("  PASS test_stat_bonuses_empty_stub")
