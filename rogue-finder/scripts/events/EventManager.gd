class_name EventManager
extends CanvasLayer

## --- EventManager ---
## CanvasLayer overlay (layer 10) driven by MapManager for EVENT nodes.
## Renders event title/body/choices, evaluates conditions, dispatches effects.
## Static condition/effect methods are headless-testable without a live scene.

signal event_finished
signal event_nav(dest: String)
signal target_picked(target: CombatantData)
signal bench_target_picked(index: int)

## --- UI Nodes ---

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _choices_container: VBoxContainer
var _result_panel: VBoxContainer
var _result_label: Label
var _picker_centering: CenterContainer = null
var _bench_picker_centering: Control = null

## --- Lifecycle ---

func _ready() -> void:
	layer = 10
	visible = false
	add_to_group("blocks_pause")
	_build_ui()

func _build_ui() -> void:
	# Full-viewport dimming rect behind the panel
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 0.60)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var centering := CenterContainer.new()
	centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	centering.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(centering)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(700.0, 500.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.05, 0.03, 0.97)
	panel_style.border_width_left   = 2; panel_style.border_width_right  = 2
	panel_style.border_width_top    = 2; panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.45, 0.35, 0.22)
	panel_style.corner_radius_top_left     = 6; panel_style.corner_radius_top_right   = 6
	panel_style.corner_radius_bottom_left  = 6; panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left  = 28.0; panel_style.content_margin_right  = 28.0
	panel_style.content_margin_top   = 24.0; panel_style.content_margin_bottom = 24.0
	_panel.add_theme_stylebox_override("panel", panel_style)
	centering.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vbox.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.add_theme_font_size_override("font_size", 14)
	_body_label.add_theme_color_override("font_color", Color(0.85, 0.82, 0.78))
	vbox.add_child(_body_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_choices_container)

	# Hidden until a non-nav choice is taken
	_result_panel = VBoxContainer.new()
	_result_panel.add_theme_constant_override("separation", 12)
	_result_panel.visible = false
	vbox.add_child(_result_panel)

	_result_label = Label.new()
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_label.add_theme_font_size_override("font_size", 14)
	_result_label.add_theme_color_override("font_color", Color(0.75, 0.90, 0.65))
	_result_panel.add_child(_result_label)

	var continue_hbox := HBoxContainer.new()
	continue_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_panel.add_child(continue_hbox)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(160.0, 40.0)
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.pressed.connect(_on_continue_pressed)
	continue_hbox.add_child(continue_btn)

## --- Public API ---

func show_event(event_data: EventData) -> void:
	_title_label.text = event_data.title
	_body_label.text  = event_data.body

	for child in _choices_container.get_children():
		child.queue_free()

	var party := GameState.party
	for choice: EventChoiceData in event_data.choices:
		var btn := Button.new()
		btn.text = choice.label
		btn.custom_minimum_size = Vector2(0.0, 40.0)
		btn.add_theme_font_size_override("font_size", 14)
		btn.size_flags_horizontal = Control.SIZE_FILL

		var enabled := true
		for cond: String in choice.conditions:
			if not evaluate_condition(cond, party):
				enabled = false
				break

		if not enabled:
			btn.disabled = true
			btn.modulate = Color(1.0, 1.0, 1.0, 0.45)

		btn.pressed.connect(_on_choice_pressed.bind(choice))
		_choices_container.add_child(btn)

	_result_panel.visible = false
	_choices_container.visible = true
	visible = true

func hide_event() -> void:
	visible = false
	for child in _choices_container.get_children():
		child.queue_free()
	_result_panel.visible = false
	_choices_container.visible = true

## --- Choice Handling ---

