extends Node

## --- Unit Tests: EventManager ---
## Headless tests — call static methods directly. No scene instantiation required.

func _ready() -> void:
	print("=== test_event_manager.gd ===")

	# Condition evaluator
	test_stat_ge_passes_when_member_qualifies()
	test_stat_ge_fails_when_no_member_qualifies()
	test_kindred_passes_and_fails()
	test_class_passes_and_fails()
	test_feat_passes_when_present_fails_when_absent()
	test_item_passes_when_in_inventory_fails_when_absent()
	test_empty_conditions_always_enabled()
	test_unknown_condition_form_fails_open()

	# Effect dispatch
	test_harm_reduces_hp_clamped_to_zero()
	test_heal_restores_hp_clamped_to_max()
	test_threat_delta_adjusts_and_clamps()
	test_feat_grant_appends_and_no_duplicate()
	test_item_gain_adds_to_inventory()
	test_item_remove_removes_from_inventory()

	# Persistence
	test_feats_survive_save_load_round_trip()
	test_old_save_without_feats_loads_as_empty_array()

	# Target resolution
	test_pc_target_returns_party_zero()
	test_random_ally_no_alive_allies_degrades_to_pc()
	test_player_pick_returns_pc_no_crash()

	print("=== All EventManager tests passed ===")

## --- Helpers ---

func _make_member(strength: int = 2, kindred: String = "Human",
		unit_class: String = "Fighter", background: String = "Soldier") -> CombatantData:
	var m := CombatantData.new()
	m.character_name = "Test"
	m.strength   = strength
	m.dexterity  = 2
	m.cognition  = 2
	m.willpower  = 2
	m.vitality   = 3
	m.kindred    = kindred
	m.unit_class = unit_class
	m.background = background
	m.current_hp = m.hp_max
	m.is_dead    = false
	return m

func _party(members: Array) -> Array[CombatantData]:
	var p: Array[CombatantData] = []
	for m in members:
		p.append(m)
	return p

## --- Condition Evaluator ---

func test_stat_ge_passes_when_member_qualifies() -> void:
	var party := _party([_make_member(4)])
	assert(EventManager.evaluate_condition("stat_ge:STR:4", party),
		"stat_ge:STR:4 should pass when member has STR 4")
	assert(EventManager.evaluate_condition("stat_ge:STR:3", party),
		"stat_ge:STR:3 should pass when member has STR 4 (>= 3)")
	print("  PASS test_stat_ge_passes_when_member_qualifies")

func test_stat_ge_fails_when_no_member_qualifies() -> void:
	var party := _party([_make_member(2)])
	assert(not EventManager.evaluate_condition("stat_ge:STR:4", party),
		"stat_ge:STR:4 should fail when member only has STR 2")
	print("  PASS test_stat_ge_fails_when_no_member_qualifies")

func test_kindred_passes_and_fails() -> void:
	var party := _party([_make_member(2, "Dwarf")])
	assert(EventManager.evaluate_condition("kindred:Dwarf", party),
		"kindred:Dwarf should pass for a Dwarf member")
	assert(not EventManager.evaluate_condition("kindred:Human", party),
		"kindred:Human should fail when party has no Human")
	print("  PASS test_kindred_passes_and_fails")

func test_class_passes_and_fails() -> void:
	var party := _party([_make_member(2, "Human", "Rogue")])
	assert(EventManager.evaluate_condition("class:Rogue", party),
		"class:Rogue should pass when a member is Rogue")
	assert(not EventManager.evaluate_condition("class:Wizard", party),
		"class:Wizard should fail when no Wizard in party")
	print("  PASS test_class_passes_and_fails")

func test_feat_passes_when_present_fails_when_absent() -> void:
	var member := _make_member()
	member.feats = ["adaptive"]
	var party_with := _party([member])
	assert(EventManager.evaluate_condition("feat:adaptive", party_with),
		"feat:adaptive should pass when member has the feat")

	var party_without := _party([_make_member()])
	assert(not EventManager.evaluate_condition("feat:adaptive", party_without),
		"feat:adaptive should fail when no member has the feat")
	print("  PASS test_feat_passes_when_present_fails_when_absent")

