extends SceneTree

## Run with:
## godot --headless --path . --script res://tests/simulation_smoke.gd

const SIMULATION_SCRIPT := preload("res://src/simulation.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var simulation = SIMULATION_SCRIPT.new()
	get_root().add_child(simulation)

	var resource: Dictionary = simulation.resources[0]
	var worker = _find_unit(simulation, RtsSimulation.PLAYER, "worker")
	var player_soldier = _find_unit(simulation, RtsSimulation.PLAYER, "soldier")
	var enemy_soldier = _find_unit(simulation, RtsSimulation.ENEMY, "soldier")
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
	var starting_stores: float = simulation.faction_state[RtsSimulation.PLAYER]["credits"]
	for index in range(45):
		simulation._process(RtsSimulation.TICK_RATE)
	if not _expect(simulation.faction_state[RtsSimulation.PLAYER]["credits"] > starting_stores, "neutral extraction did not produce stores"):
		quit(1)
		return

	player_soldier["position"] = Vector2(100, 100)
	enemy_soldier["position"] = resource["position"]
	simulation._process(RtsSimulation.TICK_RATE)
	if not _expect(resource["control"] == "enemy", "enemy control was not detected"):
		quit(1)
		return
	if not _expect(resource["gather_rates"][RtsSimulation.PLAYER] == 0.0, "enemy control did not stop player extraction"):
		quit(1)
		return
	if not _expect(resource["gather_rates"][RtsSimulation.ENEMY] == 1.0, "enemy control incorrectly stopped enemy extraction"):
		quit(1)
		return

	player_soldier["position"] = resource["position"]
	simulation._process(RtsSimulation.TICK_RATE)
	if not _expect(resource["control"] == "contested", "contested control was not detected"):
		quit(1)
		return
	if not _expect(resource["gather_rates"][RtsSimulation.PLAYER] == 0.4, "contested extraction did not reduce player rate"):
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
