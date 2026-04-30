class_name EditorState
extends RefCounted
## Pure state tracker for the shape editor. Not a Node because it needs no
## tree interaction, processing, or signals — just data and transitions.

enum State { IDLE, DRAWING, CLOSED, PREVIEWING, EDITING }

var current: State = State.IDLE
var vertices: PackedVector2Array = PackedVector2Array()
var preview_name: StringName = &""


func start_drawing(pos: Vector2) -> void:
	current = State.DRAWING
	vertices = PackedVector2Array([pos])
	preview_name = &""


func add_vertex(pos: Vector2) -> void:
	assert(current == State.DRAWING)
	vertices.append(pos)


func undo_vertex() -> void:
	assert(current == State.DRAWING)
	if vertices.size() > 1:
		vertices = vertices.slice(0, vertices.size() - 1)
	elif vertices.size() == 1:
		clear()


func can_close() -> bool:
	return current == State.DRAWING and vertices.size() >= 3


func close_polygon() -> bool:
	if not can_close():
		return false
	if _has_self_intersection():
		return false
	if not Geometry2D.is_polygon_clockwise(vertices):
		vertices.reverse()
	current = State.CLOSED
	return true


func clear() -> void:
	current = State.IDLE
	vertices = PackedVector2Array()
	preview_name = &""


func start_preview(shape_name: StringName) -> void:
	current = State.PREVIEWING
	vertices = BlockShapes.get_vertices(shape_name)
	preview_name = shape_name


func start_editing() -> void:
	assert(current == State.PREVIEWING)
	current = State.EDITING


func move_vertex(index: int, pos: Vector2) -> void:
	assert(current == State.EDITING)
	assert(index >= 0 and index < vertices.size())
	vertices[index] = pos


func insert_vertex(edge_index: int, pos: Vector2) -> void:
	assert(current == State.EDITING)
	assert(edge_index >= 0 and edge_index < vertices.size())
	vertices = (
		vertices.slice(0, edge_index + 1)
		+ PackedVector2Array([pos])
		+ vertices.slice(edge_index + 1)
	)


func remove_vertex(index: int) -> void:
	assert(current == State.EDITING)
	if vertices.size() <= 3:
		return
	vertices = vertices.slice(0, index) + vertices.slice(index + 1)


func finish_editing() -> bool:
	assert(current == State.EDITING)
	if vertices.size() < 3:
		return false
	if _has_self_intersection():
		return false
	if not Geometry2D.is_polygon_clockwise(vertices):
		vertices.reverse()
	current = State.CLOSED
	return true


func _has_self_intersection() -> bool:
	var n: int = vertices.size()
	if n < 4:
		return false
	for i: int in n:
		var a1: Vector2 = vertices[i]
		var a2: Vector2 = vertices[(i + 1) % n]
		for j: int in range(i + 2, n):
			if i == 0 and j == n - 1:
				continue
			var b1: Vector2 = vertices[j]
			var b2: Vector2 = vertices[(j + 1) % n]
			var result: Variant = Geometry2D.segment_intersects_segment(a1, a2, b1, b2)
			if result != null:
				return true
	return false
