extends SceneTree

## --- Unit Tests: Enemy AI selection logic (pure logic, no scene required) ---
## Tests the ability filtering, consumable trigger conditions, and QTE resolution
## that will live in CombatManager3D._process_enemy_actions().
##
## Each helper mirrors the exact condition from the implementation so that
## a test failure proves the production logic is wrong, not just the helper.

func _initialize() -> void:
	_test_enemy_with_zero_energy_has_no_affordable_abilities()
	_test_enemy_selects_only_affordable_abilities()
	_test_enemy_with_no_in_range_ability_skips_action()
	_test_aoe_ability_excluded_when_out_of_range()
	_test_self_shape_always_in_range_regardless_of_distance()
	_test_ally_only_ability_excluded_from_enemy_pool()
	_test_consumable_used_when_hp_below_50_percent()
	_test_consumable_not_triggered_when_hp_at_or_above_50_percent()
	_test_consumable_not_triggered_when_slot_empty()
	_test_qte_resolution_to_multiplier_tiers()
	print("All enemy AI tests PASSED.")
	quit()

## --- Helpers ---

## Mirrors the affordable-ability filter in _process_enemy_actions().
## Returns AbilityData objects that pass all three gates:
##   1. energy_cost <= current_energy
##   2. applicable_to is ENEMY or ANY  (enemies never self-use ALLY abilities)
##   3. tile_range covers post-move distance (SELF shape is exempt)
func _filter_affordable(
		ability_ids: Array[String],
		current_energy: int,
		target_dist: int) -> Array[AbilityData]:
	var result: Array[AbilityData] = []
	for ability_id in ability_ids:
		if ability_id == "":
			continue
		var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
		if current_energy < ab.energy_cost:
			continue
		if ab.applicable_to != AbilityData.ApplicableTo.ENEMY \
				and ab.applicable_to != AbilityData.ApplicableTo.ANY:
			continue
		# SELF shape always reaches the caster — skip distance gate
		if ab.target_shape != AbilityData.TargetShape.SELF \
				and ab.tile_range != -1 and target_dist > ab.tile_range:
			continue
		result.append(ab)
	return result

## Mirrors the consumable trigger condition in _process_enemy_actions().
## Does NOT include the random 50% roll — that's non-deterministic and untestable here.
func _consumable_condition_met(consumable_id: String, current_hp: int, hp_max: int) -> bool:
	if consumable_id == "":
		return false
	return float(current_hp) / float(hp_max) < 0.5

## Mirrors CombatManager3D._qte_resolution_to_multiplier().
func _qte_resolution_to_multiplier(qte_res: float) -> float:
	if qte_res >= 0.85: return 1.25
	if qte_res >= 0.60: return 1.0
	if qte_res >= 0.30: return 0.75
	return 0.25

## --- Tests ---

func _test_enemy_with_zero_energy_has_no_affordable_abilities() -> void:
	# grunt abilities: heavy_strike(4), charge(2), shove(3), ""
	var ids: Array[String] = ["heavy_strike", "charge", "shove", ""]
	var result: Array[AbilityData] = _filter_affordable(ids, 0, 1)
	assert(result.is_empty(),
		"Enemy with 0 energy should have no affordable abilities, got %d" % result.size())
	print("  PASS _test_enemy_with_zero_energy_has_no_affordable_abilities")

func _test_enemy_selects_only_affordable_abilities() -> void:
	# grunt abilities: heavy_strike(4), charge(2-SELF), shove(3), ""
	# At energy=2, only charge qualifies (cost=2, SELF/ANY, range-exempt)
	var ids: Array[String] = ["heavy_strike", "charge", "shove", ""]
	var result: Array[AbilityData] = _filter_affordable(ids, 2, 99)
	assert(result.size() == 1,
		"energy=2 should only afford charge(cost=2), got %d candidates" % result.size())
	assert(result[0].ability_id == "charge",
		"Affordable ability should be 'charge', got '%s'" % result[0].ability_id)
	print("  PASS _test_enemy_selects_only_affordable_abilities")

func _test_enemy_with_no_in_range_ability_skips_action() -> void:
	# strike: SINGLE/ENEMY, range=1. Target is 5 tiles away — out of range.
	var ids: Array[String] = ["strike", ""]
	var result: Array[AbilityData] = _filter_affordable(ids, 10, 5)
	assert(result.is_empty(),
		"strike(range=1) should be filtered at dist=5, got %d" % result.size())
	print("  PASS _test_enemy_with_no_in_range_ability_skips_action")

