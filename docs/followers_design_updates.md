# Followers — Design Updates (staging for main-file revisions)

> Staging doc for later application to `GAME_BIBLE_roguefinder.md`, `CLAUDE.md`, and any related design docs. Captured during a design brainstorm session. Apply in a future session once the full design is settled — do **not** code against this doc yet.

---

## Terminology

- **"Recruits" → "Followers"** throughout all docs.
- Noun: *follower* — an NPC party member the player has obtained.
- Verb: *recruit / obtain* — the action of adding a follower to the party/bench. "Recruit" still works as a verb even though the noun is now "follower."
- The player character is referred to as the **Pathfinder**.

---

## Follower Model

- Followers are **archetypes**, not unique individuals — same data shape as enemy NPCs (Bandit, Blood Sorcerer, Griffin, Dragon are templates).
- When obtained, a follower is permanently locked to the archetype you obtained them as — no respec of species/class after the fact.
- The player **renames** the follower on acquisition and drives their build from that point onward (level-ups, gear, ability pool choices).
- Bible wording "unique named entities with their own visuals, background, and class" should be softened: *uniqueness is player-authored through naming, leveling, and gear — not pre-baked into distinct individuals.*

---

## Acquisition Channels

All four channels are live; **combat capture is the primary channel**.

1. **Combat capture** (main) — Pathfinder-only, mid-combat action.
2. **Events** — story beats may offer a follower as an outcome.
3. **City bulletin / hired** — planned pickups at the city hub.
4. **Faction rewards** — allied factions offer exclusive followers.

---

## Combat Capture — Design So Far

