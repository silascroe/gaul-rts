extends SceneTree

## Run with:
## godot --headless --path . --script res://tests/simulation_smoke.gd

const SIMULATION_SCRIPT := preload("res://src/simulation.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulation = SIMULATION_SCRIPT.new()
	get_root().add_child(simulation)

	if not _expect(simulation.scenario.get("id", "") == "broken_oath", "scenario was not initialized"):
		quit(1)
		return
	if not _expect(simulation.resources.size() == 6, "expected six resource sites"):
		quit(1)
		return
	if not _expect(simulation.bases.size() == 2, "expected two hillforts"):
		quit(1)
		return
	if not _expect(simulation.units.size() == 10, "expected ten starting units"):
		quit(1)
		return

	var resource: Dictionary = simulation.resources[0]
	var worker = _find_unit(simulation, SIMULATION_SCRIPT.PLAYER, "worker")
	var player_soldier = _find_unit(simulation, SIMULATION_SCRIPT.PLAYER, "soldier")
	var enemy_soldier = _find_unit(simulation, SIMULATION_SCRIPT.ENEMY, "soldier")
	if not _expect(worker != null, "player worker was not created"):
		quit(1)
		return
	if not _expect(player_soldier != null, "player soldier was not created"):
		quit(1)
		return
	if not _expect(enemy_soldier != null, "enemy soldier was not created"):
		quit(1)
		return

	worker["position"] = resource["position"]
	simulation.order_gather([worker["id"]], resource["id"])
	var starting_stores: float = simulation.faction_state[SIMULATION_SCRIPT.PLAYER]["credits"]
	for index in range(45):
		simulation._process(SIMULATION_SCRIPT.TICK_RATE)
	if not _expect(simulation.faction_state[SIMULATION_SCRIPT.PLAYER]["credits"] > starting_stores, "neutral extraction did not produce stores"):
		quit(1)
		return

	player_soldier["position"] = Vector2(100, 100)
	enemy_soldier["position"] = resource["position"]
	simulation._process(SIMULATION_SCRIPT.TICK_RATE)
	if not _expect(resource["control"] == "enemy", "enemy control was not detected"):
		quit(1)
		return
	if not _expect(resource["gather_rates"][SIMULATION_SCRIPT.PLAYER] == 0.0, "enemy control did not stop player extraction"):
		quit(1)
		return
	if not _expect(resource["gather_rates"][SIMULATION_SCRIPT.ENEMY] == 1.0, "enemy control incorrectly stopped enemy extraction"):
		quit(1)
		return

	player_soldier["position"] = resource["position"]
	simulation._process(SIMULATION_SCRIPT.TICK_RATE)
	if not _expect(resource["control"] == "contested", "contested control was not detected"):
		quit(1)
		return
	if not _expect(resource["gather_rates"][SIMULATION_SCRIPT.PLAYER] == 0.4, "contested extraction did not reduce player rate"):
		quit(1)
		return

	var player_base: Dictionary = simulation.bases[0]
	var units_before_production: int = simulation.units.size()
	if not _expect(simulation.queue_production(SIMULATION_SCRIPT.PLAYER, player_base["id"], "worker"), "worker production could not be queued"):
		quit(1)
		return
	for index in range(90):
		simulation._process(SIMULATION_SCRIPT.TICK_RATE)
	if not _expect(simulation.units.size() > units_before_production, "production queue did not create a unit"):
		quit(1)
		return

	var enemy_base: Dictionary = simulation.bases[1]
	player_soldier["position"] = enemy_base["position"]
	player_soldier["damage"] = enemy_base["hp"]
	player_soldier["attack_timer"] = 0.0
	simulation.order_attack([player_soldier["id"]], "base", enemy_base["id"])
	simulation._process(SIMULATION_SCRIPT.TICK_RATE)
	if not _expect(simulation.ended and simulation.winner == SIMULATION_SCRIPT.PLAYER, "destroying the enemy hillfort did not end the match"):
		quit(1)
		return

	simulation.reset_match()
	if not _expect(not simulation.ended and simulation.units.size() == 10, "match reset did not restore the starting state"):
		quit(1)
		return

	print("simulation smoke test passed")
	quit()


func _find_unit(simulation, owner: int, kind: String):
	for unit in simulation.units:
		if unit["owner"] == owner and unit["kind"] == kind:
			return unit
	return null


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error(message)
	return false
