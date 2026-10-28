class_name ArcadeCar
extends CharacterBody3D
## Original kart-inspired arcade handling. Collision stays upright; drift yaw is bounded.
## All handling/timing values live here; speed is m/s and charge/timers are seconds.
const MAX_SPEED: float = 43.0
const REVERSE_SPEED: float = 9.0
const OFFROAD_SPEED: float = 17.0
const ACCELERATION: float = 16.0
const BOOST_SPEED: float = 54.0
const BOOST_ACCELERATION: float = 34.0
const DRIFT_ENTRY_SPEED: float = 12.0
const DRIFT_MIN_SPEED: float = 9.0
const DRIFT_SPEED: float = 39.0
const DRIFT_BLUE_CHARGE: float = 0.75
const DRIFT_ORANGE_CHARGE: float = 1.55
const BLUE_TURBO_DURATION: float = 0.65
const ORANGE_TURBO_DURATION: float = 1.15
const NITRO_DRAIN: float = 0.25
const NITRO_RECHARGE: float = 0.10
const NITRO_RECHARGE_DELAY: float = 0.8
const EffectsScript = preload("res://scripts/kart_effects.gd")
var throttle: float = 0.0
var steering: float = 0.0
# Keep the existing action/property name so saved bindings and QA inputs stay compatible.
var handbrake: bool = false
var nitro_pressed: bool = false
var nitro: float = 1.0
var nitro_active: bool = false
var boost_active: bool = false
var drift_active: bool = false
var drift_direction: float = 0.0
var drift_charge: float = 0.0
var drift_tier: int = 0
var mini_turbo_time: float = 0.0
var _drift_held: bool = false
var _recharge_delay: float = 0.0
var effects: Node3D
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
	effects = EffectsScript.new()
	visual.add_child(effects)
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
		nitro_pressed = Input.is_action_pressed("nitro")
	if not driving_enabled:
		throttle = 0.0
		steering = 0.0
		clear_boost_and_drift()
		velocity = Vector3.ZERO
		signed_speed = 0.0
		engine.volume_db = -42.0
		return
	if track:
		on_road = absf(float(track.nearest(global_position).lateral)) <= TrackWorld.ROAD_HALF_WIDTH + 0.5
	var forward := -global_basis.z
	var old_speed := velocity.dot(forward)
	var grounded := is_on_floor()
	var valid_drift := grounded and on_road and old_speed >= DRIFT_MIN_SPEED and throttle >= 0.0
	var release_tier := 0
	# Press, don't merely hold: grass/wall/air cancellation requires a fresh Space press.
	if handbrake and not _drift_held and valid_drift and old_speed >= DRIFT_ENTRY_SPEED and absf(steering) >= 0.2:
		drift_active = true
		drift_direction = signf(steering)
		drift_charge = 0.0
		drift_tier = 0
	if drift_active:
		if not valid_drift:
			_cancel_drift()
		elif not handbrake:
			release_tier = drift_tier
			_cancel_drift()
	_drift_held = handbrake
	steer_smoothed = move_toward(steer_smoothed, steering, delta * 4.6)
	var speed_ratio := clampf(absf(old_speed) / MAX_SPEED, 0.0, 1.0)
	var yaw_rate := lerpf(1.75, 0.95, speed_ratio) * clampf(absf(old_speed) / 8.0, 0.0, 1.0)
	var turn := steer_smoothed
	if drift_active:
		# Steering into the corner tightens it; countersteer widens it, never snaps direction.
		turn = drift_direction * clampf(0.45 + steer_smoothed * drift_direction * 0.65, 0.12, 1.05)
	rotation.y += turn * signf(old_speed) * yaw_rate * delta
	forward = -global_basis.z
	var right := global_basis.x
	var longitudinal := velocity.dot(forward)
	var lateral := velocity.dot(right)
	var can_boost := grounded and on_road and old_speed > 4.0 and throttle > 0.0
	if not grounded or not on_road or old_speed < 0.0 or throttle < 0.0:
		mini_turbo_time = 0.0
	nitro_active = nitro_pressed and nitro > 0.00001 and can_boost
	boost_active = can_boost and (nitro_active or mini_turbo_time > 0.0)
	if nitro_active:
		nitro = maxf(0.0, nitro - NITRO_DRAIN * delta)
		_recharge_delay = NITRO_RECHARGE_DELAY
	elif not nitro_pressed:
		_recharge_delay = maxf(0.0, _recharge_delay - delta)
		if _recharge_delay <= 0.0:
			nitro = minf(1.0, nitro + NITRO_RECHARGE * delta)
	mini_turbo_time = maxf(0.0, mini_turbo_time - delta)
	var speed_limit := BOOST_SPEED if boost_active else (DRIFT_SPEED if drift_active else MAX_SPEED)
	if not on_road:
		speed_limit = OFFROAD_SPEED
	if throttle > 0.0:
		var acceleration := BOOST_ACCELERATION if boost_active else ACCELERATION
		longitudinal = move_toward(longitudinal, speed_limit, (acceleration if longitudinal >= 0 else 34.0) * throttle * delta)
	elif throttle < 0.0:
		longitudinal = move_toward(longitudinal, -REVERSE_SPEED, (35.0 if longitudinal > 1.0 else 9.0) * -throttle * delta)
	else:
		longitudinal = move_toward(longitudinal, 0.0, (2.8 if on_road else 8.0) * delta)
	if not on_road:
		longitudinal = move_toward(longitudinal, clampf(longitudinal, -7.0, OFFROAD_SPEED), 20.0 * delta)
	var grip := 4.8 if drift_active else (8.5 if on_road else 4.2)
	lateral = clampf(lateral * exp(-grip * delta), -6.0, 6.0)
	var horizontal := (forward * longitudinal + right * lateral).limit_length(BOOST_SPEED)
	velocity = horizontal + Vector3.UP * (velocity.y - 24.0 * delta)
	move_and_slide()
	var wall_hit := false
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if absf(hit.get_normal().y) < 0.5:
			wall_hit = true
			velocity *= 0.97
	# Re-evaluate after motion so crossing onto grass or hitting a rail cannot cash a drift.
	if track:
		on_road = absf(float(track.nearest(global_position).lateral)) <= TrackWorld.ROAD_HALF_WIDTH + 0.5
	if wall_hit or not is_on_floor() or not on_road:
		_cancel_drift()
		mini_turbo_time = 0.0
		boost_active = false
		nitro_active = false
	signed_speed = velocity.dot(forward)
	# Settle rewards only after collision/surface checks, including a release on the impact tick.
	if release_tier > 0 and not wall_hit and is_on_floor() and on_road and signed_speed >= DRIFT_MIN_SPEED:
		mini_turbo_time = ORANGE_TURBO_DURATION if release_tier == 2 else BLUE_TURBO_DURATION
		nitro = minf(1.0, nitro + (0.12 if release_tier == 2 else 0.06))
	if drift_active and signed_speed >= DRIFT_MIN_SPEED:
		# Actual grounded forward corner travel, not time spent holding Space while stopped.
		var travel := global_position.distance_to(previous_position)
		if travel > DRIFT_MIN_SPEED * delta * 0.7 and absf(turn) > 0.13 and absf(turn * yaw_rate) >= 0.16:
			drift_charge = minf(DRIFT_ORANGE_CHARGE, drift_charge + delta)
		drift_tier = 2 if drift_charge >= DRIFT_ORANGE_CHARGE else (1 if drift_charge >= DRIFT_BLUE_CHARGE else 0)
	_update_visuals(delta, speed_ratio)

