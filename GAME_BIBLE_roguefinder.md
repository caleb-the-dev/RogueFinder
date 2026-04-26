# GAME BIBLE
*High-level design overview — structural reference only*

## Working Title
**Roguefinder** *(name subject to change)*
The concept originated as a **roguelite adaptation of Pathfinder 2e (PF2e)** — borrowing its mechanical depth, and fantasy tone and translating them into a roguelite structure with a creature-collector party system.

---

## Genre & Platform
- **Genre:** Tactical Turn-Based RPG Roguelite / Creature Collector
- **Platform:** PC - Steam
- **Key References:** Into the Breach (grid combat), Slay the Spire (roguelite structure), Gordian Quest (node map), Pokémon (creature collector/party framing), XCOM (escalating threat pressure)

---

## Core Fantasy
The player takes on the role of a **divine agent** called the RogueFinder — a mortal character chosen by a deity — who leads a mixed party of humanoids and creatures through a dangerous, conflict-ridden fantasy world. The player is both a participant in combat and the strategic director of their party. Think: you are the "trainer", but you also fight alongside your party.

---

## Setting & Tone
- **World:** Medieval fantasy
- **Tone:** Grounded and mundane at the surface, with an underlying current of cosmic stakes.
- **Central Threat:** An existential evil entity that threatens to destroy the world — present and challengeable from the start of each run, but confronted on the player's terms
- **Day-to-Day Reality:** Most of the player's time is spent dealing with ordinary worldly conflicts around the map — local disputes, faction skirmishes, survival challenges — not the final threat

---

## Core Gameplay Loop
**Traverse map → Encounter (fight / recruit / interact) → Adjust party build → Repeat**

- The player moves through a procedurally generated node map surrounding the city of "Badurga"
- Encounters include combat, recruitment opportunities, vendors, story beats, and environmental interactions
- Between encounters the player manages party build, gear, and strategy
- The player's party levels up from xp gained from defeating enemies, completing quests, or successfully completing events. Max level is 20, and all party members share the same level.
- The run ends when the player chooses to face the existential threat — or loses a combat

---

## Run Structure
- Runs are **open-ended** with a **player-determined endpoint**
- There are 3 rounds of bosses, each accessible on the map from the start but the player decides when they're ready to confront
- Progress through the run involves completing **randomly generated mundane quests and missions** and exploring nodes around the map
- **Time pressure:** The longer the player takes, the more powerful the final threat becomes (XCOM-style escalation) — every node visited costs time, creating a tension between preparation and urgency
- A full run = explore and grow → decide you're ready → face the current boss threat (repeat x3)

---

## Death & Progression (Roguelite Loop)
- **Permadeath** applies to any party member that's hp reaches 0. The player's character dies during combat but the rest of the party is still victorious, they return afterwards with 1hp
- On a total-party-death, the player is **reincarnated by the deity** and returned to the world at a point in time after their previous run — narratively justifying the reset
- **Meta-progression** exists: certain upgrades, unlocks, or knowledge persist between runs
- This is a **roguelite**, not a roguelike — each run builds on the last in meaningful ways

---

## The Party — Creature Collector Framework
The NPC party system is the heart of the game. Think of it like Pokémon: your recruited units are your "pokemon," and building, combining, and managing them is the primary creative expression of the game.

### Recruitment
- NPCs are **recruited through diplomacy/coercion or caught** in the world
- Party members are unique named entities with their own visuals, background, and class
- Examples of recruitable types: Bandit, Blood Sorcerer, Griffin, Dragon
- Each NPC can be renamed by the player after they join the party

### Party Size & Management
- Players maintain a **bench** of recruited members
- Max **3 units in combat** at a time (including the player character)
- **Party composition can only be changed at the city** — not before individual encounters
- This makes city visits meaningful strategic checkpoints, not just shops
- Mid-run, the player must commit to their active 3 until they return to the city
- NPCs that join the party while exploring can immediately join the party, sending one active party member back to the city
- NPCs that perma-die during combat cause an open party slot after combat, and word can be sent for a new party member from the city to rejoin. (Costs time from the boss timer)

