# Building DEX DASH

## Requirements

- Godot 4.7.1 (standard build, any platform) — [godotengine.org](https://godotengine.org)
- Node.js 18+ (only to regenerate assets)
- For exports: export templates for 4.7.1 (Editor -> Manage Export Templates)

## First run

```bash
node tools/gen-all.js        # generate atlases, music, SFX (idempotent)
godot --headless --import --path .   # import assets, compile scripts
godot --path .               # play
```

## Export presets

The repo ships `export_presets.cfg` with two presets:

- **Windows Desktop** — `build/dex-dash-win64/`
- **Linux/X11** — `build/dex-dash-linux/`

### From the editor

1. Install the 4.7.1 export templates.
2. Project -> Export -> select preset -> Export Project (or "Add" to configure).
3. Output lands in `build/` (gitignored).

### From the command line

```bash
# Windows
godot --headless --path . --export-release "Windows Desktop"
# Linux
godot --headless --path . --export-release "Linux/X11"
```

The export includes the embedded project settings (GL Compatibility renderer,
1280x720 window, stretch mode `canvas_items`), so the game scales to any
display.

## Verifying a build

Run the exported binary; you should reach the main menu with music playing.
Headless smoke checks (see CONTRIBUTING.md) cover the in-editor build.
