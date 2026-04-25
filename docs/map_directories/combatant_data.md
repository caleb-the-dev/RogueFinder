# System: Combatant Data Model

> Last updated: 2026-04-23 (S34 — ArchetypeLibrary migrated from inline const dict to archetypes.csv + CSV-native loader; ArchetypeData resource added)

---

## Purpose

`CombatantData` is the authoritative data record for every combatant (player or NPC). It replaces the simpler `UnitData` resource with a full identity + archetype + attribute model.

`ArchetypeLibrary` is the factory that creates randomized `CombatantData` instances according to per-archetype range constraints.

### Related systems (split out)

- **Abilities** — `AbilityData`, `EffectData`, `AbilityLibrary`: see `ability_system.md`.
- **Equipment & Consumables** — `EquipmentData`, `EquipmentLibrary`, `ConsumableData`, `ConsumableLibrary`: see `equipment_system.md`.
- **Backgrounds** — `BackgroundData`, `BackgroundLibrary`: see `background_system.md`.

---

## Core Files

| File | Role |
|------|------|
| `resources/CombatantData.gd` | Resource: identity, attributes, equipment, ability pool. Derived stats are computed properties. |
| `resources/ArchetypeData.gd` | Resource: one archetype's fixed data and stat ranges. Populated by ArchetypeLibrary from archetypes.csv. |
| `scripts/globals/ArchetypeLibrary.gd` | CSV-native factory: loads `archetypes.csv`, exposes `create()` / `get_archetype()` / `all_archetypes()` / `reload()`. |
| `scripts/globals/KindredLibrary.gd` | Static class: per-kindred mechanical data (speed bonus, HP bonus, feat id/name/desc, flavor name pool). CSV-sourced (`res://data/kindreds.csv`). Single source of truth — referenced by `CombatantData` computed properties and by `ArchetypeLibrary.create()` for auto-naming. |
| `data/archetypes.csv` | Data source: 5 archetype rows. Single source of truth for all archetype stat ranges, ability pools, and backgrounds. |

---

## Design Principles

**Identity vs. Blueprint:**
- `character_name` — the name this specific combatant goes by (e.g., "Vael").
- `archetype_id` — the species/template (e.g., "archer_bandit"). Fixes class, artwork, and the pools from which background and attributes are drawn.

Like a Pokémon: the archetype is Pikachu, the character_name is whatever the trainer called it.

**Fixed per archetype:** `kindred`, `unit_class`, `artwork_idle`, `artwork_attack`, `abilities`, `ability_pool` (starting set).

**Randomized per instance (within archetype ranges):** `background`, all five core attributes, `armor_defense`, `qte_resolution`.

---

## CombatantData Fields

### Identity
| Field | Type | Notes |
|-------|------|-------|
| `character_name` | `String` | Display name; player-editable. When `is_player=true` and no explicit name is supplied to `ArchetypeLibrary.create()`, auto-drawn from the character's kindred name pool via `KindredLibrary.get_name_pool()`. Falls back to `"Unit"` if the kindred's pool is empty. |
| `archetype_id` | `String` | Key into `ArchetypeLibrary` (via `get_archetype()` → `archetypes.csv`). |
| `is_player_unit` | `bool` | Team assignment; drives AI vs. player control. |
| `kindred` | `String` | Species/ancestry (e.g. `"Human"`, `"Dwarf"`, `"Gnome"`, `"Half-Orc"`). Fixed per archetype; set in `create()` from `def["kindred"]` via `.get("kindred", "Unknown")`. Persisted to save. Old saves default to `"Unknown"`. **Mechanically active:** drives `speed` and `hp_max` via `KindredLibrary`. |
| `kindred_feat_id` | `String` | ID of the kindred's passive feat (e.g. `"adaptive"`, `"relentless"`). Set in `create()` via `KindredLibrary.get_feat_id(kindred)`. Persisted to save; old saves default to `""`. Placeholder — no mechanical effect yet. Displayed as feat name in StatPanel. |

### Background & Class
| Field | Type | Notes |
|-------|------|-------|
| `background` | `String` | Background handle. Resolves to `BackgroundData` via `BackgroundLibrary.get_background()` / `get_background_by_name()`. Currently PascalCase display strings; snake_case-id migration deferred. See `background_system.md`. |
| `unit_class` | `String` | e.g. "Rogue", "Barbarian", "Wizard". Fixed per archetype. |

