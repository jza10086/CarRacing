extends RefCounted
## Local bindings shared by formal input and F6 defaults. Reading does not persist them.
static func schema() -> Dictionary:
	var fields: Dictionary = {
		"car_racing_accelerate": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_W, "physical": true}, {"kind": "key", "code": KEY_UP, "physical": true}],
			"title": "加速", "action": "car_racing_accelerate", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_brake": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_S, "physical": true}, {"kind": "key", "code": KEY_DOWN, "physical": true}],
			"title": "刹车／倒车", "action": "car_racing_brake", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_steer_left": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_A, "physical": true}, {"kind": "key", "code": KEY_LEFT, "physical": true}],
			"title": "向左转向", "action": "car_racing_steer_left", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_steer_right": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_D, "physical": true}, {"kind": "key", "code": KEY_RIGHT, "physical": true}],
			"title": "向右转向", "action": "car_racing_steer_right", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_handbrake": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_SPACE, "physical": true}],
			"title": "漂移", "action": "car_racing_handbrake", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_nitro": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_SHIFT, "physical": true}],
			"title": "氮气", "action": "car_racing_nitro", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_reset_car": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_R, "physical": true}],
			"title": "返回赛道", "action": "car_racing_reset_car", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"car_racing_start_race": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_ENTER, "physical": true}],
			"title": "开始比赛", "action": "car_racing_start_race", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false}
	}
	var layout: Array[Dictionary] = []
	for key: String in fields:
		layout.append({"field": key})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": layout}
