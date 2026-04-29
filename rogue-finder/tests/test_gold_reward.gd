extends Node

## --- Unit Tests: Gold Reward ---
## Tests: bounds, ring/threat monotonicity, determinism, and ring fallback.

func _ready() -> void:
	print("=== test_gold_reward.gd ===")
	test_positive_bounds()
	test_sane_upper_bound()
	test_ring_monotonicity()
	test_threat_monotonicity()
	test_determinism_single_seed()
	test_determinism_consecutive_sequence()
	test_ring_fallback()
	print("=== All gold reward tests passed ===")

## Returns > 0 at a typical mid-game input.
func test_positive_bounds() -> void:
	seed(1)
	var g: int = RewardGenerator.gold_drop("outer", 10, 5)
	assert(g > 0, "gold_drop must return a positive int, got %d" % g)

## Stays below a generous ceiling even at max inputs.
func test_sane_upper_bound() -> void:
	seed(1)
	var g: int = RewardGenerator.gold_drop("outer", 100, 20)
	assert(g < 300, "gold_drop exceeded sanity ceiling of 300, got %d" % g)

## outer > middle > inner at identical threat and level.
## Using the same seed before each call ensures the ±10% jitter is identical,
## so RING_BASE difference is the only variable.
func test_ring_monotonicity() -> void:
	seed(42)
	var outer: int = RewardGenerator.gold_drop("outer", 50, 5)
	seed(42)
	var middle: int = RewardGenerator.gold_drop("middle", 50, 5)
	seed(42)
	var inner: int = RewardGenerator.gold_drop("inner", 50, 5)
	assert(outer > middle, "outer (%d) must exceed middle (%d)" % [outer, middle])
	assert(middle > inner, "middle (%d) must exceed inner (%d)" % [middle, inner])

## Higher threat yields more gold when ring and level are fixed (same multiplier via same seed).
func test_threat_monotonicity() -> void:
	seed(99)
	var low: int  = RewardGenerator.gold_drop("middle", 0, 5)
	seed(99)
	var high: int = RewardGenerator.gold_drop("middle", 100, 5)
	assert(high > low, "threat=100 (%d) must exceed threat=0 (%d)" % [high, low])

## Re-seeding with the same value must produce the same single result.
func test_determinism_single_seed() -> void:
	seed(12345)
	var first: int  = RewardGenerator.gold_drop("outer", 50, 10)
	seed(12345)
	var second: int = RewardGenerator.gold_drop("outer", 50, 10)
	assert(first == second,
		"same seed must produce same gold; got %d then %d" % [first, second])

## Same seed produces the same consecutive sequence of two calls.
func test_determinism_consecutive_sequence() -> void:
	seed(555)
	var a1: int = RewardGenerator.gold_drop("outer",  30, 4)
	var a2: int = RewardGenerator.gold_drop("inner",  60, 8)
	seed(555)
	var b1: int = RewardGenerator.gold_drop("outer",  30, 4)
	var b2: int = RewardGenerator.gold_drop("inner",  60, 8)
	assert(a1 == b1 and a2 == b2,
		"consecutive call sequence must be reproducible from same seed (%d,%d vs %d,%d)" \
		% [a1, a2, b1, b2])

## Unknown ring strings fall back to inner-ring base, not zero or error.
func test_ring_fallback() -> void:
	seed(1)
	var g: int = RewardGenerator.gold_drop("badurga", 20, 3)
	seed(1)
	var inner: int = RewardGenerator.gold_drop("inner", 20, 3)
	assert(g == inner, "unknown ring must fall back to inner (%d vs %d)" % [g, inner])
