class_name CombatManagerAuto
extends Node3D

## --- CombatManagerAuto ---
## Turn-tick autobattler controller. Hosts the LaneBoard, drives the tick loop,
## fires unit turns, manages combat lifecycle (entry, victory, defeat).
## Coexists with the legacy CombatManager3D until Slice 7.

## --- Constants ---
const TICK_INTERVAL_SEC: float = 0.6  # cosmetic delay between ticks for player readability

## --- State ---
var board: LaneBoard = LaneBoard.new()
var combat_running: bool = false
var current_tick: int = 0
var _all_units: Array[CombatantData] = []
var _tick_accum: float = 0.0

## --- Lifecycle ---
func _ready() -> void:
	board = LaneBoard.new()
	# Task 4.5 wires party + enemies from GameState here.
	var party: Array[CombatantData] = []
	for cd: CombatantData in GameState.party:
		if not cd.is_dead:
			party.append(cd)
	if party.size() > LaneBoard.LANE_COUNT:
		party = party.slice(0, LaneBoard.LANE_COUNT)
	var enemies: Array[CombatantData] = GameState.pending_combat_enemies
	GameState.pending_combat_enemies = []
	if party.is_empty() or enemies.is_empty():
		push_warning("[CombatManagerAuto] missing party or enemies on scene entry")
		return
	start_combat(party, enemies)

## Real-time tick driver — called each frame by the scene tree.
func _process(delta: float) -> void:
	if not combat_running:
		return
	_tick_accum += delta
	if _tick_accum >= TICK_INTERVAL_SEC:
		_tick_accum -= TICK_INTERVAL_SEC
		_advance_tick()

## Public entry point — called by _ready() or tests.
func start_combat(party: Array[CombatantData], enemies: Array[CombatantData]) -> void:
	combat_running = true
	current_tick = 0
	_all_units.clear()
	for i in min(party.size(), LaneBoard.LANE_COUNT):
		board.place(party[i], i, "ally")
		_init_unit_for_combat(party[i])
		_all_units.append(party[i])
	for i in min(enemies.size(), LaneBoard.LANE_COUNT):
		board.place(enemies[i], i, "enemy")
		_init_unit_for_combat(enemies[i])
		_all_units.append(enemies[i])
	print("[CombatManagerAuto] combat started: %d allies, %d enemies" % [party.size(), enemies.size()])

func _init_unit_for_combat(u: CombatantData) -> void:
	u.countdown_max = CountdownTracker.compute_countdown_max(u.effective_stat("spd"))
	u.countdown_current = u.countdown_max
	u.cooldowns = [0, 0, 0]

## Drives one tick of combat. Decrements all counters; fires any units that hit 0.
## Called by _process() in real-time mode and by tests for deterministic stepping.
func _advance_tick() -> void:
	if not combat_running:
		return
	current_tick += 1
	var ready := CountdownTracker.tick_and_collect_ready(_all_units)
	for u: CombatantData in _all_units:
		CountdownTracker.tick_cooldowns(u.cooldowns)
	var ordered := CountdownTracker.tiebreak_ready(ready)
	for u: CombatantData in ordered:
		if u.current_hp <= 0:
			continue
		_fire_unit_turn(u)
		CountdownTracker.reset_countdown(u)
		if _check_combat_end():
			return

func _fire_unit_turn(u: CombatantData) -> void:
	var allies: Array[CombatantData] = board.get_all_on_side(board.get_side_of(u))
	var hostiles: Array[CombatantData] = board.get_all_on_side(board.get_opposite_side(board.get_side_of(u)))
	var pick: Dictionary = AutobattlerEnemyAI.pick(u, allies, hostiles, board)
	if pick.ability == null:
		print("  [%s] tick %d: skips (no valid action)" % [u.character_name, current_tick])
		return
	var ability: AbilityData = pick.ability
	var targets: Array = pick.targets
	for target: CombatantData in targets:
		_apply_ability(u, target, ability)
	u.cooldowns[pick.slot] = ability.cooldown_max
	print("  [%s] tick %d: %s on %d target(s)" % [u.character_name, current_tick, ability.ability_name, targets.size()])

