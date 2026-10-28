# Verification record

Tested 2026-10-28 on the dot cloud computer with **Godot 4.7.2 stable**, Compatibility renderer.

## Automated targeted checks

`tests/run_tests.sh` imports the project in an isolated temporary XDG/user-data directory, runs all three test scripts and fails if Godot prints `ERROR` or `SCRIPT ERROR`, even when the engine process returns zero.

- **27 rules/state checks passed**: continuous closed centerline sampling; expected checkpoint only; forward crossing only; off-corridor crossing rejection; duplicate gates; finish-line oscillation; large-step teleport rejection; checkpoint visits without enough road traversal; off-road shortcut rejection; reset keeps order/time; restart; three valid laps finish exactly once; completed timers freeze; countdown; pause/resume preserves clock and momentum; recovery clears motion; pause freezes nitro/boost/charge; reset keeps bottle level; new race refills and clears drift.
- **18 real CharacterBody3D physics checks passed** in an isolated flat arena: imported model/four separate wheels, no steering while stationary, 43 m/s road cap, ground stability, wheel spin, braking before bounded −9 m/s reverse, steering sign in forward/reverse, reduced high-speed steering, stable lateral grip/recovery, 17 m/s off-road cap, comparable 30/60/120 Hz acceleration, wall collision without tunneling/explosive velocity, finite state and reset.
- **39 kart-mechanic physics checks passed**: stationary/reverse/straight/low-speed rejection; fresh-press entry; left/right symmetry; direction commitment and bounded countersteer/slip; near-straight and low-speed full-countersteer charge rejection; early/blue/orange releases and expiry; grass/air/brake/wall/reset cancellation; nitro forward/ground restriction, drain, empty-hold lockout, delayed recharge, reset preservation, new-race refill and disabled-state freeze; shared boost speed cap; 30/60/120 Hz charge/drain consistency; boosted wall impact without tunneling or leaving the floor; same-tick drift release + wall impact cannot award mini-turbo or nitro.
- Track geometry additionally checked with 1,000 sample/nearest roundtrips (maximum positional error below 0.00001 m), start basis direction and 12 road-collision raycasts at y=0.12. Road mesh and collision share the same surface.

These tests exercise a focused arcade-racer scope; they are not an exhaustive physics, accessibility or hardware certification.

## Complete driving path

`tests/drive_laps.gd` steers by **normal `Input.action_press` / `action_release` actions**. It never sets the car transform, velocity, checkpoint or lap count. It follows the same scene, countdown, controller, collision and race rules as a player. It is a QA driver, not an in-game AI opponent.

- Headless final scene: **three complete laps passed**, approximately **99.60 s simulated race time**; lap times approximately 33.78 / 32.90 / 32.92 s. Maximum centerline offset stayed below 2.4 m (road half-width 6 m).
- New `--kart` normal-input headless run: **three complete laps passed**, **81.48 s simulated time**, 15 valid drifts and 15 orange mini-turbos, plus 556 physics ticks of active nitro. Maximum centerline offset **5.40 m**, within the 6 m half-width. No transforms, velocity, laps or gates are overwritten by this driver.
- Native desktop Compatibility rendering: **three complete kart laps passed**, 81.52 s simulated time, 15 drifts / 15 orange mini-turbos and active nitro, maximum offset 5.59 m. Actual viewport captures verify blue/orange wheel sparks, smoke, short tail flames, the compact nitro gauge, camera response and finish. A 7.56-second / 54-frame GIF follows drift → release mini-turbo → nitro; its playback follows simulated time, not software-renderer wall-clock speed.
- The two final reward/countersteer edge fixes were applied after that native capture and rechecked in the final 39-check kart suite plus another complete headless three-lap drive. They do not alter the reviewed visual effects. The final aggregate run's first 27 rules + 18 car checks passed; a temporary executor connection loss interrupted its kart stage, which was rerun separately to completion (39/39, no engine errors or warnings).
- First import, title, countdown, live curved-road driving and finish were observed; rule tests separately cover pause, recovery, repeated restart and return to countdown.

## Limitations

The dot desktop uses **Mesa llvmpipe software rendering** rather than a discrete GPU. Native frame rate is slower than a normal GPU, so the simulated race clock is not a real wall-clock performance benchmark. No claim is made about Windows/macOS/mobile/controller support, audio hardware output, or discrete-GPU performance. The native capture used the Dummy audio driver; synthesized sound generation is present but speaker output was not auditioned.

There is no existing CI workflow in this initially empty repository; no CI pass is claimed. The repository contains source and selected licensed assets only, not a packaged executable or export.
