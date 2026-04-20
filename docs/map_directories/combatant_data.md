# System: Combatant Data Model

> Last updated: 2026-04-20 (S23 — pool_extras key added to ArchetypeLibrary; ability_pool default note corrected)

---

## Purpose

`CombatantData` is the authoritative data record for every combatant (player or NPC). It replaces the simpler `UnitData` resource with a full identity + archetype + attribute model.

`ArchetypeLibrary` is the factory that creates randomized `CombatantData` instances according to per-archetype range constraints.

---

## Core Files

| File | Role |
|------|------|
| `resources/CombatantData.gd` | Resource: identity, attributes, equipment, ability pool. Derived stats are computed properties. |
| `resources/EquipmentData.gd` | Resource: one equipment item — id, name, slot enum, stat_bonuses dict, description. |
| `resources/ConsumableData.gd` | Resource: one consumable item — id, name, effect_type, base_value, target_stat, description. |
| `scripts/globals/ArchetypeLibrary.gd` | Static factory: archetype definitions + `create()` method. |
| `scripts/globals/EquipmentLibrary.gd` | Static catalog: 6 placeholder items + `get_equipment()` / `all_equipment()` methods. |
| `scripts/globals/ConsumableLibrary.gd` | Static factory: consumable definitions + `get_consumable()` method. |
| `resources/BackgroundData.gd` | Resource: one background — id, name, starting ability id, feat pool, unlock flag, tags, description. |
| `scripts/globals/BackgroundLibrary.gd` | Static catalog: CSV-backed (`res://data/backgrounds.csv`) + `get_background()` / `all_backgrounds()` / `reload()` methods. First CSV-sourced library in the codebase. |

---

## Design Principles

**Identity vs. Blueprint:**
- `character_name` — the name this specific combatant goes by (e.g., "Vael")
- `archetype_id` — the species/template (e.g., "archer_bandit"). Fixes class, artwork, and the pools from which background and attributes are drawn.

Like a Pokémon: the archetype is Pikachu, the character_name is whatever the trainer called it.

**Fixed per archetype:** `unit_class`, `artwork_idle`, `artwork_attack`, `abilities`, `ability_pool` (starting set).

**Randomized per instance (within archetype ranges):** `background`, all five core attributes, `armor_defense`, `qte_resolution`.

---

## CombatantData Fields

### Identity
| Field | Type | Notes |
|-------|------|-------|
| `character_name` | `String` | Display name; player-editable. |
| `archetype_id` | `String` | Key into `ArchetypeLibrary.ARCHETYPES`. |
| `is_player_unit` | `bool` | Team assignment; drives AI vs. player control. |

### Background & Class
| Field | Type | Notes |
|-------|------|-------|
| `background` | `String` | Background handle. Resolves to a `BackgroundData` via `BackgroundLibrary.get_background()`. Pool is per-archetype (`ArchetypeLibrary.ARCHETYPES[...].backgrounds`). **Migration note:** currently stores display-case strings (`"Crook"`); BackgroundLibrary keys on snake_case ids (`"crook"`). ArchetypeLibrary + any consumer that reads this field need to migrate to snake_case before BackgroundLibrary lookups succeed. |
| `unit_class` | `String` | e.g. "Rogue", "Barbarian", "Wizard". Fixed per archetype. |

### Portrait
| Field | Type | Notes |
|-------|------|-------|
| `portrait` | `Texture2D` | Face portrait for StatPanel / UnitInfoBar. `null` → falls back to Godot icon. |

### Artwork
| Field | Type | Notes |
|-------|------|-------|
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
`weapon`, `armor`, `accessory` — typed `EquipmentData` (nullable; `null` = unequipped). Stat bonuses are applied to derived stats via `_equip_bonus()`. Gear comes from rewards — no archetype starts with equipment.
`consumable` — consumable ID into `ConsumableLibrary` (e.g. `"healing_potion"`). Set to `""` when used in combat.

### Ability Slots
`abilities: Array[String]` — exactly 4 active slots. Stores ability IDs (e.g. `"strike"`). Empty string = unfilled slot. Looked up via `AbilityLibrary.get_ability()` at runtime.

