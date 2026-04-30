class_name VendorLibrary
extends RefCounted

## --- VendorLibrary ---
## Static catalog of vendor archetypes. Mirrors the BackgroundLibrary shape
## exactly — CSV is the single source of truth, cache is lazy-populated on
## first access, get_vendor() never returns null.
##
## vendors_by_scope() is the primary entry point for Slice 4 (VendorScene stock
## generation): WORLD vendors appear on map VENDOR nodes; CITY vendors appear
## inside Badurga's shop sections.

const CSV_PATH := "res://data/vendors.csv"

## Lazily populated on first access. Keyed by vendor_id.
static var _cache: Dictionary = {}

## Returns a populated VendorData for the given ID. Never returns null.
static func get_vendor(id: String) -> VendorData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := VendorData.new()
	stub.vendor_id   = "unknown"
	stub.display_name = "Unknown Vendor"
	stub.flavor      = "No one is here."
	stub.scope       = "WORLD"
	return stub

## Returns every loaded vendor.
static func all_vendors() -> Array[VendorData]:
	_ensure_loaded()
	var result: Array[VendorData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

## Returns vendors whose scope matches the given string ("CITY" or "WORLD").
static func vendors_by_scope(scope: String) -> Array[VendorData]:
	_ensure_loaded()
	var result: Array[VendorData] = []
	for v in _cache.values():
		if v.scope == scope:
			result.append(v)
	return result

## Force a reload from disk. Useful for tests and dev-time CSV edits.
static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## --- Internal ---

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("VendorLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("VendorLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("VendorLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var v := _row_to_data(header, row, row_num)
		if v != null:
			_cache[v.vendor_id] = v

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> VendorData:
	var v := VendorData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				v.vendor_id = val
			"display_name":
				v.display_name = val
			"flavor":
				v.flavor = val
			"category_pool":
				v.category_pool = _split_pipe(val)
			"stock_count":
				v.stock_count = int(val)
			"scope":
				v.scope = val
			_:
				push_warning("VendorLibrary: unknown column '%s' at row %d" % [col, row_num])
	if v.vendor_id == "":
		push_error("VendorLibrary: row %d missing id — skipping" % row_num)
		return null
	return v

static func _split_pipe(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for p in val.split("|", false):
		parts.append(p)
	return parts
