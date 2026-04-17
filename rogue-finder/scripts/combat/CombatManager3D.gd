class_name CombatManager3D
extends Node3D

## --- CombatManager3D ---
## Turn state machine for the 3D combat prototype.
## Builds the entire scene in _ready() — no child nodes needed in the .tscn.
## Controls: Click to select/move, radial action menu for abilities/consumables,
##           [Enter] end turn, [ESC] deselect.
## Camera: [Q] rotate CCW, [E] rotate CW, scroll wheel zoom.
##
## "Redo" button at bottom-left reloads the scene with freshly randomized units.

const ENEMY_TURN_DELAY: float = 0.65

## Abbreviations used in floating combat text for stat buff/debuff effects.
const STAT_ABBREV: Dictionary = {
	AbilityData.Attribute.STRENGTH:  "STR",
	AbilityData.Attribute.DEXTERITY: "DEX",
	AbilityData.Attribute.COGNITION: "COG",
	AbilityData.Attribute.VITALITY:  "VIT",
	AbilityData.Attribute.WILLPOWER: "WIL",
}

## Display names for stat buffs and debuffs — [buff_name, debuff_name] per attribute.
const STAT_STATUS_NAMES: Dictionary = {
	AbilityData.Attribute.STRENGTH:  ["Empowered",  "Weakened"],
	AbilityData.Attribute.DEXTERITY: ["Hasted",     "Slowed"],
	AbilityData.Attribute.COGNITION: ["Focused",    "Muddled"],
	AbilityData.Attribute.VITALITY:  ["Fortified",  "Vulnerable"],
	AbilityData.Attribute.WILLPOWER: ["Resolute",   "Demoralized"],
}

enum CombatState { PLAYER_TURN, QTE_RUNNING, ENEMY_TURN, WIN, LOSE }
enum PlayerMode  { IDLE, STRIDE_MODE, ABILITY_TARGET_MODE, TRAVEL_DESTINATION }

var state: CombatState = CombatState.PLAYER_TURN
var mode:  PlayerMode  = PlayerMode.IDLE

var _player_units:   Array[Unit3D]      = []
var _enemy_units:    Array[Unit3D]      = []
var _selected_unit:  Unit3D             = null
var _attack_target:  Unit3D             = null
var _pending_ability: AbilityData       = null   ## set when ability chosen from menu
var _aoe_origin:     Vector2i           = Vector2i(-1, -1)  ## aimed cell for AoE abilities
var _travel_effect:  EffectData         = null   ## stored while awaiting destination pick
var _hovered_cell:   Vector2i           = Vector2i(-1, -1)  ## last cell under mouse (cone preview)

var _grid:           Grid3D             = null
var _camera_rig:     CameraController   = null
var _qte_bar:        QTEBar             = null
var _stat_panel:     StatPanel          = null
var _info_bar:       UnitInfoBar        = null
var _action_menu:    ActionMenu         = null
var _info_bar_unit:  Unit3D             = null
var _confirm_panel:  ColorRect          = null
var _status_label:   Label              = null

## --- Initialization ---

func _ready() -> void:
	_setup_environment()
	_setup_camera()
	_setup_grid()
	_setup_environment_tiles()
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

func _setup_environment_tiles() -> void:
	# Placeholder layout — will be replaced by map/encounter data
	_grid.build_walls([Vector2i(4, 3), Vector2i(4, 5), Vector2i(5, 4)])
	_grid.set_cell_type(Vector2i(2, 7), Grid3D.CellType.HAZARD)
	_grid.set_cell_type(Vector2i(7, 2), Grid3D.CellType.HAZARD)

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
	var enemy_positions: Array[Vector2i] = [Vector2i(6, 3), Vector2i(6, 5), Vector2i(7, 4)]
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

	# Radial action menu — shown on player unit selection
	_action_menu = ActionMenu.new()
	add_child(_action_menu)
	_action_menu.ability_selected.connect(_on_ability_selected)
	_action_menu.consumable_selected.connect(_on_consumable_selected)

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
	if _stat_panel.visible:
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
			KEY_SPACE:
				_request_end_player_turn()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion and mode == PlayerMode.ABILITY_TARGET_MODE \
			and _pending_ability and _pending_ability.target_shape in [
				AbilityData.TargetShape.CONE,
				AbilityData.TargetShape.ARC,
				AbilityData.TargetShape.RADIAL,
			]:
		_handle_shape_hover()
		# not marked as handled — camera controller still needs motion events

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
		PlayerMode.ABILITY_TARGET_MODE:
			_try_ability_target(cell)
		PlayerMode.TRAVEL_DESTINATION:
			_try_travel_destination(cell)

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
			_select_unit(unit)
			_show_info_bar(unit)
		else:
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
	# Open (or refresh) the radial menu for this unit
	_action_menu.open_for(unit, _camera_rig.get_camera())
	_update_status()

