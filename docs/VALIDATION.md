# Astral Forge 1.1.0 validation

Validated on 30 October 2026 in a fresh GitHub checkout under `/workspace/astral-forge`, using Godot 4.6.3, OpenJDK 21, Android build tools 36.0.0, and Mesa software OpenGL. The previous publishing draft was not used. A new managed cloud instance was not provisioned; the fresh checkout used the available cloud runtime.

## Automated checks

| Check | Result and scope |
| --- | --- |
| Puzzle rules | **7,178 assertions, zero failures.** Complete ability-free solutions for all 30 expeditions, four daily seeds and 36 additional seeded variants. Covers special rules, undo, mechanisms, capacity, seventh-slot matches, nonmutating hints, progressive tray pressure, and emitting effects only for completed triples. |
| Save/progression | **9 checks, zero failures.** Rewards, unlocking, replay limits, daily rewards, coin limits, persistence and corrupt-save recovery. Existing version-1 saves remain compatible. |
| Headless scene | **22 checks, zero failures.** Picking, animated selection, full expedition/victory, worlds, mechanisms, quality changes, abilities and portrait gestures. The old headless click failure is fixed by supplying viewport-local test coordinates. |
| Headless touch/layout | **162 checks, zero failures.** Real screen events through Godot's input pipeline: GUI taps, dragging a settings slider, swiping level selection without activating a level, victory/collection/tutorial navigation, single selection, synthetic mouse rejection, canceled touches, single-finger orbit, pinch, backgrounding, camera controls, and state preservation across rotation. |
| Rendered scene/touch | **34 scene checks and 168 touch/layout checks, zero failures.** Captures cover the main menu, full animated victory, all five worlds, settings, and six phone/tablet layouts. The final software-rendered suites completed without script errors. |
| Windows game payload | **10 checks, zero failures.** Matching Linux Godot loads the Windows executable's embedded pack, version 1.1.0, models, menu, touch selection, three camera views, 66-relic final level and license notices. This is not native Windows execution. |
| Android game payload | **10 checks, zero failures.** Matching Linux Godot loads the exported APK's extracted game assets and performs the same checks. This is not Android execution or lifecycle QA. |

The layout matrix covers **600×1000, 600×1300, 1000×600, 1300×600, 800×1280 and 1280×800** logical viewports. Each checks all three camera views, visible touch targets, picking, selection after rotation, and preserved puzzle state. The desktop touch test temporarily enables Godot's touchscreen emulation so ScrollContainer exercises its native touch-scrolling path. Production desktop mouse-to-touch emulation stays disabled.

Run `bash tools/test.sh`. With the repository's virtual display, run `DISPLAY=:99 LP_NUM_THREADS=4 ASTRAL_TEST_FIXED_FPS=5 bash tools/test.sh --render`. Both runners preserve command failures, require nonzero suite summaries and reject script errors. Fixed simulation timing supports software-rendered functional validation; it does not measure performance.

## Download and package verification

The Windows target is a real x64 PE executable with an embedded game pack. Android is **org.astralforge.relicmatch**, version **1.1.0 / code 2**, arm64, minimum API 24, target API 36. Its manifest enables all screen-size classes, a resizable activity and full-user sensor orientation (13); the project requests sensor orientation and immersive fullscreen at runtime. There is no requested Internet permission.

Godot templates are verified against the official SHA-512 manifest. Android SDK components are verified against Google's official repository checksums. TLS and artifact verification remain enabled.

`tools/prepare_downloads.py` compresses Android assets, verifies every application entry against the exported APK, aligns the APK, signs it again and verifies APK signature schemes v2 and v3. The Windows ZIP and APK have SHA-256 checksums in `downloads/SHA256SUMS.txt`. Both direct downloads must stay below GitHub's regular-file size limit.

The APK uses a **new development signing key** because the previous workspace's key was unavailable. Android cannot install it over the older differently signed preview. Uninstalling the old preview removes its local progress; retain that installation if preserving progress is essential. The new key is kept outside Git and must be preserved securely for future compatible updates. This is not store/release signing.

## Remaining device validation

No Windows host, Android phone, tablet or emulator was attached. Native installation, actual cutouts/navigation bars, orientation sensors/rotation lock, background/resume, touch hardware, GPU-driver coverage and sustained performance remain unverified. Full-user orientation respects the device's auto-rotate setting. The 30/60 FPS options are caps, not certified performance results.

Software OpenGL screenshots do not validate Vulkan-only Forward+ effects, battery use or thermal behavior. The original procedural fantasy art and its LOD assets are retained, with new colored relic accents, pulsing hints, astral markings and match ripples; this is not a replacement asset library.

Godot's official 4.6.3 Android template retains an unused `themed_icon` resource-table reference after copying its XML to the active icon. `aapt2` warns about that unused entry; active icon assets are present. APK signing/ZIP integrity pass. Legacy `aapt dump badging` also rejects a boolean feature attribute; `aapt2` and the manifest XML dump provide the verified package metadata.
