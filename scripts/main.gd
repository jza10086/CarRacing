extends Node3D
const CarScript = preload("res://scripts/arcade_car.gd")
const TrackScript = preload("res://scripts/track_world.gd")
const RulesScript = preload("res://scripts/race_rules.gd")
const HUDScript = preload("res://scripts/race_hud.gd")
var track: TrackWorld
var car: ArcadeCar
var rules: RaceRules
var camera: Camera3D
var hud: RaceHUD
var state: String = "menu"
var countdown: float = 3.0
var toast: String = ""
var toast_time: float = 0.0
var wrong_way_time: float = 0.0
var best_time: float = 0.0
var camera_target: Vector3
var test_mode: bool = false
var camera_snap: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_inputs()
	_setup_light()
	track = TrackScript.new()
	track.name = "SunridgeCircuit"
	track.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(track)
	car = CarScript.new()
	car.name = "PlayerCar"
	car.track = track
	car.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(car)
	car.reset_to(track.start_transform())
	rules = RulesScript.new()
	rules.configure(track)
	rules.lap_completed.connect(_lap_completed)
	rules.race_completed.connect(_race_completed)
	camera = Camera3D.new()
	camera.fov = 68.0
	camera.far = 1200.0
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = HUDScript.new()
	hud.game = self
	layer.add_child(hud)
	var saved := ConfigFile.new()
	if saved.load("user://records.cfg") == OK:
		best_time = float(saved.get_value("sunridge", "best_3_laps", 0.0))
	_update_camera(1.0)

func _setup_inputs() -> void:
	var bindings := {"accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN], "steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT], "handbrake": [KEY_SPACE], "nitro": [KEY_SHIFT], "reset_car": [KEY_R], "pause_race": [KEY_ESCAPE], "start_race": [KEY_ENTER]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)

func _setup_light() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	world.environment = environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("63b5d3")
	sky_mat.sky_horizon_color = Color("c8e6db")
	sky_mat.ground_bottom_color = Color("82b692")
	sky_mat.ground_horizon_color = Color("d3e5cb")
	sky_mat.sky_curve = 0.2
	sky.sky_material = sky_mat
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d4e5ef")
	environment.ambient_light_energy = 0.4
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_color = Color("fff1cc")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 110.0
	sun.shadow_bias = 0.07
	add_child(sun)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_race"):
		if state == "racing" or state == "countdown":
			set_meta("pause_return", state)
			state = "paused"
			get_tree().paused = true
		elif state == "paused":
			resume_race()
	elif event.is_action_pressed("reset_car") and state == "racing":
		reset_car()
	elif event.is_action_pressed("start_race") and state in ["menu", "finished"]:
		start_race()

func menu_primary() -> void:
	if state == "paused":
		resume_race()
	else:
		start_race()

func menu_secondary() -> void:
	if state == "paused":
		start_race()
	else:
		get_tree().paused = false
		state = "menu"
		car.driving_enabled = false
		car.reset_to(track.start_transform())
		camera_snap = true

func resume_race() -> void:
	state = str(get_meta("pause_return", "racing"))
	get_tree().paused = false

func start_race() -> void:
	get_tree().paused = false
	rules.restart()
	car.reset_for_race()
	car.reset_to(track.start_transform())
	car.driving_enabled = false
	countdown = 3.0
	state = "countdown"
	toast_time = 0.0
	wrong_way_time = 0.0
	camera_snap = true

func _physics_process(delta: float) -> void:
	if not car or state == "paused":
		return
	if state == "countdown":
		countdown -= delta
		if countdown <= 0.0:
			state = "racing"
			car.driving_enabled = true
			toast = "GO!"
			toast_time = 1.0
	elif state == "racing":
		rules.tick(delta)
		var nearest := track.nearest(car.global_position)
		rules.observe(car.previous_position, car.global_position, float(nearest.distance), float(nearest.lateral))
		if car.velocity.dot(nearest.tangent) < -3.0:
			wrong_way_time += delta
		else:
			wrong_way_time = maxf(0.0, wrong_way_time - delta * 3.0)
		if car.global_position.y < -10 or car.global_position.length() > 420:
			reset_car()
	toast_time = maxf(0.0, toast_time - delta)

func _process(delta: float) -> void:
	if car and state != "paused":
		_update_camera(delta)

func _update_camera(delta: float) -> void:
	var forward := -car.global_basis.z
	var speed_ratio := clampf(absf(car.signed_speed) / ArcadeCar.MAX_SPEED, 0.0, 1.0)
	var focus := car.global_position + Vector3.UP * 1.4 + forward * lerpf(3.0, 5.4, speed_ratio)
	var desired := car.global_position - forward * lerpf(7.2, 8.7, speed_ratio) + Vector3.UP * lerpf(3.8, 4.6, speed_ratio)
	if state == "menu":
		desired = car.global_position - forward * 7.5 + car.global_basis.x * 6.5 + Vector3.UP * 3.5
		focus = car.global_position + forward * 3.8 + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(car.global_position + Vector3.UP * 1.7, desired, 1, [car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.4
	if camera_snap:
		camera.global_position = desired
		camera_target = focus
		camera_snap = false
	else:
		camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-7.5 * delta))
		camera_target = camera_target.lerp(focus, 1.0 - exp(-9.0 * delta))
	camera.look_at(camera_target, Vector3.UP)
	camera.fov = lerpf(camera.fov, lerpf(68.0, 76.0, speed_ratio) + (4.0 if car.boost_active else 0.0), 1.0 - exp(-3.0 * delta))

func reset_car() -> void:
	var safe := rules.last_safe_distance + 3.0
	var sample := track.sample_distance(safe)
	var pose := Transform3D(Basis.looking_at(sample.tangent, Vector3.UP), sample.position + Vector3.UP * 0.03)
	car.reset_to(pose)
	rules.reset_observation(fposmod(safe, track.length))
	camera_snap = true
	toast = "已返回检查点"
	toast_time = 1.5
	wrong_way_time = 0.0

func _lap_completed(value: float) -> void:
	toast = "第 %d 圈  ·  %s" % [rules.lap, format_time(value)]
	toast_time = 2.6

func _race_completed() -> void:
	state = "finished"
	car.driving_enabled = false
	car.clear_boost_and_drift()
	if not test_mode and (best_time <= 0 or rules.total_time < best_time):
		best_time = rules.total_time
		var record := ConfigFile.new()
		record.set_value("sunridge", "best_3_laps", best_time)
		record.save("user://records.cfg")

func format_time(value: float) -> String:
	var ms := int(value * 1000)
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]
