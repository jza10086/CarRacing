extends SceneTree
## QA driver: normal Input actions only; never sets transform, velocity, lap or gates.
## Optional --capture-dir=/absolute/path saves genuine rendered frames on a native display.
var game: Node
var capture_dir: String = ""
var native: bool = false
var frame_index: int = 0
var next_frame_time: float = 7.0
var shot_a: bool = false
var shot_b: bool = false
var last_lap: int = 1
var max_lateral: float = 0.0
var lap_events: int = 0
var kart: bool = false
var drift_timer: float = 0.0
var drift_cooldown: float = 1.0
var drift_requested: bool = false
var boost_demo_time: float = 0.0
var drifts: int = 0
var turbos: int = 0
var nitro_ticks: int = 0
var max_tier: int = 0
var was_drifting: bool = false
var was_mini: bool = false
var capture_started: bool = false
var drift_shot: bool = false
var nitro_shot: bool = false

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--kart":
			kart = true
		if arg.begins_with("--capture-dir="):
			capture_dir = arg.trim_prefix("--capture-dir=")
	native = DisplayServer.get_name() != "headless" and not capture_dir.is_empty()
	if native:
		DirAccess.make_dir_recursive_absolute(capture_dir + "/frames")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.rules.lap_completed.connect(func(_time: float): lap_events += 1)
	if native:
		await create_timer(0.5).timeout
		await capture("title.png")
	game.start_race()
	var frames: int = 0
	while game.state != "finished" and frames < 18000:
		await physics_frame
		frames += 1
		if game.state != "racing":
			continue
		var nearest: Dictionary = game.track.nearest(game.car.global_position)
		var along: float = nearest.distance
		var speed: float = absf(game.car.signed_speed)
		max_lateral = maxf(max_lateral, absf(float(nearest.lateral)))
		var lookahead: float = 6.0 + speed * 0.55
		var aim: Dictionary = game.track.sample_distance(along + lookahead)
		var to_target: Vector3 = aim.position - game.car.global_position
		to_target.y = 0.0
		var forward: Vector3 = -game.car.global_basis.z
		var angle: float = forward.signed_angle_to(to_target.normalized(), Vector3.UP)
		var steer: float = clampf(angle * 2.8, -1.0, 1.0)
		var ahead: Dictionary = game.track.sample_distance(along + 38.0)
		var turn: float = absf((nearest.tangent as Vector3).signed_angle_to(ahead.tangent, Vector3.UP))
		var desired_speed: float = clampf(34.0 - turn * 19.0, 15.0, 32.0)
		var gas := clampf((desired_speed - speed) * 0.3, -1.0, 1.0)
		if kart:
			var dt := 1.0 / float(Engine.physics_ticks_per_second)
			drift_cooldown = maxf(0.0, drift_cooldown - dt)
			if game.car.drift_active:
				if not was_drifting:
					drifts += 1
					print("KART_DRIFT start along=", along, " direction=", game.car.drift_direction)
				drift_timer += dt
				max_tier = maxi(max_tier, game.car.drift_tier)
				gas = maxf(0.0, gas)
				# Feed the same target corner angle through the drift's countersteer range.
				var direction: float = game.car.drift_direction
				var target_turn: float = steer * direction
				steer = clampf((target_turn - 0.45) / 0.65, -1.0, 1.0) * direction
				if drift_timer > 1.68 or target_turn < 0.02 or absf(nearest.lateral) > 3.5:
					drift_requested = false
					drift_cooldown = 3.0
					if game.car.drift_tier > 0:
						boost_demo_time = 0.8
			elif not drift_requested and drift_cooldown <= 0.0 and speed > 14.0 and speed < 31.0 and absf(steer) > 0.22 and turn > 0.2 and absf(nearest.lateral) < 1.5:
				drift_requested = true
				drift_timer = 0.0
				gas = maxf(0.2, gas)
			elif was_drifting:
				drift_requested = false
				drift_cooldown = 3.0
			was_drifting = game.car.drift_active
			if drift_requested:
				Input.action_press("handbrake")
			else:
				Input.action_release("handbrake")
			if boost_demo_time > 0.0:
				boost_demo_time -= dt
				gas = 1.0
			if game.car.mini_turbo_time > 0.0 and not was_mini:
				turbos += 1
				print("KART_MINI_TURBO along=", along, " duration=", game.car.mini_turbo_time)
			was_mini = game.car.mini_turbo_time > 0.0
			if turbos > 0 and not game.car.drift_active and turn < 0.25 and speed > 20.0 and absf(nearest.lateral) < 1.5 and game.car.nitro > 0.2:
				Input.action_press("nitro")
				gas = 1.0
			else:
				Input.action_release("nitro")
			if game.car.nitro_active:
				nitro_ticks += 1
		_set_axis("steer_left", "steer_right", steer)
		_set_axis("accelerate", "brake", gas)
		if game.rules.lap != last_lap:
			last_lap = game.rules.lap
			print("DRIVEN_LAP ", last_lap - 1, " time=", game.rules.lap_times[-1], " gates=", game.rules.gates.size(), " max_lateral=", max_lateral)
		if frames % 600 == 0:
			print("DRIVE_PROGRESS sim=", game.rules.total_time, " along=", snappedf(along, 0.1), " speed=", snappedf(speed, 0.1), " gate=", game.rules.next_gate, " lateral=", snappedf(nearest.lateral, 0.1))
		if native:
			if not shot_a and along > 140.0 and along < 200.0:
				shot_a = true
				capture("gameplay.png")
			if not shot_b and along > 350.0 and along < 430.0:
				shot_b = true
				capture("corner.png")
			if kart and not capture_started and game.car.drift_active:
				capture_started = true
				next_frame_time = game.rules.total_time
			if kart and game.car.drift_tier == 2 and not drift_shot:
				drift_shot = true
				capture("drift.png")
			if kart and game.car.nitro_active and not nitro_shot:
				nitro_shot = true
				capture("nitro.png")
			if frame_index < 54 and (not kart or capture_started) and game.rules.total_time >= next_frame_time:
				capture("frames/frame_%03d.png" % frame_index)
				frame_index += 1
				next_frame_time += 0.14
	for action in ["accelerate", "brake", "steer_left", "steer_right", "handbrake", "nitro"]:
		Input.action_release(action)
	if kart:
		print("KART_RESULT drifts=", drifts, " turbos=", turbos, " max_tier=", max_tier, " nitro_ticks=", nitro_ticks)
	if game.state == "finished" and lap_events == 3 and (not kart or (drifts > 0 and turbos > 0 and max_tier == 2 and nitro_ticks > 0)):
		print("DRIVE_PASS three laps through normal input; total=", game.rules.total_time, " lap_times=", game.rules.lap_times, " max_lateral=", max_lateral, " physics_ticks=", frames)
		if native:
			await capture("finish.png")
		game.car.engine.stop()
		game.car.engine.stream = null
		OS.delay_msec(100) # Let the audio mixer release voices even in --fixed-fps fast runs.
		await create_timer(0.15).timeout
		game.queue_free()
		await process_frame
		await create_timer(0.1).timeout
		quit(0)
	else:
		push_error("DRIVE_FAIL state=%s lap=%d gate=%d position=%s" % [game.state, game.rules.lap, game.rules.next_gate, game.car.global_position])
		quit(1)

func _set_axis(positive: String, negative: String, value: float) -> void:
	Input.action_release(positive)
	Input.action_release(negative)
	if value > 0.02:
		Input.action_press(positive, value)
	elif value < -0.02:
		Input.action_press(negative, -value)

func capture(filename: String) -> void:
	# Mid-race callers do not await: viewport readback must not stall steering updates.
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(capture_dir.path_join(filename))
