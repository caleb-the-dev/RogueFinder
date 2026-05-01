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
## This bucketing rule is the single authoritative decision point.
##
## Within each bucket (Slice 3), proper scoring replaces the Slice 2 "first valid" walk:
##   HARM:   AoE-2+ → finishing-blow on weakest → best expected damage
##   MEND:   lowest-HP target; closest-fit heal to minimize overheal
##   BUFF:   highest-HP non-redundant ally
##   DEBUFF: highest-HP hostile, skipping redundant/capped targets
##   FORCE:  hazard landing > edge push > isolation; drops if no meaningful push exists
##   TRAVEL: always drops (enemy TRAVEL is undefined; never situationally useful headlessly)

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

## Processing order for _process_enemy_actions — lower = acts first.
## Support roles stride before damage dealers so they reach allies / debuff targets
## before ATTACKER/CONTROLLER movement blocks their paths.
const MOVE_PRIORITY: Dictionary = {
	1: 0,  # HEALER
	2: 1,  # SUPPORTER
	3: 2,  # DEBUFFER
	0: 3,  # ATTACKER
	4: 4,  # CONTROLLER
}

## ======================================================
## --- Public API ---
## ======================================================

## Choose a target + ability for the given enemy this turn.
## Returns {"target": Unit3D, "ability": AbilityData} on success.
## Returns {"target": null, "ability": null} when no valid action exists — caller must skip.
## allies  = living enemy-side units excluding this enemy.
## hostiles = living player-side units.
## grid     = Grid3D instance for AoE origin scoring and FORCE landing checks.
static func choose_action(
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D],
		grid: Grid3D) -> Dictionary:

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
		var result: Dictionary = _try_effect_type(enemy, allies, hostiles, effect_type, grid)
		if result.get("ability") != null:
			return result

	# --- 4. Final fallback — caller skips action ---
	return {"target": null, "ability": null}

## Returns the unit this enemy should stride toward before acting.
## Replaces the random-hostile selection in CombatManager3D._process_enemy_actions().
## HEALER / SUPPORTER: lowest-HP ally below 70% HP if one exists; else nearest hostile.
## All other roles: nearest hostile (Manhattan distance).
static func pick_stride_target(
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D]) -> Unit3D:
	var archetype: ArchetypeData = ArchetypeLibrary.get_archetype(enemy.data.archetype_id)
	var role: int = int(archetype.role)

	if role == 1 or role == 2:  # HEALER or SUPPORTER
		var best_ally: Unit3D = null
		var best_hp: int = 999999
		for ally: Unit3D in allies:
			if not ally.is_alive:
				continue
			var hp_pct: float = float(ally.current_hp) / float(ally.data.hp_max)
			if hp_pct < MEND_USEFUL_THRESHOLD and ally.current_hp < best_hp:
				best_hp = ally.current_hp
				best_ally = ally
		if best_ally != null:
			return best_ally

	# Default: nearest hostile by Manhattan distance
	var nearest: Unit3D = null
	var min_dist: int = 999999
	for h: Unit3D in hostiles:
		if not h.is_alive:
			continue
		var dist: int = abs(enemy.grid_pos.x - h.grid_pos.x) + abs(enemy.grid_pos.y - h.grid_pos.y)
		if dist < min_dist:
			min_dist = dist
			nearest = h
	return nearest

## Picks the AoE origin cell that maximizes living hostile hits (random tiebreak).
## Extracted from CombatManager3D._pick_best_aoe_origin; that method wraps this one.
## Returns caster_pos as a safe fallback when grid is null or no candidates exist.
static func pick_best_aoe_origin(
		caster_pos: Vector2i,
		ability: AbilityData,
		grid: Grid3D) -> Vector2i:
	if grid == null:
		return caster_pos

	var candidates: Array[Vector2i] = []
	match ability.target_shape:
		AbilityData.TargetShape.RADIAL:
			var limit: int = ability.tile_range if ability.tile_range != -1 else 999
			for row in range(Grid3D.ROWS):
				for col in range(Grid3D.COLS):
					var cell := Vector2i(col, row)
					var dist: int = abs(cell.x - caster_pos.x) + abs(cell.y - caster_pos.y)
					if dist <= limit:
						candidates.append(cell)
		_:  # CONE, ARC, LINE — test 4 cardinal roots adjacent to caster
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var cell := caster_pos + dir
				if grid.is_valid(cell):
					candidates.append(cell)

	if candidates.is_empty():
		return caster_pos

	var best: Array[Vector2i] = []
	var best_count: int = -1
	for cand: Vector2i in candidates:
		var count: int = _aoe_hostile_count(caster_pos, cand, ability, grid)
		if count > best_count:
			best_count = count
			best = [cand]
		elif count == best_count:
			best.append(cand)

	return best[randi() % best.size()]

