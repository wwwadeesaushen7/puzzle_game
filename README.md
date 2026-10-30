# ASTRAL FORGE

An offline 3D relic-matching puzzle game for Windows and Android. Discover ancient artifacts, match three alike, and explore five astral worlds.

## Download and play

These are self-contained game downloads. **You do not need to install Godot or any development tools.**

| Platform | Direct download | Start playing |
| --- | --- | --- |
| Windows 10 / 11, 64-bit | [**Download the Windows game — ZIP**](https://github.com/wwwadeesaushen7/puzzle_game/raw/refs/heads/main/downloads/AstralForge-Windows.zip) | Extract the ZIP, then double-click **AstralForge.exe**. |
| Android 7 or newer, arm64 | [**Download the Android game — APK**](https://github.com/wwwadeesaushen7/puzzle_game/raw/refs/heads/main/downloads/AstralForge-Android.apk) | Open the APK, install it, then open **Astral Forge**. If prompted, allow installation from the app used to open this APK. |

These are preview builds. The Android APK uses development signing. See the [testing notes](docs/VALIDATION.md) for device-testing limits. Optional [download checksums](downloads/SHA256SUMS.txt) are included.


## Play

Collect **three identical relics** in the seven-slot tray. Only uncovered relics can be selected. Clear the entire board to win. A triple at the seventh slot resolves before failure. The first expeditions teach the rules; later ones introduce layered geometry and moving structures.

| Control | Desktop | Android |
| --- | --- | --- |
| Collect | Left click | Tap |
| Zoom | Mouse wheel | Two-finger pinch |
| Orbit | Right mouse drag | Two-finger turn |
| Undo / Reweave / Hint / Extra slot | U / R / H / E, or HUD buttons | HUD buttons |
| Rotate platform / shift carriage | Space / F, or HUD buttons | HUD buttons |
| Pause / fullscreen | Esc / F11 | Pause button |

Undo costs 10 earned coins; Reweave 25; a verified Hint 5; an Extra Slot 30. There are **no purchases, ads, network services, credentials or paid boosters**. Restart is free. Every standard expedition has a checked solution using no abilities. Reweave returns held relics, preserves completed matches, opens chambers and removes remaining seals while redistributing the same remaining relic counts.

Frozen relics thaw after one match. Matching Ancient Keys unlocks sealed relics. Mystery relics reveal their identity when uncovered. Guardian matches open secret compartments. Golden matches award additional first-clear coins.

## Included

- 30 deterministic expeditions across the Ancient Observatory, Crystal Temple, Golden Palace, Forgotten Ruins and Celestial Sanctuary.
- Twelve original modeled relics; beveled tiles; modeled chains, ice shells and hinged compartment lids; architectural and vegetation modules. Blender generates 22 designs, each with a separate mobile LOD.
- Original 1024-pixel PBR color/normal/roughness textures and 256-pixel mobile textures. GPU-compressed desktop and mobile imports, shared packed-scene caches, batched floor geometry and simplified pick colliders.
- Animated lifts, collection, matches, dissolves, mechanical rotation and carriage travel; GPU particles; original synthesized sound effects and ambient loop.
- Main menu, level selection, tutorial, pause, victory/defeat, settings, achievements, earned coins, stars and deterministic daily challenges. Daily challenges use the **UTC calendar date**, work offline, and award each day's first-clear reward once.
- Versioned local JSON progress with atomic replacement and a backup. Save corruption falls back to the previous complete save. Progress and settings are saved automatically; an unfinished board is restarted on relaunch.
- Landscape desktop and portrait mobile layouts, 30/60 FPS caps, render scaling, window sizes and fullscreen controls.

## Source map

The remaining sections are for developers who want to edit or rebuild the game. Players can use the downloads above.

`scripts/core/board_state.gd` owns selection, coverage, matches, special rules, undo, mechanisms and hints. `level_catalog.gd` constructs layouts and stores a legal removal certificate. `progress.gd` handles persistence and rewards. `scripts/main.gd` coordinates the scene, input and animations. `scripts/view/` contains the world, tile and interface presentation. `tools/` holds reproducible asset generation and build scripts.

No external art downloads are needed. The Blender generator and generated GLBs are included. See [asset rights](docs/ASSET_RIGHTS.md), [development and export](docs/DEVELOPMENT.md), and [validation and remaining QA](docs/VALIDATION.md).

### Optional editor setup

Developers can [download the source ZIP](https://github.com/wwwadeesaushen7/puzzle_game/archive/refs/heads/main.zip), open **`project.godot`** in Godot 4.6.3, and press **F5**, or run:

```sh
godot --path . --rendering-method gl_compatibility
```

Use `--rendering-method forward_plus` for advanced desktop lighting. The default desktop renderer supports OpenGL 3.3. Android uses the Mobile renderer with an OpenGL fallback. Quality settings scale meshes, textures, scene detail, shadows and supported effects.

## Verification

```sh
bash tools/test.sh                 # import, rule/progress suites, headless scene integration
DISPLAY=:99 bash tools/test.sh --render  # same integration in a real renderer; needs a display
python3 tools/audit_assets.py      # GLB geometry, UVs, normals, image sizes and LOD audit
```

Tests use isolated temporary save directories. Screenshots from rendered tests go into the ignored `artifacts/` directory. See `docs/screenshots/` for selected captured views.

## Builds

`export_presets.cfg` defines Windows x64 and Android arm64. `bash tools/export.sh` produces a Windows executable with an embedded game pack and a development-signed Android APK when matching templates and SDK tools are installed. See the development guide for exact toolchain setup.

The supplied art is an original procedural fantasy presentation. A photorealistic AAA finish, device-specific performance certification, store signing and native Windows/Android hardware QA require further production work; the project does not claim those results.
