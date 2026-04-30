class_name ShapeEditor
extends Node

signal back_requested

const BG_COLOR: Color = Color(0.12, 0.12, 0.14, 1.0)
const PANEL_BG: Color = Color(0.15, 0.15, 0.18, 1.0)
const NAME_REGEX: String = "^[a-z][a-z0-9_]{0,31}$"
const SIDE_PANEL_WIDTH: float = 180.0

var _state: EditorState = EditorState.new()
var _canvas: EditorCanvas = null
var _name_input: LineEdit = null
var _save_btn: Button = null
var _edit_btn: Button = null
var _done_btn: Button = null
var _status_label: Label = null
var _shape_list: VBoxContainer = null
var _undo_btn: Button = null
var _regex: RegEx = RegEx.new()
var _pending_delete: StringName = &""


func _ready() -> void:
	_regex.compile(NAME_REGEX)
	_build_ui()
	_refresh_shape_list()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = BG_COLOR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root_layout: HBoxContainer = HBoxContainer.new()
	root_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_layout)

	var left_panel: VBoxContainer = _build_left_panel()
	root_layout.add_child(left_panel)

	var right_panel: VBoxContainer = _build_right_panel()
	right_panel.custom_minimum_size = Vector2(SIDE_PANEL_WIDTH, 0.0)
	root_layout.add_child(right_panel)


func _build_left_panel() -> VBoxContainer:
	var panel: VBoxContainer = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_canvas = EditorCanvas.new()
	_canvas.state = _state
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.vertex_placed.connect(_on_vertex_placed)
	_canvas.close_requested.connect(_on_close_requested)
	_canvas.undo_requested.connect(_on_undo_requested)
	_canvas.editing_done.connect(_on_editing_done)
	_canvas.vertex_moved.connect(_on_vertex_moved)
	_canvas.vertex_inserted.connect(_on_vertex_inserted)
	_canvas.vertex_removed.connect(_on_vertex_removed)
	panel.add_child(_canvas)

	var toolbar: HBoxContainer = HBoxContainer.new()
	panel.add_child(toolbar)

	_undo_btn = Button.new()
	_undo_btn.text = "Undo"
	_undo_btn.pressed.connect(_on_undo_requested)
	toolbar.add_child(_undo_btn)

	var clear_btn: Button = Button.new()
	clear_btn.text = "Clear"
	clear_btn.pressed.connect(_on_clear)
	toolbar.add_child(clear_btn)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "shape_name"
	_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(_name_input)

	_save_btn = Button.new()
	_save_btn.text = "Save"
	_save_btn.pressed.connect(_on_save)
	toolbar.add_child(_save_btn)

	_edit_btn = Button.new()
	_edit_btn.text = "Edit"
	_edit_btn.pressed.connect(_on_edit_pressed)
	toolbar.add_child(_edit_btn)

	_done_btn = Button.new()
	_done_btn.text = "Done"
	_done_btn.pressed.connect(_on_editing_done)
	toolbar.add_child(_done_btn)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override(&"font_size", 14)
	panel.add_child(_status_label)

	return panel


func _build_right_panel() -> VBoxContainer:
	var panel: VBoxContainer = VBoxContainer.new()

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_content_margin_all(6.0)
	var panel_container: PanelContainer = PanelContainer.new()
	panel_container.add_theme_stylebox_override(&"panel", style)
	panel_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(panel_container)

	var inner: VBoxContainer = VBoxContainer.new()
	panel_container.add_child(inner)

	var title: Label = Label.new()
	title.text = "Shapes"
	title.add_theme_font_size_override(&"font_size", 20)
	inner.add_child(title)
	inner.add_child(HSeparator.new())

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)

	_shape_list = VBoxContainer.new()
	scroll.add_child(_shape_list)

	inner.add_child(HSeparator.new())

	var is_standalone: bool = get_parent() == get_tree().root
	if not is_standalone:
		var back_btn: Button = Button.new()
		back_btn.text = "Back to Game"
		back_btn.pressed.connect(func() -> void: back_requested.emit())
		inner.add_child(back_btn)

	return panel


func _refresh_shape_list() -> void:
	for child: Node in _shape_list.get_children():
		child.queue_free()
	var all_names: Array[StringName] = BlockShapes.get_all_names()
	all_names.sort()
	for shape_name: StringName in all_names:
		var row: HBoxContainer = HBoxContainer.new()
		var label_btn: Button = Button.new()
		label_btn.text = String(shape_name)
		label_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label_btn.pressed.connect(_on_preview_shape.bind(shape_name))
		row.add_child(label_btn)

		var del_btn: Button = Button.new()
		del_btn.text = "X"
		del_btn.pressed.connect(_on_delete_shape.bind(shape_name))
		row.add_child(del_btn)

		_shape_list.add_child(row)


