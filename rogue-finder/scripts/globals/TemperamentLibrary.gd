class_name TemperamentLibrary
extends RefCounted

## --- TemperamentLibrary ---
## Static catalog of temperaments. Pokémon-nature style: each entry gives +1 to
## one attribute and -1 to another. One neutral entry ("even") has no effect.
## Data source: res://data/temperaments.csv
## get_temperament() never returns null; falls back to the neutral stub on unknown ids.

const CSV_PATH := "res://data/temperaments.csv"

static var _cache: Dictionary = {}

static func get_temperament(id: String) -> TemperamentData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := TemperamentData.new()
	stub.temperament_id   = id
	stub.temperament_name = "Unknown"
	return stub

static func all_temperaments() -> Array[TemperamentData]:
	_ensure_loaded()
	var result: Array[TemperamentData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

## Picks a random temperament id using the provided RNG.
static func random_id(rng: RandomNumberGenerator) -> String:
	_ensure_loaded()
	var keys: Array = _cache.keys()
	if keys.is_empty():
		return "even"
	return keys[rng.randi_range(0, keys.size() - 1)]

static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## --- Internal ---

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("TemperamentLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("TemperamentLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("TemperamentLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var t := _row_to_data(header, row)
		if t != null:
			_cache[t.temperament_id] = t

static func _row_to_data(header: PackedStringArray, row: PackedStringArray) -> TemperamentData:
	var t := TemperamentData.new()
	for i in header.size():
		match header[i]:
			"id":             t.temperament_id   = row[i]
			"name":           t.temperament_name = row[i]
			"boosted_stat":   t.boosted_stat     = row[i]
			"hindered_stat":  t.hindered_stat    = row[i]
	if t.temperament_id == "":
		push_error("TemperamentLibrary: row missing id — skipping")
		return null
	return t
