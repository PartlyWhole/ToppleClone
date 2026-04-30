extends Node2D
## Spawns draggable blocks and creates screen boundary walls.

const WALL_THICKNESS: float = 20.0
const VIEWPORT_SIZE: Vector2 = Vector2(720, 1280)
const BLOCK_COLORS: Array[Color] = [
	Color.CORNFLOWER_BLUE,
	Color.CORAL,
	Color.MEDIUM_SEA_GREEN,
	Color.GOLD,
	Color.MEDIUM_PURPLE,
	Color.TOMATO,
	Color.DARK_TURQUOISE,
]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_create_boundaries()
	_spawn_initial_blocks()


func _create_boundaries() -> void:
	_add_wall(
		Vector2(VIEWPORT_SIZE.x / 2.0, VIEWPORT_SIZE.y + WALL_THICKNESS / 2.0),
		Vector2(VIEWPORT_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	_add_wall(
		Vector2(VIEWPORT_SIZE.x / 2.0, -WALL_THICKNESS / 2.0),
		Vector2(VIEWPORT_SIZE.x + WALL_THICKNESS * 2.0, WALL_THICKNESS)
	)
	_add_wall(
		Vector2(-WALL_THICKNESS / 2.0, VIEWPORT_SIZE.y / 2.0),
		Vector2(WALL_THICKNESS, VIEWPORT_SIZE.y)
	)
	_add_wall(
		Vector2(VIEWPORT_SIZE.x + WALL_THICKNESS / 2.0, VIEWPORT_SIZE.y / 2.0),
		Vector2(WALL_THICKNESS, VIEWPORT_SIZE.y)
	)


func _add_wall(pos: Vector2, size: Vector2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = pos
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _spawn_initial_blocks() -> void:
	var all_names: Array[StringName] = BlockShapes.get_all_names()
	if all_names.is_empty():
		push_error("No shapes loaded — check features/blocks/shapes/ directory")
		return
	for i: int in range(12):
		var block: DraggableBlock = DraggableBlock.new()
		block.shape_type = all_names[_rng.randi() % all_names.size()]
		var bounds: Vector2 = BlockShapes.get_bounding_size(block.shape_type)
		var margin: float = maxf(bounds.x, bounds.y) / 2.0 + 50.0
		block.position = Vector2(
			_rng.randf_range(margin, VIEWPORT_SIZE.x - margin),
			100.0 + i * 100.0,
		)
		block.block_color = BLOCK_COLORS[i % BLOCK_COLORS.size()]
		add_child(block)
