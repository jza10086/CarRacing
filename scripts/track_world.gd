class_name TrackWorld
extends Node3D
## Original, continuous Catmull-Rom circuit. Road visuals and collision share geometry.

const ROAD_HALF_WIDTH := 6.0
const TRACK_HEIGHT := 0.12
const SAMPLE_STEPS := 18
const GUARD_OFFSET := 8.6
var points := PackedVector3Array()
var distances := PackedFloat32Array()
var length := 0.0
var _rng := RandomNumberGenerator.new()
var _asphalt: StandardMaterial3D
var _cream: StandardMaterial3D
var _orange: StandardMaterial3D
var _dark: StandardMaterial3D

func _ready() -> void:
	_rng.seed = 784221
	_build_curve()
	_asphalt = _material(Color("35454e"))
	_cream = _material(Color("f4e9cf"))
	_orange = _material(Color("ee6b40"))
	_dark = _material(Color("253943"))
	_build_ground()
	_build_ribbons()
	_build_rails()
	_build_start()
	_build_scenery()

func _build_curve() -> void:
	var controls: Array[Vector3] = [
		Vector3(-100, 0, 80), Vector3(-100, 0, -20), Vector3(-85, 0, -85),
		Vector3(-30, 0, -115), Vector3(45, 0, -100), Vector3(90, 0, -60),
		Vector3(95, 0, -5), Vector3(45, 0, 25), Vector3(75, 0, 70),
		Vector3(70, 0, 115), Vector3(0, 0, 130), Vector3(-70, 0, 120)
	]
	for i in controls.size():
		var a := controls[posmod(i - 1, controls.size())]
		var b := controls[i]
		var c := controls[(i + 1) % controls.size()]
		var d := controls[(i + 2) % controls.size()]
		for step in SAMPLE_STEPS:
			var t := float(step) / SAMPLE_STEPS
			var p := 0.5 * ((2.0 * b) + (-a + c) * t + (2.0 * a - 5.0 * b + 4.0 * c - d) * t * t + (-a + 3.0 * b - 3.0 * c + d) * t * t * t)
			p.y = TRACK_HEIGHT
			points.append(p)
	length = 0.0
	for i in points.size():
		distances.append(length)
		length += points[i].distance_to(points[(i + 1) % points.size()])

func sample_distance(distance: float) -> Dictionary:
	var wrapped := fposmod(distance, length)
	var index := points.size() - 1
	for i in points.size() - 1:
		if wrapped < distances[i + 1]:
			index = i
			break
	var next := (index + 1) % points.size()
	var segment := points[index].distance_to(points[next])
	var weight := clampf((wrapped - distances[index]) / maxf(segment, 0.001), 0.0, 1.0)
	return {"position": points[index].lerp(points[next], weight), "tangent": (points[next] - points[index]).normalized(), "index": index, "distance": wrapped}

