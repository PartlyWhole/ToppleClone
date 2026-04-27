class_name DraggableBlock
extends RigidBody2D

signal drag_started
signal drag_ended

const MAX_DRAG_SPEED: float = 600.0
const MAX_BLOCK_SPEED: float = 800.0
const MAX_ANGULAR_SPEED: float = 6.0

@export var block_size: Vector2 = Vector2(100, 100)
@export var block_color: Color = Color.CORNFLOWER_BLUE

var _is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	assert(block_size.x > 0 and block_size.y > 0)
	input_pickable = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	input_event.connect(_on_input_event)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not _is_dragging:
		if state.linear_velocity.length() > MAX_BLOCK_SPEED:
			state.linear_velocity = state.linear_velocity.normalized() * MAX_BLOCK_SPEED
		state.angular_velocity = clampf(
			state.angular_velocity, -MAX_ANGULAR_SPEED, MAX_ANGULAR_SPEED
		)
		return
	var half: Vector2 = block_size / 2.0
	var viewport_size: Vector2 = get_viewport_rect().size
	var target: Vector2 = get_global_mouse_position() + _drag_offset
	target.x = clampf(target.x, half.x, viewport_size.x - half.x)
	target.y = clampf(target.y, half.y, viewport_size.y - half.y)
	var desired: Vector2 = (target - global_position) / state.step
	if desired.length() > MAX_DRAG_SPEED:
		desired = desired.normalized() * MAX_DRAG_SPEED
	state.linear_velocity = desired
	state.angular_velocity = 0.0


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_start_drag()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_dragging:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_stop_drag()


func _start_drag() -> void:
	_is_dragging = true
	_drag_offset = global_position - get_global_mouse_position()
	gravity_scale = 0.0
	drag_started.emit()


func _stop_drag() -> void:
	_is_dragging = false
	gravity_scale = 1.0
	linear_velocity = Vector2.ZERO
	drag_ended.emit()
