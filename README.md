# First Videogame

An old-school real-time strategy prototype set in an alternate Iron Age Gaul.

The first scenario is **The Broken Oath**, a fictional border war in the Sable Vale between the Alder League and the Flint Crown. It uses the setting as a source of texture rather than as a fidelity-max historical simulation.

## Current milestone

- Real-time fixed-tick simulation
- Two themed factions: the Alder League and the Flint Crown
- Gatherers, spearmen, and hillforts
- Iron extraction sites with neutral, controlled, and contested states
- Spearman movement and attacks
- Hillfort production queue
- Camera pan and zoom
- Pause toggle and an old-school minimap
- Click selection and box selection
- Right-click contextual orders
- A readable in-game HUD

## Running it

Open the project folder in Godot 4 and press **Play**. Godot is not installed in the authoring environment yet, so the first run will be the first real engine validation.

Once Godot is installed, the simulation rule check can be run headlessly:

```text
godot --headless --path . --script res://tests/simulation_smoke.gd
```

## Working philosophy

The project is being built in layers:

1. A small deterministic-ish simulation core.
2. A thin presentation layer.
3. Data-driven definitions as the rules become more stable.
4. Tools and content only after the loop is fun enough to deserve them.

The goal is not to reproduce a specific existing game. Existing projects such as OpenRA and OpenVic are references for architecture and systems; this repository is its own project. The setting layer is deliberately data-driven so factions, names, and the historical divergence can change without rewriting the simulation.

Resource gathering is intentionally abstract. A gatherer works an iron site and adds stores without physically returning to the hillfort. In exchange, the site is a strategic control point: enemy spearmen can shut down extraction, or reduce it while both sides contest the ground.
