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

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for arg in OS.get_cmdline_user_args():
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
		_set_axis("steer_left", "steer_right", steer)
		var ahead: Dictionary = game.track.sample_distance(along + 38.0)
		var turn: float = absf((nearest.tangent as Vector3).signed_angle_to(ahead.tangent, Vector3.UP))
		var desired_speed: float = clampf(34.0 - turn * 19.0, 15.0, 32.0)
		_set_axis("accelerate", "brake", clampf((desired_speed - speed) * 0.3, -1.0, 1.0))
		if game.rules.lap != last_lap:
			last_lap = game.rules.lap
			print("DRIVEN_LAP ", last_lap - 1, " time=", game.rules.lap_times[-1], " gates=", game.rules.gates.size(), " max_lateral=", max_lateral)
		if frames % 600 == 0:
			print("DRIVE_PROGRESS sim=", game.rules.total_time, " along=", snappedf(along, 0.1), " speed=", snappedf(speed, 0.1), " gate=", game.rules.next_gate, " lateral=", snappedf(nearest.lateral, 0.1))
		if native:
			if not shot_a and along > 140.0 and along < 200.0:
				shot_a = true
				await capture("gameplay.png")
			if not shot_b and along > 350.0 and along < 430.0:
				shot_b = true
				await capture("corner.png")
			if frame_index < 54 and game.rules.total_time >= next_frame_time:
				await capture("frames/frame_%03d.png" % frame_index)
				frame_index += 1
				next_frame_time += 0.14
	for action in ["accelerate", "brake", "steer_left", "steer_right"]:
		Input.action_release(action)
	if game.state == "finished" and lap_events == 3:
		print("DRIVE_PASS three laps through normal input; total=", game.rules.total_time, " lap_times=", game.rules.lap_times, " max_lateral=", max_lateral, " physics_ticks=", frames)
		if native:
			await capture("finish.png")
		game.car.engine.stop()
		game.car.engine.stream = null
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
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	picture.save_png(capture_dir.path_join(filename))
