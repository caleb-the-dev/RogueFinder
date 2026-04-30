extends Node

## --- Unit Tests: PricingFormula ---
## Tests: determinism, seed variation, bounds per rarity, ordering, stub item fallback, floor.

func _ready() -> void:
	print("=== test_pricing.gd ===")
	test_determinism_same_seed()
	test_different_seeds_vary()
	test_bounds_common()
	test_bounds_rare()
	test_bounds_epic()
	test_bounds_legendary()
	test_rarity_ordering()
	test_stub_item_defaults_to_common()
	test_minimum_floor()
	print("=== All pricing tests passed ===")

## Same seeded RNG + same item must yield identical prices across two calls.
func test_determinism_same_seed() -> void:
	var rng := RandomNumberGenerator.new()
	var item := { "rarity": EquipmentData.Rarity.RARE }
	rng.seed = 42
	var first: int  = PricingFormula.price_for(item, rng)
	rng.seed = 42
	var second: int = PricingFormula.price_for(item, rng)
	assert(first == second,
		"same seed must produce same price; got %d then %d" % [first, second])

## At least one pair across 10 different seeds must differ (smoke test for non-constant output).
func test_different_seeds_vary() -> void:
	var rng := RandomNumberGenerator.new()
	var item := { "rarity": EquipmentData.Rarity.EPIC }
	var seen: Dictionary = {}
	for i in range(10):
		rng.seed = i
		seen[PricingFormula.price_for(item, rng)] = true
	assert(seen.size() > 1,
		"10 different seeds should produce at least 2 distinct prices, got %d" % seen.size())

## COMMON (base 10) must land in [round(10*0.9), round(10*1.1)] = [9, 11].
func test_bounds_common() -> void:
	var rng := RandomNumberGenerator.new()
	var item := { "rarity": EquipmentData.Rarity.COMMON }
	for i in range(20):
		rng.seed = i
		var p: int = PricingFormula.price_for(item, rng)
		assert(p >= 9 and p <= 11,
			"COMMON price out of [9,11]: got %d (seed %d)" % [p, i])

## RARE (base 40) must land in [36, 44].
func test_bounds_rare() -> void:
	var rng := RandomNumberGenerator.new()
	var item := { "rarity": EquipmentData.Rarity.RARE }
	for i in range(20):
		rng.seed = i
		var p: int = PricingFormula.price_for(item, rng)
		assert(p >= 36 and p <= 44,
			"RARE price out of [36,44]: got %d (seed %d)" % [p, i])

## EPIC (base 120) must land in [108, 132].
func test_bounds_epic() -> void:
	var rng := RandomNumberGenerator.new()
	var item := { "rarity": EquipmentData.Rarity.EPIC }
	for i in range(20):
		rng.seed = i
		var p: int = PricingFormula.price_for(item, rng)
		assert(p >= 108 and p <= 132,
			"EPIC price out of [108,132]: got %d (seed %d)" % [p, i])

## LEGENDARY (base 400) must land in [360, 440].
func test_bounds_legendary() -> void:
	var rng := RandomNumberGenerator.new()
	var item := { "rarity": EquipmentData.Rarity.LEGENDARY }
	for i in range(20):
		rng.seed = i
		var p: int = PricingFormula.price_for(item, rng)
		assert(p >= 360 and p <= 440,
			"LEGENDARY price out of [360,440]: got %d (seed %d)" % [p, i])

## Median (central) price: LEGENDARY base > EPIC base > RARE base > COMMON base.
## Using seed(42) so all multipliers are identical — base order must hold.
func test_rarity_ordering() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var common: int    = PricingFormula.price_for({"rarity": EquipmentData.Rarity.COMMON},    rng)
	rng.seed = 42
	var rare: int      = PricingFormula.price_for({"rarity": EquipmentData.Rarity.RARE},      rng)
	rng.seed = 42
	var epic: int      = PricingFormula.price_for({"rarity": EquipmentData.Rarity.EPIC},      rng)
	rng.seed = 42
	var legendary: int = PricingFormula.price_for({"rarity": EquipmentData.Rarity.LEGENDARY}, rng)
	assert(legendary > epic,   "LEGENDARY (%d) must exceed EPIC (%d)"   % [legendary, epic])
	assert(epic      > rare,   "EPIC (%d) must exceed RARE (%d)"         % [epic,      rare])
	assert(rare      > common, "RARE (%d) must exceed COMMON (%d)"       % [rare,      common])

## A dict with no "rarity" key falls back to COMMON pricing.
func test_stub_item_defaults_to_common() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var price_stub: int   = PricingFormula.price_for({}, rng)
	rng.seed = 7
	var price_common: int = PricingFormula.price_for({"rarity": EquipmentData.Rarity.COMMON}, rng)
	assert(price_stub == price_common,
		"stub item (no rarity) must price same as COMMON; got %d vs %d" % [price_stub, price_common])

## Result must always be at least 1 even for COMMON items (floor guard).
func test_minimum_floor() -> void:
	var rng := RandomNumberGenerator.new()
	for i in range(50):
		rng.seed = i
		var p: int = PricingFormula.price_for({"rarity": EquipmentData.Rarity.COMMON}, rng)
		assert(p >= 1, "price must be >= 1 for all seeds; got %d (seed %d)" % [p, i])
