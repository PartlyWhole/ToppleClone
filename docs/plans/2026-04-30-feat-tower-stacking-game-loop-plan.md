---
title: "feat: Add tower stacking game loop with HUD, camera, HP, timer, and scoring"
type: feat
status: completed
date: 2026-04-30
deepened: 2026-04-30
---

# feat: Add Tower Stacking Game Loop

## Enhancement Summary

**Deepened on:** 2026-04-30
**Review agents used:** Architecture, Timing, Performance, Resource Safety, GDScript Quality, Pattern Recognition, Code Simplicity, Best Practices Research, SpecFlow Analysis

### Key Improvements
1. **Simplified from 13 new files to 3** — merged TowerTracker, BlockSpawner, FinishLine, and BasePlatform into GameManager and GameplayController; collapsed 6 HUD scripts into 1
2. **Fixed critical camera+drag bug** — existing `_integrate_forces()` clamps to viewport rect, which breaks when Camera2D scrolls; must clamp to world-space bounds
3. **Added block freeze/unfreeze lifecycle** — settled blocks freeze to eliminate physics overhead; essential for mobile performance with 30-60 blocks
4. **Fixed 3 HIGH timing issues** — settlement bounce false positives, queue_free dangling references, restart cleanup race condition

### New Considerations Discovered
- DraggableBlock drag clamping will break immediately when Camera2D is added (viewport rect vs world coordinates)
- Dual HP ownership between GameManager and GameState creates drift risk — GameManager is sole owner
- `_unhandled_input()` runs on ALL blocks (60+ dispatch per input event) — disable by default, enable only on dragged block
- Timer signal should emit only on whole-second change, not every frame
- `_integrate_forces()` runs on all blocks including settled ones — freeze after sustained sleep

---

## Overview

Transform the current block physics testing ground into a complete tower stacking game. The player stacks blocks on a base platform to reach a target height within a time limit. Blocks spawn one at a time near the top of the camera view. The camera tracks the tower's growth. Falling blocks cost HP (4 total). A polished HUD shows score, timer, HP, and a visible finish line.

## Problem Statement / Motivation

The project has a solid physics foundation — draggable rigid-body blocks with 9 shapes, collision, and rotation. But there's no game: no win/lose conditions, no progression, no feedback. The Events bus and GameState autoload already define signals and state for a game loop (`game_started`, `game_over`, `block_placed`, `block_dropped`, `score_changed`) but nothing emits them. This feature wires everything together into a playable game.

## Proposed Solution

### Architecture (Simplified)

Three new files, plus modifications to existing files:

1. **`game_manager.gd`** — state machine, HP, timer, height scanning, drop detection, block spawning (~150 lines)
2. **`game_camera.gd`** — Camera2D that tracks upward (~30 lines)
3. **`game_hud.gd`** — single script on CanvasLayer, owns all `@onready` refs to child labels/panels (~80 lines)

```
Main (Node2D)
  +-- GameplayController (Node2D)
  |     +-- BlockContainer (Node2D) — all spawned blocks live here
  |     +-- Walls (Node2D) — side walls only, extended tall
  |     +-- GameCamera (Camera2D)
  |     +-- GameManager (Node) — state machine, timer, HP, spawning, tracking
  +-- GameHUD (CanvasLayer) — all UI (sibling of gameplay, not child)
```

#### Research Insight: Why 3 files, not 13

The code simplicity review found that the original 13-file decomposition created more coordination cost than clarity benefit. TowerTracker and BlockSpawner are each ~20 lines of logic whose sole consumer is GameManager. Five HUD child scripts each do one line of work (`text = str(score)`). BasePlatform is a rectangle with a getter. Merging these into 3 files eliminates ~345 LOC of signal wiring, reference management, and initialization ordering.

**Extraction trigger:** If GameManager exceeds ~200 lines or any concern (spawning, tracking) develops independent state/behavior (queue, preview, difficulty curves), extract it then.

### Game State Machine

```
MENU → (ui_play_pressed) → PLAYING → (height >= target) → WON
                                   → (hp <= 0)          → LOST
                                   → (timer <= 0)       → LOST
WON/LOST → (ui_restart_pressed) → RESTARTING → (cleanup done) → MENU
```

