extends SceneTree
## Deterministic geometry / race-state tests, not a substitute for a driven lap.
var failures: int = 0
var checks: int = 0
var track: TrackWorld

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: " + message)

func fresh() -> RaceRules:
	var rules := RaceRules.new()
	rules.configure(track)
	return rules

func cross(rules: RaceRules, gate_index: int, direction: float = 1.0, offset: float = 0.0) -> void:
	var gate := rules.gates[gate_index]
	var tangent: Vector3 = gate.tangent
	var right := tangent.cross(Vector3.UP)
	var from: Vector3 = gate.position - tangent * direction + right * offset
	var to: Vector3 = gate.position + tangent * direction + right * offset
	var near := track.nearest(to)
	rules.observe(from, to, near.distance, near.lateral)

func traverse(rules: RaceRules, start: float, end: float, offset: float = 0.0) -> void:
	var previous: Vector3 = track.sample_distance(start).position
	var at := start
	while at < end:
		at = minf(at + 1.0, end)
		var sample := track.sample_distance(at)
		var position: Vector3 = sample.position + sample.tangent.cross(Vector3.UP) * offset
		var nearest := track.nearest(position)
		rules.tick(1.0 / 30.0)
		rules.observe(previous, position, nearest.distance, nearest.lateral)
		previous = position

func _run() -> void:
	track = TrackWorld.new()
	track._build_curve()
	check(track.length > 600.0 and track.length < 1100.0, "closed curve length is plausible: %.2f m" % track.length)
	check(track.sample_distance(track.length).position.distance_to(track.sample_distance(0).position) < 0.001, "distance sampling wraps continuously")
	var rules := fresh()
	cross(rules, 4)
	check(rules.next_gate == 0, "out-of-order checkpoint ignored")
	cross(rules, 0, -1.0)
	check(rules.next_gate == 0, "reverse checkpoint ignored")
	cross(rules, 0, 1.0, 12.0)
	check(rules.next_gate == 0, "crossing outside checkpoint corridor ignored")
	cross(rules, 0)
	check(rules.next_gate == 1, "forward expected checkpoint accepted")
	cross(rules, 0, -1.0)
	cross(rules, 0)
	check(rules.next_gate == 1, "repeated checkpoint does not advance order")
	rules = fresh()
	for i in 50:
		cross(rules, rules.gates.size() - 1, -1.0)
		cross(rules, rules.gates.size() - 1)
	check(rules.lap == 1 and rules.lap_times.is_empty(), "finish-line oscillation cannot earn lap")
	rules = fresh()
	var gate := rules.gates[0]
	var to: Vector3 = gate.position + gate.tangent
	var near := track.nearest(to)
	rules.observe(track.start_transform().origin, to, near.distance, near.lateral)
	check(rules.next_gate == 0, "teleport across checkpoint cannot advance")
	rules = fresh()
	for i in rules.gates.size():
		cross(rules, i)
	check(rules.lap == 1, "visiting gates without traversing road cannot earn lap")
	rules = fresh()
	traverse(rules, 3.0, track.length + 3.0, 11.0)
	check(rules.lap == 1 and rules.next_gate == 0, "off-road parallel shortcut earns no gates or lap")
	rules = fresh()
	traverse(rules, 3.0, track.length * 0.25 + 1.0)
	var before_gate := rules.next_gate
	var before_lap := rules.lap
	var before_time := rules.total_time
	rules.reset_observation(rules.last_safe_distance + 3.0)
	check(rules.next_gate == before_gate and rules.lap == before_lap and rules.total_time == before_time, "reset observation preserves checkpoint order and clock")
	rules.restart()
	check(rules.lap == 1 and rules.next_gate == 0 and rules.total_time == 0.0 and rules.distance_valid == 0.0, "restart clears race state")
	for i in 3:
		traverse(rules, track.length * i + 3.0, track.length * (i + 1) + 3.0)
		check(rules.lap_times.size() == i + 1, "ordered centerline lap %d accepted" % (i + 1))
	check(rules.finished and rules.lap == 3, "three laps finish exactly once")
	var finish_time := rules.total_time
	rules.tick(5.0)
	cross(rules, 0)
	check(rules.total_time == finish_time and rules.lap_times.size() == 3, "finished race clock and lap count stay frozen")
	track.free()
	await _test_pause_and_restart()
	print("RULE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_pause_and_restart() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.start_race()
	game._physics_process(3.1)
	check(game.state == "racing" and game.car.driving_enabled, "countdown unlocks driving")
	game.car.external_input = true
	game.car.throttle = 1.0
	for i in 15:
		await physics_frame
	game.car.nitro_pressed = true
	for i in 10:
		await physics_frame
	var bottle: float = game.car.nitro
	var turbo: float = game.car.mini_turbo_time
	var charge: float = game.car.drift_charge
	var before: float = game.rules.total_time
	var position: Vector3 = game.car.global_position
	var velocity: Vector3 = game.car.velocity
	var pause := InputEventAction.new()
	pause.action = "pause_race"
	pause.pressed = true
	game._unhandled_input(pause)
	for i in 5:
		await process_frame
	check(game.state == "paused" and paused, "Escape pauses race tree")
	check(game.rules.total_time == before and game.car.global_position.is_equal_approx(position), "pause freezes clock and car")
	check(game.car.nitro == bottle and game.car.mini_turbo_time == turbo and game.car.drift_charge == charge, "pause freezes boost resource and drift timers")
	game.resume_race()
	check(game.state == "racing" and not paused and game.car.velocity.is_equal_approx(velocity), "resume preserves state and momentum")
	game.reset_car()
	check(game.car.velocity.is_zero_approx() and game.rules.total_time == before, "recovery zeroes velocity without resetting timer")
	check(game.car.nitro == bottle and not game.car.boost_active and game.car.drift_charge == 0.0, "checkpoint reset clears transient boost but does not refill nitro")
	game.start_race()
	check(game.car.nitro == 1.0 and game.car.mini_turbo_time == 0.0 and not game.car.drift_active, "new race refills nitro and clears drift/mini turbo")
	check(game.state == "countdown" and game.rules.total_time == 0.0 and game.rules.lap == 1, "restart resets timing and returns countdown")
	game.car.engine.stop()
	game.car.engine.stream = null
	await create_timer(0.1).timeout
	game.queue_free()
	await process_frame
