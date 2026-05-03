class_name Unit3D
extends Node3D

## --- Unit3D ---
## 3D representation of a combat unit using a MeshInstance3D box placeholder.
## All child nodes are built in _ready() — the .tscn stays minimal.
## Mirrors the public API of Unit.gd so HUD / CombatManager work with both.

signal unit_died(unit: Unit3D)

@export var data: CombatantData

var current_hp: int = 0
var is_alive: bool  = true

const BOX_SIZE: Vector3     = Vector3(0.7, 1.6, 0.7)
const BOX_HALF_HEIGHT: float = 0.8   # BOX_SIZE.y / 2 — keeps feet at y = 0

var _mesh: MeshInstance3D           = null
var _selection_ring: MeshInstance3D = null
var _label: Label3D                 = null
var _hp_bar: Label3D                = null
var _body_mat: StandardMaterial3D   = null  # kept for hit-flash restore
var _base_color: Color              = Color.WHITE
var _buff_indicator: Label3D        = null  # ▲ shown when unit has active buffs
var _debuff_indicator: Label3D      = null  # ▼ shown when unit has active debuffs
var _countdown_label: Label3D       = null  # floating countdown number above head

func _ready() -> void:
	_build_visuals()
	if data != null:
		current_hp = data.current_hp
		is_alive = current_hp > 0
		_refresh_visuals()

## --- Visual Construction ---

func _build_visuals() -> void:
	# --- Box body (placeholder sprite) ---
	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BOX_SIZE
	_mesh.mesh     = box
	_mesh.position = Vector3(0.0, BOX_HALF_HEIGHT, 0.0)

	_body_mat = StandardMaterial3D.new()
	_body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = _body_mat
	add_child(_mesh)

	# --- Selection ring (flat cylinder at foot level) ---
	_selection_ring = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.55
	cyl.bottom_radius = 0.55
	cyl.height        = 0.06
	cyl.rings         = 1
	_selection_ring.mesh = cyl
	_selection_ring.position = Vector3(0.0, 0.03, 0.0)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode   = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color   = Color(1.0, 0.88, 0.0, 0.88)
	ring_mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	_selection_ring.material_override = ring_mat
	_selection_ring.visible = false
	add_child(_selection_ring)

	# --- Name label (billboard, above the box) ---
	_label = Label3D.new()
	_label.position      = Vector3(0.0, BOX_SIZE.y + 0.5, 0.0)
	_label.font_size     = 28
	_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.modulate      = Color.WHITE
	add_child(_label)

	# --- HP bar (billboard, between name and box top) ---
	_hp_bar = Label3D.new()
	_hp_bar.position      = Vector3(0.0, BOX_SIZE.y + 0.2, 0.0)
	_hp_bar.font_size     = 18
	_hp_bar.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_bar.no_depth_test = true
	add_child(_hp_bar)

	# --- Buff / debuff indicators (small arrows above the name label) ---
	_buff_indicator = Label3D.new()
	_buff_indicator.position      = Vector3(-0.22, BOX_SIZE.y + 0.85, 0.0)
	_buff_indicator.font_size     = 16
	_buff_indicator.text          = "▲"
	_buff_indicator.modulate      = Color(0.30, 1.00, 0.45)   # green
	_buff_indicator.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_buff_indicator.no_depth_test = true
	_buff_indicator.visible       = false
	add_child(_buff_indicator)

	_debuff_indicator = Label3D.new()
	_debuff_indicator.position      = Vector3(0.22, BOX_SIZE.y + 0.85, 0.0)
	_debuff_indicator.font_size     = 16
	_debuff_indicator.text          = "▼"
	_debuff_indicator.modulate      = Color(1.00, 0.32, 0.22)  # red-orange
	_debuff_indicator.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_debuff_indicator.no_depth_test = true
	_debuff_indicator.visible       = false
	add_child(_debuff_indicator)

	# Countdown number (autobattler) — ticks down to 0 each turn
	_countdown_label = Label3D.new()
	_countdown_label.position      = Vector3(0.0, BOX_SIZE.y + 1.25, 0.0)
	_countdown_label.font_size     = 52
	_countdown_label.outline_size  = 4
	_countdown_label.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	_countdown_label.no_depth_test = true
	_countdown_label.modulate      = Color(1.0, 0.9, 0.25)  # gold
	_countdown_label.text          = ""
	add_child(_countdown_label)

## --- Public API ---

func take_damage(amount: int) -> void:
	current_hp = maxi(0, current_hp - amount)
	show_floating_text("-%d" % amount, Color(1.0, 0.22, 0.18))
	if current_hp == 0 and is_alive:
		is_alive = false
		_refresh_visuals()
		unit_died.emit(self)
		return
	# Fire-and-forget flash (runs asynchronously)
	_play_hit_flash()
	_refresh_visuals()

