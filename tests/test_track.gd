extends SceneTree
## Designed-circuit regression suite. Fixture positioning is explicit; the separate
## drive_laps.gd proves uninterrupted laps using only normal player Input actions.
var failures: int = 0
var checks: int = 0
var game: Node
var track: TrackWorld

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

func flat(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z)

func cross_2d(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

func segments_cross(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := cross_2d(ab, cd)
	if absf(denominator) < 0.000001:
		return false
	var t := cross_2d(c - a, cd) / denominator
	var u := cross_2d(c - a, ab) / denominator
	return t > 0.00001 and t < 0.99999 and u > 0.00001 and u < 0.99999

func segment_distance(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if segments_cross(a, b, c, d):
		return 0.0
	return minf(minf(a.distance_to(Geometry2D.get_closest_point_to_segment(a, c, d)), b.distance_to(Geometry2D.get_closest_point_to_segment(b, c, d))), minf(c.distance_to(Geometry2D.get_closest_point_to_segment(c, a, b)), d.distance_to(Geometry2D.get_closest_point_to_segment(d, a, b))))

func _run() -> void:
	Engine.physics_ticks_per_second = 60
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await steps(2)
	game.test_mode = true
	track = game.track
	check(track.length > 1000.0 and track.length < 2200.0, "designed circuit has a purposeful full-lap scale: %.2f m" % track.length)
	check(track.points.size() == track.distances.size() and track.points.size() == track.half_widths.size(), "positions, arc distances and per-sample widths stay aligned")
	if track.points.size() != track.half_widths.size():
		quit(1)
		return
	_test_geometry()
	_test_gates()
	_test_road_collision()
	await _test_resets()
	await _test_rails()
	game.car.engine.stop()
	game.car.engine.stream = null
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	await process_frame
	print("TRACK TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _test_geometry() -> void:
	var width_ok := true
	var spacing_ok := true
	var level_ok := true
	var strip_ok := true
	var intersections := 0
	var corridor_collisions := 0
	var min_clearance := INF
	var max_width_slope := 0.0
	var count := track.points.size()
	for i in count:
		var j := (i + 1) % count
		var distance := track.points[i].distance_to(track.points[j])
		width_ok = width_ok and track.half_widths[i] >= 5.0 and track.half_widths[i] <= 8.0
		spacing_ok = spacing_ok and distance > 0.05 and distance < 8.0
		level_ok = level_ok and absf(track.points[i].y - TrackWorld.TRACK_HEIGHT) < 0.0001
		max_width_slope = maxf(max_width_slope, absf(track.half_widths[i] - track.half_widths[j]) / distance)
		var left_i := flat(track.points[i] - track._right(i) * track.half_widths[i])
		var left_j := flat(track.points[j] - track._right(j) * track.half_widths[j])
		var right_i := flat(track.points[i] + track._right(i) * track.half_widths[i])
		var right_j := flat(track.points[j] + track._right(j) * track.half_widths[j])
		# The two road triangles must retain a matching non-zero orientation.
		var area_a := cross_2d(left_j - left_i, right_j - left_i)
		var area_b := cross_2d(right_j - left_i, right_i - left_i)
		strip_ok = strip_ok and area_a * area_b > 0.000001
		for k in range(i + 2, count):
			var l := (k + 1) % count
			if l == i:
				continue
			if segments_cross(flat(track.points[i]), flat(track.points[j]), flat(track.points[k]), flat(track.points[l])):
				intersections += 1
			# Adjacent bends naturally have close samples. Compare genuinely separate
			# stretches, not the same continuous corridor around a local corner.
			var arc := absf(track.distances[k] - track.distances[i])
			arc = minf(arc, track.length - arc)
			var envelope := maxf(track.half_widths[i], track.half_widths[j]) + maxf(track.half_widths[k], track.half_widths[l]) + 3.6
			if arc < maxf(45.0, envelope * 2.0):
				continue
			var clearance := segment_distance(flat(track.points[i]), flat(track.points[j]), flat(track.points[k]), flat(track.points[l])) - envelope
			min_clearance = minf(min_clearance, clearance)
			if clearance < -0.05:
				corridor_collisions += 1
	check(width_ok, "road half-width remains 5–8 m across all sectors")
	check(max_width_slope < 0.12, "width changes taper smoothly, maximum %.4f m per metre" % max_width_slope)
	check(spacing_ok, "road samples have no zero-length segment or large collision gap")
	check(level_ok, "road and bridge remain level at the tested controller height")
	check(strip_ok, "variable-width road triangles do not fold or reverse winding")
	check(intersections == 0, "closed centerline has no non-adjacent self-intersections")
	check(corridor_collisions == 0, "separate road/rail envelopes do not overlap; minimum clearance %.2f m" % min_clearance)
	var max_error := 0.0
	var width_error := 0.0
	for i in 1000:
		var at := track.length * float(i) / 1000.0
		var sample := track.sample_distance(at)
		var nearest := track.nearest(sample.position)
		max_error = maxf(max_error, (sample.position as Vector3).distance_to(nearest.position))
		width_error = maxf(width_error, absf(float(sample.half_width) - float(nearest.half_width)))
	check(max_error < 0.0001 and width_error < 0.001, "1,000 sample/nearest roundtrips preserve position and local width")
	check(track.sample_distance(track.length).position.distance_to(track.sample_distance(0).position) < 0.001, "finish seam wraps continuously")

func _test_gates() -> void:
	var samples := track.checkpoint_samples()
	var ordered := true
	var aligned := true
	var local_width := true
	var previous := 0.0
	for at in samples:
		ordered = ordered and at > previous + 10.0 and at < track.length - 10.0
		previous = at
		var sample := track.sample_distance(at)
		var forward: Vector3 = track.sample_distance(at + 1.0).position - track.sample_distance(at - 1.0).position
		aligned = aligned and forward.normalized().dot(sample.tangent) > 0.99
		local_width = local_width and float(sample.half_width) >= 5.0 and absf(float(track.nearest(sample.position).lateral)) < 0.001
	check(samples.size() >= 11 and ordered, "%d feature checkpoints are strictly ordered and separated, plus one distinct finish gate" % samples.size())
	check(aligned and local_width, "every feature gate faces route travel and lies on its full-width road")
	var gate_widths_ok := true
	for i in game.rules.gates.size() - 1:
		var gate: Dictionary = game.rules.gates[i]
		var rules := RaceRules.new()
		rules.configure(track)
		rules.next_gate = i
		var tangent: Vector3 = gate.tangent
		var right := tangent.cross(Vector3.UP)
		var width: float = gate.half_width
		# A pass near the actual wide road edge must count; a wider off-road pass must not.
		var from: Vector3 = gate.position - tangent + right * (width - 0.25)
		var to: Vector3 = gate.position + tangent + right * (width - 0.25)
		var near := track.nearest(to)
		rules.observe(from, to, near.distance, near.lateral)
		gate_widths_ok = gate_widths_ok and rules.next_gate == i + 1
		rules = RaceRules.new()
		rules.configure(track)
		rules.next_gate = i
		from = gate.position - tangent + right * (width + 2.5)
		to = gate.position + tangent + right * (width + 2.5)
		near = track.nearest(to)
		rules.observe(from, to, near.distance, near.lateral)
		gate_widths_ok = gate_widths_ok and rules.next_gate == i
	check(gate_widths_ok, "checkpoint acceptance follows local road width, rejecting off-corridor crossings")

func _test_road_collision() -> void:
	var support_ok := true
	var max_height_error := 0.0
	var count := 0
	for i in 180:
		var sample := track.sample_distance(track.length * float(i) / 180.0)
		var right: Vector3 = sample.tangent.cross(Vector3.UP)
		for side: float in [-1.0, 0.0, 1.0]:
			var at: Vector3 = sample.position + right * side * (float(sample.half_width) - 0.65)
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.8, at - Vector3.UP * 0.4, 1)
			var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
			count += 1
			if hit.is_empty():
				support_ok = false
			else:
				max_height_error = maxf(max_height_error, absf(float(hit.position.y) - at.y))
				support_ok = support_ok and (hit.normal as Vector3).dot(Vector3.UP) > 0.999
	check(support_ok and max_height_error < 0.015, "%d center/edge raycasts find continuous upward road collision, height error %.5f m" % [count, max_height_error])

func _test_resets() -> void:
	var reset_ok := true
	var start_ok := true
	var car: ArcadeCar = game.car
	car.external_input = true
	car.driving_enabled = true
	car.throttle = 0.0
	car.steering = 0.0
	car.handbrake = false
	car.nitro_pressed = false
	game.rules.total_time = 17.0
	for i in game.rules.gates.size():
		var gate: Dictionary = game.rules.gates[i]
		game.rules.last_safe_distance = gate.distance
		game.rules.next_gate = (i + 1) % game.rules.gates.size()
		var next_gate: int = game.rules.next_gate
		var safe := track.sample_distance(float(gate.distance) + 3.0)
		game.reset_car()
		reset_ok = reset_ok and car.velocity.is_zero_approx() and game.rules.next_gate == next_gate and game.rules.total_time == 17.0
		reset_ok = reset_ok and (-car.global_basis.z).dot(safe.tangent) > 0.999 and flat(car.global_position).distance_to(flat(safe.position)) < 0.001
		await steps(8)
		reset_ok = reset_ok and car.is_on_floor() and absf(car.global_position.y - safe.position.y) < 0.04
		car.throttle = 1.0
		await steps(30)
		var nearest := track.nearest(car.global_position)
		start_ok = start_ok and car.is_on_floor() and car.on_road and car.signed_speed > 5.0 and flat(car.global_position).distance_to(flat(safe.position)) > 1.0 and absf(float(nearest.lateral)) < float(nearest.half_width) - 1.0
		car.throttle = 0.0
	check(reset_ok, "all %d route gates reset onto stable floor with forward heading, unchanged order and clock" % game.rules.gates.size())
	check(start_ok, "all %d route gates can restart from rest with ordinary throttle, without a speed gate or forced jump" % game.rules.gates.size())

func _test_rails() -> void:
	var car: ArcadeCar = game.car
	var stopped := true
	var remained_inside := true
	var grounded := true
	var contacts := 0
	for part in 6:
		var sample := track.sample_distance(track.length * (float(part) + 0.37) / 6.0)
		var index: int = sample.index
		var next := (index + 1) % track.points.size()
		for side: float in [-1.0, 1.0]:
			var a: Vector3 = track.points[index] + track._right(index) * side * (track.half_widths[index] + 1.8)
			var b: Vector3 = track.points[next] + track._right(next) * side * (track.half_widths[next] + 1.8)
			var outward: Vector3 = (b - a).normalized().cross(Vector3.UP) * side
			# Alternate seams and segment middles to exercise overlap as well as faces.
			var target := a if part % 2 == 0 else (a + b) * 0.5
			var start := target - outward * 2.2 + Vector3.UP * 0.03
			car.throttle = 0.0
			car.steering = 0.0
			car.handbrake = false
			car.nitro_pressed = false
			car.reset_to(Transform3D(Basis.looking_at(outward, Vector3.UP), start))
			await steps(8)
			car.velocity = outward * ArcadeCar.BOOST_SPEED
			car.throttle = 1.0
			car.nitro_pressed = true
			var contact := false
			for tick in 5:
				await physics_frame
				for collision in car.get_slide_collision_count():
					contact = contact or absf(car.get_slide_collision(collision).get_normal().y) < 0.5
				remained_inside = remained_inside and (car.global_position - target).dot(outward) < -0.9
				grounded = grounded and car.global_position.y < TrackWorld.TRACK_HEIGHT + 0.15
			if contact:
				contacts += 1
			stopped = stopped and contact and absf(car.velocity.dot(outward)) < 2.0
	check(stopped and contacts == 12, "54 m/s impacts hit actual left/right rails at six route locations, including seams")
	check(remained_inside and grounded, "boosted rail impacts never tunnel through, launch, or escape the closed road corridor")