func nearest(point: Vector3) -> Dictionary:
	var closest := Vector3.ZERO
	var best_distance := INF
	var best_along := 0.0
	var best_index := 0
	var tangent := Vector3.FORWARD
	var flat := Vector3(point.x, TRACK_HEIGHT, point.z)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var ab := b - a
		var t := clampf((flat - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var candidate := a + ab * t
		var square := flat.distance_squared_to(candidate)
		if square < best_distance:
			best_distance = square
			closest = candidate
			best_index = i
			best_along = distances[i] + ab.length() * t
			tangent = ab.normalized()
	return {"position": closest, "tangent": tangent, "distance": fposmod(best_along, length), "lateral": (flat - closest).dot(tangent.cross(Vector3.UP)), "index": best_index}

func start_transform() -> Transform3D:
	var sample := sample_distance(3.0)
	var tangent: Vector3 = sample.tangent
	return Transform3D(Basis.looking_at(tangent, Vector3.UP), sample.position + Vector3(0, 0.02, 0))

func checkpoint_samples() -> Array[float]:
	var result: Array[float] = []
	for i in range(1, 12):
		result.append(length * float(i) / 12.0)
	return result

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.94
	return mat

func _mesh_node(mesh: Mesh, material: Material, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	add_child(node)
	return node

func _box(at: Vector3, size: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

func _build_ground() -> void:
	var ground := _box(Vector3(0, -0.6, 0), Vector3(760, 1.2, 760), _material(Color("527846")))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(760, 1.2, 760)
	shape.shape = box
	body.add_child(shape)
	ground.add_child(body)
	# The distant faceted ranges close the horizon without texture or postprocessing.
	var mountain_colors: Array[Color] = [Color("739d83"), Color("81a78a"), Color("67917a"), Color("8fb397")]
	for i in 26:
		var angle := TAU * float(i) / 26.0
		var radius := _rng.randf_range(290, 360)
		var height := _rng.randf_range(36, 84)
		var cone := CylinderMesh.new()
		cone.top_radius = _rng.randf_range(0, 4)
		cone.bottom_radius = _rng.randf_range(42, 77)
		cone.height = height
		cone.radial_segments = 7
		cone.rings = 1
		var hill := _mesh_node(cone, _material(mountain_colors[i % mountain_colors.size()]), Vector3(cos(angle) * radius, height * 0.5 - 9.0, sin(angle) * radius))
		hill.rotation.y = _rng.randf_range(0, TAU)
	for i in 10:
		var angle := TAU * float(i) / 10.0 + 0.15
		var hill := SphereMesh.new()
		hill.radial_segments = 10
		hill.rings = 4
		hill.radius = _rng.randf_range(22, 40)
		hill.height = hill.radius * 2.0
		var node := _mesh_node(hill, _material(Color("76a25a")), Vector3(cos(angle) * 220, -17, sin(angle) * 220))
		node.scale.y = 0.65

func _right(index: int) -> Vector3:
	return (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]).normalized().cross(Vector3.UP)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Godot uses clockwise front faces; normal and collision both point up.
	for vertex: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(vertex)

func _ribbon(inner: float, outer: float, material: Material, offset_y: float = 0.0, alternating: int = -1) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		if alternating >= 0 and i % 2 != alternating:
			continue
		var j := (i + 1) % points.size()
		var a := points[i] + _right(i) * inner + Vector3.UP * offset_y
		var b := points[j] + _right(j) * inner + Vector3.UP * offset_y
		var c := points[j] + _right(j) * outer + Vector3.UP * offset_y
		var d := points[i] + _right(i) * outer + Vector3.UP * offset_y
		# Both positive and negative strips face upward.
		if outer > inner:
			_quad(st, a, b, c, d)
		else:
			_quad(st, d, c, b, a)
	var mesh := st.commit()
	return _mesh_node(mesh, material)

func _build_ribbons() -> void:
	_ribbon(-8.4, 8.4, _material(Color("57743f")), -0.06)
	var road := _ribbon(-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH, _asphalt)
	road.name = "ContinuousRoad"
	road.create_trimesh_collision()
	for side: float in [-1.0, 1.0]:
		_ribbon(side * 6.0, side * 6.7, _orange, 0.016, 0)
		_ribbon(side * 6.0, side * 6.7, _cream, 0.016, 1)
		_ribbon(side * 5.72, side * 5.83, _cream, 0.018)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dash_count := int(length / 14.0)
	for i in dash_count:
		var s := sample_distance(float(i) * 14.0 + 9.0)
		var p: Vector3 = s.position + Vector3.UP * 0.02
		var t: Vector3 = s.tangent
		var r := t.cross(Vector3.UP) * 0.055
		_quad(st, p - r, p + t * 3.2 - r, p + t * 3.2 + r, p + r)
	_mesh_node(st.commit(), _material(Color("97a59d")))

func _build_rails() -> void:
	var rail_st := SurfaceTool.new()
	rail_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Closed collision walls give a forgiving roadside rather than unbounded void.
	var collider := StaticBody3D.new()
	collider.name = "Guardrails"
	add_child(collider)
	var posts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		for i in points.size():
			var j := (i + 1) % points.size()
			var a := points[i] + _right(i) * side * GUARD_OFFSET
			var b := points[j] + _right(j) * side * GUARD_OFFSET
			var direction := (b - a).normalized()
			var basis := Basis.looking_at(direction)
			var midpoint := (a + b) * 0.5
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.28, 1.35, a.distance_to(b) + 0.18)
			shape.shape = box
			shape.transform = Transform3D(basis, midpoint + Vector3.UP * 0.52)
			collider.add_child(shape)
			# Merge static rail boxes into one surface; collision remains simple boxes.
			_append_box(rail_st, Transform3D(basis, midpoint + Vector3.UP * 0.72), Vector3(0.22, 0.33, a.distance_to(b) + 0.1))
			if i % 2 == 0:
				posts.append(Transform3D(Basis.IDENTITY, a + Vector3.UP * 0.38))
	_mesh_node(rail_st.commit(), _material(Color("c2cfbc")))
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.15, 0.85, 0.15)
	_make_multimesh(post_mesh, _material(Color("6a8174")), posts)

func _append_box(st: SurfaceTool, transform: Transform3D, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	st.append_from(box, 0, transform)

func _make_multimesh(mesh: Mesh, material: Material, placements: Array[Transform3D]) -> void:
	if placements.is_empty():
		return
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = placements.size()
	for i in placements.size():
		multi.set_instance_transform(i, placements[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	add_child(node)

func _build_start() -> void:
	var sample := sample_distance(0.0)
	var p: Vector3 = sample.position
	var t: Vector3 = sample.tangent
	var basis := Basis.looking_at(t)
	var frame := Node3D.new()
	frame.name = "StartFinish"
	frame.transform = Transform3D(basis, p)
	add_child(frame)
	for x: float in [-8.0, 8.0]:
		_box(Vector3(x, 3.5, 0), Vector3(0.50, 7.0, 0.55), _dark, frame)
		_box(Vector3(x, 0.45, 0), Vector3(0.9, 0.9, 1.0), _orange, frame)
	_box(Vector3(0, 6.5, 0), Vector3(16.5, 1.4, 0.50), _orange, frame)
	_box(Vector3(0, 5.65, 0), Vector3(14.6, 0.30, 0.45), _dark, frame)
	var title := Label3D.new()
	title.text = "S U N R I D G E"
	title.font_size = 64
	title.pixel_size = 0.019
	title.outline_size = 0
	title.modulate = Color("fff4d9")
	title.position = Vector3(0, 6.53, 0.27)
	frame.add_child(title)
	var stripe := SurfaceTool.new()
	stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark_stripe := SurfaceTool.new()
	dark_stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 2:
		for col in 20:
			var x := -6.0 + col * 0.6
			var z := -0.6 + row * 0.6
			var corners: Array[Vector3] = []
			for local: Vector3 in [Vector3(x, 0.026, z), Vector3(x, 0.026, z - 0.6), Vector3(x + 0.6, 0.026, z - 0.6), Vector3(x + 0.6, 0.026, z)]:
				corners.append(p + basis * local)
			_quad(stripe if (row + col) % 2 == 0 else dark_stripe, corners[0], corners[1], corners[2], corners[3])
	_mesh_node(stripe.commit(), _cream)
	_mesh_node(dark_stripe.commit(), _dark)
	# Grid slots ahead of the gantry mark the launch direction without HUD arrows.
	for dist: float in [5.0, 12.0, 19.0]:
		var mark := sample_distance(dist)
		var pos: Vector3 = mark.position + Vector3.UP * 0.03
		var tangent: Vector3 = mark.tangent
		var right := tangent.cross(Vector3.UP)
		for side: float in [-1.0, 1.0]:
			var box := _box(pos + right * side * 2.7, Vector3(2.0, 0.02, 0.12), _cream)
			box.basis = Basis.looking_at(tangent)

func _build_scenery() -> void:
	var trees: Array[Array] = [[], [], []]
	var rocks: Array[Transform3D] = []
	for i in 360:
		var p := Vector3(_rng.randf_range(-205, 205), 0, _rng.randf_range(-205, 205))
		var near := nearest(p)
		if absf(float(near.lateral)) < 13.5:
			continue
		# Keep the start complex clear, with open meadows beside the straight.
		if p.x < -105 and p.z > 35 and p.z < 125:
			continue
		if p.x > -82 and p.x < -38 and p.z > 30 and p.z < 95:
			continue
		var s := _rng.randf_range(3.2, 5.8)
		var transform := Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3.ONE * s), p + Vector3.UP * 0.05 * s)
		if i % 7 == 0:
			rocks.append(Transform3D(Basis(Vector3.UP, _rng.randf_range(0, TAU)).scaled(Vector3.ONE * _rng.randf_range(1.2, 2.4)), p))
		else:
			trees[i % 3].append(transform)
	_scatter_scene("res://assets/kenney_nature_kit/tree_pineRoundA.glb", trees[0])
	_scatter_scene("res://assets/kenney_nature_kit/tree_pineTallA.glb", trees[1])
	_scatter_scene("res://assets/kenney_nature_kit/tree_oak.glb", trees[2])
	_scatter_scene("res://assets/kenney_nature_kit/rock_largeA.glb", rocks)
	_place_scene("res://assets/kenney_racing_kit/grandStandCovered.glb", Vector3(-123, 0, 56), Vector3(9.0, 9.0, 9.0), -PI * 0.5)
	_place_scene("res://assets/kenney_racing_kit/grandStandCovered.glb", Vector3(-123, 0, 84), Vector3(9.0, 9.0, 9.0), -PI * 0.5)
	_place_scene("res://assets/kenney_racing_kit/pitsOffice.glb", Vector3(-71, 0, 53), Vector3(12.0, 12.0, 12.0), -PI * 0.5)
	_place_scene("res://assets/kenney_racing_kit/flagCheckers.glb", Vector3(-113, 0, 80), Vector3.ONE * 3.0, 0)
	# Roadside directional chevrons are scenery, never checkpoint triggers.
	for dist: float in [200.0, 280.0, 365.0, 440.0, 500.0, 565.0, 640.0, 730.0]:
		_build_chevron(dist)

func _place_scene(path: String, at: Vector3, size: Vector3, yaw: float) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var node := scene.instantiate() as Node3D
	add_child(node)
	node.position = at
	node.scale = size
	node.rotation.y = yaw

func _scatter_scene(path: String, placements: Array) -> void:
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	var source := scene.instantiate() as Node3D
	_scatter_children(source, Transform3D.IDENTITY, placements)
	source.free()

func _scatter_children(source: Node3D, inherited: Transform3D, placements: Array) -> void:
	var local := inherited * source.transform
	if source is MeshInstance3D:
		var mesh_node := source as MeshInstance3D
		var combined: Array[Transform3D] = []
		for placement: Transform3D in placements:
			combined.append(placement * local)
		_make_multimesh(mesh_node.mesh, mesh_node.material_override, combined)
	for child in source.get_children():
		if child is Node3D:
			_scatter_children(child as Node3D, local, placements)

func _build_chevron(dist: float) -> void:
	var a := sample_distance(dist)
	var b := sample_distance(dist + 18.0)
	var tangent: Vector3 = a.tangent
	var turn := tangent.cross(b.tangent).y
	var side := -1.0 if turn > 0 else 1.0
	var right := tangent.cross(Vector3.UP)
	var board := Node3D.new()
	board.transform = Transform3D(Basis.looking_at(tangent), a.position + right * side * 9.4)
	add_child(board)
	_box(Vector3(0, 1.4, 0), Vector3(2.6, 1.7, 0.2), _orange, board)
	_box(Vector3(0, 0.55, 0), Vector3(0.15, 1.1, 0.15), _dark, board)
	var arrow := Label3D.new()
	arrow.text = ">>" if turn < 0.0 else "<<"
	arrow.font_size = 60
	arrow.pixel_size = 0.025
	arrow.outline_size = 0
	arrow.modulate = Color("fff3d6")
	arrow.position = Vector3(0, 1.40, 0.12)
	board.add_child(arrow)
