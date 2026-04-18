class_name MapManager
extends Node2D

## --- Node Data ---

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const CENTER := Vector2(640.0, 360.0)

# Each dict: id, position, label, is_hub, is_player_start
var _node_data: Array[Dictionary] = []

# Edge pairs as [id_a, id_b]
var _edge_data: Array[Array] = []

# Runtime refs
var _buttons: Dictionary = {}  # id -> Button
var _hover_label: Label
var _player_marker: Polygon2D

## --- Lifecycle ---

func _ready() -> void:
	_build_node_data()
	_build_edge_data()
	_build_scene()


## --- Data Definitions ---

func _build_node_data() -> void:
	# Center hub
	_node_data.append({
		"id": "badurga",
		"position": CENTER,
		"label": "Badurga",
		"is_hub": true,
		"is_player_start": false,
	})

	# Inner ring — radius 140, 6 nodes
	var inner_ids := ["node_i0", "node_i1", "node_i2", "node_i3", "node_i4", "node_i5"]
	var inner_labels := ["Ashwood Hollow", "Greymoor Pass", "Ironveil Ford", "Saltfen Reach", "Dunmarch Gate", "The Pale Crossing"]
	var inner_offsets := [0.0, 3.0, -5.0, 7.0, -4.0, 2.0]  # degree nudges for natural feel
	for i in range(6):
		var angle := deg_to_rad(i * 60.0 + inner_offsets[i])
		_node_data.append({
			"id": inner_ids[i],
			"position": CENTER + Vector2(cos(angle), sin(angle)) * 140.0,
			"label": inner_labels[i],
			"is_hub": false,
			"is_player_start": false,
		})

	# Middle ring — radius 260, 9 nodes
	var mid_ids := ["node_m0", "node_m1", "node_m2", "node_m3", "node_m4", "node_m5", "node_m6", "node_m7", "node_m8"]
	var mid_labels := ["Fenmark Road", "Crownwood Trail", "Veldthorn Outpost", "Harrowed Fen", "Stonewatch Ridge", "Cinder Gorge", "Bleak Mire", "Thornback Camp", "Ravenscar Hill"]
	var mid_offsets := [5.0, -8.0, 3.0, -3.0, 10.0, -6.0, 4.0, -2.0, 7.0]
	for i in range(9):
		var angle := deg_to_rad(i * 40.0 + mid_offsets[i])
		_node_data.append({
			"id": mid_ids[i],
			"position": CENTER + Vector2(cos(angle), sin(angle)) * 260.0,
			"label": mid_labels[i],
			"is_hub": false,
			"is_player_start": false,
		})

	# Outer ring — radius 380, 12 nodes
	var out_ids := ["node_o0", "node_o1", "node_o2", "node_o3", "node_o4", "node_o5", "node_o6", "node_o7", "node_o8", "node_o9", "node_o10", "node_o11"]
	var out_labels := ["Coldwater Landing", "Bramblegate", "Ember Fields", "Wychwood Crossing", "Northfen Approach", "The Sunken Road", "Gravel Watch", "Ashford Ruins", "Moorvale Pass", "Duskwall Junction", "Saltmarch End", "The Last Waypost"]
	var out_offsets := [0.0, -7.0, 5.0, -4.0, 9.0, -10.0, 3.0, -6.0, 8.0, -3.0, 6.0, -5.0]
	for i in range(12):
		var angle := deg_to_rad(i * 30.0 + out_offsets[i])
		_node_data.append({
			"id": out_ids[i],
			"position": CENTER + Vector2(cos(angle), sin(angle)) * 380.0,
			"label": out_labels[i],
			"is_hub": false,
			"is_player_start": false,
		})

	# Mark one outer node as player start
	_node_data[-1]["is_player_start"] = true  # "The Last Waypost"


