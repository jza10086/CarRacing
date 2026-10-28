extends SceneTree
## Focused real-physics checks in a flat fixture; race-state checks live in test_rules.gd.
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

func reset() -> void:
	car.driving_enabled = true
	car.throttle = 0.0
	car.steering = 0.0
	car.handbrake = false
	car.nitro_pressed = false
	car.on_road = true
	car.reset_for_race()
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))
	await steps(int(Engine.physics_ticks_per_second * 0.4) + 1)

func enter_drift(direction: float = 1.0) -> void:
	car.velocity = Vector3(0, 0, -25)
	car.throttle = 1.0
	car.steering = direction * 0.5
	car.handbrake = true
	await steps(3)

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	arena = Node3D.new()
	root.add_child(arena)
	body(Vector3(0, -0.5, 0), Vector3(2000, 1, 2000))
	car = ArcadeCar.new()
	car.external_input = true
	car.driving_enabled = true
	arena.add_child(car)
	await reset()
	car.steering = 1.0
	car.handbrake = true
	await steps(60)
	check(not car.drift_active and car.drift_charge == 0.0, "stationary Space cannot enter or farm drift")
	car.throttle = 1.0
	await steps(70)
	check(not car.drift_active, "holding Space through the speed threshold does not auto-enter")
	await reset()
	car.velocity = Vector3(0, 0, 9)
	car.throttle = -1.0
	car.steering = 1.0
	car.handbrake = true
	car.nitro_pressed = true
	await steps(60)
	check(not car.drift_active and not car.boost_active and is_equal_approx(car.nitro, 1.0), "reverse cannot drift, boost or consume nitro")
	await reset()
	car.velocity = Vector3(0, 0, -25)
	car.throttle = 1.0
	car.handbrake = true
	await steps(30)
	check(not car.drift_active and car.drift_charge == 0.0, "straight Space without steering cannot charge")
	await reset()
	car.velocity = Vector3(0, 0, -ArcadeCar.DRIFT_ENTRY_SPEED + 0.5)
	car.steering = 0.5
	car.handbrake = true
	await steps(3)
	check(not car.drift_active, "speed just below the entry threshold cannot start a drift")
	await reset()
	car.throttle = 1.0
	car.nitro_pressed = true
	await steps(3)
	check(not car.nitro_active and car.nitro == 1.0, "nitro does not activate or drain before forward motion")
	await reset()
	await enter_drift()
	check(car.drift_active and car.drift_direction == 1.0, "forward speed plus left steer enters committed left drift")
	await steps(20)
	var yaw_before := car.rotation.y
	car.steering = -1.0
	await steps(35)
	check(car.drift_active and car.drift_direction == 1.0 and car.rotation.y > yaw_before, "countersteer widens drift without reversing its direction")
	check(absf(car.velocity.dot(car.global_basis.x)) <= 6.01 and absf(car.visual.rotation.y) <= 0.13, "drift slip and visual yaw stay bounded")
	var charge_before := car.drift_charge
	await steps(30)
	check(absf(car.drift_charge - charge_before) < 0.02, "near-straight full countersteer cannot farm additional charge")
	# At 15 m/s the yaw-rate multiplier alone used to permit a straightened drift to farm.
	car.velocity = -car.global_basis.z * 15.0
	car.throttle = 0.0
	charge_before = car.drift_charge
	await steps(30)
	check(car.drift_active and car.signed_speed > ArcadeCar.DRIFT_MIN_SPEED and absf(car.drift_charge - charge_before) < 0.02, "low-speed full countersteer cannot farm charge despite its larger yaw multiplier")
	await reset()
	await enter_drift()
	await steps(10)
	car.handbrake = false
	await steps(2)
	check(car.mini_turbo_time == 0.0 and not car.boost_active, "early release below blue threshold gives no mini-turbo")
	await reset()
	await enter_drift(-1.0)
	check(car.drift_active and car.drift_direction == -1.0 and car.rotation.y < 0.0, "right drift mirrors left drift")
	await reset()
	await enter_drift()
	await steps(50)
	check(car.drift_tier == 1 and car.drift_charge >= ArcadeCar.DRIFT_BLUE_CHARGE, "grounded corner travel reaches blue tier")
	car.handbrake = false
	await steps(2)
	check(not car.drift_active and car.boost_active and car.mini_turbo_time > 0.5 and car.mini_turbo_time <= ArcadeCar.BLUE_TURBO_DURATION, "blue release grants short mini-turbo and clears charge")
	await steps(50)
	check(car.mini_turbo_time == 0.0 and not car.boost_active, "blue mini-turbo expires instead of stacking forever")
	await reset()
	await enter_drift()
	await steps(99)
	check(car.drift_tier == 2 and is_equal_approx(car.drift_charge, ArcadeCar.DRIFT_ORANGE_CHARGE), "longer valid corner travel reaches capped orange tier")
	car.nitro = 0.5
	car.handbrake = false
	await steps(2)
	check(car.mini_turbo_time > 1.0 and car.nitro > 0.61, "orange release grants longer turbo and bounded nitro reward")
	await reset()
	await enter_drift()
	await steps(50)
	car.on_road = false
	await steps(2)
	car.handbrake = false
	await steps(2)
	check(not car.drift_active and car.drift_charge == 0.0 and car.mini_turbo_time == 0.0, "grass cancels charge without a release reward")
	car.on_road = true
	car.handbrake = true
	await steps(2)
	car.on_road = false
	await steps(2)
	car.on_road = true
	await steps(20)
	check(not car.drift_active, "returning from grass while holding Space cannot re-arm drift")
	await reset()
	await enter_drift()
	await steps(50)
	car.velocity.y = 10.0
	await steps(3)
	check(not car.is_on_floor() and not car.drift_active and car.drift_charge == 0.0, "airborne motion cancels stored drift charge")
	car.nitro_pressed = true
	var air_nitro := car.nitro
	await steps(5)
	check(not car.boost_active and is_equal_approx(car.nitro, air_nitro), "nitro cannot activate or drain while airborne")
	await reset()
	await enter_drift()
	await steps(50)
	car.throttle = -1.0
	await steps(2)
	check(not car.drift_active and car.mini_turbo_time == 0.0, "braking cancels drift instead of banking a reward")
	await reset()
	car.velocity = Vector3(0, 0, -43)
	car.throttle = 1.0
	car.nitro_pressed = true
	await steps(61)
	check(car.nitro_active and car.nitro > 0.73 and car.nitro < 0.76, "held nitro drains by elapsed time")
	check(car.signed_speed > ArcadeCar.MAX_SPEED and car.velocity.length() <= ArcadeCar.BOOST_SPEED + 0.01, "nitro exceeds normal cap but respects shared boost cap")
	car.mini_turbo_time = ArcadeCar.ORANGE_TURBO_DURATION
	await steps(30)
	check(car.velocity.length() <= ArcadeCar.BOOST_SPEED + 0.01, "simultaneous mini-turbo and nitro do not add speed caps")
	await steps(230)
	check(car.nitro <= 0.00001 and not car.nitro_active and not car.boost_active, "empty held nitro cannot boost or regenerate in pulses")
	await steps(60)
	check(car.nitro <= 0.00001, "continuing to hold an empty bottle leaves it empty")
	car.nitro_pressed = false
	await steps(90)
	check(car.nitro > 0.06 and car.nitro < 0.09, "release waits then passively recharges nitro")
	var remaining := car.nitro
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))
	check(is_equal_approx(car.nitro, remaining) and not car.boost_active and car.mini_turbo_time == 0.0, "checkpoint reset clears boosts but never refills nitro")
	car.reset_for_race()
	check(car.nitro == 1.0 and car.drift_charge == 0.0, "new race restores a full bottle and clears charge")
	await reset()
	await enter_drift()
	await steps(50)
	car.nitro = 0.4
	car.reset_to(Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)))
	check(not car.drift_active and car.drift_charge == 0.0 and is_equal_approx(car.nitro, 0.4), "reset during charged drift gives no turbo or free nitro")
	car.driving_enabled = false
	car.nitro_pressed = true
	car.throttle = 1.0
	car.mini_turbo_time = 1.0
	await steps(30)
	check(not car.boost_active and car.mini_turbo_time == 0.0 and is_equal_approx(car.nitro, 0.4) and car.velocity.is_zero_approx(), "disabled/countdown/finished controller cannot boost or recharge")
	var samples: Array[Dictionary] = []
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		await reset()
		car.velocity = Vector3(0, 0, -25)
		car.throttle = 1.0
		car.steering = 0.5
		car.handbrake = true
		car.nitro_pressed = true
		await steps(hz + 1)
		samples.append({"charge": car.drift_charge, "nitro": car.nitro, "speed": car.signed_speed})
		print("KART DT SAMPLE %d Hz: %s" % [hz, str(samples[-1])])
	check(absf(samples[0].charge - samples[2].charge) < 0.05 and absf(samples[0].nitro - samples[2].nitro) < 0.02, "30 / 60 / 120 Hz drift charge and nitro drain remain consistent")
	Engine.physics_ticks_per_second = 60
	await reset()
	var wall := body(Vector3(0, 1.5, -30), Vector3(100, 3, 1))
	car.velocity = Vector3(0, 0, -43)
	car.throttle = 1.0
	car.nitro_pressed = true
	car.mini_turbo_time = ArcadeCar.ORANGE_TURBO_DURATION
	await steps(90)
	check(car.global_position.z > -29.5 and car.global_position.y < 0.2 and car.velocity.length() < 2.0, "boosted wall impact stops without tunneling or leaving the ground")
	check(car.mini_turbo_time == 0.0 and not car.boost_active and not car.nitro_active, "wall impact cancels mini-turbo and active boost")
	wall.queue_free()
	await reset()
	await enter_drift()
	await steps(50)
	var ahead := car.global_position - car.global_basis.z * 4.0
	wall = body(ahead + Vector3.UP * 1.5, Vector3(100, 3, 1))
	await steps(10)
	check(not car.drift_active and car.drift_charge == 0.0 and car.mini_turbo_time == 0.0, "wall impact cancels a charged drift without reward")
	wall.queue_free()
	await reset()
	# A charged fixture releases into a real wall on this very next movement tick.
	# A 0.25 m gap is smaller than the 25 m/s car's 1/60-second advance.
	wall = body(Vector3(0, 1.5, -2.5), Vector3(100, 3, 1))
	car.velocity = Vector3(0, 0, -25)
	car.throttle = 1.0
	car.drift_active = true
	car.drift_direction = 1.0
	car.drift_charge = ArcadeCar.DRIFT_ORANGE_CHARGE
	car.drift_tier = 2
	car.handbrake = false
	car.nitro = 0.4
	car.nitro_pressed = true
	var before_impact_nitro := car.nitro
	await steps(1)
	var hit_wall := false
	for i in car.get_slide_collision_count():
		if absf(car.get_slide_collision(i).get_normal().y) < 0.5:
			hit_wall = true
	check(hit_wall and not car.drift_active and car.mini_turbo_time == 0.0 and car.nitro <= before_impact_nitro, "release and wall impact on the same physics tick award neither mini-turbo nor nitro bonus")
	check(car.global_position.is_finite() and car.velocity.is_finite(), "all kart physics states stay finite")
	car.engine.stop()
	car.engine.stream = null
	# The audio mixer is a real-time thread even under --fixed-fps fast-forward.
	OS.delay_msec(100)
	await create_timer(0.1).timeout
	arena.queue_free()
	await process_frame
	await process_frame
	print("KART TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
