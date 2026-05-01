class_name EnemyAI
extends RefCounted

## --- EnemyAI ---
## Static module — no instance state. Mirrors the RewardGenerator pattern.
##
## Decides which target + ability an enemy uses each turn, guided by the enemy's Role.
##
## Decision flow (in order):
##   1. ai_override seam — "force_random" bypasses the role walk (future Confused condition)
##   2. Critical-heal override — any affordable MEND on any ally below 15% HP in range
##   3. Role preference walk — effect-type buckets in priority order per role
##   4. Final fallback — {null, null} (caller skips the action)
##
## Primary effect type convention: ability.effects[0].effect_type (first effect wins).
## This bucketing rule is the single authoritative decision point. Slice 3 may add
## scoring within each bucket but must not change which bucket an ability belongs to.

## Role preference tables.
## Keys: ArchetypeData.Role int values (ATTACKER=0, HEALER=1, SUPPORTER=2, DEBUFFER=3, CONTROLLER=4).
## Values: ordered EffectData.EffectType int arrays (HARM=0, MEND=1, FORCE=2, TRAVEL=3, BUFF=4, DEBUFF=5).
const ROLE_PREFERENCES: Dictionary = {
	0: [0, 2, 5, 4, 1, 3],  # ATTACKER:   HARM → FORCE → DEBUFF → BUFF → MEND → TRAVEL
	1: [1, 4, 5, 0, 2, 3],  # HEALER:     MEND → BUFF → DEBUFF → HARM → FORCE → TRAVEL
	2: [4, 1, 5, 0, 2, 3],  # SUPPORTER:  BUFF → MEND → DEBUFF → HARM → FORCE → TRAVEL
	3: [5, 0, 2, 4, 1, 3],  # DEBUFFER:   DEBUFF → HARM → FORCE → BUFF → MEND → TRAVEL
	4: [2, 5, 0, 4, 1, 3],  # CONTROLLER: FORCE → DEBUFF → HARM → BUFF → MEND → TRAVEL
}

## Ally HP fraction below which the critical-heal override fires (any enemy HP < 15%).
const CRIT_HEAL_THRESHOLD: float  = 0.15
## Ally HP fraction below which MEND is considered situationally useful (any ally HP < 70%).
const MEND_USEFUL_THRESHOLD: float = 0.70

## ======================================================
## --- Public API ---
## ======================================================

## Choose a target + ability for the given enemy this turn.
## Returns {"target": Unit3D, "ability": AbilityData} on success.
## Returns {"target": null, "ability": null} when no valid action exists — caller must skip.
## allies  = living enemy-side units excluding this enemy.
## hostiles = living player-side units.
## grid parameter is reserved for Slice 3 path-awareness; unused here.
static func choose_action(
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D],
		_grid: Grid3D) -> Dictionary:

	# --- 1. ai_override seam ---
	# Dormant until the Confused status condition sets this to "force_random".
	if enemy.ai_override == "force_random":
		return _pick_random(enemy, allies, hostiles)

	# --- 2. Critical-heal global override ---
	# Any affordable MEND that can reach an ally (or self) below 15% HP takes priority
	# over the role walk — a dying teammate always beats role preference.
	var crit: Dictionary = _try_critical_heal(enemy, allies)
	if crit.get("ability") != null:
		return crit

	# --- 3. Role preference walk ---
	var archetype: ArchetypeData = ArchetypeLibrary.get_archetype(enemy.data.archetype_id)
	var role: int = int(archetype.role)
	var pref: Array = ROLE_PREFERENCES.get(role, ROLE_PREFERENCES[0])

	for effect_type: int in pref:
		var result: Dictionary = _try_effect_type(enemy, allies, hostiles, effect_type)
		if result.get("ability") != null:
			return result

	# --- 4. Final fallback — caller skips action ---
	return {"target": null, "ability": null}

## ======================================================
## --- Private: Decision helpers ---
## ======================================================

