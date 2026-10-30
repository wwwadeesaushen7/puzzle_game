# Validation and remaining release work

Validation was performed in the managed Linux development environment on 30 October 2026, using Godot 4.6.3 and Blender 4.3.2.

## Passed

| Check | Evidence |
| --- | --- |
| Project import and headless startup | All game scripts and generated assets load. The reusable `tools/setup_cloud.sh` was exercised successfully. |
| Puzzle rules | **3,081 assertions, zero failures.** All 30 standard expeditions and four deterministic daily seeds replay their complete solution certificates without abilities. Tests also cover blocked selections, exact undo restoration, SAT coverage, locks, frost, secrets, reweaving, tray overflow order and the eighth-slot limit. |
| Progress and recovery | **9 checks, zero failures.** Rewards, unlocking, replay reward limits, star improvements, independent daily progress, coin limits, JSON persistence and corrupt-save recovery. |
| Headless scene integration | **22 checks, zero failures.** Scene setup, camera, picking, animated collection, a complete animated expedition, all worlds, mechanisms, quality changes, abilities and portrait gestures. |
| Rendered scene integration | **34 checks, zero failures**, on OpenGL/Mesa llvmpipe. Captured the main menu, board, collection, victory, five worlds, level selection, settings and portrait views. |
| Input and fallback smoke tests | **9 checks passed in each of two runs.** Mouse events were routed through the viewport to the 3D picker. Requested Mobile/Forward+ backends fell back to Compatibility; these are fallback tests, not proof of Vulkan rendering. |
| Original asset audit | **44 GLBs**: 22 designs with high/mobile LODs, valid positions/normals/UVs, actual triangle reductions and 1024px/256px image variants. High assets total 103,734 triangles; low assets total 45,152. These are sums across the asset library, not per-frame counts. Full report: `asset-audit.json`. |
| Windows package | A real x64 PE executable was exported with an embedded Godot pack. Header and pack signatures were checked. The packed main scene was also loaded by the matching Linux Godot engine: 18 initial relics, the main menu and bundled license viewer passed. This does not substitute for launching the executable on Windows. |
| Android package | A real development-signed arm64 APK was exported using the matching API 36 toolchain. `apksigner verify` passed APK signature schemes v2 and v3. ZIP integrity, native library and bundled notices were checked. Manifest reports package `org.astralforge.relicmatch`, min SDK 24, target SDK 36, with no requested Internet permission. |
| Dependency integrity | Godot export-template archive verified against the official SHA-512 manifest. Android SDK archives verified against Google's repository metadata. TLS and artifact verification remained enabled. |

## Standalone downloads

`downloads/AstralForge-Windows.zip` contains the self-contained Windows executable and notices. `downloads/AstralForge-Android.apk` is the same verified Android application with stored assets ZIP-compressed, aligned again, and signed with the existing development key. Every application entry is checked byte-for-byte against the original APK. Godot's Android asset loader uses `AAsset_read`/`AAsset_seek`, which support compressed assets. APK signature schemes v2/v3 and alignment are verified again. This packaging change reduces the download size without removing application files; native device testing is still outstanding.

Both files are hosted directly in the repository, and their SHA-256 checksums are in `downloads/SHA256SUMS.txt`. Reproduce them after a build with `python3 tools/prepare_downloads.py`.

## Platform and renderer limits

The cloud display uses **software OpenGL rendering**. It has no Vulkan ICD and reports a missing `VK_KHR_surface` extension when Vulkan is requested. Godot then falls back to OpenGL and gameplay works. Consequently, Forward+ SSAO/SSR/SSIL, volumetric fog, glow and depth of field have guarded implementations but still need visual validation on a Vulkan-capable device. No GPU or phone performance measurements are claimed.

The APK's prebuilt Godot template leaves an unused `themed_icon` resource-table entry after copying the themed XML into the active `icon.xml`. `aapt2` reports that unused path as a warning. The active adaptive icon file and its foreground/background/monochrome resources are present; signing and package validation pass. This behavior was traced to the official 4.6.3 exporter, which deliberately skips `themed_icon.xml`. Native launcher/install testing remains part of Android QA.

No Windows machine, Android phone or emulator was attached. Native execution, installation, GPU-driver coverage, pause/resume lifecycle behavior, orientation on actual devices, sustained frame times, thermal/battery behavior and accessibility testing remain unverified. The 30/60 FPS modes are caps and design targets, not performance guarantees.

## Production work still required

- Playtest difficulty, coin balance and the full progression with human players. The solution certificates establish solvability, not an ideal difficulty curve.
- Review the procedural art on target displays and complete any desired photorealistic art pass. The included art is functional, original 3D fantasy art; no AAA production-quality certification is claimed.
- Profile representative low-end and high-end Android devices and Windows GPUs, then tune budgets and quality defaults using those measurements.
- Supply a production Android signing identity and store configuration. The supplied APK uses development signing. Windows Authenticode signing is not configured.
- Perform native release QA and choose distribution/store metadata before publishing.

The seven requested development areas have concrete implementations. Core gameplay, assets, animations, UI/progression and level validation are exercised. Optimization controls and export preparation are implemented; performance certification and native platform release QA remain open.

## Reproduction

Run `bash tools/test.sh` for the isolated-save headless suites. With a display, use `DISPLAY=:99 bash tools/test.sh --render`. Regenerate/check art with the commands in `DEVELOPMENT.md`. Export with `bash tools/export.sh`; package deliverables with `python3 tools/package.py`.

Local saves, signing keys, SDKs, engine binaries and cache directories are excluded from the editable source archive. Cloud installation/start instructions are saved in the environment draft; review/save and publication in environment settings are separate product actions. A newly published task has not been tested in this session.
