class_name AutobattlerEnemyAI
extends RefCounted

## --- AutobattlerEnemyAI ---
## Static module — picks an off-cooldown ability for a unit's turn based on role priority.
## No instance state. Called once per unit turn from CombatManagerAuto._fire_unit_turn.

## Role preference: ordered list of EffectType values per archetype role.
const ROLE_PREFS: Dictionary = {
	ArchetypeData.Role.ATTACKER:  [EffectData.EffectType.HARM, EffectData.EffectType.DEBUFF, EffectData.EffectType.BUFF, EffectData.EffectType.MEND],
	ArchetypeData.Role.HEALER:    [EffectData.EffectType.MEND, EffectData.EffectType.BUFF, EffectData.EffectType.HARM, EffectData.EffectType.DEBUFF],
	ArchetypeData.Role.SUPPORTER: [EffectData.EffectType.BUFF, EffectData.EffectType.DEBUFF, EffectData.EffectType.MEND, EffectData.EffectType.HARM],
	ArchetypeData.Role.DEBUFFER:  [EffectData.EffectType.DEBUFF, EffectData.EffectType.HARM, EffectData.EffectType.BUFF, EffectData.EffectType.MEND],
	ArchetypeData.Role.CONTROLLER:[EffectData.EffectType.DEBUFF, EffectData.EffectType.HARM, EffectData.EffectType.BUFF, EffectData.EffectType.MEND],
}

const DEFAULT_PREFS: Array = [EffectData.EffectType.HARM, EffectData.EffectType.DEBUFF, EffectData.EffectType.BUFF, EffectData.EffectType.MEND]

## Returns {ability: AbilityData, targets: Array[CombatantData], slot: int}.
## ability is null if no valid off-cooldown pick exists (turn skipped).
static func pick(unit: CombatantData, _allies: Array, _hostiles: Array, board: LaneBoard) -> Dictionary:
	var prefs := _get_role_prefs(unit)
	var available := CountdownTracker.available_slot_indices(unit.cooldowns)
	for effect_type: EffectData.EffectType in prefs:
		for slot: int in available:
			var ability_id: String = unit.abilities[slot] if unit.abilities.size() > slot else ""
			if ability_id == "":
				continue
			var ability := AbilityLibrary.get_ability(ability_id)
			if not _has_effect_type(ability, effect_type):
				continue
			var targets := CombatManagerAuto.resolve_targets(unit, ability, board)
			if not targets.is_empty():
				return {"ability": ability, "targets": targets, "slot": slot}
	return {"ability": null, "targets": [], "slot": -1}

static func _get_role_prefs(unit: CombatantData) -> Array:
	var aid := unit.archetype_id
	if aid == "" or aid == "generic":
		return DEFAULT_PREFS
	var arch: ArchetypeData = ArchetypeLibrary.get_archetype(aid)
	if arch == null:
		return DEFAULT_PREFS
	return ROLE_PREFS.get(arch.role, DEFAULT_PREFS)

static func _has_effect_type(ability: AbilityData, et: EffectData.EffectType) -> bool:
	for effect: EffectData in ability.effects:
		if effect.effect_type == et:
			return true
	return false
