class_name MapManager
extends Node2D

## --- Constants ---

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const CENTER        := Vector2(640.0, 360.0)
const ZOOM_MIN      := 0.35
const ZOOM_MAX      := 2.5
const ZOOM_STEP     := 0.12

## --- Scene Refs ---

var _map_container: Node2D
var _buttons: Dictionary = {}   # id -> Button
var _hover_label: Label
var _player_marker: Polygon2D

## --- Data ---

var _node_data: Array[Dictionary] = []
var _edge_data: Array[Array] = []
var _node_map: Dictionary = {}  # id -> Dictionary (fast lookup)
var _adjacency: Dictionary = {} # id -> Array[String]

var _inner_ids: Array[String] = []
var _middle_ids: Array[String] = []
var _outer_ids: Array[String] = []

## --- Pan State ---

var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_container: Vector2 = Vector2.ZERO
var _drag_moved: bool = false

## --- Lifecycle ---

func _ready() -> void:
	GameState.load_save()
	_build_node_data()
	_build_edge_data()
	_build_adjacency()
	_build_scene()

# _input (not _unhandled_input) so drag is captured even when the press starts on a Button
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_is_panning = true
					_drag_moved = false
					_pan_start_mouse = mb.global_position
					_pan_start_container = _map_container.position
				else:
					_is_panning = false
			MOUSE_BUTTON_WHEEL_UP:
				_do_zoom(1.0 + ZOOM_STEP, mb.global_position)
			MOUSE_BUTTON_WHEEL_DOWN:
				_do_zoom(1.0 - ZOOM_STEP, mb.global_position)
	elif event is InputEventMouseMotion and _is_panning:
		var mm := event as InputEventMouseMotion
		var delta: Vector2 = mm.global_position - _pan_start_mouse
		if delta.length() > 4.0:
			_drag_moved = true
		_map_container.position = _pan_start_container + delta

## --- Pan / Zoom ---

func _do_zoom(factor: float, pivot: Vector2) -> void:
	var old_scale: float = _map_container.scale.x
	var new_scale: float = clampf(old_scale * factor, ZOOM_MIN, ZOOM_MAX)
	var ratio: float = new_scale / old_scale
	# Keep the pixel under the cursor stationary
	_map_container.position = pivot + (_map_container.position - pivot) * ratio
	_map_container.scale = Vector2(new_scale, new_scale)

## --- Node Data ---

func _build_node_data() -> void:
	_add_node("badurga", CENTER, 0.0, "Badurga", true, false)

	# Inner ring — 6 nodes, radius 140
	_inner_ids = ["node_i0", "node_i1", "node_i2", "node_i3", "node_i4", "node_i5"]
	var inner_labels: Array[String] = [
		"Ashwood Hollow", "Greymoor Pass", "Ironveil Ford",
		"Saltfen Reach", "Dunmarch Gate", "The Pale Crossing",
	]
	var inner_offsets: Array[float] = [0.0, 3.0, -5.0, 7.0, -4.0, 2.0]
	for i in range(6):
		var angle := deg_to_rad(i * 60.0 + inner_offsets[i])
		_add_node(_inner_ids[i], CENTER + Vector2(cos(angle), sin(angle)) * 140.0,
				angle, inner_labels[i], false, false)

	# Middle ring — 9 nodes, radius 260
	_middle_ids = ["node_m0", "node_m1", "node_m2", "node_m3", "node_m4",
				   "node_m5", "node_m6", "node_m7", "node_m8"]
	var mid_labels: Array[String] = [
		"Fenmark Road", "Crownwood Trail", "Veldthorn Outpost",
		"Harrowed Fen", "Stonewatch Ridge", "Cinder Gorge",
		"Bleak Mire", "Thornback Camp", "Ravenscar Hill",
	]
	var mid_offsets: Array[float] = [5.0, -8.0, 3.0, -3.0, 10.0, -6.0, 4.0, -2.0, 7.0]
	for i in range(9):
		var angle := deg_to_rad(i * 40.0 + mid_offsets[i])
		_add_node(_middle_ids[i], CENTER + Vector2(cos(angle), sin(angle)) * 260.0,
				angle, mid_labels[i], false, false)

	# Outer ring — 12 nodes, radius 380
	var out_labels: Array[String] = [
		"Coldwater Landing", "Bramblegate", "Ember Fields", "Wychwood Crossing",
		"Northfen Approach", "The Sunken Road", "Gravel Watch", "Ashford Ruins",
		"Moorvale Pass", "Duskwall Junction", "Saltmarch End", "The Last Waypost",
	]
	var out_offsets: Array[float] = [0.0, -7.0, 5.0, -4.0, 9.0, -10.0, 3.0, -6.0, 8.0, -3.0, 6.0, -5.0]
	for i in range(12):
		var oid := "node_o%d" % i
		_outer_ids.append(oid)
		var angle := deg_to_rad(i * 30.0 + out_offsets[i])
		_add_node(oid, CENTER + Vector2(cos(angle), sin(angle)) * 380.0,
				angle, out_labels[i], false, false)

	# Mark one outer node as player start
	_node_data[-1]["is_player_start"] = true
	_node_map["node_o11"]["is_player_start"] = true

