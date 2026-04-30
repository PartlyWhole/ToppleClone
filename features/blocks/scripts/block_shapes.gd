class_name BlockShapes
## Loads block shape definitions from JSON files in features/blocks/shapes/.

const CELL_SIZE: float = 60.0

static var _shapes: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var raw_shapes: Array[Dictionary] = ShapeFileIO.load_all_shapes()
	for data: Dictionary in raw_shapes:
		var shape_name: StringName = StringName(data.get("name", "") as String)
		if shape_name == &"":
			continue
		var vertices: PackedVector2Array = ShapeFileIO.arrays_to_vec2_array(
			data.get("vertices", []) as Array
		)
		var convex_parts: Array[PackedVector2Array] = []
		for raw_part: Variant in data.get("convex_parts", []) as Array:
			convex_parts.append(ShapeFileIO.arrays_to_vec2_array(raw_part as Array))
		_shapes[shape_name] = {
			"vertices": vertices,
			"convex_parts": convex_parts,
		}
	print("BlockShapes: loaded %d shapes" % _shapes.size())


static func has_shape(shape_name: StringName) -> bool:
	_ensure_loaded()
	return _shapes.has(shape_name)


static func get_all_names() -> Array[StringName]:
	_ensure_loaded()
	var names: Array[StringName] = []
	for key: StringName in _shapes:
		names.append(key)
	return names


static func get_vertices(shape_name: StringName) -> PackedVector2Array:
	_ensure_loaded()
	assert(_shapes.has(shape_name), "Unknown shape: " + shape_name)
	var shape_data: Dictionary = _shapes[shape_name] as Dictionary
	return PackedVector2Array(shape_data["vertices"] as PackedVector2Array)


static func get_convex_parts(shape_name: StringName) -> Array[PackedVector2Array]:
	_ensure_loaded()
	assert(_shapes.has(shape_name), "Unknown shape: " + shape_name)
	var shape_data: Dictionary = _shapes[shape_name] as Dictionary
	var original: Array[PackedVector2Array] = (
		shape_data["convex_parts"] as Array[PackedVector2Array]
	)
	var copies: Array[PackedVector2Array] = []
	for part: PackedVector2Array in original:
		copies.append(PackedVector2Array(part))
	return copies


static func get_bounding_size(shape_name: StringName) -> Vector2:
	var verts: PackedVector2Array = get_vertices(shape_name)
	if verts.is_empty():
		return Vector2.ZERO
	var min_v: Vector2 = verts[0]
	var max_v: Vector2 = verts[0]
	for v: Vector2 in verts:
		min_v.x = minf(min_v.x, v.x)
		min_v.y = minf(min_v.y, v.y)
		max_v.x = maxf(max_v.x, v.x)
		max_v.y = maxf(max_v.y, v.y)
	return max_v - min_v


static func get_area(shape_name: StringName) -> float:
	var verts: PackedVector2Array = get_vertices(shape_name)
	var area: float = 0.0
	var n: int = verts.size()
	for i: int in n:
		var j: int = (i + 1) % n
		area += verts[i].x * verts[j].y - verts[j].x * verts[i].y
	return absf(area) / 2.0


static func reload() -> void:
	_shapes.clear()
	_loaded = false
	_ensure_loaded()
