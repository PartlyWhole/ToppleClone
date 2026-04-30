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