func _add_node(id: String, pos: Vector2, angle: float, label: String,
		is_hub: bool, is_player_start: bool) -> void:
	var nd := {
		"id": id, "position": pos, "angle": angle,
		"label": label, "is_hub": is_hub, "is_player_start": is_player_start,
		"stamp_added": false,
	}
	_node_data.append(nd)
	_node_map[id] = nd

## --- Edge Data ---

func _build_edge_data() -> void:
	# Seed RNG once per run so the map topology is deterministic on reload
	if GameState.map_seed == 0:
		GameState.map_seed = randi()
	seed(GameState.map_seed)

	# Each ring is a simple closed chain — no chords, so no crossings within the ring
	_connect_ring(_inner_ids)
	_connect_ring(_middle_ids)
	_connect_ring(_outer_ids)

	# Hub → inner: 2 randomly selected inner nodes
	_connect_hub_random(2)

	# Inter-ring gateways: stratified random angles guarantee spread + no crossings
	# 3 gateways each; randomized per run
	_connect_gateways(_inner_ids, _middle_ids, 3)
	_connect_gateways(_middle_ids, _outer_ids, 3)

func _connect_ring(ids: Array[String]) -> void:
	var n := ids.size()
	for i in range(n):
		_edge_data.append([ids[i], ids[(i + 1) % n]])

func _connect_hub_random(count: int) -> void:
	var shuffled: Array[String] = _inner_ids.duplicate()
	shuffled.shuffle()
	for i in range(mini(count, shuffled.size())):
		_edge_data.append(["badurga", shuffled[i]])

# Divides the full circle into `count` equal sectors and picks one random angle
# per sector. For each angle the angularly closest node in each ring is connected.
# Stratification ensures gateways are spread around the map rather than clustered,
# and using closest-to-angle (rather than random pairs) keeps the edges radial.
func _connect_gateways(ring_a: Array[String], ring_b: Array[String], count: int) -> void:
	var sector := TAU / float(count)
	var used_pairs: Dictionary = {}
	for i in range(count):
		var angle := i * sector + randf() * sector
		var a_id := _closest_to_angle(ring_a, angle)
		var b_id := _closest_to_angle(ring_b, angle)
		var key := a_id + "|" + b_id
		if not used_pairs.has(key):
			used_pairs[key] = true
			_edge_data.append([a_id, b_id])

# Returns the id whose stored angle is closest to target, wrapping correctly
func _closest_to_angle(ids: Array[String], target: float) -> String:
	var best_id: String = ids[0]
	var best_dist: float = TAU
	for id in ids:
		var diff: float = fposmod(_node_map[id]["angle"] - target, TAU)
		if diff > PI:
			diff = TAU - diff
		if diff < best_dist:
			best_dist = diff
			best_id = id
	return best_id

## --- Adjacency ---

func _build_adjacency() -> void:
	for edge in _edge_data:
		var a: String = edge[0]
		var b: String = edge[1]
		if not _adjacency.has(a):
			_adjacency[a] = []
		if not _adjacency.has(b):
			_adjacency[b] = []
		_adjacency[a].append(b)
		_adjacency[b].append(a)

## --- Scene Construction ---

