class_name ClassLibrary
extends RefCounted

## --- ClassLibrary ---
## Static catalog of playable classes. CSV-native from the start — mirrors
## BackgroundLibrary shape exactly (lazy-load, single-parse, stub fallback).
##
## Data source: res://data/classes.csv
## get_class_data() never returns null; falls back to a stub for unknown IDs.
##
## Note: method named get_class_data() (not get_class) because get_class() is a
## built-in Object method in Godot and cannot be redeclared.

const CSV_PATH := "res://data/classes.csv"

static var _cache: Dictionary = {}

static func get_class_data(id: String) -> ClassData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := ClassData.new()
	stub.class_id    = id
	stub.display_name = "Unknown"
	stub.description  = "Unknown class."
	return stub

static func all_classes() -> Array[ClassData]:
	_ensure_loaded()
	var result: Array[ClassData] = []
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
		push_error("ClassLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("ClassLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("ClassLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var c := _row_to_data(header, row, row_num)
		if c != null:
			_cache[c.class_id] = c

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> ClassData:
	var c := ClassData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				c.class_id = val
			"name":
				c.display_name = val
			"description":
				c.description = val
			"starting_ability_id":
				c.starting_ability_id = val
			"feat_pool":
				c.feat_pool = _split_pipe(val)
			"unlocked_by_default":
				c.unlocked_by_default = (val == "true")
			"tags":
				c.tags = _split_pipe(val)
			"notes":
				pass
			_:
				push_warning("ClassLibrary: unknown column '%s' at row %d" % [col, row_num])
	if c.class_id == "":
		push_error("ClassLibrary: row %d missing id — skipping" % row_num)
		return null
	return c

static func _split_pipe(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for p in val.split("|", false):
		parts.append(p)
	return parts