States as enum in `GameManager`:
- `MENU` — show start button, blocks/timer frozen
- `PLAYING` — timer ticking, spawning active, input enabled
- `WON` — show win screen, freeze physics
- `LOST` — show game-over screen, freeze physics
- `RESTARTING` — transient state during cleanup (guards against signal races)

#### Research Insight: RESTARTING state

The timing review found that freeing blocks during restart can trigger `block_dropped` signals that decrement HP on the fresh game. A transient RESTARTING state that blocks all gameplay signal handlers prevents this. The sequence is: (1) set state to RESTARTING, (2) free all blocks, (3) `await get_tree().process_frame`, (4) reset state, (5) transition to MENU.

## Technical Approach

### Phase 1: Foundation — Platform, Walls, Camera, Block Fixes

**Goal:** Add base platform inline, refactor walls, add Camera2D, fix DraggableBlock camera-compatibility bugs.

#### 1a. Base Platform (inline in GameplayController)

Create the platform using the existing `_add_wall()` pattern — no separate scene or script needed. Store the surface Y as a constant.

```gdscript
const PLATFORM_SURFACE_Y: float = 1180.0
const PLATFORM_WIDTH: float = 600.0
const PLATFORM_HEIGHT: float = 40.0

func _create_platform() -> void:
    _add_wall(
        Vector2(VIEWPORT_SIZE.x / 2.0, PLATFORM_SURFACE_Y + PLATFORM_HEIGHT / 2.0),
        Vector2(PLATFORM_WIDTH, PLATFORM_HEIGHT)
    )
```

#### 1b. Walls — Extend Vertically

Modify `gameplay_controller.gd`:
- Remove ceiling wall (blocks need open sky)
- Remove floor wall (replaced by platform)
- Extend side walls from `y = 2000` (well below platform) to `y = -5000` (well above any reachable height)
- Keep `WALL_THICKNESS = 20.0`, positioned at x=0 and x=720

#### 1c. BlockContainer

Add a `BlockContainer: Node2D` child of GameplayController. All spawned blocks are added here. GameManager scans `_block_container.get_children()` for height/drop detection. This avoids reaching upward into parent's children.

#### 1d. Camera2D

`features/gameplay/scripts/game_camera.gd` — `extends Camera2D`

```gdscript
class_name GameCamera
extends Camera2D

@export var smooth_speed: float = 3.0
@export var look_ahead: float = 200.0

var _target_y: float = 0.0
var _initial_y: float = 0.0

func _ready() -> void:
    assert(smooth_speed > 0.0, "smooth_speed must be positive")
    assert(look_ahead >= 0.0, "look_ahead must be non-negative")
    set_process(false)
    var viewport_height: float = get_viewport_rect().size.y
    _initial_y = viewport_height / 2.0
    _target_y = _initial_y
    position = Vector2(get_viewport_rect().size.x / 2.0, _initial_y)
    enabled = true

func _process(delta: float) -> void:
    var goal_y: float = _target_y - look_ahead
    goal_y = minf(goal_y, _initial_y)
    position.y = lerpf(position.y, goal_y, smooth_speed * delta)

func update_target(tower_top_y: float) -> void:
    _target_y = minf(_target_y, tower_top_y)

func get_target_y() -> float:
    return _target_y

func reset() -> void:
    _target_y = _initial_y
    position.y = _initial_y
```

#### Research Insights: Camera

- **Manual lerp > position_smoothing_enabled** for this case. Camera2D's built-in smoothing follows the node's position, but we need the camera to track an external target (tower top) with monotonic-upward constraint. Manual lerp gives that control.
- Camera exposes `get_target_y()` so the spawner can read the *target* position (not the interpolated mid-lerp position) for stable spawn placement.
- `set_process(false)` in `_ready()` — enabled by GameManager when entering PLAYING. Complies with default-OFF convention.

#### 1e. Fix DraggableBlock Camera Compatibility (CRITICAL)

