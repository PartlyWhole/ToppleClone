extends Node2D
## Entry point — manages game states and scene transitions.

const _DEBUG_PATH: String = "res://features/debug/scripts/debug_panel.gd"
const DebugPanelScript: GDScript = preload(_DEBUG_PATH)

const _EDITOR_PATH: String = "res://features/blocks/editor/shape_editor.tscn"
const EditorScene: PackedScene = preload(_EDITOR_PATH)

var _editor: Node = null

@onready var _gameplay: Node2D = $GameplayController


func _ready() -> void:
	var debug_panel: Node = DebugPanelScript.new()
	debug_panel.connect(&"editor_requested", switch_to_editor)
	add_child(debug_panel)


func switch_to_editor() -> void:
	_gameplay.visible = false
	_gameplay.process_mode = Node.PROCESS_MODE_DISABLED
	var editor: ShapeEditor = EditorScene.instantiate() as ShapeEditor
	editor.back_requested.connect(switch_to_gameplay)
	_editor = editor
	add_child(_editor)


func switch_to_gameplay() -> void:
	if _editor != null:
		remove_child(_editor)
		_editor.queue_free()
		_editor = null
	_gameplay.process_mode = Node.PROCESS_MODE_INHERIT
	_gameplay.visible = true
