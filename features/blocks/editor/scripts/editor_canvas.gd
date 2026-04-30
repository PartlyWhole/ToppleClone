class_name EditorCanvas
extends Control

signal vertex_placed(pos: Vector2)
signal close_requested
signal undo_requested
signal editing_done
signal vertex_moved(index: int, pos: Vector2)
signal vertex_inserted(edge_index: int, pos: Vector2)
signal vertex_removed(index: int)

const HALF_CELL: float = BlockShapes.CELL_SIZE / 2.0
const CLOSE_THRESHOLD_SQ: float = 15.0 * 15.0
const GRAB_RADIUS_SQ: float = 64.0
const EDGE_SNAP_DIST_SQ: float = 100.0
const GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.15)
const HALF_GRID_COLOR: Color = Color(1.0, 1.0, 1.0, 0.07)
const VERTEX_COLOR: Color = Color.WHITE
const LINE_COLOR: Color = Color.WHITE
const RUBBER_BAND_COLOR: Color = Color(1.0, 1.0, 1.0, 0.5)
const CLOSE_HIGHLIGHT_COLOR: Color = Color(0.0, 1.0, 0.0, 0.5)
const FILL_COLOR: Color = Color(0.3, 0.6, 1.0, 0.4)
const HOVER_COLOR: Color = Color(1.0, 0.8, 0.2, 0.8)
const EDGE_HOVER_COLOR: Color = Color(0.2, 1.0, 0.5, 0.5)
const VERTEX_RADIUS: float = 4.0
const EDIT_VERTEX_RADIUS: float = 6.0
const LINE_WIDTH: float = 2.0

var state: EditorState = null
var _cursor_pos: Vector2 = Vector2.ZERO
var _canvas_center: Vector2 = Vector2.ZERO
var _grid_offset: Vector2 = Vector2.ZERO
var _drag_index: int = -1
var _hovered_vertex: int = -1
var _hovered_edge: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	_canvas_center = size / 2.0
	_grid_offset = Vector2(fmod(_canvas_center.x, HALF_CELL), fmod(_canvas_center.y, HALF_CELL))


func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	if state.current == EditorState.State.EDITING:
		_handle_editing_input(event)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				_handle_left_click(mb.position)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				undo_requested.emit()
				accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_cursor_pos = _snap_to_shape(mm.position)
		queue_redraw()
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_BACKSPACE:
				undo_requested.emit()
				accept_event()
			elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				close_requested.emit()
				accept_event()


func _draw() -> void:
	_draw_grid()
	if state == null:
		return
	match state.current:
		EditorState.State.DRAWING:
			_draw_polygon_edges()
			_draw_rubber_band()
			_draw_close_indicator()
			_draw_vertices()
		EditorState.State.CLOSED, EditorState.State.PREVIEWING:
			_draw_filled_polygon()
			_draw_polygon_edges()
			_draw_vertices()
		EditorState.State.EDITING:
			_draw_filled_polygon()
			_draw_polygon_edges()
			_draw_edge_hover()
			_draw_editing_vertices()


func _snap_to_shape(canvas_pos: Vector2) -> Vector2:
	return (canvas_pos - _canvas_center).snappedf(HALF_CELL)


func _to_canvas(shape_pos: Vector2) -> Vector2:
	return shape_pos + _canvas_center


func _handle_left_click(raw_pos: Vector2) -> void:
	if state == null:
		return
	var shape_pos: Vector2 = _snap_to_shape(raw_pos)
	if state.current == EditorState.State.IDLE:
		vertex_placed.emit(shape_pos)
		return
	if state.current != EditorState.State.DRAWING:
		return
	if state.vertices.size() >= 3:
		if shape_pos.distance_squared_to(state.vertices[0]) < CLOSE_THRESHOLD_SQ:
			close_requested.emit()
			return
	vertex_placed.emit(shape_pos)


func _handle_editing_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var vi: int = _find_nearest_vertex(mb.position)
				if vi >= 0:
					_drag_index = vi
				else:
					var ei: int = _find_nearest_edge(mb.position)
					if ei >= 0:
						vertex_inserted.emit(ei, _snap_to_shape(mb.position))
			else:
				if _drag_index >= 0:
					vertex_moved.emit(_drag_index, _snap_to_shape(mb.position))
					_drag_index = -1
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var vi: int = _find_nearest_vertex(mb.position)
			if vi >= 0:
				vertex_removed.emit(vi)
			accept_event()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_cursor_pos = mm.position
		if _drag_index >= 0 and state != null:
			vertex_moved.emit(_drag_index, _snap_to_shape(mm.position))
		_update_hover(mm.position)
		queue_redraw()
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo:
			if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
				editing_done.emit()
				accept_event()


