extends RefCounted
## Deliberate road graph: cubic Bezier segments, half-widths and feature gates.
## One flat, closed loop, no crossing/shortcut/jump. +Z is south on the map.
const NAMES := ["港湾出发", "礁岸节奏", "船坞发卡", "灯塔长弧", "防波堤冲刺", "归港末弯"]
const LABELS := ["HARBOR", "REEF S", "DRYDOCK", "LIGHTHOUSE", "BREAKWATER", "HOME TURN"]
const K := 0.55228475

static func _p(x: float, z: float) -> Vector3:
	return Vector3(x, 0, z)

static func _segment(a: Vector3, b: Vector3, c: Vector3, d: Vector3, w0: float, w1: float, sector: int, gate: bool = false) -> Dictionary:
	return {"a": a, "b": b, "c": c, "d": d, "w0": w0, "w1": w1, "sector": sector, "gate": gate}

static func _line(a: Vector3, d: Vector3, w0: float, w1: float, sector: int, gate: bool = false) -> Dictionary:
	return _segment(a, a.lerp(d, 1.0 / 3.0), a.lerp(d, 2.0 / 3.0), d, w0, w1, sector, gate)

static func segments() -> Array[Dictionary]:
	return [
		# Harbor launch and welcoming 80 m-radius right bend.
		_line(_p(-240,130), _p(-240,-50), 7.2, 7.2, 0),
		_segment(_p(-240,-50), _p(-240,-50-80*K), _p(-160-80*K,-130), _p(-160,-130), 7.2, 7.2, 0, true),
		_line(_p(-160,-130), _p(-120,-130), 7.2, 6.2, 0, true),
		# Two linked but readable S beats; no blind or mandatory jump.
		_segment(_p(-120,-130), _p(-75,-130), _p(-85,-180), _p(-40,-180), 6.2, 6.2, 1, true),
		_segment(_p(-40,-180), _p(5,-180), _p(-5,-130), _p(40,-130), 6.2, 6.2, 1, true),
		# 50 m straight braking view, then R32 hairpin; wide entry/exit.
		_line(_p(40,-130), _p(90,-130), 6.2, 7.8, 2, true),
		_segment(_p(90,-130), _p(90+32*K,-130), _p(122,-98-32*K), _p(122,-98), 7.8, 7.8, 2, true),
		_segment(_p(122,-98), _p(122,-98+32*K), _p(90+32*K,-66), _p(90,-66), 7.8, 7.8, 2, true),
		_line(_p(90,-66), _p(50,-66), 7.8, 6.8, 2, true),
		_segment(_p(50,-66), _p(50-40*K,-66), _p(10,-26-40*K), _p(10,-26), 6.8, 6.8, 2),
		_line(_p(10,-26), _p(10,24), 6.8, 7.0, 3, true),
		_segment(_p(10,24), _p(10,24+80*K), _p(90-80*K,104), _p(90,104), 7.0, 7.0, 3, true),
		# Lighthouse bowl: sustained 180 degree drift, unbroken wide exit to bridge.
		_segment(_p(90,104), _p(90+80*K,104), _p(170,184-80*K), _p(170,184), 7.0, 7.0, 3, true),
		_segment(_p(170,184), _p(170,184+80*K), _p(90+80*K,264), _p(90,264), 7.0, 7.0, 3, true),
		# 240 m exposed bridge: turbo release / optional nitro, no speed gate.
		_line(_p(90,264), _p(35,264), 7.0, 6.3, 4, true),
		_line(_p(35,264), _p(-95,264), 6.3, 6.3, 4, true),
		_line(_p(-95,264), _p(-150,264), 6.3, 5.2, 4, true),
		# Fully visible R90 home bend, a narrower commitment before the wide grid.
		_segment(_p(-150,264), _p(-150-90*K,264), _p(-240,174+90*K), _p(-240,174), 5.2, 6.2, 5, true),
		_line(_p(-240,174), _p(-240,130), 6.2, 7.2, 5, true)
	]
