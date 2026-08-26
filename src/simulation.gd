class_name RtsSimulation
extends Node

## A small fixed-step RTS simulation. Rendering and input live in main.gd.

signal state_changed
signal match_ended(winner_owner: int, reason: String)

const MAP_SIZE := Vector2(2200.0, 1300.0)
const TICK_RATE := 1.0 / 30.0
const PLAYER := 0
const ENEMY := 1
const DATA_SCRIPT := preload("res://src/game_data.gd")

var accumulator := 0.0
var elapsed := 0.0
var ai_timer := 0.0
var next_unit_id := 1
var next_base_id := 1
var next_resource_id := 1
var winner := -1
var ended := false
var paused := false

var units: Array = []
var bases: Array = []
var resources: Array = []
var faction_state: Dictionary = {}
var unit_definitions: Dictionary = {}
var resource_definition: Dictionary = {}
var scenario: Dictionary = {}


func _ready() -> void:
	reset_match()


func _process(delta: float) -> void:
	if ended:
		return
	if paused:
		state_changed.emit()
		return

	accumulator += min(delta, 0.25)
	while accumulator >= TICK_RATE:
		_step(TICK_RATE)
		accumulator -= TICK_RATE

	state_changed.emit()


func reset_match() -> void:
	accumulator = 0.0
	elapsed = 0.0
	ai_timer = 0.0
	next_unit_id = 1
	next_base_id = 1
	next_resource_id = 1
	winner = -1
	ended = false
	paused = false
	units.clear()
	bases.clear()
	resources.clear()
	scenario = DATA_SCRIPT.scenario()
	faction_state = DATA_SCRIPT.faction_definitions()
	unit_definitions = DATA_SCRIPT.unit_definitions()
	resource_definition = DATA_SCRIPT.resource_definition()
	for owner in faction_state:
		faction_state[owner]["credits"] = 120.0

	_spawn_resource(Vector2(520, 340), 1400.0)
	_spawn_resource(Vector2(820, 850), 1400.0)
	_spawn_resource(Vector2(1120, 480), 1400.0)
	_spawn_resource(Vector2(1420, 900), 1400.0)
	_spawn_resource(Vector2(1720, 360), 1400.0)
	_spawn_resource(Vector2(1880, 1040), 1400.0)

	var player_base_id := _spawn_base(PLAYER, Vector2(260, MAP_SIZE.y * 0.5))
	var enemy_base_id := _spawn_base(ENEMY, Vector2(MAP_SIZE.x - 260, MAP_SIZE.y * 0.5))

	for index in range(3):
		_spawn_unit(PLAYER, "worker", Vector2(350, 500 + index * 62))
		_spawn_unit(ENEMY, "worker", Vector2(MAP_SIZE.x - 350, 500 + index * 62))

	_spawn_unit(PLAYER, "soldier", Vector2(390, MAP_SIZE.y * 0.5 - 85))
	_spawn_unit(PLAYER, "soldier", Vector2(390, MAP_SIZE.y * 0.5 + 85))
	_spawn_unit(ENEMY, "soldier", Vector2(MAP_SIZE.x - 390, MAP_SIZE.y * 0.5 - 85))
	_spawn_unit(ENEMY, "soldier", Vector2(MAP_SIZE.x - 390, MAP_SIZE.y * 0.5 + 85))

	# Keep the identifiers referenced so the setup is obvious while this grows.
	assert(player_base_id > 0)
	assert(enemy_base_id > 0)
	state_changed.emit()


func _step(delta: float) -> void:
	elapsed += delta
	ai_timer += delta

	_update_production(delta)
	_update_resource_control()
	_update_units(delta)
	_cleanup_destroyed()

	if ai_timer >= 2.0:
		ai_timer = 0.0
		_run_basic_ai()


