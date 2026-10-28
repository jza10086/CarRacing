# Artwork and research credits

## Included artwork — Kenney, CC0 1.0

Only the models used by the game are included. Original pack licenses are preserved in each asset directory. Thank you, Kenney!

| Directory | Included models | Original pack | Author's public download |
|---|---|---|---|
| `assets/kenney_car_kit` | `sedan-sports.glb`, required `Textures/colormap.png` | [Car Kit 3.1](https://kenney.nl/assets/car-kit) | [OpenGameArt](https://opengameart.org/content/car-kit) |
| `assets/kenney_racing_kit` | `grandStandCovered`, `pitsOffice`, `flagCheckers` | [Racing Kit 1.2](https://kenney.nl/assets/racing-kit) | [OpenGameArt](https://opengameart.org/content/racing-kit) |
| `assets/kenney_nature_kit` | `tree_pineRoundA`, `tree_pineTallA`, `tree_oak`, `rock_largeA` | [Nature Kit 2.1](https://kenney.nl/assets/nature-kit) | [OpenGameArt](https://opengameart.org/content/nature-kit) |

License: [CC0 1.0 Universal](https://creativecommons.org/publicdomain/zero/1.0/). Asset provenance and licenses verified 2026-10-28. Author-uploaded public OpenGameArt archives were used because the official ZIP endpoints returned HTTP 403. Archive hashes:

- Car Kit: `fac7dacac5c7874348cf19729af3ef205f3d366493edaf0a827d93f4fdf3d0c4`
- Racing Kit: `103acf8a85a04e94e2d3a9933fbcea12e9422c14d5e364eb013019a882af7f48`
- Nature Kit: `fa7974a0d342bfe63c38664ba9f8ec1a4aab8ea25f099bdc56870e33588c4d9d`

Racing Kit glTF/BIN files were repackaged as self-contained GLBs, and an `asset_origin` root centers X/Z and grounds Y without changing geometry/materials. Other source models retain their author geometry and materials. In-game scale/orientation and separate wheel animation are applied in code. No brand/logo is used as game branding. The track, terrain, mountains, rails, HUD, handling, and synthesized engine loop are original project work. Chinese UI uses a renamed glyph subset of **Noto Sans CJK SC Regular**, licensed under **SIL Open Font License 1.1**. Source: https://github.com/notofonts/noto-cjk . The subset is named **Ridgeline Interface**; the full installed source package copyright/license is preserved at `assets/fonts/LICENSE.txt`. No proprietary fonts are included.

## References studied before implementation

This is an original small arcade controller, **not** an imported vehicle framework or a realistic vehicle simulation. The external example projects below were inspected as references, not shipped or executed as game dependencies.

- [Godot `VehicleBody3D` documentation](https://docs.godotengine.org/en/stable/classes/class_vehiclebody3d.html): known limitations; custom CharacterBody3D / RigidBody3D approach.
- [Godot `CharacterBody3D`](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): floor snapping and collision-aware `move_and_slide`.
- [Godot Truck Town (4.3, MIT)](https://github.com/godotengine/godot-demo-projects/tree/4.3/3d/truck_town): steering smoothing and chase-camera concepts.
- [Godot Recipes 3D car sphere (MIT)](https://github.com/godotrecipes/3d_car_sphere): separate visual car lean and wheel motion.
- [Godot Easy Vehicle Physics (MIT)](https://github.com/DAShoe1/Godot-Easy-Vehicle-Physics): speed-dependent steering, grip, countersteer and surface-resistance concepts. Its full raycast-vehicle framework is not included.
- [art of rally](https://www.artofrally.com/): visual reference for clean road ribbons, restrained HUD and low-poly landscape composition. No screenshots, models, branding, code or other assets from that game are included.
