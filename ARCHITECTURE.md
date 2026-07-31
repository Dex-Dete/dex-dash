# Architecture

DEX DASH is built as a compact set of autoload singletons plus self-contained
gameplay scripts. Scenes are thin; almost all UI is constructed in code with
shared helpers (`UIBuilder`).

## Autoloads (scripts/autoload/)

| Singleton | Responsibility |
|---|---|
| `Assets` | Loads atlases + fonts, exposes texture rects by name |
| `AudioManager` | Music crossfade, BPM metadata, pooled SFX, bus volumes |
| `SettingsManager` | settings.json (video, audio, gameplay, ui, controls) |
| `SaveManager` | save.json: progress, coins, stats, achievements, unlocks, replays, custom levels |
| `StatsManager` | Lifetime + session statistics |
| `AchievementManager` | 26 achievement definitions and evaluation |
| `UnlockManager` | Icon colors / trails catalog, buying and equipping |
| `DailyManager` | Date-seeded daily level generation |
| `Localization` | 6-language string tables, runtime switching |
| `GameFlow` | Scene transitions (fade), current mode/level state |
| `InputActions` | Token-based rebindable input (physical keycodes) |
| `ThemeManager` | 7 color themes driving backgrounds and UI accents |
| `BeatManager` | Beat windows from the playing track |
| `LevelGenerator` | Procedural chunks for Endless and Daily modes |

## Gameplay (scripts/gameplay/)

`Level` owns the simulation: a fixed 60 Hz tick loop with accumulator, so
gameplay is deterministic regardless of frame rate.

**Level-frame physics.** The world is a cell grid (48 px). The player has a
position, a gravity unit vector and a forward unit vector. Rotation portals
rotate both vectors by 90°, and the camera spins to match — the level data
itself never moves, which keeps rotated sections coherent and replay-safe.

Movement is `forward * speed + gravity * vy` per tick, with speed tiers
(1.0 / 1.18 / 1.42 / 1.73), coyote time (4 ticks), jump buffering (6 ticks),
and full 1.0x collision hitboxes: the body dies on any solid overlap except
the support row/column it is landing on (the snap resolves contact), so
landings are safe while walls, ceilings and steps crush — GD-style.

**Control forms.** The player's `_ctrl` is one of `cube` (tap jump, hold for
higher), `ship` (hold = thrust against gravity), `wave` (hold = accelerate
toward the ceiling, dies on any surface), `ufo` (tap = mid-air hop) and `ball`
(tap = flip gravity, dies on any surface). Mode portals switch forms; jump
orbs give a tap-bounce in every form. Ghost replays (DXR2) record the held
state per tick so hold-based forms replay exactly.

- `LevelData` — data model, collision/index grids, validation, JSON I/O
- `LevelCatalog` — the 18 campaign levels, defined with compact design helpers
- `LevelRenderer` — batched atlas drawing with view culling (two passes)
- `BackgroundFX` — parallax layers, beat pulse
- `EffectsFX` — pooled particles and rings
- `PlayerView` / `BossView` / `CameraRig` — visuals
- `ReplayRecorder` — bit-packed DXR2 replay encoding with ghost playback
- `tools/mode_test.gd` — headless regression harness for forms, portals, orbs
  and collision (`godot --headless res://tools/mode_test.tscn`)

## Menus (scripts/menu/)

Every screen is a Control built in code: level select (sequential unlock),
story hub, endless / daily / custom menus, settings (with live input rebinding),
statistics, achievements, and the icon shop.

## Editor (scripts/editor/)

Cell-based editor with a paint palette, drag painting, snapshot undo/redo,
playtest (reuses the real gameplay scene), and clipboard export/import. Custom
levels are stored as JSON in save.json.

## Asset pipeline (tools/)

`gen-textures.js` renders every texture into packed atlases (PNG + JSON rects).
`gen-audio.js` synthesizes 10 music tracks (with BPM metadata) and 25 SFX as
WAVs. Run `node tools/gen-all.js` after checkout.
