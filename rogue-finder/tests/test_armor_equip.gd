extends Node

## --- Unit Tests: Armor Equip / Unequip Pool Lifecycle ---
## Tests: defense stat formula via _equip_bonus; on_equip adds granted_ability_ids;
## on_unequip removes them + clears active slot; Epic +2/+2 CSV parsing; item count.

func _ready() -> void:
	print("=== test_armor_equip.gd ===")
	test_common_armor_physical_defense()
	test_common_armor_magic_defense()
	test_rare_armor_grants_ability_to_pool()
	test_unequip_removes_ability_from_pool()
	test_unequip_clears_slotted_ability()
	test_epic_plus_two_plus_two_parses_correctly()
	test_all_equipment_count()
	print("=== All armor equip tests passed ===")

## (a) Common armor physical_defense via _equip_bonus

func test_common_armor_physical_defense() -> void:
	EquipmentLibrary.reload()
	var pc := CombatantData.new()
	# default physical_armor = 3, no class/kindred/bg bonuses
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_plate")
	pc.armor = eq
	pc.on_equip(eq)
	# physical_defense = 3(base) + 5(equip) = 8
	assert(pc.physical_defense == 8,
		"iron_plate should give physical_defense=8, got %d" % pc.physical_defense)
	print("  PASS test_common_armor_physical_defense")

func test_common_armor_magic_defense() -> void:
	EquipmentLibrary.reload()
	var pc := CombatantData.new()
	# default magic_armor = 2
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_plate")
	pc.armor = eq
	pc.on_equip(eq)
	# magic_defense = 2(base) + 1(equip) = 3
	assert(pc.magic_defense == 3,
		"iron_plate should give magic_defense=3, got %d" % pc.magic_defense)
	print("  PASS test_common_armor_magic_defense")

## (b) Equipping Rare armor adds the granted ability to pool

func test_rare_armor_grants_ability_to_pool() -> void:
	EquipmentLibrary.reload()
	var pc := CombatantData.new()
	pc.ability_pool = []
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_plate_rare")
	assert(eq.granted_ability_ids.has("stone_guard"),
		"iron_plate_rare should have granted_ability_ids=[stone_guard]")
	pc.on_equip(eq)
	assert(pc.ability_pool.has("stone_guard"),
		"equipping iron_plate_rare should add 'stone_guard' to ability_pool")
	print("  PASS test_rare_armor_grants_ability_to_pool")

## (c) Unequipping removes ability from pool and clears active slot

func test_unequip_removes_ability_from_pool() -> void:
	EquipmentLibrary.reload()
	var pc := CombatantData.new()
	pc.ability_pool = ["stone_guard"]
	pc.abilities    = ["", "", "", ""]
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_plate_rare")
	pc.on_unequip(eq)
	assert(not pc.ability_pool.has("stone_guard"),
		"on_unequip should remove 'stone_guard' from pool when not slotted")
	print("  PASS test_unequip_removes_ability_from_pool")

func test_unequip_clears_slotted_ability() -> void:
	EquipmentLibrary.reload()
	var pc := CombatantData.new()
	pc.ability_pool = ["stone_guard", "strike"]
	pc.abilities    = ["stone_guard", "strike", "", ""]
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_plate_rare")
	pc.on_unequip(eq)
	assert(not pc.ability_pool.has("stone_guard"),
		"on_unequip must remove 'stone_guard' from pool even when slotted")
	assert(pc.abilities[0] == "",
		"on_unequip must clear the slot that held 'stone_guard'")
	assert(pc.abilities[1] == "strike",
		"on_unequip must not touch unrelated slots")
	print("  PASS test_unequip_clears_slotted_ability")

## (d) Epic armor: +2/+2 numbers parse correctly from CSV

func test_epic_plus_two_plus_two_parses_correctly() -> void:
	EquipmentLibrary.reload()
	var pc := CombatantData.new()
	var common_eq: EquipmentData = EquipmentLibrary.get_equipment("iron_plate")
	var epic_eq:   EquipmentData = EquipmentLibrary.get_equipment("iron_plate_epic")
	# Common: physical_armor 5, magic_armor 1; Epic: physical_armor 7, magic_armor 3
	assert(common_eq.get_bonus("physical_armor") == 5,
		"iron_plate should give +5 physical_armor, got %d" % common_eq.get_bonus("physical_armor"))
	assert(common_eq.get_bonus("magic_armor") == 1,
		"iron_plate should give +1 magic_armor, got %d" % common_eq.get_bonus("magic_armor"))
	assert(epic_eq.get_bonus("physical_armor") == 7,
		"iron_plate_epic should give +7 physical_armor, got %d" % epic_eq.get_bonus("physical_armor"))
	assert(epic_eq.get_bonus("magic_armor") == 3,
		"iron_plate_epic should give +3 magic_armor, got %d" % epic_eq.get_bonus("magic_armor"))
	# Equipping the epic confirms +2/+2 relative bump lands in physical_defense / magic_defense
	pc.armor = epic_eq
	pc.on_equip(epic_eq)
	# physical_defense = 3(base) + 7(equip) = 10
	assert(pc.physical_defense == 10,
		"iron_plate_epic physical_defense should be 10, got %d" % pc.physical_defense)
	# magic_defense = 2(base) + 3(equip) = 5
	assert(pc.magic_defense == 5,
		"iron_plate_epic magic_defense should be 5, got %d" % pc.magic_defense)
	print("  PASS test_epic_plus_two_plus_two_parses_correctly")

## (e) all_equipment() returns 27 items: 12 weapons + 12 armor + 3 accessory

func test_all_equipment_count() -> void:
	EquipmentLibrary.reload()
	var all: Array[EquipmentData] = EquipmentLibrary.all_equipment()
	assert(all.size() == 27,
		"all_equipment() should return 27 items, got %d" % all.size())
	var armor_count := 0
	for eq in all:
		if eq.slot == EquipmentData.Slot.ARMOR:
			armor_count += 1
	assert(armor_count == 12,
		"should be 12 ARMOR items, got %d" % armor_count)
	print("  PASS test_all_equipment_count")
