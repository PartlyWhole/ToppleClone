class_name DraggableBlock
extends RigidBody2D

signal drag_started
signal drag_ended
signal placed

const BASE_MASS: float = 5.0
const REFERENCE_AREA: float = 3600.0
const WORLD_MIN_X: float = 20.0
const WORLD_MAX_X: float = 700.0
const FREEZE_AFTER_FRAMES: int = 60
const SETTLE_VELOCITY_SQ: float = 100.0
const SETTLE_TIME: float = 0.3

@export_group("Drag")
@export var max_drag_speed: float = 600.0
@export var contact_dampen_sideways: float = 0.3
@export var contact_dampen_downward: float = 0.0
@export var downward_normal_threshold: float = -0.5
@export var lock_rotation_while_dragging: bool = false
@export var rotate_speed: float = 4.0

@export_group("Physics Caps")
@export var max_block_speed: float = 800.0
@export var max_angular_speed: float = 6.0

@export_group("Appearance")
@export var block_color: Color = Color.CORNFLOWER_BLUE
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.4)
@export var border_width: float = 2.0

var shape_type: StringName = &""
var is_placed: bool = false
var _bounding_size: Vector2 = Vector2(60.0, 60.0)
var _is_dragging: bool = false
var _is_released: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _base_gravity_scale: float = 1.0
var _polygon: PackedVector2Array = PackedVector2Array()
var _rotate_dir: float = 0.0
var _sleep_frames: int = 0
var _settle_timer: float = 0.0


func _ready() -> void:
	assert(shape_type != &"", "shape_type must be set before adding to tree")
	assert(BlockShapes.has_shape(shape_type), "Unknown shape: " + shape_type)

	add_to_group(&"tunable_blocks")
	input_pickable = true
	set_process_unhandled_input(false)
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	contact_monitor = false
	max_contacts_reported = 4
	angular_damp = 5.0
	linear_damp = 0.5
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 1.0
	mat.rough = true
	physics_material_override = mat
	input_event.connect(_on_input_event)

	_polygon = BlockShapes.get_vertices(shape_type)
	_bounding_size = BlockShapes.get_bounding_size(shape_type)
	mass = BASE_MASS * BlockShapes.get_area(shape_type) / REFERENCE_AREA

	_build_collision()
	queue_redraw()


func _draw() -> void:
	draw_colored_polygon(_polygon, block_color)
	var outline: PackedVector2Array = _polygon.duplicate()
	outline.append(_polygon[0])
	draw_polyline(outline, border_color, border_width)


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if not _is_dragging:
		if _is_released and not is_placed:
			_check_settlement(state)
		if sleeping:
			_sleep_frames += 1
			if _sleep_frames >= FREEZE_AFTER_FRAMES:
				freeze = true
				return
		else:
			_sleep_frames = 0
		var speed_sq: float = state.linear_velocity.length_squared()
		if speed_sq > max_block_speed * max_block_speed:
			state.linear_velocity = (state.linear_velocity * (max_block_speed / sqrt(speed_sq)))
		state.angular_velocity = clampf(
			state.angular_velocity, -max_angular_speed, max_angular_speed
		)
		return

	var half: Vector2 = _bounding_size / 2.0
	var target: Vector2 = get_global_mouse_position() + _drag_offset
	target.x = clampf(target.x, WORLD_MIN_X + half.x, WORLD_MAX_X - half.x)

	var desired: Vector2 = (target - global_position) / state.step
	var desired_speed_sq: float = desired.length_squared()
	if desired_speed_sq > max_drag_speed * max_drag_speed:
		desired = desired * (max_drag_speed / sqrt(desired_speed_sq))

	for i: int in state.get_contact_count():
		var normal: Vector2 = state.get_contact_local_normal(i)
		var push: float = desired.dot(normal)
		if push < 0.0:
			var is_downward: bool = normal.y < downward_normal_threshold
			var dampen: float = contact_dampen_downward if is_downward else contact_dampen_sideways
			desired -= normal * push * (1.0 - dampen)

	state.linear_velocity = desired
	if _rotate_dir != 0.0:
		state.angular_velocity = _rotate_dir * rotate_speed
	else:
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
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.keycode == KEY_Q or key.keycode == KEY_E:
			_update_rotate_input()


func get_bounding_size() -> Vector2:
	return _bounding_size


func wake_up() -> void:
	freeze = false
	_sleep_frames = 0


func _start_drag() -> void:
	if freeze:
		wake_up()
	_is_dragging = true
	_is_released = false
	is_placed = false
	_settle_timer = 0.0
	_drag_offset = global_position - get_global_mouse_position()
	_base_gravity_scale = gravity_scale
	gravity_scale = 0.0
	contact_monitor = true
	set_process_unhandled_input(true)
	drag_started.emit()


func _stop_drag() -> void:
	_is_dragging = false
	_is_released = true
	gravity_scale = _base_gravity_scale
	linear_velocity = Vector2.ZERO
	set_process_unhandled_input(false)
	drag_ended.emit()


func _check_settlement(state: PhysicsDirectBodyState2D) -> void:
	var is_slow: bool = state.linear_velocity.length_squared() < SETTLE_VELOCITY_SQ
	var has_contact: bool = state.get_contact_count() > 0
	if is_slow and has_contact:
		_settle_timer += state.step
		if _settle_timer >= SETTLE_TIME:
			is_placed = true
			contact_monitor = false
			placed.emit()
	else:
		_settle_timer = 0.0


func _update_rotate_input() -> void:
	var left: bool = Input.is_key_pressed(KEY_Q)
	var right: bool = Input.is_key_pressed(KEY_E)
	if left and not right:
		_rotate_dir = -1.0
	elif right and not left:
		_rotate_dir = 1.0
	else:
		_rotate_dir = 0.0


func _build_collision() -> void:
	var convex_parts: Array[PackedVector2Array] = BlockShapes.get_convex_parts(shape_type)
	for part: PackedVector2Array in convex_parts:
		var col: CollisionShape2D = CollisionShape2D.new()
		var rect: Rect2 = _try_as_rect(part)
		if rect.size.x > 0.0:
			var rect_shape: RectangleShape2D = RectangleShape2D.new()
			rect_shape.size = rect.size
			col.shape = rect_shape
			col.position = rect.position + rect.size / 2.0
		else:
			var shape: ConvexPolygonShape2D = ConvexPolygonShape2D.new()
			shape.points = part
			col.shape = shape
		add_child(col)


func _try_as_rect(verts: PackedVector2Array) -> Rect2:
	if verts.size() != 4:
		return Rect2()
	var xs: PackedFloat32Array = PackedFloat32Array()
	var ys: PackedFloat32Array = PackedFloat32Array()
	for v: Vector2 in verts:
		xs.append(v.x)
		ys.append(v.y)
	xs.sort()
	ys.sort()
	if not is_equal_approx(xs[0], xs[1]) or not is_equal_approx(xs[2], xs[3]):
		return Rect2()
	if not is_equal_approx(ys[0], ys[1]) or not is_equal_approx(ys[2], ys[3]):
		return Rect2()
	return Rect2(Vector2(xs[0], ys[0]), Vector2(xs[2] - xs[0], ys[2] - ys[0]))
