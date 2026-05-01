class_name GameHUD
extends CanvasLayer

const HEART_RADIUS: float = 12.0
const HEART_SEGMENTS: int = 24

var _heart_pips: Array[Control] = []
var _is_win: bool = false
var _level_label: Label = null
var _start_panel: PanelContainer = null

@onready var _heart_1: Label = %Heart1
@onready var _heart_2: Label = %Heart2
@onready var _heart_3: Label = %Heart3
@onready var _heart_4: Label = %Heart4
@onready var _timer_label: Label = %TimerLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _start_button: Button = %StartButton
@onready var _game_over_panel: PanelContainer = %GameOverPanel
@onready var _result_label: Label = %ResultLabel
@onready var _final_score_label: Label = %FinalScoreLabel
@onready var _high_score_label: Label = %HighScoreLabel
@onready var _restart_button: Button = %RestartButton


func _ready() -> void:
	assert(_heart_1 != null, "Heart1 not found")
	assert(_heart_2 != null, "Heart2 not found")
	assert(_heart_3 != null, "Heart3 not found")
	assert(_heart_4 != null, "Heart4 not found")
	assert(_timer_label != null, "TimerLabel not found")
	assert(_score_label != null, "ScoreLabel not found")
	assert(_start_button != null, "StartButton not found")
	assert(_game_over_panel != null, "GameOverPanel not found")
	assert(_result_label != null, "ResultLabel not found")
	assert(_final_score_label != null, "FinalScoreLabel not found")
	assert(_high_score_label != null, "HighScoreLabel not found")
	assert(_restart_button != null, "RestartButton not found")

	var heart_labels: Array[Label] = [_heart_1, _heart_2, _heart_3, _heart_4]
	for heart: Label in heart_labels:
		heart.text = ""
		heart.custom_minimum_size = Vector2(HEART_RADIUS * 2.0 + 4.0, 0.0)
		var pip: Control = _create_pip()
		heart.add_child(pip)
		_heart_pips.append(pip)
	_start_button.visible = false
	_create_level_label()
	_create_start_panel()

	_restart_button.pressed.connect(_on_restart_pressed)

	Events.hp_changed.connect(_on_hp_changed)
	Events.timer_updated.connect(_on_timer_updated)
	Events.score_changed.connect(_on_score_changed)
	Events.game_started.connect(_on_game_started)
	Events.game_ended.connect(_on_game_ended)
	Events.game_restarted.connect(_on_game_restarted)
	Events.level_changed.connect(_on_level_changed)

	_show_menu()


func _show_menu() -> void:
	_start_panel.visible = true
	_game_over_panel.visible = false
	_score_label.visible = false
	_level_label.visible = false
	_timer_label.text = "01:00"
	_timer_label.modulate = Color.WHITE
	_score_label.text = "0"
	for pip: Control in _heart_pips:
		pip.modulate = Color.RED


func _create_level_label() -> void:
	_level_label = Label.new()
	_level_label.text = "Level 1"
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_label.anchors_preset = Control.PRESET_CENTER_TOP
	_level_label.anchor_left = 0.5
	_level_label.anchor_right = 0.5
	_level_label.offset_left = -100.0
	_level_label.offset_right = 100.0
	_level_label.offset_top = 52.0
	_level_label.offset_bottom = 76.0
	_level_label.add_theme_font_size_override(&"font_size", 26)
	_level_label.modulate = Color(1.0, 1.0, 1.0, 0.7)
	_level_label.visible = false
	add_child(_level_label)


