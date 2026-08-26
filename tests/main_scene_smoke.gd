extends SceneTree

## Loads the actual entry scene and allows it to initialize and draw. This test
## exists because an isolated simulation test cannot catch presentation-layer
## startup failures.

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = MAIN_SCENE.instantiate()
	get_root().add_child(main)

	await process_frame
	await process_frame

	if not _expect(main.simulation != null, "main scene did not create its simulation"):
		quit(1)
		return
	if not _expect(main.simulation.scenario.get("id", "") == "broken_oath", "main scene has no initialized scenario"):
		quit(1)
		return
	if not _expect(main.simulation.resources.size() == 6, "main scene has no initialized resources"):
		quit(1)
		return
	if not _expect(main.simulation.faction_state.size() == 2, "main scene has no initialized factions"):
		quit(1)
		return

	var player_base: Dictionary = main.simulation.bases[0]
	main._select_at_screen(main.world_to_screen(player_base["position"]))
	if not _expect(main.selected_base_id == player_base["id"], "player hillfort could not be selected"):
		quit(1)
		return
	main._queue_selected_production("worker")
	if not _expect(player_base["production_queue"].size() == 1, "selected hillfort did not accept production input"):
		quit(1)
		return

	var worker = _find_unit(main.simulation, 0, "worker")
	if not _expect(worker != null, "main scene has no selectable player worker"):
		quit(1)
		return
	main._select_at_screen(main.world_to_screen(worker["position"]))
	if not _expect(main.selected_unit_ids.has(worker["id"]), "player worker could not be selected"):
		quit(1)
		return
	main._issue_context_order(Vector2(700.0, 200.0))
	if not _expect(worker["order"] == "move", "selected worker did not receive a move order"):
		quit(1)
		return

	print("main scene smoke test passed")
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