func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, data.hp_max)
	show_floating_text("+%d" % amount, Color(0.18, 1.0, 0.38))
	_refresh_visuals()

func set_selected(selected: bool) -> void:
	if _selection_ring:
		_selection_ring.visible = selected

func update_countdown_display(value: int) -> void:
	if _countdown_label != null:
		_countdown_label.text = str(value)

## Called by CombatManagerAuto after modifying data.current_hp to keep the visual in sync.
func sync_from_data() -> void:
	if data == null:
		return
	var was_alive := is_alive
	current_hp = data.current_hp
	is_alive = current_hp > 0
	_refresh_visuals()
	if was_alive and not is_alive:
		unit_died.emit(self)

## --- Visual Helpers ---

func _refresh_visuals() -> void:
	if not is_node_ready():
		return
	if _label and data:
		# Enemies with no character_name show their archetype label instead
		if data.character_name != "":
			_label.text = data.character_name
		else:
			_label.text = data.archetype_id.replace("_", " ").capitalize()
	if _hp_bar and data:
		_refresh_hp_bar()
	_update_base_color()
	_apply_base_color()

func _refresh_hp_bar() -> void:
	var ratio: float = float(current_hp) / float(data.hp_max) if data.hp_max > 0 else 0.0
	var filled: int  = roundi(ratio * 8.0)
	var bar := ""
	for i in range(8):
		bar += "█" if i < filled else "░"
	_hp_bar.text = bar
	if ratio > 0.66:
		_hp_bar.modulate = Color(0.25, 1.0, 0.35)   # green
	elif ratio > 0.33:
		_hp_bar.modulate = Color(1.0, 0.85, 0.15)   # yellow
	else:
		_hp_bar.modulate = Color(1.0, 0.25, 0.22)   # red

func _update_base_color() -> void:
	if not is_alive:
		_base_color = Color(0.25, 0.25, 0.25)
	elif data and data.is_player_unit:
		_base_color = Color(0.22, 0.50, 1.0)
	else:
		_base_color = Color(1.0, 0.28, 0.22)

func _apply_base_color() -> void:
	if _body_mat:
		_body_mat.albedo_color = _base_color

## --- Animations ---

## Spawns a floating Label3D above the unit that rises and fades out. Fire-and-forget.
## Small random X offset prevents stacking when multiple effects land simultaneously.
func show_floating_text(text: String, color: Color) -> void:
	var lbl := Label3D.new()
	lbl.text          = text
	lbl.font_size     = 36
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate      = color
	lbl.position      = Vector3(randf_range(-0.3, 0.3), BOX_SIZE.y + 1.1, 0.0)
	add_child(lbl)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 1.5, 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5)
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

## Shows the ability name centered above the unit for ~2.5 s — enemy-only, fire-and-forget.
## Stays roughly in place (slow rise) so it reads clearly without obscuring HP/damage text.
func show_action_text(ability_name: String) -> void:
	var lbl := Label3D.new()
	lbl.text          = ability_name
	lbl.font_size     = 34
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate      = Color(0.45, 0.95, 1.0)   # light cyan — distinct from damage (red) and buffs (green)
	lbl.position      = Vector3(0.0, BOX_SIZE.y + 1.9, 0.0)
	add_child(lbl)

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y + 0.4, 2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 2.5)
	await tw.finished
	if is_instance_valid(lbl):
		lbl.queue_free()

## Lunge 35% toward target, then return. Fire-and-forget.
func play_attack_anim(target_world: Vector3) -> void:
	var start: Vector3 = global_position
	var dir: Vector3   = target_world - start
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	var lunge: Vector3 = start + dir * 0.7

	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", lunge, 0.10)
	tw.tween_property(self, "global_position", start, 0.20)
	# Caller can await this function if it needs to know when the lunge lands
	await get_tree().create_timer(0.10).timeout

## Flash white for 0.12 s on hit, then restore original material.
func _play_hit_flash() -> void:
	if not _mesh or not _body_mat:
		return
	var flash := StandardMaterial3D.new()
	flash.shading_mode  = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.albedo_color  = Color.WHITE
	_mesh.material_override = flash
	await get_tree().create_timer(0.12).timeout
	# Restore — guard in case node was freed during the wait
	if is_instance_valid(_mesh):
		_mesh.material_override = _body_mat

## --- 8-Directional Sprite Index ---
## Returns 0-7 based on viewing angle from the camera. (For future sprite sheets.)
func get_sprite_dir(camera_forward: Vector3) -> int:
	var to_cam: Vector3 = -camera_forward
	to_cam.y = 0.0
	if to_cam.length() < 0.01:
		return 0
	to_cam = to_cam.normalized()
	var angle: float = atan2(to_cam.x, to_cam.z)
	return roundi((angle + PI) / TAU * 8.0) % 8
