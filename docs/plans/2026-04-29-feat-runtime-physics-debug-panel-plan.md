---
title: Runtime Physics Debug Panel
type: feat
status: completed
date: 2026-04-29
---

# Runtime Physics Debug Panel

## Enhancement Summary

**Deepened on:** 2026-04-29
**Sections enhanced:** All
**Agents used:** architecture, gdscript, performance, timing, patterns, simplicity, best-practices, framework-docs

### Key Improvements
1. Moved from autoload to `features/debug/` — autoload scope was too broad for single-feature tooling
2. Data-driven parameter config replaces 11 hand-coded slider rows (~60 LOC saved)
3. Blocks self-register in group via `_ready()` instead of spawner managing it
4. Fixed `gravity_scale` bug: `_stop_drag()` hardcodes `1.0`, which would override debug-tuned values
5. Full-rect IGNORE root Control pattern for proper click-through

### New Considerations Discovered
- Mixed-type `const Dictionary` cascades `UNSAFE_*` errors under strict typing — use individual typed constants or data-driven array
- `set_anchors_preset()` must be called AFTER `add_child()` or anchors compute against zero-size rect
- `is_instance_valid()` guard needed in slider callbacks for scene transition safety
- ScrollContainer `clip_contents` is already `true` by default — no need to set it
- StyleBox override name for PanelContainer is `"panel"`, not `"normal"`

---

## Overview

Add a toggleable debug UI panel (Shift+5) that exposes all DraggableBlock physics parameters as live-tunable controls. The panel is a scrollable overlay built programmatically under `features/debug/`, so developers can tweak physics feel at runtime without restarting.

## Problem Statement / Motivation

Physics tuning requires constant iteration — change a value, run the game, feel it, repeat. Currently every tweak requires editing script defaults or scene properties and restarting. A runtime panel lets you adjust all 11 parameters live, see the effect immediately on all blocks, and copy the tuned values back into code.

## Proposed Solution

A debug scene added conditionally from `main.gd` that creates a `CanvasLayer` with a `ScrollContainer`-based UI panel. Each physics parameter gets a labeled slider (or checkbox for bools). Changes propagate instantly to all blocks via group query.

### Parameters Exposed

**Drag group:**
| Parameter | Type | Default | Min | Max | Step |
|---|---|---|---|---|---|
| `max_drag_speed` | float | 600.0 | 0.0 | 2000.0 | 10.0 |
| `contact_dampen_sideways` | float | 0.3 | 0.0 | 1.0 | 0.05 |
| `contact_dampen_downward` | float | 0.0 | 0.0 | 1.0 | 0.05 |
| `downward_normal_threshold` | float | -0.5 | -1.0 | 0.0 | 0.05 |
| `lock_rotation_while_dragging` | bool | false | — | — | — |

**Physics Caps group:**
| Parameter | Type | Default | Min | Max | Step |
|---|---|---|---|---|---|
| `max_block_speed` | float | 800.0 | 0.0 | 2000.0 | 10.0 |
| `max_angular_speed` | float | 6.0 | 0.0 | 20.0 | 0.5 |

**RigidBody2D properties:**
| Parameter | Type | Default | Min | Max | Step |
|---|---|---|---|---|---|
| `mass` | float | 5.0 | 0.1 | 50.0 | 0.1 |
| `angular_damp` | float | 5.0 | 0.0 | 20.0 | 0.5 |
| `gravity_scale` | float | 1.0 | 0.0 | 5.0 | 0.1 |
| `linear_damp` | float | 0.0 | 0.0 | 20.0 | 0.5 |

## Technical Considerations

### Architecture

- **Feature folder (`features/debug/scripts/debug_panel.gd`)**: Extends `Node`. Creates all UI in `_ready()` via code. Added conditionally from `main.gd` (debug builds only). Not an autoload — a debug panel is scene-specific tooling, not cross-system persistent state like Events or GameState.
- **CanvasLayer**: `layer = 100` to sit above all gameplay. Created as child of the debug panel node.
- **Block discovery**: DraggableBlock self-registers in group `"tunable_blocks"` in its own `_ready()`. Panel iterates `get_tree().get_nodes_in_group("tunable_blocks")` on value change. This follows the principle that entities own their own identity — any spawner (gameplay controller, future level editor, test harness) gets group membership for free.
- **Value propagation**: Each slider connects `value_changed` to a generic callback that iterates the group and sets the property by name. Guard each block with `is_instance_valid()` for scene transition safety.

