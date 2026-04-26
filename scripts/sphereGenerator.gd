@tool
extends MeshInstance3D

@export var update = false
@export_range(0, 10, 1) var subdiv_levels := 1:
	set(val):
		subdiv_levels = val
		gen_mesh()

@export_group("Noise Params")
@export var frequency := 0.5:
	set(val):
		frequency = val
		update_noise()

@export var multiplier := 2.0:
	set(val):
		multiplier = val
		update_noise()

@export var octaves := 5:
	set(val):
		octaves = val
		update_noise()

@export var fractal_lacunarity := 2.0:
	set(val):
		fractal_lacunarity = val
		update_noise()

@export var fractal_gain := 0.5:
	set(val):
		fractal_gain = val
		update_noise()

var base_vertices: PackedVector3Array
var base_indices: PackedInt32Array
var base_normals: PackedVector3Array


func _ready():
	gen_mesh()


func _process(_delta: float):
	if update:
		gen_mesh()
		update = false


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
	var subdivided = subdivide(vertices, indices, subdiv_levels)
	base_vertices = subdivided["vertices"]
	base_indices = subdivided["indices"]
	base_normals = gen_normals(base_vertices)

	vertices = modify_height(base_vertices)

	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = base_indices
	arrays[Mesh.ARRAY_NORMAL] = base_normals
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var line_arrays = gen_outline(vertices, base_indices)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)

	mesh = array_mesh

func gen_normals(vertices: PackedVector3Array) -> PackedVector3Array:
	var normals = PackedVector3Array()
	normals.resize(vertices.size())
	for i in vertices.size():
		normals[i] = vertices[i].normalized()

	return normals


func gen_outline(vertices: PackedVector3Array, indices: PackedInt32Array) -> Array:
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


func subdivide(vertices: PackedVector3Array, indices: PackedInt32Array, subdivision_levels: int):
	var final_vertices = PackedVector3Array()
	var final_indices = PackedInt32Array()

	for subdiv in range(subdivision_levels):
		var out_vertices = PackedVector3Array()
		var out_indices = PackedInt32Array()
		var base = 0
		for i in range(0, indices.size(), 3):
			var v1 = vertices[indices[i]]
			var v2 = vertices[indices[i + 1]]
			var v3 = vertices[indices[i + 2]]

			# Doing this interpolation in spherical space avoids the need to re-project in the future
			var v4 = v1.slerp(v2, 0.5)
			var v5 = v2.slerp(v3, 0.5)
			var v6 = v3.slerp(v1, 0.5)

			out_vertices.append_array([v1, v2, v3, v4, v5, v6])
			out_indices.append_array([
				base    , base + 3, base + 5, # 1, 4, 6
				base + 3, base + 4, base + 5, # 4, 5, 6
				base + 4, base + 2, base + 5, # 5, 3, 6
				base + 3, base + 1, base + 4, # 4, 2, 5
			])
			base += 6

		final_vertices = out_vertices
		final_indices = out_indices

		vertices = out_vertices
		indices = out_indices

	return {"vertices": final_vertices, "indices": final_indices}


func update_noise():
	var array_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = modify_height(base_vertices)
	arrays[Mesh.ARRAY_INDEX] = base_indices
	arrays[Mesh.ARRAY_NORMAL] = base_normals
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var line_arrays = gen_outline(base_vertices, base_indices)
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, line_arrays)

	mesh = array_mesh

func modify_height(vertices: PackedVector3Array) -> PackedVector3Array:
	var noise = FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.fractal_lacunarity = fractal_lacunarity
	noise.fractal_gain
	for i in range(vertices.size()):
		var vertex = vertices[i].normalized()
		var radius = 1.0 + noise.get_noise_3dv(vertex) * multiplier
		vertices[i] = vertex * radius
	return vertices
