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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/fonts/RidgelineInterface.otf")
	primary = _button(true)
	secondary = _button(false)
	primary.pressed.connect(func(): game.menu_primary())
	secondary.pressed.connect(func(): game.menu_secondary())

func _button(filled: bool) -> Button:
	var button := Button.new()
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_font_override("font", font)
	var normal := StyleBoxFlat.new()
	normal.bg_color = ACCENT if filled else Color(0.06, 0.13, 0.17, 0.78)
	normal.set_corner_radius_all(5)
	normal.content_margin_left = 20
	normal.content_margin_right = 20
	var hover := normal.duplicate()
	hover.bg_color = Color("ffd386") if filled else Color("364f59")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_color_override("font_color", INK if filled else CREAM)
	button.add_theme_color_override("font_hover_color", INK if filled else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", INK if filled else Color.WHITE)
	add_child(button)
	return button

func _process(delta: float) -> void:
	if not game:
		return
	if game.state == "racing":
		boost_phase = fposmod(boost_phase + delta * 1.8, 1.0)
	var menu: bool = game.state in ["menu", "paused", "finished"]
	primary.visible = menu
	secondary.visible = menu and game.state != "menu"
	primary.position = Vector2(64, size.y * 0.63)
	primary.size = Vector2(290, 52)
	secondary.position = primary.position + Vector2(0, 65)
	secondary.size = Vector2(290, 44)
	primary.text = "开始驾驶  →" if game.state == "menu" else ("继续比赛  →" if game.state == "paused" else "再跑一次  →")
	secondary.text = "重新开始" if game.state == "paused" else "返回主界面"
	queue_redraw()

func _text(value: String, at: Vector2, size_px: int, color: Color = CREAM) -> void:
	draw_string(font, at + Vector2(1, 2), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0.03, 0.08, 0.10, 0.45))
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _right(value: String, at: Vector2, size_px: int, color: Color = CREAM) -> void:
	_text(value, Vector2(at.x - font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x, at.y), size_px, color)

func _draw() -> void:
	if not game or not font:
		return
	var menu: bool = game.state in ["menu", "paused", "finished"]
	if menu:
		# A quiet left column leaves the actual 3D car and circuit in view.
		for x in range(0, int(size.x * 0.6), 4):
			var fade := 1.0 - smoothstep(size.x * 0.23, size.x * 0.6, float(x))
			draw_rect(Rect2(x, 0, 4, size.y), Color(0.035, 0.085, 0.11, 0.88 * fade))
		_text("RIDGELINE  /  TIME ATTACK", Vector2(64, size.y * 0.25), 14, ACCENT)
		_text("山脊竞速", Vector2(60, size.y * 0.25 + 66), 54)
		_text("晴岭赛道  /  三圈计时挑战", Vector2(64, size.y * 0.25 + 103), 16, Color("b8c9c6"))
		if game.state == "menu":
			_text("找到你的路线，刷新自己的纪录。", Vector2(64, size.y * 0.25 + 150), 20)
		elif game.state == "paused":
			_text("已暂停", Vector2(64, size.y * 0.25 + 153), 30, ACCENT)
		else:
			_text("完赛  " + game.format_time(game.rules.total_time), Vector2(64, size.y * 0.25 + 149), 28, ACCENT)
			var values: String = ""
			for i in game.rules.lap_times.size():
				values += "%d  %s   " % [i + 1, game.format_time(game.rules.lap_times[i])]
			_text(values, Vector2(64, size.y * 0.25 + 182), 15)
		if game.state == "menu":
			_text("W / ↑  加速       S / ↓  刹车 / 倒车", Vector2(64, size.y - 123), 14, Color("bdcdcb"))
			_text("A D / ← →  转向", Vector2(64, size.y - 97), 14, Color("bdcdcb"))
			_text("SPACE  DRIFT → TURBO     SHIFT  NITRO", Vector2(64, size.y - 71), 14, NITRO)
			_text("R  返回检查点       Esc  暂停", Vector2(64, size.y - 45), 14, Color("bdcdcb"))
		if game.best_time > 0:
			_right("个人最佳  " + game.format_time(game.best_time), Vector2(size.x - 36, 43), 15)
		return
	# One top strip of information, no large dashboard covering the world.
	if game.state == "racing" and game.car.boost_active:
		_draw_boost_streaks()
	_text("山脊竞速", Vector2(30, 35), 21)
	_text("晴岭赛道", Vector2(31, 58), 11, Color("cee4db"))
	_text("圈数", Vector2(size.x * 0.45, 29), 11, Color("cee4db"))
	_text("%d / 3" % game.rules.lap, Vector2(size.x * 0.45, 59), 26)
	_right("总计  " + game.format_time(game.rules.total_time), Vector2(size.x - 30, 36), 22)
	_right("本圈  " + game.format_time(game.rules.lap_time), Vector2(size.x - 31, 60), 13, Color("cee4db"))
	var speed: int = int(round(absf(game.car.signed_speed) * 3.6))
	draw_rect(Rect2(size.x - 182, size.y - 141, 3, 72), NITRO if game.car.nitro_active else ACCENT)
	_right("%03d" % speed, Vector2(size.x - 30, size.y - 83), 48)
	_right("KM/H", Vector2(size.x - 31, size.y - 60), 12, Color("cee4db"))
	_draw_nitro()
	_draw_map()
	if game.state == "countdown":
		var count: String = str(int(ceil(game.countdown))) if game.countdown > 0 else "GO"
		var width := font.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 98).x
		_text(count, Vector2((size.x - width) * 0.5, size.y * 0.43), 98, ACCENT)
	elif game.toast_time > 0:
		var width := font.get_string_size(game.toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
		_text(game.toast, Vector2((size.x - width) * 0.5, size.y * 0.24), 28, ACCENT)
	if game.wrong_way_time > 1.3:
		_text("逆向行驶", Vector2(size.x * 0.5 - 72, size.y - 55), 19, ACCENT)
	elif not game.car.on_road:
		_text("草地减速", Vector2(size.x * 0.5 - 54, size.y - 55), 16, ACCENT)

func _draw_nitro() -> void:
	var fill: float = clampf(game.car.nitro, 0.0, 1.0)
	var color: Color = NITRO if game.car.nitro_active else Color("b6d7db")
	var label := "SHIFT  NITRO"
	if game.car.nitro_active:
		label = "NITRO"
	elif game.car.mini_turbo_time > 0.0:
		label = "MINI TURBO"
		color = ACCENT
	elif fill <= 0.01:
		label = "NITRO  EMPTY"
		color = Color("819ca2")
	_text(label, Vector2(size.x - 175, size.y - 39), 11, color)
	var bar := Rect2(size.x - 175, size.y - 29, 144, 5)
	draw_rect(Rect2(bar.position - Vector2(1, 1), bar.size + Vector2(2, 2)), Color(0.06, 0.14, 0.18, 0.75))
	draw_rect(bar, Color(0.70, 0.86, 0.87, 0.16))
	if fill > 0.0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)), color)
	for part in range(1, 4):
		var x: float = bar.position.x + bar.size.x * float(part) / 4.0
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Color(0.07, 0.17, 0.20, 0.65), 1.0)

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
	var origin := Vector2(102, size.y - 101)
	var map_scale := 0.42
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