## Returns the array of target units for a given (caster, ability, board) triple.
## Empty array = no valid target (caller skips turn).
static func resolve_targets(caster: CombatantData, ability: AbilityData, board: LaneBoard) -> Array[CombatantData]:
	var caster_lane := board.get_lane_of(caster)
	var caster_side := board.get_side_of(caster)
	var enemy_side := board.get_opposite_side(caster_side)
	var result: Array[CombatantData] = []
	match ability.target_shape:
		AbilityData.TargetShape.SELF:
			result.append(caster)
		AbilityData.TargetShape.SAME_LANE, AbilityData.TargetShape.SINGLE:
			# Try direct opposite first; fall back to nearest non-empty enemy.
			var opp := board.get_unit(caster_lane, enemy_side)
			if opp != null and opp.current_hp > 0:
				result.append(opp)
			else:
				for u: CombatantData in board.get_all_on_side(enemy_side):
					if u.current_hp > 0:
						result.append(u)
						break
		AbilityData.TargetShape.ADJACENT_LANE:
			for u: CombatantData in board.get_adjacent_lane_units(caster_lane, enemy_side):
				if u.current_hp > 0:
					result.append(u)
		AbilityData.TargetShape.ALL_LANES:
			for u: CombatantData in board.get_all_on_side(enemy_side):
				if u.current_hp > 0:
					result.append(u)
		AbilityData.TargetShape.ALL_ALLIES:
			for u: CombatantData in board.get_all_on_side(caster_side):
				if u.current_hp > 0:
					result.append(u)
		_:
			# Legacy shapes (CONE/LINE/RADIAL/ARC): autobattler treats as SAME_LANE.
			# Slice 7 strips legacy shape support.
			var opp := board.get_unit(caster_lane, enemy_side)
			if opp != null and opp.current_hp > 0:
				result.append(opp)
			else:
				for u: CombatantData in board.get_all_on_side(enemy_side):
					if u.current_hp > 0:
						result.append(u)
						break
	return result

func _apply_ability(caster: CombatantData, target: CombatantData, ability: AbilityData) -> void:
	for effect: EffectData in ability.effects:
		match effect.effect_type:
			EffectData.EffectType.HARM:
				_apply_harm(caster, target, effect, ability.attribute, ability.damage_type)
			EffectData.EffectType.MEND:
				var heal_amount: int = effect.base_value + caster.effective_stat("willpower")
				target.current_hp = min(target.hp_max, target.current_hp + heal_amount)
			EffectData.EffectType.BUFF:
				_apply_stat_delta(target, effect, 1)
			EffectData.EffectType.DEBUFF:
				_apply_stat_delta(target, effect, -1)
			# FORCE / TRAVEL: no movement in autobattler, ignored

func _apply_harm(caster: CombatantData, target: CombatantData, effect: EffectData, attr: AbilityData.Attribute, dt: AbilityData.DamageType) -> void:
	var attr_name: String = _attr_to_string(attr)
	var raw_dmg: int = effect.base_value + caster.effective_stat(attr_name)
	var defense: int = 0
	if dt == AbilityData.DamageType.PHYSICAL:
		defense = target.physical_defense
	elif dt == AbilityData.DamageType.MAGIC:
		defense = target.magic_defense
	var dmg: int = max(1, raw_dmg - defense)
	target.current_hp = max(0, target.current_hp - dmg)

func _apply_stat_delta(target: CombatantData, effect: EffectData, sign: int) -> void:
	# Slice 7+: full transient stat-mod tracking (snapshots, durations).
	# For vert slice: only armor mods are implemented; other targets are no-ops.
	match effect.target_stat:
		AbilityData.Attribute.PHYSICAL_ARMOR_MOD:
			target.physical_armor_mod = clamp(target.physical_armor_mod + sign * effect.base_value, -10, 10)
		AbilityData.Attribute.MAGIC_ARMOR_MOD:
			target.magic_armor_mod = clamp(target.magic_armor_mod + sign * effect.base_value, -10, 10)

func _attr_to_string(a: AbilityData.Attribute) -> String:
	match a:
		AbilityData.Attribute.STRENGTH:  return "strength"
		AbilityData.Attribute.DEXTERITY: return "dexterity"
		AbilityData.Attribute.COGNITION: return "cognition"
		AbilityData.Attribute.WILLPOWER: return "willpower"
		AbilityData.Attribute.VITALITY:  return "vitality"
		_: return ""

func _check_combat_end() -> bool:
	if board.is_side_wiped("ally"):
		end_combat(false)
		return true
	if board.is_side_wiped("enemy"):
		end_combat(true)
		return true
	return false

func end_combat(victory: bool) -> void:
	combat_running = false
	print("[CombatManagerAuto] combat ended — victory: %s" % victory)
	# Slice 5+: route to EndCombatScreen / RunSummaryScene based on victory flag.
