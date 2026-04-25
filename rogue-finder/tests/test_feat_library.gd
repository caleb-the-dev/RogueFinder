extends Node

## --- Unit Tests: FeatLibrary ---
## Run via Project > Run This Scene (F6). No scene nodes required.

func _ready() -> void:
	print("=== test_feat_library.gd ===")
	test_csv_loads()
	test_all_four_feats_present()
	test_get_adaptive_name()
	test_get_adaptive_description()
	test_get_stonehide_description_nonempty()
	test_unknown_id_returns_stub_not_null()
	test_unknown_id_stub_name()
	test_reload_repopulates()
	print("=== All FeatLibrary tests passed ===")

func test_csv_loads() -> void:
	FeatLibrary.reload()
	assert(FeatLibrary.all_feats().size() > 0, "FeatLibrary should load at least one feat")
	print("  PASS test_csv_loads")

func test_all_four_feats_present() -> void:
	assert(FeatLibrary.all_feats().size() == 4,
		"Expected 4 feats, got %d" % FeatLibrary.all_feats().size())
	print("  PASS test_all_four_feats_present")

func test_get_adaptive_name() -> void:
	var feat: FeatData = FeatLibrary.get_feat("adaptive")
	assert(feat != null,               "get_feat('adaptive') must not be null")
	assert(feat.name == "Adaptive",    "name should be 'Adaptive', got '%s'" % feat.name)
	print("  PASS test_get_adaptive_name")

func test_get_adaptive_description() -> void:
	var feat: FeatData = FeatLibrary.get_feat("adaptive")
	assert(feat.description != "",     "adaptive description must not be empty")
	assert("survivors" in feat.description,
		"adaptive description should mention 'survivors', got '%s'" % feat.description)
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
	assert(FeatLibrary.all_feats().size() == 4,
		"reload() should restore 4 feats, got %d" % FeatLibrary.all_feats().size())
	var feat: FeatData = FeatLibrary.get_feat("adaptive")
	assert(feat.name == "Adaptive",    "reload() should repopulate adaptive feat")
	print("  PASS test_reload_repopulates")
