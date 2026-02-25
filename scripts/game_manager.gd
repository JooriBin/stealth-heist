extends Node2D

@export var player_scene: PackedScene
@export var gold_scene: PackedScene
@export var key_scene: PackedScene
@export var door_scene: PackedScene
@export var gold_count: int = 10

# Scene-tree node paths (edit in Inspector if names differ)
@export var floor_layer_path: NodePath = NodePath("../FloorLayer")
@export var wall_layer_path: NodePath = NodePath("../WallLayer")
@export var deco_layer_path: NodePath = NodePath("../DecoLayer")

# How far the exit should be from the player spawn (in tiles)
@export var min_exit_distance_tiles: int = 20

signal coins_changed(value: int)
signal key_changed(has_key: bool)

var coins: int = 0
var has_key: bool = false
var player: Node2D
var exit_zone: Area2D

func _ready() -> void:
	add_to_group("game_manager")
	coins_changed.emit(coins)
	key_changed.emit(has_key)
	spawn_player_and_exit()

# --------------------------------------------------
# LAYER HELPERS
# --------------------------------------------------
func _floor_layer() -> TileMapLayer:
	return get_node(floor_layer_path) as TileMapLayer

func _wall_layer() -> TileMapLayer:
	return get_node_or_null(wall_layer_path) as TileMapLayer

func _deco_layer() -> TileMapLayer:
	return get_node_or_null(deco_layer_path) as TileMapLayer

func _cell_to_world(cell: Vector2i) -> Vector2:
	# Always return CENTER of tile in world space
	var fl := _floor_layer()
	var ts: Vector2 = Vector2(fl.tile_set.tile_size)
	return fl.to_global(fl.map_to_local(cell) + ts * 0.5)

func _build_blocked_cells() -> Dictionary:
	# fast set: blocked[cell] = true
	var blocked := {}

	var wl := _wall_layer()
	if wl:
		for c in wl.get_used_cells():
			blocked[c] = true

	var dl := _deco_layer()
	if dl:
		for c in dl.get_used_cells():
			blocked[c] = true

	return blocked

func _build_valid_floor_cells(used_floor_cells: Array, blocked: Dictionary) -> Array[Vector2i]:
	var valid: Array[Vector2i] = []
	var fl := _floor_layer()

	for c in used_floor_cells:
		if not (c is Vector2i):
			continue

		# must be an actual floor tile
		if fl.get_cell_source_id(c) == -1:
			continue

		# must not be blocked by wall/deco tiles
		if blocked.has(c):
			continue

		valid.append(c)

	return valid

# --------------------------------------------------
# SPAWN LOGIC
# --------------------------------------------------
func spawn_player_and_exit() -> void:
	var fl := _floor_layer()
	var used_cells: Array = fl.get_used_cells()

	if used_cells.is_empty():
		push_error("No floor tiles found in FloorLayer.")
		return

	var blocked := _build_blocked_cells()
	var valid_cells := _build_valid_floor_cells(used_cells, blocked)

	if valid_cells.is_empty():
		push_error("No valid floor cells (all blocked by WallLayer/DecoLayer).")
		return

	# Spawn player
	var spawn_cell: Vector2i = valid_cells.pick_random()
	var spawn_pos: Vector2 = _cell_to_world(spawn_cell)

	player = player_scene.instantiate()
	add_child(player)
	player.global_position = spawn_pos

	# Spawn exit on valid floor only, far from player
	var exit_cell: Vector2i = pick_exit_cell(valid_cells, spawn_cell, min_exit_distance_tiles)
	var exit_pos: Vector2 = _cell_to_world(exit_cell)

	# Debug: confirm exit is on floor
	print("Exit cell:", exit_cell, " floor_source:", fl.get_cell_source_id(exit_cell))

	create_exit(exit_pos)
	spawn_door(exit_pos) # keep for testing if you want

	# Spawn key far from player + not near exit
	spawn_key(valid_cells, spawn_cell, exit_cell)

	# Spawn gold (valid + collision-safe)
	spawn_gold(valid_cells, spawn_cell, exit_cell)

func spawn_door(pos: Vector2) -> void:
	if door_scene == null:
		push_warning("Door scene not assigned!")
		return
	var door = door_scene.instantiate()
	add_child(door)
	door.global_position = pos

func get_far_cell(cells: Array[Vector2i], origin: Vector2i) -> Vector2i:
	var best_cell: Vector2i = cells[0]
	var best_distance := -1.0

	for cell in cells:
		var d = origin.distance_to(cell)
		if d > best_distance:
			best_distance = d
			best_cell = cell

	return best_cell

