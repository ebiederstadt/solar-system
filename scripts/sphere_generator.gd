@tool
extends MeshInstance3D

@export var update = false

func _ready():
	gen_mesh()


func _process(_delta: float):
	if update:
		gen_mesh()
		update = false


func gen_outline(vertices: PackedVector3Array, indices: PackedInt32Array):
	var line_indices = PackedInt32Array()
	for i in range(0, indices.size(), 3):
		var a = indices[i]
		var b = indices[i + 1]
		var c = indices[i + 2]
		line_indices.append_array([a, b, b, c, c, a])

	var line_arrays = []
	line_arrays.resize(Mesh.ARRAY_MAX)
	line_arrays[Mesh.ARRAY_VERTEX] = vertices
	line_arrays[Mesh.ARRAY_INDEX] = line_indices

	return line_arrays
	#array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)


func gen_mesh():
	# https://blog.lslabs.dev/posts/generating_icosphere_with_code
	var a := 0.525731112119134
	var c := 0.85065080835157

	var vertices = PackedVector3Array([
		Vector3(-a,  c,  0),
		Vector3( a,  c,  0),
		Vector3(-a, -c,  0),
		Vector3( a, -c,  0),

		Vector3( 0, -a,  c),
		Vector3( 0,  a,  c),
		Vector3( 0, -a, -c),
		Vector3( 0,  a, -c),

		Vector3( c,  0, -a),
		Vector3( c,  0,  a),
		Vector3(-c,  0, -a),
		Vector3(-c,  0,  a),
	])

	var indices = PackedInt32Array([
		0, 5, 11,
		0, 1, 5,
		0, 7, 1,
		0, 10, 7,

		0, 11, 10,
		1, 9, 5,
		5, 4, 11,
		11, 2, 10,

		10, 6, 7,
		7, 8, 1,
		3, 4, 9,
		3, 2, 4,

		3, 6, 2,
		3, 8, 6,
		3, 9, 8,
		4, 5, 9,

		2, 11, 4,
		6, 10, 2,
		8, 7, 6,
		9, 1, 8,
	])

	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in vertices.size():
		normals[i] = vertices[i].normalized()

	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_NORMAL] = normals
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var line_arrays = gen_outline(vertices, indices)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)

	mesh = array_mesh