### Research Insights: Architecture

- Autoload scope should be reserved for cross-system concerns (Events, GameState). A debug panel coupled to one feature's property names belongs in `features/debug/`.
- Direct property writes (`block.max_drag_speed = value`) are acceptable for a debug tool's simplicity, but if DraggableBlock refactors parameters into components, an `apply_tuning()` method would centralize the contract.
- Group-based iteration is idiomatic Godot for broadcast operations and avoids hardcoded paths.

### Input Handling

- **Toggle**: `_unhandled_input` checks for `KEY_5` + Shift modifier. This ensures UI controls consume events first (sliders, checkboxes) and the toggle only fires if nothing else handled the key.
- **Click-through prevention**: Use a full-rect `Control` with `MOUSE_FILTER_IGNORE` as the layout root inside the CanvasLayer. Place the actual `PanelContainer` as a child with `MOUSE_FILTER_STOP`. Clicks outside the panel fall through to the game world; clicks on the panel and its children (sliders, labels) are captured.

### Panel Layout

- **Position**: Right-aligned, narrow strip (~280px wide on 720px viewport). Leaves ~440px for seeing/interacting with blocks.
- **Semi-transparent background**: `StyleBoxFlat` with `bg_color = Color(0.1, 0.1, 0.1, 0.85)` applied via `add_theme_stylebox_override("panel", style)`. Note: the override name is `"panel"`, not `"normal"`.
- **ScrollContainer**: Wraps a `VBoxContainer` with all controls. Set `horizontal_scroll_mode = SCROLL_MODE_DISABLED`. `clip_contents` is already `true` by default. Set `custom_minimum_size.y` to cap panel height.
- **Per-parameter row**: `HBoxContainer` with `Label` (parameter name, `custom_minimum_size.x = 120`) + `HSlider` (`SIZE_EXPAND_FILL`, `custom_minimum_size.x = 100`) + `Label` (current value readout, `custom_minimum_size.x = 50`). Bools get a `CheckBox` instead of slider.
- **Buttons at bottom**: "Reset All" (restores defaults by instantiating a temporary reference block).

### Research Insights: UI Construction

- `set_anchors_preset()` must be called AFTER `add_child()` — before that, the control has no parent rect and the preset computes wrong.
- For right-anchored panel: `grow_horizontal = Control.GROW_DIRECTION_BEGIN` so it grows leftward from the right edge.
- Children of VBoxContainer/HBoxContainer ignore `anchor_*` and `offset_*` — use `size_flags_*` and `custom_minimum_size` instead.
- Set all slider properties (min, max, step, value) BEFORE `add_child()` to avoid redundant layout passes.
- HSlider needs `custom_minimum_size.x` set or it can collapse to zero width inside HBoxContainer.

### Data-Driven Parameter Config

Instead of 11 hand-coded slider rows, use a config array and a single loop:

```gdscript
const PARAMS: Array[Dictionary] = [
    {"name": &"max_drag_speed", "min": 0.0, "max": 2000.0, "step": 10.0, "group": "Drag"},
    {"name": &"contact_dampen_sideways", "min": 0.0, "max": 1.0, "step": 0.05},
    {"name": &"contact_dampen_downward", "min": 0.0, "max": 1.0, "step": 0.05},
    {"name": &"downward_normal_threshold", "min": -1.0, "max": 0.0, "step": 0.05},
    {"name": &"lock_rotation_while_dragging", "type": "bool"},
    {"name": &"max_block_speed", "min": 0.0, "max": 2000.0, "step": 10.0, "group": "Physics Caps"},
    {"name": &"max_angular_speed", "min": 0.0, "max": 20.0, "step": 0.5},
    {"name": &"mass", "min": 0.1, "max": 50.0, "step": 0.1, "group": "Body"},
    {"name": &"angular_damp", "min": 0.0, "max": 20.0, "step": 0.5},
    {"name": &"gravity_scale", "min": 0.0, "max": 5.0, "step": 0.1},
    {"name": &"linear_damp", "min": 0.0, "max": 20.0, "step": 0.5},
]
```

