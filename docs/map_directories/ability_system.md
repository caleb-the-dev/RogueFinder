# System: Ability System

> Last updated: 2026-05-02 (Combat Pivot Slice 5 — lane TargetShape enum values added; abilities.csv migrated to lane shapes; old CONE/LINE/RADIAL/ARC values marked legacy)

---

## Purpose

The ability system defines **what a combatant can do on their turn**. Three collaborating pieces:

- `AbilityData` — one ability (identity, shape, cost, effects list).
- `EffectData` — one effect inside an ability (the actual math).
- `AbilityLibrary` — CSV-native loader with 63 unique abilities.

One QTE fires per ability. The resulting `multiplier` float is shared across every effect in the ability's `effects` array.

---

## Core Files

| File | Role |
|------|------|
| `resources/AbilityData.gd` | Ability resource — identity, targeting shape, cost, effects array |
| `resources/EffectData.gd` | Sub-resource — one effect within an ability |
| `scripts/globals/AbilityLibrary.gd` | CSV-native loader — `get_ability()` / `all_abilities()` / `reload()` / `get_upgraded()` API |
| `data/abilities.csv` | Data source — 66 ability rows; `effects` column is a JSON array of effect objects |

---

## AbilityData

Resource subclass. One instance per ability, created by `AbilityLibrary.get_ability()`.

### Enums

**Attribute** — which stat an ability scales with; also used by EffectData as `target_stat` for BUFF/DEBUFF:
`STRENGTH(0)`, `DEXTERITY(1)`, `COGNITION(2)`, `VITALITY(3)`, `WILLPOWER(4)`, `NONE(5)`, `PHYSICAL_ARMOR_MOD(6)`, `MAGIC_ARMOR_MOD(7)`

`PHYSICAL_ARMOR_MOD` and `MAGIC_ARMOR_MOD` are runtime-only BUFF/DEBUFF targets — they tweak the transient `physical_armor_mod` / `magic_armor_mod` fields on `CombatantData` and roll back at combat end. They are never used as ability scaling stats.

**TargetShape** — the geometry of the targeting area.

*Lane-based values (active — autobattler):*

| Value | Behavior |
|-------|---------|
| `SELF(0)` | Auto-targets the caster |
| `SAME_LANE(6)` | The unit directly opposite in the caster's lane; falls back to nearest living enemy if that slot is empty |
| `ADJACENT_LANE(7)` | All living enemies in lanes ±1 of the caster (up to 2 targets) |
| `ALL_LANES(8)` | Every living enemy on the opposite side (up to 3 targets) |
| `ALL_ALLIES(9)` | Every living unit on the caster's own side (up to 3 targets; includes caster) |

*Legacy grid values (Slice 7 retirement — still parse correctly, autobattler treats them as `SAME_LANE`):*

| Value | Old behavior (retired) |
|-------|---------|
| `SINGLE(1)` | Player picks one valid unit within range |
| `CONE(2)` | Expanding T cone (grid combat) |
| `LINE(3)` | Straight ray (grid combat) |
| `RADIAL(4)` | Diamond AoE (grid combat) |
| `ARC(5)` | 3-wide adjacent arc (grid combat) |

**ApplicableTo** — which units can be affected:
`ALLY(0)`, `ENEMY(1)`, `ANY(2)`

**DamageType** — which armor type resists this ability's HARM. Only meaningful when the ability has a HARM effect:

| Value | Meaning |
|-------|---------|
| `PHYSICAL(0)` | Resisted by `physical_defense` — melee, ranged physical attacks |
| `MAGIC(1)` | Resisted by `magic_defense` — fire, acid, arcane, gadget attacks |
| `NONE(2)` | No armor reduction — used for non-HARM abilities (MEND/BUFF/FORCE/TRAVEL) |

Parsed from the `damage_type` column in `abilities.csv` by `AbilityLibrary._DAMAGE_TYPE` lookup dict.

### Fields

