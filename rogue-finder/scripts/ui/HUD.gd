class_name HUD
extends CanvasLayer

## --- HUD ---
## Displays HP and Energy for all 6 units (3 player + 3 enemy).
## All child nodes are built in _ready() so the .tscn stays minimal.
## Call refresh() whenever unit state changes.

var _player_cards: Array[Label] = []
var _enemy_cards: Array[Label]  = []

func _ready() -> void:
	_build_ui()

## --- UI Construction ---

func _build_ui() -> void:
	# Semi-transparent panel on the right side of the screen
	var panel := ColorRect.new()
	panel.color    = Color(0.10, 0.10, 0.13, 0.88)
	panel.position = Vector2(556.0, 44.0)
	panel.size     = Vector2(370.0, 360.0)
	add_child(panel)

	# "ALLIES" column header
	var ally_title := Label.new()
	ally_title.text                 = "-- ALLIES --"
	ally_title.position             = Vector2(10.0, 8.0)
	ally_title.size                 = Vector2(165.0, 22.0)
	ally_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ally_title.add_theme_font_size_override("font_size", 13)
	panel.add_child(ally_title)

	# "ENEMIES" column header
	var enemy_title := Label.new()
	enemy_title.text                 = "-- ENEMIES --"
	enemy_title.position             = Vector2(192.0, 8.0)
	enemy_title.size                 = Vector2(165.0, 22.0)
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	enemy_title.add_theme_font_size_override("font_size", 13)
	panel.add_child(enemy_title)

	# Three card labels per side, stacked vertically
	for i in range(3):
		var py: float = 36.0 + float(i) * 100.0

		var p_card := Label.new()
		p_card.position             = Vector2(8.0, py)
		p_card.size                 = Vector2(165.0, 88.0)
		p_card.add_theme_font_size_override("font_size", 11)
		p_card.autowrap_mode        = TextServer.AUTOWRAP_OFF
		panel.add_child(p_card)
		_player_cards.append(p_card)

		var e_card := Label.new()
		e_card.position             = Vector2(190.0, py)
		e_card.size                 = Vector2(165.0, 88.0)
		e_card.add_theme_font_size_override("font_size", 11)
		e_card.autowrap_mode        = TextServer.AUTOWRAP_OFF
		panel.add_child(e_card)
		_enemy_cards.append(e_card)

## --- Public API ---

## Arrays are untyped so this works with both Unit (2D) and Unit3D via duck typing.
func refresh(player_units: Array, enemy_units: Array) -> void:
	for i in range(mini(player_units.size(), _player_cards.size())):
		_player_cards[i].text = _format_unit(player_units[i])
	for i in range(mini(enemy_units.size(), _enemy_cards.size())):
		_enemy_cards[i].text = _format_unit(enemy_units[i])

func _format_unit(unit) -> String:
	if not unit.is_alive:
		return "%s\n[DEAD]" % unit.data.unit_name
	var hp_bar: String = _mini_bar(unit.current_hp,     unit.data.hp_max,     10)
	var en_bar: String = _mini_bar(unit.current_energy, unit.data.energy_max, 10)
	return "%s\nHP %s\nE  %s" % [unit.data.unit_name, hp_bar, en_bar]

## ASCII progress bar: filled = "|", empty = "."
func _mini_bar(current: int, maximum: int, width: int) -> String:
	var filled: int = clampi(roundi(float(current) / float(maximum) * float(width)), 0, width)
	return "|".repeat(filled) + ".".repeat(width - filled)
