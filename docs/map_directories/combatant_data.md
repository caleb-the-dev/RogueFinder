# System: Combatant Data Model

> Last updated: 2026-04-15 (Session 7 — ARC shape added; CONE reshaped; ForceType enum; 6 new abilities; archetype ability assignments updated)

---

## Purpose

`CombatantData` is the authoritative data record for every combatant (player or NPC). It replaces the simpler `UnitData` resource with a full identity + archetype + attribute model.

`ArchetypeLibrary` is the factory that creates randomized `CombatantData` instances according to per-archetype range constraints.

---

## Core Files

| File | Role |
|------|------|
| `resources/CombatantData.gd` | Resource: identity, attributes, equipment, ability pool. Derived stats are computed properties. |
| `scripts/globals/ArchetypeLibrary.gd` | Static factory: archetype definitions + `create()` method. |

---

## Design Principles

**Identity vs. Blueprint:**
- `character_name` — the name this specific combatant goes by (e.g., "Vael")
- `archetype_id` — the species/template (e.g., "archer_bandit"). Fixes class, artwork, and the pools from which background and attributes are drawn.

Like a Pokémon: the archetype is Pikachu, the character_name is whatever the trainer called it.

**Fixed per archetype:** `unit_class`, `artwork_idle`, `artwork_attack`, `abilities`.

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
| `background` | `String` | e.g. "Crook", "Baker". Pool is per-archetype. |
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
`weapon`, `armor`, `accessory` — currently empty strings (item system TBD).
`consumable` — display name of equipped consumable (e.g. `"Healing Potion"`). Set to `""` when used in combat.

### Ability Pool
`abilities: Array[String]` — exactly 4 slots. Stores ability IDs (e.g. `"strike"`). Empty string = unfilled slot. Looked up via `AbilityLibrary.get_ability()` at runtime.

### Enemy-Only
`qte_resolution: float` — auto-resolve accuracy for enemy QTE simulation (0.0–1.0).

---

## Derived Stats (computed properties on CombatantData)

| Property | Formula |
|----------|---------|
| `hp_max` | `10 * vitality` |
| `energy_max` | `5 + vitality` |
| `energy_regen` | `2 + willpower` |
| `speed` | `2 + dexterity` |
| `attack` | `5 + strength` |
| `defense` | alias → `armor_defense` |

---

## ArchetypeLibrary

### Defined Archetypes

| ID | Class | STR | DEX | COG | WIL | VIT | Armor | Abilities |
|----|-------|-----|-----|-----|-----|-----|-------|-----------|
| `RogueFinder` | Custom | 1–4 | 1–4 | 1–4 | 1–4 | 2–5 | 4–8 | strike, guard, fireball, sweep |
| `archer_bandit` | Rogue | 1–2 | 3–4 | 1–2 | 0–2 | 1–3 | 3–5 | quick_shot, disengage, piercing_shot, gust |
| `grunt` | Barbarian | 2–4 | 1–2 | 0–1 | 0–2 | 2–4 | 4–7 | heavy_strike, charge, -, - |
| `alchemist` | Wizard | 0–1 | 1–3 | 3–5 | 2–4 | 1–2 | 2–4 | heal_burst, smoke_bomb, healing_draught, fire_breath |
| `elite_guard` | Warrior | 3–5 | 1–3 | 1–2 | 2–4 | 3–5 | 7–10 | shield_bash, yank, windblast, sweep |

### Public API

```gdscript
static func create(archetype_id: String, character_name: String = "",
    is_player: bool = false) -> CombatantData
```

---

## Dependencies

| Dependent | On |
|-----------|----|
| `CombatantData` | Nothing (leaf node) |
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

### Defined Abilities (20)

| ID | Name | Attr | Cost | Range | Shape | Targets | Effects |
|----|------|------|------|-------|-------|---------|---------|
| `strike` | Strike | STR | 2 | 1 | Single | Enemy | HARM 5 HP |
| `heavy_strike` | Heavy Strike | STR | 4 | 1 | Single | Enemy | HARM 9 HP |
| `quick_shot` | Quick Shot | DEX | 2 | 4 | Single | Enemy | HARM 4 HP |
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
| `windblast` | Windblast | COG | 3 | 3 | Radial | Enemy | FORCE RADIAL 2 |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
```

---

## Where NOT to Look

- **Effect math is NOT here** — `EffectData` defines shape; all resolution math lives in `CombatManager3D._apply_effects()` and `_apply_force()`.
- **Stat mutation at runtime is NOT here** — `CombatantData` stores base values; `_apply_stat_delta()` in CM3D modifies them mid-combat.
- **Unit visuals are NOT here** — HP bar, lunge animations, buff/debuff indicators are in `Unit3D.gd`.

---

## Key Patterns & Gotchas

- **Stats clamp to [0, 5] mid-combat** — `_apply_stat_delta()` enforces this.
- **Stat changes are permanent within a session** — no reset at combat end yet. Future: snapshot at `Unit3D.setup()` and restore post-combat.
- **`cognition` has no derived stat yet** — reserved for ability cost scaling.
- **`abilities` array is exactly 4 slots** — ActionMenu greys out empty slots.
- **`get_ability()` never returns null** — safe to call without nil checks.
- **ForceType.LEFT/RIGHT are implemented but not yet assigned** to any archetype ability.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-04-15 | Added `ARC(5)` to TargetShape — 3-wide adjacent arc for sweep-style abilities |
| 2026-04-15 | Reshaped `CONE` to expanding T: stem(1) + crossbar(3) + back row(5) |
| 2026-04-15 | Added `ForceType` enum to EffectData (PUSH/PULL/LEFT/RIGHT/RADIAL) + `force_type` field |
| 2026-04-15 | Added 6 new abilities: fireball, heal_burst, charge, gust, yank, windblast |
| 2026-04-15 | Updated all archetype ability assignments; `taunt`/`inspire` removed from active slots (still defined) |
| 2026-04-15 | Added `EffectData` resource, rewrote `AbilityData`, defined all 14 base abilities with typed EffectData |
