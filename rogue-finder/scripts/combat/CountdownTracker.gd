class_name CountdownTracker
extends RefCounted

## --- CountdownTracker ---
## Static module — pure logic for unit countdowns and per-ability cooldowns.
## CombatManagerAuto calls these helpers each tick. No instance state.

## Returns countdown_max derived from a unit's effective SPD.
## Formula: clamp(8 - spd, 2, 12)
static func compute_countdown_max(spd: int) -> int:
	return clamp(8 - spd, 2, 12)

## Decrements countdown_current on every unit by 1 (floor 0).
static func tick(units: Array[CombatantData]) -> void:
	for u: CombatantData in units:
		u.countdown_current = max(0, u.countdown_current - 1)

## Decrements countdown_current and returns units now at 0 (ready to act).
static func tick_and_collect_ready(units: Array[CombatantData]) -> Array[CombatantData]:
	tick(units)
	var ready: Array[CombatantData] = []
	for u: CombatantData in units:
		if u.countdown_current == 0:
			ready.append(u)
	return ready

## Decrements every per-ability cooldown counter by 1 (floor 0).
static func tick_cooldowns(cooldowns: Array[int]) -> void:
	for i in cooldowns.size():
		cooldowns[i] = max(0, cooldowns[i] - 1)

## Returns the indices of slots whose cooldown is 0 (available to fire).
static func available_slot_indices(cooldowns: Array[int]) -> Array[int]:
	var result: Array[int] = []
	for i in cooldowns.size():
		if cooldowns[i] == 0:
			result.append(i)
	return result

## Returns a copy of ready sorted by descending SPD (tiebreak rule).
static func tiebreak_ready(ready: Array[CombatantData]) -> Array[CombatantData]:
	var sorted: Array[CombatantData] = []
	for u: CombatantData in ready:
		sorted.append(u)
	sorted.sort_custom(func(a: CombatantData, b: CombatantData) -> bool:
		return a.spd > b.spd
	)
	return sorted

## Resets a unit's countdown after it acts.
static func reset_countdown(unit: CombatantData) -> void:
	unit.countdown_current = unit.countdown_max
