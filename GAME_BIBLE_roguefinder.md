# GAME BIBLE
*High-level design overview — structural reference only*

## Working Title
**Roguefinder** *(name subject to change)*
The concept originated as a **roguelite adaptation of Pathfinder 2e (PF2e)** — borrowing its action economy, mechanical depth, and fantasy tone and translating them into a roguelite structure with a creature-collector party system.

---

## Genre & Platform
- **Genre:** Tactical Turn-Based RPG Roguelite / Creature Collector
- **Platform:** PC
- **Key References:** Into the Breach (grid combat), Slay the Spire (roguelite structure), Gordian Quest (node map), Pokémon (creature collector/party framing), XCOM (escalating threat pressure)

---

## Core Fantasy
The player takes on the role of a **divine agent** — a mortal character chosen by a deity — who leads a mixed party of humanoids and creatures through a dangerous, conflict-ridden fantasy world. The player is both a participant in combat and the strategic director of their party. Think: you are the trainer, but you also fight alongside your party.

---

## Setting & Tone
- **World:** Medieval fantasy
- **Tone:** Grounded and mundane at the surface, with an underlying current of cosmic stakes
- **Central Threat:** An existential evil entity that threatens to destroy the world — present and challengeable from the start of each run, but confronted on the player's terms
- **Day-to-Day Reality:** Most of the player's time is spent dealing with ordinary worldly conflicts — local disputes, faction skirmishes, survival challenges — not the final threat

---

## Core Gameplay Loop
**Traverse map → Encounter (fight / recruit / interact) → Adjust party build → Repeat**

- The player moves through a procedurally generated node map
- Encounters include combat, recruitment opportunities, vendors, story beats, and environmental interactions
- Between encounters the player manages party composition, gear, and strategy
- The run ends when the player chooses to face the existential threat — or loses a combat

---

## Run Structure
- Runs are **open-ended** with a **player-determined endpoint**
- The final boss is accessible from the start but the player decides when they're ready
- Progress through the run involves completing **randomly generated mundane quests and missions**
- **Time pressure:** The longer the player takes, the more powerful the final threat becomes (XCOM-style escalation) — every node visited costs time, creating a tension between preparation and urgency
- A full run = explore and grow → decide you're ready → face the final threat

---

## Death & Progression (Roguelite Loop)
- **Permadeath** applies to the player character within a run
- On death, the player is **reincarnated by the deity** and returned to the world at a point in time after their previous run — narratively justifying the reset
- **Meta-progression** exists: certain upgrades, unlocks, or knowledge persist between runs
- This is a **roguelite**, not a roguelike — each run builds on the last in meaningful ways

---

## The Party — Creature Collector Framework
The NPC party system is the heart of the game. Think of it like Pokémon: your recruited units are your "pokemon," and building, combining, and managing them is the primary creative expression of the game.

### Recruitment
- NPCs are **recruited through diplomacy/coercion or caught** in the world
- Party members are unique named entities with their own visuals, background, class, and equipment
- Examples of recruitable types: Bandit, Blood Sorcerer, Griffin, Dragon
- Each NPC can be renamed by the player

### Party Size & Management
- Players maintain a **bench** of recruited members
- Max **3 units in combat** at a time (including the player character)
- **Party composition can only be changed at the city** — not before individual encounters
- This makes city visits meaningful strategic checkpoints, not just shops
- Mid-run, the player must commit to their active 3 until they return to the city

### Party Synergies
- Synergies between party members are a **core build consideration**
- Party composition — not just individual unit strength — defines the build

---

## Build System

### Character Structure (applies to player character and all NPCs)
Each character has:
- **A Class** — defines ability progression and role
- **A Background** — light flavor and a single starting feat/ability (DOS2-style); does not branch event outcomes or gate content
- **4 Equipment Slots:** Weapon, Armor, Consumable, Accessory
- **A Level** (max level 20)

### Leveling & Abilities
- Every **even level** → unlock a new **class action**, added to the character's available action pool
- Every **odd level** → earn a **feat** (from class or background); feats may also grant new actions
- Characters start with **1 class action** in their pool and grow their options over the run
- Actions can also be sourced from **items**, especially weapons — expanding the pool beyond class and feats
- **Feats** are dynamic stat/effect modifiers, similar to relics in Slay the Spire — they change how a character functions, not just their numbers

### Equipment
- Gear is a primary driver of power and build identity
- 4 slots per character: **Weapon, Armor, Consumable, Accessory**
- Gear interacts with class to shape a character's role

---

## Combat

