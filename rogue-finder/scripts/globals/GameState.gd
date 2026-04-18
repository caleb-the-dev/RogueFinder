extends Node

## --- Global Game State ---
## Autoloaded singleton (name: GameState) — tracks run-wide data.
## Stage 1.5: map traversal fields. Will expand to party roster, reputation, etc.

## --- Map Progress ---

var player_node_id: String = "node_o11"
var visited_nodes: Array[String] = ["node_o11"]

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
