class_name StatPanel
extends CanvasLayer

## --- StatPanel ---
## Developer/player overlay that shows the full CombatantData for the selected unit.
## Appears on unit selection; hides on deselect or combat end.
## All child nodes are built in _ready() — the scene (if any) stays minimal.
##
## Layer 8: above HUD (layer 5), below QTE bar (layer 10).

var _panel: ColorRect = null
var _label: Label     = null

func _ready() -> void:
	layer = 8
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	_panel = ColorRect.new()
	_panel.color    = Color(0.05, 0.06, 0.12, 0.95)
	_panel.position = Vector2(10.0, 44.0)
	_panel.size     = Vector2(272.0, 600.0)
	add_child(_panel)

	var title := Label.new()
	title.text     = "-- UNIT STATS --"
	title.position = Vector2(0.0, 4.0)
	title.size     = Vector2(272.0, 22.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	_panel.add_child(title)

	_label = Label.new()
	_label.position      = Vector2(8.0, 28.0)
	_label.size          = Vector2(256.0, 568.0)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.add_theme_font_size_override("font_size", 11)
	_panel.add_child(_label)

## --- Public API ---

## Display stats for a unit. Accepts any object that has a .data: CombatantData field
## and live state fields (current_hp, current_energy, is_alive).
func show_for(unit: Unit3D) -> void:
	if not unit or not unit.data:
		hide_panel()
		return
	var d: CombatantData = unit.data
	_label.text = _format(d, unit)
	visible = true

func hide_panel() -> void:
	visible = false

## --- Formatting ---

func _format(d: CombatantData, unit: Unit3D) -> String:
	var lines: PackedStringArray = []

	# -- Identity --
	lines.append("=== %s ===" % d.character_name)
	lines.append("Archetype:  %s" % d.archetype_id.replace("_", " ").capitalize())
	lines.append("Class:      %s" % d.unit_class)
	lines.append("Background: %s" % _or_empty(d.background))
	lines.append("Team:       %s" % ("Player" if d.is_player_unit else "Enemy"))
	lines.append("")

	# -- Artwork --
	lines.append("-- Artwork --")
	lines.append("Idle:   %s" % _or_empty(d.artwork_idle))
	lines.append("Attack: %s" % _or_empty(d.artwork_attack))
	lines.append("")

	# -- Core Attributes --
	lines.append("-- Attributes --")
	lines.append("STR: %d   DEX: %d   COG: %d" % [d.strength, d.dexterity, d.cognition])
	lines.append("WIL: %d   VIT: %d" % [d.willpower, d.vitality])
	lines.append("")

	# -- Derived Stats --
	lines.append("-- Derived Stats --")
	lines.append("HP:       %d / %d" % [unit.current_hp, d.hp_max])
	lines.append("Energy:   %d / %d" % [unit.current_energy, d.energy_max])
	lines.append("E.Regen:  %d / turn" % d.energy_regen)
	lines.append("Defense:  %d  (armor)" % d.defense)
	lines.append("Attack:   %d  (5 + STR)" % d.attack)
	lines.append("Speed:    %d tiles  (2 + DEX)" % d.speed)
	if not d.is_player_unit:
		lines.append("QTE Res:  %.2f" % d.qte_resolution)
	lines.append("")

	# -- Equipment --
	lines.append("-- Equipment --")
	lines.append("Weapon:     %s" % _slot(d.weapon))
	lines.append("Armor:      %s" % _slot(d.armor))
	lines.append("Consumable: %s" % _slot(d.consumable))
	lines.append("Accessory:  %s" % _slot(d.accessory))
	lines.append("")

	# -- Abilities --
	lines.append("-- Abilities --")
	for i in range(4):
		var ab: String = d.abilities[i] if i < d.abilities.size() else ""
		lines.append("%d. %s" % [i + 1, _slot(ab)])

	return "\n".join(lines)

func _slot(val: String) -> String:
	return val if val != "" else "(empty)"

func _or_empty(val: String) -> String:
	return val if val != "" else "(none)"