func _on_choice_pressed(choice: EventChoiceData) -> void:
	# Nav effects terminate immediately — no result panel
	for effect: Dictionary in choice.effects:
		match effect.get("type", ""):
			"open_vendor":
				hide_event()
				event_nav.emit("VENDOR")
				return
			"open_bench":
				hide_event()
				event_nav.emit("BENCH")
				return

	# Pre-scan for player_pick; if found, pause dispatch and show picker
	var needs_pick := false
	for effect: Dictionary in choice.effects:
		if effect.get("target", "") == "player_pick":
			needs_pick = true
			break

	var picked_target: CombatantData = null
	if needs_pick:
		_choices_container.visible = false
		_show_picker()
		picked_target = await target_picked
		_hide_picker()

	# Pre-scan for recruit_follower when bench is full; show compare panel
	var bench_release_idx := -1
	var pending_recruit: CombatantData = null
	for effect: Dictionary in choice.effects:
		if effect.get("type", "") == "recruit_follower" and GameState.bench.size() >= GameState.BENCH_CAP:
			# Build the follower now so the comparison shows the exact instance that will be added.
			var arch_id: String = effect.get("archetype_id", "grunt")
			var arch: ArchetypeData = ArchetypeLibrary.get_archetype(arch_id)
			var name_val: String = effect.get("name", "")
			if name_val.is_empty():
				var pool: Array[String] = KindredLibrary.get_name_pool(arch.kindred)
				name_val = pool[randi() % pool.size()] if not pool.is_empty() else "Recruit"
			pending_recruit = ArchetypeLibrary.create(arch_id, name_val, true)
			if not GameState.party.is_empty():
				pending_recruit.level = GameState.party[0].level
			pending_recruit.xp = 0
			pending_recruit.pending_level_ups = 0
			pending_recruit.current_hp     = pending_recruit.hp_max

			_choices_container.visible = false
			_show_bench_picker(pending_recruit)
			bench_release_idx = await bench_target_picked
			_hide_bench_picker()
			if bench_release_idx == -1:
				# Player changed their mind — restore the choice list
				pending_recruit = null
				_choices_container.visible = true
				return
			break

	for effect: Dictionary in choice.effects:
		dispatch_effect(effect, GameState.party, picked_target, bench_release_idx, pending_recruit)

	_result_label.text = choice.result_text
	_choices_container.visible = false
	_result_panel.visible = true

## --- Picker Overlay ---
## Dynamically built and freed; blocks choice buttons while waiting for player input.

func _show_picker() -> void:
	_picker_centering = CenterContainer.new()
	_picker_centering.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker_centering.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_picker_centering)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500.0, 200.0)
	var psbox := StyleBoxFlat.new()
	psbox.bg_color = Color(0.05, 0.06, 0.08, 0.97)
	psbox.border_width_left = 2; psbox.border_width_right  = 2
	psbox.border_width_top  = 2; psbox.border_width_bottom = 2
	psbox.border_color = Color(0.40, 0.55, 0.72)
	psbox.set_corner_radius_all(6)
	psbox.content_margin_left = 20.0; psbox.content_margin_right  = 20.0
	psbox.content_margin_top  = 16.0; psbox.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", psbox)
	_picker_centering.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var prompt := Label.new()
	prompt.text = "Choose a target:"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16)
	prompt.add_theme_color_override("font_color", Color(0.85, 0.90, 0.95))
	vbox.add_child(prompt)

	for member: CombatantData in GameState.party:
		if member.is_dead:
			continue
		var btn := Button.new()
		btn.text = "%s  —  HP %d / %d  [%s]" % [
			member.character_name, member.current_hp, member.hp_max, member.unit_class]
		btn.custom_minimum_size = Vector2(0.0, 38.0)
		btn.add_theme_font_size_override("font_size", 14)
		var m: CombatantData = member
		btn.pressed.connect(func() -> void: target_picked.emit(m))
		vbox.add_child(btn)

func _hide_picker() -> void:
	if _picker_centering != null and is_instance_valid(_picker_centering):
		_picker_centering.queue_free()
	_picker_centering = null

## --- Bench Release Picker ---
## Shown when a recruit_follower effect fires with a full bench.
## Emits bench_target_picked(index) on swap, bench_target_picked(-1) on cancel.

