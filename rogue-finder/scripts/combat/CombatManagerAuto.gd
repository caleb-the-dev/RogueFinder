class_name CombatManagerAuto
extends Node3D

## --- CombatManager (autobattler) ---
## Turn-tick autobattler controller. Hosts the LaneBoard, drives the tick loop,
## fires unit turns, manages combat lifecycle (entry, victory, defeat).
## Coexists with the legacy CombatManager3D until Slice 7.

## --- Constants ---
const TICK_INTERVAL_SEC: float = 0.6  # cosmetic delay between ticks for player readability

## --- State ---
var board: LaneBoard
var combat_running: bool = false
var current_tick: int = 0

## --- Lifecycle ---
func _ready() -> void:
	board = LaneBoard.new()
	# Slice 4 wires party + enemies + tick loop here.
	print("[CombatManagerAuto] _ready — skeleton; tick loop not yet implemented")

## Public entry point — called by MapManager / external bringup.
## Slice 4 will populate units + start ticking.
func start_combat(party: Array[CombatantData], enemies: Array[CombatantData]) -> void:
	combat_running = true
	current_tick = 0
	for i in min(party.size(), LaneBoard.LANE_COUNT):
		board.place(party[i], i, "ally")
	for i in min(enemies.size(), LaneBoard.LANE_COUNT):
		board.place(enemies[i], i, "enemy")
	print("[CombatManagerAuto] combat started: %d allies, %d enemies" % [party.size(), enemies.size()])

func end_combat(victory: bool) -> void:
	combat_running = false
	print("[CombatManagerAuto] combat ended — victory: %s" % victory)
	# Slice 4: route to EndCombatScreen / RunSummaryScene, etc.
