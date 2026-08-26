extends Node2D

## Presentation and input layer for the first RTS slice.
## The simulation itself lives in simulation.gd so it can later be reused by
## a different camera, UI, or even a headless AI test runner.

const SIMULATION_SCRIPT := preload("res://src/simulation.gd")

var simulation: RtsSimulation
var camera_offset := RtsSimulation.MAP_SIZE * 0.5
var camera_zoom := 0.78
var camera_speed := 720.0
var selected_unit_ids: Array = []
var selected_base_id := -1
var dragging := false
var drag_start := Vector2.ZERO
var drag_current := Vector2.ZERO
var status_message := "Select a worker or soldier. Right-click to issue an order."
var status_message_time := 0.0
var font: Font


func _ready() -> void:
	simulation = SIMULATION_SCRIPT.new()
	add_child(simulation)
	simulation.state_changed.connect(_on_state_changed)
	simulation.match_ended.connect(_on_match_ended)
	font = ThemeDB.fallback_font
	queue_redraw()


func _process(delta: float) -> void:
	_update_camera(delta)
	status_message_time = max(0.0, status_message_time - delta)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_start = event.position
				drag_current = event.position
			else:
				drag_current = event.position
				dragging = false
				if drag_start.distance_to(drag_current) > 10.0:
					_select_box(Rect2(drag_start, drag_current - drag_start).abs())
				else:
					_select_at_screen(event.position)
				queue_redraw()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_context_order(screen_to_world(event.position))
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(event.position, 1.12)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(event.position, 1.0 / 1.12)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			simulation.reset_match()
			_clear_selection()
			_set_status("New match started.")
		elif event.keycode == KEY_ESCAPE:
			_clear_selection()
		elif event.keycode == KEY_SPACE:
			simulation.paused = not simulation.paused
			_set_status("Game paused." if simulation.paused else "Game resumed.")
		elif event.keycode == KEY_B:
			_queue_selected_production("soldier")
		elif event.keycode == KEY_W and selected_base_id >= 0:
			_queue_selected_production("worker")


