class_name CombatManager3D
extends Node3D

## --- CombatManager3D ---
## Turn state machine for the 3D combat prototype.
## Builds the entire scene in _ready() — no child nodes needed in the .tscn.
## Controls: Click to select/move, [A] attack mode, [Enter] end turn, [ESC] deselect.
## Camera: [Q] rotate CCW, [E] rotate CW, scroll wheel zoom.
##
## "Redo" button at bottom-left reloads the scene with freshly randomized units.

const ATTACK_ENERGY_COST: int  = 3
const ENEMY_TURN_DELAY: float  = 0.65  # seconds between enemy actions

enum CombatState { PLAYER_TURN, QTE_RUNNING, ENEMY_TURN, WIN, LOSE }
enum PlayerMode  { IDLE, STRIDE_MODE, ATTACK_MODE }

var state: CombatState = CombatState.PLAYER_TURN
var mode: PlayerMode   = PlayerMode.IDLE

var _player_units: Array[Unit3D] = []
var _enemy_units:  Array[Unit3D] = []
var _selected_unit: Unit3D       = null
var _attack_target: Unit3D       = null

var _grid: Grid3D                 = null
var _camera_rig: CameraController = null
var _qte_bar: QTEBar              = null
var _stat_panel: StatPanel        = null
var _info_bar: UnitInfoBar        = null
var _info_bar_unit: Unit3D        = null  # which unit the bar is currently tracking
var _confirm_panel: ColorRect     = null  # "end turn early?" dialog
var _status_label: Label          = null

## --- Initialization ---

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_grid()
	_setup_units()
	_setup_ui()
	_update_status()

func _setup_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env       := Environment.new()
	env.background_mode  = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.08, 0.10)
	world_env.environment = env
	add_child(world_env)

	# Soft directional light so the unshaded boxes cast readable shadows
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.light_energy     = 1.2
	add_child(sun)

func _setup_camera() -> void:
	_camera_rig = CameraController.new()
	# Grid center: col (0-9) center = 9.0, row (0-9) center = 9.0 (CELL_SIZE=2)
	_camera_rig.position = Vector3(9.0, 0.0, 9.0)
	add_child(_camera_rig)

func _setup_grid() -> void:
	_grid = Grid3D.new()
	add_child(_grid)

func _setup_units() -> void:
	var unit_scene: PackedScene = preload("res://scenes/combat/Unit3D.tscn")

	# --- Player unit 0: The RogueFinder (PC) ---
	# Always uses the "RogueFinder" archetype with a fixed name. One per party.
	var pc_cd: CombatantData = ArchetypeLibrary.create("RogueFinder", "Vael", true)
	var pc: Unit3D = unit_scene.instantiate()
	add_child(pc)
	pc.setup(pc_cd, Vector2i(1, 3))
	pc.global_position = _grid.grid_to_world(Vector2i(1, 3))
	_grid.set_occupied(Vector2i(1, 3), pc)
	pc.unit_died.connect(_on_unit_died)
	_player_units.append(pc)

	# --- Player units 1-2: Allies (random archetype, auto-named from flavor pool) ---
	var ally_archetypes: Array[String] = ["archer_bandit", "grunt", "alchemist", "elite_guard"]
	var ally_positions: Array[Vector2i] = [Vector2i(1, 5), Vector2i(0, 4)]
	for pos in ally_positions:
		var arch: String = ally_archetypes[randi() % ally_archetypes.size()]
		# character_name="" + is_player=true → auto-named from the archetype's flavor pool
		var cd: CombatantData = ArchetypeLibrary.create(arch, "", true)
		var unit: Unit3D = unit_scene.instantiate()
		add_child(unit)
		unit.setup(cd, pos)
		unit.global_position = _grid.grid_to_world(pos)
		_grid.set_occupied(pos, unit)
		unit.unit_died.connect(_on_unit_died)
		_player_units.append(unit)

	# --- Enemy units ---
	# character_name="" + is_player=false → empty; Unit3D shows archetype label above head.
	var enemy_archetypes: Array[String] = ["archer_bandit", "grunt", "alchemist", "elite_guard"]
	var enemy_positions: Array[Vector2i] = [Vector2i(8, 3), Vector2i(8, 5), Vector2i(9, 4)]
	for pos in enemy_positions:
		var arch: String = enemy_archetypes[randi() % enemy_archetypes.size()]
		var cd: CombatantData = ArchetypeLibrary.create(arch, "", false)
		var unit: Unit3D = unit_scene.instantiate()
		add_child(unit)
		unit.setup(cd, pos)
		unit.global_position = _grid.grid_to_world(pos)
		_grid.set_occupied(pos, unit)
		unit.unit_died.connect(_on_unit_died)
		_enemy_units.append(unit)