func test_item_passes_when_in_inventory_fails_when_absent() -> void:
	GameState.inventory.clear()
	assert(not EventManager.evaluate_condition("item:short_sword", GameState.party),
		"item:short_sword should fail with empty inventory")
	GameState.inventory.append({"id": "short_sword", "name": "Short Sword",
		"description": "A blade.", "item_type": "equipment"})
	assert(EventManager.evaluate_condition("item:short_sword", GameState.party),
		"item:short_sword should pass when item is in inventory")
	GameState.inventory.clear()
	print("  PASS test_item_passes_when_in_inventory_fails_when_absent")

func test_empty_conditions_always_enabled() -> void:
	var empty_conditions: Array[String] = []
	var enabled := true
	for cond in empty_conditions:
		if not EventManager.evaluate_condition(cond, _party([_make_member()])):
			enabled = false
			break
	assert(enabled, "Empty conditions array must always leave choice enabled")
	print("  PASS test_empty_conditions_always_enabled")

func test_unknown_condition_form_fails_open() -> void:
	var party := _party([_make_member()])
	# Unknown forms must return true (fail open) — no crash, no silent gate
	var result := EventManager.evaluate_condition("unknown_form:foo", party)
	assert(result, "Unknown condition form must fail open (return true)")
	print("  PASS test_unknown_condition_form_fails_open")

## --- Effect Dispatch ---

func test_harm_reduces_hp_clamped_to_zero() -> void:
	var member := _make_member()
	member.current_hp = 10
	var party := _party([member])
	EventManager.dispatch_effect({"type": "harm", "target": "PC", "value": 4}, party)
	assert(member.current_hp == 6, "harm should reduce HP by 4, got %d" % member.current_hp)
	EventManager.dispatch_effect({"type": "harm", "target": "PC", "value": 99}, party)
	assert(member.current_hp == 0, "harm should clamp HP to 0, got %d" % member.current_hp)
	print("  PASS test_harm_reduces_hp_clamped_to_zero")

func test_heal_restores_hp_clamped_to_max() -> void:
	var member := _make_member()
	member.current_hp = 5
	var party := _party([member])
	EventManager.dispatch_effect({"type": "heal", "target": "PC", "value": 3}, party)
	assert(member.current_hp == 8, "heal should restore 3 HP, got %d" % member.current_hp)
	EventManager.dispatch_effect({"type": "heal", "target": "PC", "value": 999}, party)
	assert(member.current_hp == member.hp_max,
		"heal should clamp HP to hp_max (%d), got %d" % [member.hp_max, member.current_hp])
	print("  PASS test_heal_restores_hp_clamped_to_max")

func test_threat_delta_adjusts_and_clamps() -> void:
	GameState.threat_level = 0.5
	var party: Array[CombatantData] = []
	EventManager.dispatch_effect({"type": "threat_delta", "value": 10}, party)
	assert(absf(GameState.threat_level - 0.6) < 0.001,
		"threat_delta +10 should set level to 0.6, got %.3f" % GameState.threat_level)
	EventManager.dispatch_effect({"type": "threat_delta", "value": 9999}, party)
	assert(GameState.threat_level == 1.0,
		"threat_delta should clamp to 1.0, got %.3f" % GameState.threat_level)
	GameState.threat_level = 0.05
	EventManager.dispatch_effect({"type": "threat_delta", "value": -99}, party)
	assert(GameState.threat_level == 0.0,
		"negative threat_delta should clamp to 0.0, got %.3f" % GameState.threat_level)
	GameState.threat_level = 0.0
	print("  PASS test_threat_delta_adjusts_and_clamps")

func test_feat_grant_appends_and_no_duplicate() -> void:
	var member := _make_member()
	member.feats = []
	var party := _party([member])
	EventManager.dispatch_effect({"type": "feat_grant", "target": "PC", "feat_id": "adaptive"}, party)
	assert(member.feats.size() == 1 and member.feats.has("adaptive"),
		"feat_grant should append 'adaptive' to feats")
	# Second grant must not duplicate
	EventManager.dispatch_effect({"type": "feat_grant", "target": "PC", "feat_id": "adaptive"}, party)
	assert(member.feats.size() == 1,
		"feat_grant should not duplicate — expected 1 feat, got %d" % member.feats.size())
	print("  PASS test_feat_grant_appends_and_no_duplicate")

func test_item_gain_adds_to_inventory() -> void:
	GameState.inventory.clear()
	var party: Array[CombatantData] = []
	# short_sword exists in equipment.csv
	EventManager.dispatch_effect({"type": "item_gain", "item_id": "short_sword"}, party)
	assert(GameState.inventory.size() == 1,
		"item_gain should add short_sword to inventory, got size %d" % GameState.inventory.size())
	assert(GameState.inventory[0].get("id", "") == "short_sword",
		"inventory entry should have id 'short_sword'")
	assert(GameState.inventory[0].get("item_type", "") == "equipment",
		"short_sword should be item_type 'equipment'")
	GameState.inventory.clear()
	print("  PASS test_item_gain_adds_to_inventory")