func _build_scene() -> void:
	_add_background()
	_add_ui_chrome()
	_create_map_container()
	_add_edges()
	_add_nodes()
	_add_hover_label()
	_refresh_all_node_visuals()

func _add_background() -> void:
	var bg := ColorRect.new()
	bg.size = VIEWPORT_SIZE
	bg.color = Color(0.82, 0.74, 0.58)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

func _add_ui_chrome() -> void:
	var lbl := Label.new()
	lbl.text = "[MAP SCENE]"
	lbl.position = Vector2(12.0, 8.0)
	var s := LabelSettings.new()
	s.font_size = 16
	s.font_color = Color(0.2, 0.15, 0.08)
	lbl.label_settings = s
	add_child(lbl)

	var btn := Button.new()
	btn.text = "→ Combat (debug)"
	btn.size = Vector2(160.0, 36.0)
	btn.position = Vector2(VIEWPORT_SIZE.x - 172.0, 8.0)
	btn.pressed.connect(_on_debug_combat_pressed)
	add_child(btn)

	var del_btn := Button.new()
	del_btn.text = "🗑 Delete Save (debug)"
	del_btn.size = Vector2(200.0, 36.0)
	del_btn.position = Vector2(VIEWPORT_SIZE.x - 172.0 - 212.0, 8.0)
	del_btn.pressed.connect(_on_debug_delete_save_pressed)
	add_child(del_btn)

func _create_map_container() -> void:
	_map_container = Node2D.new()
	add_child(_map_container)

func _add_edges() -> void:
	for edge in _edge_data:
		var a: String = edge[0]
		var b: String = edge[1]
		var line := Line2D.new()
		line.add_point(_node_map[a]["position"])
		line.add_point(_node_map[b]["position"])
		line.default_color = Color(0.55, 0.42, 0.28)
		line.width = 3.0
		_map_container.add_child(line)

func _add_nodes() -> void:
	for nd in _node_data:
		var is_hub: bool  = nd["is_hub"]
		var node_size     := Vector2(56.0, 56.0) if is_hub else Vector2(32.0, 32.0)
		var node_color    := Color(0.85, 0.65, 0.25) if is_hub else Color(0.72, 0.60, 0.44)
		var radius        := int(node_size.x * 0.5)

		var btn := Button.new()
		btn.size     = node_size
		btn.position = nd["position"] - node_size * 0.5

		var style := StyleBoxFlat.new()
		style.bg_color = node_color
		style.corner_radius_top_left    = radius
		style.corner_radius_top_right   = radius
		style.corner_radius_bottom_left = radius
		style.corner_radius_bottom_right = radius
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.25, 0.18, 0.10)
		btn.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = node_color.lightened(0.12)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.set_meta("node_id",      nd["id"])
		btn.set_meta("node_label",   nd["label"])
		btn.set_meta("base_color",   node_color)
		btn.set_meta("is_hub",       is_hub)
		btn.set_meta("normal_style", style)
		btn.set_meta("map_pos",      nd["position"])

		btn.mouse_entered.connect(_on_node_hover_enter.bind(btn))
		btn.mouse_exited.connect(_on_node_hover_exit.bind(btn))
		btn.pressed.connect(_on_node_clicked.bind(nd["id"]))

		_map_container.add_child(btn)
		_buttons[nd["id"]] = btn

		if nd["id"] == GameState.player_node_id:
			_add_player_marker(nd["position"])

func _add_player_marker(map_pos: Vector2) -> void:
	_player_marker = Polygon2D.new()
	_player_marker.polygon = PackedVector2Array([
		Vector2(0.0, -10.0), Vector2(10.0, 0.0),
		Vector2(0.0,  10.0), Vector2(-10.0, 0.0),
	])
	_player_marker.color = Color(0.3, 0.6, 1.0)
	_player_marker.position = map_pos + Vector2(0.0, -26.0)
	_map_container.add_child(_player_marker)

func _add_hover_label() -> void:
	_hover_label = Label.new()
	_hover_label.visible = false
	_hover_label.z_index = 10
	var s := LabelSettings.new()
	s.font_size    = 13
	s.font_color   = Color.WHITE
	s.shadow_color  = Color(0.0, 0.0, 0.0, 0.8)
	s.shadow_offset = Vector2(1.0, 1.0)
	_hover_label.label_settings = s
	# Inside container so it pans/zooms with the map
	_map_container.add_child(_hover_label)

