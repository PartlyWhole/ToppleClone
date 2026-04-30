---
title: "feat: Shape Editor Vertex Editing"
type: feat
status: active
date: 2026-04-30
---

# feat: Shape Editor Vertex Editing

## Overview

Add vertex editing to the shape editor so previously saved shapes can be modified in place — drag vertices to move them, click edges to insert new vertices, and click vertices to remove them. Currently shapes can only be previewed (read-only) or deleted and redrawn from scratch.

## Problem Statement

The editor's PREVIEWING state is view-only. To fix a shape, you must delete it and recreate it from scratch. This is tedious for small adjustments — moving one vertex requires redrawing the entire shape.

## Proposed Solution

Add a new **EDITING** state to the editor state machine. When a saved shape is previewed, an "Edit" button enters EDITING mode where:
- **Drag a vertex** to move it (snap to half-grid)
- **Click on an edge** to insert a new vertex at the click point
- **Right-click a vertex** to delete it (minimum 3 vertices enforced)
- **Enter or "Done" button** closes editing, re-validates the polygon, and returns to CLOSED state ready for save

The existing save flow handles the rest — name defaults to the shape's original name, and saving overwrites the file.

## Technical Approach

### State Machine Changes

Add `EDITING` to `EditorState.State` enum:

```
IDLE ──(click)──► DRAWING ──(close)──► CLOSED ──(save)──► IDLE

IDLE ──(select shape)──► PREVIEWING ──(edit btn)──► EDITING ──(done)──► CLOSED

EDITING: drag vertices, insert on edges, delete vertices
```

`editor_state.gd` changes:
- Add `State.EDITING` to enum
- Add `start_editing()` — transitions from PREVIEWING to EDITING, keeps vertices and preview_name
- Add `move_vertex(index: int, pos: Vector2)` — update vertex position in-place
- Add `insert_vertex(index: int, pos: Vector2)` — insert vertex after edge index
- Add `remove_vertex(index: int)` — remove vertex (guard: min 3 vertices)
- Add `finish_editing() -> bool` — validate (no self-intersection, non-zero area), normalize winding, transition to CLOSED

### Canvas Input Changes

`editor_canvas.gd` needs new input handling for EDITING state:

**Hit detection:**
- `_find_nearest_vertex(pos: Vector2) -> int` — returns index of vertex within grab radius (8px), or -1
- `_find_nearest_edge(pos: Vector2) -> int` — returns index of edge whose projection is within snap distance (10px), or -1

**Input routing in EDITING state:**
- **Left press on vertex** → start drag (store `_drag_vertex_index`)
- **Left press on edge** → insert vertex at snapped position
- **Left press on empty space** → nothing (or deselect)
- **Left drag** → move dragged vertex to snapped cursor position
- **Left release** → end drag
- **Right-click on vertex** → remove vertex (if 3+ remain)
- **Enter / Done button** → emit `editing_done` signal

**Visual feedback in EDITING state:**
- Draw filled polygon (same as CLOSED)
- Larger vertex circles (6px instead of 4px) to indicate they're interactive
- Highlight hovered vertex (yellow/orange)
- Highlight hovered edge for insertion (dotted line or different color)
- Show cursor hint (grab cursor over vertices)

### Editor UI Changes

`shape_editor.gd`:
- Add "Edit" button visible during PREVIEWING state
- Add "Done" button visible during EDITING state
- Wire `_on_edit_pressed()` → `_state.start_editing()`, set canvas mode
- Wire `_on_editing_done()` → `_state.finish_editing()`, pre-fill name input with `_state.preview_name`
- EDITING done → CLOSED → existing save flow works as-is

### Files to Modify

| File | Change |
|------|--------|
| `features/blocks/editor/scripts/editor_state.gd` | Add EDITING state, move/insert/remove/finish methods |
| `features/blocks/editor/scripts/editor_canvas.gd` | Add EDITING input handling, hit detection, visual feedback |
| `features/blocks/editor/shape_editor.gd` | Add Edit/Done buttons, wire new state transitions |

No new files needed. No changes to BlockShapes, DraggableBlock, or ShapeFileIO.

## Acceptance Criteria

- [ ] "Edit" button appears when previewing a saved shape
- [ ] Clicking "Edit" enters EDITING state with the shape's vertices editable
- [ ] Dragging a vertex moves it, snapping to 30px half-grid
- [ ] Clicking on an edge inserts a new vertex at the snapped click position
- [ ] Right-clicking a vertex removes it (disabled/ignored if only 3 vertices remain)
- [ ] "Done" button (or Enter key) validates the edited polygon (no self-intersection, non-zero area)
- [ ] Invalid edit shows error in status label and stays in EDITING
- [ ] After "Done", state is CLOSED with name input pre-filled with original shape name
- [ ] Saving overwrites the original shape file
- [ ] Vertices display larger in EDITING mode to indicate interactivity
- [ ] Hovered vertex is visually highlighted
- [ ] All GDScript passes `gdformat --check` and `gdlint`
- [ ] All variables/parameters/return types are statically typed

## Sources & References

- Editor state machine: `features/blocks/editor/scripts/editor_state.gd` — EditorState.State enum, transition methods
- Canvas input/draw: `features/blocks/editor/scripts/editor_canvas.gd` — `_gui_input()`, `_draw()`, `_snap()`
- Editor UI: `features/blocks/editor/shape_editor.gd` — button construction, signal wiring
- Original plan: `docs/plans/2026-04-30-feat-polygon-shape-editor-plan.md`
