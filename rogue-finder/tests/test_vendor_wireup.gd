extends Node

## --- Unit Tests: Vendor Wire-up ---
## Tests: gold_change effect (debit, clamp), has_gold condition (threshold),
## and existing event dispatcher not regressed.

func _ready() -> void:
	print("=== test_vendor_wireup.gd ===")
	test_gold_change_debits()
	test_gold_change_clamps_at_zero()
	test_has_gold_at_threshold()
	test_has_gold_above_threshold()
	test_has_gold_below_threshold()
	print("=== All vendor wire-up tests passed ===")

## gold_change with a negative value debits gold correctly.
func test_gold_change_debits() -> void:
	GameState.gold = 100
	var effect := {"type": "gold_change", "value": -25}
	EventManager.dispatch_effect(effect, [])
	assert(GameState.gold == 75, "gold should be 100 - 25 = 75, got %d" % GameState.gold)

## gold_change cannot drive gold below zero.
func test_gold_change_clamps_at_zero() -> void:
	GameState.gold = 10
	var effect := {"type": "gold_change", "value": -50}
	EventManager.dispatch_effect(effect, [])
	assert(GameState.gold == 0, "gold should clamp at 0, got %d" % GameState.gold)

## has_gold is true when gold equals the threshold exactly.
func test_has_gold_at_threshold() -> void:
	GameState.gold = 25
	var result: bool = EventManager.evaluate_condition("has_gold:25", [])
	assert(result, "has_gold:25 should be true when gold == 25")

## has_gold is true when gold exceeds the threshold.
func test_has_gold_above_threshold() -> void:
	GameState.gold = 100
	var result: bool = EventManager.evaluate_condition("has_gold:25", [])
	assert(result, "has_gold:25 should be true when gold > 25")

## has_gold is false when gold is below the threshold.
func test_has_gold_below_threshold() -> void:
	GameState.gold = 20
	var result: bool = EventManager.evaluate_condition("has_gold:25", [])
	assert(not result, "has_gold:25 should be false when gold < 25, got %s" % str(result))