func _update_camera(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		camera_offset += direction.normalized() * camera_speed * delta / camera_zoom
		camera_offset.x = clamp(camera_offset.x, 640.0 / camera_zoom, RtsSimulation.MAP_SIZE.x - 640.0 / camera_zoom)
		camera_offset.y = clamp(camera_offset.y, 360.0 / camera_zoom, RtsSimulation.MAP_SIZE.y - 360.0 / camera_zoom)


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := screen_to_world(screen_position)
	camera_zoom = clamp(camera_zoom * factor, 0.55, 1.45)
	var after := screen_to_world(screen_position)
	camera_offset += before - after


func _select_at_screen(screen_position: Vector2) -> void:
	_clear_selection()
	var entity := simulation.find_entity_at(screen_to_world(screen_position))
	if entity.is_empty() or entity["owner"] != RtsSimulation.PLAYER:
		return

	if entity["kind"] == "unit":
		selected_unit_ids.append(entity["id"])
		_set_status("Selected %s." % _unit_label(entity["id"]))
	elif entity["kind"] == "base":
		selected_base_id = entity["id"]
		_set_status("Hillfort selected. Press B for a spearman or W for a gatherer.")


func _select_box(screen_rect: Rect2) -> void:
	_clear_selection()
	var world_a := screen_to_world(screen_rect.position)
	var world_b := screen_to_world(screen_rect.end)
	var world_rect := Rect2(world_a, world_b - world_a).abs()
	for unit in simulation.units:
		if unit["owner"] == RtsSimulation.PLAYER and world_rect.has_point(unit["position"]):
			selected_unit_ids.append(unit["id"])
	if selected_unit_ids.is_empty():
		_set_status("No friendly units in selection box.")
	else:
		_set_status("Selected %d unit(s)." % selected_unit_ids.size())


func _issue_context_order(world_position: Vector2) -> void:
	if selected_unit_ids.is_empty():
		return

	var entity := simulation.find_entity_at(world_position)
	if not entity.is_empty() and entity["owner"] == RtsSimulation.ENEMY:
		if entity["kind"] == "unit" or entity["kind"] == "base":
			simulation.order_attack(selected_unit_ids, entity["kind"], entity["id"])
			_set_status("Attack order issued.")
			return

	if not entity.is_empty() and entity["kind"] == "resource":
		simulation.order_gather(selected_unit_ids, entity["id"])
		_set_status("Extraction order issued to gatherers.")
		return

	simulation.order_move(selected_unit_ids, world_position)
	_set_status("Move order issued.")


func _queue_selected_production(kind: String) -> void:
	var unit_label: String = simulation.unit_definitions[kind]["label"]
	if selected_base_id < 0:
		_set_status("Select your headquarters first.")
		return
	if simulation.queue_production(RtsSimulation.PLAYER, selected_base_id, kind):
		_set_status("Queued %s." % unit_label)
	else:
		_set_status("Could not queue %s: insufficient stores or full queue." % unit_label)


func _clear_selection() -> void:
	selected_unit_ids.clear()
	selected_base_id = -1


func _set_status(message: String) -> void:
	status_message = message
	status_message_time = 3.0


func _on_state_changed() -> void:
	# Dead units may disappear between input frames.
	var living_ids: Array = []
	for unit in simulation.units:
		living_ids.append(unit["id"])
	var valid_selection: Array = []
	for unit_id in selected_unit_ids:
		if living_ids.has(unit_id):
			valid_selection.append(unit_id)
	selected_unit_ids = valid_selection
	if selected_base_id >= 0 and simulation.get_base_by_id(selected_base_id) == null:
		selected_base_id = -1


func _on_match_ended(winner_owner: int, reason: String) -> void:
	_set_status("%s wins: %s. Press R to restart." % [simulation.faction_state[winner_owner]["name"], reason])


func screen_to_world(screen_position: Vector2) -> Vector2:
	return (screen_position - get_viewport_rect().size * 0.5) / camera_zoom + camera_offset


func world_to_screen(world_position: Vector2) -> Vector2:
	return (world_position - camera_offset) * camera_zoom + get_viewport_rect().size * 0.5


func _unit_label(unit_id: int) -> String:
	var unit = simulation.get_unit_by_id(unit_id)
	if unit == null:
		return "unit"
	return "%s #%d" % [unit["label"], unit_id]


func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("#090d12"))

	# World transform.
	draw_set_transform(viewport_size * 0.5 - camera_offset * camera_zoom, 0.0, Vector2.ONE * camera_zoom)
	_draw_world()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_hud(viewport_size)
	if dragging and drag_start.distance_to(drag_current) > 4.0:
		draw_rect(Rect2(drag_start, drag_current - drag_start).abs(), Color(0.55, 0.8, 1.0, 0.12), true)
		draw_rect(Rect2(drag_start, drag_current - drag_start).abs(), Color("#9bd4ff"), false, 1.0)


func _draw_world() -> void:
	var map_rect := Rect2(Vector2.ZERO, RtsSimulation.MAP_SIZE)
	draw_rect(map_rect, Color("#18251f"), true)
	draw_rect(map_rect, Color("#8b9b80"), false, 8.0)
	_draw_landscape_features()

	# Deliberately modest grid: readable like an old strategy map, not a modern 3D scene.
	for x in range(0, int(RtsSimulation.MAP_SIZE.x) + 1, 100):
		draw_line(Vector2(x, 0), Vector2(x, RtsSimulation.MAP_SIZE.y), Color(0.5, 0.62, 0.5, 0.10), 1.0)
	for y in range(0, int(RtsSimulation.MAP_SIZE.y) + 1, 100):
		draw_line(Vector2(0, y), Vector2(RtsSimulation.MAP_SIZE.x, y), Color(0.5, 0.62, 0.5, 0.10), 1.0)

	for resource in simulation.resources:
		var ratio: float = resource["amount"] / resource["max_amount"]
		var color: Color = simulation.resource_definition["color"].lerp(simulation.resource_definition["depleted_color"], 1.0 - ratio)
		var control_color := Color(0.78, 0.72, 0.53, 0.65)
		if resource["control"] == "player":
			control_color = simulation.faction_state[RtsSimulation.PLAYER]["color"]
		elif resource["control"] == "enemy":
			control_color = simulation.faction_state[RtsSimulation.ENEMY]["color"]
		elif resource["control"] == "contested":
			control_color = Color("#fff1b0")
		draw_arc(resource["position"], 33.0, 0.0, TAU, 32, control_color, 3.0)
		draw_circle(resource["position"], 25.0, Color(0.12, 0.10, 0.05, 0.7))
		draw_colored_polygon(PackedVector2Array([
			resource["position"] + Vector2(0, -18),
			resource["position"] + Vector2(17, 10),
			resource["position"] + Vector2(-17, 10),
		]), color)
		var resource_label: String = simulation.resource_definition["label"]
		if resource["control"] == "contested":
			resource_label += " / contested"
		elif resource["control"] == "enemy":
			resource_label += " / raided"
		draw_string(font, resource["position"] + Vector2(-18, 43), resource_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.85, 0.78, 0.56, 0.75))

	for base in simulation.bases:
		_draw_base(base)

	for unit in simulation.units:
		_draw_unit(unit)