func _find_nearest_vertex(canvas_pos: Vector2) -> int:
	if state == null:
		return -1
	var best_index: int = -1
	var best_dist_sq: float = GRAB_RADIUS_SQ
	for i: int in state.vertices.size():
		var dist_sq: float = canvas_pos.distance_squared_to(_to_canvas(state.vertices[i]))
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index


func _find_nearest_edge(canvas_pos: Vector2) -> int:
	if state == null or state.vertices.size() < 2:
		return -1
	var best_index: int = -1
	var best_dist_sq: float = EDGE_SNAP_DIST_SQ
	var n: int = state.vertices.size()
	for i: int in n:
		var a: Vector2 = _to_canvas(state.vertices[i])
		var b: Vector2 = _to_canvas(state.vertices[(i + 1) % n])
		var dist_sq: float = _point_to_segment_dist_sq(canvas_pos, a, b)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_index = i
	return best_index


func _point_to_segment_dist_sq(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.001:
		return p.distance_squared_to(a)
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var proj: Vector2 = a + ab * t
	return p.distance_squared_to(proj)


func _update_hover(pos: Vector2) -> void:
	_hovered_vertex = _find_nearest_vertex(pos)
	_hovered_edge = -1
	if _hovered_vertex < 0:
		_hovered_edge = _find_nearest_edge(pos)


func _draw_grid() -> void:
	var w: float = size.x
	var h: float = size.y
	var x: float = _grid_offset.x
	while x <= w:
		var is_major: bool = is_zero_approx(fmod(x - _grid_offset.x, BlockShapes.CELL_SIZE))
		draw_line(Vector2(x, 0.0), Vector2(x, h), GRID_COLOR if is_major else HALF_GRID_COLOR, 1.0)
		x += HALF_CELL
	var y: float = _grid_offset.y
	while y <= h:
		var is_major: bool = is_zero_approx(fmod(y - _grid_offset.y, BlockShapes.CELL_SIZE))
		draw_line(Vector2(0.0, y), Vector2(w, y), GRID_COLOR if is_major else HALF_GRID_COLOR, 1.0)
		y += HALF_CELL


func _draw_polygon_edges() -> void:
	var verts: PackedVector2Array = state.vertices
	for i: int in range(verts.size() - 1):
		draw_line(_to_canvas(verts[i]), _to_canvas(verts[i + 1]), LINE_COLOR, LINE_WIDTH)
	if (
		state.current
		in [
			EditorState.State.CLOSED,
			EditorState.State.PREVIEWING,
			EditorState.State.EDITING,
		]
	):
		if verts.size() >= 3:
			draw_line(
				_to_canvas(verts[verts.size() - 1]), _to_canvas(verts[0]), LINE_COLOR, LINE_WIDTH
			)


func _draw_rubber_band() -> void:
	if state.vertices.is_empty():
		return
	var last: Vector2 = _to_canvas(state.vertices[state.vertices.size() - 1])
	draw_line(last, _to_canvas(_cursor_pos), RUBBER_BAND_COLOR, 1.0)


func _draw_close_indicator() -> void:
	if state.vertices.size() < 3:
		return
	if _cursor_pos.distance_squared_to(state.vertices[0]) < CLOSE_THRESHOLD_SQ:
		draw_circle(_to_canvas(state.vertices[0]), 8.0, CLOSE_HIGHLIGHT_COLOR)


func _draw_vertices() -> void:
	for vertex: Vector2 in state.vertices:
		draw_circle(_to_canvas(vertex), VERTEX_RADIUS, VERTEX_COLOR)


func _draw_editing_vertices() -> void:
	for i: int in state.vertices.size():
		var color: Color = HOVER_COLOR if i == _hovered_vertex else VERTEX_COLOR
		var radius: float = EDIT_VERTEX_RADIUS + 2.0 if i == _hovered_vertex else EDIT_VERTEX_RADIUS
		draw_circle(_to_canvas(state.vertices[i]), radius, color)


func _draw_edge_hover() -> void:
	if _hovered_edge < 0 or _hovered_vertex >= 0:
		return
	var n: int = state.vertices.size()
	var a: Vector2 = _to_canvas(state.vertices[_hovered_edge])
	var b: Vector2 = _to_canvas(state.vertices[(_hovered_edge + 1) % n])
	draw_line(a, b, EDGE_HOVER_COLOR, LINE_WIDTH + 2.0)


func _draw_filled_polygon() -> void:
	if state.vertices.size() >= 3:
		var canvas_verts: PackedVector2Array = PackedVector2Array()
		for v: Vector2 in state.vertices:
			canvas_verts.append(_to_canvas(v))
		draw_colored_polygon(canvas_verts, FILL_COLOR)
