All Rights Reserved. No permission is granted to download, use, or modify this software for any purpose.

# ⚖️ Project Alpha — 3D Roguelite

> A 3D action roguelite built in **Godot 4** where you play as a divine judge navigating a fractured world of warring factions.
> Every run is shaped by your choices — who you spare, which factions you favor, and which moral archetype you embody.

**Status:** Work in progress · Built with Godot 4 & GDScript

---

## 🎮 Concept

You are a divine entity passing judgment on a corrupted world. Each run generates a sequence of encounters — battles, dialogue events, moral dilemmas — across **Faction Territory**, **Contested Zones**, and **Corrupted Lands**.

Your decisions shift your character along five archetype axes: **Death · Mercy · Order · Chaos · Fear**. Factions track your actions, NPCs remember how you treated them across runs, and your path through the world changes accordingly.

---

## 🧱 Technical Architecture

This project was an opportunity to design and implement several interconnected systems from scratch. Below is a breakdown of the most significant ones.

---

### 🗺️ Procedural Run Generation (`RunManager.gd`)

Each run generates a sequence of 15 map nodes through a **weighted, constraint-based selection algorithm**:

- Maps are defined as **data resources** (`MapData.tres`) with rich metadata: zone categories, position constraints, reuse limits, cooldown between appearances, faction requirements, and emotional weight.
- The generator filters valid maps per node position and zone, then selects by weight — with tie-breaking randomization.
- Constraints enforced per map: `max_per_run`, `min_nodes_between`, faction opinion thresholds, NPC alive/dead status.

```gdscript
func _filter_maps(zone: MapData.ZoneCategory, node_index: int, used: Dictionary) -> Array[MapData]:
    for map_data in all_maps:
        if not map_data.check_zone(zone): continue
        if not map_data.can_appear_at_node(node_index): continue
        if _too_soon(map_data.map_id, node_index, used): continue
        if not map_data.meets_requirements(): continue
        valid.append(map_data)
```

This approach makes the run system **fully data-driven**: adding a new encounter requires no code changes — just a new `.tres` resource.

---

### 🤖 Enemy AI — Finite State Machine (`BaseEnemy.gd`)

Enemies use a **10-state FSM** with clean state isolation and animation-driven transitions:

```
IDLE → CHASE → WALK → WINDUP → ATTACKING → RECOVERY
                                    ↓
                              HURT → STUNNED → DOWNED → DEAD / SPARED
```

Key design decisions:
- **Animation callbacks** (`_on_windup_complete`, `_on_hitbox_start`, `_on_attack_complete`) drive state transitions — keeping AI logic decoupled from animation timings.
- **Hitbox/hurtbox collision layers** are dynamically reconfigured based on hostility, so the same NPC can function as an enemy or an ally.
- **`BaseEnemy`** is an abstract base class — child enemies override `_choose_attack()`, `_get_attack_animation()`, and `_post_ready()` to specialize behavior without duplicating shared logic.
- NavigationAgent3D handles pathfinding with a configurable `path_update_rate` to manage performance.

---

### 📊 Persistent World State (`Stats.gd` autoload)

A global autoload tracks state that **persists across runs**, making each playthrough feel consequential:

- **Archetype axes** (Death, Mercy, Order, Chaos, Fear, Love, Apathy) — advanced through gameplay choices at configurable magnitudes (`tiny` → `max`).
- **Faction opinions** per faction (scholars, warriors, knights, exiles...) — used as filter conditions during run generation.
- **NPC persistence** — named NPCs track alive/dead status, interaction history, opinion scores, and save counts across runs.
- **Run statistics** — kills, spares, deaths, completed runs, all tracked for summaries.

Faction state also tracks **trait axes per faction** (peaceful ↔ militant, isolationist ↔ open, etc.), laying groundwork for emergent faction behavior.

---

### 🗃️ Data-Driven Map System (`MapData.gd`)

`MapData` extends `Resource`, giving each encounter a rich configuration profile:

| Field | Purpose |
|---|---|
| `PrimaryCategory` | PURE_COMBAT, MULTI_FACTION_IMPACT, RESPITE_SUPPORT, SPECIAL... |
| `VictoryType` | KILL_ALL, SURVIVE_TIMER, MAKE_CHOICE, BOSS_DEFEATED... |
| `EmotionalWeight` | Influences pacing and run generation diversity |
| `MoralChoice` | Flags encounters with narrative consequences |
| `CombatIntensity` | LOW → EXTREME, used for difficulty balancing |
| `min_nodes_between` | Prevents the same encounter repeating too soon |

This design cleanly separates **game data from game logic** — a pattern that made the system easy to iterate and extend.

---

### 💬 Dialogue System

Integrated [**Nathan Hoad's Dialogue Manager**](https://github.com/nathanhoad/godot_dialogue_manager) for branching narrative:

- A custom `dialogue_module.gd` component attaches to any NPC to drive conversations.
- Dialogue lines can trigger `Stats` updates (faction opinions, archetype shifts) via callable hooks.
- A custom balloon UI (`DialogueBalloon`) renders conversations in-world.

---

### ⚙️ Other Systems

| System | Notes |
|---|---|
| **Upgrade system** (`upgrade_manager.gd`) | Run-persistent upgrades with card-based selection UI |
| **Combat module** (`combat_module.gd`) | Composable component shared across NPC types |
| **Interactables** | Fountain (healing), Mirror (3D reflection), Teleporter |
| **Visual effects** | Tween-based hit flash, floating damage numbers, weapon trail |

---

## 🛠️ Stack

- **Engine:** Godot 4
- **Language:** GDScript
- **Architecture patterns:** Finite State Machine, Component composition, Data-driven Resources, Autoload singletons
- **Addons:** Dialogue Manager, Mirror3D

---

## 👤 About the Developer

3rd-year Computer Engineering student — this project is one of several I use to practice **software design principles** (separation of concerns, inheritance vs. composition, data/logic decoupling) in a context that actually demands them: a real, running system with many interacting parts.

📬 [youssefgaddes3@gmail.com](mailto:youssefgaddes3@gmail.com) 