One `_build_slider_row()` function, one generic `_on_param_changed(value, param_name)` callback using `.bind()`. Adding a new parameter is a single dictionary entry.

### Defaults Without Duplication

Instead of a `const DEFAULTS` dictionary (which duplicates values from `@export` defaults and `.tscn` properties), read defaults at runtime from a temporary reference block:

```gdscript
func _read_defaults() -> Dictionary:
    var ref: DraggableBlock = BlockScene.instantiate() as DraggableBlock
    var defaults: Dictionary = {}
    for param: Dictionary in PARAMS:
        defaults[param["name"]] = ref.get(param["name"])
    ref.queue_free()
    return defaults
```

Zero duplication, zero drift risk.

### Files to Create/Modify

**New files:**
- `features/debug/scripts/debug_panel.gd` — the debug panel script (~80-100 lines with data-driven approach)

**Modified files:**
- `main/main.gd` — conditionally add debug panel scene
- `features/blocks/scripts/draggable_block.gd` — add `add_to_group(&"tunable_blocks")` in `_ready()`, fix `gravity_scale` hardcode in `_stop_drag()`

### Bug Fix: gravity_scale Hardcode

`_stop_drag()` in `draggable_block.gd` currently hardcodes `gravity_scale = 1.0`. If the debug panel changes `gravity_scale` to e.g. `3.0`, dropping a block resets it to `1.0`. Fix: store the intended gravity scale and restore to that value:

```gdscript
var _base_gravity_scale: float = 1.0

func _start_drag() -> void:
    _is_dragging = true
    _drag_offset = global_position - get_global_mouse_position()
    _base_gravity_scale = gravity_scale
    gravity_scale = 0.0
    drag_started.emit()

func _stop_drag() -> void:
    _is_dragging = false
    gravity_scale = _base_gravity_scale
    linear_velocity = Vector2.ZERO
    drag_ended.emit()
```

## System-Wide Impact

- **Signal chain**: Slider `value_changed` → `_on_param_changed()` → iterates group → sets property. No autoload signals involved. Self-contained.
- **Error propagation**: Group query returns empty array if no blocks exist — harmless. `mass` clamped to 0.1 minimum prevents physics division-by-zero. Each block guarded with `is_instance_valid()`.
- **State lifecycle risks**: Panel state is ephemeral — lost on scene reload. This is intentional for a debug tool.
- **Scene interface parity**: No other scenes expose debug controls. This is the first and only debug UI.
- **Integration test scenarios**: Toggle panel on/off while dragging a block. Adjust mass while blocks are stacked. Scene transition while panel is visible.

### Research Insights: Timing

- Debug panel `_ready()` should only build UI, not query the block group (blocks may not exist yet).
- `add_to_group()` is synchronous — no timing issues with group membership.
- Autoloads persist across scene changes; a feature-folder debug panel would be freed with the scene. If persistence across scene transitions is needed, the panel could be added to `main.gd` which persists as long as the main scene is loaded.
- Newly spawned blocks won't retroactively pick up slider values unless the spawner reads current values from the panel. Document this as a known limitation.

## Acceptance Criteria

- [x] Shift+5 toggles the debug panel on/off
- [x] Panel has a scrollable area containing all 11 parameters
- [x] Each parameter has a labeled slider (or checkbox) with min/max/step constraints
- [x] Changing a value instantly applies to all existing blocks
- [x] Panel does not intercept mouse events outside its bounds (blocks remain draggable)
- [x] "Reset All" button restores all parameters to defaults (read from reference block)
- [x] Panel renders correctly in 720x1280 viewport
- [x] `gravity_scale` bug fixed — `_stop_drag()` restores saved value, not hardcoded `1.0`
- [x] Blocks self-register in `"tunable_blocks"` group in their own `_ready()`
- [x] Slider callbacks guard blocks with `is_instance_valid()`
- [x] Linting passes (gdformat + gdlint)
- [x] All variables, parameters, and return types are statically typed