**Bug found by architecture review:** `_integrate_forces()` at `draggable_block.gd:79-81` clamps drag position using `get_viewport_rect().size`. Once Camera2D scrolls, the visible area shifts in world space but `get_viewport_rect()` stays fixed at 720x1280. Blocks will clamp to wrong coordinates.

**Fix:** Clamp to world-space wall bounds instead of viewport rect:

```gdscript
# In _integrate_forces, replace viewport clamping with world-space clamping
const WORLD_MIN_X: float = 20.0   # wall thickness
const WORLD_MAX_X: float = 700.0  # 720 - wall thickness
# Y clamping: no upper limit (tower grows up), lower limit at platform
```

#### 1f. DraggableBlock Performance Fixes

**From performance review — apply during Phase 1:**

1. **Disable `_unhandled_input()` by default.** Currently all 60+ blocks receive every input event. Enable only on the dragged block:

```gdscript
func _ready() -> void:
    set_process_unhandled_input(false)
    # ... existing code ...

func _start_drag() -> void:
    set_process_unhandled_input(true)

func _stop_drag() -> void:
    set_process_unhandled_input(false)
```

2. **Freeze settled blocks.** Track consecutive sleep frames, freeze after ~1 second of sustained sleep. Unfreeze when a neighboring block is disturbed:

```gdscript
var _sleep_frames: int = 0
const FREEZE_AFTER_FRAMES: int = 60

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
    if not _is_dragging:
        if sleeping:
            _sleep_frames += 1
            if _sleep_frames >= FREEZE_AFTER_FRAMES:
                freeze = true
                return
        else:
            _sleep_frames = 0
    # ... existing velocity clamping ...
```

3. **Toggle contact_monitor only during drag.** Set `contact_monitor = false` when not dragging to reduce physics overhead:

```gdscript
func _start_drag() -> void:
    contact_monitor = true
    # ...

func _stop_drag() -> void:
    contact_monitor = false
    # ...
```

4. **Add public accessor for bounding size** (TowerTracker needs it, `_bounding_size` is private):

```gdscript
func get_bounding_size() -> Vector2:
    return _bounding_size
```

**Files:**
- `features/gameplay/scripts/game_camera.gd` (new)
- `features/gameplay/scripts/gameplay_controller.gd` (refactor walls, add platform, add BlockContainer)
- `features/gameplay/gameplay_controller.tscn` (add Camera2D, BlockContainer nodes)
- `features/blocks/scripts/draggable_block.gd` (fix clamping, add freeze lifecycle, add accessor, toggle input/contact_monitor)

---

### Phase 2: GameManager — State Machine, Spawning, Tracking

`features/gameplay/scripts/game_manager.gd` — `extends Node`

GameManager is the single "brain" that owns the game loop. It combines what was originally 3 separate nodes (GameManager + BlockSpawner + TowerTracker) because they are tightly coupled and each is only ~20 lines of logic.

```gdscript
class_name GameManager
extends Node

enum State { MENU, PLAYING, WON, LOST, RESTARTING }

const MAX_HP: int = 4
const ROUND_TIME: float = 60.0
const TARGET_HEIGHT: float = 600.0
const DROP_THRESHOLD_Y: float = 300.0
const SETTLE_VELOCITY: float = 10.0
const SETTLE_DURATION: float = 1.5
const HEIGHT_SCAN_INTERVAL: float = 0.5

var _state: State = State.MENU
var _hp: int = MAX_HP
var _time_remaining: float = ROUND_TIME
var _current_block: DraggableBlock = null
var _scan_timer: float = 0.0
var _last_displayed_seconds: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
```

#### Spawning Logic (merged from BlockSpawner)

- `_spawn_block()`: creates `DraggableBlock.new()`, random shape/color, positions near camera top using `_camera.get_target_y()` (not interpolated position)
- Block starts `freeze = true` (hovering)
- Connects to block's `drag_started` → on first drag: unfreeze, restore gravity, call `_spawn_block()` for next
- Uses `CONNECT_ONE_SHOT` flag to auto-disconnect after first drag, preventing re-drag spawning