### Portrait & Artwork
| Field | Type | Notes |
|-------|------|-------|
| `portrait` | `Texture2D` | Face portrait. `null` → falls back to Godot icon. |
| `artwork_idle` | `String` | `res://` path placeholder. |
| `artwork_attack` | `String` | `res://` path placeholder. |

### Core Attributes (range 0–5)
| Field | Drives |
|-------|--------|
| `strength` | `attack` (5 + STR) |
| `dexterity` | Reserved — no longer drives `speed`. Future: dodge/evasion. Equipment `dexterity` bonuses still add to speed as a passthrough until a dedicated speed slot exists. |
| `cognition` | Reserved for ability cost scaling (TBD) |
| `willpower` | `energy_regen` (2 + WIL) |
| `vitality` | `hp_max` (10 + kindred_bonus + VIT×6) and `energy_max` (5 + VIT) |

### Equipment Slots
`weapon`, `armor`, `accessory` — typed `EquipmentData` (nullable; `null` = unequipped). Bonuses applied via `_equip_bonus()`. See `equipment_system.md`.
`consumable` — consumable ID into `ConsumableLibrary` (e.g. `"healing_potion"`). Set to `""` when used in combat.

### Ability Slots
`abilities: Array[String]` — exactly 4 active slots. Stores ability IDs (e.g. `"strike"`). Empty string = unfilled slot. Looked up via `AbilityLibrary.get_ability()` at runtime.

### Persistent Run State
These fields survive between combats. Seeded at creation by `ArchetypeLibrary.create()`. Persisted to disk via `GameState.save()` / `load_save()` — serialized by `GameState._serialize_combatant()` / `_deserialize_combatant()`.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `ability_pool` | `Array[String]` | archetype's active abilities + `pool_extras` | Full unlocked set — superset of `abilities`. Seeded in `create()` from `abilities` then `pool_extras` (deduped). Future leveling appends here without touching the 4-slot active list. |
| `feats` | `Array[String]` | `[]` | Feats granted during the run via events (e.g. `"adaptive"`). Appended to by `EventManager.dispatch_effect` on `feat_grant` effects. No duplicates enforced by dispatcher. No mechanical effect yet — Slice 5+. Serialized with typed-array pattern; old saves without the key load as `[]`. |
| `current_hp` | `int` | `hp_max` | Live HP between combats. |
| `current_energy` | `int` | `energy_max` | Live energy between combats. |
| `is_dead` | `bool` | `false` | Permanent death flag. Set by `CombatManager3D._on_unit_died()` when a player unit's HP reaches 0; `GameState.save()` is called immediately. |

**Pool ⊇ Slots invariant:** every non-empty entry in `abilities` must also appear in `ability_pool`. True by construction in `create()` since both are seeded from the same archetype source.

### Enemy-Only
`qte_resolution: float` — auto-resolve accuracy for enemy QTE simulation (0.0–1.0). See `qte_system.md` Enemy Simulation table.

---

## Derived Stats (computed properties on CombatantData)

All derived stats include equipment bonuses via `_equip_bonus(stat_name)`, which sums the matching key from all three slots (weapon + armor + accessory).

| Property | Formula |
|----------|---------|
| `hp_max` | `10 + KindredLibrary.get_hp_bonus(kindred) + (vitality × 6) + equip("vitality")` |
| `energy_max` | `5 + vitality + equip("vitality")` |
| `energy_regen` | `2 + willpower + equip("willpower")` |
| `speed` | `1 + KindredLibrary.get_speed_bonus(kindred) + equip("dexterity")` |
| `attack` | `5 + strength + equip("strength")` |
| `defense` | `armor_defense + equip("armor_defense")` |

**Kindred bonus values (from KindredLibrary):**

| Kindred | speed_bonus → speed | hp_bonus | HP range (no equip) |
|---------|---------------------|----------|---------------------|
| Human | 3 → 4 | +5 | 21–35 (VIT 1–3, archer) / 27–45 (VIT 2–5, PC) |
| Half-Orc | 2 → 3 | +12 | 34–46 (VIT 2–4) |
| Gnome | 4 → 5 | +2 | 18–26 (VIT 1–2) |
| Dwarf | 1 → 2 | +8 | 36–48 (VIT 3–5) |
| Unknown / empty | 0 → 1 | 0 | safe default, no crash |

