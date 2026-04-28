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

const ENEMY_TURN_DELAY:     float = 0.65
const RECRUIT_ENERGY_COST: int   = 3

## Abbreviations used in floating combat text for stat buff/debuff effects.
const STAT_ABBREV: Dictionary = {
	AbilityData.Attribute.STRENGTH:           "STR",
	AbilityData.Attribute.DEXTERITY:          "DEX",
	AbilityData.Attribute.COGNITION:          "COG",
	AbilityData.Attribute.VITALITY:           "VIT",
	AbilityData.Attribute.WILLPOWER:          "WIL",
	AbilityData.Attribute.PHYSICAL_ARMOR_MOD: "P.ARM",
	AbilityData.Attribute.MAGIC_ARMOR_MOD:    "M.ARM",
}

## Display names for stat buffs and debuffs — [buff_name, debuff_name] per attribute.
const STAT_STATUS_NAMES: Dictionary = {
	AbilityData.Attribute.STRENGTH:           ["Empowered",  "Weakened"],
	AbilityData.Attribute.DEXTERITY:          ["Hasted",     "Slowed"],
	AbilityData.Attribute.COGNITION:          ["Focused",    "Muddled"],
	AbilityData.Attribute.VITALITY:           ["Fortified",  "Vulnerable"],
	AbilityData.Attribute.WILLPOWER:          ["Resolute",   "Demoralized"],
	AbilityData.Attribute.PHYSICAL_ARMOR_MOD: ["P.Hardened", "P.Cracked"],
	AbilityData.Attribute.MAGIC_ARMOR_MOD:    ["M.Warded",   "M.Exposed"],
}

enum CombatState { PLAYER_TURN, QTE_RUNNING, ENEMY_TURN, WIN, LOSE }
enum PlayerMode  { IDLE, STRIDE_MODE, ABILITY_TARGET_MODE, TRAVEL_DESTINATION, RECRUIT_TARGET_MODE }

## Emitted when a Recruit QTE succeeds — external listeners can hook this.
signal recruit_attempt_succeeded(target: Unit3D)

## Internal one-shot signals for the blocking rename and bench-full modal flows.
signal _recruit_rename_confirmed
signal _bench_full_resolved

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

var _attr_snapshots: Dictionary         = {}  ## per-unit attribute baseline; restored at combat end
var _debug_menu:     CanvasLayer        = null

var _recruit_caster:         Unit3D      = null
var _recruit_bar:            RecruitBar  = null
var _recruit_odds_layer:     CanvasLayer = null
var _recruit_odds_label_node: Label      = null

var _grid:           Grid3D             = null
var _camera_rig:     CameraController   = null
var _qte_bar:        QTEBar             = null
var _stat_panel:     StatPanel          = null
var _info_bar:       UnitInfoBar        = null
var _action_menu:    CombatActionPanel  = null
var _info_bar_unit:  Unit3D             = null
var _hover_cell:     Vector2i           = Vector2i(-1, -1)
var _confirm_panel:    ColorRect          = null
var _status_label:     Label              = null
var _end_combat_screen: EndCombatScreen   = null

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
	if GameState.test_room_mode:
		_setup_test_room_units()
		return

	var unit_scene: PackedScene = preload("res://scenes/combat/Unit3D.tscn")

	# --- Player units — driven by GameState.party ---
	# index 0 = PC, 1-2 = allies. Dead members are skipped so fewer than 3 may spawn.
	var positions: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 5), Vector2i(0, 4)]
	var pos_idx: int = 0
	for cd in GameState.party:
		if cd.is_dead:
			continue
		var unit: Unit3D = unit_scene.instantiate()
		add_child(unit)
		unit.setup(cd, positions[pos_idx])
		unit.global_position = _grid.grid_to_world(positions[pos_idx])
		_grid.set_occupied(positions[pos_idx], unit)
		unit.unit_died.connect(_on_unit_died)
		_player_units.append(unit)
		# Snapshot attributes so stat-delta mutations are rolled back at combat end
		_attr_snapshots[unit] = {
			"strength":           cd.strength,
			"dexterity":          cd.dexterity,
			"cognition":          cd.cognition,
			"vitality":           cd.vitality,
			"willpower":          cd.willpower,
			"physical_armor_mod": cd.physical_armor_mod,
			"magic_armor_mod":    cd.magic_armor_mod,
		}
		pos_idx += 1

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

## --- Test Room ---

## Routes to the right scenario based on GameState.test_room_kind.
## Default ("armor_showcase") preserves the original 3v3 dual-armor demo.
func _setup_test_room_units() -> void:
	match GameState.test_room_kind:
		"armor_mod":
			_spawn_test_room(_armor_mod_player_defs(), _armor_mod_enemy_defs())
		"recruit_test":
			_spawn_test_room(_recruit_test_player_defs(), _recruit_test_enemy_defs())
		_:
			_spawn_test_room(_armor_showcase_player_defs(), _armor_showcase_enemy_defs())

## Generic spawner — given two lists of combatant definitions, build the 3v3
## board, register attribute snapshots for player units, and connect death signals.
## Both scenarios share the same 6-cell positional layout.
func _spawn_test_room(player_defs: Array[Dictionary], enemy_defs: Array[Dictionary]) -> void:
	var unit_scene: PackedScene = preload("res://scenes/combat/Unit3D.tscn")

	var player_positions: Array[Vector2i] = [Vector2i(1, 3), Vector2i(1, 5), Vector2i(0, 4)]
	for i in player_defs.size():
		var cd: CombatantData = _make_test_combatant(player_defs[i])
		var unit: Unit3D = unit_scene.instantiate()
		add_child(unit)
		unit.setup(cd, player_positions[i])
		unit.global_position = _grid.grid_to_world(player_positions[i])
		_grid.set_occupied(player_positions[i], unit)
		unit.unit_died.connect(_on_unit_died)
		_player_units.append(unit)
		_attr_snapshots[unit] = {
			"strength": cd.strength, "dexterity": cd.dexterity, "cognition": cd.cognition,
			"vitality": cd.vitality, "willpower": cd.willpower,
			"physical_armor_mod": cd.physical_armor_mod,
			"magic_armor_mod":    cd.magic_armor_mod,
		}

	var enemy_positions: Array[Vector2i] = [Vector2i(6, 3), Vector2i(6, 5), Vector2i(7, 4)]
	for i in enemy_defs.size():
		var cd: CombatantData = _make_test_combatant(enemy_defs[i])
		var unit: Unit3D = unit_scene.instantiate()
		add_child(unit)
		unit.setup(cd, enemy_positions[i])
		unit.global_position = _grid.grid_to_world(enemy_positions[i])
		_grid.set_occupied(enemy_positions[i], unit)
		unit.unit_died.connect(_on_unit_died)
		_enemy_units.append(unit)

## --- Armor Showcase scenario (original test room) ---
## Player team covers physical + magic damage; enemies each emphasize one armor type.