```gdscript
func _spawn_block() -> void:
    if _state != State.PLAYING:
        return
    var all_names: Array[StringName] = BlockShapes.get_all_names()
    if all_names.is_empty():
        push_error("No shapes loaded")
        return
    var block: DraggableBlock = DraggableBlock.new()
    block.shape_type = all_names[_rng.randi() % all_names.size()]
    var bounds: Vector2 = BlockShapes.get_bounding_size(block.shape_type)
    var margin: float = maxf(bounds.x, bounds.y) / 2.0 + 50.0
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    block.position = Vector2(
        _rng.randf_range(margin, viewport_size.x - margin),
        _camera.get_target_y() - viewport_size.y / 2.0 + 100.0,
    )
    block.block_color = BLOCK_COLORS[_rng.randi() % BLOCK_COLORS.size()]
    block.freeze = true
    block.gravity_scale = 0.0
    block.drag_started.connect(_on_new_block_dragged.bind(block), CONNECT_ONE_SHOT)
    _current_block = block
    _block_container.add_child(block)
```

#### Height Scanning & Drop Detection (merged from TowerTracker)

Every `HEIGHT_SCAN_INTERVAL` seconds during PLAYING:
- Iterate `_block_container.get_children()` typed as DraggableBlock
- Find highest block top: `block.position.y - block.get_bounding_size().y / 2.0`
- Detect dropped blocks: `block.position.y > PLATFORM_SURFACE_Y + DROP_THRESHOLD_Y`
- Update camera, score, check win condition

```gdscript
func _scan_tower() -> void:
    var highest_y: float = PLATFORM_SURFACE_Y
    for child: Node in _block_container.get_children():
        if not (child is DraggableBlock):
            continue
        var block: DraggableBlock = child as DraggableBlock
        if not is_instance_valid(block):
            continue
        # Drop detection
        if block.position.y > PLATFORM_SURFACE_Y + DROP_THRESHOLD_Y:
            if block == _current_block:
                _current_block = null
            Events.block_dropped.emit(block)
            block.queue_free()
            _hp -= 1
            Events.hp_changed.emit(_hp)
            if _hp <= 0:
                _transition_to(State.LOST)
                return
            continue
        # Height tracking
        var top_y: float = block.position.y - block.get_bounding_size().y / 2.0
        highest_y = minf(highest_y, top_y)
    var tower_height: float = PLATFORM_SURFACE_Y - highest_y
    if tower_height > 0.0:
        _camera.update_target(highest_y)
        var height_int: int = int(tower_height)
        Events.score_changed.emit(height_int)
        GameState.current_height = tower_height
        if tower_height >= TARGET_HEIGHT:
            _transition_to(State.WON)
```

#### Research Insight: Settlement Detection

The timing review found that a 0.5s scan interval can produce false positives when a block is momentarily stationary at bounce apex. For MVP, we skip per-block settlement detection entirely — height scanning every 0.5s and position-based drop detection are sufficient. The `block_placed` signal can be emitted based on sustained low velocity if needed later, but the acceptance criteria only require height tracking and drop detection.

#### Research Insight: State Transition Guards

All signal handlers guard with `if _state != State.PLAYING: return` to prevent:
- HP decrement below 0 when multiple blocks drop simultaneously
- Timer ticking during WON/LOST
- Block spawning during game-over

#### Timer

```gdscript
func _process(delta: float) -> void:
    if _state != State.PLAYING:
        return
    # Timer
    _time_remaining -= delta
    var display_seconds: int = ceili(_time_remaining)
    if display_seconds != _last_displayed_seconds:
        _last_displayed_seconds = display_seconds
        Events.timer_updated.emit(_time_remaining)
    if _time_remaining <= 0.0:
        _time_remaining = 0.0
        _transition_to(State.LOST)
        return
    # Height scan
    _scan_timer += delta
    if _scan_timer >= HEIGHT_SCAN_INTERVAL:
        _scan_timer = 0.0
        _scan_tower()
```

#### Research Insight: Timer Signal Frequency

The performance review flagged that emitting `timer_updated` every frame (60 Hz) is wasteful when the HUD label only changes once per second. Emit only when the displayed whole-second value changes.

#### Restart Flow