func _build_edge_data() -> void:
	# Hub to all inner ring
	for i in range(6):
		_edge_data.append(["badurga", "node_i%d" % i])

	# Inner ring — chain with wrap
	for i in range(6):
		_edge_data.append(["node_i%d" % i, "node_i%d" % ((i + 1) % 6)])

	# Inner → middle spokes (each inner connects to 1–2 mid nodes)
	var inner_to_mid: Array[Array] = [
		["node_i0", "node_m0"], ["node_i0", "node_m1"],
		["node_i1", "node_m1"], ["node_i1", "node_m2"],
		["node_i2", "node_m3"], ["node_i2", "node_m4"],
		["node_i3", "node_m4"], ["node_i3", "node_m5"],
		["node_i4", "node_m6"], ["node_i4", "node_m7"],
		["node_i5", "node_m7"], ["node_i5", "node_m8"], ["node_i5", "node_m0"],
	]
	for edge in inner_to_mid:
		_edge_data.append(edge)

	# Middle ring — chain with wrap + skip some for irregular feel
	for i in range(9):
		_edge_data.append(["node_m%d" % i, "node_m%d" % ((i + 1) % 9)])
	# A few chord edges across the middle ring
	_edge_data.append(["node_m0", "node_m3"])
	_edge_data.append(["node_m4", "node_m7"])

	# Middle → outer spokes (each mid connects to 1–2 outer nodes)
	var mid_to_out: Array[Array] = [
		["node_m0", "node_o0"], ["node_m0", "node_o11"],
		["node_m1", "node_o1"], ["node_m1", "node_o2"],
		["node_m2", "node_o2"], ["node_m2", "node_o3"],
		["node_m3", "node_o3"], ["node_m3", "node_o4"],
		["node_m4", "node_o4"], ["node_m4", "node_o5"],
		["node_m5", "node_o5"], ["node_m5", "node_o6"],
		["node_m6", "node_o7"], ["node_m6", "node_o8"],
		["node_m7", "node_o8"], ["node_m7", "node_o9"],
		["node_m8", "node_o9"], ["node_m8", "node_o10"], ["node_m8", "node_o11"],
	]
	for edge in mid_to_out:
		_edge_data.append(edge)

	# Outer ring — chain with wrap
	for i in range(12):
		_edge_data.append(["node_o%d" % i, "node_o%d" % ((i + 1) % 12)])
	# A couple skip-edges in the outer ring
	_edge_data.append(["node_o0", "node_o2"])
	_edge_data.append(["node_o6", "node_o9"])


## --- Scene Construction ---

func _build_scene() -> void:
	_add_background()
	_add_placeholder_label()
	_add_debug_combat_button()
	_add_edges()
	_add_nodes()
	_add_hover_label()


func _add_background() -> void:
	var bg := ColorRect.new()
	bg.size = VIEWPORT_SIZE
	bg.color = Color(0.82, 0.74, 0.58)
	add_child(bg)


func _add_placeholder_label() -> void:
	var lbl := Label.new()
	lbl.text = "[MAP SCENE]"
	lbl.position = Vector2(12.0, 8.0)
	var settings := LabelSettings.new()
	settings.font_size = 16
	settings.font_color = Color(0.2, 0.15, 0.08)
	lbl.label_settings = settings
	add_child(lbl)


func _add_debug_combat_button() -> void:
	var btn := Button.new()
	btn.text = "→ Combat (debug)"
	btn.size = Vector2(160.0, 36.0)
	btn.position = Vector2(VIEWPORT_SIZE.x - 172.0, 8.0)
	btn.pressed.connect(_on_debug_combat_pressed)
	add_child(btn)


func _add_edges() -> void:
	# Build a lookup from id to position first
	var pos_map: Dictionary = {}
	for nd in _node_data:
		pos_map[nd["id"]] = nd["position"]

	for edge in _edge_data:
		var a: String = edge[0]
		var b: String = edge[1]
		if not pos_map.has(a) or not pos_map.has(b):
			continue
		var line := Line2D.new()
		line.add_point(pos_map[a])
		line.add_point(pos_map[b])
		line.default_color = Color(0.55, 0.42, 0.28)
		line.width = 3.0
		add_child(line)