---

## ArchetypeLibrary

### Defined Archetypes (5)

| ID | Class | Kindred | STR | DEX | COG | WIL | VIT | Armor | Abilities | Consumable |
|----|-------|---------|-----|-----|-----|-----|-----|-------|-----------|------------|
| `RogueFinder` | Custom | Human | 1–4 | 1–4 | 1–4 | 1–4 | 2–5 | 4–8 | strike, guard, fireball, sweep | `power_tonic` |
| `archer_bandit` | Rogue | Human | 1–2 | 3–4 | 1–2 | 0–2 | 1–3 | 3–5 | quick_shot, gust, acid_splash, piercing_shot | — |
| `grunt` | Barbarian | Half-Orc | 2–4 | 1–2 | 0–1 | 0–2 | 2–4 | 4–7 | heavy_strike, shove, sweep, taunt | — |
| `alchemist` | Wizard | Gnome | 0–1 | 1–3 | 3–5 | 2–4 | 1–2 | 2–4 | smoke_bomb, fire_breath, acid_splash, healing_draught | `healing_potion` |
| `elite_guard` | Warrior | Dwarf | 3–5 | 1–3 | 1–2 | 2–4 | 3–5 | 7–10 | shield_bash, yank, windblast, sweep | — |

### Schema (archetypes.csv columns)

- `id` — archetype key (e.g. `grunt`).
- `class` → `unit_class: String` — fixed class label.
- `kindred: String` — species/ancestry (fixed per archetype).
- `backgrounds: Array[String]` — pipe-separated pool; one chosen at random in `create()`.
- `abilities: Array[String]` — pipe-separated; 4 active slot ids.
- `pool_extras: Array[String]` — pipe-separated; additional ids appended to `ability_pool` beyond the 4 slots. RogueFinder/archer_bandit/grunt have +4; alchemist/elite_guard empty.
- Attribute ranges stored as `min|max` pipe pairs; `create()` samples via `randi_range()`.
- `qte_range` stored as float `min|max`.

### Public API

```gdscript
static func create(archetype_id: String, character_name: String = "",
    is_player: bool = false) -> CombatantData
static func get_archetype(id: String) -> ArchetypeData   # stub fallback on unknown
static func all_archetypes() -> Array[ArchetypeData]     # replaces ARCHETYPES iteration
static func reload() -> void                             # cache-clear for tests/dev
```

---

## Dependencies

| Dependent | On |
|-----------|----|
| `CombatantData` | `EquipmentData` (equipment slots), `KindredLibrary` (speed + HP computed props) |
| `ArchetypeLibrary` | `CombatantData`, `KindredLibrary` (sets `kindred_feat_id` + auto-name via `get_name_pool()` in `create()`) |
| `Unit3D` | `CombatantData` (via `@export var data`) |
| `StatPanel` | `CombatantData`, `Unit3D`, `FeatLibrary` (feat name lookup via `kindred_feat_id`) |
| `CombatActionPanel` | `CombatantData` (via `Unit3D.data`) |
| `CombatManager3D` | `ArchetypeLibrary`, `CombatantData` |
| `GameState` | `CombatantData` (party roster; serialize / deserialize) |

---

## Where NOT to Look

- **Effect math is NOT here** — see `combat_manager.md` (`_apply_effects`, `_apply_force`).
- **Stat mutation at runtime is NOT here** — `_apply_stat_delta()` in CM3D modifies mid-combat.
- **Unit visuals are NOT here** — HP bar, lunge, buff/debuff indicators are in `Unit3D.gd` / `unit_system.md`.

---

## Key Patterns & Gotchas