## --- Node Visual States ---

func _refresh_all_node_visuals() -> void:
	for nd in _node_data:
		var id: String = nd["id"]
		var btn: Button = _buttons[id]
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		var base_color: Color = btn.get_meta("base_color")

		var is_current: bool   = id == GameState.player_node_id
		var is_visited: bool   = GameState.is_visited(id)
		var is_reachable: bool = GameState.is_adjacent_to_player(id, _adjacency)

		if is_current:
			style.bg_color = base_color
			style.border_color = Color(0.9, 0.85, 0.3)
			style.border_width_left   = 3
			style.border_width_right  = 3
			style.border_width_top    = 3
			style.border_width_bottom = 3
			btn.modulate = Color(1, 1, 1, 1)
		elif is_reachable:
			style.bg_color = base_color
			style.border_color = Color(0.25, 0.18, 0.10)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
			btn.modulate = Color(1, 1, 1, 1)
		elif is_visited:
			style.bg_color = base_color.darkened(0.35)
			style.border_color = Color(0.25, 0.18, 0.10)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
			btn.modulate = Color(1, 1, 1, 0.85)
			_add_visited_stamp(btn, nd)
		else:
			# LOCKED
			style.bg_color = base_color.darkened(0.15)
			style.border_color = Color(0.25, 0.18, 0.10)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
			btn.modulate = Color(1, 1, 1, 0.5)

func _add_visited_stamp(btn: Button, nd: Dictionary) -> void:
	if nd["stamp_added"]:
		return
	nd["stamp_added"] = true
	var stamp := Label.new()
	stamp.text = "✓"
	stamp.position = Vector2(2.0, -2.0)
	var s := LabelSettings.new()
	s.font_size = 11
	s.font_color = Color(0.9, 0.95, 0.7)
	stamp.label_settings = s
	btn.add_child(stamp)

## --- Traversal ---

func _move_player_to(node_id: String) -> void:
	GameState.move_player(node_id)
	GameState.save()
	var target_pos: Vector2 = _node_map[node_id]["position"] + Vector2(0.0, -26.0)
	var tween := create_tween()
	tween.tween_property(_player_marker, "position", target_pos, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_refresh_all_node_visuals()

## --- Hover Callbacks ---

func _on_node_hover_enter(btn: Button) -> void:
	var node_id: String  = btn.get_meta("node_id")
	var is_locked: bool  = not GameState.is_visited(node_id) \
		and not GameState.is_adjacent_to_player(node_id, _adjacency) \
		and node_id != GameState.player_node_id
	# Always show the hub label so the player knows it exists — just suppress animation
	var is_hub: bool = btn.get_meta("is_hub")
	if is_locked and not is_hub:
		return

	var map_pos: Vector2 = btn.get_meta("map_pos")

	_hover_label.text    = btn.get_meta("node_label")
	_hover_label.visible = true
	# Wait one frame for the label's size to be computed before centering it
	await get_tree().process_frame
	var lw: float = _hover_label.size.x
	_hover_label.position = map_pos + Vector2(-lw * 0.5, btn.size.y * 0.5 + 6.0)

	if is_locked:
		return  # label shown; skip scale/tint for unreachable hub

	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_QUAD)

	if is_hub:
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		tween.parallel().tween_property(style, "bg_color", Color(1.0, 0.85, 0.4), 0.12)

func _on_node_hover_exit(btn: Button) -> void:
	_hover_label.visible = false
	var is_hub: bool   = btn.get_meta("is_hub")
	var base: Color    = btn.get_meta("base_color")

	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_QUAD)

	if is_hub:
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		tween.parallel().tween_property(style, "bg_color", base, 0.10)

## --- Click / Debug ---

func _on_node_clicked(node_id: String) -> void:
	if _drag_moved:
		return
	if node_id == GameState.player_node_id:
		return
	if not GameState.is_adjacent_to_player(node_id, _adjacency):
		return
	_move_player_to(node_id)

func _on_debug_combat_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")

func _on_debug_delete_save_pressed() -> void:
	GameState.delete_save()
	GameState.reset()
	get_tree().reload_current_scene()
