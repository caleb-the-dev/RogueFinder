# System: Feat System

> Last updated: 2026-04-24 (Slice 2 — FeatLibrary data foundation + display migration)

---

## Status

**Data layer complete.** `FeatLibrary` + `FeatData` + `feats.csv` are live. All display surfaces (StatPanel, CharacterCreationManager, PartySheet) resolve feat name/description through `FeatLibrary`. No mechanical feat effects yet — all four seeded feats are placeholders.

---

## Purpose

Central registry for passive character feats. Each kindred grants one feat at character creation via `CombatantData.kindred_feat_id`. Future event effects (`feat_grant` — Slice 4) will append additional feat ids to `CombatantData.feats`.

---

## Core Files

| File | Role |
|------|------|
| `resources/FeatData.gd` | Resource: one feat (`id`, `name`, `description`) |
| `scripts/globals/FeatLibrary.gd` | CSV-native loader; `get_feat()` / `all_feats()` / `reload()` |
| `data/feats.csv` | Data source: 4 kindred feats |

---

## FeatData Fields

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `id` | `String` | `""` | Snake-case key (e.g. `"adaptive"`) |
| `name` | `String` | `""` | Display name (e.g. `"Adaptive"`) |
| `description` | `String` | `""` | One-sentence flavour + mechanic hint |

No effect fields at this slice — mechanical wiring is Slice 4+.

---

## FeatLibrary Public API

| Method | Signature | Notes |
|--------|-----------|-------|
| `get_feat` | `(id: String) -> FeatData` | Never null; unknown id returns stub with `name = "Unknown Feat"`, `description = ""` |
| `all_feats` | `() -> Array[FeatData]` | All loaded feats (unordered) |
| `reload` | `() -> void` | Clear + re-parse; dev/test helper |

### Internal

- `_cache: Dictionary` — static, keyed by `id`; lazy-populated on first call.
- `_ensure_loaded()` — guards against double-load.
- `_row_to_data()` — maps CSV columns to `FeatData` fields; skips rows with no `id`.

---

## Seeded Feats (feats.csv)

| id | name | description |
|----|------|-------------|
| `adaptive` | Adaptive | Versatile survivors; no path is closed to them. |
| `relentless` | Relentless | Fight harder when cornered — low-HP damage bonus (placeholder). |
| `tinkerer` | Tinkerer | Find clever shortcuts — reduced ability costs (placeholder). |
| `stonehide` | Stonehide | Endure what others cannot — passive armor bonus (placeholder). |

Kindred → feat mapping lives in `kindreds.csv` (`feat_id` column), read by `KindredLibrary`.

---

## Display Surfaces

| Surface | How feat is shown |
|---------|-------------------|
| **StatPanel** | `── Feats ──` section in the scrollable RTL, after `── Abilities ──`. Numbered list: `1. <FeatName>`. Resolved via `FeatLibrary.get_feat(d.kindred_feat_id)`. |
| **CharacterCreationManager** | Preview panel: "Kindred Feat — \<name\>" label + description label below it (autowrap, 75% opacity). Resolved via `FeatLibrary.get_feat(KindredLibrary.get_feat_id(kindred_id))`. |
| **PartySheet Feats tab** | Per-member tab inside the RIGHT TabContainer. Mirrors Abilities tab: 1×/2× toggle, Name sort (asc/desc), search bar, scrollable `PanelContainer` cards. Hover card for tooltip. Source: `member.kindred_feat_id` only (Slice 4 will add `member.feats` array). |

---

## Dependencies

| System | Role |
|--------|------|
| `KindredLibrary` | Provides `feat_id` per kindred; `FeatLibrary` is the canonical name/desc store |
| `CombatantData` | `kindred_feat_id: String` is the per-unit feat reference |

`FeatLibrary` has no outbound dependencies (no scene, no autoload, no signals).

---

## Gotchas

- **Single-CSV pattern** — feats follow the standard single-CSV library convention (unlike `EventLibrary` which uses two CSVs). Add new feats by adding rows to `feats.csv`.
- **`get_feat()` never returns null** — always returns a stub on unknown id. Callers do not need null checks.
- **No mechanical effects** — `FeatData` intentionally has no effect JSON fields at this slice. Add them in Slice 4 when `feat_grant` lands.
- **Slice 4 extension point** — `CombatantData.feats: Array[String]` (not yet added) will hold additional feat ids granted by events. PartySheet's feats tab already sources from `[member.kindred_feat_id]` as a single-element list — extend to `member.feats + [member.kindred_feat_id]` (deduped) when that field lands.

---

## Tests

`tests/test_feat_library.gd` / `test_feat_library.tscn` — 8 headless tests:
- CSV loads and parses all 4 rows
- `get_feat("adaptive").name == "Adaptive"` and description matches
- `get_feat("stonehide").description` is non-empty
- Unknown id returns non-null stub with `name == "Unknown Feat"`
- `reload()` re-populates (`all_feats().size() == 4` after reload)

Run via:
```
godot --headless --path rogue-finder res://tests/test_feat_library.tscn
```

---

## Recent Changes

| Date | Change |
|------|--------|
| 2026-04-24 | **Slice 2 — FeatLibrary data foundation.** `FeatData.gd`, `FeatLibrary.gd`, `feats.csv` (4 kindred feats). Migrated all feat display surfaces from `KindredLibrary.get_feat_name()` / `get_feat_desc()` wrappers to `FeatLibrary.get_feat(id)`. StatPanel: Feats inline RTL section below Abilities. CharacterCreationManager: feat name + description in preview panel. PartySheet: Feats tab upgraded from placeholder to full search/sort/1×2× card list. 8 new headless tests (63 total across all suites). |
