class_name PlacementOverlay
extends CanvasLayer

## Pre-fight UI: click lane buttons to cycle which unit occupies each lane.
## Emits placement_locked(party_by_lane: Array) when the player presses Begin.

signal placement_locked(party_by_lane: Array)

var _party: Array[CombatantData] = []
var _lane_assignments: Array = [null, null, null]
var _lane_buttons: Array[Button] = []
var _begin_button: Button

func _ready() -> void:
	layer = 22  # above PartySheet (20), below PauseMenu (26)

func show_placement(party: Array[CombatantData]) -> void:
	_party = party.duplicate()
	for i in min(_party.size(), 3):
		_lane_assignments[i] = _party[i]
	_build_ui()
	visible = true

func _build_ui() -> void:
	for c: Node in get_children():
		c.queue_free()

	var ctrl := Control.new()
	ctrl.anchor_right = 1.0
	ctrl.anchor_bottom = 1.0
	add_child(ctrl)

	var bg := ColorRect.new()
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.color = Color(0.0, 0.0, 0.0, 0.55)
	ctrl.add_child(bg)

	var title := Label.new()
	title.text = "Assign Units to Lanes"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(340, 130)
	title.custom_minimum_size = Vector2(600, 0)
	title.add_theme_font_size_override("font_size", 28)
	ctrl.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(215, 240)
	hbox.add_theme_constant_override("separation", 20)
	ctrl.add_child(hbox)
	_lane_buttons.clear()
	for lane in 3:
		var btn := Button.new()
		btn.text = _label_for(lane)
		btn.custom_minimum_size = Vector2(240, 180)
		var captured_lane := lane
		btn.pressed.connect(func() -> void: _cycle_assignment(captured_lane))
		hbox.add_child(btn)
		_lane_buttons.append(btn)

	_begin_button = Button.new()
	_begin_button.text = "Begin Combat"
	_begin_button.custom_minimum_size = Vector2(220, 60)
	_begin_button.position = Vector2(530, 480)
	_begin_button.add_theme_font_size_override("font_size", 18)
	_begin_button.pressed.connect(_on_begin_pressed)
	ctrl.add_child(_begin_button)

func _label_for(lane: int) -> String:
	var u: CombatantData = _lane_assignments[lane]
	return "Lane %d\n\n%s" % [lane + 1, u.character_name if u != null else "—"]

func _cycle_assignment(lane: int) -> void:
	var current: CombatantData = _lane_assignments[lane]
	var idx: int = _party.find(current) if current != null else -1
	idx = (idx + 1) % (_party.size() + 1)
	for _tries in _party.size() + 2:
		var candidate: CombatantData = _party[idx] if idx < _party.size() else null
		# Accept null (empty lane) or any unit not already in another lane.
		if candidate == null or not _lane_assignments.has(candidate) or _lane_assignments[lane] == candidate:
			_lane_assignments[lane] = candidate
			break
		idx = (idx + 1) % (_party.size() + 1)
	_lane_buttons[lane].text = _label_for(lane)

func _on_begin_pressed() -> void:
	visible = false
	emit_signal("placement_locked", _lane_assignments.duplicate())