func _deselect() -> void:
	if _selected_unit:
		_selected_unit.set_selected(false)
		_selected_unit = null
	_grid.clear_highlights()
	_stat_panel.hide_panel()
	_info_bar.hide_bar()
	_action_menu.close()
	_info_bar_unit   = null
	_pending_ability = null
	_aoe_origin      = Vector2i(-1, -1)
	_travel_effect   = null
	_hovered_cell    = Vector2i(-1, -1)
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
	_check_hazard_damage(_selected_unit)

	# Tween to new world position
	var tw: Tween = create_tween()
	tw.tween_property(_selected_unit, "global_position", _grid.grid_to_world(cell), 0.18)

	# Refresh highlights and stat panel (HP/energy are unchanged by movement,
	# but position in stat display updates on next explicit selection)
	_grid.clear_highlights()
	_grid.set_highlight(cell, "selected")
	mode = PlayerMode.IDLE
	_update_status()

## Called when the player picks an ability from the ActionMenu.
func _on_ability_selected(ability_id: String) -> void:
	if not _selected_unit:
		return
	_pending_ability = AbilityLibrary.get_ability(ability_id)

	# SELF-targeting abilities skip the target-pick step and go straight to QTE
	if _pending_ability.target_shape == AbilityData.TargetShape.SELF:
		_initiate_action(_selected_unit, _selected_unit)
		return

	# Collect valid targets based on applicable_to
	var targets: Array[Unit3D] = []
	match _pending_ability.applicable_to:
		AbilityData.ApplicableTo.ALLY:
			for pu in _player_units:
				if pu.is_alive:
					targets.append(pu)
		AbilityData.ApplicableTo.ENEMY:
			for eu in _enemy_units:
				if eu.is_alive:
					targets.append(eu)
		AbilityData.ApplicableTo.ANY:
			for pu in _player_units:
				if pu.is_alive:
					targets.append(pu)
			for eu in _enemy_units:
				if eu.is_alive:
					targets.append(eu)

	# Highlight valid aim cells — varies by shape.
	mode = PlayerMode.ABILITY_TARGET_MODE
	_grid.clear_highlights()
	_grid.set_highlight(_selected_unit.grid_pos, "selected")
	var caster_pos := _selected_unit.grid_pos

	match _pending_ability.target_shape:
		AbilityData.TargetShape.SINGLE:
			# Highlight individual living units that are in range
			if targets.is_empty():
				_pending_ability = null
				return
			for target in targets:
				var dx: int = abs(target.grid_pos.x - caster_pos.x)
				var dy: int = abs(target.grid_pos.y - caster_pos.y)
				var dist: int = dx + dy
				if _pending_ability.tile_range == -1 or dist <= _pending_ability.tile_range:
					_grid.set_highlight(target.grid_pos, "ability_target")

		AbilityData.TargetShape.RADIAL:
			# Player picks the blast center — any cell within tile_range of caster
			for row in range(Grid3D.ROWS):
				for col in range(Grid3D.COLS):
					var cell := Vector2i(col, row)
					var dist: int = abs(cell.x - caster_pos.x) + abs(cell.y - caster_pos.y)
					if dist <= _pending_ability.tile_range:
						_grid.set_highlight(cell, "ability_target")

		AbilityData.TargetShape.CONE, AbilityData.TargetShape.ARC:
			# Player picks one of the 4 cardinal adjacent cells to set direction.
			# CONE expands to a triangle; ARC hits the 3-wide row at distance 1.
			var cardinals: Array[Vector2i] = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]
			for dir in cardinals:
				var cell := caster_pos + dir
				if _grid.is_valid(cell):
					_grid.set_highlight(cell, "ability_target")

		AbilityData.TargetShape.LINE:
			# Player picks any cell along the 4 cardinal axes up to tile_range
			var cardinals: Array[Vector2i] = [
				Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
			]
			for dir in cardinals:
				var cur := caster_pos + dir
				var steps: int = 0
				var limit: int = _pending_ability.tile_range if _pending_ability.tile_range != -1 else 999
				while _grid.is_valid(cur) and steps < limit:
					_grid.set_highlight(cur, "ability_target")
					cur = cur + dir
					steps += 1

	_update_status()

## Resolve the player clicking a cell while in ABILITY_TARGET_MODE.
func _try_ability_target(cell: Vector2i) -> void:
	if not _selected_unit or not _pending_ability:
		return
	if _grid.highlighted_cells.get(cell, "") != "ability_target":
		# Clicked outside valid aim cells — cancel and re-open menu
		_pending_ability = null
		_select_unit(_selected_unit)
		return

	match _pending_ability.target_shape:
		AbilityData.TargetShape.SINGLE:
			var obj: Object = _grid.get_unit_at(cell)
			if not obj is Unit3D:
				return
			var target := obj as Unit3D
			if not target.is_alive:
				return
			_initiate_action(_selected_unit, target)
		AbilityData.TargetShape.RADIAL, AbilityData.TargetShape.CONE, AbilityData.TargetShape.LINE, AbilityData.TargetShape.ARC:
			# Store the aimed origin cell; the QTE result will resolve the full shape
			_aoe_origin = cell
			_initiate_aoe_action(_selected_unit, _grid.grid_to_world(cell))

