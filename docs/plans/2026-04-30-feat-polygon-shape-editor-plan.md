---
title: "feat: Polygon Shape Editor"
type: feat
status: active
date: 2026-04-30
origin: docs/brainstorms/2026-04-30-polygon-shape-editor-brainstorm.md
deepened: 2026-04-30
---

# feat: Polygon Shape Editor

## Enhancement Summary

**Deepened on:** 2026-04-30
**Research agents used:** 7 (framework docs, best practices, architecture, timing, performance, resource safety, pattern recognition)

### Key Improvements
1. **Scene swap changed to hide/disable** — avoids `_ready()` re-firing, physics state loss, and duplicate signal connections when returning to gameplay
2. **Editor root changed from Node2D to Node** — prevents Control-under-Node2D coordinate inheritance issues
3. **Signal-based communication specified** — editor emits `back_requested`, debug panel emits `editor_requested`, main.gd connects both
4. **Godot `is_polygon_clockwise()` Y-axis inversion documented** — in screen coordinates (Y-down), `true` means visually CCW
5. **Concrete code patterns added** for grid snapping (`snappedf`), JSON I/O, convex decomposition, input handling (`_gui_input` + `accept_event`)
6. **Resource safety: return vertex array copies** from BlockShapes to prevent shared mutable state
7. **Vestigial .tscn cleanup moved to Phase 1** — existing CollisionShape2D creates phantom collision geometry

### New Considerations Discovered
- `Geometry2D.segment_intersects_segment()` returns `null` for collinear overlapping segments — needs separate handling
- `Geometry2D.decompose_polygon_in_convex()` expects CCW winding and does not validate self-intersection — must validate before calling
- `remove_child()` causes `_ready()` to re-fire on `add_child()` — hide/disable pattern avoids this entirely
- RigidBody2D physics state (contacts, sleep, velocity) is lost on remove/re-add — another reason to hide instead

## Overview

A developer-only in-game tool for visually designing block shapes by clicking vertices on a snapping grid. Shapes save as JSON files that replace the current hardcoded shape definitions in `BlockShapes`. The editor is a separate scene accessible from the debug panel or runnable standalone.

(see brainstorm: `docs/brainstorms/2026-04-30-polygon-shape-editor-brainstorm.md`)

## Problem Statement

Block shapes are currently hardcoded as cell arrays and polygon vertices in static `match` statements inside `block_shapes.gd`. Adding or tweaking shapes requires editing GDScript, understanding coordinate math, and mentally visualizing the result. This slows down iteration and makes it hard to get shapes right (e.g., the arrow shape required 3 rounds of back-and-forth).

## Proposed Solution

A standalone shape editor scene with:
- A grid canvas where vertices snap to grid intersections (60px) and edge midpoints (30px)
- Click-to-place vertex workflow with ordered line connections
- Auto convex decomposition via Godot's built-in `Geometry2D.decompose_polygon_in_convex()`
- JSON file persistence in `features/blocks/shapes/`
- Refactored `BlockShapes.gd` that loads shapes from JSON at startup

## Technical Approach

### Architecture

```
features/blocks/editor/
├── shape_editor.gd          # Main editor scene script (extends Node)
├── shape_editor.tscn         # Minimal scene (just root + script)
├── scripts/
│   ├── editor_canvas.gd      # Grid drawing + vertex placement (extends Control)
│   ├── shape_file_io.gd      # JSON save/load (static utility, class_name ShapeFileIO)
│   └── editor_state.gd       # State machine (RefCounted, class_name EditorState)
features/blocks/shapes/        # JSON shape files (created at runtime)
```

**Scene transition:** `main.gd` hides and disables the gameplay subtree, then instances the editor. On "Back," the editor is freed and gameplay is re-shown. Autoload singletons persist. This avoids `_ready()` re-firing, physics state loss, and duplicate signal connections.

