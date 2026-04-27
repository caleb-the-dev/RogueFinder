# System: Ability System

> Last updated: 2026-04-26 (class pool expansion — 4 class defining abilities + 6 new pool abilities; 42 total)

---

## Purpose

The ability system defines **what a combatant can do on their turn**. Three collaborating pieces:

- `AbilityData` — one ability (identity, shape, cost, effects list).
- `EffectData` — one effect inside an ability (the actual math).
- `AbilityLibrary` — static factory that builds 42 predefined abilities.

One QTE fires per ability. The resulting `multiplier` float is shared across every effect in the ability's `effects` array.

---

## Core Files

| File | Role |
|------|------|
| `resources/AbilityData.gd` | Ability resource — identity, targeting shape, cost, effects array |
| `resources/EffectData.gd` | Sub-resource — one effect within an ability |
| `scripts/globals/AbilityLibrary.gd` | CSV-native loader — 42 abilities, `get_ability()` / `all_abilities()` / `reload()` API |
| `data/abilities.csv` | Data source — 42 ability rows; `effects` column is a JSON array of effect objects |

---

## AbilityData

Resource subclass. One instance per ability, created by `AbilityLibrary.get_ability()`.

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

Resource subclass. One instance per effect within an ability.

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

`LEFT` and `RIGHT` are implemented but not yet assigned to any archetype ability.

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

One QTE fires per ability. The resulting `multiplier: float` is shared across all effects. Tiered values: `0.25` (miss), `0.75` (weak), `1.0` (good), `1.25` (perfect). See `qte_system.md`.

| Effect Type | Formula |
|-------------|---------|
| HARM / MEND | `max(1, round(multiplier * (base_value + caster.attribute_value)))` |
| BUFF / DEBUFF | flat `base_value`; `multiplier == 0.25` = miss |
| FORCE | slides target up to `base_value` tiles; `multiplier == 0.25` = miss |
| TRAVEL | player picks destination; multiplier unused for distance (`0.25` cancels reposition) |

---

## AbilityLibrary

CSV-native lazy-loaded class. Same pattern as all other data libraries. `ABILITIES` const dict removed; data now sourced from `abilities.csv`. Effects column stores a JSON array — each object has `type` (string), `base_value` (int), and type-specific optional keys (`pool`, `stat`, `move`, `force`).

### Defined Abilities (42)

Rows are grouped by origin; all share the same CSV format and `get_ability()` lookup.

#### Base Abilities (22)

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
| `piercing_shot` | Piercing Shot | DEX | 3 | 4 | Line | Enemy | HARM 4 HP (passthrough) |
| `fire_breath` | Fire Breath | COG | 4 | 1 | Cone | Enemy | HARM 5 HP |
| `fireball` | Fireball | COG | 5 | 4 | Radial | Any | HARM 6 HP (passthrough=false) |
| `heal_burst` | Heal Burst | WIL | 4 | 2 | Radial | Ally | MEND 5 HP (passthrough=true) |
| `charge` | Charge | STR | 2 | 3 | Self | Any | TRAVEL 3 LINE |
| `gust` | Gust | DEX | 2 | 3 | Single | Any | FORCE PUSH 2 |
| `yank` | Yank | STR | 2 | 3 | Single | Any | FORCE PULL 2 |
| `shove` | Shove | STR | 3 | 1 | Single | Enemy | FORCE PUSH 2 |
| `windblast` | Windblast | COG | 3 | 3 | Radial | Enemy | FORCE RADIAL 2 |

#### Kindred Natural Attacks (4) — assigned as `abilities[1]` at character creation

| ID | Name | Kindred | Attr | Cost | Effects |
|----|------|---------|------|------|---------|
| `focused_strike` | Focused Strike | Human | STR | 2 | HARM 5 HP |
| `savage_blow` | Savage Blow | Half-Orc | STR | 2 | HARM 6 HP |
| `gadget_spark` | Gadget Spark | Gnome | COG | 2 | HARM 4 HP (range 2) |
| `stone_fist` | Stone Fist | Dwarf | STR | 2 | HARM 5 HP |

#### Kindred Ancestry Abilities (6) — in kindred `ability_pool` (not granted at creation)

