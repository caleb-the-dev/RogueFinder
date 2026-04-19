class_name BackgroundLibrary
extends RefCounted

## --- BackgroundLibrary ---
## Static catalog of character backgrounds. Pattern mirrors AbilityLibrary /
## EquipmentLibrary / ConsumableLibrary — but this is the first library in the
## codebase that sources from CSV. Future library migrations should follow this
## shape (see csv-builder skill).
##
## Data flow: the CSV at rogue-finder/data/backgrounds.csv is the single source
## of truth — read here via res://data/backgrounds.csv. No docs/csv_data/ mirror
## (scrapped 2026-04-19; drift risk outweighed any benefit). Always read via
## res:// — relative/absolute paths work in the editor and break on export.
##
## get_background() never returns null; falls back to a stub for unknown IDs so
## callers don't have to null-guard.

const CSV_PATH := "res://data/backgrounds.csv"

## Lazily populated on first access. Keyed by background_id.
static var _cache: Dictionary = {}

## Returns a populated BackgroundData for the given ID. Never returns null.
static func get_background(id: String) -> BackgroundData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := BackgroundData.new()
	stub.background_id   = id
	stub.background_name = "Unknown"
	stub.description     = "Unknown background."
	return stub

## Back-compat bridge while CombatantData.background / ArchetypeLibrary still
## store PascalCase display strings ("Crook", "Soldier"). Lets the library be
## called from existing code without a snake_case-id migration. Delete this
## (and update callers to get_background) once that migration lands.
static func get_background_by_name(display_name: String) -> BackgroundData:
	_ensure_loaded()
	for bg in _cache.values():
		if bg.background_name == display_name:
			return bg
	return get_background("")  # falls through to Unknown stub

## Returns every loaded background. Useful for character-creation UI, unlock
## screens, and validators that cross-check ArchetypeLibrary pools.
static func all_backgrounds() -> Array[BackgroundData]:
	_ensure_loaded()
	var result: Array[BackgroundData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

## Force a reload from disk. Mostly useful for tests and dev-time iteration
## after editing the CSV without restarting the editor.
static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## --- Internal ---

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("BackgroundLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("BackgroundLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		# Godot returns [""] for the trailing newline at EOF — skip quietly.
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("BackgroundLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var bg := _row_to_data(header, row, row_num)
		if bg != null:
			_cache[bg.background_id] = bg

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> BackgroundData:
	var bg := BackgroundData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				bg.background_id = val
			"name":
				bg.background_name = val
			"starting_ability_id":
				bg.starting_ability_id = val
			"feat_pool":
				bg.feat_pool = _split_pipe(val)
			"unlocked_by_default":
				bg.unlocked_by_default = (val == "true")
			"tags":
				bg.tags = _split_pipe(val)
			"description":
				bg.description = val
			"notes":
				pass  # designer free-text; intentionally ignored
			_:
				push_warning("BackgroundLibrary: unknown column '%s' at row %d" % [col, row_num])
	if bg.background_id == "":
		push_error("BackgroundLibrary: row %d missing id — skipping" % row_num)
		return null
	return bg

static func _split_pipe(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for p in val.split("|", false):  # false = drop empty tokens between pipes
		parts.append(p)
	return parts
