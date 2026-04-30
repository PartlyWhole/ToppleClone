extends Node
## Manages persistent game state (high score, current height).

var high_score: int = 0
var current_height: float = 0.0
var is_playing: bool = false


func _ready() -> void:
	Events.game_started.connect(_on_game_started)
	Events.game_ended.connect(_on_game_ended)
	Events.game_restarted.connect(_on_game_restarted)
	_load_high_score()


func _on_game_started() -> void:
	is_playing = true
	current_height = 0.0


func _on_game_ended(_is_win: bool, final_height: float) -> void:
	is_playing = false
	current_height = final_height
	var height_score: int = int(final_height)
	if height_score > high_score:
		high_score = height_score
		Events.high_score_beaten.emit(high_score)
		_save_high_score()


func _on_game_restarted() -> void:
	current_height = 0.0
	is_playing = false


func _save_high_score() -> void:
	var file: FileAccess = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	if file:
		file.store_var(high_score)


func _load_high_score() -> void:
	if FileAccess.file_exists("user://highscore.save"):
		var file: FileAccess = FileAccess.open("user://highscore.save", FileAccess.READ)
		if file:
			high_score = file.get_var() as int