| Field | Type | Notes |
|-------|------|-------|
| `ability_id` | `String` | Snake_case key |
| `ability_name` | `String` | Display name |
| `attribute` | `Attribute` | Stat this ability scales with |
| `target_shape` | `TargetShape` | Area geometry |
| `applicable_to` | `ApplicableTo` | Which units can be affected |
| `damage_type` | `DamageType` | Which armor lane resists HARM from this ability. `NONE` for non-HARM abilities. |
| `tile_range` | `int` | 0–10; `-1` = whole map |
| `passthrough` | `bool` | CONE: crossbar/back not blocked by stem unit. RADIAL: cardinal back cells not blocked. LINE: continues past first unit. |
| `energy_cost` | `int` | **Legacy** — subtracted from unit energy by old 3D combat. Retired in Slice 7. |
| `cooldown_max` | `int` | **Autobattler** — turns until ability can fire again after use. Default 0. Used by new combat (Slice 4+). Migration: cost 1–2 → 2, cost 3–4 → 3, cost 5+ → 5. |
| `effects` | `Array[EffectData]` | Ordered list; one QTE fires for the whole ability |
| `description` | `String` | Flavor + mechanic tooltip |
| `upgraded_id` | `String` | ID of the upgraded form; empty when no upgrade exists. Set on the base row — the upgraded row is a regular ability. |
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

### Defined Abilities (63)

> **Count note:** 63 unique CSV rows. `stone_guard`, `guard`, and `divine_ward` appear in two organizational sections each (ancestry/base/class-pool AND armor families) — they are single abilities used in both contexts, not duplicates.

Rows are grouped by origin; all share the same CSV format and `get_ability()` lookup.

#### Base Abilities (22)

| ID | Name | Attr | Cost | Shape | Targets | Effects |
|----|------|------|------|-------|---------|---------|
| `strike` | Strike | STR | 2 | SameLane | Enemy | HARM 5 HP |
| `heavy_strike` | Heavy Strike | STR | 4 | SameLane | Enemy | HARM 9 HP |
| `quick_shot` | Quick Shot | DEX | 2 | SameLane | Enemy | HARM 4 HP |
| `disengage` | Disengage | DEX | 2 | Self | Any | TRAVEL 1 FREE |
| `acid_splash` | Acid Splash | COG | 3 | SameLane | Enemy | HARM 3 HP + DEBUFF 1 DEX |
| `smoke_bomb` | Smoke Bomb | COG | 2 | AllLanes | Any | DEBUFF 1 DEX |
| `healing_draught` | Healing Draught | VIT | 3 | Self | Any | MEND 5 HP |
| `shield_bash` | Shield Bash | STR | 3 | SameLane | Enemy | HARM 3 HP + DEBUFF 1 STR |
| `counter` | Counter | WIL | 2 | Self | Any | BUFF 2 STR |
| `taunt` | Taunt | WIL | 1 | SameLane | Enemy | DEBUFF 1 WIL |
| `inspire` | Inspire | WIL | 3 | AllAllies | Ally | BUFF 1 STR |
| `guard` | Guard | VIT | 2 | Self | Any | BUFF 2 VIT → `enhanced_guard` |
| `sweep` | Sweep | STR | 3 | AllLanes | Enemy | HARM 4 HP |
| `piercing_shot` | Piercing Shot | DEX | 3 | SameLane | Enemy | HARM 4 HP |
| `fire_breath` | Fire Breath | COG | 4 | AdjacentLane | Enemy | HARM 5 HP |
| `fireball` | Fireball | COG | 5 | AllLanes | Any | HARM 6 HP |
| `heal_burst` | Heal Burst | WIL | 4 | AllAllies | Ally | MEND 5 HP |
| `charge` | Charge | STR | 2 | Self | Any | TRAVEL 3 LINE |
| `gust` | Gust | DEX | 2 | SameLane | Any | FORCE PUSH 2 |
| `yank` | Yank | STR | 2 | SameLane | Any | FORCE PULL 2 |
| `shove` | Shove | STR | 3 | SameLane | Enemy | FORCE PUSH 2 |
| `windblast` | Windblast | COG | 3 | AllLanes | Enemy | FORCE RADIAL 2 |

