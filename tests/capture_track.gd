extends SceneTree
## Native visual fixtures only. This does NOT claim driven laps; drive_laps.gd does.
## --capture-dir=/absolute/path saves real viewport images, not offline mockups.
var game: Node
var directory := ""

func _initialize() -> void:
	call_deferred("run")

func capture(filename: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(directory.path_join(filename))
	print("TRACK_CAPTURE ", filename)

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			directory = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or directory.is_empty():
		push_error("capture_track requires a native display and --capture-dir")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.set_process(false)
	game.set_physics_process(false)
	game.hud.hide()
	game.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.camera.size = 560.0
	game.camera.global_position = Vector3(-35, 650, 42)
	game.camera.look_at(Vector3(-35, 0, 42), Vector3.FORWARD)
	await capture("Lighthouse-overview.png")
	game.camera.global_position = Vector3(-70, 530, 410)
	game.camera.look_at(Vector3(-35, 0, 42), Vector3.UP)
	game.camera.size = 560.0
	await capture("Lighthouse-coast.png")
	game.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	game.hud.show()
	game.state = "racing"
	for fixture in [{"name":"Lighthouse-harbor.png", "distance":15.0}, {"name":"Lighthouse-hairpin.png", "distance":float(game.track.sectors[2].distance)+27.0}, {"name":"Lighthouse-chase.png", "distance":float(game.track.sectors[3].distance)+100.0}, {"name":"Lighthouse-bridge.png", "distance":float(game.track.sectors[4].distance)+60.0}]:
		var sample: Dictionary = game.track.sample_distance(float(fixture.distance))
		game.car.reset_to(Transform3D(Basis.looking_at(sample.tangent), sample.position + Vector3.UP * 0.03))
		game.camera_snap = true
		game._update_camera(1.0)
		await capture(fixture.name)
	# Leave the real start menu on the desktop for a human inspection.
	game.car.reset_to(game.track.start_transform())
	game.state = "menu"
	game.camera_snap = true
	game._update_camera(1.0)
	await capture("Lighthouse-title.png")
	if "--stay" in OS.get_cmdline_user_args():
		game.set_process(true)
		game.set_physics_process(true)
		return
	game.car.engine.stop()
	game.car.engine.stream = null
	OS.delay_msec(100)
	game.queue_free()
	await process_frame
	quit(0)