func _create_start_panel() -> void:
	_start_panel = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.75)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 32.0
	style.content_margin_right = 32.0
	style.content_margin_top = 28.0
	style.content_margin_bottom = 28.0
	_start_panel.add_theme_stylebox_override(&"panel", style)
	_start_panel.anchors_preset = Control.PRESET_CENTER
	_start_panel.anchor_left = 0.5
	_start_panel.anchor_top = 0.5
	_start_panel.anchor_right = 0.5
	_start_panel.anchor_bottom = 0.5
	_start_panel.offset_left = -160.0
	_start_panel.offset_right = 160.0
	_start_panel.offset_top = -200.0
	_start_panel.offset_bottom = 200.0
	_start_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_start_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_start_panel.add_child(vbox)

	var title: Label = Label.new()
	title.text = "TOWER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 56)
	vbox.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "Stack to the sky"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override(&"font_size", 22)
	subtitle.modulate = Color(1.0, 1.0, 1.0, 0.6)
	vbox.add_child(subtitle)

	var spacer1: Control = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer1)

	var how_title: Label = Label.new()
	how_title.text = "HOW TO PLAY"
	how_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how_title.add_theme_font_size_override(&"font_size", 24)
	vbox.add_child(how_title)

	var instructions: Array[String] = [
		"Drag blocks onto the platform",
		"Stack them to reach the goal line",
		"Blocks that fall off cost a life",
		"Beat the clock to advance!",
	]
	for line: String in instructions:
		var lbl: Label = Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override(&"font_size", 20)
		lbl.modulate = Color(1.0, 1.0, 1.0, 0.8)
		vbox.add_child(lbl)

	var spacer2: Control = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer2)

	var controls_title: Label = Label.new()
	controls_title.text = "CONTROLS"
	controls_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls_title.add_theme_font_size_override(&"font_size", 24)
	vbox.add_child(controls_title)

	var controls: Array[String] = [
		"Click + Drag to move blocks",
		"Q / E to rotate while dragging",
	]
	for line: String in controls:
		var lbl: Label = Label.new()
		lbl.text = line
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override(&"font_size", 20)
		lbl.modulate = Color(1.0, 1.0, 1.0, 0.8)
		vbox.add_child(lbl)

	var spacer3: Control = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer3)

	var play_button: Button = Button.new()
	play_button.text = "PLAY"
	play_button.add_theme_font_size_override(&"font_size", 36)
	play_button.custom_minimum_size = Vector2(200, 50)
	play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	play_button.pressed.connect(_on_start_pressed)
	vbox.add_child(play_button)

	var high_score_label: Label = Label.new()
	high_score_label.text = "Best: %d" % GameState.high_score
	high_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	high_score_label.add_theme_font_size_override(&"font_size", 20)
	high_score_label.modulate = Color(1.0, 1.0, 1.0, 0.5)
	high_score_label.name = &"MenuHighScore"
	vbox.add_child(high_score_label)

	add_child(_start_panel)


func _on_start_pressed() -> void:
	Events.ui_play_pressed.emit()


func _on_restart_pressed() -> void:
	if _is_win:
		Events.ui_next_level_pressed.emit()
	else:
		Events.ui_restart_pressed.emit()


func _on_game_started() -> void:
	_start_panel.visible = false
	_game_over_panel.visible = false
	_score_label.visible = true
	_level_label.visible = true


func _on_level_changed(level: int, _target_height: float) -> void:
	_level_label.text = "Level %d" % level


func _on_hp_changed(new_hp: int) -> void:
	for i: int in range(_heart_pips.size()):
		if i < new_hp:
			_heart_pips[i].modulate = Color.RED
		else:
			_heart_pips[i].modulate = Color.DIM_GRAY


func _on_timer_updated(time_remaining: float) -> void:
	var total_seconds: int = maxi(ceili(time_remaining), 0)
	var mins: int = total_seconds / 60
	var secs: int = total_seconds % 60
	_timer_label.text = "%02d:%02d" % [mins, secs]
	if total_seconds <= 10:
		_timer_label.modulate = Color.RED
	else:
		_timer_label.modulate = Color.WHITE


func _on_score_changed(new_height: int) -> void:
	_score_label.text = str(new_height)


func _on_game_ended(is_win: bool, final_height: float) -> void:
	_is_win = is_win
	if is_win:
		_result_label.text = "LEVEL COMPLETE!"
		_restart_button.text = "NEXT LEVEL"
	else:
		_result_label.text = "GAME OVER"
		_restart_button.text = "RESTART"
	_final_score_label.text = "Height: %d" % int(final_height)
	_high_score_label.text = "Best: %d" % GameState.high_score
	_game_over_panel.visible = true
	_start_panel.visible = false


func _on_game_restarted() -> void:
	var menu_hs: Label = _start_panel.find_child(&"MenuHighScore") as Label
	if menu_hs != null:
		menu_hs.text = "Best: %d" % GameState.high_score
	_show_menu()


func _create_pip() -> Control:
	var pip: HeartPip = HeartPip.new()
	pip.radius = HEART_RADIUS
	pip.segments = HEART_SEGMENTS
	pip.custom_minimum_size = Vector2(HEART_RADIUS * 2.0, HEART_RADIUS * 2.0)
	pip.size = pip.custom_minimum_size
	pip.position = Vector2(2.0, 6.0)
	return pip


static func _get_heart_points(radius: float, segments: int) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments + 1):
		var t: float = TAU * float(i) / float(segments)
		var raw_x: float = 16.0 * pow(sin(t), 3)
		var raw_y: float = (
			13.0 * cos(t)
			- 5.0 * cos(2.0 * t)
			- 2.0 * cos(3.0 * t)
			- cos(4.0 * t)
		)
		points.append(Vector2(raw_x / 16.0, -raw_y / 16.0) * radius)
	return points


class HeartPip:
	extends Control

	var radius: float = 12.0
	var segments: int = 24

	func _draw() -> void:
		var center: Vector2 = size / 2.0 + Vector2(0.0, radius * 0.1)
		var points: PackedVector2Array = GameHUD._get_heart_points(radius, segments)
		var offset_points: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in points:
			offset_points.append(p + center)
		draw_colored_polygon(offset_points, Color.WHITE)
