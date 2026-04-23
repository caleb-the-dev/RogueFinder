# System: Portrait Library

> Last updated: 2026-04-23 (S30 — new, CSV-native from the start)

---

## Purpose

A **Portrait** is a selectable visual identity for a character at creation. All v1 entries use `res://icon.svg` (the Godot placeholder) — real pixel art drops in by replacing `artwork_path` in the CSV, no code changes required.

Currently **dormant** — no production code calls `PortraitLibrary` yet. The infrastructure is ready for the character-creation screen when that lands.

`tags` hint at kindred affinity (e.g. `"human"`, `"dwarf"`) for optional downstream UI filtering. The library itself never filters on tags.

---

## Core Files

| File | Role |
|------|------|
| `resources/PortraitData.gd` | Resource — one portrait |
| `scripts/globals/PortraitLibrary.gd` | Static catalog — lazy CSV load, cached by id |
| `rogue-finder/data/portraits.csv` | Source of truth — edit here; Godot reads via `res://data/` |

---

## PortraitData

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `portrait_id` | `String` | Snake_case key (e.g. `"portrait_human_m"`) |
| `portrait_name` | `String` | Display label |
| `artwork_path` | `String` | `res://` path to the texture. All v1 entries: `res://icon.svg` |
| `tags` | `Array[String]` | Kindred affinity hints for UI filtering |

### Helpers

```gdscript
func has_tag(tag: String) -> bool
```

---

## PortraitLibrary

### Data Flow

```
rogue-finder/data/portraits.csv  (source of truth — edit here; Godot reads via res://data/)
        │
        ▼  FileAccess.get_csv_line(",")
PortraitLibrary._cache           (lazy-loaded Dictionary keyed by id)
```

### Public API

```gdscript
## Returns a populated PortraitData. Never returns null — stub falls back to res://icon.svg.
static func get_portrait(id: String) -> PortraitData
## Returns every loaded portrait. For character-creation UI.
static func all_portraits() -> Array[PortraitData]
## Clears the cache and re-reads the CSV.
static func reload() -> void
```

### Defined Portraits (6 seed rows)

| ID | Name | Artwork | Tags |
|----|------|---------|------|
| `portrait_human_m` | Human (M) | `res://icon.svg` | `human`, `male` |
| `portrait_human_f` | Human (F) | `res://icon.svg` | `human`, `female` |
| `portrait_half_orc` | Half-Orc | `res://icon.svg` | `half-orc` |
| `portrait_gnome` | Gnome | `res://icon.svg` | `gnome` |
| `portrait_dwarf` | Dwarf | `res://icon.svg` | `dwarf` |
| `portrait_unknown` | Unknown | `res://icon.svg` | *(none)* |

---

## Dependencies

| Dependent | On |
|-----------|----|
| `PortraitData` | Nothing (leaf node) |
| `PortraitLibrary` | `PortraitData`, `FileAccess` |
| *(none yet — dormant)* | |

---

## Key Patterns & Gotchas

- **Swapping art** — just update `artwork_path` in the CSV. No script changes needed.
- **Stub fallback** — unknown ids return a stub with `artwork_path = "res://icon.svg"`, never null.
- **Tags are passive** — the library stores them but never filters on them. Consumers decide whether to filter.
