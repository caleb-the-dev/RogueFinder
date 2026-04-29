class_name EquipmentLibrary
extends RefCounted

## --- EquipmentLibrary ---
## Static catalog of equipment items. CSV-native — mirrors BackgroundLibrary shape
## (lazy-load, single-parse, stub fallback on unknown ID).
##
## Data source: res://data/equipment.csv
##
## stat_bonuses format: pipe-separated "stat:value" pairs, e.g. "strength:1|dexterity:-1"
## rarity format: COMMON | RARE | EPIC | LEGENDARY
## granted_ability_ids format: pipe-separated ability id strings, or empty
## feat_id format: single feat id string, or empty

const CSV_PATH := "res://data/equipment.csv"

static var _cache: Dictionary = {}

static func get_equipment(id: String) -> EquipmentData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := EquipmentData.new()
	stub.equipment_id          = id
	stub.equipment_name        = "Unknown"
	stub.slot                  = EquipmentData.Slot.WEAPON
	stub.rarity                = EquipmentData.Rarity.COMMON
	stub.stat_bonuses          = {}
	stub.granted_ability_ids   = []
	stub.feat_id               = ""
	stub.description           = "Unknown item."
	return stub

static func all_equipment() -> Array[EquipmentData]:
	_ensure_loaded()
	var result: Array[EquipmentData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## --- Internal ---

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("EquipmentLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("EquipmentLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("EquipmentLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var eq := _row_to_data(header, row, row_num)
		if eq != null:
			_cache[eq.equipment_id] = eq

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> EquipmentData:
	var eq := EquipmentData.new()
	eq.rarity               = EquipmentData.Rarity.COMMON
	eq.granted_ability_ids  = []
	eq.feat_id              = ""
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				eq.equipment_id = val
			"name":
				eq.equipment_name = val
			"slot":
				match val:
					"WEAPON":    eq.slot = EquipmentData.Slot.WEAPON
					"ARMOR":     eq.slot = EquipmentData.Slot.ARMOR
					"ACCESSORY": eq.slot = EquipmentData.Slot.ACCESSORY
					_: push_warning("EquipmentLibrary: unknown slot '%s' at row %d" % [val, row_num])
			"rarity":
				match val:
					"COMMON":    eq.rarity = EquipmentData.Rarity.COMMON
					"RARE":      eq.rarity = EquipmentData.Rarity.RARE
					"EPIC":      eq.rarity = EquipmentData.Rarity.EPIC
					"LEGENDARY": eq.rarity = EquipmentData.Rarity.LEGENDARY
					"": pass
					_: push_warning("EquipmentLibrary: unknown rarity '%s' at row %d" % [val, row_num])
			"stat_bonuses":
				eq.stat_bonuses = _parse_stat_bonuses(val, row_num)
			"granted_ability_ids":
				if val != "":
					eq.granted_ability_ids.assign(val.split("|", false))
			"feat_id":
				eq.feat_id = val
			"description":
				eq.description = val
			"notes":
				pass
			_:
				push_warning("EquipmentLibrary: unknown column '%s' at row %d" % [col, row_num])
	if eq.equipment_id == "":
		push_error("EquipmentLibrary: row %d missing id — skipping" % row_num)
		return null
	return eq

## Parses "stat:value|stat:value" into a Dictionary. Negative values are supported.
static func _parse_stat_bonuses(val: String, row_num: int) -> Dictionary:
	var result: Dictionary = {}
	if val == "":
		return result
	for pair in val.split("|", false):
		var parts := pair.split(":", false, 1)
		if parts.size() == 2:
			result[parts[0]] = int(parts[1])
		else:
			push_warning("EquipmentLibrary: malformed stat_bonuses pair '%s' at row %d" % [pair, row_num])
	return result
