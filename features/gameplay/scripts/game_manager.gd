class_name GameManager
extends Node

enum State { MENU, PLAYING, WON, LOST, RESTARTING }

const MAX_HP: int = 4
const ROUND_TIME: float = 60.0
const TARGET_HEIGHT: float = 600.0
const DROP_THRESHOLD_Y: float = 300.0
const HEIGHT_SCAN_INTERVAL: float = 0.5

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
var _current_block: DraggableBlock = null
var _scan_timer: float = 0.0
var _last_displayed_seconds: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _camera: GameCamera = _find_camera()
@onready var _block_container: Node2D = _find_block_container()
@onready var _platform_surface_y: float = _find_platform_surface_y()


func _ready() -> void:
	assert(_camera != null, "GameCamera not found as sibling")
	assert(_block_container != null, "BlockContainer not found as sibling")
	set_process(false)
	Events.ui_play_pressed.connect(_on_play_pressed)
	Events.ui_restart_pressed.connect(_on_restart_pressed)


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
	_hp = MAX_HP
	_time_remaining = ROUND_TIME
	_last_displayed_seconds = -1
	_scan_timer = 0.0
	_transition_to(State.PLAYING)
	Events.game_started.emit()
	Events.hp_changed.emit(_hp)
	Events.timer_updated.emit(_time_remaining)
	_spawn_block()


func _on_restart_pressed() -> void:
	if _state == State.RESTARTING:
		return
	_restart()


func _transition_to(new_state: State) -> void:
	_state = new_state
	match new_state:
		State.PLAYING:
			set_process(true)
			_camera.set_process(true)
			GameState.is_playing = true
		State.WON:
			set_process(false)
			_camera.set_process(false)
			GameState.is_playing = false
			_freeze_all_blocks()
			Events.game_ended.emit(true, _get_tower_height())
		State.LOST:
			set_process(false)
			_camera.set_process(false)
			GameState.is_playing = false
			_freeze_all_blocks()
			Events.game_ended.emit(false, _get_tower_height())
		State.MENU:
			set_process(false)
			_camera.set_process(false)
			GameState.is_playing = false
		State.RESTARTING:
			set_process(false)


func _restart() -> void:
	_transition_to(State.RESTARTING)
	if is_instance_valid(_current_block):
		_current_block = null
	for child: Node in _block_container.get_children():
		child.queue_free()
	_hp = MAX_HP
	_time_remaining = ROUND_TIME
	_last_displayed_seconds = -1
	_scan_timer = 0.0
	_camera.reset()
	Events.game_restarted.emit()
	_transition_to(State.MENU)


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
	_spawn_block()


func _scan_tower() -> void:
	var highest_y: float = _platform_surface_y
	var blocks_to_remove: Array[DraggableBlock] = []
	for child: Node in _block_container.get_children():
		if not (child is DraggableBlock):
			continue
		var block: DraggableBlock = child as DraggableBlock
		if not is_instance_valid(block):
			continue
		if block == _current_block and block.freeze:
			continue
		if block.position.y > _platform_surface_y + DROP_THRESHOLD_Y:
			blocks_to_remove.append(block)
			continue
		var top_y: float = block.position.y - block.get_bounding_size().y / 2.0
		highest_y = minf(highest_y, top_y)

	for block: DraggableBlock in blocks_to_remove:
		if _state != State.PLAYING:
			break
		if block == _current_block:
			_current_block = null
		block.queue_free()
		_hp -= 1
		Events.hp_changed.emit(_hp)
		Events.block_dropped.emit(block)
		if _hp <= 0:
			_transition_to(State.LOST)
			return

	var tower_height: float = _platform_surface_y - highest_y
	if tower_height > 0.0:
		_camera.update_target(highest_y)
		Events.score_changed.emit(int(tower_height))
		GameState.current_height = tower_height
		if tower_height >= TARGET_HEIGHT and _state == State.PLAYING:
			_transition_to(State.WON)


func _get_tower_height() -> float:
	var highest_y: float = _platform_surface_y
	for child: Node in _block_container.get_children():
		if not (child is DraggableBlock):
			continue
		var block: DraggableBlock = child as DraggableBlock
		if not is_instance_valid(block):
			continue
		var top_y: float = block.position.y - block.get_bounding_size().y / 2.0
		highest_y = minf(highest_y, top_y)
	return _platform_surface_y - highest_y


func _freeze_all_blocks() -> void:
	for child: Node in _block_container.get_children():
		if child is DraggableBlock:
			var block: DraggableBlock = child as DraggableBlock
			block.freeze = true
			block.input_pickable = false


func _find_camera() -> GameCamera:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is GameCamera:
			return child as GameCamera
	return null


func _find_block_container() -> Node2D:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child.name == &"BlockContainer" and child is Node2D:
			return child as Node2D
	return null


func _find_platform_surface_y() -> float:
	var parent: Node = get_parent()
	if parent != null and "PLATFORM_SURFACE_Y" in parent:
		return parent.get("PLATFORM_SURFACE_Y") as float
	return 1180.0