## Kick off a QTE for an AoE ability. No single target — uses origin world position
## for the attack animation lunge direction.
func _initiate_aoe_action(attacker: Unit3D, origin_world: Vector3) -> void:
	_attack_target = null
	state = CombatState.QTE_RUNNING
	mode  = PlayerMode.IDLE
	_grid.clear_highlights()
	_action_menu.close()
	_update_status()
	attacker.play_attack_anim(origin_world)
	await get_tree().create_timer(0.09).timeout
	var _eff_type: EffectData.EffectType = EffectData.EffectType.HARM
	if not _pending_ability.effects.is_empty():
		_eff_type = _pending_ability.effects[0].effect_type
	## For AoE FORCE abilities (e.g. windblast), project the aimed cell into screen space
	## so click-targets scatter around the actual blast centre rather than the origin corner.
	var _screen_pos: Vector2 = Vector2.ZERO
	if _eff_type == EffectData.EffectType.FORCE:
		_screen_pos = _camera_rig.get_camera().unproject_position(origin_world)
	_qte_bar.start_qte(_pending_ability.energy_cost, _pending_ability.target_shape, _eff_type, _screen_pos)

## Apply the consumable effect immediately (no QTE), then clear the slot.
func _on_consumable_selected() -> void:
	if not _selected_unit:
		return
	var con_id: String = _selected_unit.data.consumable
	if con_id == "":
		return

	var con: ConsumableData = ConsumableLibrary.get_consumable(con_id)
	match con.effect_type:
		EffectData.EffectType.MEND:
			_selected_unit.heal(con.base_value)
		EffectData.EffectType.BUFF:
			_apply_stat_delta(_selected_unit, con.target_stat, con.base_value)
		EffectData.EffectType.DEBUFF:
			_apply_stat_delta(_selected_unit, con.target_stat, -con.base_value)

	_selected_unit.data.consumable = ""
	_info_bar.refresh(_selected_unit)
	_action_menu.open_for(_selected_unit, _camera_rig.get_camera())

## Kicks off the QTE sequence. Uses _pending_ability.energy_cost for spending.
## Must only be called after _pending_ability is set.
## Stores target in _attack_target so _on_qte_resolved() can access it regardless
## of whether the entry path was self-targeting or player-picked.
func _initiate_action(attacker: Unit3D, target: Unit3D) -> void:
	_attack_target = target        ## always set here — not at call sites
	state = CombatState.QTE_RUNNING
	mode  = PlayerMode.IDLE
	_grid.clear_highlights()
	_action_menu.close()
	_update_status()
	attacker.play_attack_anim(target.global_position)
	await get_tree().create_timer(0.09).timeout
	var _eff_type: EffectData.EffectType = EffectData.EffectType.HARM
	if not _pending_ability.effects.is_empty():
		_eff_type = _pending_ability.effects[0].effect_type
	## For FORCE abilities, pass the target's screen position so the click-targets
	## QTE can scatter circles around the target unit's visual location.
	var _screen_pos: Vector2 = Vector2.ZERO
	if _eff_type == EffectData.EffectType.FORCE:
		_screen_pos = _camera_rig.get_camera().unproject_position(target.global_position)
	_qte_bar.start_qte(_pending_ability.energy_cost, _pending_ability.target_shape,
			_eff_type, _screen_pos)

func _on_qte_resolved(multiplier: float) -> void:
	if not _pending_ability:
		push_error("CombatManager3D: _on_qte_resolved called with no _pending_ability")
		state = CombatState.PLAYER_TURN
		_update_status()
		return

	var has_aoe: bool  = _aoe_origin != Vector2i(-1, -1)
	var has_target: bool = _attack_target != null

	if _selected_unit and (has_target or has_aoe):
		# Check for TRAVEL before spending energy/acting so we can enter destination mode
		var travel_eff: EffectData = null
		for eff: EffectData in _pending_ability.effects:
			if eff.effect_type == EffectData.EffectType.TRAVEL:
				travel_eff = eff
				break

		_selected_unit.spend_energy(_pending_ability.energy_cost)
		_selected_unit.has_acted = true

		if travel_eff != null:
			_pending_ability = null
			_attack_target   = null
			_aoe_origin      = Vector2i(-1, -1)
			state            = CombatState.PLAYER_TURN

			if multiplier == 0.25:
				# QTE failed — skip destination pick; energy was already spent above
				mode = PlayerMode.IDLE
				_status_label.text = "TRAVEL FAILED — repositioning lost"
				await get_tree().create_timer(1.5).timeout
				if _selected_unit and _selected_unit.is_alive:
					_select_unit(_selected_unit)
				else:
					_deselect()
				_update_status()
				_check_auto_end_turn()
				return

			# Enter destination-pick mode; effect resolves when the player clicks a tile
			_travel_effect = travel_eff
			mode           = PlayerMode.TRAVEL_DESTINATION
			_highlight_travel_destinations(_selected_unit, _travel_effect)
			_update_status()
			return
		elif has_aoe:
			var cells := _get_shape_cells(_selected_unit.grid_pos, _aoe_origin, _pending_ability)
			for unit: Unit3D in _get_units_in_cells(cells, _pending_ability.applicable_to):
				_apply_effects(_pending_ability, _selected_unit, unit, multiplier, _aoe_origin)
		else:
			_apply_effects(_pending_ability, _selected_unit, _attack_target, multiplier)

		_camera_rig.trigger_shake()

	_pending_ability = null
	_attack_target   = null
	_aoe_origin      = Vector2i(-1, -1)

	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	state = CombatState.PLAYER_TURN
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)
		_info_bar.refresh(_selected_unit)
	else:
		_deselect()
	_update_status()
	_check_auto_end_turn()