```gdscript
func _restart() -> void:
    _transition_to(State.RESTARTING)
    for child: Node in _block_container.get_children():
        child.queue_free()
    await get_tree().process_frame
    _hp = MAX_HP
    _time_remaining = ROUND_TIME
    _last_displayed_seconds = -1
    _current_block = null
    _camera.reset()
    Events.game_restarted.emit()
    _transition_to(State.MENU)
```

#### Research Insight: Restart Cleanup Race

The timing review found that `queue_free()` defers to end-of-frame, so signals from dying blocks can fire after state reset. The `await get_tree().process_frame` ensures all freed nodes are actually removed before gameplay resumes. The RESTARTING state blocks all gameplay handlers during this window.

**New Events signals needed:**

```gdscript
# Add to Events.gd
signal hp_changed(new_hp: int)
signal timer_updated(time_remaining: float)
signal game_ended(is_win: bool, final_height: float)
```

#### Research Insight: One signal, not two

Use `game_ended(is_win: bool, final_height: float)` instead of separate `game_over` + `game_won`. The only consumer (GameHUD) does the same thing for both — show a panel. The only difference is the title text.

**GameState changes:**
- Remove `current_score: int` (height IS the score, use `current_height` directly)
- Keep `high_score`, `current_height`, `is_playing`
- GameManager sets `GameState.is_playing` on state transitions (single source of truth)
- GameState listens to `game_ended` instead of `game_over`

**Files:**
- `features/gameplay/scripts/game_manager.gd` (new)
- `autoload/Events.gd` (add new signals)
- `autoload/GameState.gd` (adjust for game_ended, remove current_score)

---

### Phase 3: HUD Design

`features/hud/` — one script, one scene.

#### HUD Layout (720x1280 viewport)

```
┌──────────────────────────────┐
│  ♥ ♥ ♥ ♥          00:45     │  ← Top bar: HP hearts + Timer
│                              │
│                              │
│         [Height: 342]        │  ← Score, centered, semi-transparent
│                              │
│  ─ ─ ─ ─ GOAL ─ ─ ─ ─ ─    │  ← Dashed line at target height (world space)
│                              │
│                              │
│                              │
│                              │
│       [  ▶ START  ]         │  ← Start button (MENU state only)
│                              │
│                              │
└──────────────────────────────┘
```

#### Single HUD Script

`features/hud/scripts/game_hud.gd` — `extends CanvasLayer`

One script owns all `@onready` references and listens to Events signals. No child scripts.

```gdscript
class_name GameHUD
extends CanvasLayer

@onready var _heart_labels: Array[Label] = [$TopBar/Heart1, $TopBar/Heart2, $TopBar/Heart3, $TopBar/Heart4]
@onready var _timer_label: Label = $TopBar/TimerLabel
@onready var _score_label: Label = $ScoreLabel
@onready var _start_button: Button = $StartButton
@onready var _game_over_panel: PanelContainer = $GameOverPanel
@onready var _result_label: Label = $GameOverPanel/VBox/ResultLabel
@onready var _final_score_label: Label = $GameOverPanel/VBox/FinalScoreLabel
@onready var _high_score_label: Label = $GameOverPanel/VBox/HighScoreLabel
@onready var _restart_button: Button = $GameOverPanel/VBox/RestartButton

func _ready() -> void:
    assert(_timer_label != null, "TimerLabel not found")
    assert(_score_label != null, "ScoreLabel not found")
    assert(_start_button != null, "StartButton not found")
    assert(_game_over_panel != null, "GameOverPanel not found")
    # ... assert all onready vars ...
    _start_button.pressed.connect(func() -> void: Events.ui_play_pressed.emit())
    _restart_button.pressed.connect(func() -> void: Events.ui_restart_pressed.emit())
    Events.hp_changed.connect(_on_hp_changed)
    Events.timer_updated.connect(_on_timer_updated)
    Events.score_changed.connect(_on_score_changed)
    Events.game_started.connect(_on_game_started)
    Events.game_ended.connect(_on_game_ended)
    Events.game_restarted.connect(_on_game_restarted)
    _show_menu()

func _on_hp_changed(new_hp: int) -> void:
    for i: int in range(_heart_labels.size()):
        _heart_labels[i].modulate = Color.RED if i < new_hp else Color.DIM_GRAY

func _on_timer_updated(time_remaining: float) -> void:
    var seconds: int = ceili(time_remaining)
    _timer_label.text = "%02d:%02d" % [seconds / 60, seconds % 60]
    _timer_label.modulate = Color.RED if seconds <= 10 else Color.WHITE

func _on_score_changed(height: int) -> void:
    _score_label.text = str(height)

func _on_game_ended(is_win: bool, final_height: float) -> void:
    _result_label.text = "YOU WIN!" if is_win else "GAME OVER"
    _final_score_label.text = "Height: %d" % int(final_height)
    _high_score_label.text = "Best: %d" % GameState.high_score
    _game_over_panel.visible = true
    _start_button.visible = false
```