func _spawn_resource(position: Vector2, amount: float) -> int:
	var resource_id := next_resource_id
	next_resource_id += 1
	resources.append({
		"id": resource_id,
		"position": position,
		"amount": amount,
		"max_amount": amount,
		"control": "neutral",
		"gather_rates": {PLAYER: 1.0, ENEMY: 1.0},
		"player_presence": 0,
		"enemy_presence": 0,
	})
	return resource_id


func _spawn_base(owner: int, position: Vector2) -> int:
	var base_id := next_base_id
	next_base_id += 1
	bases.append({
		"id": base_id,
		"owner": owner,
		"position": position,
		"hp": 500.0,
		"max_hp": 500.0,
		"production_queue": [],
	})
	return base_id


func _spawn_unit(owner: int, kind: String, position: Vector2) -> int:
	var unit_id := next_unit_id
	next_unit_id += 1
	var definition: Dictionary = unit_definitions[kind]

	var unit := {
		"id": unit_id,
		"owner": owner,
		"kind": kind,
		"label": definition["label"],
		"position": position,
		"hp": definition["hp"],
		"max_hp": definition["hp"],
		"speed": definition["speed"],
		"damage": definition["damage"],
		"attack_range": definition["attack_range"],
		"attack_cooldown": definition["attack_cooldown"],
		"attack_timer": 0.0,
		"order": "idle",
		"target_position": position,
		"target_kind": "",
		"target_id": -1,
		"gather_id": -1,
		"gather_progress": 0.0,
	}
	units.append(unit)
	return unit_id


func queue_production(owner: int, base_id: int, kind: String) -> bool:
	var base = get_base_by_id(base_id)
	if base == null or base["owner"] != owner or ended:
		return false
	if kind != "worker" and kind != "soldier":
		return false
	if base["production_queue"].size() >= 4:
		return false

	var cost: float = unit_definitions[kind]["cost"]
	if faction_state[owner]["credits"] < cost:
		return false

	faction_state[owner]["credits"] = faction_state[owner]["credits"] - cost
	base["production_queue"].append({
		"kind": kind,
		"remaining": unit_definitions[kind]["build_time"],
	})
	return true


func order_move(unit_ids: Array, destination: Vector2) -> void:
	var order_index := 0
	for unit in units:
		if unit["owner"] != PLAYER or not unit_ids.has(unit["id"]):
			continue
		var column := order_index % 3
		var row := int(order_index / 3)
		var offset := Vector2((column - 1) * 30, row * 30)
		unit["order"] = "move"
		unit["target_position"] = _clamp_to_map(destination + offset)
		unit["target_kind"] = ""
		unit["target_id"] = -1
		unit["gather_id"] = -1
		order_index += 1


func order_attack(unit_ids: Array, target_kind: String, target_id: int) -> void:
	for unit in units:
		if unit["owner"] != PLAYER or not unit_ids.has(unit["id"]):
			continue
		if target_kind == "unit" and get_unit_by_id(target_id) == null:
			continue
		if target_kind == "base" and get_base_by_id(target_id) == null:
			continue
		unit["order"] = "attack"
		unit["target_kind"] = target_kind
		unit["target_id"] = target_id
		unit["gather_id"] = -1


func order_gather(unit_ids: Array, resource_id: int) -> void:
	for unit in units:
		if unit["owner"] != PLAYER or unit["kind"] != "worker" or not unit_ids.has(unit["id"]):
			continue
		if get_resource_by_id(resource_id) == null:
			continue
		unit["order"] = "gather"
		unit["gather_id"] = resource_id
		unit["target_kind"] = ""
		unit["target_id"] = -1


func _update_production(delta: float) -> void:
	for base in bases:
		if base["production_queue"].is_empty():
			continue
		var item: Dictionary = base["production_queue"][0]
		item["remaining"] -= delta
		if item["remaining"] > 0.0:
			continue

		var spawn_direction := Vector2(-1, 0) if base["owner"] == PLAYER else Vector2(1, 0)
		var spawn_position: Vector2 = base["position"] + spawn_direction * 90.0
		_spawn_unit(base["owner"], item["kind"], _clamp_to_map(spawn_position))
		base["production_queue"].pop_front()