### Party Synergies
- Synergies between party members are a **core build consideration**
- Party composition — not just individual unit strength — defines the build

---

## Build System

### Character Structure (applies to player character and all NPCs)
Each character has:
- **A Kindred** — the character's species or ancestry (e.g. Human, Dwarf, Gnome, Half-Orc, Griffin). Fixed at creation and tied to the archetype. Kindreds are flavor now and will gain mechanical hooks (passive traits, dialogue gates, faction reactions) in future stages.
- **A Class** — defines ability progression and role
- **A Background** — light flavor and a single starting feat/ability (DOS2-style); occassionally might branch event outcomes or gate content, but not frequently
- **4 Equipment Slots:** Weapon, Armor, Consumable, Accessory
- **A Level** (max level 20)
- **Ability Pool** - A pool of available abilities to be slotted into any 1 of the 4 ability slots.
- **Feats** are dynamic stat/effect modifiers, similar to relics in Slay the Spire — they change how a character functions, not just their numbers

### Leveling & Abilities
- Every **even level** → unlock a new **class ability**, added to the character's available action pool
- Every **odd level** → earn a **feat** (from class or background);
- Characters start with 1 action from their class and 1 action from their background in their pool and grow their options over the run
- Actions can also be sourced from **items**, especially weapons — expanding the pool beyond class and feats

### Equipment
- Gear is a primary driver of power and build identity
- 4 slots per character: **Weapon, Armor, Consumable, Accessory**
- Gear interacts with class to shape a character's role
- **Weapons boost the wielder's attack attribute**, not flat damage — raw hit size lives on abilities (Base Power), so better weapons make a character a better *attacker* across their entire kit rather than just buffing one ability
- **Armor provides defense values** split across Physical and Arcane (see Combat → Damage Types & Defense)
- Consumables and accessories — schemas TBD

#### Weapon Schema (CSV fields)
| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `description` | string | Player-facing flavor text |
| `notes` | string | Dev-only notes for design/balance |
| `rarity` | enum | common / uncommon / rare / epic / legendary |
| `attribute` | enum | STR / DEX / COG — which attribute this weapon boosts when attacking |
| `attack_bonus` | int | Integer added to the wielder's chosen attribute |
| `abilities_granted` | array\<ability_id\> | Abilities added to the wielder's available pool while equipped |
| `effects` | JSON array | Additional modifiers for magic/rare weapons (e.g. `[{"stat":"STR","mod":1}]`) |

- Default: one weapon boosts one attribute. Multi-attribute or exotic bonuses are handled via `effects`.
- A character can equip an "off-attribute" weapon (e.g. a COG staff on a STR fighter) — it's a build trade-off, not a trap, since `abilities_granted` and `effects` still apply.
- Weapons do **not** carry a damage value or damage type — those live with the ability being used.

#### Armor Schema (CSV fields)
| Field | Type | Description |
|---|---|---|
| `id` | string | Unique identifier |
| `name` | string | Display name |
| `description` | string | Player-facing flavor text |
| `notes` | string | Dev-only notes for design/balance |
| `rarity` | enum | common / uncommon / rare / epic / legendary |
| `phys_def` | int | Physical Defense value |
| `arc_def` | int | Arcane Defense value |
| `abilities_granted` | array\<ability_id\> | Abilities added to the wearer's available pool while equipped |
| `effects` | JSON array | Additional modifiers for magic/rare armor |

- Armor pieces can skew heavily to one defense type (plate → high PhysDef, low ArcDef), provide a balanced split, or offer unusual profiles via rarity and effects.

---

## Combat