func _setup_ui() -> void:
	_qte_bar = preload("res://scenes/combat/QTEBar.tscn").instantiate()
	add_child(_qte_bar)
	_qte_bar.qte_resolved.connect(_on_qte_resolved)

	# Full examine panel — opened only on double-click
	_stat_panel = StatPanel.new()
	add_child(_stat_panel)

	# Condensed unit info strip — shown on single-click selection
	_info_bar = UnitInfoBar.new()
	add_child(_info_bar)

	# Floating status label at top-left
	var status_layer := CanvasLayer.new()
	status_layer.layer = 3
	add_child(status_layer)
	_status_label = Label.new()
	_status_label.position = Vector2(10.0, 10.0)
	_status_label.size     = Vector2(620.0, 28.0)
	_status_label.add_theme_font_size_override("font_size", 16)
	status_layer.add_child(_status_label)

	# Redo button — reloads the scene so all units are freshly randomized
	var redo_layer := CanvasLayer.new()
	redo_layer.layer = 3
	add_child(redo_layer)
	var redo_btn := Button.new()
	redo_btn.text     = "Redo (Reroll)"
	redo_btn.position = Vector2(10.0, 648.0)
	redo_btn.size     = Vector2(140.0, 36.0)
	redo_btn.pressed.connect(func() -> void: get_tree().reload_current_scene())
	redo_layer.add_child(redo_btn)

	# "End turn early?" confirmation dialog — layer 20 so it floats above everything
	var confirm_layer := CanvasLayer.new()
	confirm_layer.layer = 20
	add_child(confirm_layer)
	_confirm_panel = ColorRect.new()
	_confirm_panel.color    = Color(0.06, 0.07, 0.16, 0.97)
	_confirm_panel.position = Vector2(480.0, 295.0)
	_confirm_panel.size     = Vector2(320.0, 130.0)
	_confirm_panel.visible  = false
	confirm_layer.add_child(_confirm_panel)

	var msg := Label.new()
	msg.text     = "Some units haven't acted yet.\nEnd the player turn anyway?"
	msg.position = Vector2(14.0, 16.0)
	msg.size     = Vector2(292.0, 48.0)
	msg.add_theme_font_size_override("font_size", 13)
	_confirm_panel.add_child(msg)

	var yes_btn := Button.new()
	yes_btn.text     = "End Turn"
	yes_btn.position = Vector2(14.0, 80.0)
	yes_btn.size     = Vector2(130.0, 36.0)
	yes_btn.pressed.connect(_on_confirm_end_turn)
	_confirm_panel.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text     = "Cancel"
	no_btn.position = Vector2(176.0, 80.0)
	no_btn.size     = Vector2(130.0, 36.0)
	no_btn.pressed.connect(func() -> void: _confirm_panel.visible = false)
	_confirm_panel.add_child(no_btn)

## --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	# Godot 4 input order: _input() → GUI _gui_input() → _unhandled_input().
	# By using _unhandled_input(), the StatPanel's Button / ScrollContainer
	# receive events first via _gui_input(). Only events that GUI did NOT
	# consume reach here, so we can block the world without breaking the panel UI.
	if _stat_panel.visible:
		# ESC closes the panel; everything else is swallowed to lock the world.
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_ESCAPE:
				_stat_panel.hide_panel()
		get_viewport().set_input_as_handled()
		return

	if state != CombatState.PLAYER_TURN:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_deselect()
				get_viewport().set_input_as_handled()
			KEY_A:
				if _selected_unit and _selected_unit.can_act(ATTACK_ENERGY_COST):
					_enter_attack_mode()
					get_viewport().set_input_as_handled()
			KEY_SPACE:
				_request_end_player_turn()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click:
			_handle_double_click()
		else:
			_handle_left_click()

func _handle_left_click() -> void:
	var camera: Camera3D = _camera_rig.get_camera()
	if not camera:
		return
	var cell: Vector2i = _grid.get_clicked_cell(camera, get_viewport())
	if cell == Vector2i(-1, -1):
		return

	match mode:
		PlayerMode.IDLE:
			_try_select_unit(cell)
		PlayerMode.STRIDE_MODE:
			_try_move(cell)
		PlayerMode.ATTACK_MODE:
			_try_attack(cell)

## Double-click on any unit opens the full StatPanel examine window.
func _handle_double_click() -> void:
	var camera: Camera3D = _camera_rig.get_camera()
	if not camera:
		return
	var cell: Vector2i = _grid.get_clicked_cell(camera, get_viewport())
	if cell == Vector2i(-1, -1):
		return
	var obj: Object = _grid.get_unit_at(cell)
	if obj is Unit3D:
		_stat_panel.show_for(obj as Unit3D)

