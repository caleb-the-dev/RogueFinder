class_name PlacementOverlay
extends CanvasLayer

## --- PlacementOverlay ---
## Pre-fight UI: drag your 3 active party units onto your 3 lanes.
## Emits `placement_locked(party_by_lane: Array[CombatantData])` when the player presses Begin.
## Slice 4 wires this into CombatManager.start_combat().

signal placement_locked(party_by_lane: Array)

var _party: Array[CombatantData] = []
var _lane_assignments: Array[CombatantData] = [null, null, null]

func _ready() -> void:
	layer = 22  # above PartySheet (20), below PauseMenu (26)

## Populates the overlay with the player's active party.
## Default placement = party order to lane 0/1/2; player drags to override.
func show_placement(party: Array[CombatantData]) -> void:
	_party = party.duplicate()
	for i in min(_party.size(), 3):
		_lane_assignments[i] = _party[i]
	visible = true
	# Slice 4: build the actual draggable UI here.
	print("[PlacementOverlay] showing placement for %d units" % _party.size())

func _on_begin_pressed() -> void:
	visible = false
	emit_signal("placement_locked", _lane_assignments.duplicate())