### Format
- **3v3** — 3 player units vs. 3 enemies
- Player character is always one of the 3 active combat slots
- All 3 player units are **fully controlled by the player** — no autobattle for allies
- Primary win condition: defeat all enemies; other win condition types not ruled out

### Damage Types & Defense
Every damaging or healing action resolves against a specific defense stat, creating matchup decisions and build expression without adding a redundant multiplier on top of the Stat Delta.

#### Two Defense Stats
- **Physical Defense (PhysDef)** — resists Physical-typed attacks
- **Arcane Defense (ArcDef)** — resists Arcane-typed attacks

Armor provides values in one or both, shaping a character's vulnerability profile.

#### Attack Resolution
- Every offensive ability has a **damage type tag: Physical or Arcane**
- The tag determines which of the target's two defense stats is used in the Stat Delta comparison
- The attacker side of the Stat Delta is the **attacker's attribute** (STR, DEX, or COG — specified by the ability) plus any weapon `attack_bonus` if the weapon boosts that attribute
- Ability damage scale is owned by the ability's **Base Power** — it does not add to the attacker's stat

This yields three clean knobs per ability:
1. **Attribute** — who's attacking (which character stat drives the Stat Delta)
2. **Base Power** — how hard the hit lands before modifiers
3. **Damage Type tag** — which defense stat the attack is compared against

#### Attribute / Damage Type Decoupling
Attribute and damage type are **independent**. The default alignment is intuitive:
- STR / DEX abilities → Physical damage
- COG abilities → Arcane damage

But **off-type abilities** — roughly 15–25% of the ability pool — break this default for build expression:
- *Flaming Sword:* STR attribute, **Arcane** damage
- *Fissure:* COG attribute, **Physical** damage
- *Blood Spike:* COG attribute, **Physical** damage

This means any character archetype can, with the right gear or ability choices, threaten either defense — preventing solved matchups and turning weapon/ability selection into a real build decision.

#### Enemy Roster Balance
- Ability distribution across the player's available pool will naturally settle roughly 60/40 physical-leaning
- **Enemy roster is designed for a roughly even spread** of Physical-threat, Arcane-threat, and mixed-threat encounters
- This keeps ArcDef a live build stat even when the player's own kit skews physical — ArcDef matters because ~⅔ of fights test it, not because the player uses it

#### Design Intent
Typing integrates *into* the Stat Delta rather than sitting on top of it. The single `attribute vs defense` comparison already answers "is this matchup favorable?" — the Physical/Arcane split just determines *which* defense is tested. No new multiplier, no redundant layer; a legible, gear-interactive matchup system.

### Grid & Positioning
- Combat takes place on a **tight grid map** 10x10 (Into the Breach-style)
- Positioning, knockback, and terrain effects are **central** to combat — not just movement range
- Spatial decision-making is a primary combat puzzle

### Turn Order
- **Team-based initiative** — all player units act first, then all enemies act
- Keeps rounds fast and readable

### Pacing Target
- Full player team turn target: **45–90 seconds** of real time
- Each unit's turn is lean: one stride, one optional consumable use, one energy-costed active action
- Enemy turns resolve with minimal delay

### Party Control
- The player **fully controls all 3 units** on their turn — no autobattle
- Enemy NPCs act autonomously, governed by behavior type and their hidden QTE stat (see Enemy AI below)
- If a party member (NPC) reaches 0 HP, they are **permanently dead** for the remainder of the run
- If the **player character** reaches 0 HP but the party wins the fight, they survive and return with **1 HP**
- If the party loses entirely, the run ends

### Action Economy Per Turn
Each unit has **3 fixed action slots** per turn:

1. **Stride** — always available; move based on the character's speed stat. Free every turn, no cost.
2. **Consumable** — use the equipped consumable item if one is equipped. Free every turn, but depletes the item on use. Does not need to be filled to enter combat.
3. **Abilities** — one of four abilities chosen from the character's slotted ability pool (see below). Costs **Energy**.