### Persistent Run State (Slices 1 & 2)
These fields survive between combats. Seeded at creation by `ArchetypeLibrary.create()`. Persisted to disk via `GameState.save()` / `load_save()` as of Slice 2 — serialized by `GameState._serialize_combatant()` / `_deserialize_combatant()`.

| Field | Type | Default | Notes |
|-------|------|---------|-------|
| `ability_pool` | `Array[String]` | archetype's active abilities + `pool_extras` | Full unlocked set — superset of `abilities`. Seeded in `create()` from `abilities` then `pool_extras` (deduped). Future leveling appends here without touching the 4-slot active list. |
| `current_hp` | `int` | `hp_max` | Live HP between combats. |
| `current_energy` | `int` | `energy_max` | Live energy between combats. |
| `is_dead` | `bool` | `false` | Permanent death flag. Set by `CombatManager3D._on_unit_died()` when a player unit's HP reaches 0; `GameState.save()` is called immediately. |

**Pool ⊇ Slots invariant:** every non-empty entry in `abilities` must also appear in `ability_pool`. True by construction in `create()` since both are seeded from the same archetype source.

### Enemy-Only
`qte_resolution: float` — auto-resolve accuracy for enemy QTE simulation (0.0–1.0).

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

### Defined Archetypes

| ID | Class | STR | DEX | COG | WIL | VIT | Armor | Abilities | Consumable |
|----|-------|-----|-----|-----|-----|-----|-------|-----------|------------|
| `RogueFinder` | Custom | 1–4 | 1–4 | 1–4 | 1–4 | 2–5 | 4–8 | strike, guard, fireball, sweep | `power_tonic` |
| `archer_bandit` | Rogue | 1–2 | 3–4 | 1–2 | 0–2 | 1–3 | 3–5 | quick_shot, gust, acid_splash, piercing_shot | — |
| `grunt` | Barbarian | 2–4 | 1–2 | 0–1 | 0–2 | 2–4 | 4–7 | heavy_strike, shove, sweep, taunt | — |
| `alchemist` | Wizard | 0–1 | 1–3 | 3–5 | 2–4 | 1–2 | 2–4 | smoke_bomb, fire_breath, acid_splash, healing_draught | `healing_potion` |
| `elite_guard` | Warrior | 3–5 | 1–3 | 1–2 | 2–4 | 3–5 | 7–10 | shield_bash, yank, windblast, sweep | — |

### Public API

```gdscript
static func create(archetype_id: String, character_name: String = "",
    is_player: bool = false) -> CombatantData
```

---

## Dependencies

| Dependent | On |
|-----------|----|
| `EquipmentData` | Nothing (leaf node) |
| `CombatantData` | `EquipmentData` |
| `EquipmentLibrary` | `EquipmentData` |
| `ArchetypeLibrary` | `CombatantData` |
| `Unit3D` | `CombatantData` (via `@export var data`) |
| `StatPanel` | `CombatantData`, `Unit3D` |
| `CombatManager3D` | `ArchetypeLibrary`, `CombatantData` |

---

## AbilityData

`resources/AbilityData.gd` — Resource subclass. One instance per ability. Created by `AbilityLibrary.get_ability()`.

### Enums

**Attribute** — which stat an ability scales with; also used by EffectData as `target_stat` for BUFF/DEBUFF:
`STRENGTH(0)`, `DEXTERITY(1)`, `COGNITION(2)`, `VITALITY(3)`, `WILLPOWER(4)`, `NONE(5)`

**TargetShape** — the geometry of the targeting area:

| Value | Behavior |
|-------|---------|
| `SELF(0)` | Auto-targets the caster; no highlight step |
| `SINGLE(1)` | Player picks one valid unit within range |
| `CONE(2)` | Expanding T: stem(1) → 3-wide crossbar(2) → 5-wide back row(3). Without passthrough, a unit at the stem blocks depth 2+3. |
| `LINE(3)` | Straight ray up to tile_range; stops at first unit unless passthrough=true |
| `RADIAL(4)` | Diamond ≤ 2 Manhattan. Without passthrough, pure cardinal distance-2 cells blocked by a unit directly between them and origin. Diagonal cells never blocked. |
| `ARC(5)` | 3-wide adjacent row: left, center, right of the chosen direction. No passthrough logic. |

