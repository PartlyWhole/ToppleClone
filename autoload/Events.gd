extends Node
## Global event bus — cross-system signals only.
## Entity roots and service nodes are the only publishers.

# Game flow
signal game_started
signal game_over(final_height: float)
signal game_restarted

# Tower events
signal block_placed(block: Node2D, height: float)
signal block_dropped(block: Node2D)
signal tower_collapsed

# Score
signal score_changed(new_score: int)
signal high_score_beaten(new_high: int)

# UI
signal ui_play_pressed
signal ui_restart_pressed
