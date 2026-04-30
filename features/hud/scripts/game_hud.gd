class_name GameHUD
extends CanvasLayer

var _heart_labels: Array[Label] = []

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

	_heart_labels = [_heart_1, _heart_2, _heart_3, _heart_4]

	_start_button.pressed.connect(_on_start_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)

	Events.hp_changed.connect(_on_hp_changed)
	Events.timer_updated.connect(_on_timer_updated)
	Events.score_changed.connect(_on_score_changed)
	Events.game_started.connect(_on_game_started)
	Events.game_ended.connect(_on_game_ended)
	Events.game_restarted.connect(_on_game_restarted)

	_show_menu()


func _show_menu() -> void:
	_start_button.visible = true
	_game_over_panel.visible = false
	_score_label.visible = false
	_timer_label.text = "01:00"
	_timer_label.modulate = Color.WHITE
	_score_label.text = "0"
	for heart: Label in _heart_labels:
		heart.modulate = Color.RED


func _on_start_pressed() -> void:
	Events.ui_play_pressed.emit()


func _on_restart_pressed() -> void:
	Events.ui_restart_pressed.emit()


func _on_game_started() -> void:
	_start_button.visible = false
	_game_over_panel.visible = false
	_score_label.visible = true


func _on_hp_changed(new_hp: int) -> void:
	for i: int in range(_heart_labels.size()):
		if i < new_hp:
			_heart_labels[i].modulate = Color.RED
		else:
			_heart_labels[i].modulate = Color.DIM_GRAY


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
	if is_win:
		_result_label.text = "YOU WIN!"
	else:
		_result_label.text = "GAME OVER"
	_final_score_label.text = "Height: %d" % int(final_height)
	_high_score_label.text = "Best: %d" % GameState.high_score
	_game_over_panel.visible = true
	_start_button.visible = false


func _on_game_restarted() -> void:
	_show_menu()
