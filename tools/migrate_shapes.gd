extends SceneTree
## One-shot migration script: converts hardcoded BlockShapes to JSON files.
## Run: godot --headless --path . -s tools/migrate_shapes.gd


func _init() -> void:
	_migrate_all()
	quit()


func _migrate_all() -> void:
	var dir: DirAccess = DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive(ShapeFileIO.SHAPES_DIR.trim_prefix("res://"))

	var keys: PackedStringArray = PackedStringArray(BlockShapes.Type.keys())
	var values: Array = BlockShapes.Type.values()

	for i: int in values.size():
		var type: BlockShapes.Type = values[i] as BlockShapes.Type
		var name_str: String = keys[i].to_lower()
		var vertices: PackedVector2Array

		if BlockShapes.is_grid_shape(type):
			vertices = BlockShapes.get_perimeter(type)
		else:
			vertices = BlockShapes.get_polygon(type)

		if vertices.is_empty():
			push_error("No vertices for %s" % name_str)
			continue

		if not Geometry2D.is_polygon_clockwise(vertices):
			vertices.reverse()

		var decomposed: Array[PackedVector2Array] = []
		for part: PackedVector2Array in Geometry2D.decompose_polygon_in_convex(vertices):
			decomposed.append(part)

		if decomposed.is_empty():
			push_error("Decomposition failed for %s" % name_str)
			continue

		var err: Error = ShapeFileIO.save_shape(name_str, vertices, decomposed)
		if err == OK:
			print("Migrated: %s (%d vertices, %d convex parts)" % [
				name_str, vertices.size(), decomposed.size()
			])
		else:
			push_error("Failed to save %s: %s" % [name_str, error_string(err)])
