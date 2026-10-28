# Verification record — Lighthouse Circuit

Tested 2026-10-28 on the **dot cloud computer**, **Godot 4.7.2 stable** (`ed1daf0bf`), Compatibility renderer. This record describes the new 1,650 m circuit, not the previous 786 m prototype.

## Automated regression

`GODOT_BIN=/path/to/godot tests/run_tests.sh` imports into isolated temporary XDG/user-data directories and fails on `ERROR` or `SCRIPT ERROR`, even if Godot itself returns zero.

**103 checks passed:**

| Suite | Checks | Coverage |
|---|---:|---|
| `test_rules.gd` | 27 | Gate order/direction/corridor, duplicate crossings, finish oscillation, teleport and shortcut rejection, required road travel, three laps exactly once, timer freeze, countdown, pause/resume, restart, reset and boost resource preservation. |
| `test_car.gd` | 18 | Real CharacterBody3D acceleration/braking/reverse, road/off-road speed limits, floor contact, steering sign/speed response, slip recovery, four animated wheels, 30/60/120 Hz consistency, wall collision and reset. |
| `test_kart.gd` | 39 | Drift entry and countersteer, blue/orange charge/release, grass/air/brake/wall/reset cancellation, no charge farming, nitro drain/recharge/restrictions, shared 54 m/s cap, boosted collisions, same-tick wall/release reward rejection. |
| `test_track.gd` | 19 | Designed track geometry, per-section widths, feature gates, actual road collision, recovery and high-speed rail integrity, detailed below. |

The final aggregate includes the completed scenery, world signs, separate record key and idle-particle visibility fix. No test errors were ignored. An initial manual import using a reused editor configuration emitted an ObjectDB snapshot-directory error; the isolated aggregate import completed cleanly without an engine workaround.

### Track-specific evidence

- **1,649.997 m**, 528 centerline samples; **17 intermediate checkpoints + finish = 18 gates**.
- Road half-width 5.2–7.8 m; maximum width taper 0.0479 m per travelled metre.
- No non-adjacent centerline crossing, folded road triangle or overlapping road/rail envelopes. Minimum tested nonlocal envelope clearance **21.19 m**.
- **1,000** sample/nearest roundtrips retain position and local width.
- **540** center/near-edge raycasts find actual upward road collision at y = 0.12, maximum measured height error below 0.00001 m. The bridge is intentionally flat, not an untested slope/jump.
- All **18** gate recovery positions retain the timer/order, point forward, settle onto stable floor, and restart from rest using ordinary throttle.
- **12** 54 m/s impacts against the actual left/right rail colliders, including segment seams: contact stops the car; no tunnelling, launch or corridor escape. These are explicitly positioned collision fixtures, not claimed as driven laps.

## Uninterrupted driving

`tests/drive_laps.gd` uses normal `Input.action_press` / `action_release` calls. It never assigns the car transform/velocity, changes laps/gates, disables collisions, or invokes recovery while driving. This is an external QA script, not an in-game AI opponent. It shares the normal scene, countdown, controller and rules; `test_mode` only prevents overwriting player records.

- Ordinary headless input drive: **three complete laps, 196.75 s simulated**, laps **66.17 / 65.27 / 65.32 s**, maximum centerline offset **1.12 m**. This initial route run also exercised installed Godot 4.6.3; the release regression uses 4.7.2.
- Godot 4.7.2 headless `--kart`: **three complete laps, 161.88 s simulated**, laps **55.15 / 53.37 / 53.37 s**, **27** valid orange mini-turbos and **1,166** nitro physics ticks; maximum offset **4.77 m**.
- Native desktop Godot 4.7.2 `--kart`: **three complete laps passed, 161.88 s simulated**, laps **55.15 / 53.37 / 53.37 s**, **27** orange mini-turbos, **1,166** nitro physics ticks. Of those, **9** mini-turbos occurred in the lighthouse sector and **531** nitro ticks on the bridge. Maximum offset **4.77 m**, **zero wall-contact ticks and zero off-road ticks** in 9,895 physics ticks. The captured moving lighthouse view, orange drift release, bridge nitro and finish are genuine viewport frames with the normal clock/speed; no values were staged.

Reproduction:

```sh
/path/to/godot --headless --path . --fixed-fps 60 --script res://tests/drive_laps.gd
/path/to/godot --headless --path . --fixed-fps 60 --script res://tests/drive_laps.gd -- --kart
# On an available native display:
/path/to/godot --path . --fixed-fps 10 --audio-driver Dummy \
  --script res://tests/drive_laps.gd -- --kart --capture-dir=/absolute/output/path
# Explicit static layout/landmark fixtures; NOT evidence of uninterrupted driving:
/path/to/godot --path . --script res://tests/capture_track.gd \
  -- --capture-dir=/absolute/output/path
```

## Visual / performance limits

Native screenshots are actual Godot viewport readbacks on the existing dot desktop (`DISPLAY=:0`), using **Mesa llvmpipe software rendering**, not a real discrete GPU. The native capture fixes rendering to 10 simulated frames/s while physics remains 60 Hz; the 7.56-second / 54-frame GIF is resampled to 140 ms/frame and follows simulated game time. Its playback and the simulated lap clock are **not** wall-clock GPU performance measurements.

The native driver emits the expected llvmpipe V-Sync warning. Dummy audio was used for capture; generated engine sound exists, but speakers were not auditioned. No Windows/macOS/mobile/controller, exhaustive accessibility or discrete-GPU certification is claimed. There is no existing CI workflow; no CI pass is claimed. Deliverable is the source repository, not a packaged executable or ZIP.
