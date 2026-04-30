# Polygon Shape Editor — Brainstorm

**Date:** 2026-04-30
**Status:** Draft

## What We're Building

An in-game developer tool for visually designing block shapes on a snapping grid. The editor is a separate scene you run directly or navigate to from the debug panel. You click to place vertices that snap to grid intersections and edge midpoints (half-grid), lines connect them in order, and closing the polygon completes the shape. Shapes save as JSON files that BlockShapes loads at startup, replacing the current hardcoded shape definitions.

The editor automatically decomposes concave polygons into convex pieces for physics collision.

## Why This Approach

- **Vertex + midpoint snapping** gives enough precision for all current shape types (grid-aligned squares, half-cell triangles, the E-shaped arrow) without the complexity of freeform drawing
- **JSON save format** is human-readable, easy to hand-edit, and avoids coupling shapes to GDScript code
- **Separate scene** keeps the editor cleanly isolated from gameplay — no input conflicts, no overlay complexity, can be run directly with F5
- **Auto convex decomposition** means you just draw the outline and physics "just works" for any shape, including concave ones like the E-block

## Key Decisions

1. **Audience:** Developer tool only, not player-facing
2. **Input method:** Click vertices on grid, snapping to intersections and edge midpoints (half-grid precision)
3. **Save format:** JSON files in `features/blocks/shapes/`, loaded by BlockShapes at startup
4. **Convexity:** Auto-decompose concave polygons for collision (ear-clipping or similar)
5. **Access:** Separate scene, with a launch button in the debug panel
6. **Grid unit:** Based on `BlockShapes.CELL_SIZE` (currently 60px)

## Scope

### In scope
- Grid canvas with visible grid lines and snap points
- Click to place vertices, lines drawn between them
- Snap to grid intersections and edge midpoints
- Visual preview of the completed polygon (filled + outline)
- Undo last vertex (backspace/right-click)
- Close polygon (click near first vertex or press Enter)
- Save shape to JSON with a name
- Load/browse/delete existing shapes
- Auto convex decomposition for collision
- Shape list panel to manage saved shapes
- Debug panel button to switch to editor scene

### Out of scope
- Player-facing UI or creative mode
- Drag-to-move vertices after placement (edit = delete + redraw)
- Bezier curves or arcs
- Multi-polygon composite shapes (single outline per shape)
- Undo beyond "remove last vertex"

## Open Questions

None — all key decisions resolved.

## Technical Notes

- The editor scene lives at `features/blocks/editor/shape_editor.tscn`
- JSON schema per shape: `{ "name": "s_block", "vertices": [[x,y], ...], "convex_parts": [[[x,y], ...], ...] }`
- `convex_parts` is computed on save, not stored manually
- BlockShapes.gd will be refactored to load from JSON at startup instead of hardcoded match statements
- Existing hardcoded shapes should be migrated to JSON files
