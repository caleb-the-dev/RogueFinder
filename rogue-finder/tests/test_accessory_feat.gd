extends Node

## --- Unit Tests: Accessory Feat Aggregation ---
## Tests: get_feat_stat_bonus() includes accessory.feat_id at read-time;
## unequip removes bonus; dedup prevents double-count; COMMON has no feat bonus;
## total equipment count is 36.

func _ready() -> void:
	print("=== test_accessory_feat.gd ===")
	test_rare_accessory_feat_adds_stat_bonus()
	test_unequip_accessory_removes_feat_bonus()
	test_dedup_accessory_feat_already_in_feat_ids()
	test_common_accessory_no_feat_bonus()
	test_all_equipment_count_36()
	print("=== All accessory feat tests passed ===")

## (a) Equipping a Rare accessory adds its feat's stat bonus to the derived stat.
## ring_of_valor_rare has feat_id=combat_training (strength:1).
## attack = 5 + strength + equip_bonus(strength) + feat_bonus(strength) + ...
## On a bare CombatantData with default strength=4, no feats, no other equip:
##   attack_before = 5 + 4 = 9
##   attack_after  = 5 + 4 + 1(ring str) + 1(combat_training str) = 11

func test_rare_accessory_feat_adds_stat_bonus() -> void:
	EquipmentLibrary.reload()
	FeatLibrary.reload()
	var pc := CombatantData.new()
	pc.feat_ids = []
	var before_attack: int = pc.attack
	var eq: EquipmentData = EquipmentLibrary.get_equipment("ring_of_valor_rare")
	assert(eq.feat_id == "combat_training",
		"ring_of_valor_rare should have feat_id=combat_training, got '%s'" % eq.feat_id)
	pc.accessory = eq
	# ring_of_valor_rare stat_bonuses: strength:1
	# combat_training stat_bonuses: strength:1
	# attack = 5 + str(4) + equip_str(1) + feat_str(1) = 11
	assert(pc.attack == before_attack + 2,
		"Rare accessory should add equip str+1 and feat str+1: expected %d, got %d" % [before_attack + 2, pc.attack])
	print("  PASS test_rare_accessory_feat_adds_stat_bonus")

## (b) Unequipping the accessory removes the feat bonus — derived stat returns to pre-equip value.

func test_unequip_accessory_removes_feat_bonus() -> void:
	EquipmentLibrary.reload()
	FeatLibrary.reload()
	var pc := CombatantData.new()
	pc.feat_ids = []
	var baseline_attack: int = pc.attack
	var eq: EquipmentData = EquipmentLibrary.get_equipment("ring_of_valor_rare")
	pc.accessory = eq
	assert(pc.attack > baseline_attack, "attack should increase when Rare accessory is equipped")
	pc.accessory = null
	assert(pc.attack == baseline_attack,
		"attack should return to baseline after unequipping, expected %d got %d" % [baseline_attack, pc.attack])
	print("  PASS test_unequip_accessory_removes_feat_bonus")

## (c) Dedup: if the accessory's feat_id is already in feat_ids, the bonus counts once.
## combat_training gives str:1. If it's in both feat_ids and accessory.feat_id, total str bonus = 1, not 2.

func test_dedup_accessory_feat_already_in_feat_ids() -> void:
	EquipmentLibrary.reload()
	FeatLibrary.reload()
	var pc := CombatantData.new()
	pc.feat_ids = ["combat_training"]  # already holds the feat
	var eq: EquipmentData = EquipmentLibrary.get_equipment("ring_of_valor_rare")
	pc.accessory = eq
	# feat bonus from combat_training should be 1 (str:1), not 2
	assert(pc.get_feat_stat_bonus("strength") == 1,
		"dedup: combat_training in feat_ids+accessory should sum to 1, got %d" % pc.get_feat_stat_bonus("strength"))
	print("  PASS test_dedup_accessory_feat_already_in_feat_ids")

## (d) Common accessory (no feat_id) does not change any feat-derived stat.

func test_common_accessory_no_feat_bonus() -> void:
	EquipmentLibrary.reload()
	FeatLibrary.reload()
	var pc := CombatantData.new()
	pc.feat_ids = []
	var eq: EquipmentData = EquipmentLibrary.get_equipment("ring_of_valor")
	assert(eq.feat_id == "",
		"ring_of_valor (COMMON) should have no feat_id, got '%s'" % eq.feat_id)
	var before_attack: int = pc.attack
	pc.accessory = eq
	# Only the stat_bonuses (strength:1) should apply — no feat bonus.
	# attack = 5 + 4 + 1(equip) + 0(feat) = 10
	assert(pc.get_feat_stat_bonus("strength") == 0,
		"COMMON accessory should contribute 0 feat bonus to strength, got %d" % pc.get_feat_stat_bonus("strength"))
	assert(pc.attack == before_attack + 1,
		"COMMON accessory: only equip stat_bonus should raise attack, expected %d got %d" % [before_attack + 1, pc.attack])
	print("  PASS test_common_accessory_no_feat_bonus")

## (e) all_equipment() returns 36 items: 12 weapons + 12 armor + 12 accessories.

func test_all_equipment_count_36() -> void:
	EquipmentLibrary.reload()
	var all: Array[EquipmentData] = EquipmentLibrary.all_equipment()
	assert(all.size() == 36,
		"all_equipment() should return 36 items, got %d" % all.size())
	var accessory_count := 0
	for eq in all:
		if eq.slot == EquipmentData.Slot.ACCESSORY:
			accessory_count += 1
	assert(accessory_count == 12,
		"should be 12 ACCESSORY items, got %d" % accessory_count)
	print("  PASS test_all_equipment_count_36")