func _armor_showcase_player_defs() -> Array[Dictionary]:
	return [
		{
			"name": "Kara", "archetype": "RogueFinder", "kindred": "Gnome",
			"class": "arcanist", "is_player": true,
			"str": 4, "dex": 4, "cog": 8, "wil": 6, "vit": 4,
			"phys_arm": 2, "magic_arm": 2,
			"abilities": ["arcane_bolt", "fireball", "acid_splash", "gadget_spark"],
			"qte": 0.0,
		},
		{
			"name": "Brak", "archetype": "test_ally", "kindred": "Half-Orc",
			"class": "vanguard", "is_player": true,
			"str": 8, "dex": 2, "cog": 2, "wil": 3, "vit": 6,
			"phys_arm": 2, "magic_arm": 2,
			"abilities": ["tower_slam", "heavy_strike", "sweep", "shove"],
			"qte": 0.0,
		},
		{
			"name": "Wren", "archetype": "test_ally", "kindred": "Human",
			"class": "prowler", "is_player": true,
			"str": 5, "dex": 7, "cog": 4, "wil": 4, "vit": 4,
			"phys_arm": 2, "magic_arm": 2,
			"abilities": ["slipshot", "backstab", "crippling_shot", "quick_shot"],
			"qte": 0.0,
		},
	]

func _armor_showcase_enemy_defs() -> Array[Dictionary]:
	return [
		{
			## High physical armor — physical attacks barely scratch it; magic melts it.
			"name": "Iron Wall", "archetype": "test_enemy", "kindred": "Half-Orc",
			"class": "vanguard", "is_player": false,
			"str": 7, "dex": 2, "cog": 2, "wil": 3, "vit": 7,
			"phys_arm": 12, "magic_arm": 2,
			"abilities": ["heavy_strike", "shove", "sweep", "taunt"],
			"qte": 0.3,
		},
		{
			## High magic armor — magic spells fizzle; physical hits land hard.
			"name": "Arcane Shell", "archetype": "test_enemy", "kindred": "Gnome",
			"class": "arcanist", "is_player": false,
			"str": 3, "dex": 4, "cog": 8, "wil": 6, "vit": 4,
			"phys_arm": 2, "magic_arm": 12,
			"abilities": ["fireball", "fire_breath", "acid_splash", "smoke_bomb"],
			"qte": 0.6,
		},
		{
			## Balanced — both armor types moderate; neither damage type has a free ride.
			"name": "Balanced Guard", "archetype": "test_enemy", "kindred": "Dwarf",
			"class": "warden", "is_player": false,
			"str": 6, "dex": 3, "cog": 3, "wil": 5, "vit": 6,
			"phys_arm": 6, "magic_arm": 6,
			"abilities": ["shield_bash", "sweep", "windblast", "yank"],
			"qte": 0.5,
		},
	]

## --- Armor Mod scenario ---
## Boran owns stone_guard (PHYSICAL_ARMOR_MOD +2). Velis owns divine_ward
## (MAGIC_ARMOR_MOD +2). Rune is a pure magic caster used both as damage source
## and as a vulnerable target for incoming magic threats. Enemies hit hard with
## a mix of physical and magic so the armor mods are consequential, not cosmetic.

func _armor_mod_player_defs() -> Array[Dictionary]:
	return [
		{
			"name": "Boran", "archetype": "test_ally", "kindred": "Dwarf",
			"class": "vanguard", "is_player": true,
			"str": 7, "dex": 2, "cog": 2, "wil": 4, "vit": 6,
			"phys_arm": 3, "magic_arm": 2,
			"abilities": ["stone_guard", "tower_slam", "heavy_strike", "shove"],
			"qte": 0.0,
		},
		{
			"name": "Velis", "archetype": "test_ally", "kindred": "Human",
			"class": "warden", "is_player": true,
			"str": 4, "dex": 3, "cog": 3, "wil": 8, "vit": 5,
			"phys_arm": 3, "magic_arm": 2,
			"abilities": ["divine_ward", "bless", "lay_on_hands", "rallying_shout"],
			"qte": 0.0,
		},
		{
			"name": "Rune", "archetype": "test_ally", "kindred": "Gnome",
			"class": "arcanist", "is_player": true,
			"str": 2, "dex": 4, "cog": 9, "wil": 5, "vit": 3,
			"phys_arm": 2, "magic_arm": 2,
			"abilities": ["arcane_bolt", "fireball", "fire_breath", "acid_splash"],
			"qte": 0.0,
		},
	]

func _armor_mod_enemy_defs() -> Array[Dictionary]:
	return [
		{
			## Heavy physical pressure — Boran's stone_guard is the natural counter.
			"name": "Stone Bruiser", "archetype": "test_enemy", "kindred": "Half-Orc",
			"class": "vanguard", "is_player": false,
			"str": 8, "dex": 2, "cog": 2, "wil": 3, "vit": 7,
			"phys_arm": 4, "magic_arm": 4,
			"abilities": ["heavy_strike", "sweep", "shove", "taunt"],
			"qte": 0.4,
		},
		{
			## Heavy magic pressure — Velis's divine_ward is the natural counter.
			"name": "Pyromancer", "archetype": "test_enemy", "kindred": "Gnome",
			"class": "arcanist", "is_player": false,
			"str": 3, "dex": 4, "cog": 8, "wil": 6, "vit": 4,
			"phys_arm": 4, "magic_arm": 4,
			"abilities": ["fireball", "fire_breath", "acid_splash", "smoke_bomb"],
			"qte": 0.6,
		},
		{
			## Mixed threat — forces the player to time both buffs across turns.
			"name": "Twin Threat", "archetype": "test_enemy", "kindred": "Dwarf",
			"class": "warden", "is_player": false,
			"str": 6, "dex": 3, "cog": 6, "wil": 5, "vit": 6,
			"phys_arm": 4, "magic_arm": 4,
			"abilities": ["strike", "arcane_bolt", "sweep", "fire_breath"],
			"qte": 0.5,
		},
	]

func _make_test_combatant(def: Dictionary) -> CombatantData:
	var cd := CombatantData.new()
	cd.character_name = def["name"]
	cd.archetype_id   = def["archetype"]
	cd.is_player_unit = def["is_player"]
	cd.kindred        = def["kindred"]
	cd.unit_class     = def["class"]
	cd.strength       = def["str"]
	cd.dexterity      = def["dex"]
	cd.cognition      = def["cog"]
	cd.willpower      = def["wil"]
	cd.vitality       = def["vit"]
	cd.physical_armor = def["phys_arm"]
	cd.magic_armor    = def["magic_arm"]
	cd.qte_resolution = def["qte"]
	cd.feat_ids       = []
	var abs: Array[String] = []
	for a in def["abilities"]:
		abs.append(str(a))
	cd.abilities      = abs
	cd.ability_pool   = abs.duplicate()
	# "hp" key overrides current_hp (used by recruit_test to force 1 HP enemies)
	cd.current_hp     = def.get("hp", cd.hp_max)
	cd.current_energy = cd.energy_max
	return cd