## --- Player Actions ---

func _try_select_unit(cell: Vector2i) -> void:
	var obj: Object = _grid.get_unit_at(cell)
	if obj is Unit3D and obj.is_alive:
		var unit := obj as Unit3D
		if unit.data.is_player_unit:
			# Player unit: select for movement/action + show condensed info bar
			_select_unit(unit)
			_show_info_bar(unit)
		else:
			# Enemy unit: show condensed info, don't take control
			_deselect()
			_show_info_bar(unit)
	else:
		_deselect()

func _select_unit(unit: Unit3D) -> void:
	if _selected_unit:
		_selected_unit.set_selected(false)
	_selected_unit = unit
	unit.set_selected(true)
	_grid.clear_highlights()
	_grid.set_highlight(unit.grid_pos, "selected")
	if unit.can_stride():
		for cell in _grid.get_move_range(unit.grid_pos, unit.data.speed):
			_grid.set_highlight(cell, "move")
	mode = PlayerMode.STRIDE_MODE if unit.can_stride() else PlayerMode.IDLE
	_update_status()

func _deselect() -> void:
	if _selected_unit:
		_selected_unit.set_selected(false)
		_selected_unit = null
	_grid.clear_highlights()
	_stat_panel.hide_panel()
	_info_bar.hide_bar()
	_info_bar_unit = null
	mode = PlayerMode.IDLE
	_update_status()

func _try_move(cell: Vector2i) -> void:
	if not _selected_unit:
		return
	if _grid.highlighted_cells.get(cell, "") != "move":
		# Clicking a non-move cell: try selecting a different unit instead
		_try_select_unit(cell)
		return

	var old_pos: Vector2i = _selected_unit.grid_pos
	_grid.clear_occupied(old_pos)
	_selected_unit.move_to(cell)
	_grid.set_occupied(cell, _selected_unit)

	# Tween to new world position
	var tw: Tween = create_tween()
	tw.tween_property(_selected_unit, "global_position", _grid.grid_to_world(cell), 0.18)

	# Refresh highlights and stat panel (HP/energy are unchanged by movement,
	# but position in stat display updates on next explicit selection)
	_grid.clear_highlights()
	_grid.set_highlight(cell, "selected")
	mode = PlayerMode.IDLE
	_update_status()

func _enter_attack_mode() -> void:
	if not _selected_unit:
		return
	mode = PlayerMode.ATTACK_MODE
	_grid.clear_highlights()
	_grid.set_highlight(_selected_unit.grid_pos, "selected")
	for enemy in _enemy_units:
		if enemy.is_alive:
			_grid.set_highlight(enemy.grid_pos, "attack")
	_update_status()

func _try_attack(cell: Vector2i) -> void:
	if not _selected_unit:
		return
	if _grid.highlighted_cells.get(cell, "") != "attack":
		return
	var obj: Object = _grid.get_unit_at(cell)
	if not obj is Unit3D:
		return
	_attack_target = obj as Unit3D
	_initiate_attack(_selected_unit, _attack_target)

func _initiate_attack(attacker: Unit3D, target: Unit3D) -> void:
	state = CombatState.QTE_RUNNING
	mode  = PlayerMode.IDLE
	_grid.clear_highlights()
	_update_status()
	# Start lunge animation; QTE fires after the lunge reaches the target
	attacker.play_attack_anim(target.global_position)
	await get_tree().create_timer(0.09).timeout
	_qte_bar.start_qte()

func _on_qte_resolved(accuracy: float) -> void:
	if _selected_unit and _attack_target:
		var dmg: int = _calculate_damage(
			_selected_unit.data.attack, _attack_target.data.defense, accuracy)
		_selected_unit.spend_energy(ATTACK_ENERGY_COST)
		_selected_unit.has_acted = true
		_attack_target.take_damage(dmg)
		_camera_rig.trigger_shake()

	_attack_target = null

	# Don't override a WIN/LOSE state that take_damage may have set
	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	state = CombatState.PLAYER_TURN
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)
		_info_bar.refresh(_selected_unit)
	else:
		_deselect()
	_update_status()

	# Auto-end the turn if every alive player unit has used their action
	_check_auto_end_turn()

## --- End Player Turn ---

## Manually triggered by Space. Shows a confirmation dialog if any unit can still act.
func _request_end_player_turn() -> void:
	for unit in _player_units:
		if unit.is_alive and not unit.has_acted and unit.can_act(ATTACK_ENERGY_COST):
			_confirm_panel.visible = true
			return
	_end_player_turn()