func test_item_remove_removes_from_inventory() -> void:
	GameState.inventory.clear()
	GameState.inventory.append({"id": "short_sword", "name": "Short Sword",
		"description": "A blade.", "item_type": "equipment"})
	assert(GameState.inventory.size() == 1, "setup: inventory should have 1 item")
	var party: Array[CombatantData] = []
	EventManager.dispatch_effect({"type": "item_remove", "item_id": "short_sword"}, party)
	assert(GameState.inventory.is_empty(),
		"item_remove should remove short_sword from inventory")
	print("  PASS test_item_remove_removes_from_inventory")

## --- Persistence ---

func test_feats_survive_save_load_round_trip() -> void:
	# Save a party member with feats, reset, reload, verify feats survive
	var member := _make_member()
	member.feats = ["adaptive", "stubborn"]
	GameState.party = [member]
	GameState.map_seed = 1
	GameState.save()
	GameState.reset()
	assert(GameState.party.is_empty(), "party should be empty after reset")
	var loaded := GameState.load_save()
	assert(loaded, "load_save should return true")
	assert(GameState.party.size() == 1, "party should have 1 member after load")
	var loaded_member := GameState.party[0]
	assert(loaded_member.feats.has("adaptive"),
		"'adaptive' feat should survive round-trip save/load")
	assert(loaded_member.feats.has("stubborn"),
		"'stubborn' feat should survive round-trip save/load")
	assert(loaded_member.feats.size() == 2,
		"feats array should have exactly 2 entries after load, got %d" % loaded_member.feats.size())
	GameState.reset()
	print("  PASS test_feats_survive_save_load_round_trip")

func test_old_save_without_feats_loads_as_empty_array() -> void:
	# Write a save file that has no "feats" key in the party member dict
	var data := {
		"player_node_id": "badurga",
		"visited_nodes": ["badurga"],
		"map_seed": 1,
		"node_types": {},
		"cleared_nodes": [],
		"threat_level": 0.0,
		"used_event_ids": [],
		"party": [{
			"archetype_id": "generic",
			"character_name": "OldUnit",
			"is_player_unit": false,
			"unit_class": "",
			"kindred": "Human",
			"kindred_feat_id": "",
			"background": "",
			"strength": 2, "dexterity": 2, "cognition": 2,
			"willpower": 2, "vitality": 2,
			"armor_defense": 5, "qte_resolution": 0.3,
			"abilities": [], "ability_pool": [],
			# No "feats" key intentionally — simulating old save
			"current_hp": 10, "current_energy": 5, "is_dead": false,
			"consumable": "", "weapon_id": "", "armor_id": "", "accessory_id": ""
		}],
		"inventory": []
	}
	var file := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file = null
	var loaded := GameState.load_save()
	assert(loaded, "load_save should succeed on old save format")
	assert(GameState.party.size() == 1, "party should have 1 member")
	assert(GameState.party[0].feats.is_empty(),
		"feats should default to empty array on old saves without feats key")
	GameState.reset()
	print("  PASS test_old_save_without_feats_loads_as_empty_array")

## --- Target Resolution ---

func test_pc_target_returns_party_zero() -> void:
	var pc := _make_member()
	var ally := _make_member()
	var party := _party([pc, ally])
	var result := EventManager.resolve_target("PC", party)
	assert(result == pc, "PC target should return party[0]")
	print("  PASS test_pc_target_returns_party_zero")

func test_random_ally_no_alive_allies_degrades_to_pc() -> void:
	var pc := _make_member()
	var ally := _make_member()
	ally.is_dead = true
	var party := _party([pc, ally])
	var result := EventManager.resolve_target("random_ally", party)
	assert(result == pc,
		"random_ally with no alive allies should degrade to PC")
	print("  PASS test_random_ally_no_alive_allies_degrades_to_pc")

func test_player_pick_returns_pc_no_crash() -> void:
	var pc := _make_member()
	var party := _party([pc])
	var result := EventManager.resolve_target("player_pick", party)
	assert(result == pc, "player_pick should return PC (party[0]) with no crash")
	print("  PASS test_player_pick_returns_pc_no_crash")
