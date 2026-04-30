class_name ShapeFileIO

const SHAPES_DIR: String = "res://features/blocks/shapes/"


static func save_shape(
	shape_name: String,
	vertices: PackedVector2Array,
	convex_parts: Array[PackedVector2Array],
) -> Error:
	var dir: DirAccess = DirAccess.open("res://")
	if dir != null:
		dir.make_dir_recursive(SHAPES_DIR.trim_prefix("res://"))
	var data: Dictionary = {
		"version": 1,
		"name": shape_name,
		"vertices": _vec2_array_to_arrays(vertices),
		"convex_parts": [],
	}
	var parts_array: Array = data["convex_parts"] as Array
	for part: PackedVector2Array in convex_parts:
		parts_array.append(_vec2_array_to_arrays(part))
	var json_string: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(SHAPES_DIR + shape_name + ".json", FileAccess.WRITE)
	if file == null:
		push_error(
			"Cannot write shape %s: %s" % [shape_name, error_string(FileAccess.get_open_error())]
		)
		return FileAccess.get_open_error()
	file.store_string(json_string)
	return OK


static func load_shape(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Cannot open %s: %s" % [file_path, error_string(FileAccess.get_open_error())])
		return {}
	var text: String = file.get_as_text()
	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		push_error("JSON parse error in %s: %s" % [file_path, json.get_error_message()])
		return {}
	var data: Variant = json.data
	if not data is Dictionary:
		push_error("Expected Dictionary in %s" % file_path)
		return {}
	return data as Dictionary


static func load_all_shapes() -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(SHAPES_DIR)
	if dir == null:
		return shapes
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var shape: Dictionary = load_shape(SHAPES_DIR + file_name)
			if shape.size() > 0:
				shapes.append(shape)
		file_name = dir.get_next()
	return shapes


static func delete_shape(shape_name: String) -> Error:
	var path: String = SHAPES_DIR + shape_name + ".json"
	if not FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	return DirAccess.remove_absolute(path)


static func _vec2_array_to_arrays(arr: PackedVector2Array) -> Array:
	var result: Array = []
	for v: Vector2 in arr:
		result.append([v.x, v.y])
	return result


static func arrays_to_vec2_array(arr: Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for raw_pair: Variant in arr:
		var pair: Array = raw_pair as Array
		var x: float = pair[0] as float
		var y: float = pair[1] as float
		result.append(Vector2(x, y))
	return result
