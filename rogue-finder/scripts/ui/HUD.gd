class_name HUD
extends CanvasLayer

## --- HUD ---
## Displays HP and Energy for all 6 units (3 player + 3 enemy).
## Call refresh() any time unit state changes.

## Node references — matched to HUD.tscn hierarchy
@onready var player_column: VBoxContainer = $Panel/HBox/PlayerColumn
@onready var enemy_column: VBoxContainer  = $Panel/HBox/EnemyColumn

## Dynamically created label cards, one per unit slot
var _player_cards: Array[Label] = []
var _enemy_cards: Array[Label]  = []

func _ready() -> void:
	# Seed title labels
	var player_title := player_column.get_node("Title") as Label
	var enemy_title  := enemy_column.get_node("Title") as Label
	player_title.text = "─ ALLIES ─"
	enemy_title.text  = "─ ENEMIES ─"

	# Create 3 card labels per side
	for _i: int in range(3):
		var p := Label.new()
		p.custom_minimum_size = Vector2(170, 52)
		p.autowrap_mode = TextServer.AUTOWRAP_OFF
		player_column.add_child(p)
		_player_cards.append(p)

		var e := Label.new()
		e.custom_minimum_size = Vector2(170, 52)
		e.autowrap_mode = TextServer.AUTOWRAP_OFF
		enemy_column.add_child(e)
		_enemy_cards.append(e)

## Rebuilds HUD text from current unit state. Call after any stat change.
func refresh(player_units: Array[Unit], enemy_units: Array[Unit]) -> void:
	for i: int in range(min(player_units.size(), _player_cards.size())):
		_player_cards[i].text = _format_unit(player_units[i])
	for i: int in range(min(enemy_units.size(), _enemy_cards.size())):
		_enemy_cards[i].text = _format_unit(enemy_units[i])

func _format_unit(unit: Unit) -> String:
	if not unit.is_alive:
		return "[color=gray]%s\n  [DEAD][/color]" % unit.data.unit_name
	# Compact two-line display: name, then HP and Energy bars
	var hp_bar: String  = _mini_bar(unit.current_hp,     unit.data.hp_max,     10)
	var en_bar: String  = _mini_bar(unit.current_energy, unit.data.energy_max, 10)
	return "%s\n  HP %s  E %s" % [unit.data.unit_name, hp_bar, en_bar]

## Builds a compact ASCII progress bar, e.g. "████░░░░░░"
func _mini_bar(current: int, maximum: int, width: int) -> String:
	var filled: int = int(float(current) / float(maximum) * float(width) + 0.5)
	filled = clampi(filled, 0, width)
	return "█".repeat(filled) + "░".repeat(width - filled)