**ApplicableTo** — which units can be affected:
`ALLY(0)`, `ENEMY(1)`, `ANY(2)`

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case key |
| `ability_name` | `String` | Display name |
| `attribute` | `Attribute` | Stat this ability scales with |
| `target_shape` | `TargetShape` | Area geometry |
| `applicable_to` | `ApplicableTo` | Which units can be affected |
| `tile_range` | `int` | 0–10; `-1` = whole map |
| `passthrough` | `bool` | CONE: crossbar/back not blocked by stem unit. RADIAL: cardinal back cells not blocked. LINE: continues past first unit. |
| `energy_cost` | `int` | Subtracted from unit energy on use |
| `effects` | `Array[EffectData]` | Ordered list; one QTE fires for the whole ability |
| `description` | `String` | Flavor + mechanic tooltip |
| `ability_icon` | `Texture2D` | Defaults to Godot icon (placeholder) |

---

## EffectData

`resources/EffectData.gd` — Resource subclass. One instance per effect within an ability.

### Enums

**EffectType:** `HARM(0)`, `MEND(1)`, `FORCE(2)`, `TRAVEL(3)`, `BUFF(4)`, `DEBUFF(5)`

**PoolType** (HARM / MEND only): `HP(0)`, `ENERGY(1)`

**MoveType** (TRAVEL only): `FREE(0)`, `LINE(1)`

**ForceType** (FORCE only):

| Value | Direction |
|-------|-----------|
| `PUSH(0)` | Away from caster along caster→target axis |
| `PULL(1)` | Toward caster along target→caster axis |
| `LEFT(2)` | 90° left of caster→target axis |
| `RIGHT(3)` | 90° right of caster→target axis |
| `RADIAL(4)` | Away from the blast origin cell (used with RADIAL shape) |

### Fields

| Field | Type | Used by |
|-------|------|---------|
| `effect_type` | `EffectType` | All |
| `base_value` | `int` | All |
| `target_pool` | `PoolType` | HARM, MEND |
| `target_stat` | `int` | BUFF, DEBUFF (stores `AbilityData.Attribute` int) |
| `movement_type` | `MoveType` | TRAVEL |
| `force_type` | `ForceType` | FORCE |

### QTE Resolution

One QTE fires per ability. The resulting `accuracy: float` (0.0–1.0) is shared across all effects:

| Effect Type | Formula |
|-------------|---------|
| HARM / MEND | `max(1, round(accuracy × (base_value + caster.attribute_value)))` |
| BUFF / DEBUFF | flat `base_value`; accuracy < 0.3 = miss |
| FORCE | slides target up to `base_value` tiles; accuracy < 0.3 = miss |
| TRAVEL | player picks destination; QTE accuracy unused for distance |

---

## AbilityLibrary

`scripts/globals/AbilityLibrary.gd` — static class, mirrors `ArchetypeLibrary`.

### Defined Abilities (22)

