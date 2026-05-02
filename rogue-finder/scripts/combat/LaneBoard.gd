class_name LaneBoard
extends RefCounted

## --- LaneBoard ---
## 3 lanes per side, flat (no front/back depth). Holds CombatantData references
## by (lane_index, side). Lane indices: 0, 1, 2. Sides: "ally" | "enemy".
## Replaces Grid3D's 10x10 cell math with a tiny 6-slot data structure.

const LANE_COUNT: int = 3
const SIDES: PackedStringArray = ["ally", "enemy"]

## { side: Array of size LANE_COUNT, null = empty }
var _slots: Dictionary = {}

func _init() -> void:
	for side: String in SIDES:
		var arr: Array = []
		arr.resize(LANE_COUNT)
		for i in LANE_COUNT:
			arr[i] = null
		_slots[side] = arr

func place(unit: CombatantData, lane: int, side: String) -> void:
	assert(lane >= 0 and lane < LANE_COUNT, "lane out of range: %d" % lane)
	assert(_slots.has(side), "unknown side: %s" % side)
	(_slots[side] as Array)[lane] = unit

func remove(lane: int, side: String) -> void:
	assert(lane >= 0 and lane < LANE_COUNT)
	(_slots[side] as Array)[lane] = null

func get_unit(lane: int, side: String) -> CombatantData:
	if lane < 0 or lane >= LANE_COUNT:
		return null
	return (_slots[side] as Array)[lane]

func get_opposite_side(side: String) -> String:
	return "enemy" if side == "ally" else "ally"

## Returns the unit directly across from `unit`, or null.
func get_opposite(unit: CombatantData) -> CombatantData:
	for side: String in SIDES:
		for lane in LANE_COUNT:
			if (_slots[side] as Array)[lane] == unit:
				return get_unit(lane, get_opposite_side(side))
	return null

## Returns the lane index of `unit`, or -1.
func get_lane_of(unit: CombatantData) -> int:
	for side: String in SIDES:
		for lane in LANE_COUNT:
			if (_slots[side] as Array)[lane] == unit:
				return lane
	return -1

## Returns the side of `unit`, or "" if not on the board.
func get_side_of(unit: CombatantData) -> String:
	for side: String in SIDES:
		for lane in LANE_COUNT:
			if (_slots[side] as Array)[lane] == unit:
				return side
	return ""

## Returns up to 2 units in lanes adjacent to `lane` on the given `side`.
func get_adjacent_lane_units(lane: int, side: String) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for offset: int in [-1, 1]:
		var l: int = lane + offset
		if l >= 0 and l < LANE_COUNT:
			var u := get_unit(l, side)
			if u != null:
				result.append(u)
	return result

## Returns every non-null unit on the given side.
func get_all_on_side(side: String) -> Array[CombatantData]:
	var result: Array[CombatantData] = []
	for lane in LANE_COUNT:
		var u := get_unit(lane, side)
		if u != null:
			result.append(u)
	return result

## Returns true if no living units remain on the given side.
func is_side_wiped(side: String) -> bool:
	for lane in LANE_COUNT:
		var u := get_unit(lane, side)
		if u != null and u.current_hp > 0:
			return false
	return true
