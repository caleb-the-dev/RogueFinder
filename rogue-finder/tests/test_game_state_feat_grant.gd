extends Node

## --- Unit Tests: GameState.grant_feat() ---
## Headless — no scene required. Manipulates GameState.party directly.

func _ready() -> void:
	print("=== test_game_state_feat_grant.gd ===")
	test_grant_feat_appends_id()
	test_grant_feat_no_duplicate()
	test_grant_feat_invalid_index_no_crash()
	test_grant_feat_saves()
	GameState.reset()
	print("=== All GameState.grant_feat tests passed ===")

func _make_member() -> CombatantData:
	var m := CombatantData.new()
	m.character_name = "Test"
	m.kindred = "Human"
	m.feat_ids = []
	m.vitality = 2
	m.current_hp = m.hp_max
	return m

func test_grant_feat_appends_id() -> void:
	var member := _make_member()
	GameState.party = [member]
	GameState.grant_feat(0, "adaptive")
	assert(member.feat_ids.has("adaptive"),
		"grant_feat should append 'adaptive' to feat_ids")
	assert(member.feat_ids.size() == 1,
		"feat_ids should have 1 entry, got %d" % member.feat_ids.size())
	GameState.reset()
	print("  PASS test_grant_feat_appends_id")

func test_grant_feat_no_duplicate() -> void:
	var member := _make_member()
	GameState.party = [member]
	GameState.grant_feat(0, "relentless")
	GameState.grant_feat(0, "relentless")
	assert(member.feat_ids.size() == 1,
		"duplicate grant must not add a second entry, got %d" % member.feat_ids.size())
	GameState.reset()
	print("  PASS test_grant_feat_no_duplicate")

func test_grant_feat_invalid_index_no_crash() -> void:
	GameState.party = []
	# Negative index — must push_error but not crash
	GameState.grant_feat(-1, "adaptive")
	# Index beyond party size
	GameState.grant_feat(5, "adaptive")
	GameState.reset()
	print("  PASS test_grant_feat_invalid_index_no_crash")

func test_grant_feat_saves() -> void:
	var member := _make_member()
	GameState.party = [member]
	GameState.map_seed = 1
	GameState.grant_feat(0, "stonehide")
	# Reload from disk and verify the feat survived
	GameState.reset()
	var loaded := GameState.load_save()
	assert(loaded, "load_save should succeed after grant_feat save")
	assert(GameState.party.size() == 1, "party should have 1 member")
	assert(GameState.party[0].feat_ids.has("stonehide"),
		"'stonehide' should survive save triggered by grant_feat")
	GameState.reset()
	print("  PASS test_grant_feat_saves")