## --- Recruit Test scenario ---
## RogueFinder with high HP and energy vs 3 weaklings at 1 HP — fast recruit loop for QTE testing.

func _recruit_test_player_defs() -> Array[Dictionary]:
	return [
		{
			"name": "The RogueFinder", "archetype": "RogueFinder", "kindred": "Human",
			"class": "prowler", "is_player": true,
			"str": 4, "dex": 4, "cog": 4, "wil": 4, "vit": 10,
			"phys_arm": 5, "magic_arm": 5,
			"abilities": ["slipshot", "quick_shot", "backstab", "crippling_shot"],
			"qte": 0.0,
		},
		{
			"name": "Ally A", "archetype": "test_ally", "kindred": "Human",
			"class": "vanguard", "is_player": true,
			"str": 4, "dex": 3, "cog": 3, "wil": 3, "vit": 6,
			"phys_arm": 3, "magic_arm": 2,
			"abilities": ["heavy_strike", "shove", "sweep", "taunt"],
			"qte": 0.0,
		},
		{
			"name": "Ally B", "archetype": "test_ally", "kindred": "Human",
			"class": "warden", "is_player": true,
			"str": 3, "dex": 3, "cog": 3, "wil": 5, "vit": 5,
			"phys_arm": 3, "magic_arm": 2,
			"abilities": ["bless", "lay_on_hands", "rallying_shout", "shield_bash"],
			"qte": 0.0,
		},
	]

func _recruit_test_enemy_defs() -> Array[Dictionary]:
	return [
		{
			## 1 HP — trivially recruitable; low qte so they barely dodge
			"name": "Whelp A", "archetype": "grunt", "kindred": "Human",
			"class": "vanguard", "is_player": false,
			"str": 2, "dex": 2, "cog": 2, "wil": 2, "vit": 1,
			"phys_arm": 0, "magic_arm": 0,
			"abilities": ["strike", "heavy_strike", "shove", "sweep"],
			"qte": 0.05, "hp": 1,
		},
		{
			"name": "Whelp B", "archetype": "grunt", "kindred": "Human",
			"class": "vanguard", "is_player": false,
			"str": 2, "dex": 2, "cog": 2, "wil": 2, "vit": 1,
			"phys_arm": 0, "magic_arm": 0,
			"abilities": ["strike", "heavy_strike", "shove", "sweep"],
			"qte": 0.05, "hp": 1,
		},
		{
			"name": "Whelp C", "archetype": "grunt", "kindred": "Human",
			"class": "vanguard", "is_player": false,
			"str": 2, "dex": 2, "cog": 2, "wil": 2, "vit": 1,
			"phys_arm": 0, "magic_arm": 0,
			"abilities": ["strike", "heavy_strike", "shove", "sweep"],
			"qte": 0.05, "hp": 1,
		},
	]

func _setup_ui() -> void:
	_qte_bar = preload("res://scenes/combat/QTEBar.tscn").instantiate()
	add_child(_qte_bar)

	# Full examine panel — opened only on double-click
	_stat_panel = StatPanel.new()
	add_child(_stat_panel)

	# Condensed unit info strip — shown on single-click selection
	_info_bar = UnitInfoBar.new()
	add_child(_info_bar)

	# Side panel — shown on player unit selection
	_action_menu = CombatActionPanel.new()
	add_child(_action_menu)
	_action_menu.ability_selected.connect(_on_ability_selected)
	_action_menu.consumable_selected.connect(_on_consumable_selected)
	_action_menu.recruit_selected.connect(_on_recruit_selected)

	_recruit_bar = preload("res://scenes/combat/RecruitBar.tscn").instantiate()
	add_child(_recruit_bar)

	# Layer for the hover odds label shown over teal-highlighted enemies
	_recruit_odds_layer       = CanvasLayer.new()
	_recruit_odds_layer.layer = 6
	add_child(_recruit_odds_layer)

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

	_end_combat_screen = EndCombatScreen.new()
	add_child(_end_combat_screen)

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
				if mode == PlayerMode.RECRUIT_TARGET_MODE:
					_cancel_recruit_targeting()
				else:
					_deselect()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_request_end_player_turn()
				get_viewport().set_input_as_handled()
			KEY_K:
				# Debug: instant-kill all enemies to test the victory screen
				for u in _enemy_units:
					if u.is_alive:
						u.take_damage(9999)
				get_viewport().set_input_as_handled()
			KEY_T:
				_toggle_debug_menu()
				get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		_handle_unit_hover()
		if mode == PlayerMode.ABILITY_TARGET_MODE \
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

func _handle_unit_hover() -> void:
	if state == CombatState.QTE_RUNNING:
		return
	var camera: Camera3D = _camera_rig.get_camera()
	if not camera:
		return
	var cell: Vector2i = _grid.get_clicked_cell(camera, get_viewport())
	if cell == _hover_cell:
		return
	_hover_cell = cell
	var obj: Object = _grid.get_unit_at(cell)
	if obj is Unit3D and (obj as Unit3D).is_alive:
		_info_bar_unit = obj as Unit3D
		_info_bar.show_for(_info_bar_unit)
	else:
		_info_bar_unit = null
		_info_bar.hide_bar()

	# In RECRUIT_TARGET_MODE show qualitative odds above teal-highlighted enemies
	if mode == PlayerMode.RECRUIT_TARGET_MODE and _recruit_caster != null:
		if obj is Unit3D:
			var hovered := obj as Unit3D
			if hovered.is_alive and not hovered.data.is_player_unit \
					and _grid.highlighted_cells.get(hovered.grid_pos, "") == "recruit_target":
				_show_recruit_odds(hovered)
				return
		_clear_recruit_odds_label()

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
		PlayerMode.RECRUIT_TARGET_MODE:
			_try_recruit_target(cell)

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
	if obj is Unit3D and (obj as Unit3D).is_alive:
		var unit := obj as Unit3D
		if unit.data.is_player_unit:
			_select_unit(unit)
		else:
			# Enemy click: clear player selection without triggering close animation,
			# then open the panel in read-only mode for the enemy.
			if _selected_unit:
				_selected_unit.set_selected(false)
				_selected_unit = null
				_grid.clear_highlights()
			_stat_panel.hide_panel()
			_pending_ability = null
			_aoe_origin      = Vector2i(-1, -1)
			_travel_effect   = null
			_hovered_cell    = Vector2i(-1, -1)
			mode = PlayerMode.IDLE
			_update_status()
			_action_menu.open_for(unit, _camera_rig.get_camera())
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
		for cell in _grid.get_move_range(unit.grid_pos, unit.remaining_move):
			_grid.set_highlight(cell, "move")
	mode = PlayerMode.STRIDE_MODE if unit.can_stride() else PlayerMode.IDLE
	# Open (or refresh) the radial menu for this unit
	_action_menu.open_for(unit, _camera_rig.get_camera())
	_update_status()

