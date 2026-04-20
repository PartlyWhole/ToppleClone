# Godot Game Development — Agentic Workflow Reference

A reusable guide for building Godot 4 games with Claude Code, the Godot
Compound plugin, MCP servers, and a documentation-first methodology.
Extracted from PirateShipGame and RootsGame.

---

## Table of Contents

1. [Toolchain](#toolchain)
2. [Project Bootstrap Checklist](#project-bootstrap-checklist)
3. [Development Loop](#development-loop)
4. [Godot Compound Plugin](#godot-compound-plugin)
5. [CLAUDE.md Conventions (Template)](#claudemd-conventions)
6. [compound-engineering.local.md (Template)](#compound-engineeringlocalmd)
7. [Documentation System](#documentation-system)
8. [Architecture Decision Records](#architecture-decision-records)
9. [Reusable ADR Patterns](#reusable-adr-patterns)
10. [Testing Strategy](#testing-strategy)
11. [Linting & Formatting](#linting--formatting)
12. [MCP Integration](#mcp-integration)
13. [CI/CD — GitHub Pages Web Export](#cicd--github-pages-web-export)
14. [Git Conventions](#git-conventions)

---

## Toolchain

| Tool | Purpose | Config Location |
|------|---------|-----------------|
| **Claude Code** | AI coding assistant (CLI / VS Code / web) | `CLAUDE.md` at project root |
| **Godot Compound** (`/gc:`) | Multi-agent review, planning, brainstorming | `~/.claude/godot-compound/`, `compound-engineering.local.md` at project root |
| **Context7 MCP** | Live Godot API / library docs | `.mcp.json` at project root |
| **Godot MCP** | Run/stop project, get debug output, scene ops | Built-in or `.mcp.json` |
| **GUT** | Unit testing framework | Vendored at `addons/gut/` |
| **gdtoolkit** | Linting (`gdlint`) + formatting (`gdformat`) | `gdlintrc` at project root |

---

## Project Bootstrap Checklist

New Godot + Claude Code project setup:

1. **Create Godot project** with target settings (viewport, stretch, renderer)
2. **Create `CLAUDE.md`** at project root (see template below)
3. **Create `compound-engineering.local.md`** at project root (see template below)
4. **Create `.mcp.json`** with Context7 (and optionally Godot MCP)
5. **Create `gdlintrc`** at project root
6. **Create folder structure:**
   ```
   addons/         — vendored third-party (GUT) + first-party EditorPlugins
   assets/         — shared textures, fonts (cross-feature)
   autoload/       — Event bus, GameState, AudioManager, etc.
   docs/
     architecture/ — onboarding tour (written after structure stabilizes)
     brainstorms/  — exploratory pre-decision docs
     decisions/    — ADRs (frozen at decision time)
     plans/        — dated execution plans with retros
     solutions/    — engine quirk troubleshooting records
   features/       — feature folders (each owns scripts, scenes, resources,
                     textures, shaders)
   main/           — main.tscn + main.gd
   systems/        — cross-feature RefCounted helpers and service Nodes
   tests/unit/     — GUT unit tests
   ```
7. **Vendor GUT** into `addons/gut/`
8. **Register autoloads** in `project.godot` (Events first, then others)
9. **Set up `.github/workflows/deploy-pages.yml`** if deploying to web
10. **Create `export_presets.cfg`** excluding `addons/gut/*`, `tests/*`

---

## Development Loop

### Phase 1: Brainstorm

Write an exploratory document evaluating multiple approaches before
committing to one. The user explicitly picks the approach.

**Template:** `docs/brainstorms/YYYY-MM-DD-<topic>-brainstorm.md`

Structure:
- Problem statement / pain points
- Strengths to preserve from current code
- Approach A (minimal), B (moderate), C (maximalist)
- Trade-offs table
- Scope cuts to consider
- User decision: which approach?

### Phase 2: Plan

Detailed step-by-step execution plan, reviewed by Godot Compound agents.

**Template:** `docs/plans/YYYY-MM-DD-<topic>-plan.md`

Structure:
- Enhancement summary (updated after each review round)
- Critical fixes discovered during review
- Scope cuts accepted by user
- Phase breakdown with numbered steps
- Pre-flight TODOs per phase
- Research deltas (discoveries from agent review)

**Agent review pipeline:** Use `/gc:plan` which dispatches the plan to
parallel review agents (architecture, timing, style, performance,
simplicity, resource safety, pattern recognition, export verification).

### Phase 3: Execute

Atomic commits. Game must be playable after every step.

Rules:
- Each step = one commit (or a small logical group)
- If a step breaks gameplay, split it
- Run linting before each commit
- Run tests after each phase
- Use Godot MCP for visual smoke tests (`run_project` → `get_debug_output` → `stop_project`)

### Phase 4: Retro

Append an execution retro to the plan document after each phase lands.

Structure:
- What actually happened vs what was planned
- Carry-overs to next phase
- Deviations discovered
- Lessons learned
- Hot-fixes applied

---

## Godot Compound Plugin

### What It Is

A fork of the Compound Engineering (`/ce:`) plugin, specialized for
Godot 4 + GDScript. Provides agents, skills, and commands under the
`/gc:` namespace.

### Installation

See the handoff doc: `docs/archive/handoffs/2026-03-19-godot-compound-plugin-install.md`
in the RootsGame repo, or follow:

1. Plugin source lives at `~/.claude/godot-compound/`
2. Marketplace wrapper at `~/.claude/godot-compound-marketplace/`
3. Register in Claude Code settings

### Commands

| Command | Purpose |
|---------|---------|
| `/gc:plan` | Create or review an execution plan with multi-agent review |
| `/gc:work` | Execute work with compound loop |
| `/gc:review` | Code review with Godot-specific agents |
| `/gc:compound` | General compound engineering loop |
| `/gc:brainstorm` | Structured brainstorm with Godot context |

### Review Agents

| Agent | What It Checks |
|-------|----------------|
| `gc-gdscript-lint` | GDScript formatting, naming, member ordering |
| `gc-gdscript-reviewer` | Code quality, static typing, style guide |
| `gc-godot-architecture-reviewer` | Composition, signal flow, scene structure |
| `gc-resource-safety-reviewer` | Resource mutation, shared state, hot-reload |
| `gc-code-simplicity-reviewer` | Unnecessary complexity, premature abstraction |
| `gc-godot-performance-reviewer` | _process overhead, untyped vars, deep inheritance |
| `gc-godot-timing-reviewer` | _ready() order, signal timing, deferred calls |
| `gc-godot-export-verifier` | Export presets, excluded files, web compatibility |

### Agent Dispatch

Controlled by `compound-engineering.local.md` at the project root.
This file specifies which agents run for code review vs plan review,
plus project-specific domain rules.

**Do NOT run `/gc:setup`** — manually maintain `compound-engineering.local.md`.

---

## CLAUDE.md Conventions

The `CLAUDE.md` at the project root is the single source of truth for
all coding conventions. Every Claude Code session reads it first.

### What Goes in CLAUDE.md (Generic Godot)

1. **Language & Engine** — Godot version, renderer, GDScript only
2. **Display Settings** — viewport size, window size, stretch mode, texture filter
3. **Folder Structure** — canonical tree with inclusion criteria
4. **GDScript Conventions:**
   - Static typing mandatory (all vars, params, return types)
   - Explicit casts after `is` checks (GDScript doesn't narrow)
   - Component pattern (Node subclasses, signal-up, default-OFF)
   - Member ordering (signals → enums → constants → exports → vars → _ready → _process → public → private)
   - Assertions on every `@export var` and `@onready var` in `_ready()`
   - `StringName` for enum-like string fields
   - `distance_squared_to` over `distance_to` for threshold comparisons
   - Avoid shadowing built-in names in signal parameters
5. **Resource Safety Doctrine:**
   - Resources are read-only templates; runtime state in Node vars
   - No writes to `@export` Resource fields (transitive)
   - `set_shader_parameter` on shared Material = write (duplicate or document)
   - No Curve/Gradient mutations at runtime
   - No `preload()` defaults on `@export var` Resource slots
   - Component .tscn files: no embedded mutable sub-resources (use ExtResources)
6. **Signal Bus Discipline:**
   - Only entity roots and service nodes publish to the Events bus
   - Components emit signals upward to entity root
   - Listener-owns-the-work (no proxy listeners for single receivers)
   - Typed payloads only (no untyped Dictionary)
   - Autoload init order matters (Events first)
7. **Scene File Safety:**
   - Properties only, no structural changes to .tscn files
   - Never add/remove `[ext_resource]`, `[sub_resource]`, `[node]`, `[connection]` entries
   - Never edit base64 data or uid values
8. **Shader Conventions** — snake_case files, PascalCase uniforms, filter hints
9. **Linting** — gdformat + gdlint commands, exclusions, two-step preload pattern
10. **Testing** — GUT setup, headless run command, test conventions
11. **MCP & Documentation** — Context7 for API lookups, Godot MCP for smoke tests

### What Does NOT Go in CLAUDE.md

- Game-specific design (what enemies do, how waves work)
- Temporary state or current-sprint goals
- Anything that belongs in an ADR or plan

### See Also

Full CLAUDE.md templates are provided as separate files:
- `docs/templates/CLAUDE.md.template` — copy and customize per project

---

## compound-engineering.local.md

This file at the project root controls Godot Compound agent dispatch.

### Template

```yaml
---
review_agents: [gc-gdscript-lint, gc-gdscript-reviewer, gc-godot-architecture-reviewer, gc-resource-safety-reviewer, gc-code-simplicity-reviewer]
plan_review_agents: [gc-code-simplicity-reviewer]
---
```

```markdown
# Review Context

This is a **Godot 4.x + GDScript <genre>** (<ProjectName>). All reviews
must apply Godot-specific patterns.

## Domain Rules

- **Architecture:** Composition over inheritance. "Call down, signal up."
  Scene inheritance limited to one layer. Event Bus for cross-system
  signals only.
- **Code quality:** Static typing mandatory. Member ordering follows
  GDScript style guide. Signals named in past tense. Booleans prefixed
  with `is_`/`can_`/`has_`.
- **Resource safety:** Flag any raw `mv`/`git mv` on resource files.
  Flag `.tres` loads without `.duplicate()` in mutable contexts. Flag
  dynamic `load()` with string concatenation.
- **Scene safety:** `.tscn` files must NOT be structurally edited by
  agents. Read and report only. Property changes are OK.
- **Performance:** Flag `_process` callbacks that could be replaced by
  signals. Flag untyped variables. Flag deep inheritance (>1 layer).
```

Customize the "Review Context" section per project (genre, specific
architectural choices, additional domain rules).

---

## Documentation System

### Document Types and When to Write Them

| Type | When | Lives In | Lifecycle |
|------|------|----------|-----------|
| **Brainstorm** | Before choosing an approach | `docs/brainstorms/` | Written once, never updated |
| **Plan** | After approach is chosen, before execution | `docs/plans/` | Updated with execution retros |
| **ADR** | When an architectural decision is made | `docs/decisions/` | Frozen (supersede, don't edit) |
| **Solution** | When you hit an engine quirk | `docs/solutions/` | Updated if engine version changes |
| **Architecture Tour** | After structure stabilizes | `docs/architecture/` | Updated after structural refactors |
| **VERIFY.md** | After major refactors | `docs/architecture/` | Rerun after each structural change |

### File Naming

- Brainstorms: `YYYY-MM-DD-<topic>-brainstorm.md`
- Plans: `YYYY-MM-DD-<topic>-plan.md` or `YYYY-MM-DD-feat-<name>-plan.md`
- ADRs: `NNN-<slug>.md` (sequential numbering)
- Solutions: `<engine>-<problem-slug>.md`

### Architecture Tour Conventions

- Link, don't duplicate — every claim has a `[file.gd](path)` link
- Use function-name anchors, not line numbers (more durable)
- Add `<!-- verified against commit <sha> on <date> -->` stamps
- Include Mermaid diagrams (state machines, sequence diagrams, flowcharts)
- Provide a reading order in the README

### VERIFY.md Checklist

A one-screen manual recheck list for post-refactor validation. Sections:
- Scene tree + wiring
- Autoloads
- Entity + components
- Signal paths (pick a critical path, walk it end-to-end)
- Resources
- ADR compliance
- Tests pass
- Export + deploy

---

## Architecture Decision Records

### When to Write an ADR

Write one when you make a decision that:
- Constrains future code (e.g., "components must signal-up")
- Has alternatives you considered and rejected
- Would surprise a new contributor ("why is it this way?")

### ADR Template

```markdown
## ADR NNN: <Title> — <Subtitle>

**Date:** YYYY-MM-DD
**Status:** Accepted | Superseded by NNN
**Related:** [ADR NNN](NNN-slug.md)

## Context

<What problem prompted this decision? What was the pre-decision state?>

## Decision

<Numbered sub-decisions with code examples and rationale>

## Consequences

**Positive:**
- <Benefit with specific evidence>

**Negative:**
- <Cost with mitigation>

## Alternatives Considered

**<Alternative name>.** <Why rejected.>
```

---

## Reusable ADR Patterns

These architectural patterns are generic to any Godot 4 + GDScript game.
Each was battle-tested across PirateShipGame and RootsGame.

### 1. Component Decomposition (ADR 005 pattern)

- Components are `Node` subclasses, one behavior each
- Exception: `extends Node2D` when children need the 2D transform chain
- Signal-up to entity root; never reach sideways to siblings
- Default-OFF: `set_physics_process(false)` + `set_process(false)` in `_ready()`
- Entity root is a thin dispatcher (~100 LOC), not a god object
- Shared behavior via `@export` parameterization, not subclassing

### 2. Events Bus Discipline (ADR 007 pattern)

- Global `Events` autoload with typed signals
- Only entity roots and service nodes publish
- Components emit upward; entity root re-emits to bus
- Listener-owns-the-work: single-receiver signals get no proxy
- Publisher owns tuning lookup; listener is dumb
- High-frequency signals OK (measure, don't assume)
- Autoload init order: Events first

### 3. Resources as Read-Only Templates (ADR 009 pattern)

- Resources are read-only; runtime state in Node `var`s
- No writes to `@export` Resource fields (transitive)
- Hot-reload granularity: per-frame re-readers update live, cached values don't
- `.duplicate()` only when code genuinely mutates (legacy pattern)
- No `preload()` defaults on `@export var` slots
- No embedded mutable sub-resources in .tscn files

### 4. Feature-Folder Structure (ADR 010 pattern)

- `features/<name>/` owns everything for that feature
- `systems/` for cross-feature helpers (if it would live in 2+ feature folders)
- Components live with their host entity, not by class role
- `.uid` sidecar moves with the script in the same commit
- Delete a feature = delete one folder

### 5. Flat-Enum FSM (ADR 006 pattern)

- One `enum State { ... }` with explicit transitions
- One `_set_state()` private method
- Public transition methods (`enter_dashing()`, `enter_dead()`)
- Replaces multi-flag "state soup" (`_is_dead`, `_input_locked`, etc.)

---

## Testing Strategy

### Unit Tests (GUT)

Vendor GUT at `addons/gut/`. Tests live under `tests/unit/`.

**Headless run:**
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

**Conventions:**
- `extends GutTest`
- `const FooClass: GDScript = preload("res://...")` (not `class_name` auto-lookup)
- `add_child_autofree(node)` for tests needing a SceneTree
- `watch_signals(obj)` + `assert_signal_emitted(obj, name)` for signal coverage
- Test Resource sharing behavior to verify ADR 009 compliance

**What to test:**
- RefCounted helpers (Cooldown, RunStats)
- Components in isolation (HealthComponent, WaveConfig)
- Resource identity / sharing invariants
- FSM state transitions

**What to smoke-test via MCP:**
- Visual systems (water, VFX, particles)
- Scene wiring (does main.tscn load without errors?)
- Export builds

### Visual / Integration Smoke Tests

```
run_project → get_debug_output → stop_project
```

Check for zero errors in debug output. Validate `.tres`/`.tscn` files
when changed.

**Pre-merge:** Open the Godot editor GUI at least once before a final
smoke run to refresh the UID-by-text-path map (MCP doesn't trigger
Godot's UID rescan).

---

## Linting & Formatting

### Setup

```bash
pipx install "gdtoolkit==4.*"
```

### gdlintrc (project root)

```
excluded_directories: !!set
  .git: null
  addons: null
```

### Commands

```bash
# formatting (skip addons/)
find . -name "*.gd" -not -path "./addons/*" -not -path "./.git/*" \
  -not -path "./.godot/*" -print0 \
  | xargs -0 gdformat --check

# style (gdlintrc handles excludes)
gdlint .
```

Run both before committing. Fix gdformat issues by re-running without
`--check`.

### Long Preload Paths

When an inline `preload()` exceeds the line-length limit, use the
two-step pattern:

```gdscript
const _MAT_PATH: String = "res://features/water/shaders/displacement_stamp_material.tres"
const BASE_MATERIAL: ShaderMaterial = preload(_MAT_PATH)
```

---

## MCP Integration

### .mcp.json (project root)

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"],
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    }
  }
}
```

**Context7:** Use automatically for Godot API lookups. Call
`resolve-library-id` then `query-docs`.

**Godot MCP:** Provides `run_project`, `stop_project`,
`get_debug_output`, `create_scene`, `add_node`, `save_scene`,
`get_project_info`, etc. Use for smoke testing and scene operations.

---

## CI/CD — GitHub Pages Web Export

### `.github/workflows/deploy-pages.yml`

Key steps:
1. Checkout code
2. Setup Godot via `chickensoft-games/setup-godot@v2`
3. Download + install export templates (not bundled with setup-godot)
4. Cache `.godot` import folder (keyed on `.tscn`, `.tres`, `.gd`, `project.godot`)
5. Import project headless (`godot --headless --import || true`)
6. Export Web build
7. Touch `.nojekyll` (prevents Jekyll stripping underscore-prefixed files)
8. Upload + deploy to GitHub Pages

### Export Presets

Exclude test/dev files from release builds:

```ini
exclude_filter="addons/gut/*, tests/*, addons/pirate_dev_tools/*"
```

---

## Git Conventions

### Commit Messages

```
type(domain): brief description
```

Types: `feat`, `fix`, `refactor`, `docs`, `chore`, `ci`, `test`

For phased work, append phase tracking:
```
refactor(ship): extract HealthComponent from ship.gd — Phase 3 step 2/8
```

### Branch Strategy

- Feature branches for multi-phase work
- Atomic commits (game playable after each)
- No force-push; clean history
- Merge to main when phase is complete + tests pass

### Commit Discipline

- Each step in a plan = one commit (or small logical group)
- Run linting before every commit
- Run tests after each phase
- `.uid` sidecar files move with their script in the same commit

---

## Memory Strategy

All project context lives in **git-tracked markdown**, not Claude Code
session memory:

| What | Where |
|------|-------|
| Coding conventions | `CLAUDE.md` |
| Architectural decisions | `docs/decisions/` (ADRs) |
| Execution history | `docs/plans/` (with retros) |
| Design alternatives | `docs/brainstorms/` |
| Engine quirks | `docs/solutions/` |
| Current architecture | `docs/architecture/` |

This means any new Claude Code session picks up full context by reading
the docs. No dependency on ephemeral session state.

Claude Code memory files (`~/.claude/projects/<path>/memory/`) are
optional — useful for user preferences and feedback, but architectural
knowledge belongs in the repo.
