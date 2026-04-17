class_name EquipmentLibrary
extends RefCounted

## --- EquipmentLibrary ---
## Static catalog of all equipment items. Pattern mirrors AbilityLibrary / ConsumableLibrary.
## Placeholder data — a future CSV import will replace these constants.
##
## get_equipment() never returns null; falls back to a stub for unknown IDs.
## all_equipment() returns the full catalog for use in reward pools.

const _ITEMS: Array[Dictionary] = [
	## --- Armor ---
	{
		"id":   "leather_armor",
		"name": "Leather Armor",
		"slot": EquipmentData.Slot.ARMOR,
		"bonuses": {"armor_defense": 1},
		"desc": "Light protection.",
	},
	{
		"id":   "chain_mail",
		"name": "Chain Mail",
		"slot": EquipmentData.Slot.ARMOR,
		"bonuses": {"armor_defense": 2, "dexterity": -1},
		"desc": "Heavier. Slower.",
	},
	## --- Weapons ---
	{
		"id":   "short_sword",
		"name": "Short Sword",
		"slot": EquipmentData.Slot.WEAPON,
		"bonuses": {"strength": 1},
		"desc": "A simple blade.",
	},
	{
		"id":   "hunters_bow",
		"name": "Hunter's Bow",
		"slot": EquipmentData.Slot.WEAPON,
		"bonuses": {"dexterity": 1},
		"desc": "Better range.",
	},
	## --- Accessories ---
	{
		"id":   "iron_ring",
		"name": "Iron Ring",
		"slot": EquipmentData.Slot.ACCESSORY,
		"bonuses": {"vitality": 1},
		"desc": "Adds constitution.",
	},
	{
		"id":   "lucky_charm",
		"name": "Lucky Charm",
		"slot": EquipmentData.Slot.ACCESSORY,
		"bonuses": {"willpower": 1},
		"desc": "Luck of the draw.",
	},
]

## Returns a populated EquipmentData for the given ID. Never returns null.
static func get_equipment(id: String) -> EquipmentData:
	for def in _ITEMS:
		if def["id"] == id:
			return _build(def)
	# Unknown ID → stub so callers never receive null
	var stub := EquipmentData.new()
	stub.equipment_id   = id
	stub.equipment_name = "Unknown"
	stub.slot           = EquipmentData.Slot.WEAPON
	stub.stat_bonuses   = {}
	stub.description    = "Unknown item."
	return stub

## Returns every defined item. Used to populate reward pools.
static func all_equipment() -> Array[EquipmentData]:
	var result: Array[EquipmentData] = []
	for def in _ITEMS:
		result.append(_build(def))
	return result

static func _build(def: Dictionary) -> EquipmentData:
	var eq := EquipmentData.new()
	eq.equipment_id   = def["id"]
	eq.equipment_name = def["name"]
	eq.slot           = def["slot"]
	eq.stat_bonuses   = def["bonuses"].duplicate()
	eq.description    = def["desc"]
	return eq
