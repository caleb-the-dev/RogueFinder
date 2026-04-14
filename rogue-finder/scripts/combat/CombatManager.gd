class_name CombatManager
extends Node2D

## --- Combat Manager ---
## Root script for CombatScene. Owns the turn state machine and routes all player
## input to the appropriate subsystems (Grid, QTEBar, HUD).
##
## Turn flow:
##   PLAYER_TURN → [player acts for each unit] → ENEMY_TURN → [AI resolves] → PLAYER_TURN
##   WIN or LOSE are terminal states.
##
## Player input summary:
##   Click own unit    = select it (enters STRIDE_MODE, shows movement range)
##   Click blue cell   = stride there
##   [A]               = enter ATTACK_MODE (shows red enemy highlights)
##   Click red enemy   = fire QTE attack
##   [M]               = re-enter STRIDE_MODE from ATTACK_MODE
##   [E]               = end player phase manually
##   [Esc]             = deselect current unit

## --- Signals ---
signal phase_changed(new_phase: String)
signal combat_ended(player_won: bool)

## --- State Machine ---
enum CombatState { PLAYER_TURN, QTE_RUNNING, ENEMY_TURN, WIN, LOSE }
enum PlayerMode  { IDLE, STRIDE_MODE, ATTACK_MODE }

var state: CombatState = CombatState.PLAYER_TURN
var player_mode: PlayerMode = PlayerMode.IDLE

## --- Unit Tracking ---
var player_units: Array[Unit] = []
var enemy_units: Array[Unit]  = []
var selected_unit: Unit = null
## Held across the QTE await so _on_qte_resolved can apply the outcome
var _pending_attacker: Unit = null
var _pending_target: Unit   = null

## --- Tuning ---
const ATTACK_ENERGY_COST: int  = 3
const ENEMY_TURN_DELAY: float  = 0.65   # Seconds between each enemy action (readability)

## --- Node References ---
@onready var grid: Grid         = $Grid
@onready var qte_bar: QTEBar    = $QTEBar
@onready var hud: HUD           = $HUD
@onready var status_label: Label = $StatusLabel

func _ready() -> void:
	_setup_units()
	_connect_signals()
	_start_player_turn()

## ─────────────────────────────────────────────────────────
## Setup
## ─────────────────────────────────────────────────────────

func _setup_units() -> void:
	# Player units — left side of grid
	var p_positions: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 2), Vector2i(1, 1)]
	var p_names: Array[String]       = ["Vael", "Kira", "Brom"]
	for i: int in range(3):
		var d := _make_player_data(p_names[i])
		var u: Unit = preload("res://scenes/combat/Unit.tscn").instantiate()
		u.unit_died.connect(_on_unit_died)
		grid.place_unit(u, p_positions[i])
		u.setup(d, p_positions[i])
		player_units.append(u)

	# Enemy units — right side of grid
	var e_positions: Array[Vector2i] = [Vector2i(5, 0), Vector2i(5, 2), Vector2i(4, 1)]
	var e_names: Array[String]       = ["Grunt A", "Grunt B", "Grunt C"]
	for i: int in range(3):
		var d := _make_enemy_data(e_names[i])
		var u: Unit = preload("res://scenes/combat/Unit.tscn").instantiate()
		u.unit_died.connect(_on_unit_died)
		grid.place_unit(u, e_positions[i])
		u.setup(d, e_positions[i])
		enemy_units.append(u)

func _make_player_data(unit_name: String) -> UnitData:
	var d := UnitData.new()
	d.unit_name      = unit_name
	d.is_player_unit = true
	d.hp_max         = 20
	d.speed          = 3
	d.attack         = 10
	d.defense        = 10
	d.energy_max     = 10
	d.energy_regen   = 3
	return d

func _make_enemy_data(unit_name: String) -> UnitData:
	var d := UnitData.new()
	d.unit_name       = unit_name
	d.is_player_unit  = false
	d.hp_max          = 15
	d.speed           = 3
	d.attack          = 10
	d.defense         = 10
	d.energy_max      = 10
	d.energy_regen    = 3
	d.qte_resolution  = 0.3   # Grunt tier — low auto-accuracy
	return d

func _connect_signals() -> void:
	grid.cell_clicked.connect(_on_cell_clicked)
	qte_bar.qte_resolved.connect(_on_qte_resolved)

## ─────────────────────────────────────────────────────────
## Phase Management
## ─────────────────────────────────────────────────────────

func _start_player_turn() -> void:
	state = CombatState.PLAYER_TURN
	for unit: Unit in player_units:
		if unit.is_alive:
			unit.regen_energy()
			unit.reset_turn()
	_deselect_unit()
	status_label.text = "PLAYER TURN  —  Select a unit.  [A] Attack  [M] Move  [E] End Turn"
	phase_changed.emit("PLAYER_TURN")
	hud.refresh(player_units, enemy_units)

