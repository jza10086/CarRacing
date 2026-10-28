class_name TrackWorld
extends Node3D
## Lighthouse Circuit: hand-authored Bezier sections, sampled into one closed road.
## Geometry, driving surface, map, gates and recovery all use this same layout.

const TRACK_HEIGHT := 0.12
const GUARD_SHOULDER := 1.8
const LAYOUT = preload("res://scripts/lighthouse_layout.gd")
var points := PackedVector3Array()
var distances := PackedFloat32Array()
var half_widths := PackedFloat32Array()
var sector_ids := PackedInt32Array()
var sectors: Array[Dictionary] = []
var gate_distances: Array[float] = []
var map_bounds := Rect2()
var length := 0.0
var _asphalt: StandardMaterial3D
var _cream: StandardMaterial3D
var _orange: StandardMaterial3D
var _dark: StandardMaterial3D

func _ready() -> void:
	_build_curve()
	_asphalt = _material(Color("35454e"))
	_cream = _material(Color("f4e9cf"))
	_orange = _material(Color("ee6b40"))
	_dark = _material(Color("253943"))
	# Coast / harbor are hand-built landmarks, independent of road collision.
	var scenery := preload("res://scripts/harbor_scenery.gd").new()
	scenery.track = self
	add_child(scenery)
	_build_ribbons()
	_build_rails()
	_build_start()
	_build_scenery()

func _build_curve() -> void:
	points.clear()
	distances.clear()
	half_widths.clear()
	sector_ids.clear()
	sectors.clear()
	gate_distances.clear()
	length = 0.0
	var data: Array[Dictionary] = LAYOUT.segments()
	var last_sector := -1
	var gate_indices: Array[int] = []
	for segment in data:
		var a: Vector3 = segment.a
		var b: Vector3 = segment.b
		var c: Vector3 = segment.c
		var d: Vector3 = segment.d
		var count := maxi(4, int(ceil((a.distance_to(b) + b.distance_to(c) + c.distance_to(d)) / 3.5)))
		if int(segment.sector) != last_sector:
			last_sector = int(segment.sector)
			sectors.append({"id": last_sector, "name": LAYOUT.NAMES[last_sector], "label": LAYOUT.LABELS[last_sector], "index": points.size()})
		if bool(segment.gate) and not points.is_empty():
			gate_indices.append(points.size())
		for step in count:
			var t := float(step) / count
			var p := a.bezier_interpolate(b, c, d, t)
			p.y = TRACK_HEIGHT
			points.append(p)
			half_widths.append(lerpf(float(segment.w0), float(segment.w1), smoothstep(0.0, 1.0, t)))
			sector_ids.append(last_sector)
	map_bounds = Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for i in points.size():
		distances.append(length)
		length += points[i].distance_to(points[(i + 1) % points.size()])
		map_bounds = map_bounds.expand(Vector2(points[i].x, points[i].z))
	for sector in sectors:
		sector["distance"] = distances[int(sector.index)]
	for index in gate_indices:
		gate_distances.append(distances[index])

func rail_offset_at(index: int) -> float:
	return half_widths[posmod(index, half_widths.size())] + GUARD_SHOULDER

func sector_at(distance: float) -> Dictionary:
	return sectors[sector_ids[int(sample_distance(distance).index)]]

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
	return {"position": points[index].lerp(points[next], weight), "tangent": (points[next] - points[index]).normalized(), "index": index, "distance": wrapped, "half_width": lerpf(half_widths[index], half_widths[next], weight), "sector": sector_ids[index]}

func nearest(point: Vector3) -> Dictionary:
	var closest := Vector3.ZERO
	var best_distance := INF
	var best_along := 0.0
	var best_index := 0
	var best_weight := 0.0
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
			best_weight = t
			best_along = distances[i] + ab.length() * t
			tangent = ab.normalized()
	return {"position": closest, "tangent": tangent, "distance": fposmod(best_along, length), "lateral": (flat - closest).dot(tangent.cross(Vector3.UP)), "index": best_index, "half_width": lerpf(half_widths[best_index], half_widths[(best_index + 1) % points.size()], best_weight), "sector": sector_ids[best_index]}

func start_transform() -> Transform3D:
	var sample := sample_distance(3.0)
	var tangent: Vector3 = sample.tangent
	return Transform3D(Basis.looking_at(tangent, Vector3.UP), sample.position + Vector3(0, 0.02, 0))

func checkpoint_samples() -> Array[float]:
	# Gates bracket every deliberate feature; non-uniform spacing is intentional.
	return gate_distances.duplicate()

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


func _right(index: int) -> Vector3:
	return (points[(index + 1) % points.size()] - points[posmod(index - 1, points.size())]).normalized().cross(Vector3.UP)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	# Godot uses clockwise front faces; normal and collision both point up.
	for vertex: Vector3 in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(vertex)

func _ribbon(inner: float, outer: float, material: Material, offset_y: float = 0.0, alternating: int = -1, side: float = 0.0) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size():
		if alternating >= 0 and i % 2 != alternating:
			continue
		var j := (i + 1) % points.size()
		var wi := half_widths[i]
		var wj := half_widths[j]
		var ai := inner * wi if side == 0.0 else side * (wi + inner)
		var bj := inner * wj if side == 0.0 else side * (wj + inner)
		var cj := outer * wj if side == 0.0 else side * (wj + outer)
		var di := outer * wi if side == 0.0 else side * (wi + outer)
		var a := points[i] + _right(i) * ai + Vector3.UP * offset_y
		var b := points[j] + _right(j) * bj + Vector3.UP * offset_y
		var c := points[j] + _right(j) * cj + Vector3.UP * offset_y
		var d := points[i] + _right(i) * di + Vector3.UP * offset_y
		# Both positive and negative strips face upward.
		if di > ai:
			_quad(st, a, b, c, d)
		else:
			_quad(st, d, c, b, a)
	var mesh := st.commit()
	return _mesh_node(mesh, material)

