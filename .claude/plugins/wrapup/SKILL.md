---
name: wrapup
description: RogueFinder end-of-session wrap-up. Use whenever the user says "wrap up", "close out", "finish the session", "wrap", "done for today", "ship it", or invokes /wrapup. Handles all git merge work AND a thorough, exhaustive update of every relevant map directory file. Nothing should be missed. Always invoke this skill for session closeout — do not do wrap-up work without it.
---

# RogueFinder Session Wrap-Up

Two goals: (1) land all code on main, (2) leave the documentation in a state where a future session can pick up with full context.

---

## Step 1 — Land the code

### 1a. Assess git state
```bash
git status
git log --oneline -10
git branch
```
Understand: what branch are you on, are there uncommitted changes, is the branch already pushed?

### 1b. Commit anything uncommitted
If there are staged or unstaged changes, commit them with an appropriate summary message before proceeding. Don't leave work stranded.

### 1c. Push the feature branch
```bash
git push origin <current-branch>
```

### 1d. Merge to main
Calling this skill is the user's explicit approval to merge. Follow the CLAUDE.md workflow exactly:
```bash
git checkout main
git merge <feature-branch> --no-ff -m "Merge branch '<feature-branch>'"
git push origin main
```
If main is already up to date (work was done directly on main, or already merged), skip the merge and note it.

---

## Step 2 — Rebuild the documentation

This is the most important part. The map files are the memory of the project. A future session that reads stale docs will make wrong assumptions. Be exhaustive — if it changed, document it.

### 2a. Gather the full session diff
```bash
git log main --oneline -15
git diff HEAD~<N> HEAD --name-only
git diff HEAD~<N> HEAD -- <each changed .gd file>
```
Read the actual diff for every `.gd` file that changed this session. Don't rely on memory or summaries — read the code.

### 2b. Map changed files to map documents

| Changed file | Relevant map doc(s) |
|---|---|
| `scripts/combat/CombatManager3D.gd` | `combat_manager.md`, possibly `map.md` |
| `scripts/combat/Grid3D.gd` | `grid_system.md`, possibly `map.md` |
| `scripts/combat/Unit3D.gd` | `unit_system.md`, possibly `map.md` |
| `scripts/combat/QTEBar.gd` | `qte_system.md` |
| `scripts/camera/CameraController.gd` | `camera_system.md` |
| `scripts/ui/*.gd` | `hud_system.md`, possibly `map.md` |
| `scripts/globals/*.gd` | `combatant_data.md` or `hud_system.md`, possibly `map.md` |
| `resources/*.gd` | `combatant_data.md`, possibly `map.md` |
| `scripts/globals/GameState.gd` | `game_state.md` |
| Any new system | `map.md` (add to index + summaries + file tree) |

`map.md` always gets updated — at minimum the session log row and `sessions_since_groom` counter.

### 2c. Update each relevant map file

For every doc that needs changes, read the current source file first, then update the doc. Go section by section:

**Signals** — Add new signals. Update changed signatures. Remove deleted signals. Be exact about arg types.

**Public methods / API tables** — Every public method that was added, changed, or removed must be reflected. Descriptions should say what the method actually does now, not what it did before.

**Key internal methods** — Update descriptions for any method whose behavior changed. Add rows for new internal methods that are non-trivial or that future sessions might need to know about.

**Dependencies table** — If a system now depends on a new system (or no longer depends on one), update it.

**Key patterns & gotchas** — Add a bullet for any new non-obvious behavior, invariant, or trap discovered this session. This is where "don't do X because Y" lives.

**Recent changes table** — Add one or more rows:
```
| YYYY-MM-DD | Short description of what changed |
```
Be specific. "Added EndCombatScreen wiring" is better than "UI updates". Multiple rows are fine if the session touched several distinct areas.

**For `map.md` specifically:**
- System Index: add any new systems with status and layer
- Dependency graph: add new edges (e.g., `CombatManager3D → EndCombatScreen`)
- System Summaries section: add a paragraph for any new system
- File Locations tree: add any new files
- Session Log: add today's date and a summary
- `sessions_since_groom`: increment by 1

### 2d. Quality bar

Before finishing, re-read each doc you updated and ask:
- Could a developer who wasn't in this session understand what changed and why?
- Are there any method signatures, signal names, or behaviors that are now out of date?
- Does the dependency graph reflect what the code actually imports/calls?

If the answer to any of these is no, fix it before committing.

---

## Step 3 — Commit the documentation

```bash
git add docs/
git commit -m "docs: session wrap-up $(date +%Y-%m-%d)"
git push origin main
```

---

## Step 4 — Report to the user

Tell the user:
- Which branch was merged (or that main was already up to date)
- Which map files were updated and a one-line summary of what changed in each
- The final git log (last 5 commits) so they can see the clean state

Keep it tight — a bullet list is fine.
