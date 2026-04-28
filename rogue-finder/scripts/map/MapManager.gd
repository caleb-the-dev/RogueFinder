class_name MapManager
extends Node2D

## --- Constants ---

const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const CENTER        := Vector2(640.0, 360.0)
const ZOOM_MIN      := 0.35
const ZOOM_MAX      := 2.5
const ZOOM_STEP     := 0.12

## --- Name Pools (seeded per run, never saved — regenerate identically from map_seed) ---

const INNER_NAMES: Array[String] = [
	"Ashwood Hollow", "Greymoor Pass", "Ironveil Ford",
	"Saltfen Reach", "Dunmarch Gate", "The Pale Crossing",
	"Cobbler's Row", "Millward Lane", "The Ashen Market",
	"Southgate Crossing", "Copperfield Road", "The Low Quarter",
	"Brackwater Close", "Tanner's Gate", "Guildhall Approach",
]

const MIDDLE_NAMES: Array[String] = [
	"Fenmark Road", "Crownwood Trail", "Veldthorn Outpost",
	"Harrowed Fen", "Stonewatch Ridge", "Cinder Gorge",
	"Bleak Mire", "Thornback Camp", "Ravenscar Hill",
	"Dustwood Crossing", "Ironspire Post", "The Witherhold",
	"Ashgate Reach", "Coldwood Trail", "Fallow Watch",
	"Bridgeburn Camp", "Redthorn Pass", "Hollowmere Outpost",
	"Saltcliff Road", "The Charred Keep",
]

const OUTER_NAMES: Array[String] = [
	"Coldwater Landing", "Bramblegate", "Ember Fields", "Wychwood Crossing",
	"Northfen Approach", "The Sunken Road", "Gravel Watch", "Ashford Ruins",
	"Moorvale Pass", "Duskwall Junction", "Saltmarch End", "The Last Waypost",
	"Grimholt Hollow", "Wraithfen Reach", "The Boneyard", "Shatterpeak Ruins",
	"Thornvast Edge", "Wolfscar Crossing", "Blightwood Camp", "The Forsaken Post",
	"Ironcliff Ruins", "Dreadmoor Approach", "Cragfall Outpost", "The Dying Road",
	"Witchwater Mere",
]

## --- Scene Refs ---

var _map_container: Node2D
var _buttons: Dictionary = {}   # id -> Button
var _tooltip: ColorRect
var _tooltip_label: Label
var _player_marker: Polygon2D

## --- Data ---

var _node_data: Array[Dictionary] = []
var _edge_data: Array[Array] = []
var _node_map: Dictionary = {}  # id -> Dictionary (fast lookup)
var _adjacency: Dictionary = {} # id -> Array[String]

var _inner_ids: Array[String] = []
var _middle_ids: Array[String] = []
var _outer_ids: Array[String] = []
var _outer_bridge_ids: Array[String] = []

## --- Pan State ---

var _node_prompt: Control = null
var _party_sheet: PartySheet = null
var _party_btn: Button = null
var _party_btn_rainbow: Tween = null
var _party_btn_pulse: Tween = null
var _event_manager: EventManager = null
var _is_dev_event: bool = false
var _dev_event_panel: CanvasLayer = null
var _add_item_panel: CanvasLayer = null
var _add_item_list: VBoxContainer = null   ## cached child of _add_item_panel; rebuilt on every show
var _threat_fill: ColorRect = null
var _threat_pct_lbl: Label = null

var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_container: Vector2 = Vector2.ZERO
var _drag_moved: bool = false

## --- Lifecycle ---

func _ready() -> void:
	GameState.load_save()
	if GameState.party.is_empty():
		GameState.init_party()
	# Seed must be set before both data builders so names and edges use the same seed
	if GameState.map_seed == 0:
		GameState.map_seed = randi()
	_build_node_data()
	_build_edge_data()
	_build_adjacency()
	_assign_boss_type()
	_party_sheet = PartySheet.new()
	add_child(_party_sheet)
	_event_manager = preload("res://scenes/events/EventScene.tscn").instantiate()
	add_child(_event_manager)
	_event_manager.event_finished.connect(_on_event_finished)
	_event_manager.event_nav.connect(_on_event_nav)
	_build_scene()
	_party_sheet.level_up_resolved.connect(_refresh_party_btn)
	_refresh_party_btn()

# _input (not _unhandled_input) so drag is captured even when the press starts on a Button
func _input(event: InputEvent) -> void:
	# Block all map input while any CanvasLayer overlay is open
	if _party_sheet != null and _party_sheet.visible:
		return
	if _event_manager != null and _event_manager.visible:
		return
	if _dev_event_panel != null and _dev_event_panel.visible:
		return
	if _add_item_panel != null and _add_item_panel.visible:
		return
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

	# Inner ring — 6 nodes, radius 140; labels assigned later by _assign_node_names
	_inner_ids = ["node_i0", "node_i1", "node_i2", "node_i3", "node_i4", "node_i5"]
	var inner_offsets: Array[float] = [0.0, 3.0, -5.0, 7.0, -4.0, 2.0]
	for i in range(6):
		var angle := deg_to_rad(i * 60.0 + inner_offsets[i])
		_add_node(_inner_ids[i], CENTER + Vector2(cos(angle), sin(angle)) * 140.0,
				angle, "...", false, false)

	# Middle ring — 9 nodes, radius 260
	_middle_ids = ["node_m0", "node_m1", "node_m2", "node_m3", "node_m4",
				   "node_m5", "node_m6", "node_m7", "node_m8"]
	var mid_offsets: Array[float] = [5.0, -8.0, 3.0, -3.0, 10.0, -6.0, 4.0, -2.0, 7.0]
	for i in range(9):
		var angle := deg_to_rad(i * 40.0 + mid_offsets[i])
		_add_node(_middle_ids[i], CENTER + Vector2(cos(angle), sin(angle)) * 260.0,
				angle, "...", false, false)

	# Outer ring — 12 nodes, radius 380
	var out_offsets: Array[float] = [0.0, -7.0, 5.0, -4.0, 9.0, -10.0, 3.0, -6.0, 8.0, -3.0, 6.0, -5.0]
	for i in range(12):
		var oid := "node_o%d" % i
		_outer_ids.append(oid)
		var angle := deg_to_rad(i * 30.0 + out_offsets[i])
		_add_node(oid, CENTER + Vector2(cos(angle), sin(angle)) * 380.0,
				angle, "...", false, false)

	# Mark one outer node as player start
	_node_data[-1]["is_player_start"] = true
	_node_map["node_o11"]["is_player_start"] = true

	_assign_node_types()