## Resolves every effect in ability.effects against target using the shared accuracy float.
## accuracy comes from the QTE result (0.0–1.0); all effects share the same roll.
## blast_origin is the aimed AoE cell — passed through to FORCE/RADIAL displacement.
func _apply_effects(ability: AbilityData, caster: Unit3D, target: Unit3D, multiplier: float,
		blast_origin: Vector2i = Vector2i(-1, -1)) -> void:
	for effect: EffectData in ability.effects:
		match effect.effect_type:
			EffectData.EffectType.HARM:
				var stat_delta: float = clampf(
					float(caster.data.attack) / float(target.data.defense), 0.5, 2.0)
				var dmg: int = maxi(1, roundi(float(effect.base_value) * stat_delta * multiplier))
				target.take_damage(dmg)
			EffectData.EffectType.MEND:
				var heal: int = maxi(1, roundi(float(effect.base_value) * 1.0 * multiplier))
				target.heal(heal)
			EffectData.EffectType.BUFF:
				var delta: int = maxi(1, roundi(float(effect.base_value) * 1.0 * multiplier))
				_apply_stat_delta(target, effect.target_stat, delta)
			EffectData.EffectType.DEBUFF:
				var delta: int = maxi(1, roundi(float(effect.base_value) * 1.0 * multiplier))
				_apply_stat_delta(target, effect.target_stat, -delta)
			EffectData.EffectType.FORCE:
				# multiplier ≤ 0.25 is the failure zone — no displacement on a miss
				if multiplier > 0.25:
					_apply_force(caster, target, effect, blast_origin)
			EffectData.EffectType.TRAVEL:
				# Handled before _apply_effects is called — see _on_qte_resolved
				pass

## Returns the raw attribute int value from a unit's CombatantData.
func _get_attribute_value(unit: Unit3D, attribute: AbilityData.Attribute) -> int:
	match attribute:
		AbilityData.Attribute.STRENGTH:  return unit.data.strength
		AbilityData.Attribute.DEXTERITY: return unit.data.dexterity
		AbilityData.Attribute.COGNITION: return unit.data.cognition
		AbilityData.Attribute.VITALITY:  return unit.data.vitality
		AbilityData.Attribute.WILLPOWER: return unit.data.willpower
		_: return 0

## Applies a +/- delta to one of a unit's core attributes.
## Clamped to [0, 5] — the defined range for all attributes.
## NOTE: stat changes are not currently reset at combat end; that is a future task.
func _apply_stat_delta(unit: Unit3D, stat: int, delta: int) -> void:
	match stat:
		AbilityData.Attribute.STRENGTH:
			unit.data.strength  = clampi(unit.data.strength  + delta, 0, 5)
		AbilityData.Attribute.DEXTERITY:
			unit.data.dexterity = clampi(unit.data.dexterity + delta, 0, 5)
		AbilityData.Attribute.COGNITION:
			unit.data.cognition = clampi(unit.data.cognition + delta, 0, 5)
		AbilityData.Attribute.VITALITY:
			unit.data.vitality  = clampi(unit.data.vitality  + delta, 0, 5)
		AbilityData.Attribute.WILLPOWER:
			unit.data.willpower = clampi(unit.data.willpower + delta, 0, 5)

	# Record the named status effect so the UI can display it
	var name_pair: Array = STAT_STATUS_NAMES.get(stat, ["Buffed", "Debuffed"])
	unit.add_stat_effect(name_pair[0] if delta > 0 else name_pair[1], stat, delta)

	# Floating combat text — green for buff, orange for debuff
	var abbrev: String = STAT_ABBREV.get(stat, "?")
	if delta > 0:
		unit.show_floating_text("+%s" % abbrev, Color(0.18, 1.0, 0.38))
	else:
		unit.show_floating_text("-%s" % abbrev, Color(1.0, 0.55, 0.0))

## --- FORCE Effect ---