| ID | Name | Attr | Cost | Range | Shape | Targets | Effects |
|----|------|------|------|-------|-------|---------|---------|
| `strike` | Strike | STR | 2 | 1 | Single | Enemy | HARM 5 HP |
| `heavy_strike` | Heavy Strike | STR | 4 | 1 | Single | Enemy | HARM 9 HP |
| `quick_shot` | Quick Shot | DEX | 2 | 3 | Single | Enemy | HARM 4 HP |
| `disengage` | Disengage | DEX | 2 | 1 | Self | Any | TRAVEL 1 FREE |
| `acid_splash` | Acid Splash | COG | 3 | 3 | Single | Enemy | HARM 3 HP + DEBUFF 1 DEX |
| `smoke_bomb` | Smoke Bomb | COG | 2 | 2 | Radial | Any | DEBUFF 1 DEX |
| `healing_draught` | Healing Draught | VIT | 3 | 0 | Self | Any | MEND 5 HP |
| `shield_bash` | Shield Bash | STR | 3 | 1 | Single | Enemy | HARM 3 HP + DEBUFF 1 STR |
| `counter` | Counter | WIL | 2 | 0 | Self | Any | BUFF 2 STR |
| `taunt` | Taunt | WIL | 1 | 3 | Single | Enemy | DEBUFF 1 WIL |
| `inspire` | Inspire | WIL | 3 | 3 | Single | Ally | BUFF 1 STR |
| `guard` | Guard | VIT | 2 | 0 | Self | Any | BUFF 2 VIT |
| `sweep` | Sweep | STR | 3 | 1 | Arc | Enemy | HARM 4 HP |
| `piercing_shot` | Piercing Shot | DEX | 3 | 6 | Line | Enemy | HARM 4 HP (passthrough) |
| `fire_breath` | Fire Breath | COG | 4 | 1 | Cone | Enemy | HARM 5 HP |
| `fireball` | Fireball | COG | 5 | 4 | Radial | Any | HARM 6 HP (passthrough=false) |
| `heal_burst` | Heal Burst | WIL | 4 | 2 | Radial | Ally | MEND 5 HP (passthrough=true) |
| `charge` | Charge | STR | 2 | 3 | Self | Any | TRAVEL 3 LINE |
| `gust` | Gust | DEX | 2 | 3 | Single | Any | FORCE PUSH 2 |
| `yank` | Yank | STR | 2 | 3 | Single | Any | FORCE PULL 2 |
| `shove` | Shove | STR | 3 | 1 | Single | Enemy | FORCE PUSH 2 |
| `windblast` | Windblast | COG | 3 | 3 | Radial | Enemy | FORCE RADIAL 2 |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
```

---

## ConsumableData

`resources/ConsumableData.gd` — Resource subclass. One instance per consumable item. Created by `ConsumableLibrary.get_consumable()`.

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `consumable_id` | `String` | Snake_case key |
| `consumable_name` | `String` | Display name |
| `effect_type` | `EffectData.EffectType` | MEND, BUFF, or DEBUFF only |
| `base_value` | `int` | Flat HP healed (MEND) or stat delta (BUFF/DEBUFF) |
| `target_stat` | `int` | `AbilityData.Attribute` int — BUFF/DEBUFF only |
| `description` | `String` | Tooltip text |

---

## ConsumableLibrary

`scripts/globals/ConsumableLibrary.gd` — static class, same pattern as `AbilityLibrary`.

### Defined Consumables

| ID | Name | Effect | Value |
|----|------|--------|-------|
| `healing_potion` | Healing Potion | MEND HP | 15 |
| `power_tonic` | Power Tonic | BUFF STR | +2 |

### Public API

```gdscript
## Returns a populated ConsumableData. Never returns null — falls back to a stub for unknown IDs.
static func get_consumable(consumable_id: String) -> ConsumableData
```

### Effect Resolution

Consumables apply immediately when used — no QTE, no energy cost.

| Effect Type | Resolution |
|-------------|------------|
| MEND | `unit.heal(base_value)` — flat heal, no stat scaling |
| BUFF | `_apply_stat_delta(unit, target_stat, +base_value)` |
| DEBUFF | `_apply_stat_delta(unit, target_stat, -base_value)` |

---

## Where NOT to Look

- **Effect math is NOT here** — `EffectData` defines shape; all resolution math lives in `CombatManager3D._apply_effects()` and `_apply_force()`.
- **Stat mutation at runtime is NOT here** — `CombatantData` stores base values; `_apply_stat_delta()` in CM3D modifies them mid-combat.
- **Unit visuals are NOT here** — HP bar, lunge animations, buff/debuff indicators are in `Unit3D.gd`.

---

## Key Patterns & Gotchas

- **Stats clamp to [0, 5] mid-combat** — `_apply_stat_delta()` enforces this.
- **Stat changes are rolled back at combat end** — `CombatManager3D._attr_snapshots` records each player unit's attribute baseline at setup and restores it in `_end_combat()` on both win and defeat.
- **`cognition` has no derived stat yet** — reserved for ability cost scaling.
- **`abilities` array is exactly 4 slots** — ActionMenu greys out empty slots.
- **`get_ability()` never returns null** — safe to call without nil checks.
- **ForceType.LEFT/RIGHT are implemented but not yet assigned** to any archetype ability.

---

## EquipmentLibrary

`scripts/globals/EquipmentLibrary.gd` — static class, same pattern as `AbilityLibrary` / `ConsumableLibrary`.

### Defined Items (6)

| ID | Name | Slot | Bonuses | Description |
|----|------|------|---------|-------------|
| `leather_armor` | Leather Armor | ARMOR | armor_defense +1 | Light protection. |
| `chain_mail` | Chain Mail | ARMOR | armor_defense +2, dexterity -1 | Heavier. Slower. |
| `short_sword` | Short Sword | WEAPON | strength +1 | A simple blade. |
| `hunters_bow` | Hunter's Bow | WEAPON | dexterity +1 | Better range. |
| `iron_ring` | Iron Ring | ACCESSORY | vitality +1 | Adds constitution. |
| `lucky_charm` | Lucky Charm | ACCESSORY | willpower +1 | Luck of the draw. |

### Public API

```gdscript
## Returns a populated EquipmentData. Never returns null — falls back to a stub for unknown IDs.
static func get_equipment(id: String) -> EquipmentData
## Returns all 6 defined items. Use for reward pools.
static func all_equipment() -> Array[EquipmentData]
```

---

## BackgroundData

`resources/BackgroundData.gd` — Resource subclass. One instance per background row. Created by `BackgroundLibrary.get_background()`.

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `background_id` | `String` | Snake_case key (e.g. `"crook"`). |
| `background_name` | `String` | Display name (e.g. `"Crook"`). |
| `starting_ability_id` | `String` | The 1 action granted at character creation (GAME_BIBLE: "1 action from their background"). FK → `AbilityLibrary`. Placeholder ids in CSV until real ability ids are wired. |
| `feat_pool` | `Array[String]` | Pool of feat ids the character can draw from at odd levels (alongside the class feat pool). Placeholder until the feat system exists. |
| `unlocked_by_default` | `bool` | `true` = available at character creation in fresh saves; `false` = meta-progression unlock. |
| `tags` | `Array[String]` | Optional event hooks (e.g. `["criminal", "urban"]`). Per GAME_BIBLE, backgrounds rarely gate events — tags are a light coupling for the cases that do. |
| `description` | `String` | Short flavor line for character creation UI. |

### Helpers

```gdscript
func has_tag(tag: String) -> bool
```

---

## BackgroundLibrary

`scripts/globals/BackgroundLibrary.gd` — static class. **First library in the codebase that sources from CSV**; future migrations of AbilityLibrary / EquipmentLibrary / ConsumableLibrary should follow this shape.

### Data Flow

```
rogue-finder/data/backgrounds.csv   (source of truth — edit here; Godot reads via res://data/)
        │
        ▼  FileAccess.get_csv_line(",")
BackgroundLibrary._cache            (lazy-loaded Dictionary keyed by id)
```

### Public API

```gdscript
## Returns a populated BackgroundData. Never returns null — stub for unknown IDs.
static func get_background(id: String) -> BackgroundData
## Back-compat lookup by display name ("Crook" / "Soldier"). Bridges the gap
## while CombatantData.background and ArchetypeLibrary still use PascalCase
## display strings. Delete when snake_case id migration lands.
static func get_background_by_name(display_name: String) -> BackgroundData
## Returns every loaded background. For character-creation UI / unlock screens.
static func all_backgrounds() -> Array[BackgroundData]
## Clears the cache and re-reads the CSV. Useful after editing the CSV mid-session.
static func reload() -> void
```

### Defined Backgrounds (4 seed rows)

| ID | Name | Starting Ability (placeholder) | Unlocked by Default | Tags |
|----|------|--------------------------------|---------------------|------|
| `crook` | Crook | `pickpocket` | `true` | `criminal`, `urban` |
| `soldier` | Soldier | `shield_bash` | `true` | `military`, `disciplined` |
| `scholar` | Scholar | `identify` | `true` | `academic`, `urban` |
| `baker` | Baker | `rally_feast` | `true` | `commoner`, `urban` |

### Parsing Rules

- First row is the header; column names drive field assignment via `match`.
- Arrays use `|` as the in-cell separator (e.g. `criminal|urban`).
- Booleans are literal `true` / `false` lowercase.
- Empty string → empty array for list-typed columns.
- Unknown columns → `push_warning`, row continues.
- Missing `id` → `push_error`, row skipped.
- Cell count mismatch with header → `push_error`, row skipped.

### Currently Dormant

No production code calls `BackgroundLibrary` yet — it's infrastructure waiting for consumers (character-creation screen, event system, feat system). Dormant-but-ready is intentional.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-20 | S23 — `ArchetypeLibrary`: added `pool_extras` key to archetype schema; `create()` now appends extras to `ability_pool` after seeding from `abilities` (deduped). Three archetypes have extras: RogueFinder (+4), archer_bandit (+4), grunt (+4). `alchemist` and `elite_guard` have no `pool_extras` (defaults to empty). Pool ⊇ Slots invariant still holds — extras supplement but never replace active slots. |
| 2026-04-19 | Added `BackgroundData` resource + `BackgroundLibrary` static class — first CSV-sourced library. CSV lives at `rogue-finder/data/backgrounds.csv` (single source; read via `res://data/`). `get_background_by_name()` bridges the existing PascalCase display-string convention (`CombatantData.background`, `ArchetypeLibrary` pools) so the library is callable today without a snake_case-id migration. Dormant — no callers yet. |
| 2026-04-19 | Slice 3 — `is_dead` now set by `CombatManager3D._on_unit_died()` (permadeath). `current_hp`/`current_energy` written back on combat victory. `Unit3D.setup()` seeds from `current_hp`/`current_energy` so a unit enters combat at its last saved HP. |
| 2026-04-19 | Slice 2 — Persistent run state fields now saved/loaded via `GameState._serialize_combatant()` / `_deserialize_combatant()`. `GameState.party: Array[CombatantData]` holds the active roster; `GameState.init_party()` seeds it on fresh runs. Equipment slots persist as `equipment_id` strings; `""` → `null` on load. 6 new headless tests. |
| 2026-04-18 | Slice 1 — Added `ability_pool`, `current_hp`, `current_energy`, `is_dead` to CombatantData. `ArchetypeLibrary.create()` seeds pool from archetype abilities (no empty strings), current_hp/energy to max. Pool ⊇ slots invariant documented. |
| 2026-04-16 | Added EquipmentData resource + EquipmentLibrary (6 placeholder items, 2 per slot) |
| 2026-04-16 | CombatantData equipment slots changed from String to EquipmentData (nullable); derived stats now include equipment bonuses via _equip_bonus() |
| 2026-04-16 | Added ConsumableData resource + ConsumableLibrary (healing_potion MEND 15, power_tonic BUFF STR+2) |
| 2026-04-16 | ArchetypeLibrary consumable values changed from display strings to ConsumableLibrary IDs |
| 2026-04-16 | CombatManager3D._on_consumable_selected() now applies MEND/BUFF/DEBUFF effects immediately |
| 2026-04-16 | Added `shove` ability (STR, SINGLE, FORCE PUSH 2, cost 3); equipped to grunt slot 3 |
| 2026-04-15 | Added `ARC(5)` to TargetShape — 3-wide adjacent arc for sweep-style abilities |
| 2026-04-15 | Reshaped `CONE` to expanding T: stem(1) + crossbar(3) + back row(5) |
| 2026-04-15 | Added `ForceType` enum to EffectData (PUSH/PULL/LEFT/RIGHT/RADIAL) + `force_type` field |
| 2026-04-15 | Added 6 new abilities: fireball, heal_burst, charge, gust, yank, windblast |
| 2026-04-15 | Updated all archetype ability assignments; `taunt`/`inspire` removed from active slots (still defined) |
| 2026-04-15 | Added `EffectData` resource, rewrote `AbilityData`, defined all 14 base abilities with typed EffectData |
