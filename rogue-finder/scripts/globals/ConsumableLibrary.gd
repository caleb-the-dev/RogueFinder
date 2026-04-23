class_name ConsumableLibrary
extends RefCounted

## --- ConsumableLibrary ---
## Static catalog of consumable items. CSV-native — mirrors BackgroundLibrary shape
## (lazy-load, single-parse, stub fallback on unknown ID).
##
## Data source: res://data/consumables.csv
## get_consumable() signature is unchanged from the old const-dict version.

const CSV_PATH := "res://data/consumables.csv"

static var _cache: Dictionary = {}

static func get_consumable(id: String) -> ConsumableData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := ConsumableData.new()
	stub.consumable_id   = "unknown"
	stub.consumable_name = "Unknown"
	stub.description     = "No consumable data found for ID: " + id
	return stub

static func all_consumables() -> Array[ConsumableData]:
	_ensure_loaded()
	var result: Array[ConsumableData] = []
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
		push_error("ConsumableLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("ConsumableLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("ConsumableLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var c := _row_to_data(header, row, row_num)
		if c != null:
			_cache[c.consumable_id] = c

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> ConsumableData:
	var c := ConsumableData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				c.consumable_id = val
			"name":
				c.consumable_name = val
			"effect_type":
				match val:
					"MEND":   c.effect_type = EffectData.EffectType.MEND
					"BUFF":   c.effect_type = EffectData.EffectType.BUFF
					"DEBUFF": c.effect_type = EffectData.EffectType.DEBUFF
					_: push_warning("ConsumableLibrary: unknown effect_type '%s' at row %d" % [val, row_num])
			"base_value":
				c.base_value = int(val)
			"target_stat":
				if val != "":
					match val:
						"STRENGTH":  c.target_stat = AbilityData.Attribute.STRENGTH
						"DEXTERITY": c.target_stat = AbilityData.Attribute.DEXTERITY
						"COGNITION": c.target_stat = AbilityData.Attribute.COGNITION
						"VITALITY":  c.target_stat = AbilityData.Attribute.VITALITY
						"WILLPOWER": c.target_stat = AbilityData.Attribute.WILLPOWER
						_: push_warning("ConsumableLibrary: unknown target_stat '%s' at row %d" % [val, row_num])
			"description":
				c.description = val
			"notes":
				pass
			_:
				push_warning("ConsumableLibrary: unknown column '%s' at row %d" % [col, row_num])
	if c.consumable_id == "":
		push_error("ConsumableLibrary: row %d missing id — skipping" % row_num)
		return null
	return c
