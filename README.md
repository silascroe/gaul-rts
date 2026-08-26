# First Videogame

An old-school real-time strategy prototype set in an alternate Iron Age Gaul.

**The Broken Oath** is the first scenario: a fictional border war in the Sable Vale between the Alder League and the Flint Crown. It borrows the texture of pre-Roman Gaul—hillforts, iron workings, river roads, groves, oaths, and competing confederacies—without pretending to be a fidelity-max historical reconstruction.

> Status: early playable foundation. The rules are deliberately small, the art is procedural placeholder work, and the project is expected to change.

## Current slice

- Real-time fixed-tick simulation with pause support
- Two themed factions: the Alder League and the Flint Crown
- Gatherers, spearmen, and hillforts
- Abstract iron extraction at strategic sites
- Neutral, controlled, contested, and raided resource states
- Production queues and a basic enemy AI
- Click selection, drag-box selection, and contextual right-click orders
- Camera pan, zoom, selection readout, and an old-school minimap
- A simple win condition: break the enemy hillfort

## Controls

| Input | Action |
| --- | --- |
| Left click | Select a unit or hillfort |
| Left-drag | Select multiple friendly units |
| Right click | Move, extract, or attack |
| WASD / arrow keys | Pan the camera |
| Mouse wheel | Zoom |
| Space | Pause / resume |
| B | Queue a spearman at the selected hillfort |
| W | Queue a gatherer at the selected hillfort |
| R | Restart the match |
| Escape | Clear the current selection |

Resource gathering is intentionally abstract: a gatherer works an iron site and adds stores without physically returning to the hillfort. The tradeoff is strategic pressure on the map. Enemy spearmen can shut down your extraction, while both sides contesting a site reduces output.

## Run locally

Open the project folder in **Godot 4.x** and press **Play**. The project file targets Godot 4.3-compatible settings.

The project currently has no external art or audio dependencies. The world, units, HUD, and map details are drawn by code so the rules can be tested before an asset pipeline is chosen.

## Headless test

Once Godot is installed, run the extraction-rule smoke test from the project root:

~~~text
godot --headless --path . --script res://tests/simulation_smoke.gd
~~~

The test checks neutral extraction, enemy control, and reduced output at contested sites.

## Project structure

~~~text
project.godot              Godot project configuration
scenes/main.tscn           Application entry scene
src/game_data.gd           Scenario, faction, unit, and resource definitions
src/simulation.gd          Fixed-tick rules and game state
src/main.gd                Rendering, camera, HUD, and input
tests/simulation_smoke.gd  Headless check for extraction rules
docs/SETTING.md            Current setting and tone
docs/DECISIONS.md          Confirmed choices and open design questions
~~~

The simulation is deliberately separate from presentation. That leaves room for alternative cameras, better tools, AI experiments, and headless tests without turning every change into a scene-editing exercise.

## Design direction

The project is meant to feel old-school without becoming a nostalgia tax. The goal is a legible battlefield with meaningful choices, not a modern content treadmill or a clone of another game.

The setting layer is data-driven. Factions, names, units, resources, and the historical divergence can change without rewriting the simulation. The first scenario uses fictional peoples so the game can develop its own identity instead of reducing real historical cultures to color-coded stereotypes.

The next major structural choice is whether battles remain standalone scenarios or become part of a lightweight persistent campaign. That decision is intentionally still open.

## License

No license has been chosen yet. Until a license is added, do not assume the code or assets are available for reuse beyond the permissions granted by the repository host.
