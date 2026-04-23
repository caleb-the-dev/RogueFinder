class_name PortraitLibrary
extends RefCounted

## --- PortraitLibrary ---
## Static catalog of selectable portraits. CSV-native — mirrors BackgroundLibrary
## shape (lazy-load, single-parse, stub fallback).
##
## Data source: res://data/portraits.csv
## get_portrait() never returns null; falls back to a stub for unknown IDs.
## Stub artwork_path points at res://icon.svg per placeholder art convention.

const CSV_PATH := "res://data/portraits.csv"

static var _cache: Dictionary = {}

static func get_portrait(id: String) -> PortraitData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := PortraitData.new()
	stub.portrait_id   = id
	stub.portrait_name = "Unknown"
	stub.artwork_path  = "res://icon.svg"
	return stub

static func all_portraits() -> Array[PortraitData]:
	_ensure_loaded()
	var result: Array[PortraitData] = []
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
		push_error("PortraitLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("PortraitLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("PortraitLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var p := _row_to_data(header, row, row_num)
		if p != null:
			_cache[p.portrait_id] = p

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> PortraitData:
	var p := PortraitData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				p.portrait_id = val
			"name":
				p.portrait_name = val
			"artwork_path":
				p.artwork_path = val
			"tags":
				p.tags = _split_pipe(val)
			"notes":
				pass
			_:
				push_warning("PortraitLibrary: unknown column '%s' at row %d" % [col, row_num])
	if p.portrait_id == "":
		push_error("PortraitLibrary: row %d missing id — skipping" % row_num)
		return null
	return p

static func _split_pipe(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for part in val.split("|", false):
		parts.append(part)
	return parts
