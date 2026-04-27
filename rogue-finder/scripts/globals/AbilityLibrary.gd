class_name AbilityLibrary
extends RefCounted

## --- AbilityLibrary ---
## CSV-native ability catalog. Migrated from inline const dict in S35
## (data-library uniformity pass session 6).
## Data source: res://data/abilities.csv (22 rows).
## get_ability() signature preserved unchanged.

const CSV_PATH := "res://data/abilities.csv"

## Lazily populated on first access. Keyed by ability_id.
static var _cache: Dictionary = {}

## Cached icon — loaded once on first populate.
static var _icon: Texture2D = null

## --- Enum name → value lookup tables ---
## Keyed by the string stored in each CSV cell; returns the enum int.
const _ATTRIBUTE: Dictionary = {
	"STRENGTH":           AbilityData.Attribute.STRENGTH,
	"DEXTERITY":          AbilityData.Attribute.DEXTERITY,
	"COGNITION":          AbilityData.Attribute.COGNITION,
	"VITALITY":           AbilityData.Attribute.VITALITY,
	"WILLPOWER":          AbilityData.Attribute.WILLPOWER,
	"NONE":               AbilityData.Attribute.NONE,
	"PHYSICAL_ARMOR_MOD": AbilityData.Attribute.PHYSICAL_ARMOR_MOD,
	"MAGIC_ARMOR_MOD":    AbilityData.Attribute.MAGIC_ARMOR_MOD,
}
const _TARGET_SHAPE: Dictionary = {
	"SELF":   AbilityData.TargetShape.SELF,
	"SINGLE": AbilityData.TargetShape.SINGLE,
	"CONE":   AbilityData.TargetShape.CONE,
	"LINE":   AbilityData.TargetShape.LINE,
	"RADIAL": AbilityData.TargetShape.RADIAL,
	"ARC":    AbilityData.TargetShape.ARC,
}
const _APPLICABLE_TO: Dictionary = {
	"ALLY":  AbilityData.ApplicableTo.ALLY,
	"ENEMY": AbilityData.ApplicableTo.ENEMY,
	"ANY":   AbilityData.ApplicableTo.ANY,
}
const _EFFECT_TYPE: Dictionary = {
	"HARM":   EffectData.EffectType.HARM,
	"MEND":   EffectData.EffectType.MEND,
	"FORCE":  EffectData.EffectType.FORCE,
	"TRAVEL": EffectData.EffectType.TRAVEL,
	"BUFF":   EffectData.EffectType.BUFF,
	"DEBUFF": EffectData.EffectType.DEBUFF,
}
const _POOL_TYPE: Dictionary = {
	"HP":     EffectData.PoolType.HP,
	"ENERGY": EffectData.PoolType.ENERGY,
}
const _MOVE_TYPE: Dictionary = {
	"FREE": EffectData.MoveType.FREE,
	"LINE": EffectData.MoveType.LINE,
}
const _FORCE_TYPE: Dictionary = {
	"PUSH":   EffectData.ForceType.PUSH,
	"PULL":   EffectData.ForceType.PULL,
	"LEFT":   EffectData.ForceType.LEFT,
	"RIGHT":  EffectData.ForceType.RIGHT,
	"RADIAL": EffectData.ForceType.RADIAL,
}
const _DAMAGE_TYPE: Dictionary = {
	"PHYSICAL": AbilityData.DamageType.PHYSICAL,
	"MAGIC":    AbilityData.DamageType.MAGIC,
	"NONE":     AbilityData.DamageType.NONE,
}

## ======================================================
## Public API
## ======================================================

## Returns a populated AbilityData for the given ID.
## Never returns null — falls back to a blank stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData:
	_ensure_loaded()
	if _cache.has(ability_id):
		return _cache[ability_id]
	var stub := AbilityData.new()
	stub.ability_id   = "unknown"
	stub.ability_name = "Unknown"
	stub.description  = "No ability data found for ID: " + ability_id
	stub.ability_icon = _get_icon()
	return stub