## Walks the enemy's ability slots looking for an affordable ability with the given
## primary effect type that passes the situational filter. Returns the first valid
## {target, ability} pair. Returns {null, null} if no candidate qualifies.
##
## Two-pass within each bucket: abilities NOT matching last_ability_id are tried first;
## last-used ability is the fallback. This prevents turn-to-turn spam when alternatives
## exist. Slice 3 replaces this with full scoring.
static func _try_effect_type(
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D],
		effect_type: int) -> Dictionary:
	# Collect bucket candidates, separating last-used from fresh options.
	var fresh: Array[AbilityData] = []
	var last_used: Array[AbilityData] = []
	for ability_id: String in enemy.data.abilities:
		if ability_id == "":
			continue
		var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
		if ab.effects.is_empty():
			continue
		# Primary effect type = effects[0].effect_type — bucketing rule; see class comment.
		if int(ab.effects[0].effect_type) != effect_type:
			continue
		if enemy.current_energy < ab.energy_cost:
			continue
		if ability_id == enemy.last_ability_id:
			last_used.append(ab)
		else:
			fresh.append(ab)
	# Try fresh options first, fall back to last-used only if nothing else works.
	for ab: AbilityData in fresh + last_used:
		if not _is_situationally_useful(ab, enemy, allies, hostiles):
			continue
		var target: Unit3D = _pick_target(ab, enemy, allies, hostiles)
		if target == null:
			continue
		return {"target": target, "ability": ab}
	return {"target": null, "ability": null}

## Critical-heal override: find the lowest-HP ally (or self) below CRIT_HEAL_THRESHOLD
## that any affordable MEND ability can reach. Returns first qualifying MEND + target.
static func _try_critical_heal(enemy: Unit3D, allies: Array[Unit3D]) -> Dictionary:
	for ability_id: String in enemy.data.abilities:
		if ability_id == "":
			continue
		var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
		if ab.effects.is_empty():
			continue
		if int(ab.effects[0].effect_type) != 1:  # must be MEND
			continue
		if enemy.current_energy < ab.energy_cost:
			continue
		# ENEMY-only non-SELF ability cannot heal allies — skip it
		if ab.applicable_to == AbilityData.ApplicableTo.ENEMY and \
				ab.target_shape != AbilityData.TargetShape.SELF:
			continue

		var candidates: Array[Unit3D] = []

		if ab.target_shape == AbilityData.TargetShape.SELF:
			# SELF shape can only heal the caster
			var hp_pct: float = float(enemy.current_hp) / float(enemy.data.hp_max)
			if hp_pct < CRIT_HEAL_THRESHOLD:
				candidates.append(enemy)
		else:
			# Check allied units (other enemies)
			if ab.applicable_to != AbilityData.ApplicableTo.ENEMY:
				for ally: Unit3D in allies:
					if not ally.is_alive:
						continue
					var hp_pct: float = float(ally.current_hp) / float(ally.data.hp_max)
					if hp_pct < CRIT_HEAL_THRESHOLD and \
							_is_in_range(ab, enemy.grid_pos, ally.grid_pos):
						candidates.append(ally)
			# Include self for ANY-applicable abilities ("including self" per spec)
			if ab.applicable_to == AbilityData.ApplicableTo.ANY:
				var self_pct: float = float(enemy.current_hp) / float(enemy.data.hp_max)
				if self_pct < CRIT_HEAL_THRESHOLD:
					candidates.append(enemy)

		if candidates.is_empty():
			continue

		# Lowest HP first; randi() tiebreak acceptable for Slice 2
		candidates.sort_custom(func(a: Unit3D, b: Unit3D) -> bool:
			return a.current_hp < b.current_hp)
		return {"target": candidates[0], "ability": ab}

	return {"target": null, "ability": null}

## ======================================================
## --- Private: Situational filters ---
## ======================================================

## Minimum-viable situational filter per effect type.
## Each check confirms the ability has at least one meaningful target before committing.
## Slice 3 will sharpen these into proper scoring (redundancy detection, health thresholds).
static func _is_situationally_useful(
		ability: AbilityData,
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D]) -> bool:
	# Primary effect type = effects[0].effect_type — bucketing rule
	var etype: int = int(ability.effects[0].effect_type)
	match etype:
		0:  # HARM — at least one reachable hostile
			for hostile: Unit3D in hostiles:
				if hostile.is_alive and _is_in_range(ability, enemy.grid_pos, hostile.grid_pos):
					return true
			return false
		1:  # MEND — at least one ally (or self) below MEND_USEFUL_THRESHOLD in range
			if ability.target_shape == AbilityData.TargetShape.SELF:
				return float(enemy.current_hp) / float(enemy.data.hp_max) < MEND_USEFUL_THRESHOLD
			for ally: Unit3D in allies:
				if not ally.is_alive:
					continue
				var hp_pct: float = float(ally.current_hp) / float(ally.data.hp_max)
				if hp_pct < MEND_USEFUL_THRESHOLD and \
						_is_in_range(ability, enemy.grid_pos, ally.grid_pos):
					return true
			# Self qualifies too for non-SELF-shape abilities
			return float(enemy.current_hp) / float(enemy.data.hp_max) < MEND_USEFUL_THRESHOLD
		2:  # FORCE — at least one reachable hostile
			for hostile: Unit3D in hostiles:
				if hostile.is_alive and _is_in_range(ability, enemy.grid_pos, hostile.grid_pos):
					return true
			return false
		3:  # TRAVEL — always usable (last resort in every preference list)
			return true
		4:  # BUFF — at least one ally in range (redundancy detection lands in Slice 3)
			if ability.target_shape == AbilityData.TargetShape.SELF:
				return true
			for ally: Unit3D in allies:
				if ally.is_alive and _is_in_range(ability, enemy.grid_pos, ally.grid_pos):
					return true
			return false
		5:  # DEBUFF — at least one reachable hostile
			for hostile: Unit3D in hostiles:
				if hostile.is_alive and _is_in_range(ability, enemy.grid_pos, hostile.grid_pos):
					return true
			return false
	return false

