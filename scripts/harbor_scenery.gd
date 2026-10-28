class_name HarborScenery
extends Node3D
## Original low-poly coastal landmarks. Terrain follows a designed shoreline, not a flat arena.
## All bridge structure above the road is outside the guardrails; the deck stays flat.
var track: Node3D
var _cream: StandardMaterial3D
var _navy: StandardMaterial3D
var _rust: StandardMaterial3D
var _teal: StandardMaterial3D
var _stone: StandardMaterial3D
var _window: StandardMaterial3D

func _ready() -> void:
	name = "LighthouseHarborScenery"
	_cream = _material(Color("eadfc1"))
	_navy = _material(Color("244a59"))
	_rust = _material(Color("d96843"))
	_teal = _material(Color("458b87"))
	_stone = _material(Color("b4af8b"))
	_window = _material(Color("7abfc2"))
	_build_coast()
	_build_port()
	_build_boatyard()
	_build_lighthouse()
	_build_bridge()
	_build_reefs()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	return material

func _mesh(mesh: Mesh, material: Material, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = material
	result.position = at
	parent.add_child(result)
	return result

func _box(at: Vector3, size: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(mesh, material, at, parent)

func _cylinder(at: Vector3, bottom: float, top: float, height: float, material: Material, sides: int = 10, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	return _mesh(mesh, material, at, parent)

func _beam(a: Vector3, b: Vector3, width: float, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var result := _box((a + b) * 0.5, Vector3(width, width, a.distance_to(b)), material, parent)
	result.basis = Basis.looking_at((b - a).normalized(), Vector3.RIGHT if absf((b - a).normalized().dot(Vector3.UP)) > 0.99 else Vector3.UP)
	return result

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color = Color.WHITE) -> void:
	st.set_normal(normal)
	st.set_color(color)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _build_coast() -> void:
	# The southern notch is a real water inlet: the boost bridge crosses its mouth.
	var outline := PackedVector2Array([
		Vector2(-280, 155), Vector2(-277, 60), Vector2(-283, -60), Vector2(-260, -115),
		Vector2(-205, -158), Vector2(-135, -159), Vector2(-95, -191), Vector2(-35, -214),
		Vector2(10, -212), Vector2(55, -190), Vector2(100, -166), Vector2(140, -149),
		Vector2(166, -115), Vector2(157, -65), Vector2(111, -39), Vector2(68, -40),
		Vector2(45, -20), Vector2(45, 20), Vector2(70, 55), Vector2(125, 75),
		Vector2(175, 110), Vector2(204, 163), Vector2(205, 213), Vector2(173, 264),
		Vector2(120, 293), Vector2(80, 290), Vector2(65, 270), Vector2(52, 241),
		Vector2(18, 228), Vector2(-20, 207), Vector2(-63, 196), Vector2(-110, 207),
		Vector2(-134, 233), Vector2(-138, 279), Vector2(-207, 281), Vector2(-244, 260),
		Vector2(-270, 220)
	])
	var indices := Geometry2D.triangulate_polygon(outline)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tones: Array[Color] = [Color("80966c"), Color("8b9c74"), Color("879870"), Color("83976e")]
	for i in range(0, indices.size(), 3):
		var a := outline[indices[i]]
		var b := outline[indices[i + 1]]
		var c := outline[indices[i + 2]]
		_triangle(top, Vector3(a.x, 0, a.y), Vector3(c.x, 0, c.y), Vector3(b.x, 0, b.y), Vector3.UP, tones[(i / 3) % tones.size()])
	var terrain_material := _material(Color.WHITE)
	terrain_material.vertex_color_use_as_albedo = true
	terrain_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plateau := _mesh(top.commit(), terrain_material, Vector3.ZERO)
	plateau.name = "ShapedCoastalPlateau"
	plateau.create_trimesh_collision()
	var cliff := SurfaceTool.new()
	cliff.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a2 := outline[i]
		var b2 := outline[(i + 1) % outline.size()]
		var a := Vector3(a2.x, -0.03, a2.y)
		var b := Vector3(b2.x, -0.03, b2.y)
		var outward := Vector3(b.z - a.z, 0, a.x - b.x).normalized()
		var low_a := a + Vector3.DOWN * (7.0 + float(i % 3)) + outward * 3.0
		var low_b := b + Vector3.DOWN * (7.0 + float((i + 1) % 3)) + outward * 3.0
		var shade := Color("b6ad89") if i % 2 == 0 else Color("a19c7c")
		_triangle(cliff, a, b, low_b, outward, shade)
		_triangle(cliff, a, low_b, low_a, outward, shade.darkened(0.08))
	var cliff_material := terrain_material.duplicate() as StandardMaterial3D
	_mesh(cliff.commit(), cliff_material, Vector3.ZERO).name = "FacetedCoastalCliffs"
	# An opaque flat water plane is cheap and gives a calm, readable horizon.
	_box(Vector3(-20, -5.7, 40), Vector3(1800, 0.6, 1800), _material(Color("3f939e"))).name = "HarborSea"
	var foam := _material(Color("a2d4c5"))
	for i in range(0, outline.size(), 2):
		var a := Vector3(outline[i].x, -5.35, outline[i].y)
		var b := Vector3(outline[(i + 1) % outline.size()].x, -5.35, outline[(i + 1) % outline.size()].y)
		var direction := (b - a).normalized()
		var outward := Vector3(direction.z, 0, -direction.x)
		var wave := _box((a + b) * 0.5 + outward * 6.0, Vector3(1.1, 0.035, a.distance_to(b) * 0.60), foam)
		wave.basis = Basis.looking_at(direction)

func _warehouse(at: Vector3, size: Vector3, roof_material: Material, yaw: float = 0.0, title: String = "") -> Node3D:
	var building := Node3D.new()
	building.position = at
	building.rotation.y = yaw
	add_child(building)
	_box(Vector3(0, size.y * 0.5, 0), size, _cream, building)
	_box(Vector3(0, 0.6, 0), Vector3(size.x + 0.4, 1.2, size.z + 0.4), _stone, building)
	# A true gabled silhouette, not another generic box.
	var roof := PrismMesh.new()
	roof.size = Vector3(size.x + 1.6, 4.4, size.z + 1.8)
	_mesh(roof, roof_material, Vector3(0, size.y + 1.8, 0), building)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * size.x * 0.27, size.y * 0.46, size.z * 0.5 + 0.04), Vector3(size.x * 0.26, size.y * 0.76, 0.10), _navy, building)
		_box(Vector3(side * size.x * 0.27, size.y * 0.72, -size.z * 0.5 - 0.04), Vector3(size.x * 0.24, size.y * 0.18, 0.10), _window, building)
	_box(Vector3(0, size.y + 0.3, size.z * 0.5 + 0.20), Vector3(size.x * 0.78, 1.7, 0.22), _navy, building)
	if not title.is_empty():
		_label(title, Vector3(0, size.y + 0.34, size.z * 0.5 + 0.34), 0.035, building)
	return building

func _label(text: String, at: Vector3, pixel_size: float, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.font_size = 40
	label.pixel_size = pixel_size
	label.outline_size = 0
	label.modulate = Color("fff0ce")
	parent.add_child(label)
	return label

func _build_port() -> void:
	# The start straight has a built-up harbor to the right and working quays to the left.
	_warehouse(Vector3(-191, 0, 104), Vector3(29, 9, 25), _rust, -PI * 0.5, "HARBOR 01")
	_warehouse(Vector3(-186, 0, 52), Vector3(26, 8, 22), _teal, -PI * 0.5, "COAST SERVICE")
	_warehouse(Vector3(-184, 0, 153), Vector3(33, 10, 23), _navy, -PI * 0.5, "SEABREAK")
	_box(Vector3(-208, 0.025, 101), Vector3(33, 0.05, 137), _material(Color("b5b397")))
	# Original shipping containers give scale while keeping all objects well off the road.
	for i in 5:
		var at := Vector3(-153 + float(i % 2) * 12.0, 1.5, 65 + float(i / 2) * 10.5)
		var material: Material = _rust if i % 2 == 0 else _teal
		_box(at, Vector3(9, 3, 5), material)
		for rib in 4:
			_box(at + Vector3(-3.4 + rib * 2.2, 0, 2.53), Vector3(0.13, 2.6, 0.11), _cream)
	_box(Vector3(-296, -1.0, 77), Vector3(48, 2, 40), _stone)
	_box(Vector3(-317, -1.0, 116), Vector3(9, 2, 43), _stone)
	for z: float in [61, 78, 95, 111, 129]:
		_cylinder(Vector3(-320, 0.45, z), 0.5, 0.5, 0.9, _navy, 8)
	_crane(Vector3(-284, 0, 70))
	_boat(Vector3(-313, -4.2, 34), 0.2, _rust)
	_boat(Vector3(-340, -4.2, 117), PI, _teal)
	# A few windbreak trees mark the quieter start/finish approach without hiding turns.
	for pos: Vector3 in [Vector3(-212, 0, -22), Vector3(-194, 0, -48), Vector3(-167, 0, -67), Vector3(-130, 0, 160), Vector3(-116, 0, 139), Vector3(-105, 0, 112)]:
		_tree(pos)

func _crane(at: Vector3) -> void:
	var crane := Node3D.new()
	crane.position = at
	add_child(crane)
	for x: float in [-3.0, 3.0]:
		for z: float in [-3.0, 3.0]:
			_beam(Vector3(x, 0, z), Vector3(x * 0.48, 24, z * 0.48), 0.9, _navy, crane)
	for y: float in [5, 12, 19]:
		_beam(Vector3(-2.7, y, -2.7), Vector3(2.7, y + 5, -2.7), 0.5, _teal, crane)
		_beam(Vector3(-2.7, y, 2.7), Vector3(2.7, y + 5, 2.7), 0.5, _teal, crane)
	_box(Vector3(-12, 25, 0), Vector3(39, 2, 2.0), _rust, crane)
	_box(Vector3(4, 23.6, 0), Vector3(5.0, 4.0, 4.5), _navy, crane)
	_box(Vector3(4, 24.1, 2.3), Vector3(3.7, 1.5, 0.10), _window, crane)
	_beam(Vector3(-28, 24, 0), Vector3(-28, 4.5, 0), 0.12, _navy, crane)
	_box(Vector3(-28, 4.2, 0), Vector3(1.3, 0.7, 0.7), _rust, crane)
	_beam(Vector3(3, 28, 0), Vector3(-29, 25.8, 0), 0.20, _cream, crane)

func _boat(at: Vector3, yaw: float, material: Material, scale_factor: float = 1.0) -> Node3D:
	var boat := Node3D.new()
	boat.position = at
	boat.rotation.y = yaw
	boat.scale = Vector3.ONE * scale_factor
	add_child(boat)
	var outline := PackedVector2Array([Vector2(-3.4, 7.5), Vector2(3.4, 7.5), Vector2(3.4, -4.0), Vector2(0, -10.0), Vector2(-3.4, -4.0)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var j := (i + 1) % outline.size()
		var a := Vector3(outline[i].x, 0, outline[i].y)
		var b := Vector3(outline[j].x, 0, outline[j].y)
		var c := b * Vector3(0.77, 1, 0.85) + Vector3.UP * 2.4
		var d := a * Vector3(0.77, 1, 0.85) + Vector3.UP * 2.4
		var normal := (b - a).cross(d - a).normalized()
		_triangle(st, a, b, c, normal)
		_triangle(st, a, c, d, normal)
		_triangle(st, Vector3(0, 2.4, 0), d, c, Vector3.UP)
	var hull_material := material.duplicate() as StandardMaterial3D
	hull_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh(st.commit(), hull_material, Vector3.ZERO, boat)
	_box(Vector3(0, 3.6, 2.4), Vector3(4.3, 2.8, 4.6), _cream, boat)
	_box(Vector3(0, 4.8, 2.4), Vector3(4.8, 0.3, 5.1), _navy, boat)
	_box(Vector3(0, 4.0, -0.0), Vector3(3.2, 1.0, 0.10), _window, boat)
	_cylinder(Vector3(1.2, 5.4, 3.8), 0.48, 0.48, 1.8, _rust, 8, boat)
	_beam(Vector3(-0.8, 4.9, 3), Vector3(-0.8, 8.4, 3), 0.13, _navy, boat)
	return boat

func _tree(at: Vector3) -> void:
	# Native Kenney asset, deliberately placed in a small harbor windbreak rather than scattered everywhere.
	var scene := load("res://assets/kenney_nature_kit/tree_pineRoundA.glb") as PackedScene
	var tree := scene.instantiate() as Node3D
	tree.position = at
	tree.scale = Vector3.ONE * 4.4
	add_child(tree)

func _build_boatyard() -> void:
	# An unmistakable inside-apex workshop is the braking hairpin's memory anchor.
	_box(Vector3(88, 0.025, -98), Vector3(34, 0.05, 27), _material(Color("c3bb95")))
	_warehouse(Vector3(91, 0, -100), Vector3(15, 7, 12), _teal, PI * 0.5, "DRY DOCK")
	var boat := _boat(Vector3(72, 1.1, -98), 0, _rust, 0.7)
	boat.name = "BoatyardHullOnCradle"
	for z: float in [-101.5, -94.5]:
		_box(Vector3(72, 0.75, z), Vector3(6, 1.5, 0.6), _navy)
	for i in 3:
		_cylinder(Vector3(105, 0.8, -108 + float(i) * 3), 0.85, 0.85, 1.6, _rust, 8)

func _build_lighthouse() -> void:
	var beacon := Node3D.new()
	beacon.name = "CapeLighthouse"
	beacon.position = Vector3(90, 0, 184)
	add_child(beacon)
	_cylinder(Vector3(0, 0.8, 0), 13.0, 12.0, 1.6, _stone, 12, beacon)
	_cylinder(Vector3(0, 2.2, 0), 7.5, 7.0, 1.8, _cream, 12, beacon)
	# White / terracotta shaft bands remain recognizable from every approach angle.
	for band in 6:
		var bottom := 5.4 - float(band) * 0.28
		_cylinder(Vector3(0, 5.5 + band * 5.0, 0), bottom, bottom - 0.28, 5.0, _cream if band % 2 == 0 else _rust, 12, beacon)
	_cylinder(Vector3(0, 33.2, 0), 6.5, 6.5, 1.0, _cream, 12, beacon)
	_cylinder(Vector3(0, 34.2, 0), 5.5, 5.5, 0.45, _navy, 12, beacon)
	_cylinder(Vector3(0, 36.5, 0), 4.0, 4.0, 4.4, _window, 12, beacon)
	for i in 8:
		var angle := TAU * float(i) / 8.0
		_box(Vector3(cos(angle) * 4.1, 36.5, sin(angle) * 4.1), Vector3(0.30, 4.7, 0.30), _navy, beacon)
	_cylinder(Vector3(0, 39.7, 0), 5.6, 0.0, 3.4, _rust, 12, beacon)
	_cylinder(Vector3(0, 42.0, 0), 0.22, 0.12, 2.4, _navy, 8, beacon)
	_box(Vector3(0, 4.5, -5.15), Vector3(2.5, 4.3, 0.22), _navy, beacon)
	_box(Vector3(0, 13.5, -4.67), Vector3(1.0, 2.0, 0.2), _navy, beacon)
	_box(Vector3(4.05, 23.5, 0), Vector3(0.2, 2.0, 1.0), _navy, beacon)
	_warehouse(Vector3(63, 0, 186), Vector3(15, 6, 12), _rust, -0.3, "BEACON 07")
	_box(Vector3(75, 0.045, 164), Vector3(26, 0.09, 4), _stone).rotation.y = 0.48
	# A navy bench and low stone wall make the inner cape readable as a destination.
	_box(Vector3(103, 0.65, 209), Vector3(17, 1.3, 1.0), _stone)
	_box(Vector3(95, 0.65, 208), Vector3(5, 0.30, 1.3), _navy)

func _build_bridge() -> void:
	var bridge := Node3D.new()
	bridge.name = "BreakwaterBoostBridge"
	add_child(bridge)
	# Flat deck shares the road's grade: no forced hop, crest or hidden velocity gate.
	_box(Vector3(-30, -0.55, 264), Vector3(244, 1.1, 26), _stone, bridge)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(-30, -0.10, 264 + side * 12.3), Vector3(244, 0.55, 0.7), _teal, bridge)
		_box(Vector3(-30, -1.8, 264 + side * 11.5), Vector3(244, 0.75, 1.0), _navy, bridge)
		for x: float in [-130, -80, -30, 20, 70]:
			_box(Vector3(x, -4.4, 264 + side * 8), Vector3(3.8, 7.6, 3.8), _stone, bridge)
		for i in 12:
			var x := -150.0 + float(i) * 20.0
			_beam(Vector3(x, -0.7, 264 + side * 11.5), Vector3(x + 20, -3.0, 264 + side * 11.5), 0.55, _navy, bridge)
	# Two widely spaced frame towers create an obvious straight-line acceleration target.
	for x: float in [-85, 35]:
		for side: float in [-1.0, 1.0]:
			_box(Vector3(x, 7.4, 264 + side * 14.4), Vector3(2.1, 16.0, 2.1), _rust, bridge)
			_box(Vector3(x, 0.6, 264 + side * 14.4), Vector3(3.5, 1.2, 3.5), _cream, bridge)
			_beam(Vector3(x, 15.2, 264 + side * 14.4), Vector3(x - 46, 2.6, 264 + side * 13.2), 0.16, _cream, bridge)
			_beam(Vector3(x, 15.2, 264 + side * 14.4), Vector3(x + 46, 2.6, 264 + side * 13.2), 0.16, _cream, bridge)
			for anchor_x: float in [x - 46, x + 46]:
				_box(Vector3(anchor_x, 1.25, 264 + side * 13.2), Vector3(1.6, 2.7, 1.8), _stone, bridge)
		_box(Vector3(x, 14.8, 264), Vector3(2.1, 1.8, 30.9), _rust, bridge)
		_box(Vector3(x, 13.3, 264), Vector3(1.0, 0.6, 26.5), _navy, bridge)
	# Water glints emphasize the channel through the inland bay, not a painted blue floor.
	var glint := _material(Color("87c5bc"))
	for mark: Vector3 in [Vector3(-120, -5.36, 296), Vector3(-63, -5.36, 238), Vector3(-26, -5.36, 307), Vector3(25, -5.36, 285)]:
		_box(mark, Vector3(16, 0.025, 0.7), glint)

func _build_reefs() -> void:
	var rock_material := _material(Color("839a90"))
	# Deliberate offshore clusters frame the S-bends and the open cape horizon.
	for item: Vector3 in [Vector3(-91, -5.0, -224), Vector3(-70, -4.3, -235), Vector3(-40, -5.1, -237), Vector3(20, -4.0, -246), Vector3(185, -4.1, -115), Vector3(232, -4.5, 132), Vector3(230, -4.8, 218), Vector3(204, -4.1, 263)]:
		var mesh := SphereMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 3
		mesh.radius = 7.5
		mesh.height = 12.0
		var rock := _mesh(mesh, rock_material, item)
		rock.scale = Vector3(1.5, 0.85, 0.9)
		rock.rotation.y = item.x * 0.1
	# A small offshore beacon points toward the final corner without hiding its entry.
	_cylinder(Vector3(-219, -0.5, 307), 5.0, 3.0, 10.0, _stone, 8)
	_cylinder(Vector3(-219, 6.6, 307), 1.7, 1.1, 5.0, _rust, 8)
	_cylinder(Vector3(-219, 9.4, 307), 1.5, 0, 1.0, _cream, 8)