func _show_bench_picker(new_recruit: CombatantData) -> void:
	_bench_picker_centering = BenchSwapPanel.build_panel(
		new_recruit,
		"Never Mind",
		func(idx: int) -> void: bench_target_picked.emit(idx),
		func() -> void:         bench_target_picked.emit(-1)
	)
	add_child(_bench_picker_centering)

func _hide_bench_picker() -> void:
	if _bench_picker_centering != null and is_instance_valid(_bench_picker_centering):
		_bench_picker_centering.queue_free()
	_bench_picker_centering = null

func _on_continue_pressed() -> void:
	GameState.save()
	event_finished.emit()
	hide_event()

## --- Static: Condition Evaluator ---

static func evaluate_condition(condition: String, party: Array[CombatantData]) -> bool:
	# Zero-argument conditions
	if condition == "bench_not_full":
		return GameState.bench.size() < GameState.BENCH_CAP

	var parts := condition.split(":")
	if parts.size() < 2:
		push_warning("EventManager: unknown condition format '%s' — failing open" % condition)
		return true

	var form: String = parts[0]
	match form:
		"has_gold":
			return GameState.gold >= int(parts[1])
		"stat_ge":
			if parts.size() < 3:
				push_warning("EventManager: malformed stat_ge condition '%s' — failing open" % condition)
				return true
			var threshold := int(parts[2])
			for member: CombatantData in party:
				if _stat_value(member, parts[1]) >= threshold:
					return true
			return false
		"kindred":
			for member: CombatantData in party:
				if member.kindred == parts[1]:
					return true
			return false
		"class":
			for member: CombatantData in party:
				if member.unit_class == parts[1]:
					return true
			return false
		"background":
			for member: CombatantData in party:
				if member.background == parts[1]:
					return true
			return false
		"feat":
			for member: CombatantData in party:
				if member.feat_ids.has(parts[1]):
					return true
			return false
		"item":
			for entry: Dictionary in GameState.inventory:
				if entry.get("id", "") == parts[1]:
					return true
			return false
		_:
			push_warning("EventManager: unknown condition form '%s' — failing open" % form)
			return true

static func _stat_value(member: CombatantData, stat_key: String) -> int:
	match stat_key:
		"STR": return member.strength
		"DEX": return member.dexterity
		"COG": return member.cognition
		"WIL": return member.willpower
		"VIT": return member.vitality
		_:
			push_warning("EventManager: unknown stat key '%s'" % stat_key)
			return 0

## --- Static: Target Resolution ---

static func resolve_target(target: String, party: Array[CombatantData]) -> CombatantData:
	if party.is_empty():
		push_warning("EventManager: resolve_target called with empty party")
		return null

	match target:
		"PC":
			return party[0]
		"random_ally":
			var alive_allies: Array[CombatantData] = []
			for i in range(1, party.size()):
				if not party[i].is_dead:
					alive_allies.append(party[i])
			if alive_allies.is_empty():
				push_warning("EventManager: random_ally — no alive allies, degrading to PC")
				return party[0]
			return alive_allies[randi() % alive_allies.size()]
		"random_party":
			var alive: Array[CombatantData] = []
			for member: CombatantData in party:
				if not member.is_dead:
					alive.append(member)
			if alive.is_empty():
				return party[0]
			return alive[randi() % alive.size()]
		"player_pick":
			push_warning("EventManager: player_pick not yet implemented — defaulting to PC")
			return party[0]
		_:
			push_warning("EventManager: unknown target '%s' — defaulting to PC" % target)
			return party[0]

## --- Static: Effect Dispatch ---
## forced_target: when non-null and the effect target is "player_pick", use this member
##   instead of resolve_target. Keeps dispatch static + headless-testable.

