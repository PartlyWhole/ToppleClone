extends Node

signal editor_requested

const BLOCK_GROUP: StringName = &"tunable_blocks"
const PANEL_WIDTH: float = 500.0
const BG_COLOR: Color = Color(0.1, 0.1, 0.1, 0.85)
const LABEL_COLOR: Color = Color.WHITE
const HEADER_COLOR: Color = Color.LIGHT_GRAY

const PARAMS: Array[Dictionary] = [
	{
		"name": &"max_drag_speed",
		"min": 0.0,
		"max": 2000.0,
		"step": 10.0,
		"group": "Drag",
	},
	{"name": &"contact_dampen_sideways", "min": 0.0, "max": 1.0, "step": 0.05},
	{"name": &"contact_dampen_downward", "min": 0.0, "max": 1.0, "step": 0.05},
	{
		"name": &"downward_normal_threshold",
		"min": -1.0,
		"max": 0.0,
		"step": 0.05,
	},
	{"name": &"lock_rotation_while_dragging", "type": &"bool"},
	{
		"name": &"max_block_speed",
		"min": 0.0,
		"max": 2000.0,
		"step": 10.0,
		"group": "Physics Caps",
	},
	{"name": &"max_angular_speed", "min": 0.0, "max": 20.0, "step": 0.5},
	{"name": &"mass", "min": 0.1, "max": 50.0, "step": 0.1, "group": "Body"},
	{"name": &"angular_damp", "min": 0.0, "max": 20.0, "step": 0.5},
	{"name": &"gravity_scale", "min": 0.0, "max": 5.0, "step": 0.1},
	{"name": &"linear_damp", "min": 0.0, "max": 20.0, "step": 0.5},
]

var _panel: PanelContainer
var _is_visible: bool = false
var _defaults: Dictionary = {}


func _ready() -> void:
	print("DebugPanel loaded")
	_read_defaults()
	_build_ui()
	_panel.visible = false
	assert(_panel != null)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_5 and key.shift_pressed:
			print("TOGGLE")
			_is_visible = not _is_visible
			_panel.visible = _is_visible
			get_viewport().set_input_as_handled()


func _read_defaults() -> void:
	var ref: DraggableBlock = DraggableBlock.new()
	for param: Dictionary in PARAMS:
		var param_name: StringName = param["name"] as StringName
		_defaults[param_name] = ref.get(param_name)
	ref.queue_free()


func _build_ui() -> void:
	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.layer = 100
	add_child(canvas_layer)

	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	canvas_layer.add_child(_panel)
	var viewport_size: Vector2 = Vector2(720, 1280)
	_panel.position = Vector2((viewport_size.x - PANEL_WIDTH) / 2.0, 0)
	_panel.size = Vector2(PANEL_WIDTH, viewport_size.y)
	_apply_panel_style(_panel)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	var title: Label = Label.new()
	title.text = "Debug Tuning"
	title.add_theme_font_size_override(&"font_size", 28)
	title.add_theme_color_override(&"font_color", LABEL_COLOR)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for param: Dictionary in PARAMS:
		if param.has("group"):
			_add_group_header(vbox, param["group"] as String)
		var is_bool: bool = param.get("type", &"") == &"bool"
		if is_bool:
			_add_checkbox_row(vbox, param)
		else:
			_add_slider_row(vbox, param)

	vbox.add_child(HSeparator.new())
	var reset_btn: Button = Button.new()
	reset_btn.text = "Reset All"
	reset_btn.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_btn)

	var editor_btn: Button = Button.new()
	editor_btn.text = "Shape Editor"
	editor_btn.pressed.connect(editor_requested.emit)
	vbox.add_child(editor_btn)


func _apply_panel_style(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_content_margin_all(8.0)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override(&"panel", style)


func _add_group_header(parent: VBoxContainer, group_name: String) -> void:
	var label: Label = Label.new()
	label.text = group_name
	label.add_theme_font_size_override(&"font_size", 22)
	label.add_theme_color_override(&"font_color", HEADER_COLOR)
	parent.add_child(label)


func _add_slider_row(parent: VBoxContainer, param: Dictionary) -> void:
	var param_name: StringName = param["name"] as StringName
	var row: HBoxContainer = HBoxContainer.new()
	parent.add_child(row)

	var label: Label = Label.new()
	label.text = String(param_name)
	label.custom_minimum_size.x = 120.0
	label.add_theme_color_override(&"font_color", LABEL_COLOR)
	label.add_theme_font_size_override(&"font_size", 18)

	var slider: HSlider = HSlider.new()
	slider.min_value = param["min"] as float
	slider.max_value = param["max"] as float
	slider.step = param["step"] as float
	slider.value = _defaults.get(param_name, 0.0) as float
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 80.0

	var value_label: Label = Label.new()
	value_label.text = "%.2f" % slider.value
	value_label.custom_minimum_size.x = 50.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override(&"font_color", LABEL_COLOR)
	value_label.add_theme_font_size_override(&"font_size", 18)

	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)

	slider.value_changed.connect(
		func(val: float) -> void:
			value_label.text = "%.2f" % val
			_apply_param(param_name, val)
	)


func _add_checkbox_row(parent: VBoxContainer, param: Dictionary) -> void:
	var param_name: StringName = param["name"] as StringName
	var checkbox: CheckBox = CheckBox.new()
	checkbox.text = String(param_name)
	checkbox.button_pressed = _defaults.get(param_name, false) as bool
	checkbox.add_theme_color_override(&"font_color", LABEL_COLOR)
	checkbox.add_theme_font_size_override(&"font_size", 18)
	parent.add_child(checkbox)

	checkbox.toggled.connect(func(val: bool) -> void: _apply_param(param_name, val))


func _apply_param(param_name: StringName, value: Variant) -> void:
	for node: Node in get_tree().get_nodes_in_group(BLOCK_GROUP):
		if is_instance_valid(node):
			node.set(param_name, value)


func _on_reset_pressed() -> void:
	for param_name: StringName in _defaults:
		_apply_param(param_name, _defaults[param_name])
	_rebuild_slider_values()


func _rebuild_slider_values() -> void:
	var ref: DraggableBlock = DraggableBlock.new()
	for param: Dictionary in PARAMS:
		var param_name: StringName = param["name"] as StringName
		_defaults[param_name] = ref.get(param_name)
	ref.queue_free()
	var old_visible: bool = _is_visible
	for child: Node in get_children():
		child.queue_free()
	call_deferred(&"_build_ui")
	_is_visible = old_visible
	call_deferred(&"_restore_visibility")


func _restore_visibility() -> void:
	_panel.visible = _is_visible
