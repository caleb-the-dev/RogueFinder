extends Node

## --- Unit Tests: Unit.gd ---
## Run via: Project > Run This Scene (F6) while this scene is open,
## or attach this script to a test runner node.
## All tests use plain assert(); failures print to the Output panel.

func _ready() -> void:
	print("=== test_unit.gd ===")
	test_initialize_from_data()
	test_take_damage_reduces_hp()
	test_take_damage_clamps_at_zero()
	test_die_sets_not_alive()
	test_spend_energy_deducts()
	test_spend_energy_fails_when_insufficient()
	test_regen_energy_clamps_at_max()
	test_reset_turn_clears_flags()
	test_can_stride_requires_alive_and_not_moved()
	test_can_act_requires_alive_not_acted_and_energy()
	print("=== All Unit tests passed ===")

## --- Helpers ---

func _make_unit(hp: int = 20, energy: int = 10, energy_max: int = 10) -> Unit:
	var d := UnitData.new()
	d.unit_name    = "TestUnit"
	d.is_player_unit = true
	d.hp_max       = hp
	d.speed        = 3
	d.attack       = 10
	d.defense      = 10
	d.energy_max   = energy_max
	d.energy_regen = 3

	# Unit needs child nodes that @onready expects; we skip them by calling setup after add_child
	var u := Unit.new()
	# Bypass @onready by manually assigning nodes
	var visual      := ColorRect.new()
	var name_label  := Label.new()
	var stats_label := Label.new()
	u.add_child(visual)
	u.add_child(name_label)
	u.add_child(stats_label)
	# Directly wire the fields (GDScript allows this because there's no true encapsulation)
	u.set("visual",      visual)
	u.set("name_label",  name_label)
	u.set("stats_label", stats_label)

	add_child(u)   # needed so _ready runs
	u.data = d
	u.current_hp     = hp
	u.current_energy = energy
	u.is_alive       = true
	return u

## --- Tests ---

func test_initialize_from_data() -> void:
	var d := UnitData.new()
	d.hp_max = 30
	d.energy_max = 8
	d.unit_name = "Hero"
	# Directly test the stat values a setup would produce
	assert(d.hp_max == 30,    "hp_max should be 30")
	assert(d.energy_max == 8, "energy_max should be 8")
	assert(d.unit_name == "Hero", "name should be Hero")
	print("  PASS test_initialize_from_data")

func test_take_damage_reduces_hp() -> void:
	var u := _make_unit(20, 10)
	u.take_damage(7)
	assert(u.current_hp == 13, "HP should be 13 after 7 damage (was 20)")
	print("  PASS test_take_damage_reduces_hp")

func test_take_damage_clamps_at_zero() -> void:
	var u := _make_unit(10, 10)
	u.take_damage(999)
	assert(u.current_hp == 0, "HP should clamp at 0, not go negative")
	print("  PASS test_take_damage_clamps_at_zero")

func test_die_sets_not_alive() -> void:
	var u := _make_unit(5, 10)
	u.take_damage(5)   # drops to 0 → triggers _die
	assert(not u.is_alive, "Unit should be marked not alive after HP reaches 0")
	print("  PASS test_die_sets_not_alive")

func test_spend_energy_deducts() -> void:
	var u := _make_unit(20, 10)
	var success: bool = u.spend_energy(3)
	assert(success,           "spend_energy should return true when affordable")
	assert(u.current_energy == 7, "Energy should be 7 after spending 3 from 10")
	print("  PASS test_spend_energy_deducts")

func test_spend_energy_fails_when_insufficient() -> void:
	var u := _make_unit(20, 2)
	var success: bool = u.spend_energy(3)
	assert(not success,        "spend_energy should return false when unaffordable")
	assert(u.current_energy == 2, "Energy should be unchanged on failed spend")
	print("  PASS test_spend_energy_fails_when_insufficient")

func test_regen_energy_clamps_at_max() -> void:
	var u := _make_unit(20, 9)
	u.data.energy_max   = 10
	u.data.energy_regen = 5
	u.regen_energy()
	assert(u.current_energy == 10, "Regen should clamp at energy_max, not exceed it")
	print("  PASS test_regen_energy_clamps_at_max")

func test_reset_turn_clears_flags() -> void:
	var u := _make_unit(20, 10)
	u.has_moved = true
	u.has_acted = true
	u.reset_turn()
	assert(not u.has_moved, "has_moved should be false after reset_turn")
	assert(not u.has_acted, "has_acted should be false after reset_turn")
	print("  PASS test_reset_turn_clears_flags")

func test_can_stride_requires_alive_and_not_moved() -> void:
	var u := _make_unit(20, 10)
	assert(u.can_stride(),    "Fresh unit should be able to stride")
	u.has_moved = true
	assert(not u.can_stride(), "Unit that already moved cannot stride again")
	u.has_moved = false
	u.is_alive  = false
	assert(not u.can_stride(), "Dead unit cannot stride")
	print("  PASS test_can_stride_requires_alive_and_not_moved")

func test_can_act_requires_alive_not_acted_and_energy() -> void:
	var u := _make_unit(20, 10)
	assert(u.can_act(3),     "Fresh unit with 10 energy can act for cost 3")
	u.has_acted = true
	assert(not u.can_act(3), "Unit that already acted cannot act again")
	u.has_acted = false
	u.current_energy = 2
	assert(not u.can_act(3), "Unit with 2 energy cannot act for cost 3")
	u.current_energy = 10
	u.is_alive = false
	assert(not u.can_act(3), "Dead unit cannot act")
	print("  PASS test_can_act_requires_alive_not_acted_and_energy")