## For CONTROLLER role: picks the stride cell that maximizes FORCE push quality.
## Evaluates both the enemy's current position and every reachable stride cell, then returns
## the cell from which FORCE would score best (hazard > edge > isolation).
## Returns enemy.grid_pos when already optimally placed or no FORCE ability is affordable.
static func pick_force_stride_cell(
		enemy: Unit3D,
		hostiles: Array[Unit3D],
		move_cells: Array[Vector2i],
		grid: Grid3D) -> Vector2i:
	if grid == null or hostiles.is_empty():
		return enemy.grid_pos

	# Collect affordable FORCE abilities with their displacement effect
	var force_entries: Array[Dictionary] = []  # [{ab: AbilityData, eff: EffectData}]
	for ability_id: String in enemy.data.abilities:
		if ability_id == "":
			continue
		var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
		if ab.effects.is_empty() or enemy.current_energy < ab.energy_cost:
			continue
		if int(ab.effects[0].effect_type) != 2:  # primary effect must be FORCE
			continue
		for eff: EffectData in ab.effects:
			if int(eff.effect_type) == 2:
				force_entries.append({"ab": ab, "eff": eff})
				break

	if force_entries.is_empty():
		return enemy.grid_pos

	var best_cell: Vector2i = enemy.grid_pos
	var best_score: int = -1

	# Include current position first — ties go to staying put (no unnecessary movement)
	var candidates: Array[Vector2i] = []
	candidates.append(enemy.grid_pos)
	candidates.append_array(move_cells)

	for cell: Vector2i in candidates:
		for entry: Dictionary in force_entries:
			var ab: AbilityData       = entry["ab"]
			var force_eff: EffectData = entry["eff"]
			for h: Unit3D in hostiles:
				if not h.is_alive:
					continue
				if not _is_in_range(ab, cell, h.grid_pos):
					continue
				var dest: Vector2i = _compute_force_dest(cell, h.grid_pos, force_eff, grid)
				if dest == h.grid_pos:
					continue  # blocked — no movement possible
				var dir: Vector2i = _force_push_dir(cell, h.grid_pos, force_eff)
				var score: int = 0
				if grid.is_hazard(dest):
					score = 3
				elif not grid.is_valid(dest + dir):
					score = 2
				else:
					var isolation_sum: int = 0
					for other: Unit3D in hostiles:
						if other == h or not other.is_alive:
							continue
						isolation_sum += abs(dest.x - other.grid_pos.x) + abs(dest.y - other.grid_pos.y)
					if isolation_sum > 0:
						score = 1
				if score > best_score:
					best_score = score
					best_cell = cell

	return best_cell

## ======================================================
## --- Private: Effect-type scoring dispatch ---
## ======================================================

## Collects affordable abilities of the given effect type and dispatches to the
## appropriate per-type scoring helper. Returns {null, null} on no valid result.
static func _try_effect_type(
		enemy: Unit3D,
		allies: Array[Unit3D],
		hostiles: Array[Unit3D],
		effect_type: int,
		grid: Grid3D) -> Dictionary:
	var candidates: Array[AbilityData] = []
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
		candidates.append(ab)

	if candidates.is_empty():
		return {"target": null, "ability": null}

	match effect_type:
		0:  return _pick_best_harm(enemy, hostiles, candidates, grid)
		1:  return _pick_best_mend(enemy, allies, candidates)
		2:  return _pick_best_force(enemy, hostiles, candidates, grid)
		4:  return _pick_best_buff(enemy, allies, candidates)
		5:  return _pick_best_debuff(enemy, hostiles, candidates)
		# TRAVEL (3): enemy TRAVEL is undefined (destination picker is player-only).
		# Return null so the role walk continues or the turn is skipped.
	return {"target": null, "ability": null}