#### HUD Visual Design

**Color palette** — dark, semi-transparent backgrounds for readability:
- Top bar background: `StyleBoxFlat` with `bg_color = Color(0, 0, 0, 0.3)`, corner radius 0
- Score: white, `36px` font size, with `LabelSettings` shadow (offset 2,2, black)
- Timer: monospace-style, white `28px`, turns red below 10s
- Hearts: red `♥` when full, dim gray `♥` when empty, `24px`
- Start button: large centered button, `StyleBoxFlat` with rounded corners, accent color
- Game-over panel: centered `PanelContainer`, `StyleBoxFlat` with `bg_color = Color(0, 0, 0, 0.7)`, `corner_radius = 12`

#### Finish Line (world space, drawn by GameplayController)

The finish line is a visual indicator at the target height. It is purely decorative — no script needed. Draw it in GameplayController's `_draw()`:

```gdscript
func _draw() -> void:
    var finish_y: float = PLATFORM_SURFACE_Y - GameManager.TARGET_HEIGHT
    var dash_length: float = 20.0
    var gap_length: float = 10.0
    var x: float = 0.0
    while x < VIEWPORT_SIZE.x:
        draw_line(
            Vector2(x, finish_y),
            Vector2(minf(x + dash_length, VIEWPORT_SIZE.x), finish_y),
            Color(1, 0.84, 0, 0.6), 2.0
        )
        x += dash_length + gap_length
    # "GOAL" label drawn centered
    draw_string(
        ThemeDB.fallback_font, Vector2(VIEWPORT_SIZE.x / 2.0 - 30.0, finish_y - 8.0),
        "GOAL", HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 0.84, 0, 0.8)
    )
```

**Files:**
- `features/hud/game_hud.tscn` (new — scene tree with Labels, Button, PanelContainer)
- `features/hud/scripts/game_hud.gd` (new — single script for all HUD logic)
- `features/gameplay/scripts/gameplay_controller.gd` (add `_draw()` for finish line)

---

### Phase 4: Integration & Polish

#### 4a. Wire GameplayController

Refactor `gameplay_controller.gd` to:
1. Remove `_spawn_initial_blocks()` entirely
2. Keep `_create_boundaries()` but modify: remove floor/ceiling, extend side walls
3. Add `_create_platform()` using existing `_add_wall()` pattern
4. Add BlockContainer, GameCamera, GameManager as child nodes in scene
5. Add GameHUD as sibling CanvasLayer
6. Add `_draw()` for finish line
7. Expose `PLATFORM_SURFACE_Y` as constant for GameManager

#### 4b. Block Freezing During Non-PLAYING States

GameManager handles this in state transitions:
- On entering MENU/WON/LOST: iterate `_block_container.get_children()`, set `freeze = true` and `input_pickable = false`
- On entering PLAYING: existing blocks stay frozen (they are stacked), new spawned block starts frozen and unfreezes on drag

#### 4c. DraggableBlock — Minimal Modifications

- Fix world-space clamping (Phase 1e) — CRITICAL
- Add freeze lifecycle (Phase 1f)
- Add `get_bounding_size()` public accessor
- Disable `_unhandled_input()` by default
- Toggle `contact_monitor` on drag start/stop
- No `block_id`, no `is_placed` — YAGNI
- No mobile rotation buttons for MVP — Q/E works, add touch controls when mobile testing reveals need

