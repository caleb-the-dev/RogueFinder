extends Node

## --- Unit Tests: FeatLibrary ---
## Run via test_feat_library.tscn headlessly. No scene nodes required.

func _ready() -> void:
	print("=== test_feat_library.gd ===")
	test_csv_loads()
	test_all_feats_count()
	test_get_adaptive_name()
	test_get_adaptive_description()
	test_get_stonehide_description_nonempty()
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
	assert(FeatLibrary.all_feats().size() == 28,
		"Expected 28 feats, got %d" % FeatLibrary.all_feats().size())
	print("  PASS test_all_feats_count")

func test_get_adaptive_name() -> void:
	var feat: FeatData = FeatLibrary.get_feat("adaptive")
	assert(feat != null,               "get_feat('adaptive') must not be null")
	assert(feat.name == "Adaptive",    "name should be 'Adaptive', got '%s'" % feat.name)
	print("  PASS test_get_adaptive_name")

func test_get_adaptive_description() -> void:
	var feat: FeatData = FeatLibrary.get_feat("adaptive")
	assert(feat.description != "",     "adaptive description must not be empty")
	assert("willpower" in feat.description or "reinvention" in feat.description,
		"adaptive description should mention the feat flavor, got '%s'" % feat.description)
	print("  PASS test_get_adaptive_description")

func test_get_stonehide_description_nonempty() -> void:
	var feat: FeatData = FeatLibrary.get_feat("stonehide")
	assert(feat.description != "",     "stonehide description must not be empty")
	print("  PASS test_get_stonehide_description_nonempty")

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
	assert(FeatLibrary.all_feats().size() == 28,
		"reload() should restore 28 feats, got %d" % FeatLibrary.all_feats().size())
	var feat: FeatData = FeatLibrary.get_feat("adaptive")
	assert(feat.name == "Adaptive",    "reload() should repopulate adaptive feat")
	print("  PASS test_reload_repopulates")

func test_stat_bonuses_parsed() -> void:
	var stonehide: FeatData = FeatLibrary.get_feat("stonehide")
	assert(stonehide.stat_bonuses.has("armor_defense"),
		"stonehide should have armor_defense bonus, got %s" % str(stonehide.stat_bonuses))
	assert(stonehide.stat_bonuses["armor_defense"] == 2,
		"stonehide armor_defense should be 2, got %d" % stonehide.stat_bonuses["armor_defense"])

	var adaptive: FeatData = FeatLibrary.get_feat("adaptive")
	assert(adaptive.stat_bonuses.has("willpower"),
		"adaptive should have willpower bonus")
	assert(adaptive.stat_bonuses["willpower"] == 1,
		"adaptive willpower bonus should be 1, got %d" % adaptive.stat_bonuses["willpower"])
	print("  PASS test_stat_bonuses_parsed")

func test_source_type_parsed() -> void:
	assert(FeatLibrary.get_feat("adaptive").source_type == "kindred",
		"adaptive source_type should be 'kindred'")
	assert(FeatLibrary.get_feat("shadow_step").source_type == "class",
		"shadow_step source_type should be 'class'")
	assert(FeatLibrary.get_feat("street_smart").source_type == "background",
		"street_smart source_type should be 'background'")
	print("  PASS test_source_type_parsed")

func test_unknown_feat_returns_empty_bonuses() -> void:
	var stub: FeatData = FeatLibrary.get_feat("not_a_real_feat")
	assert(stub.stat_bonuses.is_empty(),
		"unknown feat stub must have empty stat_bonuses dict")
	print("  PASS test_unknown_feat_returns_empty_bonuses")