- **Who can initiate:** only the Pathfinder (the PC). Followers cannot recruit other enemies.
- **Recruit is a Pathfinder ability, NOT a class ability.** It's an identity-level action tied to *being the divine agent*, not to the player's chosen combat class. This means the mechanic is uniform across every PC regardless of class/build — no class-specific variants, no attribute-gated tiers. Consistency is deliberate: the rest of the game is already dense, and recruit needs to read the same way every run.
- **Action cost:** consumes the Pathfinder's ability-slot action for that turn (replaces a normal ability use).
- **Frequency limit:** **none** — the Pathfinder may attempt recruitment any turn they're willing to spend the action on it. Each attempt costs that turn's ability slot + Energy, which is already a significant opportunity cost (giving up ~33% of the team's action economy that round). There is no per-combat lockout.
- **Emergent tactical layer:** because allies are fully player-controlled, the player can *set up* a recruit — chip the target down with ally abilities while keeping them alive, then attempt. Missing once doesn't restart the setup. The corresponding risk is the player accidentally killing the recruit target with an ally's attack, which is a real tactical discipline requirement, not a design flaw.
- **Resolution style:** hybrid of random-roll-with-modifiers (Pokemon-style) and a **new dedicated recruit QTE**. The modifiers set an underlying base chance; the QTE acts as a skill multiplier on that chance; one final roll decides success.
- **Combine math (mirrors existing combat QTE shape):** `Final Chance = Base Chance × QTE Multiplier`, where:
  - **Base Chance** is derived from modifiers (see below).
  - **QTE Multiplier** follows the same bucket shape as combat QTEs — flawless ≈ 1.25×, great ≈ 1.0×, okay ≈ 0.75×, whiff ≈ 0.25× (exact numbers TBD in balancing).
  - One final roll resolves against the computed chance.
- **Modifiers to Base Chance:**
  - **Target HP %** — lower HP = higher base chance (primary driver).
  - **Party Willpower (sum across active 3)** — higher = small positive bump.
  - **Enemy Willpower (sum across active enemies)** — higher = small negative bump.
  - WIL is deliberately a **light-touch input** — it's currently under-utilized in combat, so this gives it a reason to exist without rebalancing the entire stat sheet.
- **No new attribute.** Charisma-style stat scrapped; WIL absorbs the thematic role.
- **Why this shape:** matches the bible's existing QTE math voice (`Base × QTE Multiplier × Stat Delta`), so players fluent in combat resolution read it instantly. Both QTE skill and strategic setup (weakening the target, party comp) visibly matter.

### QTE Style (recruit-specific)

- **Hold-and-release / vertical bar** above the target enemy's head.
- The bar rises upward from a base; player holds an input and releases at the right moment to land within the success window.
- **Why this style:**
  - Visually distinct from the defender slider (horizontal vs vertical).
  - Spatially attached to the recruit target — the player always knows where to look.
  - Easiest of the bible's QTE families to implement and read.
  - Plenty of difficulty-curve runway: tighten the success window, speed up the rise, narrow the band — all simple knobs to tune.
  - Reuses the bible's existing **Hold (Travel)** style template; no fifth QTE family invented.
- **Modifier integration:** target HP and party/enemy WIL delta adjust the size of the success window and/or the bar's rise speed. Lower target HP and higher party WIL = wider window, slower rise. The QTE's outcome bucket (flawless / great / okay / whiff) maps to the standard QTE multiplier (~1.25× / 1.0× / 0.75× / 0.25×).
- Subject to change after playtest; this is the starting style.

### Range & Targeting

- **Fixed range: 3 tiles, line-of-sight required.** Same rule for every Pathfinder, every class, every build.
- Target must be visible (no recruiting through walls or blocking terrain).
- Chosen over adjacent-only because an "adjacent-only" rule would implicitly force the Pathfinder into tanky/melee builds to avoid the counterattack cost — which narrows build variety in a game that's supposed to support unconventional archetypes (battlemages, hybrid builds, etc.).
- Chosen over class-tied range because uneven class builds (a COG-primary character built for STR damage, for example) would create confusing edge cases. Flat range keeps the mechanic legible across every possible PC.

### Odds Visibility

- Players see **qualitative buckets**, not exact percentages: *Very Low / Low / Moderate / High / Very High*.
- Thresholds are set behind the scenes based on the computed base chance.
- Fits the game's grounded-fantasy tone ("the bandit looks shaken" over "42.3% chance") and gives actionable strategic info without flattening every attempt into numerical optimization.
- **Not a mystery** — the player should always be able to tell whether conditions favor the attempt. Hidden/diegetic-only was rejected.

### Context: QTE Reactive Overhaul

An in-flight overhaul is removing QTEs from the default attack flow — QTEs are becoming **reactive-only** (defender gets a slider when hit by enemy Harm abilities). The recruit QTE is additive to this trimmed system but lives in a different category:

- It is **rare** (at most once per combat).
- It is **player-initiated**, not reactive.
- It is **Pathfinder-only**, not a universal action.
- Its visual/mechanical style should be **distinct** from the defender slider so it reads as its own thing rather than a stapled-on slider variant.

### Customization at Recruit Time

- **Rename only.** That's the entirety of the recruit-time interview. No portrait pick, no background pick, no starting feat pick.
- All ongoing build authorship (ability pool slotting, gear, future level-ups) happens through the **existing PartySheet UI** — no new recruit-time flow to design.
- Recruitment stays snappy; the game is already dense, recruit doesn't need its own mini character-creation.

### Level Matching (corollary)

- New followers join at **party level** (bible rule: all party members share level).
- **Prior-level feats auto-fill** from the archetype's canonical feat pool — no recruit-time feat interview.
- Player can swap/rearrange feats after the fact via the existing PartySheet ability/feat UI if they want to repurpose the follower.

### Failure Outcome (combat capture)

- **No extra counterplay.** A missed attempt costs what it already costs: the Pathfinder's action slot for that turn, the Energy spent, and a round of fight the team didn't shorten.
- Enemy turn proceeds as normal after the player's turn ends — no out-of-turn reprisal, no morale debuff, no WIL penalty.
- The tension of recruiting lives in the *decision to attempt*, not in the punishment for missing. Players should feel free to attempt when the odds feel right, not gate attempts behind 80%+ certainty.

### Success Outcome (combat capture)

- On success, the **recruited enemy leaves combat immediately** — narratively, they've switched sides and step out of the fight. Remaining battle continues at a reduced enemy count (e.g. 3v2), which becomes a natural tactical bonus for landing a recruit.
- After combat ends, the new follower **appears on the bench**, not in the active party.
- **Active-party composition does not change mid-run** from combat recruits — players swap at the next city visit.
- The bible's "NPCs joining while exploring can immediately join, sending one active to city" language is scoped to **non-combat channels** (events, story beats). Combat captures funnel to bench only.

#### Bridging the "wait-for-city" gap

The design intent is not to lock the bench down permanently. Future channels will let players pull followers off the bench while away from the city — for example:

- **Event-driven swaps** — certain events may offer to bring a benched follower into the active party on the spot.
- **High-cost extraction** — a premium option (large gold cost, boss-timer time hit, or reputation cost) to call a benched follower to your location.

These exist as relief valves so combat recruiting still feels rewarding in the short term, without eroding the city-as-strategic-checkpoint rule for routine party changes.

---

### Recruitable Scope

- **Universal — every enemy in the roster is recruitable.** This includes grunts, elites, mini-bosses, and **boss-tier enemies**.
- **Tier scales base chance.** Grunts have generous base chance; elites are much harder; bosses are dramatically harder.
- **Boss-tier recruits carry compounding risk.** Boss fights are already deadly — spending the Pathfinder's action on a long-shot recruit attempt in a fight where every turn matters is a significant additional risk. The reward (adding a boss-tier unit to your bench) scales with that risk.
- **Flavor verb flexes by archetype.** Humanoids are *persuaded*, beasts are *tamed*, certain constructs/entities may be *bound* or have unique flavor — but the mechanic underneath is one system.
- **Open consideration (flag only, not decided):** whether the final existential threat is a carve-out exclusion. Recruiting the final cosmic antagonist would reshape the run's narrative endpoint (potential alternate win condition?) — worth revisiting once the endgame loop is designed.

---

## Bench & Roster Capacity

- **Active party: 3 slots** (unchanged — includes the Pathfinder).
- **Bench: 9 slots** (separate from active).
- **Total roster capacity: 12 followers** per run.
- This is a **starting value, not a hard settle** — expect to tune 9 up or down after playtesting. What's committed is that the bench is *limited*, not unlimited; the exact number is a tuning variable.
- Once the bench is full, new recruits force a **release-or-replace decision** — the player must drop an existing follower to make room. Exact release UX (sell / retire / walk-off) is TBD.
- Bench is **accessed at the city** by default. The relief-valve channels (events, high-cost extraction) noted earlier are the only other ways to reach followers mid-run.

---

## Non-Combat Acquisition Channels — Shape

Each non-combat channel has its **own distinct feel**, not a reskin of the combat QTE. Combat capture is the game's one skill-driven recruit moment; other channels express recruitment through different verbs (narrative, economic, political).

### Events

- Story beats present a follower as a potential outcome (e.g. "a traveler asks to join your camp", "a freed prisoner offers their sword").
- No QTE, no roll — if the event offers a follower and the player accepts, the follower is added.
- May have **prerequisites** — party composition, kindred in party, faction standing, etc. — that gate whether the offer appears in the first place.
- Some event recruits may be **immediate joiners** (the bible's "send one active to city" carve-out lives here). Others may go to bench by default. Exact split per-event.

### City (bulletin / hiring)

- The city hub offers a **rotating listing** of archetypes available for hire.
- Recruits are purchased with **gold**. Slot count on the listing is limited; list refreshes on some cadence (between city visits, or on faction/world events).
- No skill component — it's a strategic/economic decision.

### Faction

- Allied factions (reputation at the highest tier) **unlock exclusive archetypes** that cannot be obtained via any other channel.
- Unlocks are delivered through one of the other channels (e.g. the exclusive archetype appears on the city hire list once you're Allied, or arrives via a faction-flavored event). Not a separate UI/flow.
- This honors the bible's "exclusive recruits" language and ties recruitment into the existing faction reputation system.

---

## Cost Structure Across Channels

- **Combat:** Pathfinder's turn action + **medium Energy** (not low; not high). High enough that a recruit attempt isn't a casual default move. Low enough that it remains pickable at the end of a long fight when Energy is depleted. Exact number is tuning.
- **Events:** cost is per-event — gold, item, faction rep, party-member-as-payment, etc., depending on what the event flavor implies. No uniform recruit-cost rule across events.
- **City hire:** **gold only.** Each archetype on the rotating listing has a price tag; higher tiers cost more. No reputation cost on the hire itself.
- **Faction:** **reputation only.** Reaching Allied unlocks exclusive archetypes — those archetypes then appear through one of the other channels (city hire list, event arrival, etc.). Reputation is the gate; the recipient channel still applies its own cost.

---

## Release Mechanics

- **Trigger:** when the bench is at the cap (9) and a new follower would join, the player picks an existing follower to release.
- **Outcome:** released follower **walks off forever** — gone from the run permanently.
- **Auto-deequip:** all equipped gear automatically returns to the party inventory. No manual deequip ritual.
- **No refund:** no gold or items returned for releasing the follower itself. The trade is "lose a follower to make room" — no economic side-channel.
- Future option (not for vert slice): "retire" instead of "release" — the specific follower-by-name is gone, but the archetype remains in your meta-progression unlock list. Treat as a later-stage feature.

---

## Meaningfulness — Why Recruits Don't Become a Constant Stream

The system uses **layered scarcity** rather than a single gating lever. Each layer reinforces the others:

1. **Effort to obtain.** Attempts cost real action economy (one third of the team's turn) and medium Energy. Setup matters — chip the target without killing them, and execute the QTE under pressure. Skill and tactical discipline are part of the price.
2. **Capacity-forced choice to keep.** The 9-slot bench means late in a long run, every new recruit forces a release decision. The cost is no longer just "obtaining" — it's also "what do I let go of?"
3. **Permadeath stakes.** Followers can permanently die in combat. A roster you've invested in is at constant low-grade risk, which keeps each individual valuable.
4. **Build investment.** Followers grow through level-ups, feat assignments, and gear over the run. A new recruit isn't immediately as valuable as one you've spent the run shaping.
5. **Meta-progression unlocks.** New archetypes become recruitable across runs (per the bible). The roster pool itself grows over time, so what feels "rare" shifts run-by-run.

No single one of these is the answer — together they prevent recruitment from feeling like a vending machine.
