# Decisions and open questions

This file keeps the important choices visible. Early decisions are deliberately reversible.

## Confirmed direction

- The game is a real-time strategy game rather than a turn-based strategy game.
- The presentation should feel old-school, even if the underlying implementation is modern Godot code.
- The first project is also a way to learn how RTS games work, so the simulation should remain understandable and inspectable.
- The setting is pre-Roman Gaul-inspired alt-history rather than a strict historical reconstruction.

## Chosen for the first prototype

### Real-time simulation

The game advances continuously with a fixed simulation step. The player can pause later, but real-time is the default because that is the kind of strategy game we are trying to understand.

### Old-school presentation

The first pass uses a restrained palette, geometric placeholder art, a map-like HUD, and no asset dependency. The eventual visual direction is open.

### Small battlefield before grand strategy

The first loop is battlefield RTS: select units, issue orders, gather resources, produce units, and destroy the enemy headquarters. Political and grand-strategy systems are future layers, not current assumptions.

### Two factions and one map

The first simulation is intentionally small enough to reason about while still producing a complete game loop.

### Abstract extraction with contested sites

Workers extract iron at the site instead of carrying it back to the hillfort. This keeps the economy readable and puts the interesting decision on the map: which sites can be held, defended, or raided? Enemy spearmen stop extraction when they have uncontested military presence at a site; both sides present means reduced output.

### Standalone scenarios before campaign

The first development phase uses self-contained battles. A later campaign-lite war map may connect them through territory, alliances, resources, and consequences, but it will not be built until the battlefield layer is working on its own.

### Pausable battlefield

The simulation is real-time by default but can be paused with Space. This keeps the first prototype approachable while preserving the real-time decision-making we want to learn.

### Fictional factions, historical texture

The first scenario uses the invented Alder League and Flint Crown in the Sable Vale. This gives the game room to develop its own conflicts and visual language without pretending that two fictional factions are literal stand-ins for specific historical peoples.

## Open questions for the next design pass

- What is the alternate-history point of divergence, and how early should it shape the world?
- Should the camera stay top-down, become isometric, or use a faux-3D perspective?
- Should the factions remain confederacies, or become city-states, dynasties, cults, or something stranger?
- Is the long-term game battlefield-focused, economy-focused, or a hybrid?
- How much of the interface should feel like a classic RTS, and how much should feel deliberately personal?