func _deselect() -> void:
	_recruit_caster = null
	_clear_recruit_odds_label()
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
		_try_select_unit(cell)
		return

	var unit: Unit3D = _selected_unit
	var old_pos: Vector2i = unit.grid_pos

	# Lock input immediately so overlapping clicks during the animation are safe
	_grid.clear_highlights()
	mode = PlayerMode.IDLE
	_update_status()

	_grid.clear_occupied(old_pos)
	var path: Array[Vector2i] = _grid.find_path(old_pos, cell, unit)

	if path.is_empty():
		_grid.set_occupied(old_pos, unit)
		_grid.set_highlight(old_pos, "selected")
		return

	for step_cell in path:
		var tw: Tween = create_tween()
		tw.tween_property(unit, "global_position", _grid.grid_to_world(step_cell), 0.12)
		await tw.finished
		unit.grid_pos = step_cell
		_check_hazard_damage(unit)
		if not unit.is_alive:
			break

	if unit.is_alive:
		_grid.set_occupied(unit.grid_pos, unit)
		unit.remaining_move -= path.size()
		_grid.set_highlight(unit.grid_pos, "selected")
		_action_menu.open_for(unit, _camera_rig.get_camera())
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

	attacker.spend_energy(_pending_ability.energy_cost)
	attacker.has_acted = true

	var cells := _get_shape_cells(attacker.grid_pos, _aoe_origin, _pending_ability)
	var aoe_targets := _get_units_in_cells(cells, _pending_ability.applicable_to)

	for unit: Unit3D in aoe_targets:
		_apply_non_harm_effects(_pending_ability, attacker, unit, _aoe_origin)

	var harm_eff: EffectData = _get_harm_effect(_pending_ability)
	if harm_eff != null:
		var harm_targets: Array[Unit3D] = []
		for unit: Unit3D in aoe_targets:
			if unit.is_alive:
				harm_targets.append(unit)
		await _run_harm_defenders(attacker, harm_targets, harm_eff, _pending_ability.energy_cost, _pending_ability)

	_pending_ability = null
	_aoe_origin      = Vector2i(-1, -1)

	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	_camera_rig.trigger_shake()
	state = CombatState.PLAYER_TURN
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)
		_info_bar.refresh(_selected_unit)
	else:
		_deselect()
	_update_status()
	_check_auto_end_turn()

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

## Initiates an action for the selected unit against a single target (or self).
## Handles TRAVEL immediately (destination-pick mode); HARM routes through per-defender
## QTE; all other effects auto-resolve at full strength.
func _initiate_action(attacker: Unit3D, target: Unit3D) -> void:
	_attack_target = target
	state = CombatState.QTE_RUNNING
	mode  = PlayerMode.IDLE
	_grid.clear_highlights()
	_action_menu.close()
	_update_status()
	attacker.play_attack_anim(target.global_position)
	await get_tree().create_timer(0.09).timeout

	attacker.spend_energy(_pending_ability.energy_cost)
	attacker.has_acted = true

	## TRAVEL special case: skip QTE entirely, always enter destination-pick mode.
	for eff: EffectData in _pending_ability.effects:
		if eff.effect_type == EffectData.EffectType.TRAVEL:
			_pending_ability = null
			_attack_target   = null
			_aoe_origin      = Vector2i(-1, -1)
			state            = CombatState.PLAYER_TURN
			_travel_effect   = eff
			mode             = PlayerMode.TRAVEL_DESTINATION
			_highlight_travel_destinations(attacker, _travel_effect)
			_update_status()
			return

	_apply_non_harm_effects(_pending_ability, attacker, target)

	var harm_eff: EffectData = _get_harm_effect(_pending_ability)
	if harm_eff != null:
		await _run_harm_defenders(attacker, [target], harm_eff, _pending_ability.energy_cost, _pending_ability)

	_pending_ability = null
	_attack_target   = null

	if state == CombatState.WIN or state == CombatState.LOSE:
		return

	_camera_rig.trigger_shake()
	state = CombatState.PLAYER_TURN
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)
		_info_bar.refresh(_selected_unit)
	else:
		_deselect()
	_update_status()
	_check_auto_end_turn()

## Applies all non-HARM effects in an ability at full strength (multiplier 1.0).
## HARM is excluded — it routes through _run_harm_defenders() instead.
## TRAVEL is excluded — it's handled in _initiate_action() as a special state.
func _apply_non_harm_effects(ability: AbilityData, caster: Unit3D, target: Unit3D,
		blast_origin: Vector2i = Vector2i(-1, -1)) -> void:
	for effect: EffectData in ability.effects:
		match effect.effect_type:
			EffectData.EffectType.MEND:
				var heal: int = maxi(1, roundi(float(effect.base_value)))
				target.heal(heal)
			EffectData.EffectType.BUFF:
				_apply_stat_delta(target, effect.target_stat, maxi(1, effect.base_value))
			EffectData.EffectType.DEBUFF:
				_apply_stat_delta(target, effect.target_stat, -maxi(1, effect.base_value))
			EffectData.EffectType.FORCE:
				_apply_force(caster, target, effect, blast_origin)
			EffectData.EffectType.HARM, EffectData.EffectType.TRAVEL:
				pass

## Returns the first HARM EffectData in an ability, or null if none.
func _get_harm_effect(ability: AbilityData) -> EffectData:
	for eff: EffectData in ability.effects:
		if eff.effect_type == EffectData.EffectType.HARM:
			return eff
	return null

## Maps the QTEBar defender roll (1.25/1.0/0.75/0.25) to a damage multiplier.
## Higher dodge roll → attacker deals less damage.
func _defender_roll_to_dmg_multiplier(roll: float) -> float:
	if roll >= 1.25: return 0.5
	if roll >= 1.0:  return 0.75
	if roll >= 0.75: return 1.0
	return 1.25

## Processes HARM for each defender sequentially.
## Player-controlled defenders see the QTE bar; AI-controlled defenders instant-sim.
## Damage formula: max(1, round(dmg_mult * (base_value + caster.attack)) - armor)
## armor is physical_defense or magic_defense based on ability.damage_type; NONE = 0.
func _run_harm_defenders(caster: Unit3D, defenders: Array[Unit3D],
		effect: EffectData, energy_cost: int, ability: AbilityData) -> void:
	for defender: Unit3D in defenders:
		if not defender.is_alive:
			continue

		var dmg_mult: float
		var friendly: bool = caster.data.is_player_unit == defender.data.is_player_unit
		if friendly:
			## Friendly fire: skip QTE, apply at dmg_mult 1.0 (no dodge, no bonus).
			## The value 1.0 is a hookpoint for future feats/items.
			dmg_mult = 1.0
		elif defender.data.is_player_unit:
			state = CombatState.QTE_RUNNING
			await _camera_rig.focus_on(caster.global_position).finished
			await get_tree().create_timer(0.25).timeout
			_qte_bar.start_qte(energy_cost, caster)
			var qte_result: float = await _qte_bar.qte_resolved
			_camera_rig.restore()
			dmg_mult = _defender_roll_to_dmg_multiplier(qte_result)
		else:
			var qte_result: float = _qte_resolution_to_multiplier(defender.data.qte_resolution)
			dmg_mult = _defender_roll_to_dmg_multiplier(qte_result)

		var armor: int
		match ability.damage_type:
			AbilityData.DamageType.PHYSICAL: armor = defender.data.physical_defense
			AbilityData.DamageType.MAGIC:    armor = defender.data.magic_defense
			_:                               armor = 0
		var dmg: int = maxi(1, roundi(dmg_mult * float(effect.base_value + caster.data.attack)) - armor)
		defender.take_damage(dmg)
		_check_win_lose()
		if state == CombatState.WIN or state == CombatState.LOSE:
			return

