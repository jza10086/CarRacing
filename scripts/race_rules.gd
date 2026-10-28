class_name RaceRules
extends RefCounted
## Ordered directional gates; no lap credit from teleports, reverse or shortcuts.
signal lap_completed(lap_time: float)
signal race_completed
const LAPS: int = 3
var lap: int = 1
var next_gate: int = 0
var total_time: float = 0.0
var lap_time: float = 0.0
var lap_times: Array[float] = []
var distance_valid: float = 0.0
var finished: bool = false
var last_safe_distance: float = 0.0
var gates: Array[Dictionary] = []
var track_length: float = 1.0
var previous_along: float = 3.0

func configure(track: TrackWorld) -> void:
	track_length = track.length
	gates.clear()
	for at in track.checkpoint_samples():
		gates.append(track.sample_distance(at))
	gates.append(track.sample_distance(0.0))
	restart()

func restart() -> void:
	lap = 1
	next_gate = 0
	total_time = 0.0
	lap_time = 0.0
	lap_times.clear()
	distance_valid = 0.0
	finished = false
	last_safe_distance = 0.0
	previous_along = 3.0

func tick(delta: float) -> void:
	if not finished:
		total_time += delta
		lap_time += delta

func observe(from: Vector3, to: Vector3, along: float, lateral: float, road_half_width: float = 6.0) -> void:
	if finished or gates.is_empty():
		return
	var step := to.distance_to(from)
	var advance := fposmod(along - previous_along + track_length * 0.5, track_length) - track_length * 0.5
	previous_along = along
	# Excludes resets/teleports and requires the large majority of a lap on the road.
	if step > 8.0:
		return
	if absf(lateral) <= road_half_width + 0.8 and advance > 0.0 and advance < 8.0:
		distance_valid += advance
	var gate := gates[next_gate]
	var tangent: Vector3 = gate.tangent
	var origin: Vector3 = gate.position
	var before := (from - origin).dot(tangent)
	var after := (to - origin).dot(tangent)
	if before > 0.0 or after <= 0.0 or after <= before:
		return
	var crossing := from.lerp(to, -before / (after - before))
	var right := tangent.cross(Vector3.UP).normalized()
	if absf((crossing - origin).dot(right)) > float(gate.get("half_width", 6.0)) + 0.8 or absf(crossing.y - origin.y) > 3.0:
		return
	if next_gate < gates.size() - 1:
		last_safe_distance = float(gate.get("distance", float(next_gate + 1) * track_length / float(gates.size())))
		next_gate += 1
	else:
		if distance_valid < track_length * 0.88:
			return
		lap_times.append(lap_time)
		lap_completed.emit(lap_time)
		next_gate = 0
		last_safe_distance = 0.0
		distance_valid = 0.0
		lap_time = 0.0
		if lap >= LAPS:
			finished = true
			race_completed.emit()
		else:
			lap += 1

func reset_observation(along: float) -> void:
	previous_along = along
