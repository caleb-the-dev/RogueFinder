extends Node

## --- Unit Tests: PortraitLibrary + PortraitData ---
## Run via Project > Run This Scene (F6).
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_portrait_library.gd ===")
	test_load_succeeds()
	test_expected_row_count()
	test_get_known_id()
	test_get_unknown_id_is_stub_not_null()
	test_all_portraits_full_roster()
	test_reload_reparses()
	test_artwork_paths_are_set()
	test_tags_parsed()
	print("=== All PortraitLibrary tests passed ===")

func test_load_succeeds() -> void:
	PortraitLibrary.reload()
	assert(PortraitLibrary.all_portraits().size() > 0,
		"PortraitLibrary should load at least one portrait")
	print("  PASS test_load_succeeds")

func test_expected_row_count() -> void:
	assert(PortraitLibrary.all_portraits().size() == 6,
		"Expected 6 portraits, got %d" % PortraitLibrary.all_portraits().size())
	print("  PASS test_expected_row_count")

func test_get_known_id() -> void:
	var p: PortraitData = PortraitLibrary.get_portrait("portrait_human_m")
	assert(p != null,                          "get_portrait('portrait_human_m') must not be null")
	assert(p.portrait_id == "portrait_human_m","portrait_id should be 'portrait_human_m'")
	assert(p.portrait_name != "",              "portrait_name must not be empty")
	assert(p.artwork_path != "",               "artwork_path must not be empty")
	print("  PASS test_get_known_id")

func test_get_unknown_id_is_stub_not_null() -> void:
	var p: PortraitData = PortraitLibrary.get_portrait("not_a_real_portrait")
	assert(p != null,                          "get_portrait unknown id must never return null")
	assert(p.portrait_name == "Unknown",       "stub portrait_name should be 'Unknown'")
	assert(p.artwork_path == "res://icon.svg", "stub artwork_path should fall back to icon.svg")
	print("  PASS test_get_unknown_id_is_stub_not_null")

func test_all_portraits_full_roster() -> void:
	var ids: Array[String] = []
	for p in PortraitLibrary.all_portraits():
		ids.append(p.portrait_id)
	assert("portrait_human_m"  in ids, "roster missing 'portrait_human_m'")
	assert("portrait_human_f"  in ids, "roster missing 'portrait_human_f'")
	assert("portrait_half_orc" in ids, "roster missing 'portrait_half_orc'")
	assert("portrait_gnome"    in ids, "roster missing 'portrait_gnome'")
	assert("portrait_dwarf"    in ids, "roster missing 'portrait_dwarf'")
	assert("portrait_unknown"  in ids, "roster missing 'portrait_unknown'")
	print("  PASS test_all_portraits_full_roster")

func test_reload_reparses() -> void:
	PortraitLibrary.reload()
	assert(PortraitLibrary.all_portraits().size() == 6,
		"reload() should restore full roster of 6, got %d" % PortraitLibrary.all_portraits().size())
	print("  PASS test_reload_reparses")

func test_artwork_paths_are_set() -> void:
	# All v1 entries use the placeholder icon — confirm no row has a blank path.
	for p in PortraitLibrary.all_portraits():
		assert(p.artwork_path != "",
			"%s: artwork_path must not be empty" % p.portrait_id)
	print("  PASS test_artwork_paths_are_set")

func test_tags_parsed() -> void:
	var dwarf: PortraitData = PortraitLibrary.get_portrait("portrait_dwarf")
	assert(dwarf.tags.size() > 0, "portrait_dwarf should have at least one tag")
	assert("dwarf" in dwarf.tags, "portrait_dwarf tags should include 'dwarf'")
	print("  PASS test_tags_parsed")