## Displaces `target` up to effect.base_value tiles in the direction determined by
## effect.force_type. Stops at the grid edge or the first occupied cell.
## blast_origin is the AoE aim cell; used by RADIAL to push targets away from center.
func _apply_force(caster: Unit3D, target: Unit3D, effect: EffectData, blast_origin: Vector2i) -> void:
	var dir: Vector2i
	match effect.force_type:
		EffectData.ForceType.PUSH:
			dir = _cardinal_direction(caster.grid_pos, target.grid_pos)
		EffectData.ForceType.PULL:
			dir = _cardinal_direction(target.grid_pos, caster.grid_pos)
		EffectData.ForceType.LEFT:
			var base: Vector2i = _cardinal_direction(caster.grid_pos, target.grid_pos)
			dir = Vector2i(-base.y, base.x)   # rotate 90° left
		EffectData.ForceType.RIGHT:
			var base: Vector2i = _cardinal_direction(caster.grid_pos, target.grid_pos)
			dir = Vector2i(base.y, -base.x)   # rotate 90° right
		EffectData.ForceType.RADIAL:
			# Push away from blast center; fall back to caster if no origin stored
			var origin: Vector2i = blast_origin if blast_origin != Vector2i(-1, -1) \
				else caster.grid_pos
			dir = _cardinal_direction(origin, target.grid_pos)

	# Slide target along dir, stopping at grid edge or first occupied cell
	var dest: Vector2i = target.grid_pos
	for _i in range(effect.base_value):
		var nxt: Vector2i = dest + dir
		if not _grid.is_valid(nxt) or _grid.is_occupied(nxt):
			break
		dest = nxt

	if dest == target.grid_pos:
		return  # nowhere to move

	_grid.clear_occupied(target.grid_pos)
	target.move_to(dest)           # updates grid_pos + emits unit_moved
	_grid.set_occupied(dest, target)
	_check_hazard_damage(target)
	var tw: Tween = create_tween()
	tw.tween_property(target, "global_position", _grid.grid_to_world(dest), 0.20)

## --- TRAVEL Effect ---

## Highlights valid destination tiles for a TRAVEL effect.
## FREE: all unoccupied cells within Manhattan ≤ base_value of the caster.
## LINE: unoccupied cells along the 4 cardinal axes up to base_value, stopping at obstacles.
func _highlight_travel_destinations(unit: Unit3D, effect: EffectData) -> void:
	_grid.clear_highlights()
	_grid.set_highlight(unit.grid_pos, "selected")
	var move_range: int = effect.base_value

	if effect.movement_type == EffectData.MoveType.FREE:
		for row in range(Grid3D.ROWS):
			for col in range(Grid3D.COLS):
				var cell := Vector2i(col, row)
				var dist: int = abs(cell.x - unit.grid_pos.x) + abs(cell.y - unit.grid_pos.y)
				if dist > 0 and dist <= move_range and not _grid.is_occupied(cell):
					_grid.set_highlight(cell, "move")
	else:
		# LINE: straight-line repositioning only
		var cardinals: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]
		for dir in cardinals:
			var cur := unit.grid_pos + dir
			var steps: int = 0
			while _grid.is_valid(cur) and steps < move_range:
				if _grid.is_occupied(cur):
					break  # blocked
				_grid.set_highlight(cur, "move")
				cur = cur + dir
				steps += 1

## Resolves the player clicking a destination tile during TRAVEL_DESTINATION mode.
func _try_travel_destination(cell: Vector2i) -> void:
	if not _selected_unit or not _travel_effect:
		return
	if _grid.highlighted_cells.get(cell, "") != "move":
		# Clicked outside valid destinations — cancel travel
		_travel_effect = null
		mode = PlayerMode.IDLE
		_grid.clear_highlights()
		_update_status()
		return

	var old_pos: Vector2i = _selected_unit.grid_pos
	_grid.clear_occupied(old_pos)
	_selected_unit.move_to(cell)
	_grid.set_occupied(cell, _selected_unit)
	_check_hazard_damage(_selected_unit)
	var tw: Tween = create_tween()
	tw.tween_property(_selected_unit, "global_position", _grid.grid_to_world(cell), 0.18)

	_travel_effect = null
	mode = PlayerMode.IDLE
	_grid.clear_highlights()
	_grid.set_highlight(cell, "selected")
	_update_status()
	_check_auto_end_turn()

## --- AoE Shape Hover Preview ---

## Called on every mouse-motion event while a CONE, ARC, or RADIAL ability is being aimed.
## Replaces the static aim-range highlight with a live preview of which cells will be hit.
func _handle_shape_hover() -> void:
	var camera: Camera3D = _camera_rig.get_camera()
	if not camera or not _selected_unit:
		return
	var cell: Vector2i = _grid.get_clicked_cell(camera, get_viewport())
	if cell == _hovered_cell:
		return
	_hovered_cell = cell

	var caster_pos: Vector2i = _selected_unit.grid_pos
	_grid.clear_highlights()
	_grid.set_highlight(caster_pos, "selected")

	if _pending_ability.target_shape == AbilityData.TargetShape.RADIAL:
		# If cursor is inside the valid aim range, show the blast footprint there.
		# Otherwise fall back to drawing the full aim range so the player knows where to click.
		var dist: int = abs(cell.x - caster_pos.x) + abs(cell.y - caster_pos.y)
		var limit: int = _pending_ability.tile_range
		if _grid.is_valid(cell) and (limit == -1 or dist <= limit):
			for c: Vector2i in _get_shape_cells(caster_pos, cell, _pending_ability):
				_grid.set_highlight(c, "ability_target")
		else:
			# Restore the plain aim-range highlight when cursor is out of range
			for row in range(Grid3D.ROWS):
				for col in range(Grid3D.COLS):
					var aim := Vector2i(col, row)
					var d: int = abs(aim.x - caster_pos.x) + abs(aim.y - caster_pos.y)
					if limit == -1 or d <= limit:
						_grid.set_highlight(aim, "ability_target")
	else:
		# CONE / ARC: show full shape when over a direction root; 4 roots otherwise.
		var cardinals: Array[Vector2i] = [
			Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
		]
		var over_root: bool = false
		for dir: Vector2i in cardinals:
			if caster_pos + dir == cell:
				over_root = true
				break

		if over_root:
			for c: Vector2i in _get_shape_cells(caster_pos, cell, _pending_ability):
				_grid.set_highlight(c, "ability_target")
		else:
			for dir: Vector2i in cardinals:
				var root: Vector2i = caster_pos + dir
				if _grid.is_valid(root):
					_grid.set_highlight(root, "ability_target")

