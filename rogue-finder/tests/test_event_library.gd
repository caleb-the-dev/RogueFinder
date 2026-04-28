extends Node

## --- Unit Tests: EventLibrary ---
## Run via Project > Run This Scene (F6).
## No scene nodes, timers, or signals required.

func _ready() -> void:
	print("=== test_event_library.gd ===")
	test_load_succeeds()
	test_event_count()
	test_get_known_event()
	test_get_unknown_id_is_stub_not_null()
	test_choices_joined_and_sorted()
	test_choice_conditions_parsed()
	test_choice_effects_json_parsed()
	test_noop_choice_empty_effects()
	test_ring_filter_outer()
	test_ring_filter_middle()
	test_ring_filter_inner()
	test_reload_repopulates()
	print("=== All EventLibrary tests passed ===")

func test_load_succeeds() -> void:
	EventLibrary.reload()
	assert(EventLibrary.all_events().size() > 0, "EventLibrary should load at least one event")
	print("  PASS test_load_succeeds")

func test_event_count() -> void:
	assert(EventLibrary.all_events().size() == 17,
		"Expected 17 events, got %d" % EventLibrary.all_events().size())
	print("  PASS test_event_count")

func test_get_known_event() -> void:
	var ev: EventData = EventLibrary.get_event("chest_rusty")
	assert(ev != null,                      "get_event('chest_rusty') must not be null")
	assert(ev.id == "chest_rusty",          "id should be 'chest_rusty'")
	assert(ev.title == "Rusted Chest",      "title should be 'Rusted Chest'")
	assert(ev.body != "",                   "body must not be empty")
	assert(ev.ring_eligibility.size() > 0, "ring_eligibility must not be empty")
	print("  PASS test_get_known_event")

func test_get_unknown_id_is_stub_not_null() -> void:
	var ev: EventData = EventLibrary.get_event("not_a_real_event")
	assert(ev != null,             "get_event unknown id must never return null")
	assert(ev.title == "Unknown",  "stub title should be 'Unknown'")
	assert(ev.body  != "",         "stub body must not be empty")
	assert(ev.choices.size() == 0, "stub choices must be empty")
	print("  PASS test_get_unknown_id_is_stub_not_null")

func test_choices_joined_and_sorted() -> void:
	var chest: EventData = EventLibrary.get_event("chest_rusty")
	assert(chest.choices.size() == 2,
		"chest_rusty should have 2 choices, got %d" % chest.choices.size())
	assert(chest.choices[0].label == "Kick it open (STR 4)",
		"choice[0] label wrong: '%s'" % chest.choices[0].label)
	assert(chest.choices[1].label == "Leave it.",
		"choice[1] label wrong: '%s'" % chest.choices[1].label)
	var stall: EventData = EventLibrary.get_event("merchant_stall")
	assert(stall.choices.size() == 3,
		"merchant_stall should have 3 choices, got %d" % stall.choices.size())
	assert(stall.choices[0].label == "Browse the goods.",
		"stall choice[0] label wrong: '%s'" % stall.choices[0].label)
	assert(stall.choices[2].label == "Move on.",
		"stall choice[2] label wrong: '%s'" % stall.choices[2].label)
	print("  PASS test_choices_joined_and_sorted")

func test_choice_conditions_parsed() -> void:
	var chest: EventData = EventLibrary.get_event("chest_rusty")
	var gated: EventChoiceData = chest.choices[0]
	assert(gated.conditions.size() == 1,
		"gated choice should have 1 condition, got %d" % gated.conditions.size())
	assert(gated.conditions[0] == "stat_ge:STR:4",
		"condition string wrong: '%s'" % gated.conditions[0])
	var free: EventChoiceData = chest.choices[1]
	assert(free.conditions.size() == 0,
		"no-condition choice should have 0 conditions, got %d" % free.conditions.size())
	print("  PASS test_choice_conditions_parsed")

func test_choice_effects_json_parsed() -> void:
	var chest: EventData = EventLibrary.get_event("chest_rusty")
	var gated: EventChoiceData = chest.choices[0]
	assert(gated.effects.size() == 1,
		"gated choice should have 1 effect, got %d" % gated.effects.size())
	assert(gated.effects[0].has("type"),
		"effect dict should have 'type' key")
	assert(gated.effects[0]["type"] == "item_gain",
		"effect type should be 'item_gain', got '%s'" % gated.effects[0]["type"])
	assert(gated.effects[0].has("item_id"),
		"item_gain effect should have 'item_id' key")
	var traveler: EventData = EventLibrary.get_event("wounded_traveler")
	var heal_choice: EventChoiceData = traveler.choices[0]
	assert(heal_choice.effects[0]["target"] == "player_pick",
		"heal effect target should be 'player_pick'")
	print("  PASS test_choice_effects_json_parsed")

func test_noop_choice_empty_effects() -> void:
	var chest: EventData = EventLibrary.get_event("chest_rusty")
	var noop: EventChoiceData = chest.choices[1]
	assert(noop.effects.size() == 0,
		"no-op choice should have 0 effects, got %d" % noop.effects.size())
	assert(noop.result_text != "", "no-op choice result_text must not be empty")
	print("  PASS test_noop_choice_empty_effects")

func test_ring_filter_outer() -> void:
	var outer_events: Array[EventData] = EventLibrary.all_events_for_ring("outer")
	assert(outer_events.size() == 10,
		"outer ring should have 10 events, got %d" % outer_events.size())
	print("  PASS test_ring_filter_outer")

func test_ring_filter_middle() -> void:
	var middle_events: Array[EventData] = EventLibrary.all_events_for_ring("middle")
	assert(middle_events.size() == 10,
		"middle ring should have 10 events, got %d" % middle_events.size())
	print("  PASS test_ring_filter_middle")

func test_ring_filter_inner() -> void:
	var inner_events: Array[EventData] = EventLibrary.all_events_for_ring("inner")
	assert(inner_events.size() == 5,
		"inner ring should have 5 events, got %d" % inner_events.size())
	assert(inner_events[0].id == "wounded_traveler",
		"first inner ring event should be 'wounded_traveler', got '%s'" % inner_events[0].id)
	print("  PASS test_ring_filter_inner")

func test_reload_repopulates() -> void:
	EventLibrary.reload()
	assert(EventLibrary.all_events().size() == 17,
		"reload() should restore 17 events, got %d" % EventLibrary.all_events().size())
	var chest: EventData = EventLibrary.get_event("chest_rusty")
	assert(chest.choices.size() == 2,
		"reload() should re-attach choices (expected 2, got %d)" % chest.choices.size())
	print("  PASS test_reload_repopulates")