- **Stats clamp to [0, 5] mid-combat** — `_apply_stat_delta()` enforces this.
- **Stat changes are rolled back at combat end** — `CombatManager3D._attr_snapshots` records each player unit's attribute baseline at setup and restores it in `_end_combat()` on both win and defeat.
- **`cognition` has no derived stat yet** — reserved for ability cost scaling.
- **`abilities` array is exactly 4 slots** — `CombatActionPanel` greys out empty slots.
- **Shared resource references** — `CombatManager3D._setup_units()` passes the same `CombatantData` instance that lives in `GameState.party`, not a copy. Stat mutations hit the live party member, which is why snapshot/restore is mandatory.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-23 | Name-pool migration — `_NAME_POOLS` const dict removed from `ArchetypeLibrary.gd`. Flavor names now live on `KindredData.name_pool` (new `Array[String]` field) sourced from the new `name_pool` column in `kindreds.csv`. `ArchetypeLibrary.create()` pulls from `KindredLibrary.get_name_pool(data.kindred)` when auto-naming player allies; empty pool → fallback `"Unit"`. Closes the last inline-const-dict exception in the data-library uniformity pass. Names themselves unchanged per-kindred (Human pool = old archer_bandit names; Half-Orc = grunt; Gnome = alchemist; Dwarf = elite_guard). Added `test_kindred_name_pool_loaded` + `test_kindred_name_pool_unknown_safe` to `test_combatant_data.gd`. |
| 2026-04-23 | S34 — ArchetypeLibrary migrated from inline `const ARCHETYPES` dict to `archetypes.csv` + CSV-native loader. `ArchetypeData.gd` resource added with all fields as typed `@export` vars. `ARCHETYPES` dict removed; `all_archetypes()` / `get_archetype()` / `reload()` added to public API. `create()` signature unchanged — unknown ids still fall back to grunt definition. `test_combatant_data.gd` (4 tests) and `test_consumables.gd` (1 test) updated from `ARCHETYPES.keys()` to `all_archetypes()`. |
| 2026-04-23 | S29 — Kindred mechanics live. `hp_max` formula changed to `10 + kindred_hp_bonus + VIT×6 + equip`; `speed` formula changed to `1 + kindred_speed_bonus + equip("dexterity")`. DEX removed from speed (reserved for future dodge/evasion). Added `kindred_feat_id: String` field; set in `create()` via `KindredLibrary.get_feat_id()`, persisted to save (old saves default `""`). New `KindredLibrary.gd` holds all per-kindred data. StatPanel feat row added. `test_combatant_data.gd` updated + 4 new kindred tests. |
| 2026-04-25 | Slice 4 — Added `feats: Array[String]` to Persistent Run State. Serialized/deserialized in `GameState._serialize_combatant()` / `_deserialize_combatant()` using typed-array conversion. Old saves without the key load as `[]`. Populated by `EventManager.dispatch_effect` on `feat_grant` effects. No mechanical effect yet. |
| 2026-04-23 | S28 — Added `kindred: String` to `CombatantData` (Identity section). Each archetype definition includes a `"kindred"` key; `create()` sets `data.kindred = def.get("kindred", "Unknown")`. Assignments: RogueFinder→Human, archer_bandit→Human, grunt→Half-Orc, alchemist→Gnome, elite_guard→Dwarf. Persisted in `GameState._serialize_combatant()` / `_deserialize_combatant()` (old saves default `"Unknown"`). Displayed in StatPanel, CombatActionPanel, and PartySheet. |
| 2026-04-20 | S23 — `ArchetypeLibrary.pool_extras` key added; `create()` appends extras to `ability_pool` (deduped). RogueFinder / archer_bandit / grunt each get +4 extras. Pool ⊇ Slots invariant still holds. |
| 2026-04-19 | Slice 3 — `is_dead` now set by `CombatManager3D._on_unit_died()` (permadeath). `current_hp`/`current_energy` written back on combat victory. `Unit3D.setup()` seeds from persistent fields. |
| 2026-04-19 | Slice 2 — Persistent run state now saved/loaded via `GameState._serialize_combatant()` / `_deserialize_combatant()`. `GameState.party: Array[CombatantData]`; `init_party()` seeds on fresh runs. Equipment slots persist as id strings. |
| 2026-04-18 | Slice 1 — Added `ability_pool`, `current_hp`, `current_energy`, `is_dead` fields. `create()` seeds pool from archetype abilities + pool_extras. |
| 2026-04-16 | Equipment slots changed from String to `EquipmentData` (nullable); derived stats include equipment bonuses via `_equip_bonus()`. |
