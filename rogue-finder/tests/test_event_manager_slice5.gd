extends Node

## --- Unit Tests: EventManager Slice 5 ---
## Tests for player_pick forced_target substitution and inventory seen flag.
## All headless — no scene instantiation required.

func _ready() -> void:
	print("=== test_event_manager_slice5.gd ===")

	# player_pick substitution via forced_target
	test_forced_target_applies_heal_to_picked_member()
	test_forced_target_null_degrades_player_pick_to_pc()
	test_forced_target_ignored_for_non_player_pick_effects()
	test_no_picker_needed_for_effects_without_player_pick()

	# Inventory seen flag
	test_add_to_inventory_sets_seen_false()
	test_old_item_without_seen_key_reads_as_true()
	test_seen_flag_can_be_set_true_on_dict()

	print("=== All EventManager Slice 5 tests passed ===")

## --- Helpers ---

func _make_member(name: String = "Test", hp: int = 10) -> CombatantData:
	var m := CombatantData.new()
	m.character_name = name
	m.strength   = 2
	m.dexterity  = 2
	m.cognition  = 2
	m.willpower  = 2
	m.vitality   = 3
	m.current_hp = hp
	m.is_dead    = false
	return m

func _party(members: Array) -> Array[CombatantData]:
	var p: Array[CombatantData] = []
	for m in members:
		p.append(m)
	return p

## --- player_pick Substitution ---

func test_forced_target_applies_heal_to_picked_member() -> void:
	var pc   := _make_member("PC", 5)
	var ally := _make_member("Ally", 4)
	var party := _party([pc, ally])

	EventManager.dispatch_effect(
		{"type": "heal", "target": "player_pick", "value": 6},
		party, ally)

	assert(ally.current_hp == mini(ally.hp_max, 10),
		"forced_target ally should receive the heal, got %d" % ally.current_hp)
	assert(pc.current_hp == 5,
		"PC should be untouched when forced_target is ally, got %d" % pc.current_hp)
	print("  PASS test_forced_target_applies_heal_to_picked_member")

func test_forced_target_null_degrades_player_pick_to_pc() -> void:
	var pc   := _make_member("PC", 10)
	var ally := _make_member("Ally", 10)
	var party := _party([pc, ally])

	# forced_target = null → resolve_target("player_pick") → degrades to PC
	EventManager.dispatch_effect(
		{"type": "harm", "target": "player_pick", "value": 3},
		party, null)

	assert(pc.current_hp == 7,
		"null forced_target should degrade player_pick to PC, got %d" % pc.current_hp)
	assert(ally.current_hp == 10,
		"ally should be untouched when forced_target is null, got %d" % ally.current_hp)
	print("  PASS test_forced_target_null_degrades_player_pick_to_pc")

func test_forced_target_ignored_for_non_player_pick_effects() -> void:
	var pc   := _make_member("PC", 10)
	var ally := _make_member("Ally", 10)
	var party := _party([pc, ally])

	# Effect targets "PC" explicitly — forced_target (ally) should not override
	EventManager.dispatch_effect(
		{"type": "harm", "target": "PC", "value": 4},
		party, ally)

	assert(pc.current_hp == 6,
		"PC-targeted harm should hit PC even when forced_target is ally, got %d" % pc.current_hp)
	assert(ally.current_hp == 10,
		"ally should be untouched for PC-targeted effect, got %d" % ally.current_hp)
	print("  PASS test_forced_target_ignored_for_non_player_pick_effects")

func test_no_picker_needed_for_effects_without_player_pick() -> void:
	# Scan logic: effect list with no player_pick target → needs_pick = false
	var effects: Array[Dictionary] = [
		{"type": "harm",  "target": "PC",           "value": 2},
		{"type": "heal",  "target": "random_party",  "value": 1},
		{"type": "item_gain", "item_id": "short_sword"},
	]
	var needs_pick := false
	for effect in effects:
		if effect.get("target", "") == "player_pick":
			needs_pick = true
			break
	assert(not needs_pick,
		"effects list without player_pick should not require picker")
	print("  PASS test_no_picker_needed_for_effects_without_player_pick")

## --- Inventory Seen Flag ---

func test_add_to_inventory_sets_seen_false() -> void:
	GameState.inventory.clear()
	var item := {"id": "short_sword", "name": "Short Sword",
		"description": "A blade.", "item_type": "equipment"}
	GameState.add_to_inventory(item)
	assert(GameState.inventory.size() == 1, "inventory should have 1 item after add")
	assert(GameState.inventory[0].get("seen", true) == false,
		"add_to_inventory should set seen = false, got %s" % str(GameState.inventory[0].get("seen", "MISSING")))
	GameState.inventory.clear()
	print("  PASS test_add_to_inventory_sets_seen_false")

func test_old_item_without_seen_key_reads_as_true() -> void:
	# Old saves won't have the "seen" key — .get("seen", true) must return true (no spurious glow)
	var old_item := {"id": "rusted_dagger", "name": "Rusted Dagger",
		"description": "A old blade.", "item_type": "equipment"}
	assert(old_item.get("seen", true) == true,
		"missing seen key should read as true (already seen)")
	print("  PASS test_old_item_without_seen_key_reads_as_true")

func test_seen_flag_can_be_set_true_on_dict() -> void:
	# Simulates what the hover handler does: sets seen = true on the live dict
	GameState.inventory.clear()
	var item := {"id": "short_sword", "name": "Short Sword",
		"description": "A blade.", "item_type": "equipment"}
	GameState.add_to_inventory(item)
	assert(GameState.inventory[0].get("seen", true) == false, "should start unseen")

	# hover callback sets seen = true on the dict (shallow ref in inventory)
	GameState.inventory[0]["seen"] = true
	assert(GameState.inventory[0].get("seen", true) == true,
		"seen should be true after hover clears it")
	GameState.inventory.clear()
	print("  PASS test_seen_flag_can_be_set_true_on_dict")