This structure keeps turns lean and decisions focused. The interesting choice each turn is *which* ability to use and whether the Energy cost is worth it right now.

### Ability Slots & Energy
Between combats, each character has a pool of available abilities earned through leveling, feats, and items. The player slots **up to 4 abilities** from this pool before entering combat — these are the options available each turn.

**Energy** is a per-character resource that governs Active Action use:
- Each character has a maximum Energy pool determined by a stat (TBD name)
- Energy regenerates each turn by an amount determined by a separate stat (TBD name)
- More powerful actions cost more Energy
- Managing Energy across a fight — spending aggressively vs. pacing for regeneration — is a core tactical layer

### Quick Time Events (QTEs)
Every Action is resolved through a **Quick Time Event**. QTEs inject real-time player skill into turn-based combat, making every action feel earned and providing a high-ceiling for mechanical mastery.

#### 1. The Dynamic Difficulty Matrix
The difficulty and structure of a QTE are derived from the action’s **Energy Cost** and its **Targeting Shape**.

* **Difficulty (Energy Anchor):** The **Energy Cost** of an action determines the speed of the QTE and the precision required. High-energy actions have faster sliders, smaller success windows, and tighter timers. Low-energy actions are more forgiving.
* **Succession (Targeting Anchor):** The **Targeting Shape** determines the number of "beats" or prompts in a sequence. The *scale* of the beat count depends on the QTE style (see §2), because each style has a different natural granularity.

    | Targeting Shape | Slide (Harm/Mend) | Target (Force) | Directional (Buff/Debuff) | Hold (Travel) |
    |---|---|---|---|---|
    | Self / Single | 1 | 3 | 3 | — |
    | Cone          | 2 | 6 | 6 | — |
    | Line          | 3 | 9 | 9 | — |
    | Radial        | 4 | 12 | 12 | — |

    **Travel** uses a single hold-and-release meter regardless of targeting shape — no beat sequence.

#### 2. QTE Styles by Effect Tag
To ensure mechanical variety, the style of the mini-game changes based on the primary **Effect Tag** of the action:
* **Harm/Mend (HP/Energy Gain or Loss):** — A timing-based slider (Gears of War style)
* **Force (Displacement):** — Rapid-target clicking (dots) on the targeted unit(s) ("Osu" or "Whack-a-Mole" effect)
* **Buff / Debuff (Stats):** — A directional input string (helldivers 2 stratagems)
* **Travel (Movement):** — A meter that must be held and released at a specific threshold (Common mechanic for the powerbar in golf games)

#### 3. How Outcomes are Calculated
The final effectiveness is the product of the **QTE Skill Multiplier** and the **Stat Delta Result**.

**QTE Skill Multiplier:**
* **Total Success (All beats hit):** **1.25x** (Critical - provides a reward beyond the stat-line).
* **Major Success (High completion):** **1.0x** (Standard - the action performs as advertised).
* **Minor Success (Low completion):** **0.75x** (Glancing - the action is dampened).
* **Failure (0 hits):** **0.25x** (Whiff - the absolute minimum impact).

**The Stat Delta**
The Stat Delta acts as the Dynamic Baseline. It scales based on the ratio of the **attacker's attribute** (the ability's chosen attribute + any matching weapon `attack_bonus`) to the **target's defense stat** (PhysDef or ArcDef, selected by the ability's damage type tag — see Damage Types & Defense).
- At Parity (1:1): Delta = 1.0x.
- At Advantage (2:1): Delta = 2.0x (Hard Cap).
- At Disadvantage (1:2): Delta = 0.5x (Hard Floor).


**The Final Formula:**
`Final Effect = (Base Power * Stat Delta) * QTE Multiplier`

