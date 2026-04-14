class_name Unit
extends Node2D

## --- Unit ---
## Represents a single combatant on the grid.
## Tracks runtime stat state, turn flags, and visual representation.
## CombatManager drives behavior; Unit is responsible only for its own data.

## --- Signals ---
signal unit_died(unit: Unit)
signal unit_moved(unit: Unit, new_pos: Vector2i)

## --- Inspector ---
@export var data: UnitData

## --- Runtime State ---
var current_hp: int = 0
var current_energy: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var has_moved: bool = false
var has_acted: bool = false
var is_alive: bool = true

## --- Visual Constants ---
const CELL_SIZE: int = 80
const COLOR_PLAYER  := Color(0.22, 0.50, 1.00)
const COLOR_ENEMY   := Color(1.00, 0.28, 0.22)
const COLOR_SELECTED := Color(1.00, 0.90, 0.20)
const COLOR_ACTED   := Color(0.38, 0.44, 0.52)   # Dimmed when unit is spent for the turn
const COLOR_DEAD    := Color(0.22, 0.22, 0.22)

## --- Node References ---
@onready var visual: ColorRect = $Visual
@onready var name_label: Label  = $NameLabel
@onready var stats_label: Label = $StatsLabel

func _ready() -> void:
	if data:
		_initialize_from_data()

## --- Public API ---

## Called by CombatManager to fully initialize a unit at a grid position.
func setup(unit_data: UnitData, pos: Vector2i) -> void:
	data = unit_data
	grid_pos = pos
	position = Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE)
	_initialize_from_data()

func take_damage(amount: int) -> void:
	current_hp = max(0, current_hp - amount)
	_update_stats_label()
	if current_hp == 0:
		_die()

## Returns false without deducting if insufficient energy.
func spend_energy(amount: int) -> bool:
	if current_energy < amount:
		return false
	current_energy -= amount
	_update_stats_label()
	return true

func regen_energy() -> void:
	current_energy = min(data.energy_max, current_energy + data.energy_regen)
	_update_stats_label()

## Clears per-turn flags; called at the start of this unit's phase.
func reset_turn() -> void:
	has_moved = false
	has_acted = false
	refresh_visual()

func can_stride() -> bool:
	return is_alive and not has_moved

func can_act(energy_cost: int = 3) -> bool:
	return is_alive and not has_acted and current_energy >= energy_cost

## Highlight or un-highlight this unit's visual when selected.
func set_selected(selected: bool) -> void:
	if not is_alive:
		return
	visual.color = COLOR_SELECTED if selected else _base_color()

## Move to a new grid cell. CombatManager must update Grid.unit_map separately.
func move_to(new_pos: Vector2i) -> void:
	grid_pos = new_pos
	position = Vector2(new_pos.x * CELL_SIZE, new_pos.y * CELL_SIZE)
	has_moved = true
	refresh_visual()
	unit_moved.emit(self, new_pos)

## Call after externally changing has_moved / has_acted to sync the color.
func refresh_visual() -> void:
	if not is_alive:
		visual.color = COLOR_DEAD
	elif has_moved and has_acted:
		visual.color = COLOR_ACTED
	else:
		visual.color = _base_color()

## --- Private Helpers ---

func _initialize_from_data() -> void:
	current_hp     = data.hp_max
	current_energy = data.energy_max
	is_alive       = true
	has_moved      = false
	has_acted      = false
	name_label.text = data.unit_name
	refresh_visual()
	_update_stats_label()

func _die() -> void:
	is_alive = false
	refresh_visual()
	name_label.text = data.unit_name + "\n[Dead]"
	unit_died.emit(self)

func _base_color() -> Color:
	return COLOR_PLAYER if data.is_player_unit else COLOR_ENEMY

func _update_stats_label() -> void:
	stats_label.text = "HP %d/%d\nE  %d/%d" % [
		current_hp,     data.hp_max,
		current_energy, data.energy_max,
	]