## Returns the raw attribute int value from a unit's CombatantData.
func _get_attribute_value(unit: Unit3D, attribute: AbilityData.Attribute) -> int:
	match attribute:
		AbilityData.Attribute.STRENGTH:  return unit.data.strength
		AbilityData.Attribute.DEXTERITY: return unit.data.dexterity
		AbilityData.Attribute.COGNITION: return unit.data.cognition
		AbilityData.Attribute.VITALITY:  return unit.data.vitality
		AbilityData.Attribute.WILLPOWER: return unit.data.willpower
		_: return 0

## Applies a +/- delta to one of a unit's core attributes (or transient armor mods).
## Core attributes clamp to [0, 5]; armor mods clamp to [-10, 10] since armor can be
## meaningfully debuffed below zero (the HARM formula's maxi(1, ...) provides the floor).
## All mutations on player units are rolled back at combat end via _attr_snapshots.
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
		AbilityData.Attribute.PHYSICAL_ARMOR_MOD:
			unit.data.physical_armor_mod = clampi(unit.data.physical_armor_mod + delta, -10, 10)
		AbilityData.Attribute.MAGIC_ARMOR_MOD:
			unit.data.magic_armor_mod    = clampi(unit.data.magic_armor_mod    + delta, -10, 10)

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

	# Slide target along dir, stopping at grid edge or first occupied cell.
	# Track every cell in the path so traversal hazards can be applied.
	var dest: Vector2i = target.grid_pos
	var path: Array[Vector2i] = []
	for _i in range(effect.base_value):
		var nxt: Vector2i = dest + dir
		if not _grid.is_valid(nxt) or _grid.is_occupied(nxt):
			break
		dest = nxt
		path.append(dest)

	if dest == target.grid_pos:
		return  # nowhere to move

	_grid.clear_occupied(target.grid_pos)
	target.move_to(dest)           # updates grid_pos + emits unit_moved
	_grid.set_occupied(dest, target)
	# Damage for every hazard cell in the path (includes traversed cells and landing cell)
	for cell in path:
		if _grid.is_hazard(cell):
			target.take_damage(2)
			_camera_rig.trigger_shake()
			if not target.is_alive:
				break
	_check_win_lose()
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
		if enemy.remaining_move > 0:
			var move_cells: Array[Vector2i] = _grid.get_move_range(enemy.grid_pos, enemy.remaining_move)
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
				var path: Array[Vector2i] = _grid.find_path(enemy.grid_pos, best_cell, enemy)
				if path.is_empty():
					_grid.set_occupied(enemy.grid_pos, enemy)
				else:
					for step_cell in path:
						var tw: Tween = create_tween()
						tw.tween_property(enemy, "global_position", _grid.grid_to_world(step_cell), 0.12)
						await tw.finished
						enemy.grid_pos = step_cell
						_check_hazard_damage(enemy)
						if not enemy.is_alive:
							break
					if enemy.is_alive:
						_grid.set_occupied(enemy.grid_pos, enemy)
						enemy.remaining_move -= path.size()
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
		enemy.spend_energy(chosen.energy_cost)
		enemy.show_action_text(chosen.ability_name)

		var harm_eff: EffectData = _get_harm_effect(chosen)

		match chosen.target_shape:
			AbilityData.TargetShape.SELF:
				enemy.play_attack_anim(enemy.global_position)
				await get_tree().create_timer(0.10).timeout
				_apply_non_harm_effects(chosen, enemy, enemy)
				if harm_eff != null:
					await _run_harm_defenders(enemy, [enemy], harm_eff, chosen.energy_cost, chosen)

			AbilityData.TargetShape.SINGLE:
				enemy.play_attack_anim(target.global_position)
				await get_tree().create_timer(0.10).timeout
				_apply_non_harm_effects(chosen, enemy, target)
				if harm_eff != null:
					await _run_harm_defenders(enemy, [target], harm_eff, chosen.energy_cost, chosen)

			_:  # AoE: RADIAL, CONE, ARC, LINE
				var best_origin: Vector2i = _pick_best_aoe_origin(enemy, chosen)
				var origin_world: Vector3 = _grid.grid_to_world(best_origin)
				enemy.play_attack_anim(origin_world)
				await get_tree().create_timer(0.10).timeout
				var cells: Array[Vector2i] = _get_shape_cells(enemy.grid_pos, best_origin, chosen)
				## applicable_to is from the caster's perspective:
				## ENEMY = hits the opposing side (player units); ANY = hits all; ALLY = hits own side
				var aoe_hits: Array[Unit3D] = []
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
						_apply_non_harm_effects(chosen, enemy, hit_unit, best_origin)
						aoe_hits.append(hit_unit)
				if harm_eff != null:
					var alive_hits: Array[Unit3D] = []
					for hu: Unit3D in aoe_hits:
						if hu.is_alive:
							alive_hits.append(hu)
					await _run_harm_defenders(enemy, alive_hits, harm_eff, chosen.energy_cost, chosen)

		if state == CombatState.WIN or state == CombatState.LOSE:
			return

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
	if _action_menu.current_unit == unit:
		_action_menu.close()
	# Allies die permanently on death. PC death is resolved at combat end:
	# if the team wins the PC revives at 1 HP; if all units die the run ends.
	# Test room units are transient — no permadeath, no save.
	if unit.data.is_player_unit and unit.data.archetype_id != "RogueFinder" \
			and not GameState.test_room_mode:
		unit.data.is_dead = true
		GameState.save()
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
	_action_menu.close()
	_info_bar_unit = null
	_update_status()
	# Restore snapshotted attributes for all player units regardless of outcome.
	# Armor mods use .get(..., 0) so old in-flight snapshots without the keys still restore safely.
	for unit in _player_units:
		var snap: Dictionary = _attr_snapshots.get(unit, {})
		if not snap.is_empty():
			unit.data.strength           = snap["strength"]
			unit.data.dexterity          = snap["dexterity"]
			unit.data.cognition          = snap["cognition"]
			unit.data.vitality           = snap["vitality"]
			unit.data.willpower          = snap["willpower"]
			unit.data.physical_armor_mod = snap.get("physical_armor_mod", 0)
			unit.data.magic_armor_mod    = snap.get("magic_armor_mod",    0)

	# Test room: skip all GameState mutations and return to the map after a brief pause.
	if GameState.test_room_mode:
		GameState.test_room_mode = false
		GameState.test_room_kind = "armor_showcase"  # reset to default for next normal combat
		_status_label.text = "TEST ROOM: %s — returning to map..." % ("Victory!" if player_won else "Defeated.")
		await get_tree().create_timer(2.5).timeout
		get_tree().change_scene_to_file("res://scenes/map/MapScene.tscn")
		return

	if player_won:
		for unit in _player_units:
			if unit.is_alive:
				unit.data.current_hp     = unit.current_hp
				unit.data.current_energy = unit.current_energy
			elif unit.data.archetype_id == "RogueFinder":
				# PC was downed but allies won — revive at 1 HP, never permanently dead
				unit.data.current_hp = 1
				unit.data.current_energy = 0
		GameState.grant_xp(15)
		GameState.save()
		_end_combat_screen.show_victory(RewardGenerator.roll(3))
	else:
		# All player units died — run is over. Mark PC as dead, capture stats, show overlay.
		for unit in _player_units:
			if unit.data.archetype_id == "RogueFinder":
				unit.data.is_dead = true
				break
		_capture_run_summary()
		GameState.save()
		_show_run_end_overlay()