**Files modified:**
- `features/gameplay/scripts/gameplay_controller.gd` (major refactor)
- `features/gameplay/gameplay_controller.tscn` (add nodes)
- `features/blocks/scripts/draggable_block.gd` (fixes + accessor)
- `main/main.tscn` (add GameHUD)

---

## System-Wide Impact

### Signal Chain

```
ui_play_pressed → GameManager._on_play() → Events.game_started
  → GameState._on_game_started() [reset height, set is_playing]
  → GameHUD._on_game_started() [hide start button, show timer/score/hp]
  → GameManager._spawn_block() [first block]

block.drag_started → GameManager._on_new_block_dragged()
  → unfreeze block, restore gravity
  → GameManager._spawn_block() [next block]

_scan_tower() every 0.5s:
  → finds highest block → Events.score_changed(height)
    → GameHUD._on_score_changed() [update label]
  → updates camera target → _camera.update_target(top_y)
  → detects dropped blocks → Events.block_dropped(block)
    → block.queue_free()
    → Events.hp_changed(new_hp)
    → GameHUD._on_hp_changed() [update hearts]
  → detects win → Events.game_ended(true, height)

timer expires → Events.game_ended(false, height)
hp depleted → Events.game_ended(false, height)

game_ended → GameState._on_game_ended() [save high score]
          → GameHUD._on_game_ended() [show panel]
          → GameManager freezes all blocks

ui_restart_pressed → GameManager._restart()
  → state = RESTARTING (blocks all handlers)
  → free all blocks, await frame
  → reset state, camera
  → Events.game_restarted
  → state = MENU
```

### Error Propagation

- `BlockShapes.get_all_names()` returns empty → `push_error()` in spawner, no blocks spawn
- Camera target never updated → camera stays at initial position (safe default)
- Block `queue_free()` while it is `_current_block` → null `_current_block` first, check `is_instance_valid()` before access
- Multiple blocks drop in same scan → state guard prevents HP decrement after state leaves PLAYING

### State Lifecycle Risks

- **Partial restart:** RESTARTING state + `await process_frame` ensures all cleanup completes before new game state
- **Orphaned blocks:** Periodic full scan catches all blocks below threshold
- **Timer drift:** `_process(delta)` accumulation is standard and frame-rate-correct
- **Dual state:** GameManager is sole owner of `_hp` and `_time_remaining`. GameState only mirrors `is_playing` and `current_height` for persistence. No `current_hp` in GameState.

---

## Acceptance Criteria

### Functional Requirements

- [x] Base platform exists at the bottom of the play area
- [x] First block spawns near top of screen on game start
- [x] New block spawns when current block is first dragged
- [x] Blocks stack physically on the platform and each other
- [x] Camera smoothly tracks upward as tower grows
- [x] Camera never scrolls back down
- [x] Block falling below platform triggers HP loss
- [x] HP starts at 4, displayed as hearts in HUD
- [x] Timer counts down from 60 seconds, displayed in HUD
- [x] Timer turns red when < 10 seconds
- [x] Score equals tower height (highest block top to platform surface)
- [x] Finish line visible at target height (600px above platform)
- [x] Game ends with WIN when tower reaches finish line
- [x] Game ends with LOSS when HP reaches 0 or timer expires
- [x] Win/loss screen shows final score and high score
- [x] Restart button resets all state and returns to menu
- [x] High score persists between sessions

### Non-Functional Requirements

- [x] HUD is readable over gameplay (dark semi-transparent backgrounds)
- [x] Camera movement is smooth (lerp, no jitter)
- [x] Block spawn position uses camera target (not interpolated position)
- [x] Settled blocks freeze for mobile performance
- [x] `_unhandled_input()` disabled on non-dragged blocks
- [x] `contact_monitor` toggled on drag only
- [x] All variables, parameters, and return types are statically typed
- [x] No writes to shared Resources at runtime
- [x] Drag clamping uses world-space bounds (not viewport rect)

### Quality Gates

- [x] `gdformat --check` passes on all new files
- [x] `gdlint .` passes on all new files
- [x] Project runs without errors in headless mode
- [x] All `@export` and `@onready` vars have `assert()` in `_ready()`
- [x] `set_process(false)` called in `_ready()` for GameCamera and GameManager