**All shapes become polygon-only after refactoring.** The grid-vs-polygon rendering duality is removed. Grid shapes (squares, bars, S-shape) are migrated to JSON as polygon outlines. The per-cell rectangle look is replaced by filled polygon rendering for all shapes. This simplifies `DraggableBlock` to a single rendering path.

### Research Insights: Architecture

**Editor root extends Node, not Node2D.** The editor is an orchestrator — it holds a Control-based canvas and UI children. Using Node2D would cause Control children to inherit a 2D transform chain, which CLAUDE.md warns against ("components whose behavior depends on the entity's 2D transform chain MUST extends Node2D" — the editor canvas does NOT need this). Extending plain Node avoids the issue entirely.

**EditorState as RefCounted is correct.** It is pure state tracking (current state, vertex list, shape name) with no need for `_process()`, `_ready()`, or tree membership. This is the first RefCounted class in the codebase — add a docstring explaining why it is not a Node.

**Communication pattern: signals up.**
- Editor emits `signal back_requested` — `main.gd` connects when instancing
- Debug panel emits `signal editor_requested` — `main.gd` connects in `_ready()`
- This follows CLAUDE.md's "call down, signal up" rule and avoids routing through the Events bus (single-receiver principle: only `main.gd` listens)

### Drawing State Machine

```
IDLE ──(click)──► DRAWING ──(close)──► CLOSED ──(save)──► IDLE
  ▲                  │                    │
  │              (undo all)           (clear/new)
  └──────────────────┘                    │
  ▲                                       │
  └───────────────────────────────────────┘

IDLE ──(select saved shape)──► PREVIEWING ──(dismiss)──► IDLE
```

**States:**
- **IDLE:** Empty canvas. Can start drawing (click) or preview a saved shape (select from list).
- **DRAWING:** 1+ vertices placed, polygon open. Can add vertices (click), undo last (right-click/Backspace/undo button), or close (click near first vertex when 3+ vertices exist, or press Enter).
- **CLOSED:** Polygon complete. Shows filled shape with outline. Can enter name and save, or clear to return to IDLE.
- **PREVIEWING:** Showing a saved shape on canvas (read-only). Can dismiss to return to IDLE, or delete the shape.

### Key Design Decisions

**1. Scene transition via hide/disable in `main.gd`**

`main.gd` hides the gameplay subtree and disables its processing, then instances the editor. On return, the editor is freed and gameplay is re-shown. This preserves the full gameplay state including physics body contacts, tower stacking, and sleep states.

```gdscript
# main.gd
const _EDITOR_PATH: String = "res://features/blocks/editor/shape_editor.tscn"
const EditorScene: PackedScene = preload(_EDITOR_PATH)

@onready var _gameplay: Node2D = $GameplayController
var _editor: Node = null

func switch_to_editor() -> void:
    _gameplay.visible = false
    _gameplay.process_mode = Node.PROCESS_MODE_DISABLED
    _editor = EditorScene.instantiate()
    _editor.back_requested.connect(switch_to_gameplay)
    add_child(_editor)

func switch_to_gameplay() -> void:
    if _editor != null:
        remove_child(_editor)
        _editor.queue_free()
        _editor = null
    _gameplay.process_mode = Node.PROCESS_MODE_INHERIT
    _gameplay.visible = true
```

**Research insight:** `remove_child()` before `queue_free()` prevents deferred calls on the editor from interacting with the live scene. The gameplay node stays in the tree throughout, so `_ready()` never re-fires, physics state is preserved, and signal connections remain intact.

**2. Coordinate space: center-relative pixels**

Vertices are stored in center-relative pixel coordinates, matching the existing `get_polygon()` contract. The editor canvas shows a grid with (0,0) at the center. On save, the centroid of all vertices is computed and subtracted so shapes are always centered.

**3. `Geometry2D.decompose_polygon_in_convex()` for decomposition**

Godot's built-in Hertel-Mehlhorn decomposition produces minimal convex pieces (not triangulation). A 10-vertex concave shape produces ~3-4 convex pieces instead of 8 triangles.

