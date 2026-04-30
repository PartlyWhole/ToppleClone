extends Node
## Global event bus — cross-system signals only.
## Entity roots and service nodes are the only publishers.

# Game flow
signal game_started
signal game_ended(is_win: bool, final_height: float)
signal game_restarted

# Tower events
signal block_dropped(block: Node2D)
signal score_changed(new_height: int)
signal high_score_beaten(new_high: int)

# Player state
signal hp_changed(new_hp: int)
signal timer_updated(time_remaining: float)

# UI
signal ui_play_pressed
signal ui_restart_pressed