func _start_enemy_turn() -> void:
	state = CombatState.ENEMY_TURN
	_deselect_unit()
	status_label.text = "ENEMY TURN..."
	phase_changed.emit("ENEMY_TURN")
	_run_enemy_turn()

func _end_combat(player_won: bool) -> void:
	state = CombatState.WIN if player_won else CombatState.LOSE
	status_label.text = "VICTORY! All enemies defeated." if player_won \
		else "DEFEAT! Your party has fallen."
	combat_ended.emit(player_won)

## ─────────────────────────────────────────────────────────
## Player Input
## ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if state != CombatState.PLAYER_TURN:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.keycode:
		KEY_E:
			# Manually end player phase
			_start_enemy_turn()
		KEY_ESCAPE:
			_deselect_unit()
		KEY_A:
			# Enter attack mode for selected unit
			if selected_unit and selected_unit.can_act(ATTACK_ENERGY_COST):
				player_mode = PlayerMode.ATTACK_MODE
				_show_attack_targets()
				_set_status_for_selected()
		KEY_M:
			# (Re-)enter stride mode for selected unit
			if selected_unit and selected_unit.can_stride():
				player_mode = PlayerMode.STRIDE_MODE
				_show_move_range()
				_set_status_for_selected()

func _on_cell_clicked(grid_pos: Vector2i) -> void:
	if state != CombatState.PLAYER_TURN:
		return

	var clicked_unit: Unit = grid.get_unit_at(grid_pos)

	match player_mode:
		PlayerMode.IDLE:
			# Select a player unit
			if clicked_unit and clicked_unit.data.is_player_unit and clicked_unit.is_alive:
				_select_unit(clicked_unit)

		PlayerMode.STRIDE_MODE:
			if grid_pos in grid.highlighted_cells and not grid.is_occupied(grid_pos):
				# Move the selected unit to this empty highlighted cell
				var old_pos: Vector2i = selected_unit.grid_pos
				selected_unit.move_to(grid_pos)
				grid.register_move(selected_unit, old_pos, grid_pos)
				grid.clear_highlights()
				_after_unit_action()
			elif clicked_unit and clicked_unit.data.is_player_unit and clicked_unit.is_alive:
				# Re-select a different player unit
				_select_unit(clicked_unit)

		PlayerMode.ATTACK_MODE:
			if clicked_unit and not clicked_unit.data.is_player_unit and clicked_unit.is_alive \
					and grid_pos in grid.highlighted_cells:
				_initiate_attack(selected_unit, clicked_unit)
			elif clicked_unit and clicked_unit.data.is_player_unit and clicked_unit.is_alive:
				_select_unit(clicked_unit)

## ─────────────────────────────────────────────────────────
## Unit Selection Helpers
## ─────────────────────────────────────────────────────────

func _select_unit(unit: Unit) -> void:
	if selected_unit:
		selected_unit.set_selected(false)
	selected_unit = unit
	unit.set_selected(true)
	# Default to stride mode on select; player can press A to switch to attack
	player_mode = PlayerMode.STRIDE_MODE
	_show_move_range()
	_set_status_for_selected()

func _deselect_unit() -> void:
	if selected_unit:
		selected_unit.set_selected(false)
		selected_unit = null
	player_mode = PlayerMode.IDLE
	grid.clear_highlights()

func _set_status_for_selected() -> void:
	if not selected_unit:
		return
	var mode_str: String = "[M] Move" if player_mode == PlayerMode.STRIDE_MODE \
		else "[A] Attack"
	var move_str: String  = "" if selected_unit.can_stride() else "(moved) "
	var act_str: String   = "" if selected_unit.can_act(ATTACK_ENERGY_COST) else "(no energy) "
	status_label.text = "%s  %s%s%s  [E] End Turn  [Esc] Deselect" % [
		selected_unit.data.unit_name, move_str, act_str, mode_str
	]

func _show_move_range() -> void:
	if not selected_unit or not selected_unit.can_stride():
		grid.clear_highlights()
		return
	grid.show_move_highlights(grid.get_valid_move_cells(selected_unit))

func _show_attack_targets() -> void:
	# Stage 1: any alive enemy is a valid target regardless of range
	var cells: Array[Vector2i] = []
	for enemy: Unit in enemy_units:
		if enemy.is_alive:
			cells.append(enemy.grid_pos)
	grid.show_attack_highlights(cells)

## Called after a stride or act to update mode and check for auto-advance.
func _after_unit_action() -> void:
	if not selected_unit:
		return
	if selected_unit.can_act(ATTACK_ENERGY_COST) and not selected_unit.has_acted:
		# Prompt for attack next
		player_mode = PlayerMode.ATTACK_MODE
		_show_attack_targets()
	else:
		player_mode = PlayerMode.IDLE
		grid.clear_highlights()
	_set_status_for_selected()
	_check_all_acted()

