class_name FirstGameData
extends RefCounted

## Setting and rules data live here so the simulation does not become a wall of
## hard-coded names and numbers as the project grows.


static func scenarios() -> Dictionary:
	return {
		"broken_oath": {
			"id": "broken_oath",
			"title": "THE BROKEN OATH",
			"region": "The Sable Vale",
			"subtitle": "A border war in an alternate Iron Age Gaul",
			"objective": "Break the Flint Crown's hillfort.",
			"starting_credits": 120.0,
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
			"resources": [
				{"position": Vector2(520, 340), "amount": 1400.0},
				{"position": Vector2(820, 850), "amount": 1400.0},
				{"position": Vector2(1120, 480), "amount": 1400.0},
				{"position": Vector2(1420, 900), "amount": 1400.0},
				{"position": Vector2(1720, 360), "amount": 1400.0},
				{"position": Vector2(1880, 1040), "amount": 1400.0},
			],
			"bases": [
				{"owner": 0, "position": Vector2(260, 650)},
				{"owner": 1, "position": Vector2(1940, 650)},
			],
			"starting_units": [
				{"owner": 0, "kind": "worker", "position": Vector2(350, 500)},
				{"owner": 1, "kind": "worker", "position": Vector2(1850, 500)},
				{"owner": 0, "kind": "worker", "position": Vector2(350, 562)},
				{"owner": 1, "kind": "worker", "position": Vector2(1850, 562)},
				{"owner": 0, "kind": "worker", "position": Vector2(350, 624)},
				{"owner": 1, "kind": "worker", "position": Vector2(1850, 624)},
				{"owner": 0, "kind": "soldier", "position": Vector2(390, 565)},
				{"owner": 0, "kind": "soldier", "position": Vector2(390, 735)},
				{"owner": 1, "kind": "soldier", "position": Vector2(1810, 565)},
				{"owner": 1, "kind": "soldier", "position": Vector2(1810, 735)},
			],
		},
	}


static func scenario(scenario_id: String = "broken_oath") -> Dictionary:
	var definitions := scenarios()
	if definitions.has(scenario_id):
		return definitions[scenario_id]
	return definitions["broken_oath"]


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