## "End Turn" button in the confirmation dialog.
func _on_confirm_end_turn() -> void:
	_confirm_panel.visible = false
	_end_player_turn()

## Auto-end after each attack resolves. Fires only when no alive player can still act.
func _check_auto_end_turn() -> void:
	if state != CombatState.PLAYER_TURN:
		return
	for unit in _player_units:
		if unit.is_alive and not unit.has_acted and unit.can_act(ATTACK_ENERGY_COST):
			return  # at least one unit hasn't acted and still can
	_end_player_turn()

## Show a unit in the InfoBar and track it for post-damage refresh.
func _show_info_bar(unit: Unit3D) -> void:
	_info_bar_unit = unit
	_info_bar.show_for(unit)

func _end_player_turn() -> void:
	_deselect()
	state = CombatState.ENEMY_TURN
	_update_status()
	# Fire-and-forget coroutine — state machine blocks player input during ENEMY_TURN
	_run_enemy_turn()

## --- Enemy Turn ---

func _run_enemy_turn() -> void:
	await _process_enemy_actions()
	if state == CombatState.WIN or state == CombatState.LOSE:
		return
	# Regen energy and reset turn flags for every unit
	for unit in _player_units:
		unit.regen_energy()
		unit.reset_turn()
	for unit in _enemy_units:
		unit.regen_energy()
		unit.reset_turn()
	state = CombatState.PLAYER_TURN
	_update_status()

func _process_enemy_actions() -> void:
	for enemy in _enemy_units:
		if not enemy.is_alive:
			continue
		# Collect living player targets
		var targets: Array[Unit3D] = []
		for pu in _player_units:
			if pu.is_alive:
				targets.append(pu)
		if targets.is_empty():
			break

		var target: Unit3D = targets[randi() % targets.size()]
		var dmg: int = _calculate_damage(
			enemy.data.attack, target.data.defense, enemy.data.qte_resolution)

		# Lunge, then deal damage at the moment of impact
		enemy.play_attack_anim(target.global_position)
		await get_tree().create_timer(0.10).timeout

		target.take_damage(dmg)
		_camera_rig.trigger_shake()
		# Refresh condensed bar if the attacked unit is currently shown
		if _info_bar_unit == target:
			_info_bar.refresh(target)

		if state == CombatState.WIN or state == CombatState.LOSE:
			return

		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout

## --- Win / Lose ---

func _on_unit_died(unit: Unit3D) -> void:
	_grid.clear_occupied(unit.grid_pos)
	if _info_bar_unit == unit:
		_info_bar.hide_bar()
		_info_bar_unit = null
	_check_win_lose()

func _check_win_lose() -> void:
	var any_player_alive: bool = false
	for u in _player_units:
		if u.is_alive:
			any_player_alive = true
			break
	var any_enemy_alive: bool = false
	for u in _enemy_units:
		if u.is_alive:
			any_enemy_alive = true
			break

	if not any_enemy_alive:
		_end_combat(true)
	elif not any_player_alive:
		_end_combat(false)

func _end_combat(player_won: bool) -> void:
	state = CombatState.WIN if player_won else CombatState.LOSE
	_stat_panel.hide_panel()
	_info_bar.hide_bar()
	_info_bar_unit = null
	_update_status()

## --- Damage Formula ---
## Result scales with stat delta (+/-20 pts = 2x / 0.5x) and QTE accuracy.
func _calculate_damage(atk: int, def: int, accuracy: float) -> int:
	var delta: float     = float(atk - def)
	var stat_mult: float = clampf(1.0 + delta / 20.0, 0.5, 2.0)
	var acc_mult: float  = clampf(accuracy, 0.1, 1.0)
	return maxi(1, roundi(float(atk) * stat_mult * acc_mult))

## --- Status ---

func _update_status() -> void:
	if not _status_label:
		return
	match state:
		CombatState.PLAYER_TURN:
			match mode:
				PlayerMode.IDLE:
					_status_label.text = "PLAYER TURN — click a unit  |  double-click = examine  |  Space = end turn"
				PlayerMode.STRIDE_MODE:
					_status_label.text = "STRIDE — click blue cell to move  |  [A] attack  |  ESC cancel"
				PlayerMode.ATTACK_MODE:
					_status_label.text = "ATTACK — click a red enemy  |  ESC cancel"
		CombatState.QTE_RUNNING:
			_status_label.text = "QTE — press SPACE or click to strike!"
		CombatState.ENEMY_TURN:
			_status_label.text = "ENEMY TURN..."
		CombatState.WIN:
			_status_label.text = "** VICTORY! ** — all enemies defeated"
		CombatState.LOSE:
			_status_label.text = "** DEFEAT... ** — all allies fallen"
