class_name StatPanel
extends CanvasLayer

## --- StatPanel ---
## Full examine window (DOS2-style). Opens on DOUBLE-CLICK of any unit.
## Closed by the X button or ESC via CombatManager3D._deselect().
## Layer 8: above UnitInfoBar (layer 4), below QTE bar (layer 10).

const PANEL_W: float    = 360.0
const PANEL_H: float    = 600.0
const PORTRAIT_SZ: float = 120.0

var _panel: ColorRect       = null
var _portrait: TextureRect  = null
var _title: Label           = null
var _scroll: ScrollContainer = null
var _rtl: RichTextLabel     = null
var _close_btn: Button      = null

func _ready() -> void:
	layer = 8
	_build_ui()
	visible = false

## --- UI Construction ---

func _build_ui() -> void:
	# Background panel — centered on a 1280×720 viewport
	_panel = ColorRect.new()
	_panel.color    = Color(0.05, 0.07, 0.16, 0.96)
	_panel.position = Vector2(460.0, 30.0)
	_panel.size     = Vector2(PANEL_W, PANEL_H)
	add_child(_panel)

	# X close button (top-right corner)
	_close_btn = Button.new()
	_close_btn.text     = "✕"
	_close_btn.position = Vector2(PANEL_W - 32.0, 4.0)
	_close_btn.size     = Vector2(28.0, 24.0)
	_close_btn.pressed.connect(hide_panel)
	_panel.add_child(_close_btn)

	# Portrait box (centered horizontally, 34px from top)
	_portrait = TextureRect.new()
	_portrait.position     = Vector2((PANEL_W - PORTRAIT_SZ) * 0.5, 34.0)
	_portrait.size         = Vector2(PORTRAIT_SZ, PORTRAIT_SZ)
	_portrait.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_panel.add_child(_portrait)

	# Title — name + class, centered below portrait
	_title = Label.new()
	_title.position              = Vector2(0.0, 34.0 + PORTRAIT_SZ + 6.0)
	_title.size                  = Vector2(PANEL_W, 24.0)
	_title.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 14)
	_panel.add_child(_title)

	# ScrollContainer + RichTextLabel for all stat content
	var content_y: float = 34.0 + PORTRAIT_SZ + 34.0
	_scroll = ScrollContainer.new()
	_scroll.position               = Vector2(6.0, content_y)
	_scroll.size                   = Vector2(PANEL_W - 12.0, PANEL_H - content_y - 6.0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_AUTO
	_panel.add_child(_scroll)

	_rtl = RichTextLabel.new()
	_rtl.bbcode_enabled = true
	_rtl.fit_content    = true
	# Constrain width so text wraps; let fit_content grow the height naturally.
	# Do NOT set size.y — overriding it to 0 defeats fit_content and hides all text.
	_rtl.custom_minimum_size = Vector2(PANEL_W - 28.0, 0.0)
	_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rtl.add_theme_font_size_override("normal_font_size", 12)
	_scroll.add_child(_rtl)

## --- Public API ---

func show_for(unit: Unit3D) -> void:
	if not unit or not unit.data:
		hide_panel()
		return
	var d: CombatantData = unit.data

	# Portrait: use character's texture or fall back to the Godot icon
	_portrait.texture = d.portrait if d.portrait \
		else (load("res://icon.svg") as Texture2D)

	# Title: name (or archetype label if unnamed) + class
	var display_name: String = d.character_name if d.character_name != "" \
		else d.archetype_id.replace("_", " ").capitalize()
	_title.text = "%s  [%s]" % [display_name, d.unit_class]

	_rtl.text = _format(d, unit)
	_scroll.scroll_vertical = 0  # reset scroll to top on each open
	visible = true

func hide_panel() -> void:
	visible = false

## --- Content Formatting ---

func _format(d: CombatantData, unit: Unit3D) -> String:
	var lines: PackedStringArray = []

	# -- Identity --
	lines.append("[b]Archetype:[/b]  %s" % d.archetype_id.replace("_", " ").capitalize())
	lines.append("[b]Background:[/b] %s" % _or(d.background))
	lines.append("[b]Team:[/b]       %s" % ("Player" if d.is_player_unit else "Enemy"))
	lines.append("")

	# -- Live State --
	lines.append("[b]── Live State ──[/b]")
	lines.append("[b]HP:[/b]     %d / %d" % [unit.current_hp, d.hp_max])
	lines.append("[b]Energy:[/b] %d / %d" % [unit.current_energy, d.energy_max])
	lines.append("")

	# -- Core Attributes --
	lines.append("[b]── Attributes ──[/b]")
	lines.append("STR [b]%d[/b]   DEX [b]%d[/b]   COG [b]%d[/b]" \
		% [d.strength, d.dexterity, d.cognition])
	lines.append("WIL [b]%d[/b]   VIT [b]%d[/b]" % [d.willpower, d.vitality])
	lines.append("")

	# -- Derived Stats --
	lines.append("[b]── Derived Stats ──[/b]")
	lines.append("[b]Attack:[/b]  %d   (5 + STR)" % d.attack)
	lines.append("[b]Defense:[/b] %d   (armor)" % d.defense)
	lines.append("[b]Speed:[/b]   %d tiles   (2 + DEX)" % d.speed)
	lines.append("[b]E.Regen:[/b] %d/turn   (2 + WIL)" % d.energy_regen)
	if not d.is_player_unit:
		lines.append("[b]QTE Res:[/b] %.2f" % d.qte_resolution)
	lines.append("")

	# -- Equipment --
	lines.append("[b]── Equipment ──[/b]")
	lines.append("[b]Weapon:[/b]     %s" % (d.weapon.equipment_name    if d.weapon    else "(empty)"))
	lines.append("[b]Armor:[/b]      %s" % (d.armor.equipment_name     if d.armor     else "(empty)"))
	lines.append("[b]Consumable:[/b] %s" % _slot(d.consumable))
	lines.append("[b]Accessory:[/b]  %s" % (d.accessory.equipment_name if d.accessory else "(empty)"))
	lines.append("")

	# -- Abilities --
	lines.append("[b]── Abilities ──[/b]")
	for i in range(4):
		var ab: String = d.abilities[i] if i < d.abilities.size() else ""
		lines.append("%d. %s" % [i + 1, _slot(ab)])

	# -- Status Effects --
	if not unit.stat_effects.is_empty():
		lines.append("")
		lines.append("[b]── Status Effects ──[/b]")
		for e: Dictionary in unit.stat_effects:
			var arrow: String = "▲" if e["delta"] > 0 else "▼"
			lines.append("%s  [b]%s[/b]  (%+d %s)" % [
				arrow, e["display_name"], e["delta"], _stat_abbr(e["stat"])
			])

	return "\n".join(lines)

func _slot(val: String) -> String:
	return val if val != "" else "(empty)"

func _or(val: String) -> String:
	return val if val != "" else "(none)"

func _stat_abbr(stat: int) -> String:
	match stat:
		AbilityData.Attribute.STRENGTH:  return "STR"
		AbilityData.Attribute.DEXTERITY: return "DEX"
		AbilityData.Attribute.COGNITION: return "COG"
		AbilityData.Attribute.VITALITY:  return "VIT"
		AbilityData.Attribute.WILLPOWER: return "WIL"
		_: return "???"