## ======================================================
## --- Private: Per-type scoring helpers ---
## ======================================================

## HARM scoring — three-tier priority:
##   1. AoE-2+: any AoE ability whose optimal origin hits ≥2 hostiles → prefer AoE (most hits).
##   2. Finishing-blow: lowest-HP reachable hostile → highest expected damage against them.
##   3. Best damage: globally highest expected-damage (hostile, ability) pair.
static func _pick_best_harm(
		enemy: Unit3D,
		hostiles: Array[Unit3D],
		abilities: Array[AbilityData],
		grid: Grid3D) -> Dictionary:

	# --- 1. AoE-2+ ---
	var best_aoe: AbilityData = null
	var best_aoe_count: int = 1  # must exceed 1; start at threshold-1 so count>=2 qualifies
	for ab: AbilityData in abilities:
		match ab.target_shape:
			AbilityData.TargetShape.SINGLE, AbilityData.TargetShape.SELF:
				continue  # not AoE
		if grid == null:
			continue
		var origin: Vector2i = pick_best_aoe_origin(enemy.grid_pos, ab, grid)
		var count: int = _aoe_hostile_count(enemy.grid_pos, origin, ab, grid)
		if count > best_aoe_count:
			best_aoe_count = count
			best_aoe = ab
	if best_aoe != null:
		# AoE origin is recalculated by CombatManager3D; target is a non-null placeholder only.
		var placeholder: Unit3D = hostiles[0] if not hostiles.is_empty() else null
		if placeholder != null:
			return {"target": placeholder, "ability": best_aoe}

	# --- 2. Finishing-blow: focus lowest-HP reachable hostile ---
	var weakest: Unit3D = null
	var weakest_hp: int = 999999
	for h: Unit3D in hostiles:
		if not h.is_alive or h.current_hp >= weakest_hp:
			continue
		for ab: AbilityData in abilities:
			if _is_in_range(ab, enemy.grid_pos, h.grid_pos):
				weakest_hp = h.current_hp
				weakest = h
				break
	if weakest != null:
		var best_ab: AbilityData = null
		var best_dmg: int = -1
		for ab: AbilityData in abilities:
			if not _is_in_range(ab, enemy.grid_pos, weakest.grid_pos):
				continue
			var dmg: int = _expected_damage(ab, enemy, weakest)
			if dmg > best_dmg:
				best_dmg = dmg
				best_ab = ab
		if best_ab != null:
			return {"target": weakest, "ability": best_ab}

	# --- 3. Best damage: globally highest (hostile, ability) pair ---
	var best_target: Unit3D = null
	var best_global_ab: AbilityData = null
	var best_global_dmg: int = -1
	for ab: AbilityData in abilities:
		for h: Unit3D in hostiles:
			if not h.is_alive:
				continue
			if not _is_in_range(ab, enemy.grid_pos, h.grid_pos):
				continue
			var dmg: int = _expected_damage(ab, enemy, h)
			if dmg > best_global_dmg:
				best_global_dmg = dmg
				best_target = h
				best_global_ab = ab
	if best_global_ab != null:
		return {"target": best_target, "ability": best_global_ab}

	return {"target": null, "ability": null}

