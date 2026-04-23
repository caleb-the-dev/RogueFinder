# System: Combatant Data Model

> Last updated: 2026-04-23 (S28 kindred + split during map audit — abilities, equipment, and backgrounds moved to their own files)

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
| `scripts/globals/ArchetypeLibrary.gd` | Static factory: archetype definitions + `create()` method. |

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
| `character_name` | `String` | Display name; player-editable. |
| `archetype_id` | `String` | Key into `ArchetypeLibrary.ARCHETYPES`. |
| `is_player_unit` | `bool` | Team assignment; drives AI vs. player control. |
| `kindred` | `String` | Species/ancestry (e.g. `"Human"`, `"Dwarf"`, `"Gnome"`, `"Half-Orc"`). Fixed per archetype; set in `create()` from `def["kindred"]` via `.get("kindred", "Unknown")`. Persisted to save. Old saves without this key default to `"Unknown"`. Flavor-only now; mechanical hooks deferred to Stage 2. |

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
| `dexterity` | `speed` (2 + DEX) |
| `cognition` | Reserved for ability cost scaling (TBD) |
| `willpower` | `energy_regen` (2 + WIL) |
| `vitality` | `hp_max` (10 × VIT) and `energy_max` (5 + VIT) |

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
| `hp_max` | `10 * vitality + equip("vitality")` |
| `energy_max` | `5 + vitality + equip("vitality")` |
| `energy_regen` | `2 + willpower + equip("willpower")` |
| `speed` | `2 + dexterity + equip("dexterity")` |
| `attack` | `5 + strength + equip("strength")` |
| `defense` | `armor_defense + equip("armor_defense")` |

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

### Schema keys

- `kindred: String` — species/ancestry (fixed per archetype).
- `abilities: Array[String]` — 4 active slot ids.
- `pool_extras: Array[String]` — additional ids appended to `ability_pool` beyond the 4 slots. Defined on: RogueFinder (+4), archer_bandit (+4), grunt (+4). Absent on alchemist + elite_guard (defaults to empty).
- Attribute ranges as `[lo, hi]` tuples; `create()` samples via `randi_range()`.

### Public API

```gdscript
static func create(archetype_id: String, character_name: String = "",
    is_player: bool = false) -> CombatantData
```

---

## Dependencies

| Dependent | On |
|-----------|----|
| `CombatantData` | `EquipmentData` (equipment slots) |
| `ArchetypeLibrary` | `CombatantData` |
| `Unit3D` | `CombatantData` (via `@export var data`) |
| `StatPanel` | `CombatantData`, `Unit3D` |
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
| 2026-04-23 | S28 — Added `kindred: String` to `CombatantData` (Identity section). Each archetype definition includes a `"kindred"` key; `create()` sets `data.kindred = def.get("kindred", "Unknown")`. Assignments: RogueFinder→Human, archer_bandit→Human, grunt→Half-Orc, alchemist→Gnome, elite_guard→Dwarf. Persisted in `GameState._serialize_combatant()` / `_deserialize_combatant()` (old saves default `"Unknown"`). Displayed in StatPanel, CombatActionPanel, and PartySheet. |
| 2026-04-20 | S23 — `ArchetypeLibrary.pool_extras` key added; `create()` appends extras to `ability_pool` (deduped). RogueFinder / archer_bandit / grunt each get +4 extras. Pool ⊇ Slots invariant still holds. |
| 2026-04-19 | Slice 3 — `is_dead` now set by `CombatManager3D._on_unit_died()` (permadeath). `current_hp`/`current_energy` written back on combat victory. `Unit3D.setup()` seeds from persistent fields. |
| 2026-04-19 | Slice 2 — Persistent run state now saved/loaded via `GameState._serialize_combatant()` / `_deserialize_combatant()`. `GameState.party: Array[CombatantData]`; `init_party()` seeds on fresh runs. Equipment slots persist as id strings. |
| 2026-04-18 | Slice 1 — Added `ability_pool`, `current_hp`, `current_energy`, `is_dead` fields. `create()` seeds pool from archetype abilities + pool_extras. |
| 2026-04-16 | Equipment slots changed from String to `EquipmentData` (nullable); derived stats include equipment bonuses via `_equip_bonus()`. |