func _draw_landscape_features() -> void:
	var river_points: PackedVector2Array = simulation.scenario["river_points"]
	draw_polyline(river_points, Color("#102b34"), 112.0, true)
	draw_polyline(river_points, Color("#275864"), 86.0, true)
	draw_polyline(river_points, Color(0.42, 0.68, 0.68, 0.45), 2.0, true)

	for road in simulation.scenario["roads"]:
		var road_points := PackedVector2Array(road)
		draw_polyline(road_points, Color(0.38, 0.30, 0.20, 0.35), 22.0, true)
		draw_polyline(road_points, Color(0.63, 0.52, 0.35, 0.28), 2.0, true)

	for grove in simulation.scenario["groves"]:
		var grove_position: Vector2 = grove["position"]
		var grove_radius: float = grove["radius"]
		draw_circle(grove_position, grove_radius, Color(0.06, 0.16, 0.12, 0.46))
		for index in range(7):
			var angle := float(index) * TAU / 7.0
			var tree_position := grove_position + Vector2(cos(angle), sin(angle)) * grove_radius * 0.62
			draw_line(tree_position + Vector2(0, 13), tree_position + Vector2(0, -10), Color("#4b6145"), 4.0)
			draw_circle(tree_position + Vector2(0, -16), 12.0, Color("#304f3b"))

	for stone_position in simulation.scenario["standing_stones"]:
		draw_colored_polygon(PackedVector2Array([
			stone_position + Vector2(-10, 16),
			stone_position + Vector2(-7, -18),
			stone_position + Vector2(5, -26),
			stone_position + Vector2(12, 15),
		]), Color("#6d7467"))
		draw_line(stone_position + Vector2(-3, -17), stone_position + Vector2(4, 8), Color(0.8, 0.82, 0.68, 0.34), 2.0)