**Research insights:**
- Signature: `static decompose_polygon_in_convex(polygon: PackedVector2Array) -> Array[PackedVector2Array]`
- **Expects CCW winding** (in Godot's Y-down screen space, this means `is_polygon_clockwise()` returns `true`). Normalize before calling.
- **Does NOT validate self-intersection.** Self-intersecting input produces undefined output. Must validate before calling.
- On failure, prints `"Convex decomposing failed!"` and returns empty array. Check for empty result.

**4. Self-intersection validation on close**

When the developer attempts to close the polygon, edges are checked for intersections using `Geometry2D.segment_intersects_segment()`. If any edges cross, the polygon is rejected with a visual flash on the offending edges.

**Research insight:** `segment_intersects_segment()` returns `Variant` — a `Vector2` intersection point on success, or `null` if no intersection. **Collinear overlapping segments also return `null`** — the function cannot detect collinear overlap. For the editor, collinear edges are unlikely (vertices snap to grid) and non-harmful, so this limitation is acceptable.

**5. Winding order normalization**

**Critical gotcha from Godot docs:** `Geometry2D.is_polygon_clockwise()` assumes a Cartesian coordinate system (+Y up). In Godot's 2D screen coordinates (+Y down), **the result is inverted**:
- `is_polygon_clockwise()` returning `true` → polygon is visually **CCW** in screen space
- `is_polygon_clockwise()` returning `false` → polygon is visually **CW** in screen space

Since `decompose_polygon_in_convex()` expects CCW winding, normalize with:
```gdscript
if not Geometry2D.is_polygon_clockwise(vertices):
    vertices.reverse()
```

**6. All shapes become polygon-only**

The `is_grid_shape()` / `get_cells()` / `get_cell_centers()` / `get_perimeter()` code paths are removed. All shapes are defined by polygon vertices and rendered with `draw_colored_polygon()`. Grid shapes are migrated to equivalent polygon outlines.

**7. Shape identification by string name**

`BlockShapes.Type` enum is replaced by string-based shape names loaded from JSON filenames. `DraggableBlock.shape_type` becomes a `StringName`. `GameplayController` iterates `BlockShapes.get_all_names()` instead of `ALL_TYPES`.

**Research insight:** This loses compile-time type safety. Add runtime validation:
```gdscript
# DraggableBlock._ready()
assert(BlockShapes.has_shape(shape_type), "Unknown shape: " + shape_type)
```

**8. Canvas input handling**

The editor canvas extends `Control` and uses `_gui_input()` (not `_unhandled_input()`).

**Research insights:**
- `_gui_input()` respects Control layering — buttons/LineEdit on top of the canvas consume events first
- Call `accept_event()` after handling clicks to prevent propagation to parent Controls
- UI elements (save button, name input, shape list) must be in a separate container layered above the canvas, or on a non-overlapping region
- Use `mouse_filter = MOUSE_FILTER_STOP` (default) on the canvas to consume events within its rect

**Grid snapping pattern:**
```gdscript
const HALF_CELL: float = 30.0

func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mb: InputEventMouseButton = event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            var snapped_pos: Vector2 = mb.position.snappedf(HALF_CELL)
            _place_vertex(snapped_pos)
            accept_event()
```

### Implementation Phases

#### Phase 1: JSON Shape Infrastructure + Cleanup

Refactor `BlockShapes` and `DraggableBlock` to load shapes from JSON. Migrate existing 9 shapes to JSON files. **Clean up vestigial .tscn nodes.** Verify gameplay is identical after refactoring.

**Files:**
- `features/blocks/scripts/shape_file_io.gd` — new: JSON read/write utility
- `features/blocks/scripts/block_shapes.gd` — rewrite: load from JSON, remove enum/hardcoded data
- `features/blocks/scripts/draggable_block.gd` — modify: single polygon rendering path, string-based shape_type
- `features/gameplay/scripts/gameplay_controller.gd` — modify: use new BlockShapes API
- `features/blocks/shapes/*.json` — new: 9 migrated shape files
- `features/blocks/draggable_block.tscn` — cleanup: remove vestigial ColorRect and CollisionShape2D (in Godot editor, per scene file safety rules)

**Research insight — vestigial collision (resource safety review, HIGH):** The existing `.tscn` contains a `CollisionShape2D` with a 100x100 `RectangleShape2D` that creates phantom collision geometry overlapping with the programmatically-built shapes. This cleanup must happen in Phase 1, not deferred.

**Research insight — return vertex copies (resource safety review):** When shapes are loaded into a static dictionary, getter functions must return copies to prevent shared mutable state:
```gdscript
static func get_vertices(shape_name: StringName) -> PackedVector2Array:
    return PackedVector2Array(_shapes[shape_name].vertices)
```

**Research insight — JSON type conversion:** `JSON.parse()` returns untyped `Array`, not `PackedVector2Array`. Convert explicitly at load time in `ShapeFileIO`:
```gdscript
static func _arrays_to_vec2_array(arr: Array) -> PackedVector2Array:
    var result: PackedVector2Array = PackedVector2Array()
    for pair: Array in arr:
        result.append(Vector2(pair[0], pair[1]))
    return result
```

**Acceptance test:** Game runs identically with JSON-loaded shapes. All 9 shapes render correctly and have correct collision.

**JSON schema:**
```json
{
  "version": 1,
  "name": "s_shape",
  "vertices": [[-60, -30], [0, -30], [0, 30], [60, 30], [60, 90], [-60, 90]],
  "convex_parts": [
    [[-60, -30], [0, -30], [0, 30], [-60, 30]],
    [[0, 30], [60, 30], [60, 90], [0, 90]]
  ]
}
```

Coordinates are center-relative pixels. `convex_parts` is computed on save by the editor (or by a migration script for existing shapes).

**Collision building — one CollisionShape2D per convex part:**
```gdscript
func _build_collision(convex_parts: Array[PackedVector2Array]) -> void:
    for part: PackedVector2Array in convex_parts:
        var col: CollisionShape2D = CollisionShape2D.new()
        var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
        shape.points = part
        col.shape = shape
        add_child(col)
```

#### Phase 2: Editor Scene — Canvas and Drawing

Build the editor scene with grid canvas, vertex placement, snapping, and polygon closing.

**Files:**
- `features/blocks/editor/shape_editor.gd` — new: editor root (extends Node), UI layout, state management
- `features/blocks/editor/shape_editor.tscn` — new: minimal scene (root node + script only; all UI built programmatically per scene file safety)
- `features/blocks/editor/scripts/editor_canvas.gd` — new: grid drawing, vertex input, snap logic (extends Control)
- `features/blocks/editor/scripts/editor_state.gd` — new: state machine (extends RefCounted, with docstring explaining why not Node)

**Deliverables:**
- Grid canvas fills most of the screen with visible grid lines (60px, brighter) and midpoint indicators (30px, dimmer)
- Click places vertices that snap to 30px half-grid via `Vector2.snappedf(30.0)`
- Lines connect vertices in order with a rubber-band line from last vertex to cursor
- Right-click / Backspace / on-screen undo button removes last vertex
- Visual indicator (green highlight) on first vertex when cursor is within close range
- Click near first vertex (within 15px, using `distance_squared_to` per CLAUDE.md) or Enter closes polygon (requires 3+ vertices)
- Self-intersection validation on close with visual feedback (red flash on crossing edges)
- Winding order normalized on close (see Decision 5 for the inverted `is_polygon_clockwise` handling)
- Closed polygon shows filled + outline
- On-screen undo button for touch input (right-click unavailable on touch)

**Research insight — grid rendering performance:** ~33 grid lines + ~1008 midpoint dots are batched by Godot's 2D renderer into a small number of draw calls. The canvas only redraws on state changes (`queue_redraw()`), not every frame. No performance concern.

#### Phase 3: Save/Load and Shape Management

Add save UI, shape list panel, and debug panel integration.

**Files:**
- `features/blocks/editor/shape_editor.gd` — extend: save UI, shape list panel, back button
- `main/main.gd` — modify: add hide/show swap methods, connect signals
- `features/debug/scripts/debug_panel.gd` — modify: add "Shape Editor" button, emit `editor_requested` signal

**Deliverables:**
- Name input (`LineEdit`) + Save button below canvas
- Name validation: `^[a-z][a-z0-9_]{0,31}$`, non-empty, visual error on invalid
- Duplicate name shows overwrite confirmation
- Shape list panel on right side (~180px wide, collapsible), shows all saved shapes
- Click shape name to preview on canvas (PREVIEWING state)
- Delete button per shape (with confirmation)
- "Back to Game" button emits `back_requested` signal → `main.gd` handles swap
- Hidden when running standalone (detect via `get_parent() == get_tree().root`)
- Debug panel gets "Shape Editor" button that emits `editor_requested` signal
- `main.gd` connects `debug_panel.editor_requested` to `switch_to_editor` in `_ready()`
- Minimum 3 vertex validation, non-zero area validation, decomposition-must-succeed validation
- Ensure `features/blocks/shapes/` directory exists before write via `DirAccess.make_dir_recursive_static()`

**Research insight — FileAccess patterns:**
- `FileAccess.open()` returns `null` on failure; check `FileAccess.get_open_error()` for reason
- Use instance-based `JSON.new().parse()` for error line/message reporting, not `JSON.parse_string()`
- Pass `"\t"` to `JSON.stringify()` for human-readable output
- `res://` writes work in editor only, not exported builds — acceptable for dev-only tool

**Research insight — UI layout on 720x1280 portrait:**
```gdscript
var root_layout := HBoxContainer.new()
root_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
add_child(root_layout)

var canvas: EditorCanvas = EditorCanvas.new()
canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
root_layout.add_child(canvas)

var side_panel: VBoxContainer = _build_side_panel()
side_panel.custom_minimum_size = Vector2(180, 0)
root_layout.add_child(side_panel)
```

#### Phase 4: Migration Verification

Verify all migrated shapes produce correct geometry and behavior. Final cleanup.

**Files:**
- `features/blocks/shapes/*.json` — verify: all 9 shapes produce correct geometry
- `features/blocks/scripts/block_shapes.gd` — cleanup: remove any remaining hardcoded fallbacks

**Acceptance test:** Delete all JSON files, run editor, recreate each of the 9 original shapes, save them, return to gameplay, verify blocks spawn and behave correctly.

## Acceptance Criteria

### Functional Requirements

- [ ] Grid canvas displays with 60px grid lines and 30px midpoint snap indicators
- [ ] Clicking places vertices that snap to nearest 30px grid point via `snappedf()`
- [ ] Lines connect vertices in placement order with rubber-band preview line
- [ ] Right-click, Backspace, and on-screen button each undo last vertex
- [ ] Visual close indicator appears when cursor is near first vertex
- [ ] Clicking within 15px of first vertex (with 3+ vertices) closes the polygon
- [ ] Enter key closes the polygon (with 3+ vertices)
- [ ] Self-intersecting polygons are rejected on close with visual feedback
- [ ] Winding order is normalized on close (handling Godot's inverted Y-axis convention)
- [ ] Closed polygons display filled with color and outline
- [ ] Shape name input accepts only `[a-z][a-z0-9_]{0,31}`
- [ ] Save writes JSON to `features/blocks/shapes/` with version, name, vertices, convex_parts
- [ ] Duplicate name save shows overwrite confirmation
- [ ] Shape list panel shows all saved shapes with preview and delete
- [ ] Convex decomposition uses `Geometry2D.decompose_polygon_in_convex()`
- [ ] One `CollisionShape2D` per convex part (not one for the whole polygon)
- [ ] "Back to Game" returns to gameplay via signal, with physics state preserved
- [ ] Editor is runnable standalone (F5 on scene) with "Back" button hidden
- [ ] All 9 existing shapes are migrated to JSON
- [ ] `BlockShapes.gd` loads exclusively from JSON — no hardcoded shape data remains
- [ ] `BlockShapes` getters return copies of vertex arrays (no shared mutable state)
- [ ] `DraggableBlock` uses a single polygon rendering path for all shapes
- [ ] `DraggableBlock._ready()` asserts that shape_type exists in BlockShapes
- [ ] Gameplay spawns blocks from JSON-loaded shapes identically to before
- [ ] Vestigial ColorRect and CollisionShape2D removed from `draggable_block.tscn`

### Non-Functional Requirements

- [ ] All GDScript passes `gdformat --check` and `gdlint`
- [ ] All variables, parameters, and return types are statically typed
- [ ] No `UNSAFE_*` warnings (project has these set to Error)
- [ ] Editor UI is built programmatically (consistent with project patterns)
- [ ] Editor canvas uses `_gui_input()` + `accept_event()` (not `_unhandled_input`)
- [ ] `.uid` sidecar files committed alongside new `.gd` files

## Dependencies & Risks

**Risk: Visual regression for grid shapes.** Converting grid shapes (squares, bars, S-shape) from per-cell rectangle rendering to polygon rendering changes their appearance. The per-cell borders are lost. Mitigation: accepted tradeoff per brainstorm decision. The polygon look is cleaner and uniform.

**Risk: Physics behavior changes.** Switching from `RectangleShape2D`-per-cell to `ConvexPolygonShape2D` pieces may subtly change collision behavior at corners. Mitigation: manual playtesting after migration. Performance review confirms this is likely a collision count *reduction* for most shapes (3x3 goes from 9 shapes to 1).

**Risk: `Geometry2D.decompose_polygon_in_convex()` edge cases.** Very thin or nearly-degenerate polygons may produce unexpected decompositions. Mitigation: validate non-zero area before decomposition; reject degenerate shapes; check for empty result array.

**Risk: `res://` is read-only in exports.** The editor writes JSON to `res://features/blocks/shapes/`. This only works during development. Mitigation: this is a developer-only tool — document that it runs in the Godot editor, not in exported builds.

**Dependency: No external dependencies.** All functionality uses Godot built-ins (`Geometry2D`, `FileAccess`, `JSON`, `DirAccess`).

## Sources & References

### Origin

- **Brainstorm document:** [docs/brainstorms/2026-04-30-polygon-shape-editor-brainstorm.md](docs/brainstorms/2026-04-30-polygon-shape-editor-brainstorm.md) — Key decisions carried forward: vertex + midpoint snapping, JSON save format, separate scene, auto convex decomposition, developer-only tool.

### Internal References

- Debug panel pattern: `features/debug/scripts/debug_panel.gd` — programmatic UI construction, CanvasLayer overlay, keyboard toggle
- Block shape system: `features/blocks/scripts/block_shapes.gd` — static utility class being refactored
- Shape consumer: `features/blocks/scripts/draggable_block.gd` — `_draw()` + collision building from shape data
- Block spawner: `features/gameplay/scripts/gameplay_controller.gd` — random shape selection
- Scene root: `main/main.gd` — needs hide/show swap capability added

### Godot Built-ins Used

- `Geometry2D.decompose_polygon_in_convex()` — Hertel-Mehlhorn convex decomposition (expects CCW winding in screen space)
- `Geometry2D.is_polygon_clockwise()` — winding order detection (**inverted in Y-down screen coords**)
- `Geometry2D.segment_intersects_segment()` — self-intersection validation (returns `null` for collinear segments)
- `Vector2.snappedf()` — grid snapping to nearest multiple
- `FileAccess` + `JSON` — shape file I/O (`res://` writable in editor only)
- `DirAccess` — directory creation and listing
- `Control._gui_input()` + `accept_event()` — input handling for editor canvas
