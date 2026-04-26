class_name KindredLibrary
extends RefCounted

## --- KindredLibrary ---
## Single source of truth for per-kindred mechanical data. CSV-native — mirrors
## BackgroundLibrary shape (lazy-load, single-parse, stub fallback).
##
## Data source: res://data/kindreds.csv
## Kindreds no longer grant feats — stat_bonuses are structural (always-on).

const CSV_PATH := "res://data/kindreds.csv"

static var _cache: Dictionary = {}

## --- Public getters ---

static func get_speed_bonus(kindred: String) -> int:
	return get_kindred(kindred).speed_bonus

static func get_hp_bonus(kindred: String) -> int:
	return get_kindred(kindred).hp_bonus

## Returns the flat stat bonus for a given stat key. 0 for unknown kindred or stat.
static func get_stat_bonus(kindred: String, stat: String) -> int:
	return get_kindred(kindred).stat_bonuses.get(stat, 0)

## Returns the flavor name pool for the given kindred. Empty array if unknown.
static func get_name_pool(kindred: String) -> Array[String]:
	return get_kindred(kindred).name_pool

## --- Catalog API ---

static func get_kindred(id: String) -> KindredData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := KindredData.new()
	stub.kindred_id = id
	return stub

static func all_kindreds() -> Array[KindredData]:
	_ensure_loaded()
	var result: Array[KindredData] = []
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
		push_error("KindredLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("KindredLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("KindredLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var k := _row_to_data(header, row, row_num)
		if k != null:
			_cache[k.kindred_id] = k

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> KindredData:
	var k := KindredData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				k.kindred_id = val
			"speed_bonus":
				k.speed_bonus = int(val)
			"hp_bonus":
				k.hp_bonus = int(val)
			"stat_bonuses":
				k.stat_bonuses = _parse_stat_bonuses(val)
			"starting_ability_id":
				k.starting_ability_id = val
			"ability_pool":
				k.ability_pool = _split_pipe(val)
			"name_pool":
				k.name_pool = _split_pipe(val)
			"notes":
				pass
			_:
				push_warning("KindredLibrary: unknown column '%s' at row %d" % [col, row_num])
	if k.kindred_id == "":
		push_error("KindredLibrary: row %d missing id — skipping" % row_num)
		return null
	return k

## Parses "stat:value|stat:value" into a Dictionary. Empty string returns {}.
static func _parse_stat_bonuses(val: String) -> Dictionary:
	var result: Dictionary = {}
	if val == "":
		return result
	for pair in val.split("|", false):
		var parts := pair.split(":", false)
		if parts.size() == 2:
			result[parts[0]] = int(parts[1])
	return result

static func _split_pipe(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for p in val.split("|", false):
		parts.append(p)
	return parts
