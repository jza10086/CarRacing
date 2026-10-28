class_name KartEffects
extends Node3D
## Original low-poly feedback. CPU particles work with Compatibility/OpenGL.
## Attach below the car's visual pivot; its forward direction is -Z.
const BLUE := Color("66dbff")
const ORANGE := Color("ffb447")
var smoke: Array[CPUParticles3D] = []
var sparks: Array[CPUParticles3D] = []
var flames: Array[Node3D] = []
var wheel_glints: Array[Node3D] = []
var glint_material: StandardMaterial3D
var phase: float = 0.0
var last_tier: int = -1

func _ready() -> void:
	var smoke_mesh := SphereMesh.new()
	smoke_mesh.radius = 0.15
	smoke_mesh.height = 0.25
	smoke_mesh.radial_segments = 6
	smoke_mesh.rings = 3
	smoke_mesh.material = _material(Color.WHITE, true)
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.045, 0.045, 0.14)
	spark_mesh.material = _material(Color.WHITE, true)
	glint_material = _material(BLUE)
	for side in [-1.0, 1.0]:
		# Actual scaled Kenney rear-wheel contact points, not the body center.
		var at := Vector3(side * 0.90, 0.16, 1.04)
		var puff := _particles(at, smoke_mesh, 10, 0.28)
		puff.local_coords = true
		puff.direction = Vector3(side * 0.2, 0.4, 1.0)
		puff.spread = 32.0
		puff.initial_velocity_min = 0.7
		puff.initial_velocity_max = 1.4
		puff.gravity = Vector3(0, 0.6, 0)
		puff.scale_amount_min = 0.6
		puff.scale_amount_max = 1.25
		puff.color_ramp = _fade(Color(0.76, 0.84, 0.85, 0.24))
		smoke.append(puff)
		var spark := _particles(at + Vector3(0, 0.05, 0), spark_mesh, 18, 0.23)
		# Anchor the short spray to the tire, including slow render catch-up frames.
		spark.local_coords = true
		spark.direction = Vector3(side * 0.55, 0.6, 1.0)
		spark.spread = 28.0
		spark.initial_velocity_min = 2.0
		spark.initial_velocity_max = 4.4
		spark.gravity = Vector3(0, -4.0, 0)
		spark.color_ramp = _fade(Color.WHITE)
		sparks.append(spark)
		wheel_glints.append(_wheel_glint(at + Vector3(side * 0.12, 0.0, 0.0), side))
		var flame := Node3D.new()
		flame.position = Vector3(side * 0.43, 0.34, 1.88)
		add_child(flame)
		_cone(flame, 0.15, 0.95, Color(BLUE.r, BLUE.g, BLUE.b, 0.72))
		_cone(flame, 0.085, 0.62, Color("fff0bd"))
		flame.visible = false
		flames.append(flame)

func _wheel_glint(at: Vector3, side: float) -> Node3D:
	# Three tiny angular strokes make the charge source legible at the contact patch.
	var source := Node3D.new()
	source.position = at
	source.visible = false
	add_child(source)
	for i in 3:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.045, 0.045, 0.24)
		var stroke := MeshInstance3D.new()
		stroke.mesh = mesh
		stroke.material_override = glint_material
		stroke.position = Vector3(side * (0.04 + i * 0.07), i * 0.06, i * 0.05)
		stroke.rotation = Vector3(-0.25 - i * 0.3, side * (0.3 + i * 0.3), 0.0)
		stroke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		source.add_child(stroke)
	return source

func _particles(at: Vector3, mesh: Mesh, count: int, lifetime: float) -> CPUParticles3D:
	var result := CPUParticles3D.new()
	result.position = at
	result.mesh = mesh
	result.amount = count
	result.lifetime = lifetime
	result.local_coords = false
	result.emitting = false
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(result)
	return result

func _material(color: Color, alpha: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alpha:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material

func _fade(color: Color) -> Gradient:
	var result := Gradient.new()
	result.set_color(0, color)
	result.set_color(1, Color(color.r, color.g, color.b, 0.0))
	return result

func _cone(parent: Node3D, radius: float, length: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 6
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _material(color, color.a < 1.0)
	node.rotation.x = PI * 0.5
	node.position.z = length * 0.5
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

func update_effects(delta: float, drifting: bool, tier: int, boosting: bool, speed: float) -> void:
	phase += delta * 35.0
	var slipping := drifting and speed > 8.0
	for emitter in smoke:
		emitter.emitting = slipping
		emitter.visible = slipping
	for emitter in sparks:
		emitter.emitting = slipping and tier > 0
		emitter.visible = slipping and tier > 0
		if tier != last_tier:
			emitter.color = ORANGE if tier >= 2 else BLUE
	if tier != last_tier:
		glint_material.albedo_color = ORANGE if tier >= 2 else BLUE
	for source in wheel_glints:
		source.visible = slipping and tier > 0
		source.scale = Vector3.ONE * (0.92 + 0.08 * sin(phase))
	last_tier = tier
	for i in flames.size():
		flames[i].visible = boosting and speed > 1.0
		flames[i].scale = Vector3(1.0, 1.0, 0.88 + 0.12 * sin(phase + i * 1.7))

func clear() -> void:
	for emitter in smoke + sparks:
		emitter.restart()
		emitter.emitting = false
		emitter.visible = false
	for flame in flames:
		flame.visible = false
	for source in wheel_glints:
		source.visible = false
	last_tier = -1
