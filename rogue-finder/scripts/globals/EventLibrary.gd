class_name EventLibrary
extends RefCounted

## --- EventLibrary ---
## Static catalog of non-combat events. Loads from two CSVs (events.csv +
## event_choices.csv) and joins them by event_id. Choices are sorted by order
## and attached to their parent EventData after both files are parsed.
##
## get_event() never returns null — unknown ids get a stub so callers stay
## null-guard-free (same contract as every other *Library in this codebase).

const EVENTS_CSV  := "res://data/events.csv"
const CHOICES_CSV := "res://data/event_choices.csv"

static var _cache: Dictionary = {}

## Returns a populated EventData for the given id. Never returns null.
static func get_event(id: String) -> EventData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	var stub := EventData.new()
	stub.id    = id
	stub.title = "Unknown"
	stub.body  = "Unknown event."
	return stub

## Returns every loaded event.
static func all_events() -> Array[EventData]:
	_ensure_loaded()
	var result: Array[EventData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

## Returns events whose ring_eligibility list contains the given ring string.
static func all_events_for_ring(ring: String) -> Array[EventData]:
	var result: Array[EventData] = []
	for ev in all_events():
		if ev.ring_eligibility.has(ring):
			result.append(ev)
	return result

## Clears and re-parses both CSVs. Useful for tests and hot-reload in editor.
static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## --- Internal ---

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	_parse_events()
	_parse_choices()

static func _parse_events() -> void:
	var file := FileAccess.open(EVENTS_CSV, FileAccess.READ)
	if file == null:
		push_error("EventLibrary: could not open %s (err %d)" % [EVENTS_CSV, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("EventLibrary: %s has no header row" % EVENTS_CSV)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("EventLibrary: events row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var ev := _row_to_event(header, row, row_num)
		if ev != null:
			_cache[ev.id] = ev

static func _parse_choices() -> void:
	var file := FileAccess.open(CHOICES_CSV, FileAccess.READ)
	if file == null:
		push_error("EventLibrary: could not open %s (err %d)" % [CHOICES_CSV, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("EventLibrary: %s has no header row" % CHOICES_CSV)
		return
	# Gather all choice entries first, then group + sort + attach.
	var pending: Array = []
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("EventLibrary: choices row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var entry := _row_to_choice_entry(header, row, row_num)
		if not entry.is_empty():
			pending.append(entry)
	# Group by event_id.
	var by_event: Dictionary = {}
	for entry in pending:
		var eid: String = entry["event_id"]
		if not by_event.has(eid):
			by_event[eid] = []
		by_event[eid].append(entry)
	# Sort by order and attach to parent event.
	for eid in by_event.keys():
		if not _cache.has(eid):
			push_warning("EventLibrary: choices reference unknown event_id '%s' — skipping" % eid)
			continue
		var entries: Array = by_event[eid]
		entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["order"] < b["order"])
		for entry in entries:
			_cache[eid].choices.append(entry["choice"])

static func _row_to_event(header: PackedStringArray, row: PackedStringArray, row_num: int) -> EventData:
	var ev := EventData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				ev.id = val
			"title":
				ev.title = val
			"body":
				ev.body = val
			"ring_eligibility":
				ev.ring_eligibility = _split_pipe(val)
			_:
				push_warning("EventLibrary: unknown events column '%s' at row %d" % [col, row_num])
	if ev.id == "":
		push_error("EventLibrary: events row %d missing id — skipping" % row_num)
		return null
	return ev

## Returns {event_id, order, choice} dict, or empty dict on parse failure.
static func _row_to_choice_entry(header: PackedStringArray, row: PackedStringArray, row_num: int) -> Dictionary:
	var event_id := ""
	var order    := 0
	var choice   := EventChoiceData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"event_id":
				event_id = val
			"order":
				if val.is_valid_int():
					order = val.to_int()
				else:
					push_warning("EventLibrary: choices row %d 'order' is not an int ('%s')" % [row_num, val])
			"label":
				choice.label = val
			"conditions":
				choice.conditions = _split_pipe(val)
			"effects":
				choice.effects = _parse_effects(val, row_num)
			"result_text":
				choice.result_text = val
			_:
				push_warning("EventLibrary: unknown choices column '%s' at row %d" % [col, row_num])
	if event_id == "":
		push_error("EventLibrary: choices row %d missing event_id — skipping" % row_num)
		return {}
	return {"event_id": event_id, "order": order, "choice": choice}

static func _parse_effects(val: String, row_num: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if val == "" or val == "[]":
		return result
	var parsed: Variant = JSON.parse_string(val)
	if parsed == null:
		push_warning("EventLibrary: choices row %d effects JSON parse failed: '%s'" % [row_num, val])
		return result
	if not parsed is Array:
		push_warning("EventLibrary: choices row %d effects is not a JSON array" % row_num)
		return result
	for item in parsed:
		if item is Dictionary:
			result.append(item)
	return result

static func _split_pipe(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for p in val.split("|", false):
		parts.append(p)
	return parts
