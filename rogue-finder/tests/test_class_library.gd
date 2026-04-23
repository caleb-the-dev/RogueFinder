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
	var c: ClassData = ClassLibrary.get_class("rogue")
	assert(c != null,                     "get_class('rogue') must not be null")
	assert(c.class_id == "rogue",         "class_id should be 'rogue'")
	assert(c.class_name == "Rogue",       "class_name should be 'Rogue'")
	assert(c.starting_ability_id != "",   "starting_ability_id must not be empty")
	assert(c.description != "",           "description must not be empty")
	print("  PASS test_get_known_id")

func test_get_unknown_id_is_stub_not_null() -> void:
	var c: ClassData = ClassLibrary.get_class("not_a_real_class")
	assert(c != null,                          "get_class unknown id must never return null")
	assert(c.class_name == "Unknown",          "stub class_name should be 'Unknown'")
	assert(c.starting_ability_id == "",        "stub starting_ability_id should be empty")
	print("  PASS test_get_unknown_id_is_stub_not_null")

func test_all_classes_full_roster() -> void:
	var ids: Array[String] = []
	for c in ClassLibrary.all_classes():
		ids.append(c.class_id)
	assert("rogue"     in ids, "roster missing 'rogue'")
	assert("barbarian" in ids, "roster missing 'barbarian'")
	assert("wizard"    in ids, "roster missing 'wizard'")
	assert("warrior"   in ids, "roster missing 'warrior'")
	print("  PASS test_all_classes_full_roster")

func test_reload_reparses() -> void:
	ClassLibrary.reload()
	assert(ClassLibrary.all_classes().size() == 4,
		"reload() should restore full roster of 4, got %d" % ClassLibrary.all_classes().size())
	print("  PASS test_reload_reparses")

func test_known_ability_ids_are_valid() -> void:
	# Verifies each class points at an ability that actually exists in AbilityLibrary.
	for c in ClassLibrary.all_classes():
		assert(AbilityLibrary.ABILITIES.has(c.starting_ability_id),
			"%s: starting_ability_id '%s' not found in AbilityLibrary" % [c.class_id, c.starting_ability_id])
	print("  PASS test_known_ability_ids_are_valid")

func test_unlocked_by_default_all_true() -> void:
	for c in ClassLibrary.all_classes():
		assert(c.unlocked_by_default == true,
			"%s: unlocked_by_default should be true at v1" % c.class_id)
	print("  PASS test_unlocked_by_default_all_true")

func test_tags_parsed() -> void:
	var rogue: ClassData = ClassLibrary.get_class("rogue")
	assert(rogue.tags.size() > 0, "rogue should have at least one tag")
	assert("agile" in rogue.tags, "rogue tags should include 'agile'")
	print("  PASS test_tags_parsed")