## MEND scoring:
##   Pick the lowest-HP target (self or ally) below 70% HP.
##   Among in-range abilities, pick the one minimizing abs(heal_value - hp_missing).
##   Tiebreak: cheapest energy cost.
static func _pick_best_mend(
		enemy: Unit3D,
		allies: Array[Unit3D],
		abilities: Array[AbilityData]) -> Dictionary:

	# Collect qualified targets sorted by HP ascending
	var targets: Array[Unit3D] = []
	if float(enemy.current_hp) / float(enemy.data.hp_max) < MEND_USEFUL_THRESHOLD:
		targets.append(enemy)
	for ally: Unit3D in allies:
		if ally.is_alive and float(ally.current_hp) / float(ally.data.hp_max) < MEND_USEFUL_THRESHOLD:
			targets.append(ally)
	if targets.is_empty():
		return {"target": null, "ability": null}

	targets.sort_custom(func(a: Unit3D, b: Unit3D) -> bool: return a.current_hp < b.current_hp)

	for tgt: Unit3D in targets:
		var hp_missing: int = tgt.data.hp_max - tgt.current_hp
		var best_ab: AbilityData = null
		var best_fit: int = 999999
		var best_cost: int = 999999
		for ab: AbilityData in abilities:
			# SELF-shape: only valid on the caster
			if ab.target_shape == AbilityData.TargetShape.SELF:
				if tgt != enemy:
					continue
			else:
				if not _is_in_range(ab, enemy.grid_pos, tgt.grid_pos):
					continue
			# Sum MEND base_values to get heal amount
			var heal_val: int = 0
			for eff: EffectData in ab.effects:
				if int(eff.effect_type) == 1:  # MEND
					heal_val += maxi(1, roundi(float(eff.base_value)))
			var fit: int = abs(heal_val - hp_missing)
			if fit < best_fit or (fit == best_fit and ab.energy_cost < best_cost):
				best_fit = fit
				best_cost = ab.energy_cost
				best_ab = ab
		if best_ab != null:
			return {"target": tgt, "ability": best_ab}

	return {"target": null, "ability": null}

## BUFF scoring:
##   For each ability (in candidate order), find the highest-HP living ally not already buffed.
##   Redundancy check: skip targets whose active_buff_ability_ids already contains this ability's id.
##   Returns the first successful (ability, target) pair found.
static func _pick_best_buff(
		enemy: Unit3D,
		allies: Array[Unit3D],
		abilities: Array[AbilityData]) -> Dictionary:

	for ab: AbilityData in abilities:
		if ab.target_shape == AbilityData.TargetShape.SELF:
			if not enemy.active_buff_ability_ids.has(ab.ability_id):
				return {"target": enemy, "ability": ab}
			continue  # self already buffed by this ability

		# Build reachable, non-redundant ally candidates
		var valid: Array[Unit3D] = []
		match ab.applicable_to:
			AbilityData.ApplicableTo.ALLY, AbilityData.ApplicableTo.ANY:
				for ally: Unit3D in allies:
					if ally.is_alive \
							and _is_in_range(ab, enemy.grid_pos, ally.grid_pos) \
							and not ally.active_buff_ability_ids.has(ab.ability_id):
						valid.append(ally)
				# Self qualifies as a fallback for ANY-applicable buffs
				if ab.applicable_to == AbilityData.ApplicableTo.ANY \
						and not enemy.active_buff_ability_ids.has(ab.ability_id):
					valid.append(enemy)
		if valid.is_empty():
			continue

		# Pick highest-HP target (least likely to die before buff pays off)
		valid.sort_custom(func(a: Unit3D, b: Unit3D) -> bool: return a.current_hp > b.current_hp)
		return {"target": valid[0], "ability": ab}

	return {"target": null, "ability": null}

## DEBUFF scoring:
##   For each ability, find the highest-HP living hostile that isn't redundant and not at stack cap.
##   Redundancy: skip if hostile's active_debuff_ability_ids contains this ability's id.
##   Stack cap: skip if debuff_stat_stacks[target_stat] >= 3.
static func _pick_best_debuff(
		enemy: Unit3D,
		hostiles: Array[Unit3D],
		abilities: Array[AbilityData]) -> Dictionary:

	for ab: AbilityData in abilities:
		# Determine the DEBUFF effect's target_stat for stack-cap check
		var target_stat: int = -1
		for eff: EffectData in ab.effects:
			if int(eff.effect_type) == 5:  # DEBUFF
				target_stat = int(eff.target_stat)
				break

		var best_hostile: Unit3D = null
		var best_hp: int = -1
		for h: Unit3D in hostiles:
			if not h.is_alive:
				continue
			if not _is_in_range(ab, enemy.grid_pos, h.grid_pos):
				continue
			if h.active_debuff_ability_ids.has(ab.ability_id):
				continue  # redundant — this debuff is already active
			if target_stat >= 0 and h.debuff_stat_stacks.get(target_stat, 0) >= 3:
				continue  # stack cap — no more of this stat debuff on this target
			if h.current_hp > best_hp:
				best_hp = h.current_hp
				best_hostile = h

		if best_hostile != null:
			return {"target": best_hostile, "ability": ab}

	return {"target": null, "ability": null}

