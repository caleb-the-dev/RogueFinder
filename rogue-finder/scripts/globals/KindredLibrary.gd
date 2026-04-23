class_name KindredLibrary
extends RefCounted

## --- KindredLibrary ---
## Single source of truth for per-kindred mechanical data.
## Speed bonus replaces DEX in the speed formula; hp_bonus adds a flat offset to hp_max.
## Feats are placeholder (named but have no mechanical effect yet).
## Unknown kindreds return safe defaults (0 for numerics, "" for strings) — never crash.

const KINDREDS: Dictionary = {
	"Human": {
		"speed_bonus": 3,
		"hp_bonus":    5,
		"feat_id":     "adaptive",
		"feat_name":   "Adaptive",
		"feat_desc":   "Versatile survivors; no path is closed to them.",
	},
	"Half-Orc": {
		"speed_bonus": 2,
		"hp_bonus":    12,
		"feat_id":     "relentless",
		"feat_name":   "Relentless",
		"feat_desc":   "Fight harder when cornered — low-HP damage bonus (placeholder).",
	},
	"Gnome": {
		"speed_bonus": 4,
		"hp_bonus":    2,
		"feat_id":     "tinkerer",
		"feat_name":   "Tinkerer",
		"feat_desc":   "Find clever shortcuts — reduced ability costs (placeholder).",
	},
	"Dwarf": {
		"speed_bonus": 1,
		"hp_bonus":    8,
		"feat_id":     "stonehide",
		"feat_name":   "Stonehide",
		"feat_desc":   "Endure what others cannot — passive armor bonus (placeholder).",
	},
}

static func get_speed_bonus(kindred: String) -> int:
	return (KINDREDS.get(kindred, {}) as Dictionary).get("speed_bonus", 0)

static func get_hp_bonus(kindred: String) -> int:
	return (KINDREDS.get(kindred, {}) as Dictionary).get("hp_bonus", 0)

static func get_feat_id(kindred: String) -> String:
	return (KINDREDS.get(kindred, {}) as Dictionary).get("feat_id", "")

static func get_feat_name(kindred: String) -> String:
	return (KINDREDS.get(kindred, {}) as Dictionary).get("feat_name", "")

static func get_feat_desc(kindred: String) -> String:
	return (KINDREDS.get(kindred, {}) as Dictionary).get("feat_desc", "")