**Examples of the Interplay:**
* **Skill compensates for Stats:** 100% QTE Success (1.25x) + Weak Stats (0.5x delta) = **0.625x** effectiveness (A "Perfect" hit makes a weak attack viable).
* **Stats compensate for Skill:** 0% QTE Success (0.25x) + Overpowering Stats (2.0x delta) = **0.5x** effectiveness (The creature is so strong it still hurts even when you mess up).
* **The Sweet Spot:** 100% QTE Success (1.25x) + Strong Stats (2.0x delta) = **2.5x** effectiveness (This is how players "melt" bosses).

**Design intent:** The stat delta sets the baseline potential (the "Floor" and "Ceiling"), while player execution determines exactly where the result lands. This ensures that skilled players can "punch up" against stronger foes, while less mechanically-inclined players can rely on superior party builds and stat growth to overcome challenges.

### Enemy AI & QTE Resolution
- Enemy NPCs act autonomously — no player input during enemy turns
- Each enemy has a hidden **QTE Resolution stat** that governs how effectively they auto-resolve their own attacks
- **Grunt-tier enemies** have a low resolution rate — they land hits at low effectiveness, making them feel manageable
- **Elite and boss-tier enemies** have a high resolution rate — they hit reliably at or near maximum effectiveness, making them feel dangerous
- This creates natural difficulty scaling without relying solely on inflated enemy stat numbers

---

## Non-Combat Events

### Presentation
- Streamlined — combat is the core; events provide context, trajectory, and resources
- Exact format TBD, but will prioritize speed and clarity

### Event Categories
1. **Shopping / Vendors** — buy gear, consumables, services
2. **Story Beats** — narrative moments that may offer recruitment, lore, or main threat progression
3. **Environmental / Mechanical** — interact with the world (e.g. "you find a chest, do you…")

### Event Interactions
- Party composition can matter — who you have with you may open or close choices
- Background provides a starting ability; certain backgrounds may occasionally gate choices or branch event outcomes (see Character Structure above)

---

## Map & Traversal