func pick_exit_cell(valid_cells: Array[Vector2i], spawn_cell: Vector2i, min_dist: int) -> Vector2i:
	# Pick a far-ish exit but still guaranteed floor.
	# We sample random cells and keep the farthest that meets min_dist.
	var best := spawn_cell
	var best_d := -1.0

	var tries = min(600, valid_cells.size())
	for i in range(tries):
		var c: Vector2i = valid_cells.pick_random()
		var d := spawn_cell.distance_to(c)

		if d < float(min_dist):
			continue

		# Optional: also require it not to collide (extra safety)
		if not _is_point_free(_cell_to_world(c), 6.0):
			continue

		if d > best_d:
			best_d = d
			best = c

	# fallback: farthest overall
	if best_d < 0.0:
		best = get_far_cell(valid_cells, spawn_cell)

	return best

func spawn_key(valid_cells: Array[Vector2i], spawn_cell: Vector2i, exit_cell: Vector2i) -> void:
	if key_scene == null:
		push_error("GameManager: key_scene is NOT assigned in Inspector.")
		return

	var tries := 600
	var key_cell: Vector2i = exit_cell

	# Prefer far from player AND not near the exit/door
	for i in range(tries):
		var c: Vector2i = valid_cells.pick_random()

		# don't spawn on door tile or right next to it
		if c == exit_cell:
			continue
		if c.distance_to(exit_cell) < 3.0:
			continue

		# also avoid spawning too close to player spawn
		if c.distance_to(spawn_cell) < 8.0:
			continue

		# final safety: collision check
		if not _is_point_free(_cell_to_world(c), 6.0):
			continue

		key_cell = c
		break

	# fallback if somehow none found
	if key_cell == exit_cell:
		key_cell = get_far_cell(valid_cells, spawn_cell)

	var key_pos := _cell_to_world(key_cell)
	var k = key_scene.instantiate()
	add_child(k)
	k.global_position = key_pos
	if "z_index" in k:
		k.z_index = 10

	print("Spawned KEY at cell:", key_cell, " pos:", key_pos)

func spawn_gold(valid_cells: Array[Vector2i], player_cell: Vector2i, exit_cell: Vector2i) -> void:
	if gold_scene == null:
		push_warning("Gold scene not assigned")
		return

	if valid_cells.is_empty():
		push_error("No valid cells for gold spawn.")
		return

	var tries_per_gold := 250

	for i in range(gold_count):
		var placed := false

		for t in range(tries_per_gold):
			var cell: Vector2i = valid_cells.pick_random()

			# avoid player and exit cells
			if cell == player_cell:
				continue
			if cell == exit_cell:
				continue

			var pos := _cell_to_world(cell)

			# collision-based validation (prevents walls/deco with collision)
			if not _is_point_free(pos, 6.0):
				continue

			var g = gold_scene.instantiate()
			add_child(g)
			g.global_position = pos
			placed = true
			break

		if not placed:
			push_warning("Could not place gold #%d (no free spot found)." % i)

# --------------------------------------------------
# EXIT
# --------------------------------------------------
func create_exit(pos: Vector2) -> void:
	exit_zone = Area2D.new()
	exit_zone.name = "ExitZone"

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect

	exit_zone.add_child(shape)
	exit_zone.global_position = pos
	add_child(exit_zone)

	exit_zone.body_entered.connect(_on_exit_body_entered)

func _on_exit_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return

	if not has_key:
		print("Door locked: find the key first!")
		return

	print("ESCAPED")
	reload_level()

func reload_level() -> void:
	reset_level_state()
	get_tree().change_scene_to_file("res://scenes/world.tscn")

# --------------------------------------------------
# STATE MANAGEMENT
# --------------------------------------------------
func add_coins(amount: int) -> void:
	coins = max(0, coins + amount)
	coins_changed.emit(coins)

func set_has_key(v: bool) -> void:
	has_key = v
	key_changed.emit(has_key)

func reset_level_state() -> void:
	coins = 0
	has_key = false
	coins_changed.emit(coins)
	key_changed.emit(has_key)

func go_to_level(scene_path: String) -> void:
	if scene_path == "":
		push_warning("GameManager: empty scene path")
		return
	get_tree().change_scene_to_file(scene_path)

# --------------------------------------------------
# COLLISION CHECK (spawn safety)
# --------------------------------------------------
func _is_point_free(world_pos: Vector2, radius: float = 6.0) -> bool:
	var space := get_world_2d().direct_space_state
	var params := PhysicsShapeQueryParameters2D.new()

	var shape := CircleShape2D.new()
	shape.radius = radius
	params.shape = shape
	params.transform = Transform2D(0.0, world_pos)

	# Don't count the player collider as "blocked"
	if player != null and is_instance_valid(player):
		params.exclude = [player.get_rid()]

	# if any collision hit -> not free
	return space.intersect_shape(params, 1).is_empty()
