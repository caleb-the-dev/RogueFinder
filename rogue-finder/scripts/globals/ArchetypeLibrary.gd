class_name ArchetypeLibrary
extends RefCounted

## --- ArchetypeLibrary ---
## CSV-native archetype catalog + CombatantData factory.
## Data source: res://data/archetypes.csv (single source of truth).
## Migrated from inline const dict in S34 (data-library uniformity pass session 5).
## Public API — create() signature — preserved unchanged.

const CSV_PATH := "res://data/archetypes.csv"

## Lazily populated on first access. Keyed by archetype_id.
static var _cache: Dictionary = {}

## Flavor names live on the kindred (see KindredLibrary.get_name_pool) — archetypes
## no longer carry their own pool. Enemies stay unnamed; player allies draw from
## their kindred's pool when no explicit name is supplied.

## ======================================================
## Public API
## ======================================================

## Returns ArchetypeData for the given id. Never returns null; falls back to grunt
## for unknown ids (preserves existing caller behavior).
static func get_archetype(id: String) -> ArchetypeData:
	_ensure_loaded()
	if _cache.has(id):
		return _cache[id]
	if _cache.has("grunt"):
		return _cache["grunt"]
	var stub := ArchetypeData.new()
	stub.archetype_id = id
	return stub

## Returns every loaded archetype. Replaces ARCHETYPES.keys() iteration in callers.
static func all_archetypes() -> Array[ArchetypeData]:
	_ensure_loaded()
	var result: Array[ArchetypeData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

## Force reload from disk — for tests and dev-time CSV edits.
static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## Creates a fully randomized CombatantData for the given archetype.
##
## archetype_id  — key in archetypes.csv; falls back to grunt definition if unknown.
## character_name — optional override; empty → auto-name for players, empty for enemies.
## is_player     — sets is_player_unit on the result.
static func create(archetype_id: String, character_name: String = "",
		is_player: bool = false) -> CombatantData:
	var src: ArchetypeData = get_archetype(archetype_id)
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var data := CombatantData.new()
	data.archetype_id   = archetype_id
	data.is_player_unit = is_player
	data.unit_class     = src.unit_class
	data.kindred        = src.kindred
	data.feat_ids       = []  # enemies start with no feats; kindred bonuses are structural
	data.artwork_idle   = src.artwork_idle
	data.artwork_attack = src.artwork_attack

	# Active slots: exactly 4 entries, empty string = unfilled
	data.abilities.clear()
	for ab in src.abilities:
		data.abilities.append(str(ab))
	while data.abilities.size() < 4:
		data.abilities.append("")

	# ability_pool: superset of active slots. Future leveling appends here without
	# touching the 4-slot active list. Skip empty strings — pool holds real IDs only.
	data.ability_pool.clear()
	for ab in src.abilities:
		if ab != "":
			data.ability_pool.append(str(ab))
	for ab in src.pool_extras:
		var ab_str: String = str(ab)
		if ab_str != "" and not data.ability_pool.has(ab_str):
			data.ability_pool.append(ab_str)

	data.consumable = src.consumable

	var bgs: Array[String] = src.backgrounds
	data.background = bgs[rng.randi_range(0, bgs.size() - 1)] if not bgs.is_empty() else ""

	data.strength  = rng.randi_range(src.str_range[0],   src.str_range[1])
	data.dexterity = rng.randi_range(src.dex_range[0],   src.dex_range[1])
	data.cognition = rng.randi_range(src.cog_range[0],   src.cog_range[1])
	data.willpower = rng.randi_range(src.wil_range[0],   src.wil_range[1])
	data.vitality  = rng.randi_range(src.vit_range[0],   src.vit_range[1])
	data.vitality  = maxi(1, data.vitality)  # guard: HP = 0 is invalid

	data.physical_armor  = rng.randi_range(src.physical_armor_range[0], src.physical_armor_range[1])
	data.magic_armor     = rng.randi_range(src.magic_armor_range[0],    src.magic_armor_range[1])
	data.qte_resolution  = rng.randf_range(src.qte_range[0],   src.qte_range[1])
	data.temperament_id  = TemperamentLibrary.random_id(rng)

	data.current_hp     = data.hp_max
	data.current_energy = data.energy_max

	if character_name != "":
		data.character_name = character_name
	elif is_player:
		var pool: Array[String] = KindredLibrary.get_name_pool(data.kindred)
		if pool.is_empty():
			data.character_name = "Unit"
		else:
			data.character_name = pool[rng.randi_range(0, pool.size() - 1)]
	else:
		data.character_name = ""

	return data

## --- Internal ---

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("ArchetypeLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("ArchetypeLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("ArchetypeLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var archetype := _row_to_data(header, row, row_num)
		if archetype != null:
			_cache[archetype.archetype_id] = archetype

static func _row_to_data(header: PackedStringArray, row: PackedStringArray, row_num: int) -> ArchetypeData:
	var archetype := ArchetypeData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				archetype.archetype_id = val
			"class":
				archetype.unit_class = val
			"kindred":
				archetype.kindred = val
			"backgrounds":
				archetype.backgrounds = _split_pipe_str(val)
			"abilities":
				archetype.abilities = _split_pipe_str(val)
			"pool_extras":
				archetype.pool_extras = _split_pipe_str(val)
			"consumable":
				archetype.consumable = val
			"str_range":
				archetype.str_range = _split_pipe_int(val)
			"dex_range":
				archetype.dex_range = _split_pipe_int(val)
			"cog_range":
				archetype.cog_range = _split_pipe_int(val)
			"wil_range":
				archetype.wil_range = _split_pipe_int(val)
			"vit_range":
				archetype.vit_range = _split_pipe_int(val)
			"physical_armor_range":
				archetype.physical_armor_range = _split_pipe_int(val)
			"magic_armor_range":
				archetype.magic_armor_range = _split_pipe_int(val)
			"qte_range":
				archetype.qte_range = _split_pipe_float(val)
			"artwork_idle":
				archetype.artwork_idle = val
			"artwork_attack":
				archetype.artwork_attack = val
			"hire_cost":
				archetype.hire_cost = int(val)
			"notes":
				pass  # designer free-text; intentionally ignored
			_:
				push_warning("ArchetypeLibrary: unknown column '%s' at row %d" % [col, row_num])
	if archetype.archetype_id == "":
		push_error("ArchetypeLibrary: row %d missing id — skipping" % row_num)
		return null
	return archetype

static func _split_pipe_str(val: String) -> Array[String]:
	if val == "":
		return []
	var parts: Array[String] = []
	for p in val.split("|", false):
		parts.append(p)
	return parts

static func _split_pipe_int(val: String) -> Array[int]:
	var parts := val.split("|", false)
	if parts.size() < 2:
		return [0, 0]
	var result: Array[int] = []
	result.append(int(parts[0]))
	result.append(int(parts[1]))
	return result

static func _split_pipe_float(val: String) -> Array[float]:
	var parts := val.split("|", false)
	if parts.size() < 2:
		return [0.0, 0.0]
	var result: Array[float] = []
	result.append(float(parts[0]))
	result.append(float(parts[1]))
	return result