func _check_all_acted() -> void:
	# Auto-advance to enemy turn when every alive player unit has both moved and acted
	for unit: Unit in player_units:
		if unit.is_alive and (not unit.has_moved or not unit.has_acted):
			return
	_start_enemy_turn()

## ─────────────────────────────────────────────────────────
## Attack Flow
## ─────────────────────────────────────────────────────────

func _initiate_attack(attacker: Unit, target: Unit) -> void:
	if not attacker.spend_energy(ATTACK_ENERGY_COST):
		status_label.text = "Not enough Energy to attack!"
		return
	_pending_attacker = attacker
	_pending_target   = target
	state = CombatState.QTE_RUNNING
	grid.clear_highlights()
	attacker.set_selected(false)
	qte_bar.start_qte()

func _on_qte_resolved(accuracy: float) -> void:
	var attacker := _pending_attacker
	var target   := _pending_target
	_pending_attacker = null
	_pending_target   = null

	var damage: int = _calculate_damage(attacker, target, accuracy)
	# take_damage may trigger unit_died → _on_unit_died → _check_win_lose → _end_combat
	target.take_damage(damage)
	attacker.has_acted = true
	attacker.refresh_visual()
	hud.refresh(player_units, enemy_units)

	# Combat may have ended synchronously inside take_damage
	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	state = CombatState.PLAYER_TURN
	status_label.text = "%s dealt %d damage to %s! (%.0f%% accuracy)" % [
		attacker.data.unit_name, damage, target.data.unit_name, accuracy * 100.0
	]
	_deselect_unit()
	_check_all_acted()

## ─────────────────────────────────────────────────────────
## Enemy AI
## ─────────────────────────────────────────────────────────

func _run_enemy_turn() -> void:
	# Regen energy for all enemies at the start of their phase
	for enemy: Unit in enemy_units:
		if enemy.is_alive:
			enemy.regen_energy()
			enemy.reset_turn()
	hud.refresh(player_units, enemy_units)
	await _process_enemy_actions()
	# Safety check after all enemies have acted
	if state != CombatState.WIN and state != CombatState.LOSE:
		_start_player_turn()

func _process_enemy_actions() -> void:
	for enemy: Unit in enemy_units:
		if not enemy.is_alive:
			continue
		# Pick a random alive player unit as the attack target
		var alive_players: Array[Unit] = player_units.filter(
			func(u: Unit) -> bool: return u.is_alive
		)
		if alive_players.is_empty():
			return

		var target: Unit = alive_players[randi() % alive_players.size()]
		# Auto-resolve QTE using the enemy's hidden accuracy stat
		var accuracy: float = enemy.data.qte_resolution
		var damage: int = _calculate_damage(enemy, target, accuracy)
		target.take_damage(damage)
		enemy.has_acted = true

		status_label.text = "%s attacks %s for %d damage!" % [
			enemy.data.unit_name, target.data.unit_name, damage
		]
		hud.refresh(player_units, enemy_units)

		# take_damage may have ended combat via _on_unit_died
		if state == CombatState.WIN or state == CombatState.LOSE:
			return

		# Brief pause so the player can read each enemy action
		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout

## ─────────────────────────────────────────────────────────
## Damage Formula
## ─────────────────────────────────────────────────────────

## Effectiveness scales with the attacker/defender stat delta.
## Skill (accuracy) determines where within that range the hit lands.
## Minimum 1 damage — the action always fires even on a full miss.
func _calculate_damage(attacker: Unit, target: Unit, accuracy: float) -> int:
	# +1.0 at parity, up to +2.0 when attack >> defense, down to +0.5 when defense >> attack
	var stat_delta: float  = float(attacker.data.attack - target.data.defense)
	var effectiveness: float = clampf(1.0 + stat_delta / 20.0, 0.5, 2.0)
	var skill: float       = clampf(accuracy, 0.1, 1.0)
	return maxi(1, roundi(float(attacker.data.attack) * effectiveness * skill))

## ─────────────────────────────────────────────────────────
## Win / Lose
## ─────────────────────────────────────────────────────────

func _check_win_lose() -> void:
	# Guard: don't overwrite a terminal state
	if state == CombatState.WIN or state == CombatState.LOSE:
		return
	var all_enemies_dead: bool = enemy_units.all(func(u: Unit) -> bool: return not u.is_alive)
	var all_players_dead: bool = player_units.all(func(u: Unit) -> bool: return not u.is_alive)
	if all_enemies_dead:
		_end_combat(true)
	elif all_players_dead:
		_end_combat(false)

func _on_unit_died(unit: Unit) -> void:
	hud.refresh(player_units, enemy_units)
	if unit.data.is_player_unit:
		status_label.text = "%s has fallen!" % unit.data.unit_name
	_check_win_lose()