#### Kindred Natural Attacks (8) — assigned as `abilities[1]` at character creation

| ID | Name | Kindred | Attr | Cost | Effects |
|----|------|---------|------|------|---------|
| `focused_strike` | Focused Strike | Human | STR | 2 | HARM 5 HP (SameLane) |
| `savage_blow` | Savage Blow | Half-Orc | STR | 2 | HARM 6 HP (SameLane) |
| `gadget_spark` | Gadget Spark | Gnome | COG | 2 | HARM 4 HP (SameLane) |
| `stone_fist` | Stone Fist | Dwarf | STR | 2 | HARM 5 HP (SameLane) |
| `bone_strike` | Bone Strike | Skeleton | STR | 2 | HARM 5 HP (SameLane) |
| `gnaw` | Gnaw | Giant Rat | STR | 2 | HARM 4 HP (SameLane) |
| `venom_bite` | Venom Bite | Spider | DEX | 2 | HARM 3 HP + DEBUFF 1 DEX (SameLane) |
| `claw_swipe` | Claw Swipe | Dragon | STR | 2 | AllLanes HARM 5 HP |

#### Kindred Ancestry Abilities (14) — in kindred `ability_pool` (not granted at creation)

| ID | Name | Attr | Cost | Effects |
|----|------|------|------|---------|
| `steadfast` | Steadfast | WIL | 2 | BUFF 2 VIT |
| `battle_surge` | Battle Surge | STR | 3 | BUFF 2 STR |
| `warcry` | Warcry | WIL | 2 | AdjacentLane DEBUFF 1 STR |
| `tinker_boost` | Tinker Boost | COG | 2 | BUFF 1 COG |
| `quick_wit` | Quick Wit | COG | 2 | DEBUFF 1 COG (range 3) |
| `stone_guard` | Stone Guard | STR | 2 | BUFF 2 PHYSICAL_ARMOR_MOD | `fortified_guard` |
| `grim_endurance` | Grim Endurance | WIL | 2 | BUFF 2 VIT (Skeleton) |
| `death_rattle` | Death Rattle | WIL | 2 | DEBUFF 1 WIL range 2 (Skeleton) |
| `scatter` | Scatter | DEX | 1 | TRAVEL 2 FREE — cost 1, cheapest ability (Giant Rat) |
| `pack_instinct` | Pack Instinct | WIL | 2 | AllAllies BUFF 1 STR (Giant Rat) |
| `web_shot` | Web Shot | COG | 3 | DEBUFF 2 DEX range 3 (Spider) |
| `skitter` | Skitter | DEX | 2 | BUFF 2 DEX (Spider) |
| `draconic_breath` | Draconic Breath | COG | 3 | AdjacentLane HARM 4 MAGIC (Dragon) |
| `scales_up` | Scales Up | STR | 2 | BUFF 2 PHYSICAL_ARMOR_MOD (Dragon) |

#### Class Defining Abilities (4) — unique per class, assigned as `abilities[0]` at character creation

| ID | Name | Class | Attr | Cost | Range | Targets | Effects |
|----|------|-------|------|------|-------|---------|---------|
| `tower_slam` | Tower Slam | Vanguard | STR | 3 | 1 | Enemy | HARM 4 HP + FORCE PUSH 1 |
| `arcane_bolt` | Arcane Bolt | Arcanist | COG | 3 | 4 | Enemy | HARM 5 HP |
| `slipshot` | Slipshot | Prowler | DEX | 3 | 3 | Enemy | HARM 4 HP + TRAVEL 1 FREE |
| `bless` | Bless | Warden | WIL | 2 | 3 | AllAllies | BUFF 1 STR |

> Defining abilities must **not** appear in any class's `ability_pool` — they are auto-granted separately.

#### Weapon Abilities (6) — granted via equipped weapons (Slice 3)

