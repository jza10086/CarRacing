## Lightweight catalog data. Do not load gameplay scenes or scripts here.
extends RefCounted

static func party_definition() -> Dictionary:
	return {"player_counts": [1], "controls": {"car_racing_accelerate": "加速", "car_racing_brake": "刹车／倒车", "car_racing_steer_left": "向左转向", "car_racing_steer_right": "向右转向", "car_racing_handbrake": "漂移", "car_racing_nitro": "氮气", "car_racing_reset_car": "返回赛道", "car_racing_start_race": "开始比赛"}}