### Format
- **3v3** — 3 player units vs. up to 3 enemies
- Player character is always one of the 3 active combat slots
- All 3 player units are **fully controlled by the player** — no autobattle for allies
- Primary win condition: defeat all enemies; other win condition types not ruled out

### Grid & Positioning
- Combat takes place on a **tight grid map** (Into the Breach-style)
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
3. **Active Action** — one action chosen from the character's slotted action pool (see below). Costs **Energy**.

This structure keeps turns lean and decisions focused. The interesting choice each turn is *which* Active Action to use and whether the Energy cost is worth it right now.

### Action Slots & Energy
Between combats, each character has a pool of available actions earned through leveling, feats, and items. The player slots **up to 4 actions** from this pool before entering combat — these are the options available as their Active Action each turn.

**Energy** is a per-character resource that governs Active Action use:
- Each character has a maximum Energy pool determined by a stat (TBD name)
- Energy regenerates each turn by an amount determined by a separate stat (TBD name)
- More powerful actions cost more Energy
- Managing Energy across a fight — spending aggressively vs. pacing for regeneration — is a core tactical layer

### Quick Time Events (QTEs)
Every Active Action is resolved through a **Quick Time Event**. QTEs inject real-time player skill into turn-based combat, making every action feel earned.

**How QTEs work:**
- Each action has a defined number of QTE prompts (e.g. Fireball = 5 prompts, Dual Strike = 10 prompts)
- Each prompt is a discrete skill check. Reference model: the **Gears of War reload mechanic** — a tick slides across a bar and the player must tap at the right moment to register a hit
- Prompt count and individual difficulty are tuned per action — a fast multi-hit action has more prompts that are individually easier; a slow powerful action has fewer prompts with tighter timing windows
- Prompts resolve in sequence; the action fires after all prompts complete regardless of how many the player hit

**How outcomes are calculated:**
The final effectiveness of an action is determined by two factors: **completion rate** (how many prompts the player hit) and the **Attack vs. Defense stat delta** between attacker and target.

- All prompts hit + Attack equals Defense → **1.0x effectiveness** (baseline)
- All prompts hit + Attack significantly exceeds Defense → up to **2.0x effectiveness**
- All prompts hit + Defense significantly exceeds Attack → reduced effectiveness (e.g. **0.5x**)
- Half prompts hit + Attack equals Defense → **0.5x effectiveness**
- The stat delta sets the ceiling and floor for the outcome range; player skill determines where within that range the result lands
- Even a 0% completion rate still resolves the action at minimum effectiveness — the action always fires, skill only affects how well

**Design intent:** QTEs mean player execution matters on every action, not just at the build screen. A skilled player can punch above their stat weight; a less skilled player needs stronger builds to compensate. Stats and skill are both always relevant.

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
- Background provides a starting ability but does not gate or branch event outcomes

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
- Exact grid size for combat maps
- Specific action designs, Energy costs, and balance numbers
- QTE visual design and prompt variety (how many distinct prompt types exist beyond the sliding tick)
- Energy stat names and exact regeneration formula
- Faction names, aesthetics, and goal details

---

## Prototyping Notes
*A living log of what has been tested and what remains unvalidated.*

### Validated (GMS2 Autobattler Prototype)
- Grid-based combat feel is fun and readable
- Autobattle loop is satisfying to watch
- Build engine concept (random loot, class actions) works and received positive feedback
- 3v3 combat format feels right; 4 units was manageable but 3 is preferred for turn-based

### Not Yet Validated
- Whether QTEs feel exciting rather than intrusive within turn-based combat
- Whether the Energy economy creates interesting turn-to-turn decisions
- Whether the fixed Stride + Consumable + 1 Active Action structure feels focused or too restrictive
- Whether full player control of all 3 units is too slow or feels empowering
- Whether city-only party swapping creates meaningful tension or frustration
- Whether the bulletin board successfully conveys a sense of living world history
- Whether faction reputation across runs creates genuine investment
- Whether creature collector / recruitment creates meaningful attachment
- Whether the roguelite map structure layers well onto the combat system

### Playtesting Findings
- **Terminal sim (Python):** Built and functional but not an effective playtest vehicle — tracking board state and available actions in text format is too cognitively demanding to accurately simulate combat feel
- **Recommendation:** Use in-person tabletop (dry-erase board, physical tokens) for design validation before investing in a Godot build

### Planned Next Step
- Build Stage 1 combat in Godot: real grid, Energy economy, 3-slot action structure (Stride / Consumable / Active), QTE resolution prototype, full player control of all 3 units

---

*This document covers structural and high-level design only. It is not a spec for specific values, abilities, damage numbers, or narrative scripts.*