Each base ability is linked to its upgrade via `upgraded_id`. These are pool-only abilities — they appear in the level-up pick screen when the weapon is equipped, and are removed from the pool on unequip (unless slotted).

| ID | Name | Attr | Cost | Range | Effects | Upgraded Form |
|----|------|------|------|-------|---------|---------------|
| `blade_strike` | Blade Strike | STR | 2 | 1 | HARM 4 PHYSICAL | `heavy_blade_strike` |
| `heavy_blade_strike` | Heavy Blade Strike | STR | 2 | 1 | HARM 7 PHYSICAL | — |
| `quick_draw` | Quick Draw | DEX | 2 | 3 | HARM 4 PHYSICAL | `aimed_draw` |
| `aimed_draw` | Aimed Draw | DEX | 2 | 3 | HARM 6 PHYSICAL | — |
| `staff_bolt` | Staff Bolt | COG | 3 | 4 | HARM 4 MAGIC | `empowered_bolt` |
| `empowered_bolt` | Empowered Bolt | COG | 3 | 4 | HARM 7 MAGIC | — |

#### Armor Abilities (6) — granted via equipped armor (Slice 4)

3 base abilities (one per armor family) linked to 3 upgraded forms via `upgraded_id`. All are BUFF effects (never HARM). `guard` and `stone_guard` existed before this slice; their `upgraded_id` was wired here. `divine_ward` also existed; `greater_ward` is new.

| ID | Name | Attr | Cost | Effects | Upgraded Form |
|----|------|------|------|---------|---------------|
| `stone_guard` | Stone Guard | STR | 2 | BUFF 2 PHYSICAL_ARMOR_MOD | `fortified_guard` |
| `fortified_guard` | Fortified Guard | STR | 2 | BUFF 3 PHYSICAL_ARMOR_MOD | — |
| `guard` | Guard | VIT | 2 | BUFF 2 VIT | `enhanced_guard` |
| `enhanced_guard` | Enhanced Guard | VIT | 2 | BUFF 3 VIT | — |
| `divine_ward` | Divine Ward | WIL | 2 | BUFF 2 MAGIC_ARMOR_MOD | `greater_ward` |
| `greater_ward` | Greater Ward | WIL | 2 | BUFF 3 MAGIC_ARMOR_MOD | — |

#### Class Pool Additions (6) — added for Prowler / Warden pools (2026-04-26)

| ID | Name | Attr | Cost | Range | Targets | Effects |
|----|------|------|------|-------|---------|---------|
| `backstab` | Backstab | DEX | 3 | 1 | Enemy | HARM 6 HP |
| `crippling_shot` | Crippling Shot | DEX | 3 | 3 | Enemy | HARM 3 HP + DEBUFF 1 DEX |
| `vanishing_step` | Vanishing Step | DEX | 2 | 0 | Self | BUFF 2 DEX |
| `lay_on_hands` | Lay on Hands | WIL | 3 | 1 | AllAllies | MEND 6 HP |
| `divine_ward` | Divine Ward | WIL | 2 | 0 | Self | BUFF 2 MAGIC_ARMOR_MOD | `greater_ward` |
| `rallying_shout` | Rallying Shout | WIL | 3 | 1 | AllAllies | BUFF 1 STR |

### Public API

