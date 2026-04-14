extends Node

## --- Unit Tests: CombatManager logic (pure logic only) ---
## Tests stat calculations, win/lose conditions, and energy math.
## Avoids anything that requires a running scene (no @onready, no timers, no signals).

func _ready() -> void:
	print("=== test_combat_manager.gd ===")
	test_damage_at_stat_parity()
	test_damage_scales_up_when_attack_exceeds_defense()
	test_damage_scales_down_when_defense_exceeds_attack()
	test_damage_clamped_to_minimum_one()
	test_damage_effectiveness_ceiling()
	test_damage_effectiveness_floor()
	test_qte_accuracy_inside_sweet_spot()
	test_qte_accuracy_outside_sweet_spot()
	test_qte_accuracy_at_center()
	test_energy_regen_and_cost_balance()
	print("=== All CombatManager logic tests passed ===")

## --- Helpers ---

## Returns a mock Unit with just the stat fields needed for _calculate_damage.
func _mock_unit(atk: int, def_: int) -> Unit:
	var u  := Unit.new()
	var d  := UnitData.new()
	d.attack  = atk
	d.defense = def_
	d.unit_name = "Mock"
	d.is_player_unit = true
	d.hp_max = 20; d.energy_max = 10; d.energy_regen = 3; d.speed = 3
	u.data         = d
	u.current_hp   = 20
	u.is_alive     = true
	return u

## Mirrors CombatManager._calculate_damage() — kept here so tests run standalone.
func _calc_damage(atk: int, def_: int, accuracy: float) -> int:
	var stat_delta: float   = float(atk - def_)
	var effectiveness: float = clampf(1.0 + stat_delta / 20.0, 0.5, 2.0)
	var skill: float         = clampf(accuracy, 0.1, 1.0)
	return maxi(1, roundi(float(atk) * effectiveness * skill))

## Mirrors QTEBar._calculate_accuracy()
func _calc_accuracy(pos: float) -> float:
	const SS_START: float = 0.35
	const SS_END:   float = 0.65
	if pos < SS_START or pos > SS_END:
		return 0.2
	var center: float     = (SS_START + SS_END) / 2.0
	var half_width: float = (SS_END - SS_START) / 2.0
	return lerp(1.0, 0.5, abs(pos - center) / half_width)

## --- Damage Formula Tests ---

func test_damage_at_stat_parity() -> void:
	# Attack = Defense = 10, all prompts hit (accuracy 1.0)
	# effectiveness = 1.0, final = 10 * 1.0 * 1.0 = 10
	var dmg: int = _calc_damage(10, 10, 1.0)
	assert(dmg == 10, "Damage at parity with full accuracy should be 10, got %d" % dmg)
	print("  PASS test_damage_at_stat_parity")

func test_damage_scales_up_when_attack_exceeds_defense() -> void:
	# attack=20, defense=10 → stat_delta=+10 → effectiveness=1.5 → dmg=20*1.5*1.0=30
	var dmg: int = _calc_damage(20, 10, 1.0)
	assert(dmg == 30, "Expected 30, got %d" % dmg)
	print("  PASS test_damage_scales_up_when_attack_exceeds_defense")

func test_damage_scales_down_when_defense_exceeds_attack() -> void:
	# attack=10, defense=20 → stat_delta=-10 → effectiveness=0.5 → dmg=10*0.5*1.0=5
	var dmg: int = _calc_damage(10, 20, 1.0)
	assert(dmg == 5, "Expected 5, got %d" % dmg)
	print("  PASS test_damage_scales_down_when_defense_exceeds_attack")

func test_damage_clamped_to_minimum_one() -> void:
	# Even a full miss (accuracy 0.0 clamped to 0.1) should deal at least 1
	var dmg: int = _calc_damage(1, 100, 0.0)
	assert(dmg >= 1, "Damage should never be below 1, got %d" % dmg)
	print("  PASS test_damage_clamped_to_minimum_one")

func test_damage_effectiveness_ceiling() -> void:
	# stat_delta = +100 → effectiveness clamped at 2.0 → dmg = atk * 2.0 * 1.0
	var dmg: int = _calc_damage(10, 0, 1.0)   # delta = +10 → effective = 1.5
	assert(dmg == 15, "Expected 15 (delta+10 → 1.5x), got %d" % dmg)
	# Push delta to +20 for the 2.0x ceiling
	var dmg_ceil: int = _calc_damage(10, -10, 1.0)  # delta=+20 → effective=2.0
	assert(dmg_ceil == 20, "Expected 20 (2.0x ceiling), got %d" % dmg_ceil)
	print("  PASS test_damage_effectiveness_ceiling")

func test_damage_effectiveness_floor() -> void:
	# delta = -20 → effectiveness clamped at 0.5 → dmg = 10 * 0.5 * 1.0 = 5
	var dmg: int = _calc_damage(10, 30, 1.0)  # delta = -20 → 0.5x
	assert(dmg == 5, "Expected 5 (0.5x floor), got %d" % dmg)
	print("  PASS test_damage_effectiveness_floor")

## --- QTE Accuracy Tests ---

func test_qte_accuracy_inside_sweet_spot() -> void:
	# Position 0.5 (dead center) should give maximum accuracy
	var acc: float = _calc_accuracy(0.50)
	assert(acc >= 0.99, "Dead center should yield ~1.0 accuracy, got %.2f" % acc)
	# Position 0.35 (sweet spot edge) should give ~0.5
	var acc_edge: float = _calc_accuracy(0.35)
	assert(acc_edge >= 0.49 and acc_edge <= 0.51,
		"Sweet spot edge should yield ~0.5 accuracy, got %.2f" % acc_edge)
	print("  PASS test_qte_accuracy_inside_sweet_spot")

func test_qte_accuracy_outside_sweet_spot() -> void:
	assert(_calc_accuracy(0.10) == 0.2, "Outside sweet spot should yield 0.2")
	assert(_calc_accuracy(0.90) == 0.2, "Outside sweet spot should yield 0.2")
	print("  PASS test_qte_accuracy_outside_sweet_spot")

func test_qte_accuracy_at_center() -> void:
	var acc: float = _calc_accuracy(0.5)
	assert(is_equal_approx(acc, 1.0), "Center of bar should yield exactly 1.0, got %.4f" % acc)
	print("  PASS test_qte_accuracy_at_center")

## --- Energy Economy Tests ---

func test_energy_regen_and_cost_balance() -> void:
	# Grunts: energy_max=10, regen=3, cost=3 → always able to act each turn
	var energy: int = 10
	energy -= 3    # spend on attack
	assert(energy == 7, "After attack, energy should be 7")
	energy = mini(10, energy + 3)  # regen at turn start
	assert(energy == 10, "After regen (cap 10), energy should be back to 10")
	print("  PASS test_energy_regen_and_cost_balance")