func _on_vertex_placed(pos: Vector2) -> void:
	_pending_delete = &""
	if _state.current == EditorState.State.IDLE:
		_state.start_drawing(pos)
	elif _state.current == EditorState.State.DRAWING:
		_state.add_vertex(pos)
	_canvas.queue_redraw()
	_set_status("")


func _on_close_requested() -> void:
	_pending_delete = &""
	if not _state.can_close():
		_set_status("Need at least 3 vertices to close")
		return
	if _state.close_polygon():
		_set_status("Polygon closed. Enter a name and save.")
		_canvas.queue_redraw()
	else:
		_set_status("Self-intersecting polygon — fix vertices")


func _on_undo_requested() -> void:
	_pending_delete = &""
	if _state.current == EditorState.State.DRAWING:
		_state.undo_vertex()
		_canvas.queue_redraw()
		_set_status("")


func _on_clear() -> void:
	_pending_delete = &""
	_state.clear()
	_canvas.queue_redraw()
	_set_status("")


func _on_save() -> void:
	_pending_delete = &""
	if _state.current != EditorState.State.CLOSED:
		_set_status("Close the polygon first")
		return
	var shape_name: String = _name_input.text.strip_edges()
	if _regex.search(shape_name) == null:
		_set_status("Invalid name: use a-z, 0-9, underscore (start with letter)")
		return
	var sn: StringName = StringName(shape_name)
	if BlockShapes.has_shape(sn):
		_set_status("Overwriting existing shape: " + shape_name)

	var verts: PackedVector2Array = _center_vertices(_state.vertices)
	var area: float = _compute_area(verts)
	if area < 1.0:
		_set_status("Shape has zero area — add more vertices")
		return

	var convex_parts: Array[PackedVector2Array] = []
	for part: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(verts):
		convex_parts.append(part)
	if convex_parts.is_empty():
		_set_status("Convex decomposition failed")
		return

	var err: Error = ShapeFileIO.save_shape(shape_name, verts, convex_parts)
	if err != OK:
		_set_status("Save failed: " + error_string(err))
		return

	BlockShapes.reload()
	_refresh_shape_list()
	_state.clear()
	_canvas.queue_redraw()
	_set_status("Saved: " + shape_name)


func _on_preview_shape(shape_name: StringName) -> void:
	_pending_delete = &""
	_state.start_preview(shape_name)
	_canvas.queue_redraw()
	_set_status("Previewing: " + shape_name)


func _on_delete_shape(shape_name: StringName) -> void:
	if _pending_delete != shape_name:
		_pending_delete = shape_name
		_set_status("Click X again to confirm deleting: " + shape_name)
		return
	_pending_delete = &""
	var err: Error = ShapeFileIO.delete_shape(String(shape_name))
	if err != OK:
		_set_status("Delete failed: " + error_string(err))
		return
	BlockShapes.reload()
	_refresh_shape_list()
	if _state.preview_name == shape_name:
		_state.clear()
		_canvas.queue_redraw()
	_set_status("Deleted: " + shape_name)


func _set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text


func _on_edit_pressed() -> void:
	_pending_delete = &""
	if _state.current != EditorState.State.PREVIEWING:
		return
	_state.start_editing()
	_canvas.queue_redraw()
	_set_status("Editing: drag vertices, click edges to insert, right-click to remove")


func _on_editing_done() -> void:
	_pending_delete = &""
	if _state.current != EditorState.State.EDITING:
		return
	if _state.finish_editing():
		_name_input.text = String(_state.preview_name)
		_canvas.queue_redraw()
		_set_status("Edit complete. Save to keep changes.")
	else:
		_set_status("Invalid polygon — fix self-intersections or add vertices")


func _on_vertex_moved(index: int, pos: Vector2) -> void:
	if _state.current == EditorState.State.EDITING:
		_state.move_vertex(index, pos)
		_canvas.queue_redraw()


func _on_vertex_inserted(edge_index: int, pos: Vector2) -> void:
	if _state.current == EditorState.State.EDITING:
		_state.insert_vertex(edge_index, pos)
		_canvas.queue_redraw()


func _on_vertex_removed(index: int) -> void:
	if _state.current == EditorState.State.EDITING:
		_state.remove_vertex(index)
		_canvas.queue_redraw()


func _center_vertices(verts: PackedVector2Array) -> PackedVector2Array:
	if verts.is_empty():
		return verts
	var centroid: Vector2 = Vector2.ZERO
	for v: Vector2 in verts:
		centroid += v
	centroid /= float(verts.size())
	centroid = centroid.snappedf(BlockShapes.CELL_SIZE / 2.0)
	var centered: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in verts:
		centered.append(v - centroid)
	return centered


func _compute_area(verts: PackedVector2Array) -> float:
	var area: float = 0.0
	var n: int = verts.size()
	for i: int in n:
		var j: int = (i + 1) % n
		area += verts[i].x * verts[j].y - verts[j].x * verts[i].y
	return absf(area) / 2.0