func _add_node(id: String, pos: Vector2, angle: float, label: String,
		is_hub: bool, is_player_start: bool) -> void:
	var nd := {
		"id": id, "position": pos, "angle": angle,
		"label": label, "is_hub": is_hub, "is_player_start": is_player_start,
		"stamp_added": false,
		"cleared_stamp_added": false,
		"node_type": GameState.node_types.get(id, "COMBAT"),
	}
	_node_data.append(nd)
	_node_map[id] = nd

func _assign_node_types() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.map_seed

	# Always regenerate names from seed — not persisted to disk
	_assign_node_names(rng)

	# Skip type generation if types were already loaded from save
	if not GameState.node_types.is_empty():
		for nd in _node_data:
			nd["node_type"] = GameState.node_types.get(nd["id"], "COMBAT")
		return

	GameState.node_types["badurga"] = "CITY"

	# Outer ring (12): BOSS assigned separately in _assign_boss_type(); provision all 12 as COMBAT/EVENT/VENDOR
	# One COMBAT will later be promoted to BOSS, yielding: 1 BOSS, 7 COMBAT, 3 EVENT, 1 VENDOR
	var outer_pool: Array[String] = [
		"COMBAT","COMBAT","COMBAT","COMBAT","COMBAT","COMBAT","COMBAT","COMBAT",
		"EVENT","EVENT","EVENT","VENDOR",
	]
	for i in range(outer_pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = outer_pool[i]; outer_pool[i] = outer_pool[j]; outer_pool[j] = tmp
	for i in range(_outer_ids.size()):
		GameState.node_types[_outer_ids[i]] = outer_pool[i]

	# Middle ring (9): COMBAT×5, EVENT×3, VENDOR×1
	var mid_pool: Array[String] = ["COMBAT","COMBAT","COMBAT","COMBAT","COMBAT","EVENT","EVENT","EVENT","VENDOR"]
	for i in range(mid_pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = mid_pool[i]; mid_pool[i] = mid_pool[j]; mid_pool[j] = tmp
	for i in range(_middle_ids.size()):
		GameState.node_types[_middle_ids[i]] = mid_pool[i]

	# Inner ring (6): COMBAT×4, EVENT×2 — no VENDOR in inner ring
	var inner_pool: Array[String] = ["COMBAT","COMBAT","COMBAT","COMBAT","EVENT","EVENT"]
	for i in range(inner_pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = inner_pool[i]; inner_pool[i] = inner_pool[j]; inner_pool[j] = tmp
	for i in range(_inner_ids.size()):
		GameState.node_types[_inner_ids[i]] = inner_pool[i]

	# Patch node_type onto already-built dicts (save deferred to _assign_boss_type)
	for nd in _node_data:
		nd["node_type"] = GameState.node_types.get(nd["id"], "COMBAT")

# Promotes one outer-ring node to BOSS, chosen after bridge endpoints are known.
# Excluded zone: each bridge node and its two outer-ring neighbors (≥ 2 hops away).
# Uses a separate RNG stream so it never interferes with the type-assignment RNG.
func _assign_boss_type() -> void:
	if GameState.node_types.values().has("BOSS"):
		return  # already saved from a previous run load

	var n := _outer_ids.size()
	var excluded: Array[String] = []
	for bridge_id in _outer_bridge_ids:
		var idx := _outer_ids.find(bridge_id)
		if idx == -1:
			continue
		for offset in [-1, 0, 1]:
			var neighbor := _outer_ids[(idx + offset + n) % n]
			if not excluded.has(neighbor):
				excluded.append(neighbor)

	var candidates: Array[String] = []
	for id in _outer_ids:
		if not excluded.has(id) and id != GameState.player_node_id:
			candidates.append(id)

	# Fallback: if exclusion zone consumed everything, allow any non-start outer node
	if candidates.is_empty():
		for id in _outer_ids:
			if id != GameState.player_node_id:
				candidates.append(id)

	var rng := RandomNumberGenerator.new()
	rng.seed = GameState.map_seed ^ 0x1B055
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = candidates[i]; candidates[i] = candidates[j]; candidates[j] = tmp

	var boss_id := candidates[0]
	GameState.node_types[boss_id] = "BOSS"
	_node_map[boss_id]["node_type"] = "BOSS"
	GameState.save()

# Seeded Fisher-Yates shuffle of each name pool; writes labels directly into _node_map dicts.
# Called on every load — names are not saved, they regenerate identically from map_seed.
func _assign_node_names(rng: RandomNumberGenerator) -> void:
	var inner_pool: Array[String] = INNER_NAMES.duplicate()
	var mid_pool:   Array[String] = MIDDLE_NAMES.duplicate()
	var outer_pool: Array[String] = OUTER_NAMES.duplicate()

	for i in range(inner_pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = inner_pool[i]; inner_pool[i] = inner_pool[j]; inner_pool[j] = tmp
	for i in range(mid_pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = mid_pool[i]; mid_pool[i] = mid_pool[j]; mid_pool[j] = tmp
	for i in range(outer_pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = outer_pool[i]; outer_pool[i] = outer_pool[j]; outer_pool[j] = tmp

	for i in range(_inner_ids.size()):
		_node_map[_inner_ids[i]]["label"] = inner_pool[i]
	for i in range(_middle_ids.size()):
		_node_map[_middle_ids[i]]["label"] = mid_pool[i]
	for i in range(_outer_ids.size()):
		_node_map[_outer_ids[i]]["label"] = outer_pool[i]

## --- Edge Data ---

func _build_edge_data() -> void:
	# Seed global RNG from already-set map_seed for deterministic topology
	seed(GameState.map_seed)

	# Each ring is a simple closed chain
	_connect_ring(_inner_ids)
	_connect_ring(_middle_ids)
	_connect_ring(_outer_ids)

	# Inner→middle gateways first; store chosen angles for cross-pair exclusion
	var im_angles := _connect_gateways_v2(_inner_ids, _middle_ids, 3, [], 90.0)

	# Middle→outer: inner→middle angles become 30° exclusion zones
	var mo_angles := _connect_gateways_v2(_middle_ids, _outer_ids, 3, im_angles, 90.0)
	# Record which outer nodes are bridge endpoints so BOSS can avoid them
	for a in mo_angles:
		var oid := _closest_to_angle(_outer_ids, a)
		if not _outer_bridge_ids.has(oid):
			_outer_bridge_ids.append(oid)

	# Hub→inner: skip the inner nodes already used as IM gateways so hub is not a shortcut
	var gateway_inner_ids: Array[String] = []
	for a in im_angles:
		var inner_id := _closest_to_angle(_inner_ids, a)
		if not gateway_inner_ids.has(inner_id):
			gateway_inner_ids.append(inner_id)
	_connect_hub_random(2, gateway_inner_ids)

func _connect_ring(ids: Array[String]) -> void:
	var n := ids.size()
	for i in range(n):
		_edge_data.append([ids[i], ids[(i + 1) % n]])

func _connect_hub_random(count: int, excluded_ids: Array[String] = []) -> void:
	var candidates: Array[String] = []
	for id in _inner_ids:
		if not excluded_ids.has(id):
			candidates.append(id)
	candidates.shuffle()
	for i in range(mini(count, candidates.size())):
		_edge_data.append(["badurga", candidates[i]])

# Places `count` bridges between ring_a and ring_b with two spacing guarantees:
#   - Intra-pair: bridges in this pair must be ≥ min_gap_deg apart from each other.
#   - Cross-pair: bridges must be ≥ 30° away from any angle in excluded_angles (previous pair).
# Returns chosen bridge angles so the caller can pass them as excluded_angles to the next pair.
func _connect_gateways_v2(
		ring_a: Array[String],
		ring_b: Array[String],
		count: int,
		excluded_angles: Array[float],
		min_gap_deg: float) -> Array[float]:
	var min_gap_rad: float    = deg_to_rad(min_gap_deg)
	var cross_excl_rad: float = deg_to_rad(30.0)
	var sector: float         = TAU / float(count)
	var chosen_angles: Array[float] = []
	var used_pairs: Dictionary = {}

	for i in range(count):
		var sector_start: float = i * sector
		var chosen: float       = sector_start + sector * 0.5  # fallback: sector centre
		var gap_relax: float    = 0.0

		for attempt in range(10):
			var candidate: float = sector_start + randf() * sector

			# Reject if too close to an already-placed bridge in this ring pair
			var too_close: bool = false
			for a: float in chosen_angles:
				var diff: float = fposmod(candidate - a, TAU)
				if diff > PI:
					diff = TAU - diff
				if diff < (min_gap_rad - gap_relax):
					too_close = true
					break

			# Reject if within 30° of any previous-pair bridge (prevents straight corridors)
			if not too_close:
				for a: float in excluded_angles:
					var diff: float = fposmod(candidate - a, TAU)
					if diff > PI:
						diff = TAU - diff
					if diff < cross_excl_rad:
						too_close = true
						break

			if not too_close:
				chosen = candidate
				break

			# Gradually relax the intra-pair gap after 5 failed attempts in this sector
			if attempt >= 4:
				gap_relax += deg_to_rad(10.0)

		chosen_angles.append(chosen)
		var a_id: String = _closest_to_angle(ring_a, chosen)
		var b_id: String = _closest_to_angle(ring_b, chosen)
		var key: String  = a_id + "|" + b_id
		if not used_pairs.has(key):
			used_pairs[key] = true
			_edge_data.append([a_id, b_id])

	return chosen_angles

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
	_add_hover_tooltip()
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

	_add_threat_meter()

	# Party / Level-Up button — top right, sole action button in the chrome
	_party_btn = Button.new()
	_party_btn.text = "Party"
	_party_btn.size = Vector2(172.0, 36.0)
	_party_btn.position = Vector2(VIEWPORT_SIZE.x - 180.0, 8.0)
	_party_btn.pressed.connect(func(): _party_sheet.show_sheet())
	add_child(_party_btn)

	# Debug controls — bottom right, out of the normal play area
	var dev_events_btn := Button.new()
	dev_events_btn.text = "Dev Menu"
	dev_events_btn.size = Vector2(100.0, 32.0)
	dev_events_btn.position = Vector2(VIEWPORT_SIZE.x - 314.0, VIEWPORT_SIZE.y - 40.0)
	dev_events_btn.pressed.connect(_toggle_dev_event_panel)
	add_child(dev_events_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete Save (debug)"
	del_btn.size = Vector2(202.0, 32.0)
	del_btn.position = Vector2(VIEWPORT_SIZE.x - 210.0, VIEWPORT_SIZE.y - 40.0)
	del_btn.pressed.connect(_on_debug_delete_save_pressed)
	add_child(del_btn)

func _add_threat_meter() -> void:
	var bar_w  := 20.0
	var bar_h  := 120.0
	var bar_x  := 12.0
	var bar_y  := 50.0
	var t: float = GameState.threat_level

	var header := Label.new()
	header.text = "THREAT"
	header.position = Vector2(bar_x, 30.0)
	var hs := LabelSettings.new()
	hs.font_size = 11
	hs.font_color = Color(0.75, 0.18, 0.12)
	header.label_settings = hs
	add_child(header)

	# Border outline
	var border := ColorRect.new()
	border.color = Color(0.45, 0.35, 0.25, 0.9)
	border.size = Vector2(bar_w + 4.0, bar_h + 4.0)
	border.position = Vector2(bar_x - 2.0, bar_y - 2.0)
	add_child(border)

	# Dark background track
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.03, 0.95)
	bg.size = Vector2(bar_w, bar_h)
	bg.position = Vector2(bar_x, bar_y)
	add_child(bg)

	# Fill — grows upward from the bottom of the bar; always present so live refresh can resize it
	var fill_h: float = t * bar_h
	var fill := ColorRect.new()
	fill.color = _threat_fill_color(t)
	fill.size = Vector2(bar_w, fill_h)
	fill.position = Vector2(bar_x, bar_y + bar_h - fill_h)
	add_child(fill)
	_threat_fill = fill

	# Quadrant tick marks at 25 / 50 / 75 %
	for pct: float in [0.25, 0.50, 0.75]:
		var tick := ColorRect.new()
		tick.color = Color(0.85, 0.80, 0.70, 0.65)
		tick.size = Vector2(bar_w, 1.5)
		tick.position = Vector2(bar_x, bar_y + bar_h * (1.0 - pct))
		add_child(tick)

	# Percentage readout below the bar
	var pct_lbl := Label.new()
	pct_lbl.text = "%d%%" % int(t * 100.0)
	pct_lbl.position = Vector2(bar_x, bar_y + bar_h + 4.0)
	var ps := LabelSettings.new()
	ps.font_size = 12
	ps.font_color = Color(0.85, 0.75, 0.65)
	pct_lbl.label_settings = ps
	add_child(pct_lbl)
	_threat_pct_lbl = pct_lbl

func _refresh_threat_meter() -> void:
	if _threat_fill == null or _threat_pct_lbl == null:
		return
	const BAR_H := 120.0
	const BAR_X := 12.0
	const BAR_Y := 50.0
	var t: float = GameState.threat_level
	var fill_h: float = t * BAR_H
	_threat_fill.size     = Vector2(20.0, fill_h)
	_threat_fill.position = Vector2(BAR_X, BAR_Y + BAR_H - fill_h)
	_threat_fill.color    = _threat_fill_color(t)
	_threat_pct_lbl.text  = "%d%%" % int(t * 100.0)

func _threat_fill_color(t: float) -> Color:
	if t < 0.25:
		return Color(0.95, 0.75, 0.10)   # yellow-orange — low threat
	elif t < 0.50:
		return Color(0.95, 0.45, 0.08)   # orange
	elif t < 0.75:
		return Color(0.90, 0.22, 0.08)   # red-orange
	else:
		return Color(0.85, 0.08, 0.08)   # bright red — critical

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

func _color_for_type(t: String) -> Color:
	match t:
		"COMBAT":  return Color(0.70, 0.22, 0.18)
		"VENDOR":  return Color(0.48, 0.22, 0.68)
		"EVENT":   return Color(0.20, 0.42, 0.72)
		"BOSS":    return Color(0.40, 0.08, 0.08)
		"CITY":    return Color(0.85, 0.65, 0.25)
		_:         return Color(0.72, 0.60, 0.44)

func _icon_for_type(t: String) -> String:
	match t:
		"COMBAT":  return "X"
		"VENDOR":  return "$"
		"EVENT":   return "?"
		"BOSS":    return "!"
		"CITY":    return "★"
		_:         return ""

func _add_type_icon(btn: Button, node_type: String) -> void:
	var icon := Label.new()
	icon.text = _icon_for_type(node_type)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	var s := LabelSettings.new()
	s.font_size = 10
	s.font_color = Color.WHITE
	icon.label_settings = s
	# Must ignore mouse or it swallows button press events
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

func _add_boss_glow(center_pos: Vector2) -> void:
	var glow := Polygon2D.new()
	var points: PackedVector2Array = []
	var glow_radius := 34.0
	for i in range(32):
		var a := TAU * i / 32.0
		points.append(center_pos + Vector2(cos(a), sin(a)) * glow_radius)
	glow.polygon = points
	glow.color = Color(0.95, 0.15, 0.05, 0.75)
	_map_container.add_child(glow)
	# Looping pulse: fade between dim and bright over ~1.6 s
	var tween := create_tween().set_loops()
	tween.tween_property(glow, "modulate:a", 0.1, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(glow, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _add_nodes() -> void:
	for nd in _node_data:
		var is_hub: bool      = nd["is_hub"]
		var node_type: String = nd["node_type"]
		var node_size: Vector2
		if is_hub:
			node_size = Vector2(56.0, 56.0)
		elif node_type == "BOSS":
			node_size = Vector2(44.0, 44.0)
		else:
			node_size = Vector2(32.0, 32.0)
		var node_color := _color_for_type(node_type)
		var radius     := int(node_size.x * 0.5)

		# Glow must be added before the button so it renders behind it
		if node_type == "BOSS":
			_add_boss_glow(nd["position"])

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

		# BOSS nodes always show a bright red border regardless of visual state
		if node_type == "BOSS":
			style.border_width_left   = 3
			style.border_width_right  = 3
			style.border_width_top    = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.80, 0.15, 0.10)

		btn.add_theme_stylebox_override("normal", style)

		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = node_color.lightened(0.12)
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.set_meta("node_id",      nd["id"])
		btn.set_meta("node_label",   nd["label"])
		btn.set_meta("node_type",    node_type)
		btn.set_meta("base_color",   node_color)
		btn.set_meta("is_hub",       is_hub)
		btn.set_meta("normal_style", style)
		btn.set_meta("map_pos",      nd["position"])

		btn.mouse_entered.connect(_on_node_hover_enter.bind(btn))
		btn.mouse_exited.connect(_on_node_hover_exit.bind(btn))
		btn.pressed.connect(_on_node_clicked.bind(nd["id"]))

		_map_container.add_child(btn)
		_add_type_icon(btn, node_type)
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

func _desc_for_type(t: String) -> String:
	match t:
		"COMBAT":  return "An enemy patrol blocks the path."
		"BOSS":    return "A powerful foe guards this location."
		"VENDOR":  return "A travelling merchant. Browse wares or pass through."
		"EVENT":   return "Something stirs here. Approach and find out."
		"CITY":    return "Badurga, the hub city. The heart of civilization in these parts."
		_:         return ""

func _add_hover_tooltip() -> void:
	_tooltip = ColorRect.new()
	_tooltip.color = Color(0.10, 0.08, 0.06, 0.88)
	_tooltip.visible = false
	_tooltip.z_index = 10
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_container.add_child(_tooltip)

	_tooltip_label = Label.new()
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := LabelSettings.new()
	s.font_size = 12
	s.font_color = Color.WHITE
	_tooltip_label.label_settings = s
	_tooltip.add_child(_tooltip_label)

## --- Node Visual States ---

func _refresh_all_node_visuals() -> void:
	for nd in _node_data:
		var id: String = nd["id"]
		var btn: Button = _buttons[id]
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		var base_color: Color = btn.get_meta("base_color")

		var is_current: bool   = id == GameState.player_node_id
		var is_cleared: bool   = GameState.cleared_nodes.has(id) and nd["node_type"] != "CITY"
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
			if is_cleared:
				_add_cleared_stamp(btn, nd)
		elif is_reachable:
			style.bg_color = base_color
			style.border_color = Color(0.25, 0.18, 0.10)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
			btn.modulate = Color(1, 1, 1, 1)
		elif is_cleared:
			style.bg_color = base_color.darkened(0.35)
			style.border_color = Color(0.25, 0.18, 0.10)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
			btn.modulate = Color(1, 1, 1, 0.85)
			_add_cleared_stamp(btn, nd)
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

func _add_cleared_stamp(btn: Button, nd: Dictionary) -> void:
	if nd["cleared_stamp_added"]:
		return
	nd["cleared_stamp_added"] = true
	var stamp := Label.new()
	stamp.text = "✗"
	stamp.set_anchors_preset(Control.PRESET_FULL_RECT)
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := LabelSettings.new()
	s.font_size = 18
	s.font_color = Color(1.0, 0.18, 0.12)
	s.outline_size = 2
	s.outline_color = Color(0.0, 0.0, 0.0, 0.7)
	stamp.label_settings = s
	btn.add_child(stamp)

## --- Traversal ---

func _move_player_to(node_id: String) -> void:
	_dismiss_prompt()
	GameState.move_player(node_id)
	# +5% for each node traversal, regardless of whether you enter it
	GameState.threat_level = minf(GameState.threat_level + 0.05, 1.0)
	GameState.save()
	_refresh_threat_meter()
	var target_pos: Vector2 = _node_map[node_id]["position"] + Vector2(0.0, -26.0)
	var tween := create_tween()
	tween.tween_property(_player_marker, "position", target_pos, 0.25) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_refresh_all_node_visuals()
	await tween.finished

	if GameState.cleared_nodes.has(node_id):
		return  # cleared nodes are pass-through

	var node_type: String = GameState.node_types.get(node_id, "COMBAT")
	if node_type == "COMBAT" or node_type == "BOSS" or node_type == "EVENT":
		_enter_current_node()
	else:
		_show_node_prompt(node_id)
	GameState.save()

## --- Node Prompt ---

func _show_node_prompt(node_id: String) -> void:
	_dismiss_prompt()

	var node_type: String  = GameState.node_types.get(node_id, "EVENT")
	var node_label: String = _node_map[node_id]["label"]
	var type_color: Color  = _color_for_type(node_type).lightened(0.25)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400.0, 0.0)
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.07, 0.05, 0.03, 0.94)
	style.border_width_left   = 2; style.border_width_right  = 2
	style.border_width_top    = 2; style.border_width_bottom = 2
	style.border_color        = _color_for_type(node_type)
	style.corner_radius_top_left    = 6; style.corner_radius_top_right   = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	style.content_margin_left  = 20.0; style.content_margin_right  = 20.0
	style.content_margin_top   = 16.0; style.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	_node_prompt = panel

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = node_label + "  [" + node_type.capitalize() + "]"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", type_color)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var desc := Label.new()
	desc.text = _desc_for_type(node_type)
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(360.0, 0.0)
	vbox.add_child(desc)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var enter_btn := Button.new()
	enter_btn.text = "Enter"
	enter_btn.custom_minimum_size = Vector2(120.0, 40.0)
	enter_btn.add_theme_font_size_override("font_size", 15)
	enter_btn.pressed.connect(_on_prompt_enter.bind(node_id))
	hbox.add_child(enter_btn)

	var pass_btn := Button.new()
	pass_btn.text = "Keep Moving"
	pass_btn.custom_minimum_size = Vector2(120.0, 40.0)
	pass_btn.add_theme_font_size_override("font_size", 15)
	pass_btn.pressed.connect(_on_prompt_pass)
	hbox.add_child(pass_btn)

	# Position after one frame so PanelContainer has computed its size
	await get_tree().process_frame
	if is_instance_valid(panel):
		panel.position = Vector2(
			(VIEWPORT_SIZE.x - panel.size.x) * 0.5,
			VIEWPORT_SIZE.y - panel.size.y - 40.0
		)

func _dismiss_prompt() -> void:
	if _node_prompt != null and is_instance_valid(_node_prompt):
		_node_prompt.queue_free()
	_node_prompt = null

func _on_prompt_enter(node_id: String) -> void:
	_dismiss_prompt()
	# node_id == GameState.player_node_id at this point
	_enter_current_node()

func _on_prompt_pass() -> void:
	_dismiss_prompt()

## --- Hover Callbacks ---

func _on_node_hover_enter(btn: Button) -> void:
	var node_id: String   = btn.get_meta("node_id")
	var node_type: String = btn.get_meta("node_type")
	var is_locked: bool   = not GameState.is_visited(node_id) \
		and not GameState.is_adjacent_to_player(node_id, _adjacency) \
		and node_id != GameState.player_node_id
	# Always show Badurga's tooltip so the player knows it exists
	var is_hub: bool = btn.get_meta("is_hub")
	if is_locked and not is_hub:
		return

	var map_pos: Vector2 = btn.get_meta("map_pos")
	var type_str: String = node_type.capitalize()
	_tooltip_label.text = btn.get_meta("node_label") + " [" + type_str + "]\n" + _desc_for_type(node_type)
	_tooltip.visible = true

	# Wait one frame for the label to compute its size before positioning
	await get_tree().process_frame
	var pad := Vector2(8.0, 6.0)
	_tooltip_label.position = pad
	_tooltip.size = _tooltip_label.size + pad * 2.0
	_tooltip.position = map_pos + Vector2(-_tooltip.size.x * 0.5,
			-btn.size.y * 0.5 - _tooltip.size.y - 6.0)

	if is_locked:
		return  # tooltip shown; skip scale/tint for unreachable hub

	var tween := create_tween()
	tween.tween_property(btn, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_QUAD)

	if is_hub:
		var style: StyleBoxFlat = btn.get_meta("normal_style")
		tween.parallel().tween_property(style, "bg_color", Color(1.0, 0.85, 0.4), 0.12)

func _on_node_hover_exit(btn: Button) -> void:
	_tooltip.visible = false
	var is_hub: bool = btn.get_meta("is_hub")
	var base: Color  = btn.get_meta("base_color")

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
		if _node_prompt == null and (_event_manager == null or not _event_manager.visible):
			_enter_current_node()
		return
	if not GameState.is_adjacent_to_player(node_id, _adjacency):
		return
	_move_player_to(node_id)

func _enter_current_node() -> void:
	if GameState.cleared_nodes.has(GameState.player_node_id):
		return  # cleared nodes are pass-through — no entry increment
	# +5% for actually entering any non-cleared node (city counts — you crossed the gate)
	GameState.threat_level = minf(GameState.threat_level + 0.05, 1.0)
	GameState.save()
	_refresh_threat_meter()
	var node_type: String = GameState.node_types.get(GameState.player_node_id, "COMBAT")
	match node_type:
		"COMBAT", "BOSS":
			GameState.current_combat_node_id = GameState.player_node_id
			get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
		"CITY":
			get_tree().change_scene_to_file("res://scenes/city/BadurgaScene.tscn")
		"EVENT":
			var ring := _get_ring(GameState.player_node_id)
			var event_data := EventSelector.pick_for_node(ring)
			_event_manager.show_event(event_data)
		_:
			GameState.pending_node_type = node_type
			get_tree().change_scene_to_file("res://scenes/misc/NodeStub.tscn")

func _get_ring(node_id: String) -> String:
	if "node_i" in node_id:
		return "inner"
	elif "node_m" in node_id:
		return "middle"
	elif "node_o" in node_id:
		return "outer"
	return "outer"  # fallback for badurga or unrecognized

func _refresh_party_btn() -> void:
	if _party_btn == null or not is_instance_valid(_party_btn):
		return
	var has_pending: bool = GameState.party.any(func(pc: CombatantData) -> bool:
		return pc.pending_level_ups > 0
	)
	if has_pending:
		_party_btn.text = "Level Up Available"
		if _party_btn_rainbow == null or not _party_btn_rainbow.is_valid():
			_party_btn_rainbow = create_tween().set_loops()
			for c: Color in [
				Color(1.0, 0.0, 0.0), Color(1.0, 0.5, 0.0), Color(1.0, 1.0, 0.0),
				Color(0.0, 1.0, 0.0), Color(0.0, 0.5, 1.0), Color(0.6, 0.0, 1.0),
			]:
				_party_btn_rainbow.tween_property(_party_btn, "modulate", c, 0.32)
		if _party_btn_pulse == null or not _party_btn_pulse.is_valid():
			_party_btn.pivot_offset = Vector2(86.0, 18.0)
			_party_btn_pulse = create_tween().set_loops()
			_party_btn_pulse.tween_property(_party_btn, "scale", Vector2(1.07, 1.07), 0.55) \
				.set_trans(Tween.TRANS_SINE)
			_party_btn_pulse.tween_property(_party_btn, "scale", Vector2(1.0, 1.0), 0.55) \
				.set_trans(Tween.TRANS_SINE)
	else:
		_party_btn.text = "Party"
		_party_btn.modulate = Color.WHITE
		_party_btn.scale    = Vector2.ONE
		if _party_btn_rainbow != null:
			_party_btn_rainbow.kill()
			_party_btn_rainbow = null
		if _party_btn_pulse != null:
			_party_btn_pulse.kill()
			_party_btn_pulse = null

func _on_event_finished() -> void:
	_refresh_threat_meter()
	_refresh_party_btn()
	if _is_dev_event:
		_is_dev_event = false
		return
	if not GameState.cleared_nodes.has(GameState.player_node_id):
		GameState.cleared_nodes.append(GameState.player_node_id)
	_refresh_all_node_visuals()

func _on_event_nav(dest: String) -> void:
	if _is_dev_event:
		_is_dev_event = false
		return  # dev-fired nav events don't route or clear nodes
	if not GameState.cleared_nodes.has(GameState.player_node_id):
		GameState.cleared_nodes.append(GameState.player_node_id)
	GameState.save()
	GameState.pending_node_type = dest
	get_tree().change_scene_to_file("res://scenes/misc/NodeStub.tscn")

func _on_debug_delete_save_pressed() -> void:
	GameState.delete_save()
	GameState.reset()
	get_tree().reload_current_scene()

## --- Dev Event Panel ---

func _toggle_dev_event_panel() -> void:
	if _dev_event_panel == null:
		_build_dev_event_panel()
	_dev_event_panel.visible = not _dev_event_panel.visible

func _build_dev_event_panel() -> void:
	_dev_event_panel = CanvasLayer.new()
	_dev_event_panel.layer = 30
	add_child(_dev_event_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_dev_event_panel.add_child(bg)

	var pw := 680.0
	var ph := 520.0
	var panel := PanelContainer.new()
	panel.position = Vector2((VIEWPORT_SIZE.x - pw) * 0.5, (VIEWPORT_SIZE.y - ph) * 0.5)
	panel.custom_minimum_size = Vector2(pw, ph)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color            = Color(0.08, 0.06, 0.04, 0.96)
	pstyle.border_width_left   = 2
	pstyle.border_width_right  = 2
	pstyle.border_width_top    = 2
	pstyle.border_width_bottom = 2
	pstyle.border_color              = Color(0.40, 0.30, 0.20)
	pstyle.corner_radius_top_left    = 6
	pstyle.corner_radius_top_right   = 6
	pstyle.corner_radius_bottom_left = 6
	pstyle.corner_radius_bottom_right = 6
	pstyle.content_margin_left   = 20.0
	pstyle.content_margin_right  = 20.0
	pstyle.content_margin_top    = 16.0
	pstyle.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", pstyle)
	_dev_event_panel.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "[DEV] Dev Menu"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.80, 0.75, 0.60))
	header_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	close_btn.pressed.connect(func(): _dev_event_panel.visible = false)
	header_row.add_child(close_btn)

	# --- XP / Level-Up section ---
	var xp_hdr := Label.new()
	xp_hdr.text = "XP / LEVEL"
	xp_hdr.add_theme_font_size_override("font_size", 11)
	xp_hdr.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	vbox.add_child(xp_hdr)

	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(xp_row)

	var grant_xp_btn := Button.new()
	grant_xp_btn.text = "Grant XP +20 (all)"
	grant_xp_btn.custom_minimum_size = Vector2(160.0, 32.0)
	grant_xp_btn.add_theme_font_size_override("font_size", 13)
	grant_xp_btn.pressed.connect(func() -> void:
		GameState.grant_xp(20)
		_refresh_party_btn()
	)
	xp_row.add_child(grant_xp_btn)

	var force_lvl_btn := Button.new()
	force_lvl_btn.text = "Force Level-Up (all)"
	force_lvl_btn.custom_minimum_size = Vector2(160.0, 32.0)
	force_lvl_btn.add_theme_font_size_override("font_size", 13)
	force_lvl_btn.pressed.connect(func() -> void:
		for pc: CombatantData in GameState.party:
			if not pc.is_dead:
				pc.level = mini(pc.level + 1, 20)
				pc.pending_level_ups += 1
		GameState.save()
		_refresh_party_btn()
	)
	xp_row.add_child(force_lvl_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# --- Combat section ---
	var combat_hdr := Label.new()
	combat_hdr.text = "COMBAT"
	combat_hdr.add_theme_font_size_override("font_size", 11)
	combat_hdr.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	vbox.add_child(combat_hdr)

	var test_room_row := HBoxContainer.new()
	test_room_row.add_theme_constant_override("separation", 8)
	vbox.add_child(test_room_row)

	var armor_showcase_btn := Button.new()
	armor_showcase_btn.text = "⚔ Test Room — Armor Showcase"
	armor_showcase_btn.custom_minimum_size = Vector2(220.0, 32.0)
	armor_showcase_btn.add_theme_font_size_override("font_size", 13)
	armor_showcase_btn.pressed.connect(func() -> void:
		_dev_event_panel.visible = false
		GameState.test_room_mode = true
		GameState.test_room_kind = "armor_showcase"
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
	)
	test_room_row.add_child(armor_showcase_btn)

	var armor_mod_btn := Button.new()
	armor_mod_btn.text = "⚔ Test Room — Armor Mod"
	armor_mod_btn.custom_minimum_size = Vector2(220.0, 32.0)
	armor_mod_btn.add_theme_font_size_override("font_size", 13)
	armor_mod_btn.pressed.connect(func() -> void:
		_dev_event_panel.visible = false
		GameState.test_room_mode = true
		GameState.test_room_kind = "armor_mod"
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
	)
	test_room_row.add_child(armor_mod_btn)

	var recruit_test_btn := Button.new()
	recruit_test_btn.text = "⊕ Test Room — Recruit"
	recruit_test_btn.custom_minimum_size = Vector2(220.0, 32.0)
	recruit_test_btn.add_theme_font_size_override("font_size", 13)
	recruit_test_btn.pressed.connect(func() -> void:
		_dev_event_panel.visible = false
		GameState.test_room_mode = true
		GameState.test_room_kind = "recruit_test"
		get_tree().change_scene_to_file("res://scenes/combat/CombatScene3D.tscn")
	)
	test_room_row.add_child(recruit_test_btn)

	var sep_combat := HSeparator.new()
	vbox.add_child(sep_combat)

	# --- Inventory section ---
	var inv_hdr := Label.new()
	inv_hdr.text = "INVENTORY"
	inv_hdr.add_theme_font_size_override("font_size", 11)
	inv_hdr.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	vbox.add_child(inv_hdr)

	var inv_row := HBoxContainer.new()
	inv_row.add_theme_constant_override("separation", 8)
	vbox.add_child(inv_row)

	var add_item_btn := Button.new()
	add_item_btn.text = "+ Add Item to Inventory"
	add_item_btn.custom_minimum_size = Vector2(220.0, 32.0)
	add_item_btn.add_theme_font_size_override("font_size", 13)
	add_item_btn.pressed.connect(func() -> void:
		_dev_event_panel.visible = false
		_show_add_item_panel()
	)
	inv_row.add_child(add_item_btn)

	var add_bench_btn := Button.new()
	add_bench_btn.text = "⊕ Add Random to Bench"
	add_bench_btn.custom_minimum_size = Vector2(200.0, 32.0)
	add_bench_btn.add_theme_font_size_override("font_size", 13)
	add_bench_btn.pressed.connect(func() -> void:
		var all_archs: Array[ArchetypeData] = ArchetypeLibrary.all_archetypes()
		var pool: Array[ArchetypeData] = []
		for a: ArchetypeData in all_archs:
			if a.archetype_id != "RogueFinder":
				pool.append(a)
		if pool.is_empty():
			return
		var pick: ArchetypeData = pool[randi() % pool.size()]
		var f: CombatantData = ArchetypeLibrary.create(pick.archetype_id, "", true)
		if not GameState.add_to_bench(f):
			push_warning("DevMenu: bench is full (%d/%d)" % [GameState.bench.size(), GameState.BENCH_CAP])
	)
	inv_row.add_child(add_bench_btn)

	var give_gold_btn := Button.new()
	give_gold_btn.text = "+ Give Gold +100"
	give_gold_btn.custom_minimum_size = Vector2(180.0, 32.0)
	give_gold_btn.add_theme_font_size_override("font_size", 13)
	give_gold_btn.pressed.connect(func() -> void:
		GameState.gold += 100
		GameState.save()
	)
	inv_row.add_child(give_gold_btn)

	var sep_inv := HSeparator.new()
	vbox.add_child(sep_inv)

	# --- Events section ---
	var evt_hdr := Label.new()
	evt_hdr.text = "EVENTS"
	evt_hdr.add_theme_font_size_override("font_size", 11)
	evt_hdr.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	vbox.add_child(evt_hdr)

	var hint := Label.new()
	hint.text = "Fired events do not clear the current node or consume the event pool."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	vbox.add_child(hint)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	for ev in EventLibrary.all_events():
		var event_data := ev as EventData
		var rings: String = ", ".join(event_data.ring_eligibility)
		var row_btn := Button.new()
		row_btn.text = "%s  [%s]" % [event_data.title, rings]
		row_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row_btn.add_theme_font_size_override("font_size", 13)
		row_btn.custom_minimum_size = Vector2(0.0, 32.0)
		row_btn.pressed.connect(_on_dev_event_selected.bind(event_data))
		list.add_child(row_btn)

func _on_dev_event_selected(event_data: EventData) -> void:
	_dev_event_panel.visible = false
	_is_dev_event = true
	_event_manager.show_event(event_data)

## --- Add Item Dev Panel ---

## Lazy-built modal listing every equipment piece + every consumable in A-Z order.
## Click a row to drop the item directly into GameState.inventory and close the panel.
## Uses the same CanvasLayer pattern as the dev event panel so input gating already works.
func _show_add_item_panel() -> void:
	if _add_item_panel == null:
		_build_add_item_panel()
	_refresh_add_item_list()
	_add_item_panel.visible = true

func _build_add_item_panel() -> void:
	_add_item_panel = CanvasLayer.new()
	_add_item_panel.layer = 30
	add_child(_add_item_panel)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_item_panel.add_child(bg)

	var pw := 600.0
	var ph := 540.0
	var panel := PanelContainer.new()
	panel.position = Vector2((VIEWPORT_SIZE.x - pw) * 0.5, (VIEWPORT_SIZE.y - ph) * 0.5)
	panel.custom_minimum_size = Vector2(pw, ph)
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color            = Color(0.08, 0.06, 0.04, 0.96)
	pstyle.border_width_left   = 2; pstyle.border_width_right  = 2
	pstyle.border_width_top    = 2; pstyle.border_width_bottom = 2
	pstyle.border_color              = Color(0.40, 0.30, 0.20)
	pstyle.corner_radius_top_left    = 6; pstyle.corner_radius_top_right   = 6
	pstyle.corner_radius_bottom_left = 6; pstyle.corner_radius_bottom_right = 6
	pstyle.content_margin_left   = 20.0; pstyle.content_margin_right  = 20.0
	pstyle.content_margin_top    = 16.0; pstyle.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", pstyle)
	_add_item_panel.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "[DEV] Add Item to Inventory"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", Color(0.80, 0.75, 0.60))
	header_row.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(32.0, 32.0)
	close_btn.pressed.connect(func(): _add_item_panel.visible = false)
	header_row.add_child(close_btn)

	var hint := Label.new()
	hint.text = "Click any row to drop a copy into the bag. Equipment and consumables are listed alphabetically."
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.60, 0.55, 0.45))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(pw - 40.0, 0.0)
	vbox.add_child(hint)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_add_item_list = VBoxContainer.new()
	_add_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_item_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_add_item_list)

## Rebuilds the list contents from EquipmentLibrary + ConsumableLibrary, sorted A-Z by name.
## Called every time the panel is shown so newly-added CSV rows appear without a restart.
func _refresh_add_item_list() -> void:
	if _add_item_list == null:
		return
	for child in _add_item_list.get_children():
		child.queue_free()

	var rows: Array = []
	for eq: EquipmentData in EquipmentLibrary.all_equipment():
		rows.append({
			"name": eq.equipment_name,
			"id":   eq.equipment_id,
			"slot": EquipmentData.Slot.keys()[eq.slot].capitalize(),
			"item_type": "equipment",
			"description": eq.description,
		})
	for con: ConsumableData in ConsumableLibrary.all_consumables():
		rows.append({
			"name": con.consumable_name,
			"id":   con.consumable_id,
			"slot": "Consumable",
			"item_type": "consumable",
			"description": con.description,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"].to_lower() < b["name"].to_lower()
	)

	for row in rows:
		var btn := Button.new()
		btn.text = "%s  [%s]" % [row["name"], row["slot"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 13)
		btn.custom_minimum_size = Vector2(0.0, 32.0)
		btn.tooltip_text = row["description"]
		btn.pressed.connect(_on_add_item_selected.bind(row))
		_add_item_list.add_child(btn)

func _on_add_item_selected(row: Dictionary) -> void:
	GameState.add_to_inventory({
		"id":          row["id"],
		"name":        row["name"],
		"description": row["description"],
		"item_type":   row["item_type"],
	})
	GameState.save()
	_add_item_panel.visible = false
