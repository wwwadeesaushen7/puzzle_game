# Astral Forge 1.1.0

- Allow scroll gestures to propagate through level buttons and containers while blocking HUD clicks from selecting the board.
- Enable Godot's touch-to-mouse GUI path; route raw board touches separately and reject duplicate synthetic mouse selections.
- Cancel pending taps on drag, multi-touch, modal navigation, rotation, cancellation and backgrounding. Single-finger drag orbits; pinch and twist remain available.
- Use immersive Android fullscreen with sensor orientation and an adaptive logical viewport. Keep controls inside display safe bounds. Preserve open panels and scroll position on resize.
- Add Perspective, Overhead and Inspect views, zoom buttons and camera reset. Fit board bounds for each view and use a side control column on compact landscape screens.
- Introduce interleaved matching waves and a fifth layer in final levels, reaching 66 relics. Preserve deterministic, ability-free solution certificates.
- Emit match effects only for completed triples.
- Add relic color accents, pulsing hint rings, astral markings, expanding match effects, a thin progress strip and tray pressure feedback.
- Fix headless scene input coordinates and add touch/layout/camera regression coverage. Test runners reject script errors and missing suite results.
- Refresh the direct Windows ZIP and Android APK to 1.1.0 (Android version code 2). The APK uses a new development signing key because the previous workspace key was unavailable; uninstalling the earlier build removes its local progress.
