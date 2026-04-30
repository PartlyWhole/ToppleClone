---
status: deferred
priority: p2
issue_id: "001"
tags: [code-review, resource-safety, gdscript]
---

# Embedded StyleBoxFlat sub-resources in game_hud.tscn

## Problem Statement
`features/hud/game_hud.tscn` embeds two mutable `StyleBoxFlat` sub-resources directly in the scene file. Per CLAUDE.md: "Component .tscn files must not embed mutable sub-resources."

## Findings
- `StyleBoxFlat_topbar` and `StyleBoxFlat_gameover` are `[sub_resource]` entries
- No runtime mutation occurs currently, but convention is violated
- Low risk since HUD is a singleton

## Proposed Solutions
1. Extract to `features/hud/resources/topbar_style.tres` and `gameover_panel_style.tres`, reference as ext_resource. Do this in the Godot editor.

## Acceptance Criteria
- [ ] No `[sub_resource]` entries for StyleBoxFlat in game_hud.tscn
- [ ] Styles referenced as ext_resource from features/hud/resources/