## FORCE scoring — three-tier priority, drops if no meaningful push exists:
##   1. Hazard landing (score 3): forced landing cell is a HAZARD — immediate damage benefit.
##   2. Edge push (score 2): the cell beyond the landing is off-grid — maximum displacement.
##   3. Isolation gain (score 1): landing puts the target farther from its remaining allies.
##   Score 0 or no movement possible → not situationally useful; return {null, null}.
##
## When grid is null (test context without a scene), falls back to "any reachable hostile" —
## matching the Slice 2 situational-useful behavior so existing headless tests still pass.
##
## RADIAL force_type is treated as PUSH at decision time — blast origin is unknown pre-cast.
static func _pick_best_force(
		enemy: Unit3D,
		hostiles: Array[Unit3D],
		abilities: Array[AbilityData],
		grid: Grid3D) -> Dictionary:

	# --- null-grid fallback: pick highest-HP reachable hostile, first qualifying ability ---
	# Used when running headlessly in tests that don't construct a Grid3D.
	if grid == null:
		for ab: AbilityData in abilities:
			var best_hp: int = -1
			var fallback: Unit3D = null
			for h: Unit3D in hostiles:
				if h.is_alive and _is_in_range(ab, enemy.grid_pos, h.grid_pos) and h.current_hp > best_hp:
					best_hp = h.current_hp
					fallback = h
			if fallback != null:
				return {"target": fallback, "ability": ab}
		return {"target": null, "ability": null}

	# --- Full scoring path (grid available) ---
	var best_score: int = 0
	var best_target: Unit3D = null
	var best_ab: AbilityData = null

	for ab: AbilityData in abilities:
		var force_eff: EffectData = null
		for eff: EffectData in ab.effects:
			if int(eff.effect_type) == 2:  # FORCE
				force_eff = eff
				break
		if force_eff == null:
			continue

		for h: Unit3D in hostiles:
			if not h.is_alive:
				continue
			if not _is_in_range(ab, enemy.grid_pos, h.grid_pos):
				continue

			var dest: Vector2i = _compute_force_dest(enemy.grid_pos, h.grid_pos, force_eff, grid)
			if dest == h.grid_pos:
				continue  # unit can't move — no benefit

			var dir: Vector2i = _force_push_dir(enemy.grid_pos, h.grid_pos, force_eff)
			var score: int = 0
			if grid.is_hazard(dest):
				score = 3  # highest: lands on hazard (takes immediate damage)
			elif not grid.is_valid(dest + dir):
				score = 2  # edge push: next step would be off-grid
			else:
				# Isolation: sum of distances to remaining hostiles after the push
				var isolation_sum: int = 0
				for other: Unit3D in hostiles:
					if other == h or not other.is_alive:
						continue
					isolation_sum += abs(dest.x - other.grid_pos.x) + abs(dest.y - other.grid_pos.y)
				if isolation_sum > 0:
					score = 1

			if score > best_score:
				best_score = score
				best_target = h
				best_ab = ab

	if best_score > 0 and best_ab != null:
		return {"target": best_target, "ability": best_ab}
	return {"target": null, "ability": null}

## ======================================================
## --- Private: Critical-heal override ---
## ======================================================

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
			# Include self for ANY-applicable abilities
			if ab.applicable_to == AbilityData.ApplicableTo.ANY:
				var self_pct: float = float(enemy.current_hp) / float(enemy.data.hp_max)
				if self_pct < CRIT_HEAL_THRESHOLD:
					candidates.append(enemy)

		if candidates.is_empty():
			continue

		candidates.sort_custom(func(a: Unit3D, b: Unit3D) -> bool:
			return a.current_hp < b.current_hp)
		return {"target": candidates[0], "ability": ab}

	return {"target": null, "ability": null}

