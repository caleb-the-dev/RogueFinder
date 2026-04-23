class_name KindredLibrary
extends RefCounted

## --- KindredLibrary ---
## Single source of truth for per-kindred mechanical data. CSV-native — mirrors
## BackgroundLibrary shape (lazy-load, single-parse, stub fallback).
##
## Data source: res://data/kindreds.csv
## Getter functions (get_speed_bonus / get_hp_bonus / get_feat_*) are unchanged
## from the old const-dict version — all callers unaffected.

const CSV_PATH := "res://data/kindreds.csv"

static var _cache: Dictionary = {}

## --- Public getters (existing API — unchanged) ---

static func get_speed_bonus(kindred: String) -> int:
	return get_kindred(kindred).speed_bonus

static func get_hp_bonus(kindred: String) -> int:
	return get_kindred(kindred).hp_bonus

static func get_feat_id(kindred: String) -> String:
	return get_kindred(kindred).feat_id

static func get_feat_name(kindred: String) -> String:
	return get_kindred(kindred).feat_name

static func get_feat_desc(kindred: String) -> String:
	return get_kindred(kindred).feat_desc

## --- New catalog API ---

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
			"feat_id":
				k.feat_id = val
			"feat_name":
				k.feat_name = val
			"feat_desc":
				k.feat_desc = val
			"notes":
				pass
			_:
				push_warning("KindredLibrary: unknown column '%s' at row %d" % [col, row_num])
	if k.kindred_id == "":
		push_error("KindredLibrary: row %d missing id — skipping" % row_num)
		return null
	return k