func _update_units(delta: float) -> void:
	for unit in units:
		if unit["hp"] <= 0.0:
			continue
		unit["attack_timer"] = max(0.0, unit["attack_timer"] - delta)

		match unit["order"]:
			"move":
				_move_toward(unit, unit["target_position"], delta)
				if unit["position"].distance_to(unit["target_position"]) < 5.0:
					unit["order"] = "idle"
			"attack":
				_update_attack(unit, delta)
			"gather":
				_update_gather(unit, delta)


func _move_toward(unit: Dictionary, target: Vector2, delta: float) -> void:
	var position: Vector2 = unit["position"]
	var distance := position.distance_to(target)
	if distance <= 0.1:
		return
	var step := min(distance, unit["speed"] * delta)
	unit["position"] = _clamp_to_map(position + position.direction_to(target) * step)


func _update_attack(unit: Dictionary, _delta: float) -> void:
	var target = _get_target(unit["target_kind"], unit["target_id"])
	if target == null or target["owner"] == unit["owner"] or target["hp"] <= 0.0:
		unit["order"] = "idle"
		unit["target_kind"] = ""
		unit["target_id"] = -1
		return

	var target_position: Vector2 = target["position"]
	var distance: float = unit["position"].distance_to(target_position)
	var attack_range: float = unit["attack_range"]
	if distance > attack_range:
		_move_toward(unit, target_position, TICK_RATE)
		return

	if unit["attack_timer"] <= 0.0:
		_apply_damage(unit["target_kind"], unit["target_id"], unit["damage"], unit["owner"])
		unit["attack_timer"] = unit["attack_cooldown"]


func _update_gather(unit: Dictionary, delta: float) -> void:
	var resource = get_resource_by_id(unit["gather_id"])
	if resource == null or resource["amount"] <= 0.0:
		unit["order"] = "idle"
		return

	var resource_position: Vector2 = resource["position"]
	if unit["position"].distance_to(resource_position) > 28.0:
		_move_toward(unit, resource_position, delta)
		return

	# Extraction is abstract: there is no return trip. The price of that
	# convenience is that the site itself becomes the strategic objective.
	var gather_rate: float = resource["gather_rates"][unit["owner"]]
	if gather_rate <= 0.0:
		unit["gather_progress"] = max(0.0, unit["gather_progress"] - delta)
		return

	unit["gather_progress"] += delta * gather_rate
	if unit["gather_progress"] < 1.0:
		return

	unit["gather_progress"] = 0.0
	var amount := min(5.0, resource["amount"])
	resource["amount"] -= amount
	faction_state[unit["owner"]]["credits"] = faction_state[unit["owner"]]["credits"] + amount


func _update_resource_control() -> void:
	for resource in resources:
		var player_presence := 0
		var enemy_presence := 0
		for unit in units:
			if unit["kind"] != "soldier" or unit["hp"] <= 0.0:
				continue
			if unit["position"].distance_to(resource["position"]) > 130.0:
				continue
			if unit["owner"] == PLAYER:
				player_presence += 1
			else:
				enemy_presence += 1

		resource["player_presence"] = player_presence
		resource["enemy_presence"] = enemy_presence
		if player_presence > 0 and enemy_presence > 0:
			resource["control"] = "contested"
			resource["gather_rates"][PLAYER] = 0.4
			resource["gather_rates"][ENEMY] = 0.4
		elif enemy_presence > 0:
			resource["control"] = "enemy"
			resource["gather_rates"][PLAYER] = 0.0
			resource["gather_rates"][ENEMY] = 1.0
		elif player_presence > 0:
			resource["control"] = "player"
			resource["gather_rates"][PLAYER] = 1.0
			resource["gather_rates"][ENEMY] = 0.0
		else:
			resource["control"] = "neutral"
			resource["gather_rates"][PLAYER] = 1.0
			resource["gather_rates"][ENEMY] = 1.0


