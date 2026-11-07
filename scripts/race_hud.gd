class_name RaceHUD
extends Control
var game: Node
var font: Font
var primary: Button
var secondary: Button
var boost_phase: float = 0.0
const INK := Color("182c35")
const CREAM := Color("fff3d7")
const ACCENT := Color("ffb34b")
const NITRO := Color("70dcff")

const DefaultText: Translation = preload("res://games/minigame/godot_party_default_car_racing/i18n/zh_Hans.po")
var i18n: RefCounted

func hud_text(key: StringName, values: Dictionary) -> String:
	return DefaultText.get_message(key).format(values) if i18n == null else i18n.text(key, values)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://games/minigame/godot_party_default_car_racing/assets/fonts/RidgelineInterface.otf")
	primary = $Primary
	secondary = $Secondary
	primary.pressed.connect(func(): game.menu_primary())
	secondary.pressed.connect(func(): game.menu_secondary())

func _process(delta: float) -> void:
	if not game:
		return
	if game.state == "racing":
		boost_phase = fposmod(boost_phase + delta * 1.8, 1.0)
	var menu: bool = game.state in ["menu", "paused", "finished"]
	primary.visible = menu
	secondary.visible = menu and game.state != "menu"
	primary.text = "开始驾驶  →" if game.state == "menu" else ("继续比赛  →" if game.state == "paused" else "再跑一次  →")
	secondary.text = "重新开始" if game.state == "paused" else "返回主界面"
	%Driving.visible = not menu
	%Menu.visible = menu
	if menu:
		%Best.visible = game.best_time > 0
		%Best.text = hud_text(&"hud.best", {"time":game.format_time(game.best_time)})
		%Guide.visible = game.state == "menu"
		if game.controls.context != null:
			%Guide.text = hud_text(&"hud.formal_controls", {})
		%SplitTimes.visible = game.state == "finished"
		%MenuStatus.text = "过发卡，绕灯塔，沿海桥冲向终点。" if game.state == "menu" else ("已暂停" if game.state == "paused" else hud_text(&"hud.finished", {"time": game.format_time(game.rules.total_time)}))
		if game.state == "finished":
			var laps: PackedStringArray = []
			for index: int in game.rules.lap_times.size():
				laps.append(hud_text(&"hud.split", {"lap":index + 1, "time":game.format_time(game.rules.lap_times[index])}))
			%SplitTimes.text = "   ".join(laps)
	else:
		%Lap.text = hud_text(&"hud.lap", {"lap":game.rules.lap})
		%TotalTime.text = hud_text(&"hud.total", {"time":game.format_time(game.rules.total_time)})
		%LapTime.text = hud_text(&"hud.current", {"time":game.format_time(game.rules.lap_time)})
		%Speed.text = "%03d" % roundi(absf(game.car.signed_speed) * 3.6)
		%NitroBar.value = game.car.nitro
		%Nitro.text = "NITRO" if game.car.nitro_active else ("MINI TURBO" if game.car.mini_turbo_time > 0 else ("NITRO  EMPTY" if game.car.nitro <= 0.01 else "SHIFT  NITRO"))
		%Countdown.visible = game.state == "countdown"
		%Countdown.text = str(ceili(game.countdown)) if game.countdown > 0 else "GO"
		%Toast.visible = game.state != "countdown" and game.toast_time > 0
		%Toast.text = game.toast
		%RoadHint.visible = game.wrong_way_time > 1.3 or not game.car.on_road
		%RoadHint.text = "逆向行驶" if game.wrong_way_time > 1.3 else "路肩减速"
	queue_redraw()

func _draw() -> void:
	if not game or game.state in ["menu", "finished", "paused"]:
		return
	if game.state == "racing" and game.car.boost_active:
		_draw_boost_streaks()
	_draw_map()

func _draw_boost_streaks() -> void:
	# Six quiet edge strokes leave the road and car completely unobscured.
	var center := size * Vector2(0.5, 0.48)
	for side in [-1.0, 1.0]:
		for i in 3:
			var phase := fposmod(boost_phase + float(i) * 0.31, 1.0)
			var edge := Vector2(size.x * (0.5 + side * 0.60), size.y * (0.29 + float(i) * 0.20))
			var start := center.lerp(edge, 0.76 + phase * 0.13)
			var end := center.lerp(edge, 0.85 + phase * 0.13)
			var tint := Color(NITRO if game.car.nitro_active else CREAM, 0.11 * sin(phase * PI))
			draw_line(start, end, tint, 1.5, true)

func _draw_map() -> void:
	if game.track.points.is_empty():
		return
	var bounds: Rect2 = game.track.map_bounds
	var map_scale: float = minf(148.0 / bounds.size.x, 152.0 / bounds.size.y)
	var origin := Vector2(102, size.y - 104) - bounds.get_center() * map_scale
	var path := PackedVector2Array()
	for point in game.track.points:
		path.append(origin + Vector2(point.x, point.z) * map_scale)
	path.append(path[0])
	draw_polyline(path, Color(0.07, 0.17, 0.20, 0.72), 6.0, true)
	draw_polyline(path, Color(0.85, 0.92, 0.85, 0.70), 2.0, true)
	var cp: Vector3 = game.car.global_position
	var car_point := origin + Vector2(cp.x, cp.z) * map_scale
	draw_circle(car_point, 4.5, ACCENT)
	draw_circle(path[0], 3, CREAM)
