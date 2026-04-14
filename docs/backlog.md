# RogueFinder — Backlog

> Ordered by priority within each stage. Items move to "Done" when merged to main.

---

## Stage 1.5 — 3D Combat Prototype (Current)

### Immediate
- [ ] Open project in Godot, assign UIDs, run first playtest
- [ ] Document playtest failures → create bug tickets below

### Known Deferred
- [ ] Grid size tuning (currently 6×4 — may adjust post-playtest)
- [ ] Balance numbers (HP, ATK, DEF placeholders — TBD after playtest)
- [ ] QTE variety (sliding bar only — more types TBD for Stage 2)

---

## Stage 2 — Scope TBD

> Design gate: complete Stage 1.5 playtest first.

Candidates (from GAME_BIBLE):
- [ ] Node map / traversal system
- [ ] Recruitment system
- [ ] Enemy variety (elite tier, unique abilities)
- [ ] GameState wired to combat outcomes
- [ ] Persistent party across encounters

---

## Done

- [x] Stage 1 — 2D combat prototype (6×4 grid, click-to-move, 3v3, QTE, HUD, tests)
- [x] Stage 1.5 — 3D refactor (CameraController, Unit3D, Grid3D, CombatManager3D)