func _add_nodes() -> void:
	for nd in _node_data:
		var is_hub: bool = nd["is_hub"]
		var node_size := Vector2(56.0, 56.0) if is_hub else Vector2(32.0, 32.0)
		var node_color := Color(0.85, 0.65, 0.25) if is_hub else Color(0.72, 0.60, 0.44)

		var btn := Button.new()
		btn.size = node_size
		# Center the button on its map position
		btn.position = nd["position"] - node_size * 0.5

		# StyleBoxFlat circle appearance
		var style := StyleBoxFlat.new()
		style.bg_color = node_color
		style.corner_radius_top_left = int(node_size.x * 0.5)
		style.corner_radius_top_right = int(node_size.x * 0.5)
		style.corner_radius_bottom_left = int(node_size.x * 0.5)
		style.corner_radius_bottom_right = int(node_size.x * 0.5)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.25, 0.18, 0.10)
		btn.add_theme_stylebox_override("normal", style)

		# Hover style — slightly brighter so we can tell hover works
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = node_color.lightened(0.12)
		btn.add_theme_stylebox_override("hover", hover_style)

		# Store style refs on the button using metadata so hover callbacks can tint
		btn.set_meta("node_id", nd["id"])
		btn.set_meta("node_label", nd["label"])
		btn.set_meta("base_color", node_color)
		btn.set_meta("is_hub", is_hub)
		btn.set_meta("normal_style", style)

		btn.mouse_entered.connect(_on_node_hover_enter.bind(btn))
		btn.mouse_exited.connect(_on_node_hover_exit.bind(btn))
		btn.pressed.connect(_on_node_clicked.bind(nd["id"]))

		add_child(btn)
		_buttons[nd["id"]] = btn

		# Player start marker
		if nd["is_player_start"]:
			_add_player_marker(nd["position"])


func _add_player_marker(map_pos: Vector2) -> void:
	_player_marker = Polygon2D.new()
	# Diamond: top, right, bottom, left — ±10px
	_player_marker.polygon = PackedVector2Array([
		Vector2(0.0, -10.0),
		Vector2(10.0, 0.0),
		Vector2(0.0, 10.0),
		Vector2(-10.0, 0.0),
	])
	_player_marker.color = Color(0.3, 0.6, 1.0)
	# Center above the node circle
	_player_marker.position = map_pos + Vector2(0.0, -26.0)
	add_child(_player_marker)


func _add_hover_label() -> void:
	_hover_label = Label.new()
	_hover_label.visible = false
	_hover_label.z_index = 10
	var settings := LabelSettings.new()
	settings.font_size = 13
	settings.font_color = Color.WHITE
	settings.shadow_color = Color(0.0, 0.0, 0.0, 0.8)
	settings.shadow_offset = Vector2(1.0, 1.0)
	_hover_label.label_settings = settings
	add_child(_hover_label)


## --- Hover Callbacks ---

func _on_node_hover_enter(btn: Button) -> void:
	var node_label: String = btn.get_meta("node_label")
	var is_hub: bool = btn.get_meta("is_hub")
	var map_pos: Vector2 = btn.position + btn.size * 0.5

	# Position label centered below node
	_hover_label.text = node_label
	_hover_label.visible = true
	# Measure text width after setting so we can center it
	await get_tree().process_frame
	var label_width: float = _hover_label.size.x
	_hover_label.position = map_pos + Vector2(-label_width * 0.5, btn.size.y * 0.5 + 6.0)

	# Scale tween
	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_QUAD)

	# Hub gets a gold tint
	if is_hub:
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		tween.parallel().tween_property(style, "bg_color", Color(1.0, 0.85, 0.4), 0.12)


func _on_node_hover_exit(btn: Button) -> void:
	_hover_label.visible = false

	var is_hub: bool = btn.get_meta("is_hub")
	var base_color: Color = btn.get_meta("base_color")

	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_QUAD)

	if is_hub:
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		tween.parallel().tween_property(style, "bg_color", base_color, 0.10)


## --- Click / Debug Callbacks ---

func _on_node_clicked(node_id: String) -> void:
	print("Clicked: ", node_id)


func _on_debug_combat_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
