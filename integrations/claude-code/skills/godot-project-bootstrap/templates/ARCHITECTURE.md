# ARCHITECTURE — <game name>

> How the project is built. Update it in the same change that adds, moves or removes a system, scene or autoload.

## Layout
| Folder | Contents |
|---|---|
| `scenes/` | `.tscn` scenes |
| `scripts/` | GDScript |
| `resources/` | `.tres` resources (data, materials, themes) |
| `data/` | JSON / CSV game data |
| `assets/` | art, audio, fonts |

## Main scene and autoloads
- Main scene: `res://scenes/main.tscn`
- Autoloads: name → script, and what each one owns.

## Systems
For each system: purpose, main scripts/scenes, the data it owns, how other systems talk to it (signals, method calls, autoload).

## Data flow
How game state moves between systems (e.g. simulation tick → state → UI).

## Conventions
Naming, typed GDScript, signal naming, where generated content lives (data + generator script, not hand-placed nodes).