## --- AoE Shape Helpers ---

## Returns the cardinal direction from `from` to `to`, snapping to the dominant axis.
## e.g. (3, 1) → (1, 0);  (1, 3) → (0, 1)
func _cardinal_direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var diff := to - from
	if abs(diff.x) >= abs(diff.y):
		return Vector2i(sign(diff.x), 0)
	else:
		return Vector2i(0, sign(diff.y))

## Returns every grid cell covered by the ability's shape, given caster and aim positions.
## RADIAL: diamond ≤ 2 Manhattan from origin. Without passthrough, only pure cardinal
##         distance-2 cells are blocked (by a unit sitting directly between them and origin).
##         Diagonal distance-2 cells are never blocked — no clean intermediate exists.
## ARC:    3-wide row at distance 1 — no passthrough logic (arc always hits all 3).
## CONE:   stem (1) → 3-wide crossbar (2) → 5-wide back row (3). Without passthrough,
##         a unit at the stem blocks depth 2 and 3.
## LINE:   straight ray up to tile_range; stops at first unit unless passthrough.
func _get_shape_cells(caster_pos: Vector2i, origin_pos: Vector2i, ability: AbilityData) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	match ability.target_shape:
		AbilityData.TargetShape.RADIAL:
			var radius: int = 2  # fixed by design spec ("5 wide × 5 tall" diamond)
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					if abs(dx) + abs(dy) > radius:
						continue
					var cell := Vector2i(origin_pos.x + dx, origin_pos.y + dy)
					if not _grid.is_valid(cell):
						continue
					# Without passthrough, only pure cardinal distance-2 cells can be blocked
					# (a unit directly between the origin and that cell stops the blast).
					# Diagonal distance-2 cells have no clean intermediate — never blocked.
					if not ability.passthrough and abs(dx) + abs(dy) == 2 \
							and (dx == 0 or dy == 0):
						var mid := Vector2i(origin_pos.x + sign(dx), origin_pos.y + sign(dy))
						if _grid.is_occupied(mid):
							continue
					cells.append(cell)
		AbilityData.TargetShape.ARC:
			# 3-cell sweep: left-of-root, root, right-of-root — all at distance 1.
			var dir: Vector2i  = _cardinal_direction(caster_pos, origin_pos)
			var root: Vector2i = caster_pos + dir
			var perp: Vector2i = Vector2i(dir.y, dir.x)
			for c: Vector2i in [root - perp, root, root + perp]:
				if _grid.is_valid(c):
					cells.append(c)
		AbilityData.TargetShape.CONE:
			# Expanding shape: stem (d1), 3-wide crossbar (d2), 5-wide back row (d3).
			# Without passthrough, a unit at d1 blocks d2 and d3.
			var dir: Vector2i  = _cardinal_direction(caster_pos, origin_pos)
			var perp: Vector2i = Vector2i(dir.y, dir.x)
			var d1: Vector2i   = caster_pos + dir
			var d2: Vector2i   = d1 + dir
			var d3: Vector2i   = d2 + dir
			if _grid.is_valid(d1):
				cells.append(d1)
			if ability.passthrough or not _grid.is_occupied(d1):
				for c: Vector2i in [d2 - perp, d2, d2 + perp]:
					if _grid.is_valid(c):
						cells.append(c)
				for c: Vector2i in [d3 - perp * 2, d3 - perp, d3, d3 + perp, d3 + perp * 2]:
					if _grid.is_valid(c):
						cells.append(c)
		AbilityData.TargetShape.LINE:
			var dir := _cardinal_direction(caster_pos, origin_pos)
			var cur := caster_pos + dir
			var steps: int = 0
			var limit: int = ability.tile_range if ability.tile_range != -1 else 999
			while _grid.is_valid(cur) and steps < limit:
				cells.append(cur)
				if _grid.is_occupied(cur) and not ability.passthrough:
					break  # blocked by a unit; stop unless passthrough
				cur = cur + dir
				steps += 1
	return cells

## Filters a cell list to living units that match the ability's applicable_to.
func _get_units_in_cells(cells: Array[Vector2i], applicable_to: AbilityData.ApplicableTo) -> Array[Unit3D]:
	var result: Array[Unit3D] = []
	for cell in cells:
		var obj: Object = _grid.get_unit_at(cell)
		if not obj is Unit3D:
			continue
		var unit := obj as Unit3D
		if not unit.is_alive:
			continue
		var is_player: bool = unit.data.is_player_unit
		match applicable_to:
			AbilityData.ApplicableTo.ALLY:
				if is_player:
					result.append(unit)
			AbilityData.ApplicableTo.ENEMY:
				if not is_player:
					result.append(unit)
			AbilityData.ApplicableTo.ANY:
				result.append(unit)
	return result

