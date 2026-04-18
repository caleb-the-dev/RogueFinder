extends Node

## --- Global Game State ---
## Autoloaded singleton (name: GameState) — tracks run-wide data.
## Stage 1.5: map traversal + save/load. Will expand to party roster, reputation, etc.

const SAVE_PATH := "user://save.json"

## --- Map Progress ---

var player_node_id: String = "node_o11"
var visited_nodes: Array[String] = ["node_o11"]
# Owned here so load_save() can restore it before MapManager seeds its RNG.
var map_seed: int = 0  # 0 = not yet seeded

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
	player_node_id = parsed.get("player_node_id", "node_o11")
	var raw_visited: Array = parsed.get("visited_nodes", ["node_o11"])
	# JSON returns untyped Array; convert back to the typed form
	visited_nodes = Array(raw_visited, TYPE_STRING, "", null)
	map_seed = parsed.get("map_seed", 0)
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