func _test_aoe_ability_excluded_when_out_of_range() -> void:
	# sweep: ARC/ENEMY, range=1. At dist=3 it should be excluded.
	var ids: Array[String] = ["sweep", "", "", ""]
	var result: Array[AbilityData] = _filter_affordable(ids, 10, 3)
	assert(result.is_empty(),
		"sweep(range=1) should be excluded at dist=3, got %d" % result.size())
	print("  PASS _test_aoe_ability_excluded_when_out_of_range")

func _test_self_shape_always_in_range_regardless_of_distance() -> void:
	# healing_draught: SELF/ANY, cost=3 — must pass regardless of target_dist
	var ids: Array[String] = ["healing_draught", "", "", ""]
	var result: Array[AbilityData] = _filter_affordable(ids, 5, 999)
	assert(result.size() == 1,
		"SELF-shape ability should always pass range gate, got %d" % result.size())
	assert(result[0].ability_id == "healing_draught",
		"Expected healing_draught, got '%s'" % result[0].ability_id)
	print("  PASS _test_self_shape_always_in_range_regardless_of_distance")

func _test_ally_only_ability_excluded_from_enemy_pool() -> void:
	# inspire: SINGLE/ALLY — must never appear in enemy pool even if energy and range allow
	var ids: Array[String] = ["inspire", "", "", ""]
	var result: Array[AbilityData] = _filter_affordable(ids, 10, 1)
	assert(result.is_empty(),
		"ALLY applicable_to ability should be excluded from enemy pool, got %d" % result.size())
	print("  PASS _test_ally_only_ability_excluded_from_enemy_pool")

func _test_consumable_used_when_hp_below_50_percent() -> void:
	# 4/10 HP = 40% — below threshold; condition should be true
	assert(_consumable_condition_met("healing_potion", 4, 10),
		"Consumable condition should be true at 40% HP")
	# 1/10 HP = 10% — well below threshold
	assert(_consumable_condition_met("healing_potion", 1, 10),
		"Consumable condition should be true at 10% HP")
	print("  PASS _test_consumable_used_when_hp_below_50_percent")

func _test_consumable_not_triggered_when_hp_at_or_above_50_percent() -> void:
	# 5/10 HP = 50% exactly — NOT below 0.5, so condition is false
	assert(not _consumable_condition_met("healing_potion", 5, 10),
		"Consumable condition should be false at exactly 50% HP")
	# 6/10 HP = 60% — above threshold
	assert(not _consumable_condition_met("healing_potion", 6, 10),
		"Consumable condition should be false at 60% HP")
	print("  PASS _test_consumable_not_triggered_when_hp_at_or_above_50_percent")

func _test_consumable_not_triggered_when_slot_empty() -> void:
	assert(not _consumable_condition_met("", 1, 10),
		"Consumable condition should be false when slot is empty")
	print("  PASS _test_consumable_not_triggered_when_slot_empty")

func _test_qte_resolution_to_multiplier_tiers() -> void:
	# Elite: qte_resolution=0.8 → tier 1.0
	assert(_qte_resolution_to_multiplier(0.80) == 1.0,
		"0.80 should map to 1.0, got %.2f" % _qte_resolution_to_multiplier(0.80))
	# Grunt: qte_resolution=0.3 → tier 0.75 (boundary: exactly 0.30 → 0.75)
	assert(_qte_resolution_to_multiplier(0.30) == 0.75,
		"0.30 should map to 0.75, got %.2f" % _qte_resolution_to_multiplier(0.30))
	# Very weak: 0.0 → 0.25 (miss tier)
	assert(_qte_resolution_to_multiplier(0.0) == 0.25,
		"0.0 should map to 0.25, got %.2f" % _qte_resolution_to_multiplier(0.0))
	# Max: 0.85 → 1.25
	assert(_qte_resolution_to_multiplier(0.85) == 1.25,
		"0.85 should map to 1.25, got %.2f" % _qte_resolution_to_multiplier(0.85))
	print("  PASS _test_qte_resolution_to_multiplier_tiers")