## --- Debug Menu ---

func _toggle_debug_menu() -> void:
	if _debug_menu == null:
		_build_debug_menu()
		return  # just built = already visible
	_debug_menu.visible = not _debug_menu.visible

func _build_debug_menu() -> void:
	_debug_menu = CanvasLayer.new()
	_debug_menu.layer = 25
	add_child(_debug_menu)

	var panel := ColorRect.new()
	panel.color = Color(0.08, 0.08, 0.10, 0.95)
	panel.size = Vector2(240.0, 320.0)
	panel.position = Vector2(20.0, 20.0)
	_debug_menu.add_child(panel)

	var title := Label.new()
	title.text = "DEBUG MENU  [T]"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	title.position = Vector2(8.0, 8.0)
	title.size = Vector2(224.0, 20.0)
	panel.add_child(title)

	var actions: Array[Dictionary] = [
		{"label": "Kill PC",               "cb": _dbg_kill_pc},
		{"label": "Kill All Allies",        "cb": _dbg_kill_allies},
		{"label": "Kill All Enemies  (K)",  "cb": _dbg_kill_enemies},
		{"label": "Kill Entire Party",      "cb": _dbg_kill_party},
		{"label": "Damage PC  -20 HP",      "cb": _dbg_damage_pc},
		{"label": "Grant XP  +20",          "cb": _dbg_grant_xp},
		{"label": "Force Level-Up",         "cb": _dbg_force_levelup},
	]
	for i in range(actions.size()):
		var btn := Button.new()
		btn.text = actions[i]["label"]
		btn.custom_minimum_size = Vector2(224.0, 40.0)
		btn.position = Vector2(8.0, 36.0 + i * 48.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.pressed.connect(actions[i]["cb"])
		panel.add_child(btn)

func _dbg_kill_pc() -> void:
	for u in _player_units:
		if u.is_alive and u.data.archetype_id == "RogueFinder":
			u.take_damage(9999)
			break
	_debug_menu.visible = false

func _dbg_kill_allies() -> void:
	for u in _player_units:
		if u.is_alive and u.data.archetype_id != "RogueFinder":
			u.take_damage(9999)
	_debug_menu.visible = false

func _dbg_kill_enemies() -> void:
	for u in _enemy_units:
		if u.is_alive:
			u.take_damage(9999)
	_debug_menu.visible = false

func _dbg_kill_party() -> void:
	for u in _player_units:
		if u.is_alive:
			u.take_damage(9999)
	_debug_menu.visible = false

func _dbg_damage_pc() -> void:
	for u in _player_units:
		if u.is_alive and u.data.archetype_id == "RogueFinder":
			u.take_damage(20)
			break
	_debug_menu.visible = false

func _dbg_grant_xp() -> void:
	GameState.grant_xp(20)
	_debug_menu.visible = false

func _dbg_force_levelup() -> void:
	for pc: CombatantData in GameState.party:
		if not pc.is_dead:
			pc.level = mini(pc.level + 1, 20)
			pc.pending_level_ups += 1
	GameState.save()
	_debug_menu.visible = false

## Populates GameState.run_summary with stats captured at the moment of run loss.
func _capture_run_summary() -> void:
	var fallen_allies: Array[String] = []
	for i in range(1, GameState.party.size()):
		if GameState.party[i].is_dead:
			fallen_allies.append(GameState.party[i].character_name)
	var pc_name: String = GameState.party[0].character_name if not GameState.party.is_empty() else "The RogueFinder"
	GameState.run_summary = {
		"pc_name":       pc_name,
		"nodes_visited": GameState.visited_nodes.size(),
		"nodes_cleared": GameState.cleared_nodes.size(),
		"threat_level":  GameState.threat_level,
		"fallen_allies": fallen_allies,
	}

## Shows "The RogueFinder has perished." for 3 seconds then loads the run summary scene.
func _show_run_end_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 20
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var label := Label.new()
	label.text = "The RogueFinder has perished."
	label.add_theme_font_size_override("font_size", 52)
	label.add_theme_color_override("font_color", Color(0.85, 0.15, 0.15))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.position = Vector2(0.0, 340.0)
	overlay.add_child(label)

	await get_tree().create_timer(3.0).timeout
	get_tree().change_scene_to_file("res://scenes/ui/RunSummaryScene.tscn")

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
## Also returns true for the Pathfinder (party[0]) if Recruit is available.
func _unit_can_still_act(unit: Unit3D) -> bool:
	if unit.has_acted:
		return false
	for ability_id in unit.data.abilities:
		if ability_id == "":
			continue
		var ability: AbilityData = AbilityLibrary.get_ability(ability_id)
		if unit.current_energy >= ability.energy_cost:
			return true
	# Pathfinder can also act via Recruit when energy and bench allow.
	# In the recruit_test room party is empty, so we check archetype_id directly.
	var is_pathfinder: bool = (not GameState.party.is_empty() and unit.data == GameState.party[0]) \
		or (GameState.test_room_kind == "recruit_test" \
			and unit.data.is_player_unit and unit.data.archetype_id == "RogueFinder")
	if is_pathfinder:
		if unit.current_energy >= RECRUIT_ENERGY_COST \
				and GameState.bench.size() < GameState.BENCH_CAP:
			return true
	return false

## --- Recruit Action ---

## Triggered when the Pathfinder clicks "⊕ Recruit" in CombatActionPanel.
## Enters RECRUIT_TARGET_MODE: highlights living enemies within 3 Manhattan tiles in teal.
func _on_recruit_selected() -> void:
	if not _selected_unit or state != CombatState.PLAYER_TURN:
		return
	_recruit_caster = _selected_unit
	mode = PlayerMode.RECRUIT_TARGET_MODE
	_grid.clear_highlights()
	_grid.set_highlight(_recruit_caster.grid_pos, "selected")
	var caster_pos: Vector2i = _recruit_caster.grid_pos
	for enemy in _enemy_units:
		if not enemy.is_alive:
			continue
		var dist: int = abs(enemy.grid_pos.x - caster_pos.x) \
			+ abs(enemy.grid_pos.y - caster_pos.y)
		if dist <= 3:
			_grid.set_highlight(enemy.grid_pos, "recruit_target")
	_update_status()

## Click handler in RECRUIT_TARGET_MODE. Teal-highlighted enemy → initiate QTE.
## Any other cell → cancel (no energy spent).
func _try_recruit_target(cell: Vector2i) -> void:
	if _grid.highlighted_cells.get(cell, "") != "recruit_target":
		_cancel_recruit_targeting()
		return
	var obj: Object = _grid.get_unit_at(cell)
	if not obj is Unit3D:
		return
	var target := obj as Unit3D
	if not target.is_alive:
		return
	_initiate_recruit(_recruit_caster, target)

## Cancels RECRUIT_TARGET_MODE and returns to the caster's normal STRIDE/IDLE state.
func _cancel_recruit_targeting() -> void:
	_recruit_caster = null
	_clear_recruit_odds_label()
	if _selected_unit and _selected_unit.is_alive:
		_select_unit(_selected_unit)   # re-opens panel and restores mode
	else:
		_deselect()

## Commits the Recruit action: spends energy, locks has_acted, runs the QTE, evaluates result.
func _initiate_recruit(caster: Unit3D, target: Unit3D) -> void:
	_clear_recruit_odds_label()
	_grid.clear_highlights()
	caster.spend_energy(RECRUIT_ENERGY_COST)
	caster.has_acted = true
	_action_menu.open_for(caster, _camera_rig.get_camera())

	var base_chance: float = _compute_recruit_base_chance(caster, target)
	mode  = PlayerMode.IDLE
	state = CombatState.QTE_RUNNING
	_update_status()

	await _camera_rig.focus_on(target.global_position).finished
	await get_tree().create_timer(0.25).timeout

	_recruit_bar.start_recruit_qte(base_chance, target)
	var qte_mult: float = await _recruit_bar.recruit_resolved

	_camera_rig.restore()

	var final_chance: float = clampf(base_chance * _qte_mult_to_recruit_mult(qte_mult), 0.0, 1.0)
	var success: bool = randf() < final_chance

	if not success:
		_show_recruit_fail_feedback(target)
		state = CombatState.PLAYER_TURN
		if _selected_unit and _selected_unit.is_alive:
			_select_unit(_selected_unit)
			_info_bar.refresh(_selected_unit)
		else:
			_deselect()
		_update_status()
		_check_auto_end_turn()
		return

	# Full success path: remove enemy, rename, bench-insert, then resume turn.
	# await keeps this coroutine suspended until the entire flow (including rename prompt) finishes.
	await _on_recruit_succeeded(target)

## Computes recruit success probability [0.05, 0.95].
## Primary driver: target HP% (lower = easier). Light WIL delta modifier.
func _compute_recruit_base_chance(caster: Unit3D, target: Unit3D) -> float:
	var hp_pct: float      = float(target.current_hp) / float(target.data.hp_max) \
		if target.data.hp_max > 0 else 0.0
	var hp_component: float = 1.0 - hp_pct

	var party_wil: int = 0
	for pc: CombatantData in GameState.party:
		if not pc.is_dead:
			party_wil += pc.willpower
	var enemy_wil: int = 0
	for unit: Unit3D in _enemy_units:
		if unit.is_alive:
			enemy_wil += unit.data.willpower
	var wil_delta: float = float(party_wil - enemy_wil) / 20.0

	return clampf(hp_component * 0.80 + wil_delta * 0.20, 0.05, 0.95)

## Maps a qualitative label to a base_chance value for display during target hover.
func _recruit_odds_label(base_chance: float) -> String:
	if base_chance < 0.20: return "Very Low"
	if base_chance < 0.40: return "Low"
	if base_chance < 0.60: return "Moderate"
	if base_chance < 0.80: return "High"
	return "Very High"

## Maps a QTE tier multiplier to a recruit chance multiplier (1-to-1 passthrough).
func _qte_mult_to_recruit_mult(qte_mult: float) -> float:
	if qte_mult >= 1.25: return 1.25
	if qte_mult >= 1.0:  return 1.0
	if qte_mult >= 0.75: return 0.75
	return 0.25

## Shows a floating "Failed!" label above the target on a failed recruit attempt.
func _show_recruit_fail_feedback(target: Unit3D) -> void:
	if is_instance_valid(target) and target.is_alive:
		target.show_floating_text("Failed!", Color(0.95, 0.30, 0.20))

## Positions and shows the qualitative odds label over a hovered recruit target.
func _show_recruit_odds(target: Unit3D) -> void:
	var base_chance: float = _compute_recruit_base_chance(_recruit_caster, target)
	var odds_str: String   = _recruit_odds_label(base_chance)

	if _recruit_odds_label_node == null:
		_recruit_odds_label_node = Label.new()
		_recruit_odds_label_node.add_theme_font_size_override("font_size", 13)
		_recruit_odds_label_node.add_theme_color_override("font_color", Color(0.20, 0.80, 0.68))
		_recruit_odds_layer.add_child(_recruit_odds_label_node)

	_recruit_odds_label_node.text    = "Recruit: %s" % odds_str
	_recruit_odds_label_node.visible = true

	var camera: Camera3D = _camera_rig.get_camera()
	if camera:
		var screen_pos: Vector2 = camera.unproject_position(
			target.global_position + Vector3(0, 2.5, 0))
		_recruit_odds_label_node.position = screen_pos + Vector2(-45.0, -28.0)

## Hides the recruit odds label (called on hover-exit or mode exit).
func _clear_recruit_odds_label() -> void:
	if _recruit_odds_label_node != null:
		_recruit_odds_label_node.visible = false

## --- Recruit Success Path ---

## Main async handler for a successful recruit QTE. Removes the enemy, runs the rename prompt,
## inserts the follower onto the bench (or shows bench-full release modal), then resumes the turn.
## Called via `await` in _initiate_recruit so the turn state is correct throughout.
func _on_recruit_succeeded(target: Unit3D) -> void:
	recruit_attempt_succeeded.emit(target)

	# Step 1: Remove target from combat board.
	_enemy_units.erase(target)
	_grid.clear_occupied(target.grid_pos)
	var target_world_pos: Vector3 = target.global_position
	target.show_floating_text("Recruited!", Color(0.20, 0.80, 0.68))
	# Brief pause so the floating text is visible before the unit disappears.
	await get_tree().create_timer(0.4).timeout
	target.visible = false

	# Step 2: Build follower CombatantData from the captured unit.
	var follower: CombatantData = _build_follower(target.data)

	# Step 3: Let the player name the follower (blocking).
	await _show_recruit_rename_prompt(follower)

	# Step 4: Bench insertion.
	if GameState.add_to_bench(follower):
		GameState.save()
		_show_bench_add_label(target_world_pos)
	else:
		# Bench is full — let player release a slot or discard the recruit.
		await _show_bench_full_modal(follower)

	# Step 5: Post-success cleanup.
	target.queue_free()
	_camera_rig.trigger_shake()
	_check_win_lose()
	_update_status()
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

## Copies stats from a captured enemy into a new player-side CombatantData.
## Level matches the current party level (guards against empty party in test room mode).
func _build_follower(source: CombatantData) -> CombatantData:
	var f := CombatantData.new()
	f.archetype_id   = source.archetype_id
	f.is_player_unit = true
	f.unit_class     = source.unit_class
	f.kindred        = source.kindred
	f.background     = source.background
	f.temperament_id = source.temperament_id
	f.strength       = source.strength
	f.dexterity      = source.dexterity
	f.cognition      = source.cognition
	f.willpower      = source.willpower
	f.vitality       = source.vitality
	f.physical_armor = source.physical_armor
	f.magic_armor    = source.magic_armor
	f.qte_resolution = 0.0
	f.abilities      = source.abilities.duplicate()
	f.ability_pool   = source.ability_pool.duplicate()
	f.feat_ids       = []
	# Level-match to the party (bible rule). Falls back to 1 in test room where party is empty.
	var party_level: int = GameState.party[0].level if not GameState.party.is_empty() else 1
	f.level          = party_level
	f.xp             = 0
	f.pending_level_ups = 0
	f.current_hp     = f.hp_max
	f.current_energy = f.energy_max
	f.is_dead        = false
	f.consumable     = ""
	# character_name set by _show_recruit_rename_prompt
	return f

## Blocking rename overlay. Pre-fills from the kindred's name pool. Awaits Confirm (button or Enter).
## Cannot be cancelled — once recruited, the player must name the follower.
func _show_recruit_rename_prompt(follower: CombatantData) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 16
	add_child(overlay)

	var bg := ColorRect.new()
	bg.color    = Color(0.08, 0.08, 0.14, 0.97)
	bg.size     = Vector2(380.0, 162.0)
	bg.position = Vector2(490.0, 285.0)
	overlay.add_child(bg)

	var title := Label.new()
	title.text     = "Name your new follower"
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color(0.20, 0.80, 0.68))
	title.position = Vector2(12.0, 10.0)
	title.size     = Vector2(356.0, 24.0)
	bg.add_child(title)

	var name_field := LineEdit.new()
	name_field.position = Vector2(12.0, 46.0)
	name_field.size     = Vector2(356.0, 36.0)
	name_field.add_theme_font_size_override("font_size", 15)
	var pool: Array[String] = KindredLibrary.get_name_pool(follower.kindred)
	name_field.text = pool[randi() % pool.size()] if not pool.is_empty() else "Recruit"
	bg.add_child(name_field)

	var confirm_btn := Button.new()
	confirm_btn.text     = "Confirm"
	confirm_btn.position = Vector2(12.0, 114.0)
	confirm_btn.size     = Vector2(356.0, 36.0)
	bg.add_child(confirm_btn)

	var _confirmed := false
	var _do_confirm := func() -> void:
		if _confirmed:
			return
		_confirmed = true
		var name: String = name_field.text.strip_edges()
		if name.is_empty():
			name = pool[randi() % pool.size()] if not pool.is_empty() else "Recruit"
		follower.character_name = name
		overlay.queue_free()
		_recruit_rename_confirmed.emit()

	confirm_btn.pressed.connect(_do_confirm)
	name_field.text_submitted.connect(func(_t: String) -> void: _do_confirm.call())

	await get_tree().process_frame
	name_field.grab_focus()
	name_field.select_all()

	await _recruit_rename_confirmed