## ======================================================
## --- Private: Geometry helpers ---
## (Extracted from CombatManager3D; that class's methods are thin wrappers here.)
## ======================================================

## Returns every grid cell covered by the ability's shape given caster and aim positions.
## Mirrors CombatManager3D._get_shape_cells exactly.
static func _get_shape_cells_static(
		caster_pos: Vector2i,
		origin_pos: Vector2i,
		ability: AbilityData,
		grid: Grid3D) -> Array[Vector2i]:
	if grid == null:
		return [] as Array[Vector2i]
	var cells: Array[Vector2i] = []
	match ability.target_shape:
		AbilityData.TargetShape.RADIAL:
			var radius: int = 2  # fixed 5×5 diamond
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if abs(dx) + abs(dy) > radius:
						continue
					var cell := Vector2i(origin_pos.x + dx, origin_pos.y + dy)
					if not grid.is_valid(cell):
						continue
					if not ability.passthrough and abs(dx) + abs(dy) == 2 \
							and (dx == 0 or dy == 0):
						var mid := Vector2i(origin_pos.x + sign(dx), origin_pos.y + sign(dy))
						if grid.is_occupied(mid):
							continue
					cells.append(cell)
		AbilityData.TargetShape.ARC:
			var dir: Vector2i  = _cardinal_direction_static(caster_pos, origin_pos)
			var root: Vector2i = caster_pos + dir
			var perp: Vector2i = Vector2i(dir.y, dir.x)
			for c: Vector2i in [root - perp, root, root + perp]:
				if grid.is_valid(c):
					cells.append(c)
		AbilityData.TargetShape.CONE:
			var dir: Vector2i  = _cardinal_direction_static(caster_pos, origin_pos)
			var perp: Vector2i = Vector2i(dir.y, dir.x)
			var d1: Vector2i   = caster_pos + dir
			var d2: Vector2i   = d1 + dir
			var d3: Vector2i   = d2 + dir
			if grid.is_valid(d1):
				cells.append(d1)
			if ability.passthrough or not grid.is_occupied(d1):
				for c: Vector2i in [d2 - perp, d2, d2 + perp]:
					if grid.is_valid(c):
						cells.append(c)
				for c: Vector2i in [d3 - perp * 2, d3 - perp, d3, d3 + perp, d3 + perp * 2]:
					if grid.is_valid(c):
						cells.append(c)
		AbilityData.TargetShape.LINE:
			var dir := _cardinal_direction_static(caster_pos, origin_pos)
			var cur := caster_pos + dir
			var steps: int = 0
			var limit: int = ability.tile_range if ability.tile_range != -1 else 999
			while grid.is_valid(cur) and steps < limit:
				cells.append(cur)
				if grid.is_occupied(cur) and not ability.passthrough:
					break
				cur = cur + dir
				steps += 1
	return cells