## Success Metrics

- Developer can tune all physics parameters without restarting the game
- No physics jitter or instability caused by mid-simulation property changes
- Panel toggle is responsive (<1 frame)
- Adding a new tunable parameter requires only a single dictionary entry in PARAMS

## Dependencies & Risks

- **Risk**: Changing `mass` on a RigidBody2D mid-contact can cause a one-frame impulse spike. Mitigation: acceptable for debug use.
- **Risk**: ScrollContainer + touch input may conflict with block drag gestures. Mitigation: debug panel is desktop-only tooling; touch conflict is low priority.
- **Risk**: Newly spawned blocks won't inherit current slider values. Mitigation: document as known limitation; fix if needed by having spawner read current values.
- **Bug to fix**: `_stop_drag()` hardcodes `gravity_scale = 1.0` — must store and restore the intended value.

## MVP

### features/debug/scripts/debug_panel.gd (skeleton)

```gdscript
extends Node

const BLOCK_GROUP: StringName = &"tunable_blocks"
const PANEL_WIDTH: float = 280.0

const PARAMS: Array[Dictionary] = [
    {"name": &"max_drag_speed", "min": 0.0, "max": 2000.0, "step": 10.0, "group": "Drag"},
    {"name": &"contact_dampen_sideways", "min": 0.0, "max": 1.0, "step": 0.05},
    # ... remaining params
]

var _panel: PanelContainer
var _is_visible: bool = false


func _ready() -> void:
    _build_ui()
    _panel.visible = false
    assert(_panel != null)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and key.keycode == KEY_5 and key.shift_pressed:
            _is_visible = not _is_visible
            _panel.visible = _is_visible
            get_viewport().set_input_as_handled()


func _build_ui() -> void:
    var canvas_layer: CanvasLayer = CanvasLayer.new()
    canvas_layer.layer = 100
    add_child(canvas_layer)

    # Full-rect IGNORE root so clicks outside panel pass through
    var root: Control = Control.new()
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas_layer.add_child(root)

    _panel = PanelContainer.new()
    _panel.mouse_filter = Control.MOUSE_FILTER_STOP
    root.add_child(_panel)
    _panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
    _panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
    # Apply semi-transparent StyleBoxFlat via add_theme_stylebox_override("panel", style)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _panel.add_child(scroll)

    var vbox: VBoxContainer = VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(vbox)

    # Data-driven loop over PARAMS to create slider/checkbox rows
    for param: Dictionary in PARAMS:
        if param.has("group"):
            _add_group_header(vbox, param["group"] as String)
        _add_param_row(vbox, param)


func _on_param_changed(value: float, param_name: StringName) -> void:
    for node: Node in get_tree().get_nodes_in_group(BLOCK_GROUP):
        if is_instance_valid(node):
            node.set(param_name, value)
```

### draggable_block.gd changes

```gdscript
# In _ready(), add:
add_to_group(&"tunable_blocks")

# Fix _stop_drag():
var _base_gravity_scale: float = 1.0

func _start_drag() -> void:
    _base_gravity_scale = gravity_scale
    gravity_scale = 0.0
    # ...

func _stop_drag() -> void:
    gravity_scale = _base_gravity_scale
    # ...
```

### main.gd changes

```gdscript
# In _ready():
var debug_panel_script: GDScript = load("res://features/debug/scripts/debug_panel.gd")
var debug_panel: Node = debug_panel_script.new()
add_child(debug_panel)
```

## Sources

- `features/blocks/scripts/draggable_block.gd` — all @export parameters
- `features/blocks/draggable_block.tscn` — mass=5.0, angular_damp=5.0
- `features/gameplay/scripts/gameplay_controller.gd` — block spawning
- CLAUDE.md — autoload conventions, scene safety rules, static typing requirements
- Godot 4.6 docs: ScrollContainer, PanelContainer, HSlider, Control, CanvasLayer, StyleBoxFlat