| ID | Name | Attr | Cost | Effects |
|----|------|------|------|---------|
| `steadfast` | Steadfast | WIL | 2 | BUFF 2 VIT |
| `battle_surge` | Battle Surge | STR | 3 | BUFF 2 STR |
| `warcry` | Warcry | WIL | 2 | ARC DEBUFF 1 STR (range 1) |
| `tinker_boost` | Tinker Boost | COG | 2 | BUFF 1 COG |
| `quick_wit` | Quick Wit | COG | 2 | DEBUFF 1 COG (range 3) |
| `stone_guard` | Stone Guard | STR | 2 | BUFF 2 ARMOR_DEFENSE |

#### Class Defining Abilities (4) — unique per class, assigned as `abilities[0]` at character creation

| ID | Name | Class | Attr | Cost | Range | Targets | Effects |
|----|------|-------|------|------|-------|---------|---------|
| `tower_slam` | Tower Slam | Vanguard | STR | 3 | 1 | Enemy | HARM 4 HP + FORCE PUSH 1 |
| `arcane_bolt` | Arcane Bolt | Arcanist | COG | 3 | 4 | Enemy | HARM 5 HP |
| `slipshot` | Slipshot | Prowler | DEX | 3 | 3 | Enemy | HARM 4 HP + TRAVEL 1 FREE |
| `bless` | Bless | Warden | WIL | 2 | 3 | Ally | BUFF 1 STR |

> Defining abilities must **not** appear in any class's `ability_pool` — they are auto-granted separately.

#### Class Pool Additions (6) — added this session for Prowler / Warden pools

| ID | Name | Attr | Cost | Range | Targets | Effects |
|----|------|------|------|-------|---------|---------|
| `backstab` | Backstab | DEX | 3 | 1 | Enemy | HARM 6 HP |
| `crippling_shot` | Crippling Shot | DEX | 3 | 3 | Enemy | HARM 3 HP + DEBUFF 1 DEX |
| `vanishing_step` | Vanishing Step | DEX | 2 | 0 | Self | BUFF 2 DEX |
| `lay_on_hands` | Lay on Hands | WIL | 3 | 1 | Ally | MEND 6 HP |
| `divine_ward` | Divine Ward | WIL | 2 | 0 | Self | BUFF 2 ARMOR_DEFENSE |
| `rallying_shout` | Rallying Shout | WIL | 3 | 1 | Ally (Arc) | BUFF 1 STR |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
static func all_abilities() -> Array[AbilityData]   # replaces ABILITIES iteration
static func reload() -> void                         # cache-clear for tests/dev
```

---

## Dependencies

| Dependent | On |
|-----------|----|
| `AbilityData` | `EffectData` (via `effects` array) |
| `AbilityLibrary` | `AbilityData`, `EffectData` |
| `CombatManager3D` | `AbilityLibrary`, `AbilityData`, `EffectData` (ability resolution + effect dispatch) |
| `CombatActionPanel` | `AbilityLibrary` (button build + tooltip) |
| `CombatantData` | `AbilityLibrary` indirectly (stores ability IDs; CM3D resolves at runtime) |

---

## Where NOT to Look

- **Effect math is NOT here** — `EffectData` defines shape; all resolution lives in `CombatManager3D._apply_effects()` and `_apply_force()`.
- **Targeting highlights are NOT here** — `Grid3D.set_highlight()` + `CombatManager3D._handle_shape_hover()` own those.
- **QTE display is NOT here** — `QTEBar.gd` routes by effect type (see `qte_system.md`).

---

## Key Patterns & Gotchas

- **`get_ability()` never returns null** — safe to call without nil checks. Unknown IDs return a stub AbilityData.
- **One QTE per ability, not per effect** — `AbilityData.effects` can contain multiple entries (e.g. `acid_splash`: HARM + DEBUFF); they all receive the same `multiplier`.
- **CSV effects format** — each row's `effects` cell is a JSON array. String enum names (e.g. `"HARM"`, `"DEXTERITY"`) are mapped to int values by lookup tables inside `AbilityLibrary`. Edit the CSV in a spreadsheet; the `""` escaping of double quotes is standard CSV and handled transparently.