## Cardinal direction from `from` to `to` — pure math, no grid access.
## Mirrors CombatManager3D._cardinal_direction exactly.
static func _cardinal_direction_static(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff := to - from
	if abs(diff.x) >= abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	else:
		return Vector2i(0, sign(diff.y))

## Counts living hostile units (player units, from an enemy caster's perspective) in the
## AoE cells at the given origin. Used by pick_best_aoe_origin and _pick_best_harm.
static func _aoe_hostile_count(
		caster_pos: Vector2i,
		origin: Vector2i,
		ability: AbilityData,
		grid: Grid3D) -> int:
	var cells := _get_shape_cells_static(caster_pos, origin, ability, grid)
	var count: int = 0
	for cell: Vector2i in cells:
		var obj: Object = grid.get_unit_at(cell)
		if not obj is Unit3D:
			continue
		var u := obj as Unit3D
		if not u.is_alive:
			continue
		# Enemy caster perspective: ENEMY applicable_to targets player units
		match ability.applicable_to:
			AbilityData.ApplicableTo.ENEMY:
				if u.data.is_player_unit:
					count += 1
			AbilityData.ApplicableTo.ANY:
				count += 1
			AbilityData.ApplicableTo.ALLY:
				if not u.data.is_player_unit:
					count += 1
	return count

## Simulates where a target lands after a FORCE push/pull/etc. from the given caster position.
## Returns the same grid_pos if no movement is possible (blocked at first step).
## RADIAL force_type is treated as PUSH (blast origin is unknown at decision time).
static func _compute_force_dest(
		caster_pos: Vector2i,
		target_pos: Vector2i,
		effect: EffectData,
		grid: Grid3D) -> Vector2i:
	var dir: Vector2i = _force_push_dir(caster_pos, target_pos, effect)
	var dest: Vector2i = target_pos
	for _i in range(effect.base_value):
		var nxt: Vector2i = dest + dir
		if not grid.is_valid(nxt) or grid.is_occupied(nxt):
			break
		dest = nxt
	return dest

## Returns the displacement direction for a FORCE effect.
## RADIAL treated as PUSH (blast origin unavailable at AI decision time).
static func _force_push_dir(
		caster_pos: Vector2i,
		target_pos: Vector2i,
		effect: EffectData) -> Vector2i:
	match int(effect.force_type):
		1:  # PULL
			return _cardinal_direction_static(target_pos, caster_pos)
		2:  # LEFT — 90° left of caster→target axis
			var base := _cardinal_direction_static(caster_pos, target_pos)
			return Vector2i(-base.y, base.x)
		3:  # RIGHT — 90° right of caster→target axis
			var base := _cardinal_direction_static(caster_pos, target_pos)
			return Vector2i(base.y, -base.x)
		_:  # PUSH (0) and RADIAL (4) both push away from caster toward target
			return _cardinal_direction_static(caster_pos, target_pos)

## ======================================================
## --- Private: Damage estimation ---
## ======================================================

## Estimates damage an ability will deal to a target, ignoring QTE roll (assumes neutral outcome).
## Mirrors the CM3D HARM formula: base_values + caster's effective attribute - target's armor.
## QTE roll unknowable at decision time; estimator assumes neutral defender outcome.
static func _expected_damage(
		ability: AbilityData,
		attacker: Unit3D,
		target: Unit3D) -> int:
	var base_dmg: int = 0
	for eff: EffectData in ability.effects:
		if int(eff.effect_type) == 0:  # HARM
			base_dmg += eff.base_value

	var attr_val: int = 0
	match ability.attribute:
		AbilityData.Attribute.STRENGTH:  attr_val = attacker.data.effective_stat("strength")
		AbilityData.Attribute.DEXTERITY: attr_val = attacker.data.effective_stat("dexterity")
		AbilityData.Attribute.COGNITION: attr_val = attacker.data.effective_stat("cognition")
		AbilityData.Attribute.VITALITY:  attr_val = attacker.data.effective_stat("vitality")
		AbilityData.Attribute.WILLPOWER: attr_val = attacker.data.effective_stat("willpower")

	var armor: int = 0
	match ability.damage_type:
		AbilityData.DamageType.PHYSICAL: armor = target.data.physical_defense
		AbilityData.DamageType.MAGIC:    armor = target.data.magic_defense

	# QTE roll unknowable at decision time; estimator assumes neutral defender outcome
	return maxi(0, base_dmg + attr_val - armor)

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
	var target: Unit3D = _pick_target_simple(chosen, enemy, allies, hostiles)
	return {"target": target, "ability": chosen}

## Simple first-valid target picker for force_random — not used in the scored role walk.
static func _pick_target_simple(
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
			var etype: int = int(ability.effects[0].effect_type)
			if etype == 0 or etype == 2 or etype == 5:  # HARM, FORCE, DEBUFF
				for hostile: Unit3D in hostiles:
					if hostile.is_alive and _is_in_range(ability, enemy.grid_pos, hostile.grid_pos):
						return hostile
				for ally: Unit3D in allies:
					if ally.is_alive and _is_in_range(ability, enemy.grid_pos, ally.grid_pos):
						return ally
			else:
				for ally: Unit3D in allies:
					if ally.is_alive and _is_in_range(ability, enemy.grid_pos, ally.grid_pos):
						return ally
				return enemy
	return null
