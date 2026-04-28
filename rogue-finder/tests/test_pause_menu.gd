extends Node

## --- Unit Tests: Pause Menu + Archetypes Log ---
## Headless — no scene, no rendering required.
## Covers: scene-name gate, record_archetype logic, save/load round-trip,
## log filter, and SettingsStore save/load.

func _ready() -> void:
	print("=== test_pause_menu.gd ===")
	test_scene_gate_pauseable_scenes()
	test_scene_gate_blocks_menu_and_run_summary()
	test_record_archetype_adds_id()
	test_record_archetype_skips_duplicate()
	test_record_archetype_skips_empty_string()
	test_encountered_archetypes_save_round_trip()
	test_log_filter_excludes_rogue_finder()
	test_settings_store_round_trip()
	_cleanup()
	print("=== All pause menu tests passed ===")

func _cleanup() -> void:
	GameState.reset()
	GameState.delete_save()

## --- Scene Gate ---

## Gameplay scenes should be pauseable.
func test_scene_gate_pauseable_scenes() -> void:
	assert(PauseMenuManager._scene_name_is_pauseable("res://scenes/map/MapScene.tscn"),
		"MapScene must be pauseable")
	assert(PauseMenuManager._scene_name_is_pauseable("res://scenes/combat/CombatScene3D.tscn"),
		"CombatScene3D must be pauseable")
	assert(PauseMenuManager._scene_name_is_pauseable("res://scenes/city/BadurgaScene.tscn"),
		"BadurgaScene must be pauseable")
	assert(PauseMenuManager._scene_name_is_pauseable("res://scenes/ui/CharacterCreationScene.tscn"),
		"CharacterCreationScene must be pauseable")
	print("  PASS test_scene_gate_pauseable_scenes")

## Title screen and run-end summary must not allow the pause menu.
func test_scene_gate_blocks_menu_and_run_summary() -> void:
	assert(not PauseMenuManager._scene_name_is_pauseable("res://scenes/ui/MainMenuScene.tscn"),
		"MainMenuScene must NOT be pauseable")
	assert(not PauseMenuManager._scene_name_is_pauseable("res://scenes/ui/RunSummaryScene.tscn"),
		"RunSummaryScene must NOT be pauseable")
	print("  PASS test_scene_gate_blocks_menu_and_run_summary")

## --- record_archetype ---

func test_record_archetype_adds_id() -> void:
	GameState.reset()
	GameState.record_archetype("grunt")
	assert(GameState.encountered_archetypes.has("grunt"),
		"grunt should appear in encountered_archetypes after record")
	assert(GameState.encountered_archetypes.size() == 1,
		"exactly one entry expected, got %d" % GameState.encountered_archetypes.size())
	GameState.reset()
	print("  PASS test_record_archetype_adds_id")

func test_record_archetype_skips_duplicate() -> void:
	GameState.reset()
	GameState.record_archetype("grunt")
	GameState.record_archetype("grunt")
	assert(GameState.encountered_archetypes.size() == 1,
		"duplicate record must not create a second entry, got %d" % GameState.encountered_archetypes.size())
	GameState.reset()
	print("  PASS test_record_archetype_skips_duplicate")

func test_record_archetype_skips_empty_string() -> void:
	GameState.reset()
	GameState.record_archetype("")
	assert(GameState.encountered_archetypes.is_empty(),
		"empty string id must not be recorded")
	GameState.reset()
	print("  PASS test_record_archetype_skips_empty_string")

## --- Save / Load Round-Trip ---

func test_encountered_archetypes_save_round_trip() -> void:
	_cleanup()
	GameState.record_archetype("grunt")
	GameState.record_archetype("archer_bandit")
	GameState.save()
	GameState.reset()
	assert(GameState.encountered_archetypes.is_empty(),
		"encountered_archetypes must be empty after reset()")
	GameState.load_save()
	assert(GameState.encountered_archetypes.size() == 2,
		"should load 2 archetypes, got %d" % GameState.encountered_archetypes.size())
	assert(GameState.encountered_archetypes.has("grunt"),
		"grunt must be present after load")
	assert(GameState.encountered_archetypes.has("archer_bandit"),
		"archer_bandit must be present after load")
	_cleanup()
	print("  PASS test_encountered_archetypes_save_round_trip")

## --- Log Filter ---

## The archetypes log must exclude the RogueFinder player template.
func test_log_filter_excludes_rogue_finder() -> void:
	GameState.reset()
	GameState.record_archetype("grunt")
	GameState.record_archetype("RogueFinder")
	GameState.record_archetype("archer_bandit")
	var display: Array[String] = GameState.encountered_archetypes.filter(
		func(id: String) -> bool: return id != "RogueFinder"
	)
	assert("RogueFinder" not in display,
		"RogueFinder must not appear in the filtered display list")
	assert(display.size() == 2,
		"display list should have 2 entries (grunt + archer_bandit), got %d" % display.size())
	GameState.reset()
	print("  PASS test_log_filter_excludes_rogue_finder")

## --- SettingsStore ---

func test_settings_store_round_trip() -> void:
	SettingsStore.fullscreen    = false
	SettingsStore.master_volume = 0.75
	SettingsStore.music_volume  = 0.50
	SettingsStore.sfx_volume    = 0.25
	SettingsStore.save_settings()

	# Overwrite in memory, then reload from disk
	SettingsStore.fullscreen    = true
	SettingsStore.master_volume = 1.0
	SettingsStore.music_volume  = 1.0
	SettingsStore.sfx_volume    = 1.0
	SettingsStore.load_settings()

	assert(SettingsStore.fullscreen == false,
		"fullscreen should reload as false")
	assert(abs(SettingsStore.master_volume - 0.75) < 0.001,
		"master_volume should reload as 0.75, got %f" % SettingsStore.master_volume)
	assert(abs(SettingsStore.music_volume - 0.50) < 0.001,
		"music_volume should reload as 0.50, got %f" % SettingsStore.music_volume)
	assert(abs(SettingsStore.sfx_volume - 0.25) < 0.001,
		"sfx_volume should reload as 0.25, got %f" % SettingsStore.sfx_volume)
	print("  PASS test_settings_store_round_trip")
