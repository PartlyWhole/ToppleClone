class_name GameplayController
extends Node2D
## Sets up the play area: base platform and finish line.

const VIEWPORT_SIZE: Vector2 = Vector2(720, 1280)
const PLATFORM_SURFACE_Y: float = 1180.0
const PLATFORM_WIDTH: float = 360.0
const PLATFORM_HEIGHT: float = 80.0
const OUT_OF_BOUNDS_MARGIN: float = 300.0

var _target_height: float = 300.0

@onready var _block_container: Node2D = $BlockContainer


func _ready() -> void:
	assert(_block_container != null, "BlockContainer node not found")
	_create_platform()
	Events.level_changed.connect(_on_level_changed)
	queue_redraw()


func _draw() -> void:
	_draw_finish_line()


func _on_level_changed(_level: int, target_height: float) -> void:
	_target_height = target_height
	queue_redraw()


func _create_platform() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.position = Vector2(
		VIEWPORT_SIZE.x / 2.0,
		PLATFORM_SURFACE_Y + PLATFORM_HEIGHT / 2.0,
	)
	var mat: PhysicsMaterial = PhysicsMaterial.new()
	mat.friction = 0.8
	mat.rough = true
	body.physics_material_override = mat
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(PLATFORM_WIDTH, PLATFORM_HEIGHT)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)

	var visual: ColorRect = ColorRect.new()
	visual.color = Color(0.25, 0.25, 0.3, 1.0)
	visual.size = Vector2(PLATFORM_WIDTH, PLATFORM_HEIGHT)
	visual.position = Vector2(
		(VIEWPORT_SIZE.x - PLATFORM_WIDTH) / 2.0,
		PLATFORM_SURFACE_Y,
	)
	add_child(visual)


func _draw_finish_line() -> void:
	var finish_y: float = PLATFORM_SURFACE_Y - _target_height
	var dash_length: float = 20.0
	var gap_length: float = 10.0
	var line_color: Color = Color(1.0, 0.84, 0.0, 0.6)
	var x: float = 0.0
	while x < VIEWPORT_SIZE.x:
		var end_x: float = minf(x + dash_length, VIEWPORT_SIZE.x)
		draw_line(Vector2(x, finish_y), Vector2(end_x, finish_y), line_color, 2.0)
		x += dash_length + gap_length
	draw_string(
		ThemeDB.fallback_font,
		Vector2(VIEWPORT_SIZE.x / 2.0 - 24.0, finish_y - 8.0),
		"GOAL",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		16,
		Color(1.0, 0.84, 0.0, 0.8),
	)
