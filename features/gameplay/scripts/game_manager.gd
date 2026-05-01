class_name GameManager
extends Node

enum State { MENU, PLAYING, WON, LOST, RESTARTING }

const MAX_HP: int = 4
const ROUND_TIME: float = 60.0
const DROP_THRESHOLD_Y: float = 300.0
const HEIGHT_SCAN_INTERVAL: float = 0.5
const SPAWN_DELAY: float = 2.0
const BASE_TARGET_HEIGHT: float = 300.0
const HEIGHT_PER_LEVEL: float = 200.0

const BLOCK_COLORS: Array[Color] = [
	Color.CORNFLOWER_BLUE,
	Color.CORAL,
	Color.MEDIUM_SEA_GREEN,
	Color.GOLD,
	Color.MEDIUM_PURPLE,
	Color.TOMATO,
	Color.DARK_TURQUOISE,
]

var _state: State = State.MENU
var _hp: int = MAX_HP
var _time_remaining: float = ROUND_TIME
var _level: int = 1
var _current_block: DraggableBlock = null
var _scan_timer: float = 0.0
var _last_displayed_seconds: int = -1
var _tower_height: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _camera: GameCamera = $"../GameCamera" as GameCamera
@onready var _block_container: Node2D = $"../BlockContainer" as Node2D


func _ready() -> void:
	assert(_camera != null, "GameCamera not found as sibling")
	assert(_block_container != null, "BlockContainer not found as sibling")
	set_process(false)
	Events.ui_play_pressed.connect(_on_play_pressed)
	Events.ui_restart_pressed.connect(_on_restart_pressed)
	Events.ui_next_level_pressed.connect(_on_next_level_pressed)


func _process(delta: float) -> void:
	if _state != State.PLAYING:
		return
	_time_remaining -= delta
	var display_seconds: int = ceili(_time_remaining)
	if display_seconds != _last_displayed_seconds:
		_last_displayed_seconds = display_seconds
		Events.timer_updated.emit(_time_remaining)
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		Events.timer_updated.emit(0.0)
		_transition_to(State.LOST)
		return
	_scan_timer += delta
	if _scan_timer >= HEIGHT_SCAN_INTERVAL:
		_scan_timer = 0.0
		_scan_tower()


func _on_play_pressed() -> void:
	if _state != State.MENU:
		return
	_level = 1
	_start_round()


func _on_restart_pressed() -> void:
	if _state == State.RESTARTING:
		return
	_restart()


func _on_next_level_pressed() -> void:
	if _state != State.WON:
		return
	_level += 1
	_start_round()


func _start_round() -> void:
	_hp = MAX_HP
	_time_remaining = ROUND_TIME
	_last_displayed_seconds = -1
	_scan_timer = 0.0
	_tower_height = 0.0
	_transition_to(State.PLAYING)
	Events.level_changed.emit(_level, _get_level_target())
	Events.game_started.emit()
	Events.hp_changed.emit(_hp)
	Events.timer_updated.emit(_time_remaining)
	_spawn_block()


func _transition_to(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.PLAYING:
			set_process(true)
		State.WON:
			set_process(false)
			_freeze_all_blocks()
			Events.game_ended.emit(true, _tower_height)
		State.LOST:
			set_process(false)
			_freeze_all_blocks()
			Events.game_ended.emit(false, _tower_height)
		State.MENU, State.RESTARTING:
			set_process(false)


func _restart() -> void:
	_transition_to(State.RESTARTING)
	for child: Node in _block_container.get_children():
		if child is DraggableBlock:
			var block: DraggableBlock = child as DraggableBlock
			block.input_pickable = false
			block.set_process_unhandled_input(false)
		child.queue_free()
	_current_block = null
	_level = 1
	_tower_height = 0.0
	Events.game_restarted.emit()
	_transition_to(State.MENU)


func _get_level_target() -> float:
	return BASE_TARGET_HEIGHT + (_level - 1) * HEIGHT_PER_LEVEL


func _spawn_block() -> void:
	if _state != State.PLAYING:
		return
	var all_names: Array[StringName] = BlockShapes.get_all_names()
	if all_names.is_empty():
		push_error("No shapes loaded — check features/blocks/shapes/ directory")
		return
	var block: DraggableBlock = DraggableBlock.new()
	block.shape_type = all_names[_rng.randi() % all_names.size()]
	var bounds: Vector2 = BlockShapes.get_bounding_size(block.shape_type)
	var margin: float = maxf(bounds.x, bounds.y) / 2.0 + 50.0
	var viewport_w: float = get_viewport().get_visible_rect().size.x
	var spawn_y: float = (
		_camera.get_target_y() - get_viewport().get_visible_rect().size.y / 2.0 + 120.0
	)
	block.position = Vector2(
		_rng.randf_range(margin, viewport_w - margin),
		spawn_y,
	)
	block.block_color = BLOCK_COLORS[_rng.randi() % BLOCK_COLORS.size()]
	block.freeze = true
	block.gravity_scale = 0.0
	block.drag_started.connect(_on_new_block_dragged.bind(block), CONNECT_ONE_SHOT)
	_current_block = block
	_block_container.add_child(block)


func _on_new_block_dragged(block: DraggableBlock) -> void:
	if _state != State.PLAYING:
		return
	block.freeze = false
	block.gravity_scale = 1.0
	get_tree().create_timer(SPAWN_DELAY).timeout.connect(_spawn_block)


func _scan_tower() -> void:
	var highest_y: float = GameplayController.PLATFORM_SURFACE_Y
	var blocks_to_remove: Array[DraggableBlock] = []
	for child: Node in _block_container.get_children():
		if not (child is DraggableBlock):
			continue
		var block: DraggableBlock = child as DraggableBlock
		if not is_instance_valid(block):
			continue
		if _is_out_of_bounds(block):
			blocks_to_remove.append(block)
			continue
		if not block.is_placed:
			continue
		var top_y: float = block.position.y - block.get_bounding_size().y / 2.0
		highest_y = minf(highest_y, top_y)

	for block: DraggableBlock in blocks_to_remove:
		if _state != State.PLAYING:
			break
		if block == _current_block:
			_current_block = null
		Events.block_dropped.emit(block)
		block.queue_free()
		_hp -= 1
		Events.hp_changed.emit(_hp)
		if _hp <= 0:
			_transition_to(State.LOST)
			return

	_tower_height = GameplayController.PLATFORM_SURFACE_Y - highest_y
	if _tower_height > 0.0:
		_camera.update_target(highest_y)
		Events.score_changed.emit(int(_tower_height))
		GameState.current_height = _tower_height
		if _tower_height >= _get_level_target() and _state == State.PLAYING:
			_transition_to(State.WON)


func _freeze_all_blocks() -> void:
	for child: Node in _block_container.get_children():
		if child is DraggableBlock:
			var block: DraggableBlock = child as DraggableBlock
			block.freeze = true
			block.input_pickable = false


func _is_out_of_bounds(block: DraggableBlock) -> bool:
	var margin: float = GameplayController.OUT_OF_BOUNDS_MARGIN
	var pos: Vector2 = block.position
	if pos.y > GameplayController.PLATFORM_SURFACE_Y + margin:
		return true
	if pos.x < -margin or pos.x > GameplayController.VIEWPORT_SIZE.x + margin:
		return true
	return false