func _build_ribbons() -> void:
	_ribbon(-1.0, 1.0, _material(Color("c6b68d")), -0.06)
	for side: float in [-1.0, 1.0]:
		var shoulder := _ribbon(0.0, GUARD_SHOULDER + 0.25, _material(Color("c6b68d")), -0.05, -1, side)
		shoulder.create_trimesh_collision()
	var road := _ribbon(-1.0, 1.0, _asphalt)
	road.name = "ContinuousRoad"
	road.create_trimesh_collision()
	for side: float in [-1.0, 1.0]:
		_ribbon(0.0, 0.65, _orange, 0.016, 0, side)
		_ribbon(0.0, 0.65, _cream, 0.016, 1, side)
		_ribbon(-0.28, -0.17, _cream, 0.018, -1, side)
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
			var a := points[i] + _right(i) * side * rail_offset_at(i)
			var b := points[j] + _right(j) * side * rail_offset_at(j)
			var direction := (b - a).normalized()
			var basis := Basis.looking_at(direction)
			var midpoint := (a + b) * 0.5
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.8, 1.8, a.distance_to(b) + 0.35)
			shape.shape = box
			shape.transform = Transform3D(basis, midpoint + Vector3.UP * 0.72)
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
	for x: float in [-9.8, 9.8]:
		_box(Vector3(x, 3.5, 0), Vector3(0.50, 7.0, 0.55), _dark, frame)
		_box(Vector3(x, 0.45, 0), Vector3(0.9, 0.9, 1.0), _orange, frame)
	_box(Vector3(0, 6.5, 0), Vector3(20.1, 1.4, 0.50), _orange, frame)
	_box(Vector3(0, 5.65, 0), Vector3(18.5, 0.30, 0.45), _dark, frame)
	var title := Label3D.new()
	title.text = "L I G H T H O U S E"
	title.font_size = 64
	title.pixel_size = 0.019
	title.outline_size = 0
	title.modulate = Color("fff4d9")
	title.position = Vector3(0, 6.53, 0.27)
	frame.add_child(title)
	var finish := Label3D.new()
	finish.text = "START / FINISH"
	finish.font_size = 48
	finish.pixel_size = 0.012
	finish.outline_size = 0
	finish.modulate = Color("fff4d9")
	finish.position = Vector3(0, 5.65, 0.26)
	frame.add_child(finish)
	var stripe := SurfaceTool.new()
	stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dark_stripe := SurfaceTool.new()
	dark_stripe.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 2:
		for col in 24:
			var x := -7.2 + col * 0.6
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
	# Signs precede decisions. They are not invisible checkpoint triggers.
	for sector in sectors:
		var dist: float = sector.distance
		_build_sign(dist + 8.0, "%02d  %s" % [int(sector.id) + 1, sector.label], _dark)
	for at: float in [180.0, 225.0, 370.0, 440.0, 510.0, 592.0, 640.0, 705.0, 845.0, 950.0, 1045.0, length - 150.0, length - 95.0]:
		_build_chevron(at)
	var hairpin_start: float = sectors[2].distance
	_build_sign(hairpin_start - 50.0, "HAIRPIN  100", _orange)
	_build_sign(hairpin_start, "BRAKE  50", _orange)
	_build_sign(hairpin_start + 17.0, "HAIRPIN  >>", _orange)
	var bridge_start: float = sectors[4].distance
	_build_sign(bridge_start + 18.0, "SHIFT  /  NITRO", _material(Color("226d85")))
	_build_sign(sectors[5].distance - 38.0, "LIFT  /  FINAL TURN", _orange)

func _build_sign(dist: float, text: String, material: Material) -> void:
	var sample := sample_distance(dist)
	var tangent: Vector3 = sample.tangent
	var board := Node3D.new()
	board.transform = Transform3D(Basis.looking_at(tangent), sample.position + tangent.cross(Vector3.UP) * (float(sample.half_width) + 3.2))
	add_child(board)
	_box(Vector3(0, 2.25, 0), Vector3(6.6, 1.7, 0.22), material, board)
	for x: float in [-2.6, 2.6]:
		_box(Vector3(x, 0.8, 0), Vector3(0.16, 1.6, 0.16), _dark, board)
	var label := Label3D.new()
	label.text = text
	label.font_size = 48
	label.pixel_size = 0.013
	label.outline_size = 0
	label.modulate = Color("fff3d6")
	label.position = Vector3(0, 2.25, 0.13)
	board.add_child(label)

func _build_chevron(dist: float) -> void:
	var a := sample_distance(dist)
	var b := sample_distance(dist + 18.0)
	var tangent: Vector3 = a.tangent
	var turn := tangent.cross(b.tangent).y
	var side := -1.0 if turn > 0 else 1.0
	var right := tangent.cross(Vector3.UP)
	var board := Node3D.new()
	board.transform = Transform3D(Basis.looking_at(tangent), a.position + right * side * (float(a.half_width) + 3.0))
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