## --- End Player Turn ---

## Manually triggered by Space. Shows a confirmation dialog if any unit can still act.
func _request_end_player_turn() -> void:
	for unit in _player_units:
		if unit.is_alive and _unit_can_still_act(unit):
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
		if unit.is_alive and _unit_can_still_act(unit):
			return
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
	# Regen energy and reset turn flags for every unit; hazard damage on player units here
	# (this is the effective start-of-player-turn hook — no per-unit player turn callback exists)
	for unit in _player_units:
		unit.regen_energy()
		unit.reset_turn()
		_check_hazard_damage(unit)
	if state == CombatState.WIN or state == CombatState.LOSE:
		return
	for unit in _enemy_units:
		unit.regen_energy()
		unit.reset_turn()
	state = CombatState.PLAYER_TURN
	_update_status()

func _process_enemy_actions() -> void:
	for enemy in _enemy_units:
		if not enemy.is_alive:
			continue

		_check_hazard_damage(enemy)
		if not enemy.is_alive:
			continue

		# --- 1. Target selection ---
		var targets: Array[Unit3D] = []
		for pu in _player_units:
			if pu.is_alive:
				targets.append(pu)
		if targets.is_empty():
			break
		var target: Unit3D = targets[randi() % targets.size()]

		# --- 2. Consumable use (50% chance when HP < 50%) ---
		if enemy.data.consumable != "":
			var hp_pct: float = float(enemy.current_hp) / float(enemy.data.hp_max)
			if hp_pct < 0.5 and randi() % 2 == 0:
				var con: ConsumableData = ConsumableLibrary.get_consumable(enemy.data.consumable)
				match con.effect_type:
					EffectData.EffectType.MEND:
						enemy.heal(con.base_value)
					EffectData.EffectType.BUFF:
						_apply_stat_delta(enemy, con.target_stat, con.base_value)
					EffectData.EffectType.DEBUFF:
						_apply_stat_delta(enemy, con.target_stat, -con.base_value)
				enemy.data.consumable = ""
				enemy.show_action_text(con.consumable_name)

		# --- 3. Movement (Stride) — greedy Manhattan minimization ---
		if not enemy.has_moved:
			var move_cells: Array[Vector2i] = _grid.get_move_range(enemy.grid_pos, enemy.data.speed)
			var best_cell: Vector2i = enemy.grid_pos
			var best_dist: int = abs(enemy.grid_pos.x - target.grid_pos.x) \
					+ abs(enemy.grid_pos.y - target.grid_pos.y)
			for cell in move_cells:
				var dist: int = abs(cell.x - target.grid_pos.x) + abs(cell.y - target.grid_pos.y)
				if dist < best_dist:
					best_dist = dist
					best_cell = cell
			if best_cell != enemy.grid_pos:
				_grid.clear_occupied(enemy.grid_pos)
				enemy.move_to(best_cell)
				_grid.set_occupied(best_cell, enemy)
				var tw: Tween = create_tween()
				tw.tween_property(enemy, "global_position", _grid.grid_to_world(best_cell), 0.22)
				await tw.finished  # must complete before lunge anim starts on same property
				_check_hazard_damage(enemy)
				if not enemy.is_alive:
					await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
					continue

		# --- 4. Ability selection ---
		var post_dist: int = abs(enemy.grid_pos.x - target.grid_pos.x) \
				+ abs(enemy.grid_pos.y - target.grid_pos.y)
		var affordable: Array[AbilityData] = []
		for ability_id: String in enemy.data.abilities:
			if ability_id == "":
				continue
			var ab: AbilityData = AbilityLibrary.get_ability(ability_id)
			if enemy.current_energy < ab.energy_cost:
				continue
			if ab.applicable_to != AbilityData.ApplicableTo.ENEMY \
					and ab.applicable_to != AbilityData.ApplicableTo.ANY:
				continue
			# SELF shape always reaches the caster — skip distance gate
			if ab.target_shape != AbilityData.TargetShape.SELF \
					and ab.tile_range != -1 and post_dist > ab.tile_range:
				continue
			affordable.append(ab)

		if affordable.is_empty():
			await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
			continue

		# --- 5. Execute ability ---
		var chosen: AbilityData = affordable[randi() % affordable.size()]
		var multiplier: float = _qte_resolution_to_multiplier(enemy.data.qte_resolution)
		enemy.spend_energy(chosen.energy_cost)

		enemy.show_action_text(chosen.ability_name)

		match chosen.target_shape:
			AbilityData.TargetShape.SELF:
				enemy.play_attack_anim(enemy.global_position)
				await get_tree().create_timer(0.10).timeout
				_apply_effects(chosen, enemy, enemy, multiplier)

			AbilityData.TargetShape.SINGLE:
				enemy.play_attack_anim(target.global_position)
				await get_tree().create_timer(0.10).timeout
				_apply_effects(chosen, enemy, target, multiplier)

			_:  # AoE: RADIAL, CONE, ARC, LINE
				var best_origin: Vector2i = _pick_best_aoe_origin(enemy, chosen)
				var origin_world: Vector3 = _grid.grid_to_world(best_origin)
				enemy.play_attack_anim(origin_world)
				await get_tree().create_timer(0.10).timeout
				var cells: Array[Vector2i] = _get_shape_cells(enemy.grid_pos, best_origin, chosen)
				## applicable_to is from the caster's perspective:
				## ENEMY = hits the opposing side (player units); ANY = hits all; ALLY = hits own side
				for cell in cells:
					var obj: Object = _grid.get_unit_at(cell)
					if not obj is Unit3D:
						continue
					var hit_unit := obj as Unit3D
					if not hit_unit.is_alive:
						continue
					var should_hit: bool = false
					match chosen.applicable_to:
						AbilityData.ApplicableTo.ENEMY:
							should_hit = hit_unit.data.is_player_unit
						AbilityData.ApplicableTo.ANY:
							should_hit = true
						AbilityData.ApplicableTo.ALLY:
							should_hit = not hit_unit.data.is_player_unit
					if should_hit:
						_apply_effects(chosen, enemy, hit_unit, multiplier, best_origin)

		_camera_rig.trigger_shake()
		if _info_bar_unit != null:
			_info_bar.refresh(_info_bar_unit)

		if state == CombatState.WIN or state == CombatState.LOSE:
			return

		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout

## Picks the AoE origin cell that maximizes living player units hit (random tiebreak).
## For RADIAL, scans all cells within tile_range of the caster.
## For CONE/ARC/LINE, tests the 4 cardinal roots adjacent to the caster.
func _pick_best_aoe_origin(enemy: Unit3D, ability: AbilityData) -> Vector2i:
	var candidates: Array[Vector2i] = []
	var caster_pos: Vector2i = enemy.grid_pos

	match ability.target_shape:
		AbilityData.TargetShape.RADIAL:
			var limit: int = ability.tile_range if ability.tile_range != -1 else 999
			for row in range(Grid3D.ROWS):
				for col in range(Grid3D.COLS):
					var cell := Vector2i(col, row)
					var dist: int = abs(cell.x - caster_pos.x) + abs(cell.y - caster_pos.y)
					if dist <= limit:
						candidates.append(cell)
		_:  # CONE, ARC, LINE — try each of the 4 cardinal roots
			for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var cell := caster_pos + dir
				if _grid.is_valid(cell):
					candidates.append(cell)

	if candidates.is_empty():
		return caster_pos

	var best: Array[Vector2i] = []
	var best_count: int = -1
	for cand in candidates:
		var cells: Array[Vector2i] = _get_shape_cells(caster_pos, cand, ability)
		var count: int = 0
		for cell in cells:
			var obj: Object = _grid.get_unit_at(cell)
			if obj is Unit3D:
				var u := obj as Unit3D
				if not u.is_alive:
					continue
				# Count from the caster's perspective: ENEMY means the opposing side (players)
				match ability.applicable_to:
					AbilityData.ApplicableTo.ENEMY:
						if u.data.is_player_unit:
							count += 1
					AbilityData.ApplicableTo.ANY:
						count += 1
					AbilityData.ApplicableTo.ALLY:
						if not u.data.is_player_unit:
							count += 1
		if count > best_count:
			best_count = count
			best = [cand]
		elif count == best_count:
			best.append(cand)

	return best[randi() % best.size()]

## --- Hazard Damage ---

func _check_hazard_damage(unit: Unit3D) -> void:
	if _grid.is_hazard(unit.grid_pos) and unit.is_alive:
		unit.take_damage(2)
		_camera_rig.trigger_shake()
		_check_win_lose()

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

## --- Helpers ---

## Maps enemy qte_resolution stat to the nearest multiplier tier.
## Mirrors the zone thresholds the player QTE bar uses.
func _qte_resolution_to_multiplier(qte_res: float) -> float:
	if qte_res >= 0.85: return 1.25
	if qte_res >= 0.60: return 1.0
	if qte_res >= 0.30: return 0.75
	return 0.25

## Returns true if the unit has not yet acted AND can afford at least one slotted ability.
func _unit_can_still_act(unit: Unit3D) -> bool:
	if unit.has_acted:
		return false
	for ability_id in unit.data.abilities:
		if ability_id == "":
			continue
		var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
		if unit.current_energy >= ability.energy_cost:
			return true
	return false

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
					_status_label.text = "STRIDE — click blue cell to move  |  ESC cancel"
				PlayerMode.ABILITY_TARGET_MODE:
					var aname: String = _pending_ability.ability_name if _pending_ability else "Ability"
					_status_label.text = "%s — click a purple target  |  ESC cancel" % aname
				PlayerMode.TRAVEL_DESTINATION:
					_status_label.text = "REPOSITION — click a blue tile  |  ESC cancel"
		CombatState.QTE_RUNNING:
			_status_label.text = "QTE — press SPACE or click to strike!"
		CombatState.ENEMY_TURN:
			_status_label.text = "ENEMY TURN..."
		CombatState.WIN:
			_status_label.text = "** VICTORY! ** — all enemies defeated"
		CombatState.LOSE:
			_status_label.text = "** DEFEAT... ** — all allies fallen"