static func dispatch_effect(effect: Dictionary, party: Array[CombatantData],
		forced_target: CombatantData = null, bench_release_idx: int = -1,
		prebuilt_follower: CombatantData = null) -> void:
	var effect_type: String = effect.get("type", "")
	match effect_type:
		"item_gain":
			var item_id: String = effect.get("item_id", "")
			var item_dict := _item_dict_for_id(item_id)
			if item_dict.is_empty():
				push_warning("EventManager: item_gain — unknown item_id '%s'" % item_id)
				return
			GameState.add_to_inventory(item_dict)
		"item_remove":
			GameState.remove_from_inventory(effect.get("item_id", ""))
		"harm":
			var t := _resolve_with_override(effect.get("target", "PC"), party, forced_target)
			if t == null:
				return
			t.current_hp = maxi(0, t.current_hp - int(effect.get("value", 0)))
		"heal":
			var t := _resolve_with_override(effect.get("target", "PC"), party, forced_target)
			if t == null:
				return
			t.current_hp = mini(t.hp_max, t.current_hp + int(effect.get("value", 0)))
		"xp_grant":
			print("[EventEffect] xp_grant %d — stub" % int(effect.get("value", 0)))
		"gold_change":
			GameState.gold = maxi(0, GameState.gold + int(effect.get("value", 0)))
		"threat_delta":
			GameState.threat_level = clampf(
				GameState.threat_level + float(int(effect.get("value", 0))) / 100.0,
				0.0, 1.0)
		"feat_grant":
			var t := _resolve_with_override(effect.get("target", "PC"), party, forced_target)
			if t == null:
				return
			var feat_id: String = effect.get("feat_id", "")
			if not feat_id.is_empty():
				GameState.grant_feat(party.find(t), feat_id)
		"recruit_follower":
			var follower: CombatantData
			if prebuilt_follower != null:
				# Reuse the instance shown in the comparison UI (stats are identical).
				follower = prebuilt_follower
			else:
				var arch_id: String = effect.get("archetype_id", "grunt")
				var arch: ArchetypeData = ArchetypeLibrary.get_archetype(arch_id)
				var name_val: String = effect.get("name", "")
				if name_val.is_empty():
					var pool: Array[String] = KindredLibrary.get_name_pool(arch.kindred)
					name_val = pool[randi() % pool.size()] if not pool.is_empty() else "Recruit"
				follower = ArchetypeLibrary.create(arch_id, name_val, true)
				if not GameState.party.is_empty():
					follower.level = GameState.party[0].level
				follower.xp = 0
				follower.pending_level_ups = 0
				follower.current_hp     = follower.hp_max
				follower.current_energy = follower.energy_max
			# Release a bench slot first if the player chose one via the compare panel
			if GameState.bench.size() >= GameState.BENCH_CAP and bench_release_idx >= 0:
				GameState.release_from_bench(bench_release_idx)
			if not GameState.add_to_bench(follower):
				push_warning("EventManager: recruit_follower — bench full, follower not added")
		"open_vendor", "open_bench":
			pass  # nav effects handled in _on_choice_pressed
		_:
			if not effect_type.is_empty():
				push_warning("EventManager: unknown effect type '%s'" % effect_type)

## Uses forced_target when the effect target is "player_pick" and a resolved member is available.
static func _resolve_with_override(target: String, party: Array[CombatantData],
		forced_target: CombatantData) -> CombatantData:
	if target == "player_pick" and forced_target != null:
		return forced_target
	return resolve_target(target, party)

## Looks up item in EquipmentLibrary first, then ConsumableLibrary.
## Returns empty dict if not found in either.
static func _item_dict_for_id(item_id: String) -> Dictionary:
	var eq: EquipmentData = EquipmentLibrary.get_equipment(item_id)
	if eq.equipment_name != "Unknown":
		return {"id": item_id, "name": eq.equipment_name, "description": eq.description, "item_type": "equipment"}
	var con: ConsumableData = ConsumableLibrary.get_consumable(item_id)
	# ConsumableLibrary stub sets consumable_id to "unknown" (not the queried id)
	if con.consumable_id == item_id:
		return {"id": item_id, "name": con.consumable_name, "description": con.description, "item_type": "consumable"}
	return {}
