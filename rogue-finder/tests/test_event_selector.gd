extends Node

## --- Unit Tests: EventSelector ---
## Run via the headless .tscn runner.
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_event_selector.gd ===")
	test_returns_valid_event_for_outer()
	test_appends_to_used_event_ids()
	test_exhaustion_fallback_still_returns_valid_event()
	test_unknown_ring_returns_stub_not_null()
	test_reset_clears_used_event_ids()
	print("=== All EventSelector tests passed ===")

func _clean() -> void:
	GameState.used_event_ids.clear()
	EventLibrary.reload()

## pick_for_node("outer") returns non-null EventData whose ring_eligibility includes "outer"
func test_returns_valid_event_for_outer() -> void:
	_clean()
	var ev: EventData = EventSelector.pick_for_node("outer")
	assert(ev != null, "pick_for_node must never return null")
	assert(ev.id != "", "returned EventData must have a non-empty id")
	assert(ev.ring_eligibility.has("outer"),
		"returned event should be eligible for 'outer', got eligibility: %s" % str(ev.ring_eligibility))
	print("  PASS test_returns_valid_event_for_outer")

## Calling pick_for_node appends the chosen id to GameState.used_event_ids
func test_appends_to_used_event_ids() -> void:
	_clean()
	assert(GameState.used_event_ids.is_empty(), "used_event_ids should start empty")
	var ev: EventData = EventSelector.pick_for_node("outer")
	assert(GameState.used_event_ids.size() == 1,
		"used_event_ids should have 1 entry after one pick, got %d" % GameState.used_event_ids.size())
	assert(GameState.used_event_ids.has(ev.id),
		"used_event_ids should contain the picked event id '%s'" % ev.id)
	print("  PASS test_appends_to_used_event_ids")

## After all outer events are marked used, pick_for_node("outer") still returns a valid event
func test_exhaustion_fallback_still_returns_valid_event() -> void:
	_clean()
	# Mark every outer-eligible event as seen
	var all_outer: Array[EventData] = EventLibrary.all_events_for_ring("outer")
	for e in all_outer:
		GameState.used_event_ids.append(e.id)
	# All exhausted — fallback must still return something valid
	var ev: EventData = EventSelector.pick_for_node("outer")
	assert(ev != null, "exhaustion fallback must not return null")
	assert(ev.id != "", "exhaustion fallback must return an event with a non-empty id")
	assert(ev.ring_eligibility.has("outer"),
		"fallback event must still be eligible for 'outer'")
	print("  PASS test_exhaustion_fallback_still_returns_valid_event")

## pick_for_node with a ring that has no events returns the stub (not null, no crash)
func test_unknown_ring_returns_stub_not_null() -> void:
	_clean()
	var ev: EventData = EventSelector.pick_for_node("no_such_ring")
	assert(ev != null, "pick_for_node on unknown ring must not return null")
	assert(ev.title == "Unknown",
		"unknown ring should return stub with title 'Unknown', got '%s'" % ev.title)
	print("  PASS test_unknown_ring_returns_stub_not_null")

## GameState.reset() clears used_event_ids
func test_reset_clears_used_event_ids() -> void:
	_clean()
	GameState.used_event_ids.append("chest_rusty")
	GameState.used_event_ids.append("wounded_traveler")
	assert(GameState.used_event_ids.size() == 2, "should have 2 entries before reset")
	GameState.reset()
	assert(GameState.used_event_ids.is_empty(),
		"used_event_ids must be empty after reset(), got %d entries" % GameState.used_event_ids.size())
	print("  PASS test_reset_clears_used_event_ids")
