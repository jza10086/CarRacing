extends Node3D
const Controls = preload("res://games/protocols/godot_party_default_protocol/solo_controls.gd")
const Settings = preload("res://games/minigame/godot_party_default_car_racing/settings.gd")
var controls: Controls = Controls.new(Settings.schema())
var _active: bool = false
var _stopped: bool = false
var _text_source: RefCounted

signal completed(metrics: Dictionary)
var personal_best: int = 0
const CarScript = preload("res://games/minigame/godot_party_default_car_racing/scripts/arcade_car.gd")
const TrackScript = preload("res://games/minigame/godot_party_default_car_racing/scripts/track_world.gd")
const RulesScript = preload("res://games/minigame/godot_party_default_car_racing/scripts/race_rules.gd")
const HUDScript = preload("res://games/minigame/godot_party_default_car_racing/scripts/race_hud.gd")
var track: TrackScript
var car: CarScript
var rules: RulesScript
var camera: Camera3D
var hud: HUDScript
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
	process_mode = Node.PROCESS_MODE_INHERIT
	track = $LighthouseCircuit
	car = $PlayerCar
	car.track = track
	car.reset_to(track.start_transform())
	rules = RulesScript.new()
	rules.configure(track)
	rules.lap_completed.connect(_lap_completed)
	rules.race_completed.connect(_race_completed)
	camera = $Camera
	hud = $GameHUD/RaceHUD
	hud.game = self
	hud.i18n = _text_source
	best_time = float(personal_best) / 1000.0
	_update_camera(1.0)
	car.controls = controls
	car.set_physics_process(false)
	$GameHUD.hide()
	if controls.context == null:
		solo_start()

func _unhandled_input(event: InputEvent) -> void:
	if not controls.allowed():
		return
	if controls.context == null and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if state == "racing" or state == "countdown":
			set_meta("pause_return", state)
			state = "paused"
			car.process_mode = Node.PROCESS_MODE_DISABLED
		elif state == "paused":
			resume_race()
	elif controls.matches(event, &"car_racing_reset_car") and state == "racing":
		reset_car()
	elif controls.matches(event, &"car_racing_start_race") and state in ["menu", "finished"]:
		start_race()

func menu_primary() -> void:
	if not controls.allowed():
		return
	if state == "paused":
		resume_race()
	else:
		start_race()

func menu_secondary() -> void:
	if not controls.allowed():
		return
	if state == "paused":
		start_race()
	else:
		car.process_mode = Node.PROCESS_MODE_INHERIT
		state = "menu"
		car.driving_enabled = false
		car.reset_to(track.start_transform())
		camera_snap = true

func resume_race() -> void:
	state = str(get_meta("pause_return", "racing"))
	car.process_mode = Node.PROCESS_MODE_INHERIT

func start_race() -> void:
	car.process_mode = Node.PROCESS_MODE_INHERIT
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
	if not _active or state == "paused":
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
		rules.observe(car.previous_position, car.global_position, float(nearest.distance), float(nearest.lateral), float(nearest.half_width))
		if car.velocity.dot(nearest.tangent) < -3.0:
			wrong_way_time += delta
		else:
			wrong_way_time = maxf(0.0, wrong_way_time - delta * 3.0)
		if car.global_position.y < -10 or car.global_position.length() > 650:
			reset_car()
	toast_time = maxf(0.0, toast_time - delta)

func _process(delta: float) -> void:
	if _active and state != "paused":
		_update_camera(delta)

func _update_camera(delta: float) -> void:
	var forward := -car.global_basis.z
	var speed_ratio := clampf(absf(car.signed_speed) / CarScript.MAX_SPEED, 0.0, 1.0)
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

	completed.emit({"time": roundi(rules.total_time * 1000.0)})

func format_time(value: float) -> String:
	var ms := int(value * 1000)
	return "%d:%02d.%03d" % [ms / 60000, (ms / 1000) % 60, ms % 1000]


## Injected before entering the tree. F6 leaves the formal dependencies unset.
func solo_setup(input: PartyInput, text_source: RefCounted) -> void:
	controls.bind(input)
	_text_source = text_source
	$GameAudio.prepare_scope()

func solo_start() -> void:
	if _stopped:
		return
	_active = true
	controls.enabled = true
	$GameHUD.show()
	car.set_physics_process(true)
	$GameAudio.route_player(car.engine)
	car.engine.play()
	start_race()

func solo_stop() -> void:
	if _stopped:
		return
	_stopped = true
	_active = false
	controls.enabled = false
	set_process(false)
	set_physics_process(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	if not is_node_ready():
		return
	car.driving_enabled = false
	car.clear_boost_and_drift()
	car.set_physics_process(false)
	$GameHUD.hide()
	$GameAudio.close_scope()

func solo_graphics_targets() -> Dictionary:
	return {"world": $WorldEnvironment1, "sun": $DirectionalLight3D2}

func solo_audio_target() -> PartyGameAudio:
	return $GameAudio