---

## Risk Analysis & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Drag clamping breaks with camera | **Certain** | High | Fix in Phase 1e before adding camera |
| Block settlement false positives | Medium | Medium | Skip per-block settlement for MVP; scan positions only |
| Physics jitter at high towers | Low | Medium | Freeze settled blocks; CCD already enabled |
| HUD obscures gameplay on small screens | Medium | Medium | Minimal HUD elements; test at 360x640 |
| Cascading block falls drain all HP | Low | High | Intentional; add grace period if too harsh |
| Restart race condition | Medium | High | RESTARTING state + await process_frame |
| GameManager grows too large | Low | Medium | Extract spawner/tracker if >200 lines |

---

## Implementation Order

1. **Phase 1** — Platform, wall refactor, Camera2D, DraggableBlock fixes (~1 session)
2. **Phase 2** — GameManager: state machine, spawning, tracking, timer (~1 session)
3. **Phase 3** — GameHUD: scene + single script, finish line (~1 session)
4. **Phase 4** — Integration wiring, restart flow, polish (~0.5 session)

Each phase is independently testable. Phase 1 produces a visible result (platform + camera). Phase 2 produces a playable loop. Phase 3 adds feedback. Phase 4 polishes.

---

## New Files Summary

| File | Type | Lines (est) |
|------|------|-------------|
| `features/gameplay/scripts/game_camera.gd` | New | ~30 |
| `features/gameplay/scripts/game_manager.gd` | New | ~150 |
| `features/hud/scripts/game_hud.gd` | New | ~80 |
| `features/hud/game_hud.tscn` | New | scene |
| **Total new GDScript** | | **~260** |

| File | Type | Changes |
|------|------|---------|
| `features/gameplay/scripts/gameplay_controller.gd` | Modified | Refactor walls, add platform, add _draw(), remove old spawn |
| `features/gameplay/gameplay_controller.tscn` | Modified | Add Camera2D, BlockContainer, GameManager nodes |
| `features/blocks/scripts/draggable_block.gd` | Modified | Fix clamping, add freeze, accessor, input toggle |
| `autoload/Events.gd` | Modified | Add hp_changed, timer_updated, game_ended signals |
| `autoload/GameState.gd` | Modified | Adjust for game_ended, remove current_score |
| `main/main.tscn` | Modified | Add GameHUD CanvasLayer |

---

## Future Considerations

- Level system with increasing target heights and shorter timers
- Block preview ("next block" indicator)
- Combo scoring for rapid placements
- Particle effects on placement and block destruction
- Sound effects and music
- Mobile rotation gesture or on-screen buttons
- Difficulty curves for block shape selection
- Per-block settlement detection with `block_placed` signal
- Extract BlockSpawner/TowerTracker if GameManager exceeds ~200 lines

---

## Sources & References

### Internal References

- Events autoload: `autoload/Events.gd` — existing signal definitions
- GameState autoload: `autoload/GameState.gd` — existing state management
- Block physics: `features/blocks/scripts/draggable_block.gd` — drag/drop, signals, viewport clamping at line 79
- Shape system: `features/blocks/scripts/block_shapes.gd` — shape data access
- Current gameplay: `features/gameplay/scripts/gameplay_controller.gd` — wall creation, spawn code to replace
- Project settings: `project.godot` — viewport 720x1280, window 360x640

### Conventions

- CLAUDE.md: component pattern, signal bus discipline, resource safety, static typing, default-OFF
- Folder structure: features own their scripts/scenes, systems for cross-feature code

### Review Findings Incorporated

- Architecture review: 5 P1 coupling issues (all resolved by simplification + container node)
- Timing review: 3 HIGH issues (settlement, dangling ref, restart race — all addressed)
- Performance review: 2 HIGH issues (block freezing, contact monitoring — both addressed)
- Code simplicity review: reduced from 13 files to 3 new files
- GDScript review: asserts, default-OFF, magic numbers — all addressed
- Pattern review: dual HP ownership, viewport constants — all addressed
- Resource safety review: PASS (clean, one vestigial .tscn cleanup noted)
