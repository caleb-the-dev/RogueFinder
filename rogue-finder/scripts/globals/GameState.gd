extends Node

## --- Global Game State ---
## Autoloaded singleton (name: GameState) — tracks run-wide data.
## Stage 1.5: map traversal + save/load. Will expand to party roster, reputation, etc.

const SAVE_PATH := "user://save.json"

## --- Map Progress ---

var player_node_id: String = "badurga"
var visited_nodes: Array[String] = ["badurga"]
# Owned here so load_save() can restore it before MapManager seeds its RNG.
var map_seed: int = 0  # 0 = not yet seeded
var node_types: Dictionary = {}    # id -> String; populated by MapManager on first run, saved to disk
var pending_node_type: String = "" # consumed by NodeStub on scene entry; NOT saved to disk
var current_combat_node_id: String = "" # transient handoff to EndCombatScreen; NOT saved to disk
var cleared_nodes: Array[String] = []  # nodes where player won and collected reward; saved to disk
var threat_level: int = 0              # increments each non-cleared node entry; resets on BOSS defeat

# threat_level feeds into boss difficulty scaling — see Feature 8
func get_threat_level() -> int:
	return threat_level

func move_player(node_id: String) -> void:
	player_node_id = node_id
	if node_id not in visited_nodes:
		visited_nodes.append(node_id)

func is_visited(node_id: String) -> bool:
	return node_id in visited_nodes

# adjacency is passed in from MapManager to keep GameState decoupled from map-building data
func is_adjacent_to_player(node_id: String, adjacency: Dictionary) -> bool:
	var neighbors: Array = adjacency.get(player_node_id, [])
	return node_id in neighbors

## --- Save / Load ---

func save() -> void:
	var data := {
		"player_node_id": player_node_id,
		"visited_nodes": visited_nodes,
		"map_seed": map_seed,
		"node_types": node_types,
		"cleared_nodes": cleared_nodes,
		"threat_level": threat_level,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t"))

func load_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	player_node_id = parsed.get("player_node_id", "badurga")
	var raw_visited: Array = parsed.get("visited_nodes", ["badurga"])
	# JSON returns untyped Array; convert back to the typed form
	visited_nodes = Array(raw_visited, TYPE_STRING, "", null)
	map_seed = parsed.get("map_seed", 0)
	# Dictionary values are already strings from JSON; no typed conversion needed
	node_types = parsed.get("node_types", {})
	var raw_cleared: Array = parsed.get("cleared_nodes", [])
	cleared_nodes = Array(raw_cleared, TYPE_STRING, "", null)
	threat_level = parsed.get("threat_level", 0)
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# Resets all in-memory fields to fresh-run defaults. Call before reload_current_scene()
# when wiping a save mid-session — load_save() does NOT reset fields on a missing file.
func reset() -> void:
	player_node_id = "badurga"
	visited_nodes = ["badurga"]
	map_seed = 0
	node_types = {}
	pending_node_type = ""
	current_combat_node_id = ""
	cleared_nodes = []
	threat_level = 0