```gdscript
## Returns a populated AbilityData. Never returns null — falls back to a stub for unknown IDs.
static func get_ability(ability_id: String) -> AbilityData
static func all_abilities() -> Array[AbilityData]   # replaces ABILITIES iteration
static func reload() -> void                         # cache-clear for tests/dev
## Returns the upgraded form of base_id. Falls back to a blank stub (ability_id == "") when
## upgraded_id is empty or unknown — callers never need nil checks.
static func get_upgraded(base_id: String) -> AbilityData
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

- **New lane TargetShape values are the live vocabulary** — `SAME_LANE`, `ADJACENT_LANE`, `ALL_LANES`, `ALL_ALLIES` are the active autobattler shapes. All 64 CSV rows migrated in Slice 5. Legacy values `SINGLE/CONE/LINE/RADIAL/ARC` still parse (Slice 7 removes them from code); `CombatManagerAuto.resolve_targets` treats them as `SAME_LANE` until then.
- **`ALL_ALLIES` includes the caster** — `resolve_targets` calls `board.get_all_on_side(caster_side)` which returns every unit on the caster's side, including the caster themselves. Heal/buff abilities using `ALL_ALLIES` will affect the caster.
- **`energy_cost` and `cooldown_max` coexist until Slice 7** — `energy_cost` drives the old 3D combat; `cooldown_max` drives the new autobattler (Slice 4+). Do not remove `energy_cost` before the Slice 7 cutover. Both fields parse from CSV (`cost` → `energy_cost`, `cooldown` → `cooldown_max`).
- **`cooldown_max` migration table:** cost 0 → cooldown 0, cost 1–2 → cooldown 2, cost 3–4 → cooldown 3, cost 5+ → cooldown 5. All 63 abilities migrated in Slice 2.
- **`get_ability()` never returns null** — safe to call without nil checks. Unknown IDs return a stub AbilityData with `ability_id = "unknown"` and `damage_type = DamageType.NONE`.
- **`get_upgraded()` stub differs from `get_ability()` stub** — when `upgraded_id` is empty or unresolvable, `get_upgraded()` returns a blank `AbilityData.new()` with `ability_id == ""` (not `"unknown"`). Callers checking for "no upgrade available" should test `result.ability_id == ""`, not `result == null`.
- **One QTE per ability, not per effect** — `AbilityData.effects` can contain multiple entries (e.g. `acid_splash`: HARM + DEBUFF); they all receive the same `multiplier`.
- **CSV effects format** — each row's `effects` cell is a JSON array. String enum names (e.g. `"HARM"`, `"DEXTERITY"`) are mapped to int values by lookup tables inside `AbilityLibrary`. Edit the CSV in a spreadsheet; the `""` escaping of double quotes is standard CSV and handled transparently.
- **`damage_type` lives on `AbilityData`, not `EffectData`** — it is ability-level, shared by all effects in the ability. This means an ability cannot mix PHYSICAL and MAGIC damage from a single cast.
- **Physical vs magic tagging:** physical = melee/ranged weapon attacks; magic = fire/acid/arcane/gadget. Non-HARM abilities (MEND/BUFF/DEBUFF/FORCE/TRAVEL) use `NONE`.

---

## Recent Changes

| Date | Change |
|---|---|
| 2026-05-02 | **Combat Pivot Slice 5 — lane targeting.** `AbilityData.TargetShape` gained 4 new values: `SAME_LANE(6)`, `ADJACENT_LANE(7)`, `ALL_LANES(8)`, `ALL_ALLIES(9)`. Old values `SINGLE/CONE/LINE/RADIAL/ARC` remain (Slice 7 retirement). `AbilityLibrary._TARGET_SHAPE` dict extended with the 4 new string keys. `abilities.csv` fully migrated: all 64 rows now use lane-based shapes (no remaining CONE/LINE/RADIAL/ARC). Migration: SINGLE ENEMY→SAME_LANE; SINGLE ALLY→ALL_ALLIES; CONE→ADJACENT_LANE; LINE→SAME_LANE; RADIAL ALLY→ALL_ALLIES; RADIAL ANY/ENEMY→ALL_LANES; ARC HARM→ALL_LANES; ARC DEBUFF→ADJACENT_LANE; ARC ALLY→ALL_ALLIES. `CombatManagerAuto.resolve_targets(caster, ability, board)` static method added — replaces `_stub_pick_target`. `_fire_unit_turn` now calls `resolve_targets` and iterates over the returned array (supports multi-hit AoE). `_stub_pick_target` deleted. 6 headless tests added (`test_lane_targeting.gd/.tscn`). `test_combat_loop.gd` updated with `get_tree().quit()` for headless execution. |
| 2026-05-02 | **Combat Pivot Slice 2 — cooldown field.** `AbilityData` gained `@export var cooldown_max: int = 0` (next to `energy_cost`; both fields coexist until Slice 7). `abilities.csv` gained a `cooldown` column after `cost`; all 63 rows populated per migration table (cost 1–2 → 2, 3–4 → 3, 5+ → 5, 0 → 0). `AbilityLibrary._row_to_data()` gained `"cooldown"` match case → sets `a.cooldown_max`. `energy_cost` untouched — old combat unaffected. 3 headless tests added (`test_cooldown_field.gd`). |
| 2026-04-29 | **Armor Tier Families (Slice 4).** 6 new armor abilities added: `stone_guard` / `divine_ward` / `guard` (3 existing) gained `upgraded_id` links to `fortified_guard` / `greater_ward` / `enhanced_guard` (3 new). Upgraded forms are plain BUFF abilities with `base_value` bumped by +1 (2→3). All are SELF-target BUFF, cost 2, NONE damage_type. Total abilities: 60→66. |
| 2026-04-28 | **Weapon Tier Families (Slice 3).** 6 new weapon abilities added to `abilities.csv`: `blade_strike` (STR base, upgraded_id=heavy_blade_strike), `heavy_blade_strike` (STR upgraded), `quick_draw` (DEX base, upgraded_id=aimed_draw), `aimed_draw` (DEX upgraded), `staff_bolt` (COG base, upgraded_id=empowered_bolt), `empowered_bolt` (COG upgraded). All are HARM-only with the appropriate `DamageType` (PHYSICAL or MAGIC). Total abilities: 54→60. |
| 2026-04-28 | **Upgraded ability data layer (Rarity Slice 2).** `AbilityData` gained `upgraded_id: String = ""`. `AbilityLibrary` parses the new CSV column and exposes `get_upgraded(base_id)` — returns the linked ability or a blank stub; never null. `abilities.csv` gained the `upgraded_id` column (all 54 rows empty — content comes in Slices 3–5). 6 headless tests added. |
| 2026-04-27 | **Kindred expansion — 12 new abilities.** 4 new kindreds (Skeleton, Giant Rat, Spider, Dragon) each received a natural attack + 2 ancestry pool abilities. Total 42→54. Notable: `scatter` (cost 1) is intentionally the cheapest ability in the game. `venom_bite` is the first natural attack with a dual effect (HARM + DEBUFF). `claw_swipe` uses ARC shape at natural-attack cost 2. No code changes — data-only additions to `abilities.csv`. |
| 2026-04-27 | **Armor mod — Attribute enum extended.** Added `PHYSICAL_ARMOR_MOD = 6` and `MAGIC_ARMOR_MOD = 7` to `AbilityData.Attribute`. `AbilityLibrary._ATTRIBUTE` gained the matching string keys so JSON `"stat":"PHYSICAL_ARMOR_MOD"` / `"MAGIC_ARMOR_MOD"` parse correctly in effects cells. `stone_guard` and `divine_ward` rows updated from the dead `"ARMOR_DEFENSE"` value to the new enum names — both are now mechanically active. No new abilities; no other ability rows changed. |
| 2026-04-27 | **DamageType enum + damage_type field.** `AbilityData` gained `DamageType` enum (`PHYSICAL=0`, `MAGIC=1`, `NONE=2`) and `damage_type: DamageType = DamageType.NONE` field. `abilities.csv` gained `damage_type` column — all 42 abilities tagged. `AbilityLibrary` gained `_DAMAGE_TYPE` lookup dict; `_row_to_data` parses the new column. Physical: melee/ranged attacks. Magic: fire/acid/arcane/gadget. NONE: all non-HARM abilities. |
| 2026-04-26 | **Class pool expansion** — 4 class defining abilities + 6 pool additions (Prowler + Warden); abilities.csv 32→42 rows. |
| 2026-04-26 | **Pillar foundation** — 4 kindred natural attacks + 6 ancestry abilities added; all sourced from abilities.csv via AbilityLibrary. |
