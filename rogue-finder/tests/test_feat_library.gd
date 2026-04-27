extends Node

## --- Unit Tests: FeatLibrary ---
## Run via test_feat_library.tscn headlessly. No scene nodes required.

func _ready() -> void:
	print("=== test_feat_library.gd ===")
	test_csv_loads()
	test_all_feats_count()
	test_get_shadow_step_name()
	test_get_shadow_step_description()
	test_get_iron_will_description_nonempty()
	test_unknown_id_returns_stub_not_null()
	test_unknown_id_stub_name()
	test_reload_repopulates()
	test_stat_bonuses_parsed()
	test_source_type_parsed()
	test_unknown_feat_returns_empty_bonuses()
	print("=== All FeatLibrary tests passed ===")

func test_csv_loads() -> void:
	FeatLibrary.reload()
	assert(FeatLibrary.all_feats().size() > 0, "FeatLibrary should load at least one feat")
	print("  PASS test_csv_loads")

func test_all_feats_count() -> void:
	assert(FeatLibrary.all_feats().size() == 32,
		"Expected 32 feats, got %d" % FeatLibrary.all_feats().size())
	print("  PASS test_all_feats_count")

func test_get_shadow_step_name() -> void:
	var feat: FeatData = FeatLibrary.get_feat("shadow_step")
	assert(feat != null,                   "get_feat('shadow_step') must not be null")
	assert(feat.name == "Shadow Step",     "name should be 'Shadow Step', got '%s'" % feat.name)
	print("  PASS test_get_shadow_step_name")

func test_get_shadow_step_description() -> void:
	var feat: FeatData = FeatLibrary.get_feat("shadow_step")
	assert(feat.description != "",         "shadow_step description must not be empty")
	print("  PASS test_get_shadow_step_description")

func test_get_iron_will_description_nonempty() -> void:
	var feat: FeatData = FeatLibrary.get_feat("iron_will")
	assert(feat.description != "",         "iron_will description must not be empty")
	print("  PASS test_get_iron_will_description_nonempty")

func test_unknown_id_returns_stub_not_null() -> void:
	var feat: FeatData = FeatLibrary.get_feat("not_a_real_feat")
	assert(feat != null,               "get_feat unknown id must never return null")
	print("  PASS test_unknown_id_returns_stub_not_null")

func test_unknown_id_stub_name() -> void:
	var feat: FeatData = FeatLibrary.get_feat("not_a_real_feat")
	assert(feat.name == "Unknown Feat",
		"stub name should be 'Unknown Feat', got '%s'" % feat.name)
	print("  PASS test_unknown_id_stub_name")

func test_reload_repopulates() -> void:
	FeatLibrary.reload()
	assert(FeatLibrary.all_feats().size() == 32,
		"reload() should restore 32 feats, got %d" % FeatLibrary.all_feats().size())
	var feat: FeatData = FeatLibrary.get_feat("shadow_step")
	assert(feat.name == "Shadow Step", "reload() should repopulate shadow_step feat")
	print("  PASS test_reload_repopulates")

func test_stat_bonuses_parsed() -> void:
	var iron_guard: FeatData = FeatLibrary.get_feat("iron_guard")
	assert(iron_guard.stat_bonuses.has("physical_armor"),
		"iron_guard should have physical_armor bonus, got %s" % str(iron_guard.stat_bonuses))
	assert(iron_guard.stat_bonuses["physical_armor"] == 2,
		"iron_guard physical_armor should be 2, got %d" % iron_guard.stat_bonuses["physical_armor"])

	var iron_will: FeatData = FeatLibrary.get_feat("iron_will")
	assert(iron_will.stat_bonuses.has("willpower"),
		"iron_will should have willpower bonus")
	assert(iron_will.stat_bonuses["willpower"] == 2,
		"iron_will willpower bonus should be 2, got %d" % iron_will.stat_bonuses["willpower"])
	print("  PASS test_stat_bonuses_parsed")

func test_source_type_parsed() -> void:
	assert(FeatLibrary.get_feat("shadow_step").source_type == "class",
		"shadow_step source_type should be 'class'")
	assert(FeatLibrary.get_feat("iron_will").source_type == "class",
		"iron_will source_type should be 'class'")
	assert(FeatLibrary.get_feat("street_smart").source_type == "background",
		"street_smart source_type should be 'background'")
	print("  PASS test_source_type_parsed")

func test_unknown_feat_returns_empty_bonuses() -> void:
	var stub: FeatData = FeatLibrary.get_feat("not_a_real_feat")
	assert(stub.stat_bonuses.is_empty(),
		"unknown feat stub must have empty stat_bonuses dict")
	print("  PASS test_unknown_feat_returns_empty_bonuses")