func _apply_damage(target_kind: String, target_id: int, amount: float, attacking_owner: int) -> void:
	if target_kind == "unit":
		var target_unit = get_unit_by_id(target_id)
		if target_unit != null:
			target_unit["hp"] -= amount
	elif target_kind == "base":
		var target_base = get_base_by_id(target_id)
		if target_base != null:
			target_base["hp"] -= amount
			if target_base["hp"] <= 0.0 and not ended:
				ended = true
				winner = attacking_owner
				match_ended.emit(winner, "headquarters destroyed")


func _cleanup_destroyed() -> void:
	var survivors: Array = []
	for unit in units:
		if unit["hp"] > 0.0:
			survivors.append(unit)
	units = survivors


func _run_basic_ai() -> void:
	if ended:
		return

	var enemy_base = _first_base_for_owner(ENEMY)
	if enemy_base == null:
		return

	if faction_state[ENEMY]["credits"] >= 60.0:
		queue_production(ENEMY, enemy_base["id"], "soldier")

	var player_base = _first_base_for_owner(PLAYER)
	for unit in units:
		if unit["owner"] != ENEMY:
			continue
		if unit["kind"] == "worker":
			if unit["order"] == "idle":
				var resource = _nearest_available_resource(unit["position"])
				if resource != null:
					unit["order"] = "gather"
					unit["gather_id"] = resource["id"]
		elif unit["kind"] == "soldier" and unit["order"] == "idle" and player_base != null:
			unit["order"] = "attack"
			unit["target_kind"] = "base"
			unit["target_id"] = player_base["id"]


func _get_target(target_kind: String, target_id: int):
	if target_kind == "unit":
		return get_unit_by_id(target_id)
	if target_kind == "base":
		return get_base_by_id(target_id)
	return null


func _nearest_available_resource(from_position: Vector2):
	var best = null
	var best_distance := INF
	for resource in resources:
		if resource["amount"] <= 0.0:
			continue
		var distance: float = from_position.distance_to(resource["position"])
		if distance < best_distance:
			best = resource
			best_distance = distance
	return best


func _first_base_for_owner(owner: int):
	for base in bases:
		if base["owner"] == owner:
			return base
	return null


func _clamp_to_map(position: Vector2) -> Vector2:
	return Vector2(
		clamp(position.x, 40.0, MAP_SIZE.x - 40.0),
		clamp(position.y, 40.0, MAP_SIZE.y - 40.0)
	)


func get_unit_by_id(unit_id: int):
	for unit in units:
		if unit["id"] == unit_id:
			return unit
	return null


func get_base_by_id(base_id: int):
	for base in bases:
		if base["id"] == base_id:
			return base
	return null


func get_resource_by_id(resource_id: int):
	for resource in resources:
		if resource["id"] == resource_id:
			return resource
	return null


func find_entity_at(world_position: Vector2) -> Dictionary:
	var nearest_distance := INF
	var result: Dictionary = {}

	for unit in units:
		var distance: float = world_position.distance_to(unit["position"])
		if distance <= 24.0 and distance < nearest_distance:
			nearest_distance = distance
			result = {"kind": "unit", "id": unit["id"], "owner": unit["owner"]}

	for base in bases:
		var distance: float = world_position.distance_to(base["position"])
		if distance <= 58.0 and distance < nearest_distance:
			nearest_distance = distance
			result = {"kind": "base", "id": base["id"], "owner": base["owner"]}

	for resource in resources:
		var distance: float = world_position.distance_to(resource["position"])
		if distance <= 30.0 and distance < nearest_distance:
			nearest_distance = distance
			result = {"kind": "resource", "id": resource["id"], "owner": -1}

	return result
