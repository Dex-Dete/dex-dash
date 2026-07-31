# Changelog

All notable changes to DEX DASH.

## [0.2.0] - 2026-07-31

### Added
- GD-style control modes: **ship** (hold to thrust), **wave** (hold up / release
  down, dies on any surface), **UFO** (tap = mid-air hop), **ball** (tap flips
  gravity, dies on any surface) — switched by five new portal types
- **Jump orbs** — tap to bounce in any form (works in every mode, like GD)
- New campaign level **"Mode Circuit"** (`modes_1`) teaching all five forms
- **Auto-retry**: instant restart on death, default ON (toggle in Settings)
- Replay format v2 (`DXR2`): records jump-hold state so ship/wave/ufo/ball
  ghost replays work

### Fixed
- Critical collision bug: the player died on landing (hitbox overlapped the
  ground row before snapping). Landing, wall and ceiling contact are now
  resolved correctly — the game is actually playable
- Jump orbs and mode portals now trigger at the body edge (3-cell sweep),
  matching GD overlap-trigger feel
- Cube-only variable jump height (hold = higher); UFO/ball are tap-only

## [0.1.0] - 2026-07-31

### Added
- Procedural asset pipeline (`tools/`): packed texture atlases, 10 synth music
  tracks with BPM metadata, 25 synthesized sound effects
- Core gameplay: fixed 60 Hz simulation, jump feel (coyote time, buffering),
  gravity/speed/size/dash portals, rotation + spin portals (level-frame model)
- 17-level campaign: Tutorial, Easy x2, Normal x3, Hard x2, Harder x2,
  Insane x2, Extreme x2, and the boss level THE WARDEN
- Practice mode with checkpoints; ghost replays of your best runs
- Endless mode (procedural, rising difficulty) and date-seeded Daily Challenge
- Level editor: cell painting, palette, undo/redo, playtest, clipboard
  import/export, custom level management
- Settings: video, audio, gameplay, interface, rebindable controls, save reset
- Statistics, 26 achievements, icon shop (8 colors, 5 trails)
- Localization: en, es, de, fr, pt, ja
- 7 color themes; accessibility options (reduced motion, high contrast, colorblind)
- Windows and Linux export presets
