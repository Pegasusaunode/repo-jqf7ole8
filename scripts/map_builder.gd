extends RefCounted
class_name MapBuilder
## Builds a simple symmetric CS-style arena out of textured boxes plus a few
## Kenney GLB props. Returns spawn transforms for both teams.

const PROTO := "res://assets/prototype/"
const ARENA := "res://assets/arena/"
const HALF := 30.0   # arena half-size


static func build(parent: Node3D) -> Dictionary:
	_add_environment(parent)
	_build_floor(parent)
	_build_walls(parent)
	_build_cover(parent)
	_decorate(parent)

	var ct: Array[Vector3] = []
	var t: Array[Vector3] = []
	for i in range(5):
		var x: float = -16.0 + i * 8.0
		ct.append(Vector3(x, 0.2, -HALF + 5.0))
		t.append(Vector3(x, 0.2, HALF - 5.0))
	return {"ct": ct, "t": t, "ct_yaw": 0.0, "t_yaw": PI}


static func _add_environment(parent: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -45, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	parent.add_child(sun)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.55, 0.65, 0.78)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.68)
	e.ambient_light_energy = 0.6
	e.fog_enabled = true
	e.fog_light_color = Color(0.6, 0.68, 0.8)
	e.fog_density = 0.004
	env.environment = e
	parent.add_child(env)


static func _texmat(file: String, tiling: float, tint := Color.WHITE) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var path := PROTO + file
	if ResourceLoader.exists(path):
		mat.albedo_texture = load(path)
		mat.uv1_scale = Vector3(tiling, tiling, tiling)
	mat.albedo_color = tint
	return mat


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	body.add_child(mesh)

	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)


static func _build_floor(parent: Node3D) -> void:
	_box(parent, Vector3(0, -0.5, 0), Vector3(HALF * 2.0, 1.0, HALF * 2.0),
		_texmat("light_floor.png", HALF))


static func _build_walls(parent: Node3D) -> void:
	var h := 6.0
	var wall := _texmat("texture_01.png", 8.0)
	_box(parent, Vector3(0, h * 0.5, -HALF), Vector3(HALF * 2.0 + 2.0, h, 1.0), wall)
	_box(parent, Vector3(0, h * 0.5, HALF), Vector3(HALF * 2.0 + 2.0, h, 1.0), wall)
	_box(parent, Vector3(-HALF, h * 0.5, 0), Vector3(1.0, h, HALF * 2.0), wall)
	_box(parent, Vector3(HALF, h * 0.5, 0), Vector3(1.0, h, HALF * 2.0), wall)


static func _build_cover(parent: Node3D) -> void:
	var crate := _texmat("orange.png", 1.0)
	var wall := _texmat("texture_02.png", 3.0)
	# Mirrored cover layout (CS-style mid + sites).
	var layout := [
		# central mound
		[Vector3(0, 1.0, 0), Vector3(6, 2, 2)],
		[Vector3(0, 1.5, 0), Vector3(2, 3, 6)],
		# left lane long walls
		[Vector3(-18, 1.5, -6), Vector3(2, 3, 10)],
		[Vector3(-18, 1.5, 6), Vector3(2, 3, 10)],
		# right lane
		[Vector3(18, 1.5, -6), Vector3(2, 3, 10)],
		[Vector3(18, 1.5, 6), Vector3(2, 3, 10)],
		# scattered crates (mirrored)
		[Vector3(-9, 1.0, -12), Vector3(2, 2, 2)],
		[Vector3(9, 1.0, -12), Vector3(2, 2, 2)],
		[Vector3(-9, 1.0, 12), Vector3(2, 2, 2)],
		[Vector3(9, 1.0, 12), Vector3(2, 2, 2)],
		[Vector3(-6, 1.0, 0), Vector3(2, 2, 2)],
		[Vector3(6, 1.0, 0), Vector3(2, 2, 2)],
	]
	for i in layout.size():
		var pos: Vector3 = layout[i][0]
		var size: Vector3 = layout[i][1]
		var mat := crate if size.x <= 2.5 and size.z <= 2.5 else wall
		_box(parent, pos, size, mat)


static func _decorate(parent: Node3D) -> void:
	# Purely visual GLB props (no gameplay collision needed).
	_prop(parent, ARENA + "column.glb", Vector3(-24, 0, -24), 0.0, 3.0)
	_prop(parent, ARENA + "column.glb", Vector3(24, 0, -24), 0.0, 3.0)
	_prop(parent, ARENA + "column.glb", Vector3(-24, 0, 24), 0.0, 3.0)
	_prop(parent, ARENA + "column.glb", Vector3(24, 0, 24), 0.0, 3.0)
	_prop(parent, ARENA + "tree.glb", Vector3(-27, 0, 0), 0.0, 4.0)
	_prop(parent, ARENA + "tree.glb", Vector3(27, 0, 0), 0.0, 4.0)


static func _prop(parent: Node3D, path: String, pos: Vector3, yaw: float, target_h: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var packed = load(path)
	if packed == null:
		return
	var inst: Node3D = packed.instantiate()
	parent.add_child(inst)
	inst.position = pos
	inst.rotation.y = yaw
	if target_h > 0.0:
		_scale_to_height(inst, target_h)


static func _scale_to_height(node: Node3D, target_h: float) -> void:
	var aabb := _aabb(node)
	if aabb.size.y > 0.0001:
		var s: float = target_h / aabb.size.y
		node.scale = Vector3(s, s, s)


static func _aabb(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var box: AABB = mi.mesh.get_aabb()
			var rel: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
			box = rel * box
			if first:
				result = box
				first = false
			else:
				result = result.merge(box)
		for c in n.get_children():
			if c is Node3D:
				stack.push_back(c)
	return result
