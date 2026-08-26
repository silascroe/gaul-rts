class_name FirstGameData
extends RefCounted

## Setting and rules data live here so the simulation does not become a wall of
## hard-coded names and numbers as the project grows.


static func scenario() -> Dictionary:
	return {
		"title": "THE BROKEN OATH",
		"region": "The Sable Vale",
		"subtitle": "A border war in an alternate Iron Age Gaul",
		"objective": "Break the Flint Crown's hillfort.",
		"river_points": PackedVector2Array([
			Vector2(1110, -60),
			Vector2(960, 210),
			Vector2(1180, 470),
			Vector2(1030, 740),
			Vector2(1290, 1000),
			Vector2(1120, 1360),
		]),
		"roads": [
			PackedVector2Array([
				Vector2(260, 650),
				Vector2(650, 650),
				Vector2(1060, 690),
				Vector2(1560, 650),
				Vector2(1940, 650),
			]),
			PackedVector2Array([
				Vector2(780, 850),
				Vector2(1060, 690),
				Vector2(1420, 900),
			]),
		],
		"standing_stones": [
			Vector2(990, 360),
			Vector2(1260, 930),
		],
		"groves": [
			{"position": Vector2(430, 255), "radius": 92.0},
			{"position": Vector2(1770, 1060), "radius": 104.0},
		],
	}


static func faction_definitions() -> Dictionary:
	return {
		0: {
			"name": "The Alder League",
			"short_name": "Alder",
			"color": Color("#8fc7d4"),
			"accent": Color("#dceca8"),
		},
		1: {
			"name": "The Flint Crown",
			"short_name": "Flint",
			"color": Color("#db8179"),
			"accent": Color("#f2c078"),
		},
	}


static func unit_definitions() -> Dictionary:
	return {
		"worker": {
			"label": "Gatherer",
			"plural": "Gatherers",
			"hp": 48.0,
			"speed": 110.0,
			"damage": 4.0,
			"attack_range": 26.0,
			"attack_cooldown": 1.25,
			"cost": 35.0,
			"build_time": 2.5,
		},
		"soldier": {
			"label": "Spearman",
			"plural": "Spearmen",
			"hp": 105.0,
			"speed": 88.0,
			"damage": 15.0,
			"attack_range": 78.0,
			"attack_cooldown": 0.8,
			"cost": 60.0,
			"build_time": 4.0,
		},
	}


static func resource_definition() -> Dictionary:
	return {
		"label": "iron",
		"color": Color("#d7b35a"),
		"depleted_color": Color("#5a4c2b"),
	}