## Returns every loaded ability. Use for validation, UI lists, etc.
static func all_abilities() -> Array[AbilityData]:
	_ensure_loaded()
	var result: Array[AbilityData] = []
	for key in _cache.keys():
		result.append(_cache[key])
	return result

## Force reload from disk — for tests and dev-time CSV edits.
static func reload() -> void:
	_cache.clear()
	_ensure_loaded()

## --- Internal ---

static func _get_icon() -> Texture2D:
	if _icon == null:
		_icon = load("res://icon.svg")
	return _icon

static func _ensure_loaded() -> void:
	if not _cache.is_empty():
		return
	var icon: Texture2D = _get_icon()
	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		push_error("AbilityLibrary: could not open %s (err %d)" % [CSV_PATH, FileAccess.get_open_error()])
		return
	var header := file.get_csv_line(",")
	if header.size() == 0 or header[0] == "":
		push_error("AbilityLibrary: %s has no header row" % CSV_PATH)
		return
	var row_num := 1
	while not file.eof_reached():
		var row := file.get_csv_line(",")
		row_num += 1
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != header.size():
			push_error("AbilityLibrary: row %d has %d cells, header has %d — skipping" % [row_num, row.size(), header.size()])
			continue
		var ability := _row_to_data(header, row, row_num, icon)
		if ability != null:
			_cache[ability.ability_id] = ability

static func _row_to_data(header: PackedStringArray, row: PackedStringArray,
		row_num: int, icon: Texture2D) -> AbilityData:
	var a := AbilityData.new()
	for i in header.size():
		var col := header[i]
		var val := row[i]
		match col:
			"id":
				a.ability_id = val
			"name":
				a.ability_name = val
			"attribute":
				a.attribute = _ATTRIBUTE.get(val, AbilityData.Attribute.NONE)
			"target":
				a.target_shape = _TARGET_SHAPE.get(val, AbilityData.TargetShape.SINGLE)
			"applicable_to":
				a.applicable_to = _APPLICABLE_TO.get(val, AbilityData.ApplicableTo.ENEMY)
			"range":
				a.tile_range = int(val)
			"passthrough":
				a.passthrough = (val == "true")
			"cost":
				a.energy_cost = int(val)
			"description":
				a.description = val
			"effects":
				a.effects = _parse_effects(val, row_num)
			"damage_type":
				a.damage_type = _DAMAGE_TYPE.get(val, AbilityData.DamageType.NONE)
			"notes":
				pass  # designer free-text; intentionally ignored
			_:
				push_warning("AbilityLibrary: unknown column '%s' at row %d" % [col, row_num])
	if a.ability_id == "":
		push_error("AbilityLibrary: row %d missing id — skipping" % row_num)
		return null
	a.ability_icon = icon
	return a

static func _parse_effects(effects_str: String, row_num: int) -> Array[EffectData]:
	if effects_str == "":
		return []
	var parsed: Variant = JSON.parse_string(effects_str)
	if not (parsed is Array):
		push_error("AbilityLibrary: row %d — invalid effects JSON: %s" % [row_num, effects_str])
		return []
	var result: Array[EffectData] = []
	for item: Variant in (parsed as Array):
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var e := EffectData.new()
		e.effect_type = _EFFECT_TYPE.get(d.get("type", "HARM"), EffectData.EffectType.HARM)
		e.base_value  = int(d.get("base_value", 0))
		if d.has("pool"):
			e.target_pool = _POOL_TYPE.get(d.get("pool", "HP"), EffectData.PoolType.HP)
		if d.has("stat"):
			e.target_stat = _ATTRIBUTE.get(d.get("stat", "NONE"), AbilityData.Attribute.NONE)
		if d.has("move"):
			e.movement_type = _MOVE_TYPE.get(d.get("move", "FREE"), EffectData.MoveType.FREE)
		if d.has("force"):
			e.force_type = _FORCE_TYPE.get(d.get("force", "PUSH"), EffectData.ForceType.PUSH)
		result.append(e)
	return result
