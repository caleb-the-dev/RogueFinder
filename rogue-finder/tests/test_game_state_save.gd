extends Node

## --- Unit Tests: GameState save/load — used_event_ids persistence ---
## Run via the headless .tscn runner.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_game_state_save.gd ===")
	test_used_event_ids_round_trip()
	test_used_event_ids_default_empty_on_fresh_save()
	print("=== All GameState save tests passed ===")

func _clean() -> void:
	GameState.delete_save()
	GameState.reset()

## Populated used_event_ids survive a save → reset → load cycle intact
func test_used_event_ids_round_trip() -> void:
	_clean()
	GameState.used_event_ids.append("chest_rusty")
	GameState.used_event_ids.append("wounded_traveler")
	GameState.save()
	GameState.reset()
	assert(GameState.used_event_ids.is_empty(),
		"used_event_ids should be empty after reset(), got %d" % GameState.used_event_ids.size())
	GameState.load_save()
	assert(GameState.used_event_ids.size() == 2,
		"used_event_ids should have 2 after load, got %d" % GameState.used_event_ids.size())
	assert(GameState.used_event_ids.has("chest_rusty"),
		"used_event_ids should contain 'chest_rusty'")
	assert(GameState.used_event_ids.has("wounded_traveler"),
		"used_event_ids should contain 'wounded_traveler'")
	_clean()
	print("  PASS test_used_event_ids_round_trip")

## A save written with no event ids loads back as an empty typed array (no crash)
func test_used_event_ids_default_empty_on_fresh_save() -> void:
	_clean()
	GameState.save()
	GameState.reset()
	GameState.load_save()
	assert(GameState.used_event_ids.is_empty(),
		"used_event_ids should be empty after loading a save with no events drawn")
	_clean()
	print("  PASS test_used_event_ids_default_empty_on_fresh_save")