### Structure
- **Spiderweb node map** — branching and interconnected, not strictly linear (reference: Gordian Quest's first map)
- Procedurally generated each run
- Player can **freely traverse** between connected nodes, including backtracking to previously visited ones
- **One city node** exists on the map — the only location where party composition can be changed, the bulletin board accessed, and faction interactions occur

### Node Visibility
- Players can see a node's **name and general type** before visiting
- Specific contents are **unknown until arrival** (unless a skill or ability provides advance intel)

### Time Pressure & Threat Escalation
- Every node visited **incrementally empowers the final boss**
- Creates a constant strategic tension: preparation vs. urgency
- Players must decide when they are strong enough to stop preparing and face the threat

---

## Narrative Summary
*Lore is background context — this is not a story-driven game.*

- A **benevolent/neutral deity** does not want the world destroyed by the existential threat
- The deity **reincarnates the player** upon death into the body of a **host** — an adult already living in the world
- This explains why the player character has a class, background, and skills despite being freshly reincarnated — they inhabit a body with its own history
- The player is the **divine agent** acting on the deity's behalf, though the day-to-day work is mundane conflict, not divine mission
- **World structure:** 1 city and 3 factions — deliberately small to keep scope manageable and deepen each relationship rather than spread thin

---

## World State & Factions

### Structure
- **1 city** — the hub of civilization; always present as a node on the map
- **3 factions** — each with distinct goals, aesthetics, and attitudes toward the player; detail TBD

### Faction Reputation
- Each faction tracks a **reputation score** with the player: Hostile / Neutral / Allied (or a numeric range behind the scenes)
- Reputation shifts based on run actions — who you fight for, who you fight against, quests completed, NPCs recruited or killed
- Reputation carries forward between runs as part of meta-progression
- Example consequences: a faction destroyed last run may be fearful and weakened this run; one aided may offer better prices or exclusive recruits

### The City Bulletin Board
- A persistent **bulletin board** in the city surfaces consequences from past runs as short world-event entries
- Each entry is a flavor line paired with a mechanical effect for the current run
- Examples:
  - *"The Hollow Claw Bandits were wiped out last season — bandit encounter frequency reduced this run"*
  - *"Word has spread of a fearless warrior — one faction begins this run at Cautious instead of Neutral"*
- Entries are generated from **milestone flags** set during previous runs — no complex city simulation required
- Creates a genuine sense of living world history with minimal implementation overhead

---

## Meta-Progression

### Philosophy
- No permanent **stat advantages** carry between runs — every run is skill-balanced
- Progression is **content-based**: more options, more variety, a more alive world — not a stronger character
- Runs feel different and expand over time without becoming easier by default

### What Persists
- **Faction reputation scores** — carry forward and shift the starting state of each run
- **Bulletin board flags** — milestone events from past runs surface as world consequences
- **Unlocked classes and backgrounds** — available at character creation in future runs
- **Unlocked unit types** — new recruitable NPCs become available in the world

### Where It Happens
- Meta-progression is integrated into the **run start / character creation screen** — not a separate hub

### How Unlocks Are Triggered
- Completing runs (win or lose)
- Hitting specific milestones (e.g. first dragon recruited, first boss defeated)
- Discovering things in the world for the first time
- All unlock paths are valid — different playstyles unlock different content

---

## Art Style & Medium

### Overall Aesthetic
- **Tone:** Whimsical and stylized — not dark/gritty, not realistic
- **Presentation:** Hybrid 2D/3D — the game reads as 2D to the player but uses 3D production where it aids scalability
- **Engine:** Godot
- **Key differentiator:** Visually distinct from Slay the Spire (dark painted 2D) and Into the Breach (flat pixel mech aesthetic)

### Per-Surface Breakdown
- **Characters (portraits + combat icons):** Built in Blender, rendered as static 2D images. The 3D pipeline allows new recruits to be re-posed and re-rendered rather than redrawn — critical for scaling a large roster with one artist.
- **Combat maps & backgrounds:** 3D in Godot, allowing flexible lighting and camera control suited to grid-based combat
- **Node map:** 2D illustrated — treated as a stylized UI surface
- **Event vignettes:** 2D illustrated scenes — these don't need to scale like characters so hand-drawn works here
- **Action effects & QTE overlay:** 2D particles and effects in Godot; QTE prompts are a clean minimal UI overlay that does not obscure the combat grid

### Production Notes
- One artist currently skilled in pixel art and learning Blender
- Scalability is the primary constraint driving medium choices — character variety is large, so per-character effort must stay manageable
- Pixel art remains an option for specific UI elements or stylistic accents if needed

---

## Key Design Pillars
1. **Strategic Depth** — Every combat decision matters; tight grid, limited party slots, meaningful positioning
2. **Party as Expression** — Who you recruit, how you build them, and how they synergize is the core creative outlet
3. **Meaningful Runs** — Each run feels like a chapter; death is narrative, not just mechanical
4. **Mundane + Epic** — The world feels lived-in; the cosmic threat looms but doesn't dominate every moment
5. **Tension of Time** — Exploration is rewarding but costly; the clock is always ticking
6. **Skill Matters** — QTEs ensure player execution is always relevant; a skilled player outperforms their build, a less skilled player leans on stronger builds

---

## Open / TBD
- Exact format of non-combat event presentation
- Specifics of meta-progression unlocks between runs
- Specific action designs, Energy costs, and balance numbers
- QTE system overhaul planned — four mechanical styles are designed (Slide for Harm/Mend, Force for Displacement, Directional for Buff/Debuff, Hold for Travel; see Combat section above) but full visual design, interaction feel, and prompt polish are subject to redesign
- Energy stat names and exact regeneration formula
- Faction names, aesthetics, and goal details
- Consumable and Accessory schemas (weapon and armor schemas settled)
- Exact `effects` modifier vocabulary (stat names, supported modifier types) for gear

---

*This document covers structural and high-level design only. It is not a spec for specific values, abilities, damage numbers, or narrative scripts.*