func _update_visuals(delta: float, speed_ratio: float) -> void:
	wheel_spin += signed_speed * delta / 0.45
	for i in wheel_pivots.size():
		wheel_pivots[i].rotation.y = steer_smoothed * 0.38 if i < 2 else 0.0
		wheel_meshes[i].rotation.x = wheel_spin
	var blend := 1.0 - exp(-8.0 * delta)
	visual.rotation.z = lerpf(visual.rotation.z, -steer_smoothed * speed_ratio * 0.07, blend)
	visual.rotation.x = lerpf(visual.rotation.x, -throttle * 0.022, blend)
	visual.rotation.y = lerp_angle(visual.rotation.y, drift_direction * 0.12 if drift_active else 0.0, blend)
	effects.update_effects(delta, drift_active, drift_tier, boost_active, signed_speed)
	engine.pitch_scale = 0.65 + absf(signed_speed) / 31.0 + (0.12 if boost_active else 0.0)
	engine.volume_db = -27.0 if absf(throttle) > 0.1 else -34.0

func _cancel_drift() -> void:
	drift_active = false
	drift_direction = 0.0
	drift_charge = 0.0
	drift_tier = 0

func clear_boost_and_drift() -> void:
	_cancel_drift()
	mini_turbo_time = 0.0
	nitro_active = false
	boost_active = false
	# Do not re-arm a held Space after reset or after a blocked race state.
	_drift_held = handbrake
	if effects:
		effects.clear()

func reset_to(value: Transform3D) -> void:
	global_transform = value
	velocity = Vector3.ZERO
	signed_speed = 0.0
	steer_smoothed = 0.0
	previous_position = global_position
	clear_boost_and_drift()
	# Checkpoint recovery must not refill the bottle or bypass its recharge delay.
	_recharge_delay = maxf(_recharge_delay, NITRO_RECHARGE_DELAY)
	if visual:
		visual.rotation = Vector3.ZERO

func reset_for_race() -> void:
	clear_boost_and_drift()
	nitro = 1.0
	_recharge_delay = 0.0

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
