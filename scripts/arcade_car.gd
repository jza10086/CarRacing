class_name ArcadeCar
extends CharacterBody3D
## Upright arcade handling: visual lean is independent of the collision body.
const MAX_SPEED: float = 43.0
const REVERSE_SPEED: float = 9.0
var throttle: float = 0.0
var steering: float = 0.0
var handbrake: bool = false
var driving_enabled: bool = false
var on_road: bool = true
var steer_smoothed: float = 0.0
var signed_speed: float = 0.0
var visual: Node3D
var model: Node3D
var wheel_pivots: Array[Node3D] = []
var wheel_meshes: Array[Node3D] = []
var wheel_spin: float = 0.0
var engine: AudioStreamPlayer
var track: TrackWorld
var external_input: bool = false
var previous_position: Vector3

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.6
	floor_stop_on_slope = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 1.3, 3.5)
	collision.shape = shape
	collision.position.y = 0.65
	add_child(collision)
	visual = Node3D.new()
	add_child(visual)
	model = load("res://assets/kenney_car_kit/sedan-sports.glb").instantiate()
	model.rotation.y = PI
	model.scale = Vector3.ONE * 1.5
	visual.add_child(model)
	for node_name in ["wheel-front-left", "wheel-front-right", "wheel-back-left", "wheel-back-right"]:
		var wheel := model.find_child(node_name, true, false) as Node3D
		if wheel:
			var pivot := Node3D.new()
			pivot.position = wheel.position
			wheel.get_parent().add_child(pivot)
			wheel.reparent(pivot, false)
			wheel.position = Vector3.ZERO
			wheel_pivots.append(pivot)
			wheel_meshes.append(wheel)
	engine = AudioStreamPlayer.new()
	engine.stream = _engine_wave()
	engine.volume_db = -26.0
	add_child(engine)
	engine.play()

func _physics_process(delta: float) -> void:
	previous_position = global_position
	if not external_input:
		throttle = Input.get_action_strength("accelerate") - Input.get_action_strength("brake")
		steering = Input.get_action_strength("steer_left") - Input.get_action_strength("steer_right")
		handbrake = Input.is_action_pressed("handbrake")
	if not driving_enabled:
		throttle = 0.0
		steering = 0.0
		handbrake = false
		velocity = Vector3.ZERO
		engine.volume_db = -42.0
		return
	if track:
		on_road = absf(float(track.nearest(global_position).lateral)) <= TrackWorld.ROAD_HALF_WIDTH + 0.5
	var forward := -global_basis.z
	var old_speed := velocity.dot(forward)
	steer_smoothed = move_toward(steer_smoothed, steering, delta * 4.6)
	var speed_ratio := clampf(absf(old_speed) / MAX_SPEED, 0.0, 1.0)
	var yaw_rate := lerpf(1.75, 0.95, speed_ratio) * clampf(absf(old_speed) / 8.0, 0.0, 1.0)
	if handbrake:
		yaw_rate *= 1.23
	rotation.y += steer_smoothed * signf(old_speed) * yaw_rate * delta
	forward = -global_basis.z
	var right := global_basis.x
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	if throttle > 0.0:
		longitudinal = move_toward(longitudinal, MAX_SPEED if on_road else 17.0, (16.0 if longitudinal >= 0 else 34.0) * throttle * delta)
	elif throttle < 0.0:
		longitudinal = move_toward(longitudinal, -REVERSE_SPEED, (35.0 if longitudinal > 1.0 else 9.0) * -throttle * delta)
	else:
		longitudinal = move_toward(longitudinal, 0.0, (2.8 if on_road else 8.0) * delta)
	if not on_road:
		longitudinal = move_toward(longitudinal, clampf(longitudinal, -7.0, 17.0), 20.0 * delta)
	if handbrake:
		longitudinal = move_toward(longitudinal, 0.0, 11.0 * delta)
	var grip := (8.5 if on_road else 4.2) if not handbrake else 2.3
	lateral *= exp(-grip * delta)
	var vertical := velocity.y - 24.0 * delta
	velocity = forward * longitudinal + right * lateral + Vector3.UP * vertical
	move_and_slide()
	signed_speed = velocity.dot(forward)
	if get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var hit := get_slide_collision(i)
			if absf(hit.get_normal().y) < 0.5:
				velocity *= 0.97
	wheel_spin += signed_speed * delta / 0.45
	for i in wheel_pivots.size():
		wheel_pivots[i].rotation.y = steer_smoothed * 0.38 if i < 2 else 0.0
		wheel_meshes[i].rotation.x = wheel_spin
	visual.rotation.z = lerpf(visual.rotation.z, -steer_smoothed * speed_ratio * 0.07, 1.0 - exp(-8.0 * delta))
	visual.rotation.x = lerpf(visual.rotation.x, -throttle * 0.022, 1.0 - exp(-8.0 * delta))
	engine.pitch_scale = 0.65 + absf(signed_speed) / 31.0
	engine.volume_db = -27.0 if absf(throttle) > 0.1 else -34.0

func reset_to(value: Transform3D) -> void:
	global_transform = value
	velocity = Vector3.ZERO
	signed_speed = 0.0
	steer_smoothed = 0.0
	previous_position = global_position
	if visual:
		visual.rotation = Vector3.ZERO

func _engine_wave() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := 2205
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var phase := TAU * 80.0 * float(i) / 22050.0
		var value := (sin(phase) * 0.55 + sin(phase * 2.0) * 0.26 + sin(phase * 4.0) * 0.10) * 10000.0
		data.encode_s16(i * 2, int(value))
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream

func _exit_tree() -> void:
	if is_instance_valid(engine):
		engine.stop()
		engine.stream = null
