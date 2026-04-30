---
status: pending
priority: p2
issue_id: "002"
tags: [code-review, architecture, gdscript]
---

# GameManager uses sibling traversal instead of scene paths or @export

## Problem Statement
GameManager finds siblings (GameCamera, BlockContainer) via `get_parent().get_children()` iteration. This is a sideways reach that violates "call down, signal up."

## Findings
- `_find_camera()`, `_find_block_container()`, `_find_parent_const()` iterate parent's children
- Works but fragile to dynamic instantiation or scene restructuring
- Duck-typed property access (`"PLATFORM_SURFACE_Y" in parent`) bypasses static typing

## Proposed Solutions
1. Use direct scene paths: `@onready var _camera: GameCamera = $"../GameCamera"`
2. Use `@export var` slots wired in the .tscn inspector

## Acceptance Criteria
- [ ] No `get_parent().get_children()` iteration in GameManager
- [ ] References resolved via scene paths or @export