## ======================================================
## --- Private: Target selection ---
## ======================================================

## Picks the first valid target for an ability based on applicable_to.
## For ANY applicable_to, uses effect type as a tiebreak (attack effects → hostiles first).
## For AoE shapes the returned target is not used by the executor (_pick_best_aoe_origin
## handles that), but must be non-null to prevent the action from being skipped.
static func _pick_target(
		ability: AbilityData,
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D]) -> Unit3D:
	if ability.target_shape == AbilityData.TargetShape.SELF:
		return enemy
	match ability.applicable_to:
		AbilityData.ApplicableTo.ENEMY:
			for hostile: Unit3D in hostiles:
				if hostile.is_alive and _is_in_range(ability, enemy.grid_pos, hostile.grid_pos):
					return hostile
		AbilityData.ApplicableTo.ALLY:
			for ally: Unit3D in allies:
				if ally.is_alive and _is_in_range(ability, enemy.grid_pos, ally.grid_pos):
					return ally
		AbilityData.ApplicableTo.ANY:
			# Offensive effects (HARM/FORCE/DEBUFF) prefer hostiles; restorative prefer allies
			var etype: int = int(ability.effects[0].effect_type)
			if etype == 0 or etype == 2 or etype == 5:  # HARM, FORCE, DEBUFF
				for hostile: Unit3D in hostiles:
					if hostile.is_alive and _is_in_range(ability, enemy.grid_pos, hostile.grid_pos):
						return hostile
				for ally: Unit3D in allies:
					if ally.is_alive and _is_in_range(ability, enemy.grid_pos, ally.grid_pos):
						return ally
			else:  # MEND, BUFF, TRAVEL
				for ally: Unit3D in allies:
					if ally.is_alive and _is_in_range(ability, enemy.grid_pos, ally.grid_pos):
						return ally
				return enemy  # self always reachable as last resort
	return null

## ======================================================
## --- Private: Range check ---
## ======================================================

## True if the caster can reach target_pos with this ability.
## Uses Manhattan distance — mirrors the pre-existing distance gate in _process_enemy_actions.
## tile_range == -1 means whole-map. SELF shape always passes.
static func _is_in_range(
		ability: AbilityData, caster_pos: Vector2i, target_pos: Vector2i) -> bool:
	if ability.target_shape == AbilityData.TargetShape.SELF:
		return true
	if ability.tile_range == -1:
		return true
	var manhattan: int = abs(caster_pos.x - target_pos.x) + abs(caster_pos.y - target_pos.y)
	return manhattan <= ability.tile_range

## ======================================================
## --- Private: Force-random fallback ---
## ======================================================

## Picks any affordable, in-range ability and a valid target at random.
## Used when ai_override == "force_random" (future Confused condition).
static func _pick_random(
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D]) -> Dictionary:
	var affordable: Array[AbilityData] = []
	var all_units: Array[Unit3D] = []
	all_units.assign(allies)
	for hostile: Unit3D in hostiles:
		all_units.append(hostile)

	for ability_id: String in enemy.data.abilities:
		if ability_id == "":
			continue
		var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
		if ab.effects.is_empty():
			continue
		if enemy.current_energy < ab.energy_cost:
			continue
		if ab.target_shape == AbilityData.TargetShape.SELF:
			affordable.append(ab)
			continue
		for unit: Unit3D in all_units:
			if unit.is_alive and _is_in_range(ab, enemy.grid_pos, unit.grid_pos):
				affordable.append(ab)
				break

	if affordable.is_empty():
		return {"target": null, "ability": null}

	var chosen: AbilityData = affordable[randi() % affordable.size()]
	var target: Unit3D = _pick_target(chosen, enemy, allies, hostiles)
	return {"target": target, "ability": chosen}
