extends SceneTree
## Real CharacterBody3D physics on a flat test ground; no position edits while driving.
var failures: int = 0
var checks: int = 0
var arena: Node3D
var car: ArcadeCar

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func steps(count: int) -> void:
	for i in count:
		await physics_frame

func reset(at: Vector3 = Vector3(0, 0.35, 0)) -> void:
	car.reset_to(Transform3D(Basis.IDENTITY, at))
	car.throttle = 0.0
	car.steering = 0.0
	car.handbrake = false
	car.on_road = true
	await steps(30)

func body(at: Vector3, size: Vector3) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.position = at
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	result.add_child(shape)
	arena.add_child(result)
	return result

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	arena = Node3D.new()
	root.add_child(arena)
	body(Vector3(0, -0.5, 0), Vector3(2000, 1, 2000))
	car = ArcadeCar.new()
	car.external_input = true
	car.driving_enabled = true
	arena.add_child(car)
	check(is_instance_valid(car.model) and is_instance_valid(car.engine), "model and engine resources load")
	if not is_instance_valid(car.engine):
		quit(1)
		return
	check(car.wheel_meshes.size() == 4 and car.wheel_pivots.size() == 4, "four model wheels are independently animated")
	await reset()
	var height := car.global_position.y
	car.steering = 1.0
	await steps(60)
	check(absf(car.rotation.y) < 0.01 and absf(car.signed_speed) < 0.01, "steering cannot rotate a stationary car")
	car.steering = 0.0
	car.throttle = 1.0
	await steps(180)
	check(car.signed_speed > 40.0 and car.signed_speed <= ArcadeCar.MAX_SPEED + 0.01, "acceleration reaches and respects speed cap: %.2f" % car.signed_speed)
	check(absf(car.global_position.y - height) < 0.05 and car.is_on_floor(), "ground collision stays stable at speed")
	check(absf(car.wheel_spin) > 10.0, "wheel spin follows driven distance")
	car.throttle = -1.0
	await steps(60)
	check(car.signed_speed < 12.0 and car.signed_speed > 0.0, "brake decelerates before reversing: %.2f" % car.signed_speed)
	await steps(120)
	check(car.signed_speed < -8.0 and car.signed_speed >= -ArcadeCar.REVERSE_SPEED - 0.01, "continued brake enters bounded reverse: %.2f" % car.signed_speed)
	await reset()
	car.throttle = 1.0
	await steps(60)
	car.steering = 1.0
	await steps(30)
	check(car.rotation.y > 0.2, "left steering turns forward car left")
	await reset()
	car.throttle = -1.0
	await steps(90)
	car.steering = 1.0
	await steps(30)
	check(car.rotation.y < -0.2, "steering yaw reverses while backing up")
	await reset()
	car.velocity = Vector3(0, 0, -8)
	car.steering = 1.0
	await steps(18)
	var low_speed_yaw := absf(car.rotation.y)
	await reset()
	car.velocity = Vector3(0, 0, -43)
	car.steering = 1.0
	await steps(18)
	check(absf(car.rotation.y) < low_speed_yaw, "steering response is reduced at high speed")
	await reset()
	car.velocity = Vector3(8, 0, -15)
	await steps(20)
	check(absf(car.velocity.x) < 0.6, "ordinary steering retains stable lateral grip")
	await steps(60)
	check(absf(car.velocity.x) < 0.02, "lateral slip naturally recovers")
	await reset()
	car.velocity = Vector3(0, 0, -43)
	car.on_road = false
	car.throttle = 1.0
	await steps(90)
	check(car.signed_speed <= 17.1 and car.signed_speed > 10.0, "off-road resistance limits speed: %.2f" % car.signed_speed)
	var samples: Array[Dictionary] = []
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		await reset()
		var start := car.global_position
		car.throttle = 1.0
		await steps(hz + 1)
		samples.append({"speed": car.signed_speed, "distance": start.distance_to(car.global_position)})
		print("DT SAMPLE %d Hz: %s" % [hz, str(samples[-1])])
	check(absf(samples[0].speed - samples[2].speed) < 0.8 and absf(samples[0].distance - samples[2].distance) < 0.8, "30 / 60 / 120 Hz acceleration remains consistent")
	Engine.physics_ticks_per_second = 60
	await reset()
	body(Vector3(0, 1, -30), Vector3(30, 2, 1))
	car.throttle = 1.0
	await steps(240)
	check(car.global_position.z > -29.5 and car.global_position.y < 2.0 and car.velocity.length() < 2.0, "wall collision stops car without tunneling or explosive velocity")
	check(car.global_position.is_finite() and car.velocity.is_finite(), "physics state remains finite")
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(20, 0.35, 0)))
	check(car.velocity.is_zero_approx() and car.signed_speed == 0.0 and car.steer_smoothed == 0.0, "reset clears motion and steering")
	car.engine.stop()
	car.engine.stream = null
	await create_timer(0.1).timeout
	arena.queue_free()
	await process_frame
	print("CAR TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