func _draw_base(base: Dictionary) -> void:
	var color: Color = simulation.faction_state[base["owner"]]["color"]
	var accent: Color = simulation.faction_state[base["owner"]]["accent"]
	var position: Vector2 = base["position"]
	draw_circle(position, 66.0, Color(0.02, 0.03, 0.04, 0.65))
	draw_rect(Rect2(position - Vector2(45, 45), Vector2(90, 90)), color.darkened(0.45), true)
	draw_rect(Rect2(position - Vector2(36, 36), Vector2(72, 72)), color, true)
	draw_rect(Rect2(position - Vector2(25, 25), Vector2(50, 50)), Color("#252c32"), true)
	draw_line(position + Vector2(-17, 0), position + Vector2(17, 0), color, 5.0)
	draw_line(position + Vector2(0, -17), position + Vector2(0, 17), color, 5.0)

	if selected_base_id == base["id"]:
		draw_arc(position, 74.0, 0.0, TAU, 48, accent, 3.0)

	_draw_health_bar(position + Vector2(-48, 58), 96.0, base["hp"], base["max_hp"])
	draw_string(font, position + Vector2(-42, -76), "HILLFORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if not base["production_queue"].is_empty():
		var queue_item: Dictionary = base["production_queue"][0]
		var queue_label: String = simulation.unit_definitions[queue_item["kind"]]["label"]
		draw_string(font, position + Vector2(-46, 92), "%s %.1fs" % [queue_label, queue_item["remaining"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)


func _draw_unit(unit: Dictionary) -> void:
	var color: Color = simulation.faction_state[unit["owner"]]["color"]
	var position: Vector2 = unit["position"]
	var radius := 13.0 if unit["kind"] == "worker" else 17.0

	if selected_unit_ids.has(unit["id"]):
		draw_arc(position, radius + 8.0, 0.0, TAU, 24, Color("#fff1b0"), 3.0)

	draw_circle(position + Vector2(3, 4), radius, Color(0.02, 0.03, 0.04, 0.7))
	if unit["kind"] == "worker":
		draw_circle(position, radius, color)
		draw_circle(position, radius * 0.42, Color("#25313a"))
	else:
		draw_colored_polygon(PackedVector2Array([
			position + Vector2(0, -radius - 2),
			position + Vector2(radius, radius),
			position + Vector2(-radius, radius),
		]), color)
		draw_line(position, position + Vector2(0, -radius * 0.65), Color("#2a3338"), 3.0)

	_draw_health_bar(position + Vector2(-radius, radius + 7), radius * 2.0, unit["hp"], unit["max_hp"])


func _draw_health_bar(position: Vector2, width: float, hp: float, max_hp: float) -> void:
	draw_rect(Rect2(position, Vector2(width, 5)), Color("#2c1719"), true)
	draw_rect(Rect2(position, Vector2(width * clamp(hp / max_hp, 0.0, 1.0), 5)), Color("#7ee08a"), true)


func _draw_hud(viewport_size: Vector2) -> void:
	var panel := Color(0.035, 0.05, 0.065, 0.94)
	var border := Color("#6d7e80")
	var player_state: Dictionary = simulation.faction_state[RtsSimulation.PLAYER]
	var enemy_state: Dictionary = simulation.faction_state[RtsSimulation.ENEMY]
	draw_rect(Rect2(16, 16, 530, 112), panel, true)
	draw_rect(Rect2(16, 16, 530, 112), border, false, 2.0)
	draw_string(font, Vector2(32, 44), simulation.scenario["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#e7d6a0"))
	draw_string(font, Vector2(32, 68), "%s · %s" % [simulation.scenario["region"], simulation.scenario["subtitle"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6b5ad"))
	draw_string(font, Vector2(32, 94), "%s stores: %03d" % [player_state["short_name"], int(player_state["credits"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#e5c875"))
	draw_string(font, Vector2(190, 94), "Time: %05.1f" % simulation.elapsed, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#a6d5d0"))
	draw_string(font, Vector2(32, 116), "%s hillfort: %03d / 500" % [player_state["short_name"], int(simulation.bases[0]["hp"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, player_state["color"])
	draw_string(font, Vector2(190, 116), "%s hillfort: %03d / 500" % [enemy_state["short_name"], int(simulation.bases[1]["hp"])], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, enemy_state["color"])

	var objective_rect := Rect2(viewport_size.x - 360, 16, 344, 112)
	draw_rect(objective_rect, panel, true)
	draw_rect(objective_rect, border, false, 2.0)
	draw_string(font, objective_rect.position + Vector2(16, 28), "FIRST BATTLE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#e7d6a0"))
	draw_string(font, objective_rect.position + Vector2(16, 54), simulation.scenario["objective"], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d2ded7"))
	draw_string(font, objective_rect.position + Vector2(16, 82), "%s vs. %s" % [player_state["name"], enemy_state["name"]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6b5ad"))

	var help_rect := Rect2(16, viewport_size.y - 92, 660, 70)
	draw_rect(help_rect, panel, true)
	draw_rect(help_rect, border, false, 2.0)
	draw_string(font, Vector2(32, viewport_size.y - 62), "LMB select / drag box   RMB move, extract, or attack", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d2ded7"))
	draw_string(font, Vector2(32, viewport_size.y - 38), "WASD/arrows pan   wheel zoom   SPACE pause   B spearman   W gatherer", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#a6b5ad"))
	_draw_selection_panel(viewport_size)
	_draw_minimap(viewport_size)

	if simulation.paused and not simulation.ended:
		draw_rect(Rect2(viewport_size * 0.5 - Vector2(100, 28), Vector2(200, 56)), Color(0.02, 0.03, 0.04, 0.92), true)
		draw_rect(Rect2(viewport_size * 0.5 - Vector2(100, 28), Vector2(200, 56)), Color("#fff1b0"), false, 2.0)
		draw_string(font, viewport_size * 0.5 + Vector2(-43, 7), "PAUSED", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#fff1b0"))

	if status_message_time > 0.0 or simulation.ended:
		draw_string(font, Vector2(32, viewport_size.y - 108), status_message, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#fff1b0"))

	if simulation.ended:
		var winner_name: String = simulation.faction_state[simulation.winner]["name"]
		draw_rect(Rect2(viewport_size * 0.5 - Vector2(220, 80), Vector2(440, 160)), Color(0.02, 0.03, 0.04, 0.94), true)
		draw_rect(Rect2(viewport_size * 0.5 - Vector2(220, 80), Vector2(440, 160)), Color("#fff1b0"), false, 3.0)
		draw_string(font, viewport_size * 0.5 + Vector2(-110, -18), "%s WINS" % winner_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#fff1b0"))
		draw_string(font, viewport_size * 0.5 + Vector2(-104, 18), "Press R to start again", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#d2ded7"))


func _draw_selection_panel(viewport_size: Vector2) -> void:
	var panel := Color(0.035, 0.05, 0.065, 0.94)
	var border := Color("#6d7e80")
	var panel_rect := Rect2(700, viewport_size.y - 92, 260, 70)
	draw_rect(panel_rect, panel, true)
	draw_rect(panel_rect, border, false, 2.0)

	if selected_base_id >= 0:
		var base = simulation.get_base_by_id(selected_base_id)
		if base != null:
			draw_string(font, panel_rect.position + Vector2(14, 25), "HILLFORT", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e7d6a0"))
			draw_string(font, panel_rect.position + Vector2(14, 49), "Queue: %d / 4" % base["production_queue"].size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#a6b5ad"))
			return

	if selected_unit_ids.is_empty():
		draw_string(font, panel_rect.position + Vector2(14, 26), "NO SELECTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#7e8d87"))
		draw_string(font, panel_rect.position + Vector2(14, 50), "Select units or a hillfort", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6b5ad"))
		return

	var gatherer_count := 0
	var spearman_count := 0
	for unit_id in selected_unit_ids:
		var unit = simulation.get_unit_by_id(unit_id)
		if unit == null:
			continue
		if unit["kind"] == "worker":
			gatherer_count += 1
		else:
			spearman_count += 1
	var composition := ("%d gatherer" % gatherer_count) if gatherer_count == 1 else ("%d gatherers" % gatherer_count)
	if spearman_count > 0:
		composition += (" · %d spearman" % spearman_count) if spearman_count == 1 else (" · %d spearmen" % spearman_count)
	draw_string(font, panel_rect.position + Vector2(14, 26), "%d UNIT(S)" % selected_unit_ids.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#e7d6a0"))
	draw_string(font, panel_rect.position + Vector2(14, 50), composition, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#a6b5ad"))


func _draw_minimap(viewport_size: Vector2) -> void:
	var panel := Color(0.035, 0.05, 0.065, 0.94)
	var border := Color("#6d7e80")
	var minimap_rect := Rect2(viewport_size.x - 296, viewport_size.y - 184, 280, 168)
	var map_rect := Rect2(minimap_rect.position + Vector2(8, 22), Vector2(264, 138))
	var map_scale := map_rect.size / RtsSimulation.MAP_SIZE

	draw_rect(minimap_rect, panel, true)
	draw_rect(minimap_rect, border, false, 2.0)
	draw_string(font, minimap_rect.position + Vector2(10, 16), "SABLE VALE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e7d6a0"))
	draw_rect(map_rect, Color("#18251f"), true)
	draw_rect(map_rect, Color("#8b9b80"), false, 1.0)

	var river_points := PackedVector2Array()
	for world_point in simulation.scenario["river_points"]:
		river_points.append(map_rect.position + world_point * map_scale)
	draw_polyline(river_points, Color("#275864"), 10.0, true)

	for resource in simulation.resources:
		var resource_point: Vector2 = map_rect.position + resource["position"] * map_scale
		draw_circle(resource_point, 3.0, Color("#d7b35a"))

	for base in simulation.bases:
		var base_point: Vector2 = map_rect.position + base["position"] * map_scale
		var base_color: Color = simulation.faction_state[base["owner"]]["color"]
		draw_rect(Rect2(base_point - Vector2(4, 4), Vector2(8, 8)), base_color, true)

	for unit in simulation.units:
		var unit_point: Vector2 = map_rect.position + unit["position"] * map_scale
		var unit_color: Color = simulation.faction_state[unit["owner"]]["color"]
		draw_circle(unit_point, 2.0, unit_color)

	var camera_world_size := viewport_size / camera_zoom
	var camera_rect := Rect2(camera_offset - camera_world_size * 0.5, camera_world_size)
	var camera_minimap_rect := Rect2(map_rect.position + camera_rect.position * map_scale, camera_rect.size * map_scale)
	draw_rect(camera_minimap_rect, Color("#fff1b0"), false, 1.0)