## Blocking modal listing all bench slots. Player picks one to release (making room), or loses the recruit.
func _show_bench_full_modal(follower: CombatantData) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 16
	add_child(overlay)

	var slot_count: int   = GameState.bench.size()
	var bg_height: float  = 66.0 + (slot_count + 1) * 44.0 + 12.0
	var bg := ColorRect.new()
	bg.color    = Color(0.06, 0.07, 0.16, 0.97)
	bg.size     = Vector2(400.0, bg_height)
	bg.position = Vector2(480.0, 60.0)
	overlay.add_child(bg)

	var title := Label.new()
	title.text          = "Bench is full. Release a follower to make room, or lose this recruit."
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.position      = Vector2(12.0, 8.0)
	title.size          = Vector2(376.0, 52.0)
	title.add_theme_font_size_override("font_size", 13)
	bg.add_child(title)

	var _resolved := false

	for i in range(slot_count):
		var f: CombatantData = GameState.bench[i]
		var slot_btn := Button.new()
		slot_btn.text = "%s (%s · %s)" % [f.character_name, f.kindred, f.unit_class]
		slot_btn.position = Vector2(12.0, 66.0 + i * 44.0)
		slot_btn.size     = Vector2(376.0, 38.0)
		slot_btn.add_theme_font_size_override("font_size", 13)
		var idx := i
		slot_btn.pressed.connect(func() -> void:
			if _resolved:
				return
			_resolved = true
			GameState.release_from_bench(idx)
			GameState.add_to_bench(follower)
			GameState.save()
			overlay.queue_free()
			_bench_full_resolved.emit()
		)
		bg.add_child(slot_btn)

	var lose_btn := Button.new()
	lose_btn.text     = "Lose Recruit"
	lose_btn.position = Vector2(12.0, 66.0 + slot_count * 44.0)
	lose_btn.size     = Vector2(376.0, 38.0)
	lose_btn.add_theme_font_size_override("font_size", 13)
	lose_btn.pressed.connect(func() -> void:
		if _resolved:
			return
		_resolved = true
		overlay.queue_free()
		_bench_full_resolved.emit()
	)
	bg.add_child(lose_btn)

	await _bench_full_resolved

## Shows a world-space "Added to bench!" label at the target's last position (fire-and-forget).
## Parented to CM3D (Node3D at origin) so it stays visible after the target is hidden.
func _show_bench_add_label(world_pos: Vector3) -> void:
	var lbl := Label3D.new()
	lbl.text          = "Added to bench!"
	lbl.modulate      = Color(0.20, 0.80, 0.68)
	lbl.font_size     = 28
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position      = world_pos + Vector3(0, 1.0, 0)
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.5, 2.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.finished.connect(func() -> void: if is_instance_valid(lbl): lbl.queue_free())

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
				PlayerMode.RECRUIT_TARGET_MODE:
					_status_label.text = "RECRUIT — click a teal enemy within 3 tiles  |  ESC cancel"
		CombatState.QTE_RUNNING:
			_status_label.text = "DODGE! — press SPACE or click!"
		CombatState.ENEMY_TURN:
			_status_label.text = "ENEMY TURN..."
		CombatState.WIN, CombatState.LOSE:
			_status_label.text = ""
