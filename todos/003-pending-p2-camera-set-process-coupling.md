---
status: complete
priority: p2
issue_id: "003"
tags: [code-review, architecture, gdscript]
---

# GameManager directly calls set_process on GameCamera sibling

## Problem Statement
GameManager calls `_camera.set_process(true/false)` in `_transition_to()`, controlling a sibling's processing lifecycle. This couples GameManager to GameCamera's internal implementation.

## Findings
- Lines 88-89, 91-92, 96-97, 101-102 of game_manager.gd
- GameCamera should manage its own processing based on game state signals

## Proposed Solutions
1. Expose `enable()`/`disable()` methods on GameCamera
2. GameCamera listens to Events.game_started/game_ended to self-manage

## Acceptance Criteria
- [ ] GameManager does not call set_process on GameCamera
- [ ] GameCamera manages its own processing lifecycle
