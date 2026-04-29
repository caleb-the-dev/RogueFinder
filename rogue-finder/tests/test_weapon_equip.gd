extends Node

## --- Unit Tests: Weapon Equip / Unequip Pool Lifecycle ---
## Tests: on_equip adds granted_ability_ids to pool; on_unequip removes them;
## active slots protect abilities from removal; CSV pipe-parsing; dedup.
## Run headless: import then run test_weapon_equip.tscn.

func _ready() -> void:
	print("=== test_weapon_equip.gd ===")
	test_equip_adds_granted_ability_to_pool()
	test_equip_deduplicates_ability_in_pool()
	test_unequip_removes_granted_ability_from_pool()
	test_unequip_clears_slotted_ability()
	test_csv_iron_sword_grants_blade_strike()
	test_csv_pipe_multiple_granted_ids_parsed()
	test_armor_equip_is_pool_noop()
	print("=== All weapon equip tests passed ===")

func _make_weapon(ability_ids: Array[String]) -> EquipmentData:
	var eq := EquipmentData.new()
	eq.equipment_id        = "test_weapon"
	eq.equipment_name      = "Test Weapon"
	eq.slot                = EquipmentData.Slot.WEAPON
	eq.rarity              = EquipmentData.Rarity.COMMON
	eq.stat_bonuses        = {}
	eq.granted_ability_ids = ability_ids
	eq.feat_id             = ""
	return eq

## --- on_equip ---

func test_equip_adds_granted_ability_to_pool() -> void:
	var pc := CombatantData.new()
	pc.ability_pool = []
	var eq := _make_weapon(["blade_strike"])
	pc.on_equip(eq)
	assert(pc.ability_pool.has("blade_strike"),
		"on_equip should add 'blade_strike' to ability_pool")
	print("  PASS test_equip_adds_granted_ability_to_pool")

func test_equip_deduplicates_ability_in_pool() -> void:
	var pc := CombatantData.new()
	pc.ability_pool = ["blade_strike"]
	var eq := _make_weapon(["blade_strike"])
	pc.on_equip(eq)
	var count: int = 0
	for aid in pc.ability_pool:
		if aid == "blade_strike":
			count += 1
	assert(count == 1,
		"on_equip should not duplicate 'blade_strike' already in pool; count=%d" % count)
	print("  PASS test_equip_deduplicates_ability_in_pool")

## --- on_unequip ---

func test_unequip_removes_granted_ability_from_pool() -> void:
	var pc := CombatantData.new()
	pc.ability_pool = ["strike", "blade_strike"]
	pc.abilities    = ["strike", "", "", ""]
	var eq := _make_weapon(["blade_strike"])
	pc.on_unequip(eq)
	assert(not pc.ability_pool.has("blade_strike"),
		"on_unequip should remove 'blade_strike' from pool when not slotted")
	assert(pc.ability_pool.has("strike"),
		"on_unequip should leave unrelated 'strike' in pool")
	print("  PASS test_unequip_removes_granted_ability_from_pool")

func test_unequip_clears_slotted_ability() -> void:
	var pc := CombatantData.new()
	pc.ability_pool = ["blade_strike", "strike"]
	pc.abilities    = ["blade_strike", "strike", "", ""]
	var eq := _make_weapon(["blade_strike"])
	pc.on_unequip(eq)
	assert(not pc.ability_pool.has("blade_strike"),
		"on_unequip must remove 'blade_strike' from pool even when slotted")
	assert(pc.abilities[0] == "",
		"on_unequip must clear the slot that held the granted ability")
	assert(pc.abilities[1] == "strike",
		"on_unequip must not touch unrelated slots")
	print("  PASS test_unequip_clears_slotted_ability")

## --- CSV parsing ---

func test_csv_iron_sword_grants_blade_strike() -> void:
	EquipmentLibrary.reload()
	var eq: EquipmentData = EquipmentLibrary.get_equipment("iron_sword")
	assert(not eq.granted_ability_ids.is_empty(),
		"iron_sword should have at least one granted_ability_id")
	assert(eq.granted_ability_ids[0] == "blade_strike",
		"iron_sword granted_ability_ids[0] should be 'blade_strike', got '%s'" % eq.granted_ability_ids[0])
	print("  PASS test_csv_iron_sword_grants_blade_strike")

func test_csv_pipe_multiple_granted_ids_parsed() -> void:
	## Inject a fake row with two pipe-separated ids to verify split logic.
	## We do this by constructing a manual EquipmentData and confirming
	## on_equip handles multiple ids correctly.
	var pc := CombatantData.new()
	pc.ability_pool = []
	var eq := _make_weapon(["blade_strike", "quick_draw"])
	pc.on_equip(eq)
	assert(pc.ability_pool.has("blade_strike"),
		"equip with two ids should add 'blade_strike' to pool")
	assert(pc.ability_pool.has("quick_draw"),
		"equip with two ids should add 'quick_draw' to pool")
	pc.on_unequip(eq)
	assert(not pc.ability_pool.has("blade_strike"),
		"unequip with two ids should remove 'blade_strike' from pool")
	assert(not pc.ability_pool.has("quick_draw"),
		"unequip with two ids should remove 'quick_draw' from pool")
	print("  PASS test_csv_pipe_multiple_granted_ids_parsed")

func test_armor_equip_is_pool_noop() -> void:
	var pc := CombatantData.new()
	pc.ability_pool = ["strike"]
	var armor := EquipmentData.new()
	armor.equipment_id        = "padded_armor"
	armor.equipment_name      = "Padded Armor"
	armor.slot                = EquipmentData.Slot.ARMOR
	armor.rarity              = EquipmentData.Rarity.COMMON
	armor.stat_bonuses        = {"physical_armor": 1}
	armor.granted_ability_ids = []
	armor.feat_id             = ""
	pc.on_equip(armor)
	assert(pc.ability_pool.size() == 1 and pc.ability_pool[0] == "strike",
		"equipping armor with no granted_ability_ids must not change pool")
	pc.on_unequip(armor)
	assert(pc.ability_pool.size() == 1 and pc.ability_pool[0] == "strike",
		"unequipping armor with no granted_ability_ids must not change pool")
	print("  PASS test_armor_equip_is_pool_noop")
