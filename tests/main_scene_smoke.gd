extends SceneTree

## Loads the actual entry scene and allows it to initialize and draw. This test
## exists because an isolated simulation test cannot catch presentation-layer
## startup failures.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const SIMULATION_SCRIPT := preload("res://src/simulation.gd")


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

	var pan_key := InputEventKey.new()
	pan_key.keycode = KEY_W
	pan_key.pressed = true
	main._unhandled_input(pan_key)
	if not _expect(player_base["production_queue"].is_empty(), "camera-up key queued a gatherer"):
		quit(1)
		return

	var gatherer_key := InputEventKey.new()
	gatherer_key.keycode = KEY_G
	gatherer_key.pressed = true
	main._unhandled_input(gatherer_key)
	if not _expect(player_base["production_queue"].size() == 1, "gatherer production key did not queue a worker"):
		quit(1)
		return

	main.camera_offset = Vector2(-1000.0, 9000.0)
	main._zoom_at(main.get_viewport_rect().size * 0.5, 0.01)
	var half_view := main.get_viewport_rect().size * 0.5 / main.camera_zoom
	if not _expect(_camera_axis_is_valid(main.camera_offset.x, half_view.x, SIMULATION_SCRIPT.MAP_SIZE.x), "camera x escaped the map after zoom"):
		quit(1)
		return
	if not _expect(_camera_axis_is_valid(main.camera_offset.y, half_view.y, SIMULATION_SCRIPT.MAP_SIZE.y), "camera y escaped the map after zoom"):
		quit(1)
		return
	main.camera_zoom = 0.78
	main.camera_offset = SIMULATION_SCRIPT.MAP_SIZE * 0.5
	main._clamp_camera()

	var drag_press := InputEventMouseButton.new()
	drag_press.button_index = MOUSE_BUTTON_LEFT
	drag_press.pressed = true
	drag_press.position = Vector2(100.0, 100.0)
	main._unhandled_input(drag_press)
	var drag_motion := InputEventMouseMotion.new()
	drag_motion.position = Vector2(180.0, 160.0)
	main._unhandled_input(drag_motion)
	if not _expect(main.dragging and main.drag_current == drag_motion.position, "drag marquee did not track mouse motion"):
		quit(1)
		return
	var drag_release := InputEventMouseButton.new()
	drag_release.button_index = MOUSE_BUTTON_LEFT
	drag_release.pressed = false
	drag_release.position = drag_motion.position
	main._unhandled_input(drag_release)
	if not _expect(not main.dragging, "drag selection did not finish on mouse release"):
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


func _camera_axis_is_valid(value: float, half_view: float, map_extent: float) -> bool:
	if half_view * 2.0 >= map_extent:
		return is_equal_approx(value, map_extent * 0.5)
	return value >= half_view - 0.01 and value <= map_extent - half_view + 0.01


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
