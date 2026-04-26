class_name FeatLibrary
extends RefCounted

const CSV_PATH := "res://data/feats.csv"

static var _cache: Dictionary = {}

## Returns a FeatData for the given id. Never returns null.
static func get_feat(id: String) -> FeatData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := FeatData.new()
	stub.id          = id
	stub.name        = "Unknown Feat"
	stub.description = ""
	stub.stat_bonuses = {}
	return stub

static func all_feats() -> Array[FeatData]:
	_ensure_loaded()
	var result: Array[FeatData] = []
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
		push_error("FeatLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("FeatLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("FeatLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var feat := _row_to_data(header, row, row_num)
		if feat != null:
			_cache[feat.id] = feat

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> FeatData:
	var feat := FeatData.new()
	for i in header.size():
		match header[i]:
			"id":          feat.id          = row[i]
			"name":        feat.name        = row[i]
			"description": feat.description = row[i]
			"source_type": feat.source_type = row[i]
			"stat_bonuses":
				feat.stat_bonuses = _parse_stat_bonuses(row[i])
			"effects", "notes":
				pass  # effects reserved for future trigger-based feats; notes are designer free-text
			_:
				push_warning("FeatLibrary: unknown column '%s' at row %d" % [header[i], row_num])
	if feat.id == "":
		push_error("FeatLibrary: row %d missing id — skipping" % row_num)
		return null
	return feat

## Parses "stat:value|stat:value" → {stat: int}. Empty string → {}.
static func _parse_stat_bonuses(raw: String) -> Dictionary:
	var result: Dictionary = {}
	if raw == "":
		return result
	for pair in raw.split("|", false):
		var parts := pair.split(":", false)
		if parts.size() == 2:
			result[parts[0]] = int(parts[1])
		else:
			push_warning("FeatLibrary: malformed stat_bonus pair '%s'" % pair)
	return result
